//! Notification rows own the bounded in-memory rows shown by notification banners.

const std = @import("std");

const max_entries: u32 = 256;
const max_app_name_bytes: u32 = 256;
const max_app_icon_bytes: u32 = 256;
const max_summary_bytes: u32 = 512;
const max_body_bytes: u32 = 4096;

comptime {
    std.debug.assert(max_entries > 0);
    std.debug.assert(max_app_name_bytes > 0);
    std.debug.assert(max_app_icon_bytes > 0);
    std.debug.assert(max_summary_bytes > 0);
    std.debug.assert(max_body_bytes > 0);
}

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

const Rows = struct {
    mu: std.Io.Mutex = .init,
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    close_fn: ?*const fn (u32) bool = null,
};

var row_store: Rows = .{};

pub fn registerCloser(close_fn: *const fn (u32) bool) void {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);
    row_store.close_fn = close_fn;
}

pub fn clearCloser(close_fn: *const fn (u32) bool) void {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);
    if (row_store.close_fn == close_fn) row_store.close_fn = null;
}

pub fn resetForTest(allocator: std.mem.Allocator) void {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);
    for (row_store.entries.items) |row| {
        freeEntry(allocator, row);
    }
    row_store.entries.clearRetainingCapacity();
    row_store.close_fn = null;
}

fn deinitForTest(allocator: std.mem.Allocator) void {
    resetForTest(allocator);
    row_store.entries.deinit(allocator);
    row_store.entries = .empty;
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
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);

    const now = nowNs();
    if (findIndexLocked(id)) |idx| {
        var row = &row_store.entries.items[idx];
        allocator.free(row.app_name);
        allocator.free(row.app_icon);
        allocator.free(row.summary);
        allocator.free(row.body);
        row.app_name = try duplicateBounded(allocator, app_name, max_app_name_bytes);
        row.app_icon = try duplicateBounded(allocator, app_icon, max_app_icon_bytes);
        row.summary = try duplicateBounded(allocator, summary, max_summary_bytes);
        row.body = try duplicateBounded(allocator, body, max_body_bytes);
        row.urgency = urgency;
        row.transient = transient;
        row.active = true;
        row.closed_reason = 0;
        row.updated_ns = now;
        return;
    }

    try row_store.entries.append(allocator, .{
        .id = id,
        .app_name = try duplicateBounded(allocator, app_name, max_app_name_bytes),
        .app_icon = try duplicateBounded(allocator, app_icon, max_app_icon_bytes),
        .summary = try duplicateBounded(allocator, summary, max_summary_bytes),
        .body = try duplicateBounded(allocator, body, max_body_bytes),
        .urgency = urgency,
        .transient = transient,
        .active = true,
        .closed_reason = 0,
        .created_ns = now,
        .updated_ns = now,
    });

    while (row_store.entries.items.len > max_entries) {
        const removed = row_store.entries.orderedRemove(0);
        freeEntry(allocator, removed);
    }
}

pub fn recordClosed(id: u32, reason: u32) void {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);
    const idx = findIndexLocked(id) orelse return;
    row_store.entries.items[idx].active = false;
    row_store.entries.items[idx].closed_reason = reason;
    row_store.entries.items[idx].updated_ns = nowNs();
}

pub fn closeById(id: u32) bool {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);
    const close_fn = row_store.close_fn orelse return false;
    return close_fn(id);
}

pub fn closeAllActive() u32 {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    const close_fn = row_store.close_fn;
    var ids: [max_entries]u32 = undefined;
    var id_count: u32 = 0;
    if (close_fn != null) {
        for (row_store.entries.items) |entry| {
            if (!entry.active) continue;
            std.debug.assert(id_count < max_entries);
            ids[id_count] = entry.id;
            id_count += 1;
        }
    }
    row_store.mu.unlock(std.Options.debug_io);

    if (close_fn == null) return 0;
    var closed: u32 = 0;
    for (ids[0..id_count]) |id| {
        if (close_fn.?(id)) closed += 1;
    }
    return closed;
}

pub fn snapshot(allocator: std.mem.Allocator) ![]Snapshot {
    row_store.mu.lockUncancelable(std.Options.debug_io);
    defer row_store.mu.unlock(std.Options.debug_io);

    var out = try allocator.alloc(Snapshot, row_store.entries.items.len);
    errdefer {
        for (out) |row| freeSnapshotRow(allocator, row);
        allocator.free(out);
    }

    for (row_store.entries.items, 0..) |entry, idx| {
        out[idx] = .{
            .id = entry.id,
            .app_name = try duplicateBounded(allocator, entry.app_name, max_app_name_bytes),
            .app_icon = try duplicateBounded(allocator, entry.app_icon, max_app_icon_bytes),
            .summary = try duplicateBounded(allocator, entry.summary, max_summary_bytes),
            .body = try duplicateBounded(allocator, entry.body, max_body_bytes),
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
    for (row_store.entries.items, 0..) |row, idx| {
        if (row.id == id) return @intCast(idx);
    }
    return null;
}

fn duplicateBounded(allocator: std.mem.Allocator, text: []const u8, max_bytes: u32) ![]u8 {
    const out_len = @min(text.len, max_bytes);
    const out = try allocator.dupe(u8, text[0..out_len]);
    if (text.len > out_len and out_len > 0) out[out_len - 1] = '~';
    return out;
}

fn nowNs() i128 {
    return std.Io.Clock.real.now(std.Options.debug_io).toNanoseconds();
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
    defer deinitForTest(allocator);

    try recordNotify(allocator, 7, "app", "app-icon", "hello", "body", 2, true);
    recordClosed(7, 3);
    try recordNotify(allocator, 7, "app2", "app2-icon", "hello2", "body2", 1, false);

    const rows = try snapshot(allocator);
    defer freeSnapshot(allocator, rows);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(row_store.entries.items.len)));
    try std.testing.expectEqual(@as(u32, 7), rows[0].id);
    try std.testing.expectEqualStrings("app2", rows[0].app_name);
    try std.testing.expectEqualStrings("app2-icon", rows[0].app_icon);
    try std.testing.expect(rows[0].active);
}

test "recordNotify bounds retained body bytes" {
    const allocator = std.testing.allocator;
    resetForTest(allocator);
    defer deinitForTest(allocator);

    const body = [_]u8{'x'} ** (max_body_bytes + 1);
    try recordNotify(allocator, 9, "app", "icon", "summary", &body, 1, false);

    const rows = try snapshot(allocator);
    defer freeSnapshot(allocator, rows);
    try std.testing.expectEqual(@as(u32, max_body_bytes), @as(u32, @intCast(rows[0].body.len)));
    try std.testing.expectEqual(@as(u8, '~'), rows[0].body[rows[0].body.len - 1]);
}
