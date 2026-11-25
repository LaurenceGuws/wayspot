// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The presentation module against the fake compositor: formats, the buffer
//! pool's states, resizing, damage and scale, and frame pacing.

const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const protocol = @import("protocol");
const present = @import("present");
const wl = @import("wayland-protocols").wl;
const fake = @import("fake.zig");

const Fd = protocol.Fd;

/// The objects every test starts with, in the order their ids are given
/// out: the registry is 2, `wl_shm` 3, `wl_compositor` 4, the surface 5.
const Setup = struct {
    p: fake.Pair,
    wl_shm: wl.Shm,
    surface: wl.Surface,
    shm: *present.Shm,
    pool: *present.BufferPool,
    presenter: *present.Presenter,

    fn init(s: *Setup, compositor_version: u32) !void {
        s.p = try .init();
        const session = &s.p.conn.session;
        const registry = try (wl.Display{ .id = .display }).getRegistry(session);
        s.wl_shm = try registry.bind(session, 1, wl.Shm, 1);
        const compositor = try registry.bind(session, 2, wl.Compositor, compositor_version);
        s.surface = try compositor.createSurface(session);
        s.shm = try .create(testing.allocator, &s.p.conn, s.wl_shm);
        s.pool = try .create(testing.allocator, &s.p.conn, s.shm, .{});
        s.presenter = try .create(testing.allocator, &s.p.conn, s.surface);
        try s.p.conn.flush();
        try s.p.drain();
    }

    fn deinit(s: *Setup) void {
        s.presenter.destroy();
        s.pool.destroy();
        s.shm.destroy();
        s.p.deinit();
    }

    /// The requests sent since the last call, and only those to `object`.
    fn requestsTo(s: *Setup, object: protocol.ObjectId, out: *std.ArrayList(fake.Request)) ![]const fake.Request {
        const all = try s.p.requests(null);
        for (all) |r| {
            if (r.object == object) try out.append(testing.allocator, .{
                .object = r.object,
                .opcode = r.opcode,
                .words = try testing.allocator.dupe(u32, r.words),
            });
        }
        fake.freeRequests(all);
        return out.items;
    }

    fn release(s: *Setup, buffer: *present.Buffer) !void {
        try s.p.send(buffer.wl_buffer.id, &wl.Buffer.interface, 0, &.{}, &.{});
    }

    fn frameDone(s: *Setup, time: u32) !void {
        try s.p.send(s.presenter.frame.?.id, &wl.Callback.interface, 0, &.{.{ .uint = time }}, &.{});
    }
};

fn freeList(list: *std.ArrayList(fake.Request)) void {
    for (list.items) |r| testing.allocator.free(r.words);
    list.deinit(testing.allocator);
}

test "formats are collected from wl_shm" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    try testing.expect(s.shm.supports(.argb8888));
    try testing.expect(s.shm.supports(.xrgb8888));
    try testing.expect(!s.shm.supports(.abgr8888));

    for ([_]u32{ 0, 1, present.Format.abgr8888.toShm(), 1 }) |f| {
        try s.p.send(s.wl_shm.id, &wl.Shm.interface, 0, &.{.{ .uint = f }}, &.{});
    }
    while (s.shm.formats.items.len < 3) _ = try s.p.conn.dispatch();
    try testing.expectEqualSlices(present.Format, &.{ .argb8888, .xrgb8888, .abgr8888 }, s.shm.formats.items);
    try testing.expect(s.shm.supports(.abgr8888));

    try testing.expectError(error.UnsupportedFormat, s.pool.acquire(8, 8, .rgb565));
    try testing.expectError(error.UnsupportedFormat, s.pool.acquire(8, 8, @fromBackingInt(present.fourcc("NV12"))));
    try testing.expectError(error.InvalidSize, s.pool.acquire(0, 8, .xrgb8888));
}

