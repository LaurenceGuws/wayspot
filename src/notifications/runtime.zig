const std = @import("std");

const max_entries: u32 = 256;

const Entry = struct {
    id: u32,
    app_name: []u8,
    app_icon: []u8,
    summary: []u8,
    body: []u8,
    urgency: u8,
    transient: bool,
    active: bool,
    closed_reason: u32,
    created_ns: i128,
    updated_ns: i128,
};

pub const Snapshot = struct {
    id: u32,
    app_name: []u8,
    app_icon: []u8,
    summary: []u8,
    body: []u8,
    urgency: u8,
    transient: bool,
    active: bool,
    closed_reason: u32,
    created_ns: i128,
    updated_ns: i128,
};

const Runtime = struct {
    mu: std.Thread.Mutex = .{},
    entries: std.ArrayListUnmanaged(Entry) = .{},
    close_fn: ?*const fn (u32) bool = null,
};

var runtime: Runtime = .{};

pub fn registerCloser(close_fn: *const fn (u32) bool) void {
    runtime.mu.lock();
    defer runtime.mu.unlock();
    runtime.close_fn = close_fn;
}

pub fn clearCloser(close_fn: *const fn (u32) bool) void {
    runtime.mu.lock();
    defer runtime.mu.unlock();
    if (runtime.close_fn == close_fn) runtime.close_fn = null;
}

pub fn resetForTest(allocator: std.mem.Allocator) void {
    runtime.mu.lock();
    defer runtime.mu.unlock();
    for (runtime.entries.items) |row| {
        freeEntry(allocator, row);
    }
    runtime.entries.clearRetainingCapacity();
    runtime.close_fn = null;
}

pub fn recordNotify(
    allocator: std.mem.Allocator,
    id: u32,
    app_name: []const u8,
    app_icon: []const u8,
    summary: []const u8,
    body: []const u8,
    urgency: u8,
    transient: bool,
) !void {
    runtime.mu.lock();
    defer runtime.mu.unlock();

    const now = std.time.nanoTimestamp();
    if (findIndexLocked(id)) |idx| {
        var row = &runtime.entries.items[idx];
        allocator.free(row.app_name);
        allocator.free(row.app_icon);
        allocator.free(row.summary);
        allocator.free(row.body);
        row.app_name = try allocator.dupe(u8, app_name);
        row.app_icon = try allocator.dupe(u8, app_icon);
        row.summary = try allocator.dupe(u8, summary);
        row.body = try allocator.dupe(u8, body);
        row.urgency = urgency;
        row.transient = transient;
        row.active = true;
        row.closed_reason = 0;
        row.updated_ns = now;
        return;
    }

    try runtime.entries.append(allocator, .{
        .id = id,
        .app_name = try allocator.dupe(u8, app_name),
        .app_icon = try allocator.dupe(u8, app_icon),
        .summary = try allocator.dupe(u8, summary),
        .body = try allocator.dupe(u8, body),
        .urgency = urgency,
        .transient = transient,
        .active = true,
        .closed_reason = 0,
        .created_ns = now,
        .updated_ns = now,
    });

    while (runtime.entries.items.len > max_entries) {
        const removed = runtime.entries.orderedRemove(0);
        freeEntry(allocator, removed);
    }
}

pub fn recordClosed(id: u32, reason: u32) void {
    runtime.mu.lock();
    defer runtime.mu.unlock();
    const idx = findIndexLocked(id) orelse return;
    runtime.entries.items[idx].active = false;
    runtime.entries.items[idx].closed_reason = reason;
    runtime.entries.items[idx].updated_ns = std.time.nanoTimestamp();
}

pub fn closeById(id: u32) bool {
    runtime.mu.lock();
    defer runtime.mu.unlock();
    const close_fn = runtime.close_fn orelse return false;
    return close_fn(id);
}

pub fn closeAllActive() u32 {
    runtime.mu.lock();
    const close_fn = runtime.close_fn;
    var ids = std.ArrayList(u32).empty;
    defer ids.deinit(std.heap.page_allocator);
    if (close_fn != null) {
        for (runtime.entries.items) |entry| {
            if (!entry.active) continue;
            ids.append(std.heap.page_allocator, entry.id) catch |err| {
                std.log.warn("notifications close-all id buffer append failed: {s}", .{@errorName(err)});
                break;
            };
        }
    }
    runtime.mu.unlock();

    if (close_fn == null) return 0;
    var closed: u32 = 0;
    for (ids.items) |id| {
        if (close_fn.?(id)) closed += 1;
    }
    return closed;
}

pub fn snapshot(allocator: std.mem.Allocator) ![]Snapshot {
    runtime.mu.lock();
    defer runtime.mu.unlock();

    var out = try allocator.alloc(Snapshot, runtime.entries.items.len);
    errdefer {
        for (out) |row| freeSnapshotRow(allocator, row);
        allocator.free(out);
    }

    for (runtime.entries.items, 0..) |entry, idx| {
        out[idx] = .{
            .id = entry.id,
            .app_name = try allocator.dupe(u8, entry.app_name),
            .app_icon = try allocator.dupe(u8, entry.app_icon),
            .summary = try allocator.dupe(u8, entry.summary),
            .body = try allocator.dupe(u8, entry.body),
            .urgency = entry.urgency,
            .transient = entry.transient,
            .active = entry.active,
            .closed_reason = entry.closed_reason,
            .created_ns = entry.created_ns,
            .updated_ns = entry.updated_ns,
        };
    }
    return out;
}

pub fn freeSnapshot(allocator: std.mem.Allocator, rows: []Snapshot) void {
    for (rows) |row| freeSnapshotRow(allocator, row);
    allocator.free(rows);
}

fn findIndexLocked(id: u32) ?u32 {
    for (runtime.entries.items, 0..) |row, idx| {
        if (row.id == id) return @intCast(idx);
    }
    return null;
}

fn freeEntry(allocator: std.mem.Allocator, row: Entry) void {
    allocator.free(row.app_name);
    allocator.free(row.app_icon);
    allocator.free(row.summary);
    allocator.free(row.body);
}

fn freeSnapshotRow(allocator: std.mem.Allocator, row: Snapshot) void {
    allocator.free(row.app_name);
    allocator.free(row.app_icon);
    allocator.free(row.summary);
    allocator.free(row.body);
}

test "recordNotify and snapshot preserve latest state" {
    const allocator = std.testing.allocator;
    resetForTest(allocator);
    defer resetForTest(allocator);

    try recordNotify(allocator, 7, "app", "app-icon", "hello", "body", 2, true);
    recordClosed(7, 3);
    try recordNotify(allocator, 7, "app2", "app2-icon", "hello2", "body2", 1, false);

    const rows = try snapshot(allocator);
    defer freeSnapshot(allocator, rows);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(rows.len)));
    try std.testing.expectEqual(@as(u32, 7), rows[0].id);
    try std.testing.expectEqualStrings("app2", rows[0].app_name);
    try std.testing.expectEqualStrings("app2-icon", rows[0].app_icon);
    try std.testing.expect(rows[0].active);
}
