// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Which object each id names, from the client's side of the connection.
//!
//! The two ends allocate ids from separate ranges: the client from 1 up, the
//! server from `ObjectId.server_start` up. Both are dense, so each range is a
//! plain array indexed by id.
//!
//! An object the client destroys does not give its id back straight away. The
//! server may already have sent events to it, and they are still on their way,
//! so the id stays a *zombie* -- known, so those events can be recognized and
//! skipped, but dead -- until the server says with `wl_display.delete_id` that
//! it has finished with it too. Only then is it free to reuse. Server-allocated
//! ids have no such handshake and go as soon as they are destroyed.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Interface = @import("Interface.zig");
const ObjectId = @import("wire.zig").ObjectId;

const ObjectMap = @This();

/// The largest id the client may allocate.
pub const client_max: u32 = ObjectId.server_start - 1;

pub const Entry = struct {
    interface: *const Interface,
    version: u32,
    state: State = .live,
    /// Two words that belong to whoever is using the session, carried with
    /// the object and dropped with it. The `client` module keeps an object's
    /// listener here, which means a listener can never outlive its object and
    /// be called for whatever reuses the id.
    user_data: ?*anyopaque = null,
    user_fn: ?*const anyopaque = null,

    pub const State = enum { live, zombie };
};

/// Indexed by id; slot 0 is the null object and is never used.
client: std.ArrayList(?Entry) = .empty,
/// Indexed by id minus `ObjectId.server_start`.
server: std.ArrayList(?Entry) = .empty,
/// Client ids given back by `delete_id`, reused last in, first out as
/// libwayland does.
free: std.ArrayList(u32) = .empty,

pub fn deinit(map: *ObjectMap, gpa: Allocator) void {
    map.client.deinit(gpa);
    map.server.deinit(gpa);
    map.free.deinit(gpa);
    map.* = undefined;
}

pub const AllocError = Allocator.Error || error{OutOfIds};

/// A new client id for `entry`.
pub fn allocate(map: *ObjectMap, gpa: Allocator, entry: Entry) AllocError!ObjectId {
    if (map.free.pop()) |id| {
        map.client.items[id] = entry;
        return @fromBackingInt(id);
    }
    if (map.client.items.len == 0) try map.client.append(gpa, null);
    const id = map.client.items.len;
    if (id > client_max) return error.OutOfIds;
    try map.client.append(gpa, entry);
    return @fromBackingInt(@as(u32, @intCast(id)));
}

/// Puts `entry` at a specific client id. Only `wl_display` needs this, since
/// it is the one object both ends agree on without anything being sent.
pub fn insertClient(map: *ObjectMap, gpa: Allocator, id: ObjectId, entry: Entry) Allocator.Error!void {
    const index = @backingInt(id);
    std.debug.assert(index != 0 and !id.isServer());
    if (index >= map.client.items.len) try map.client.appendNTimes(gpa, null, index + 1 - map.client.items.len);
    map.client.items[index] = entry;
}

pub const InsertServerError = Allocator.Error || error{InvalidNewId};

/// Records an object the server has just created.
///
/// The server allocates densely, so a new id is either one it is reusing or
/// the next one past the end. Anything else is refused: an id near the top
/// of the range would otherwise have this side allocate sixteen million
/// empty slots on the server's say-so.
pub fn insertServer(map: *ObjectMap, gpa: Allocator, id: ObjectId, entry: Entry) InsertServerError!void {
    if (!id.isServer()) return error.InvalidNewId;
    const index = @backingInt(id) - ObjectId.server_start;
    if (index < map.server.items.len) {
        if (map.server.items[index] != null) return error.InvalidNewId;
        map.server.items[index] = entry;
    } else if (index == map.server.items.len) {
        try map.server.append(gpa, entry);
    } else return error.InvalidNewId;
}

/// The object at `id`, live or zombie.
pub fn get(map: *const ObjectMap, id: ObjectId) ?*Entry {
    const s = map.slot(id) orelse return null;
    return if (s.*) |*entry| entry else null;
}

/// The object at `id` if it is live.
pub fn getLive(map: *const ObjectMap, id: ObjectId) ?*Entry {
    const entry = map.get(id) orelse return null;
    return if (entry.state == .live) entry else null;
}