test "the pixels drawn are the pixels the compositor maps" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    const buffer = (try s.pool.acquire(64, 32, .xrgb8888)).?;
    try testing.expectEqual(@as(u32, 256), buffer.stride);
    try testing.expectEqual(@as(usize, 256 * 32), buffer.pixels().len);
    @memset(buffer.pixels(), 0xab);

    var fds: std.ArrayList(Fd) = .empty;
    defer fds.deinit(testing.allocator);
    const sent = try s.p.requests(&fds);
    defer fake.freeRequests(sent);
    try testing.expectEqual(@as(usize, 1), fds.items.len);
    defer _ = linux.close(fds.items[0]);

    // create_pool on wl_shm: new id, then the size; then create_buffer on
    // the pool with the shape and the wl_shm code for xrgb8888, which is 1.
    try testing.expectEqual(s.wl_shm.id, sent[0].object);
    try testing.expectEqual(@as(u32, 256 * 32), sent[0].words[1]);
    try testing.expectEqualSlices(u32, &.{ 0, 64, 32, 256, 1 }, sent[1].words[1..]);

    const mapped = linux.mmap(null, 256 * 32, .{ .READ = true }, .{ .TYPE = .SHARED }, fds.items[0], 0);
    try testing.expectEqual(std.posix.E.SUCCESS, std.posix.errno(mapped));
    const seen: [*]const u8 = @ptrFromInt(mapped);
    defer _ = linux.munmap(seen, 256 * 32);
    try testing.expectEqual(@as(u8, 0xab), seen[0]);
    try testing.expectEqual(@as(u8, 0xab), seen[256 * 32 - 1]);
}

test "a buffer the compositor holds is never handed out" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    const a = (try s.pool.acquire(16, 16, .xrgb8888)).?;
    try s.presenter.present(a, .{});
    try testing.expectEqual(present.Buffer.State.busy, a.state);
    try testing.expect(!s.presenter.ready());

    const b = (try s.pool.acquire(16, 16, .xrgb8888)).?;
    try testing.expect(b != a);
    try s.presenter.present(b, .{});
    // Both busy, so a third.
    const c = (try s.pool.acquire(16, 16, .xrgb8888)).?;
    try testing.expect(c != a and c != b);
    // And no fourth.
    try testing.expectEqual(@as(?*present.Buffer, null), try s.pool.acquire(16, 16, .xrgb8888));
    try testing.expectEqual(@as(usize, 3), s.pool.count());

    try s.release(a);
    while (a.state != .free) _ = try s.p.conn.dispatch();
    try testing.expectEqual(a, (try s.pool.acquire(16, 16, .xrgb8888)).?);

    // Given back unpresented, it is free again at once.
    s.pool.cancel(c);
    try testing.expectEqual(c, (try s.pool.acquire(16, 16, .xrgb8888)).?);
}

test "a resize retires the old shape once the compositor lets go" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    const a = (try s.pool.acquire(16, 16, .xrgb8888)).?;
    try s.presenter.present(a, .{});
    const b = (try s.pool.acquire(16, 16, .xrgb8888)).?;
    s.pool.cancel(b);
    const b_id = b.wl_buffer.id;
    const a_id = a.wl_buffer.id;
    try s.p.drain();

    // b was free and goes at once; a is on screen and waits.
    const c = (try s.pool.acquire(32, 8, .xrgb8888)).?;
    try testing.expectEqual(@as(u32, 32), c.width);
    try testing.expect(a.stale);
    try testing.expectEqual(@as(usize, 2), s.pool.count());

    var sent: std.ArrayList(fake.Request) = .empty;
    defer freeList(&sent);
    try testing.expectEqual(@as(usize, 1), (try s.requestsTo(b_id, &sent)).len);
    try testing.expectEqual(@as(u16, 0), sent.items[0].opcode);

    try s.release(a);
    while (s.pool.count() > 1) _ = try s.p.conn.dispatch();
    try s.p.conn.flush();
    for (sent.items) |r| testing.allocator.free(r.words);
    sent.clearRetainingCapacity();
    const destroyed = try s.requestsTo(a_id, &sent);
    try testing.expectEqual(@as(usize, 1), destroyed.len);
    try testing.expectEqual(@as(u16, 0), destroyed[0].opcode);
}

