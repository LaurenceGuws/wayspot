//! Owns the bounded active notification records of one resident process.

const std = @import("std");
const builtin = @import("builtin");

pub const capacity = 256;
pub const app_name_capacity = 256;
pub const app_icon_capacity = 1024;
pub const summary_capacity = 1024;
pub const body_capacity = 16 * 1024;

pub const Request = struct {
    replaces_id: u32,
    app_name: []const u8,
    app_icon: []const u8,
    summary: []const u8,
    body: []const u8,
    expire_timeout: i32,
};

pub const Notification = struct {
    id: u32,
    storage: []u8,
    app_name: []u8,
    app_icon: []u8,
    summary: []u8,
    body: []u8,
    expire_timeout: i32,

    fn init(allocator: std.mem.Allocator, id: u32, request: Request) error{OutOfMemory}!Notification {
        std.debug.assert(id != 0);
        const size = request.app_name.len + request.app_icon.len + request.summary.len + request.body.len;
        const storage = try allocator.alloc(u8, size);
        var offset: usize = 0;

        return .{
            .id = id,
            .storage = storage,
            .app_name = copy(storage, &offset, request.app_name),
            .app_icon = copy(storage, &offset, request.app_icon),
            .summary = copy(storage, &offset, request.summary),
            .body = copy(storage, &offset, request.body),
            .expire_timeout = request.expire_timeout,
        };
    }

    fn deinit(notification: *Notification, allocator: std.mem.Allocator) void {
        allocator.free(notification.storage);
        notification.* = undefined;
    }
};

fn copy(storage: []u8, offset: *usize, bytes: []const u8) []u8 {
    std.debug.assert(offset.* <= storage.len);
    std.debug.assert(bytes.len <= storage.len - offset.*);
    const result = storage[offset.*..][0..bytes.len];
    @memcpy(result, bytes);
    offset.* += bytes.len;
    return result;
}

pub const Store = struct {
    slots: [capacity]?Notification = @splat(null),
    count: usize = 0,
    last_id: u32 = 0,

    pub fn deinit(store: *Store, allocator: std.mem.Allocator) void {
        store.assertValid();
        for (&store.slots) |*slot| {
            if (slot.*) |*notification| notification.deinit(allocator);
            slot.* = null;
        }
        store.count = 0;
        store.assertValid();
    }

    /// Validates and owns one request before atomically inserting or replacing it.
    pub fn notify(
        store: *Store,
        allocator: std.mem.Allocator,
        request: Request,
    ) error{ InvalidUtf8, FieldTooLong, RecordsFull, IdExhausted, OutOfMemory }!u32 {
        store.assertValid();
        try validate(request);

        if (request.replaces_id != 0) {
            if (store.find(request.replaces_id)) |index| {
                const replacement = try Notification.init(allocator, request.replaces_id, request);
                store.slots[index].?.deinit(allocator);
                store.slots[index] = replacement;
                store.assertValid();
                return request.replaces_id;
            }
        }

        if (store.count == capacity) return error.RecordsFull;
        const id = try store.nextId();
        var notification = try Notification.init(allocator, id, request);
        errdefer notification.deinit(allocator);
        const index = store.freeSlot();
        std.debug.assert(store.slots[index] == null);
        store.slots[index] = notification;
        store.count += 1;
        store.last_id = id;
        store.assertValid();
        return id;
    }

    /// Invalidates and releases one known notification before its caller emits a close signal.
    pub fn close(
        store: *Store,
        allocator: std.mem.Allocator,
        id: u32,
    ) error{UnknownNotification}!void {
        store.assertValid();
        const index = store.find(id) orelse return error.UnknownNotification;
        store.slots[index].?.deinit(allocator);
        store.slots[index] = null;
        store.count -= 1;
        store.assertValid();
    }

    pub fn get(store: *const Store, id: u32) ?*const Notification {
        const index = store.find(id) orelse return null;
        return &store.slots[index].?;
    }

    fn find(store: *const Store, id: u32) ?usize {
        if (id == 0) return null;
        for (store.slots, 0..) |slot, index| {
            if (slot) |notification| {
                if (notification.id == id) return index;
            }
        }
        return null;
    }

    fn freeSlot(store: *const Store) usize {
        std.debug.assert(store.count < capacity);
        for (store.slots, 0..) |slot, index| {
            if (slot == null) return index;
        }
        unreachable;
    }

    fn nextId(store: *const Store) error{IdExhausted}!u32 {
        var id = store.last_id;
        for (0..capacity + 1) |_| {
            id +%= 1;
            if (id == 0) id = 1;
            if (store.find(id) == null) return id;
        }
        return error.IdExhausted;
    }

    fn assertValid(store: *const Store) void {
        std.debug.assert(store.count <= capacity);
        var count: usize = 0;
        for (store.slots, 0..) |slot, index| {
            const notification = slot orelse continue;
            std.debug.assert(notification.id != 0);
            count += 1;
            for (store.slots[index + 1 ..]) |other_slot| {
                if (other_slot) |other| std.debug.assert(notification.id != other.id);
            }
        }
        std.debug.assert(count == store.count);
    }
};