/// The object has been destroyed. A client id becomes a zombie until the
/// server's `delete_id`; a server id goes at once.
pub fn destroy(map: *ObjectMap, id: ObjectId) void {
    if (id.isServer()) {
        if (map.slot(id)) |s| s.* = null;
        return;
    }
    const entry = map.get(id) orelse return;
    entry.state = .zombie;
    entry.user_data = null;
    entry.user_fn = null;
}

/// The server's `delete_id`: the id is free to reuse. An id that is not in
/// use is ignored, so a confused server cannot put one on the free list twice.
pub fn release(map: *ObjectMap, gpa: Allocator, id: ObjectId) Allocator.Error!void {
    if (id == .null or id == .display or id.isServer()) return;
    const s = map.slot(id) orelse return;
    if (s.* == null) return;
    try map.free.append(gpa, @backingInt(id));
    s.* = null;
}

fn slot(map: *const ObjectMap, id: ObjectId) ?*?Entry {
    const raw = @backingInt(id);
    const list, const index = if (id.isServer())
        .{ &map.server, raw - ObjectId.server_start }
    else
        .{ &map.client, raw };
    if (index >= list.items.len) return null;
    return &list.items[index];
}

const testing = std.testing;
const dummy: Interface = .{ .name = "dummy", .version = 1, .requests = &.{}, .events = &.{} };

test "client ids count up from 1 and come back only after delete_id" {
    var map: ObjectMap = .{};
    defer map.deinit(testing.allocator);
    try map.insertClient(testing.allocator, .display, .{ .interface = &dummy, .version = 1 });

    const a = try map.allocate(testing.allocator, .{ .interface = &dummy, .version = 1 });
    const b = try map.allocate(testing.allocator, .{ .interface = &dummy, .version = 1 });
    try testing.expectEqual(@as(u32, 2), @backingInt(a));
    try testing.expectEqual(@as(u32, 3), @backingInt(b));

    map.destroy(a);
    try testing.expect(map.get(a) != null);
    try testing.expect(map.getLive(a) == null);
    try testing.expectEqual(@as(u32, 4), @backingInt(try map.allocate(testing.allocator, .{ .interface = &dummy, .version = 1 })));

    try map.release(testing.allocator, a);
    try map.release(testing.allocator, a);
    try testing.expect(map.get(a) == null);
    try testing.expectEqual(a, try map.allocate(testing.allocator, .{ .interface = &dummy, .version = 1 }));
    try testing.expectEqual(@as(u32, 5), @backingInt(try map.allocate(testing.allocator, .{ .interface = &dummy, .version = 1 })));
}

test "server ids must be dense" {
    var map: ObjectMap = .{};
    defer map.deinit(testing.allocator);
    const first: ObjectId = @fromBackingInt(ObjectId.server_start);
    const second: ObjectId = @fromBackingInt(ObjectId.server_start + 1);
    const far: ObjectId = @fromBackingInt(0xffff_ffff);

    try testing.expectError(error.InvalidNewId, map.insertServer(testing.allocator, second, .{ .interface = &dummy, .version = 1 }));
    try testing.expectError(error.InvalidNewId, map.insertServer(testing.allocator, far, .{ .interface = &dummy, .version = 1 }));
    try testing.expectError(error.InvalidNewId, map.insertServer(testing.allocator, @fromBackingInt(5), .{ .interface = &dummy, .version = 1 }));
    try map.insertServer(testing.allocator, first, .{ .interface = &dummy, .version = 1 });
    try testing.expectError(error.InvalidNewId, map.insertServer(testing.allocator, first, .{ .interface = &dummy, .version = 1 }));
    try map.insertServer(testing.allocator, second, .{ .interface = &dummy, .version = 1 });

    map.destroy(first);
    try testing.expect(map.get(first) == null);
    try map.insertServer(testing.allocator, first, .{ .interface = &dummy, .version = 1 });
}

test "unknown ids are simply absent" {
    var map: ObjectMap = .{};
    defer map.deinit(testing.allocator);
    try testing.expect(map.get(.null) == null);
    try testing.expect(map.get(@fromBackingInt(1234)) == null);
    try testing.expect(map.get(@fromBackingInt(0xffff_fff0)) == null);
    map.destroy(@fromBackingInt(1234));
    try map.release(testing.allocator, @fromBackingInt(1234));
}