test "damage and scale reach the surface" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    const a = (try s.pool.acquire(40, 20, .xrgb8888)).?;
    try s.p.drain();
    try s.presenter.present(a, .{
        .scale = 2,
        .damage = &.{ .{ .x = 1, .y = 2, .width = 3, .height = 4 }, .{ .x = 10, .y = 0, .width = 5, .height = 5 } },
    });

    var sent: std.ArrayList(fake.Request) = .empty;
    defer freeList(&sent);
    const r = try s.requestsTo(s.surface.id, &sent);
    // frame, attach, set_buffer_scale, damage_buffer twice, commit.
    try testing.expectEqual(@as(usize, 6), r.len);
    for (r, [_]u16{ 3, 1, 8, 9, 9, 6 }) |req, opcode| try testing.expectEqual(opcode, req.opcode);
    try testing.expectEqualSlices(u32, &.{ @backingInt(a.wl_buffer.id), 0, 0 }, r[1].words);
    try testing.expectEqualSlices(u32, &.{2}, r[2].words);
    try testing.expectEqualSlices(u32, &.{ 1, 2, 3, 4 }, r[3].words);
    try testing.expectEqualSlices(u32, &.{ 10, 0, 5, 5 }, r[4].words);
    try testing.expectEqual(@as(i32, 2), s.presenter.scale);

    // The same scale again is not sent again, and no damage is the whole
    // buffer.
    try s.frameDone(1);
    try s.release(a);
    while (!s.presenter.ready() or a.state != .free) _ = try s.p.conn.dispatch();
    try s.p.drain();
    try s.presenter.present((try s.pool.acquire(40, 20, .xrgb8888)).?, .{ .scale = 2 });
    for (sent.items) |req| testing.allocator.free(req.words);
    sent.clearRetainingCapacity();
    const again = try s.requestsTo(s.surface.id, &sent);
    for (again, [_]u16{ 3, 1, 9, 6 }) |req, opcode| try testing.expectEqual(opcode, req.opcode);
    try testing.expectEqualSlices(u32, &.{ 0, 0, 40, 20 }, again[2].words);
}

test "before version 4, damage is in surface coordinates" {
    var s: Setup = undefined;
    try s.init(3);
    defer s.deinit();

    const a = (try s.pool.acquire(40, 20, .xrgb8888)).?;
    try s.p.drain();
    try s.presenter.present(a, .{ .scale = 2, .damage = &.{.{ .x = 1, .y = 1, .width = 3, .height = 3 }} });

    var sent: std.ArrayList(fake.Request) = .empty;
    defer freeList(&sent);
    const r = try s.requestsTo(s.surface.id, &sent);
    for (r, [_]u16{ 3, 1, 8, 2, 6 }) |req, opcode| try testing.expectEqual(opcode, req.opcode);
    // Buffer pixels 1..4 at scale 2 cover surface pixels 0..2.
    try testing.expectEqualSlices(u32, &.{ 0, 0, 2, 2 }, r[3].words);
}

test "frame callbacks pace the presenter" {
    var s: Setup = undefined;
    try s.init(6);
    defer s.deinit();

    const Seen = struct {
        time: ?u32 = null,
        fn onFrame(context: ?*anyopaque, time: u32) void {
            const seen: *@This() = @ptrCast(@alignCast(context.?));
            seen.time = time;
        }
    };
    var seen: Seen = .{};
    s.presenter.on_frame = .{ .context = &seen, .call = Seen.onFrame };

    try testing.expect(s.presenter.ready());
    try s.presenter.present((try s.pool.acquire(8, 8, .xrgb8888)).?, .{});
    try testing.expect(!s.presenter.ready());
    const first = s.presenter.frame.?;

    // Presenting again before the answer asks for no second callback.
    try s.presenter.present((try s.pool.acquire(8, 8, .xrgb8888)).?, .{});
    try testing.expectEqual(first, s.presenter.frame.?);

    try s.frameDone(4242);
    while (!s.presenter.ready()) _ = try s.p.conn.dispatch();
    try testing.expectEqual(@as(?u32, 4242), seen.time);
    try testing.expectEqual(@as(?u32, 4242), s.presenter.last_frame_time);
}