fn validate(request: Request) error{ InvalidUtf8, FieldTooLong }!void {
    const fields = [_]struct { bytes: []const u8, limit: usize }{
        .{ .bytes = request.app_name, .limit = app_name_capacity },
        .{ .bytes = request.app_icon, .limit = app_icon_capacity },
        .{ .bytes = request.summary, .limit = summary_capacity },
        .{ .bytes = request.body, .limit = body_capacity },
    };
    for (fields) |field| {
        if (field.bytes.len > field.limit) return error.FieldTooLong;
        if (!std.unicode.utf8ValidateSlice(field.bytes)) return error.InvalidUtf8;
    }
}

fn sampleRequest(summary: []const u8) Request {
    return .{
        .replaces_id = 0,
        .app_name = "app",
        .app_icon = "",
        .summary = summary,
        .body = "body",
        .expire_timeout = -1,
    };
}

test "new replacement unknown replacement and close preserve identity" {
    var store: Store = .{};
    defer store.deinit(std.testing.allocator);

    const first = try store.notify(std.testing.allocator, sampleRequest("first"));
    try std.testing.expectEqual(@as(u32, 1), first);
    try std.testing.expectEqual(@as(usize, 1), store.count);

    var replacement = sampleRequest("replacement");
    replacement.replaces_id = first;
    try std.testing.expectEqual(first, try store.notify(std.testing.allocator, replacement));
    try std.testing.expectEqual(@as(usize, 1), store.count);
    try std.testing.expectEqualStrings("replacement", store.get(first).?.summary);

    var stale = sampleRequest("stale");
    stale.replaces_id = 99;
    const second = try store.notify(std.testing.allocator, stale);
    try std.testing.expectEqual(@as(u32, 2), second);
    try std.testing.expectEqual(@as(usize, 2), store.count);

    try store.close(std.testing.allocator, first);
    try std.testing.expect(store.get(first) == null);
    try std.testing.expectError(error.UnknownNotification, store.close(std.testing.allocator, first));
}

test "ids wrap without producing zero or colliding" {
    var store: Store = .{ .last_id = std.math.maxInt(u32) - 1 };
    defer store.deinit(std.testing.allocator);

    try std.testing.expectEqual(std.math.maxInt(u32), try store.notify(std.testing.allocator, sampleRequest("max")));
    try std.testing.expectEqual(@as(u32, 1), try store.notify(std.testing.allocator, sampleRequest("one")));
}

test "bounds and invalid UTF-8 change no state" {
    var store: Store = .{};
    defer store.deinit(std.testing.allocator);

    const first = try store.notify(std.testing.allocator, sampleRequest("first"));
    var too_long: [summary_capacity + 1]u8 = @splat('x');
    var invalid = sampleRequest(&too_long);
    invalid.replaces_id = first;
    try std.testing.expectError(error.FieldTooLong, store.notify(std.testing.allocator, invalid));
    try std.testing.expectEqualStrings("first", store.get(first).?.summary);

    invalid.summary = &.{0xff};
    try std.testing.expectError(error.InvalidUtf8, store.notify(std.testing.allocator, invalid));
    try std.testing.expectEqualStrings("first", store.get(first).?.summary);
    try std.testing.expectEqual(@as(u32, 1), store.last_id);
}

test "exact field bounds are accepted" {
    var app_name: [app_name_capacity]u8 = @splat('a');
    var app_icon: [app_icon_capacity]u8 = @splat('i');
    var summary: [summary_capacity]u8 = @splat('s');
    var body: [body_capacity]u8 = @splat('b');
    var store: Store = .{};
    defer store.deinit(std.testing.allocator);

    const id = try store.notify(std.testing.allocator, .{
        .replaces_id = 0,
        .app_name = &app_name,
        .app_icon = &app_icon,
        .summary = &summary,
        .body = &body,
        .expire_timeout = 0,
    });
    try std.testing.expectEqual(app_name_capacity, store.get(id).?.app_name.len);
    try std.testing.expectEqual(app_icon_capacity, store.get(id).?.app_icon.len);
    try std.testing.expectEqual(summary_capacity, store.get(id).?.summary.len);
    try std.testing.expectEqual(body_capacity, store.get(id).?.body.len);
}

test "full store rejects new records but permits replacement" {
    var store: Store = .{};
    defer store.deinit(std.testing.allocator);

    for (0..capacity) |index| {
        try std.testing.expectEqual(
            @as(u32, @intCast(index + 1)),
            try store.notify(std.testing.allocator, sampleRequest("full")),
        );
    }
    try std.testing.expectError(
        error.RecordsFull,
        store.notify(std.testing.allocator, sampleRequest("overflow")),
    );

    var replacement = sampleRequest("replacement");
    replacement.replaces_id = 1;
    try std.testing.expectEqual(@as(u32, 1), try store.notify(std.testing.allocator, replacement));
    try std.testing.expectEqual(@as(usize, capacity), store.count);
    try std.testing.expectEqualStrings("replacement", store.get(1).?.summary);
}

test "replacement allocation failure is atomic and leak free" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailureTest, .{});
}

fn allocationFailureTest(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit(allocator);

    const first = try store.notify(allocator, sampleRequest("first"));
    var replacement = sampleRequest("replacement");
    replacement.replaces_id = first;
    const result = store.notify(allocator, replacement) catch |err| {
        try std.testing.expectEqualStrings("first", store.get(first).?.summary);
        try std.testing.expectEqual(@as(usize, 1), store.count);
        try std.testing.expectEqual(@as(u32, 1), store.last_id);
        return err;
    };
    try std.testing.expectEqual(first, result);
    try std.testing.expectEqualStrings("replacement", store.get(first).?.summary);
}

test "generated notification histories remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzHistory, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzHistory({}, &empty);
}

fn fuzzHistory(_: void, smith: *std.testing.Smith) !void {
    var store: Store = .{};
    defer store.deinit(std.testing.allocator);

    var bytes: [128]u8 = undefined;
    for (0..capacity * 2) |_| {
        if (smith.eosWeightedSimple(1, 7)) break;
        if (smith.value(bool)) {
            const text = bytes[0..smith.slice(&bytes)];
            _ = store.notify(std.testing.allocator, .{
                .replaces_id = smith.value(u32),
                .app_name = text,
                .app_icon = "",
                .summary = text,
                .body = text,
                .expire_timeout = smith.value(i32),
            }) catch |err| switch (err) {
                error.InvalidUtf8, error.RecordsFull => {},
                else => return err,
            };
        } else {
            store.close(std.testing.allocator, smith.value(u32)) catch |err| switch (err) {
                error.UnknownNotification => {},
            };
        }
        store.assertValid();
    }
}
