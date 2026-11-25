// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! dma-buf presentation against the fake compositor: feedback, the version 3
//! fallback, buffers built from someone else's memory with
//! `zwp_linux_buffer_params_v1`, and explicit sync.

const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const endian = @import("builtin").cpu.arch.endian();
const protocol = @import("protocol");
const present = @import("present");
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const wp = protocols.wp;
const zwp = protocols.zwp;
const fake = @import("fake.zig");

const Fd = protocol.Fd;
const Format = present.Format;
const tiled: u64 = 0x0100_0000_0000_0001;

/// A memfd holding a format table, as a compositor sends one.
fn formatTable(entries: []const present.Feedback.FormatModifier) !Fd {
    const fd: Fd = @intCast(linux.memfd_create("format-table", linux.MFD.CLOEXEC));
    var bytes: [16 * 8]u8 = @splat(0);
    for (entries, 0..) |e, i| {
        std.mem.writeInt(u32, bytes[i * 16 ..][0..4], @backingInt(e.format), endian);
        std.mem.writeInt(u64, bytes[i * 16 + 8 ..][0..8], e.modifier, endian);
    }
    try testing.expectEqual(entries.len * 16, linux.write(fd, &bytes, entries.len * 16));
    return fd;
}

fn devT(value: u64) [8]u8 {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, endian);
    return bytes;
}

fn indices(comptime list: []const u16) [list.len * 2]u8 {
    var bytes: [list.len * 2]u8 = undefined;
    for (list, 0..) |i, n| std.mem.writeInt(u16, bytes[n * 2 ..][0..2], i, endian);
    return bytes;
}

const Fb = zwp.LinuxDmabufFeedbackV1;

/// Sends a whole feedback batch: optionally a table, then tranches.
fn sendBatch(p: *fake.Pair, feedback: Fb, table: ?[]const present.Feedback.FormatModifier, tranches: []const struct { device: u64, scanout: bool, indices: []const u8 }) !void {
    if (table) |t| {
        const fd = try formatTable(t);
        defer _ = linux.close(fd);
        try p.send(feedback.id, &Fb.interface, 1, &.{ .{ .fd = 0 }, .{ .uint = @intCast(t.len * 16) } }, &.{fd});
        const main = devT(0xe280);
        try p.send(feedback.id, &Fb.interface, 2, &.{.{ .array = &main }}, &.{});
    }
    for (tranches) |t| {
        const device = devT(t.device);
        try p.send(feedback.id, &Fb.interface, 4, &.{.{ .array = &device }}, &.{});
        try p.send(feedback.id, &Fb.interface, 6, &.{.{ .uint = @intFromBool(t.scanout) }}, &.{});
        try p.send(feedback.id, &Fb.interface, 5, &.{.{ .array = t.indices }}, &.{});
        try p.send(feedback.id, &Fb.interface, 3, &.{}, &.{});
    }
    try p.send(feedback.id, &Fb.interface, 0, &.{}, &.{});
}

/// Registry 2, linux-dmabuf 3, compositor 4, surface 5, the syncobj manager
/// 6; then, at version 4, the default feedback is 7.
const Setup = struct {
    p: fake.Pair,
    object: zwp.LinuxDmabufV1,
    surface: wl.Surface,
    manager: wp.LinuxDrmSyncobjManagerV1,
    dmabuf: *present.Dmabuf,

    fn init(s: *Setup, version: u32) !void {
        s.p = try .init();
        const session = &s.p.conn.session;
        const registry = try (wl.Display{ .id = .display }).getRegistry(session);
        s.object = try registry.bind(session, 1, zwp.LinuxDmabufV1, version);
        const compositor = try registry.bind(session, 2, wl.Compositor, 6);
        s.surface = try compositor.createSurface(session);
        s.manager = try registry.bind(session, 3, wp.LinuxDrmSyncobjManagerV1, 1);
        s.dmabuf = try .create(testing.allocator, &s.p.conn, s.object);
        try s.p.conn.flush();
        try s.p.drain();
    }

    fn deinit(s: *Setup) void {
        s.dmabuf.destroy();
        s.p.deinit();
    }

    /// The usual table: XR24 tiled and linear in a scanout tranche, AR24
    /// linear in the next.
    fn standardFeedback(s: *Setup) !void {
        try sendBatch(&s.p, s.dmabuf.default.object.?, &.{
            .{ .format = .xrgb8888, .modifier = present.modifier.linear },
            .{ .format = .xrgb8888, .modifier = tiled },
            .{ .format = .argb8888, .modifier = present.modifier.linear },
            .{ .format = .abgr8888, .modifier = present.modifier.invalid },
        }, &.{
            .{ .device = 0xe280, .scanout = true, .indices = &indices(&.{1}) },
            // 99 is past the end of the table, and is dropped.
            .{ .device = 0xe281, .scanout = false, .indices = &indices(&.{ 0, 2, 99 }) },
        });
        while (s.dmabuf.default.generation == 0) _ = try s.p.conn.dispatch();
    }
};

test "the default feedback is read, and replaced whole by the next batch" {
    var s: Setup = undefined;
    try s.init(4);
    defer s.deinit();

    const Seen = struct {
        count: usize = 0,
        fn onChange(context: ?*anyopaque, _: *present.Feedback) void {
            const seen: *@This() = @ptrCast(@alignCast(context.?));
            seen.count += 1;
        }
    };
    var seen: Seen = .{};
    s.dmabuf.default.on_change = .{ .context = &seen, .call = Seen.onChange };

    try s.standardFeedback();
    const f = s.dmabuf.feedback();
    try testing.expectEqual(@as(?u64, 0xe280), s.dmabuf.mainDevice());
    try testing.expectEqual(@as(usize, 2), f.tranches.items.len);
    try testing.expectEqual(@as(?u64, 0xe280), f.tranches.items[0].target_device);
    try testing.expect(f.tranches.items[0].scanout);
    try testing.expect(!f.tranches.items[1].scanout);
    try testing.expectEqual(@as(usize, 2), f.tranches.items[1].pairs.len);

    // Tranche order is preference order.
    const xr = try s.dmabuf.modifiers(testing.allocator, .xrgb8888);
    defer testing.allocator.free(xr);
    try testing.expectEqualSlices(u64, &.{ tiled, present.modifier.linear }, xr);
    try testing.expect(s.dmabuf.supports(.argb8888));
    try testing.expect(!s.dmabuf.supports(.abgr8888));
    try testing.expect(f.changed);
    try testing.expectEqual(@as(usize, 1), seen.count);

    // A later batch may leave the table out, and the old one still holds.
    f.changed = false;
    try sendBatch(&s.p, f.object.?, null, &.{.{ .device = 0xe281, .scanout = false, .indices = &indices(&.{3}) }});
    while (f.generation < 2) _ = try s.p.conn.dispatch();
    try testing.expect(f.changed);
    try testing.expectEqual(@as(usize, 2), seen.count);
    try testing.expect(!s.dmabuf.supports(.xrgb8888));
    const ab = try s.dmabuf.modifiers(testing.allocator, .abgr8888);
    defer testing.allocator.free(ab);
    try testing.expectEqualSlices(u64, &.{present.modifier.invalid}, ab);
}

test "a version 3 compositor's modifier events, and no main device" {
    var s: Setup = undefined;
    try s.init(3);
    defer s.deinit();
    try testing.expect(s.dmabuf.default.object == null);

    const I = zwp.LinuxDmabufV1.interface;
    // The deprecated format event is ignored from version 3 on.
    try s.p.send(s.object.id, &I, 0, &.{.{ .uint = @backingInt(Format.abgr8888) }}, &.{});
    try s.p.send(s.object.id, &I, 1, &.{ .{ .uint = @backingInt(Format.xrgb8888) }, .{ .uint = 0x0100_0000 }, .{ .uint = 1 } }, &.{});
    try s.p.send(s.object.id, &I, 1, &.{ .{ .uint = @backingInt(Format.xrgb8888) }, .{ .uint = 0 }, .{ .uint = 0 } }, &.{});
    while (!s.dmabuf.supports(.xrgb8888) or (try countModifiers(s.dmabuf, .xrgb8888)) < 2) _ = try s.p.conn.dispatch();

    try testing.expectEqual(@as(?u64, null), s.dmabuf.mainDevice());
    const xr = try s.dmabuf.modifiers(testing.allocator, .xrgb8888);
    defer testing.allocator.free(xr);
    try testing.expectEqualSlices(u64, &.{ tiled, present.modifier.linear }, xr);
    try testing.expect(!s.dmabuf.supports(.abgr8888));
    try testing.expectError(error.UnsupportedVersion, s.dmabuf.surfaceFeedback(s.surface));
}

fn countModifiers(d: *present.Dmabuf, format: Format) !usize {
    const list = try d.modifiers(testing.allocator, format);
    defer testing.allocator.free(list);
    return list.len;
}

/// An allocator standing in for a GPU: it hands out two planes backed by
/// memfds it owns, picks the first modifier it is offered, and counts frees.
const FakeGpu = struct {
    fds: [2]Fd,
    offered: std.ArrayList(u64) = .empty,
    allocated: usize = 0,
    freed: usize = 0,
    refuse: bool = false,

    fn init() FakeGpu {
        return .{ .fds = .{
            @intCast(linux.memfd_create("plane0", linux.MFD.CLOEXEC)),
            @intCast(linux.memfd_create("plane1", linux.MFD.CLOEXEC)),
        } };
    }

    fn deinit(g: *FakeGpu) void {
        for (g.fds) |fd| _ = linux.close(fd);
        g.offered.deinit(testing.allocator);
    }

    fn allocator(g: *FakeGpu) present.Dmabuf.BufferAllocator {
        return .{ .context = g, .allocate = allocate, .free = free };
    }

    fn allocate(context: ?*anyopaque, width: u32, height: u32, format: Format, modifiers: []const u64) anyerror!present.Dmabuf.Allocation {
        _ = height;
        _ = format;
        const g: *FakeGpu = @ptrCast(@alignCast(context.?));
        if (g.refuse) return error.OutOfDeviceMemory;
        g.offered.clearRetainingCapacity();
        try g.offered.appendSlice(testing.allocator, modifiers);
        g.allocated += 1;
        return .{
            .handle = @ptrFromInt(0x1000 + g.allocated),
            .modifier = modifiers[0],
            .planes = .{
                .{ .fd = g.fds[0], .offset = 0, .stride = width * 4 },
                .{ .fd = g.fds[1], .offset = 4096, .stride = 64 },
                undefined,
                undefined,
            },
            .plane_count = 2,
        };
    }

    fn free(context: ?*anyopaque, handle: ?*anyopaque) void {
        const g: *FakeGpu = @ptrCast(@alignCast(context.?));
        std.debug.assert(handle != null);
        g.freed += 1;
    }
};

/// The id the next client object will get, which is what a params object
/// about to be created will be.
fn nextId(s: *Setup) !protocol.ObjectId {
    const probe = try s.p.conn.session.newId(&wl.Callback.interface, 1);
    s.p.conn.session.forget(probe);
    return probe;
}

test "a dma-buf becomes a wl_buffer through the params object" {
    var s: Setup = undefined;
    try s.init(4);
    defer s.deinit();
    try s.standardFeedback();
    try s.p.drain();

    var gpu: FakeGpu = .init();
    defer gpu.deinit();
    const pool: *present.BufferPool = try .createDmabuf(testing.allocator, &s.p.conn, s.dmabuf, gpu.allocator(), .{});
    defer pool.destroy();

    // The compositor's answer is written before it is asked for; it waits
    // in the socket.
    const params = try nextId(&s);
    const new_buffer: protocol.ObjectId = @fromBackingInt(protocol.ObjectId.server_start);
    try s.p.send(params, &zwp.LinuxBufferParamsV1.interface, 0, &.{.{ .new_id = new_buffer }}, &.{});

    const buffer = (try pool.acquire(64, 32, .xrgb8888)).?;
    try testing.expectEqual(new_buffer, buffer.wl_buffer.id);
    try testing.expectEqual(@as(?[]u8, null), buffer.mapped());
    try testing.expectEqual(@as(u32, 256), buffer.stride);
    try testing.expectEqual(tiled, buffer.storage.dmabuf.modifier);
    try testing.expectEqualSlices(u64, &.{ tiled, present.modifier.linear }, gpu.offered.items);

    var fds: std.ArrayList(Fd) = .empty;
    defer {
        for (fds.items) |fd| _ = linux.close(fd);
        fds.deinit(testing.allocator);
    }
    // The params object's destroy is queued behind the answer, and goes with
    // whatever is sent next.
    try s.p.conn.flush();
    const sent = try s.p.requests(&fds);
    defer fake.freeRequests(sent);
    try testing.expectEqual(@as(usize, 2), fds.items.len);

    // create_params, add each plane in order with the modifier split high
    // then low, create, and the params object destroyed once answered.
    try testing.expectEqual(s.object.id, sent[0].object);
    try testing.expectEqual(@as(u16, 1), sent[0].opcode);
    try testing.expectEqualSlices(u32, &.{@backingInt(params)}, sent[0].words);
    try testing.expectEqual(params, sent[1].object);
    try testing.expectEqualSlices(u32, &.{ 0, 0, 256, 0x0100_0000, 1 }, sent[1].words);
    try testing.expectEqualSlices(u32, &.{ 1, 4096, 64, 0x0100_0000, 1 }, sent[2].words);
    try testing.expectEqual(@as(u16, 2), sent[3].opcode);
    try testing.expectEqualSlices(u32, &.{ 64, 32, @backingInt(Format.xrgb8888), 0 }, sent[3].words);
    try testing.expectEqual(params, sent[4].object);
    try testing.expectEqual(@as(u16, 0), sent[4].opcode);

    // Released like any other buffer, and retired through the allocator.
    const presenter: *present.Presenter = try .create(testing.allocator, &s.p.conn, s.surface);
    defer presenter.destroy();
    try presenter.present(buffer, .{});
    try s.p.send(new_buffer, &wl.Buffer.interface, 0, &.{}, &.{});
    while (buffer.state != .free) _ = try s.p.conn.dispatch();

    fake.freeRequests(try s.p.requests(null));
    const next_params = try nextId(&s);
    try s.p.send(next_params, &zwp.LinuxBufferParamsV1.interface, 0, &.{.{ .new_id = @fromBackingInt(protocol.ObjectId.server_start + 1) }}, &.{});
    _ = (try pool.acquire(128, 32, .xrgb8888)).?;
    try testing.expectEqual(@as(usize, 1), gpu.freed);
    try testing.expectEqual(@as(usize, 1), pool.count());
}

test "a refused dma-buf is an error to fall back from, and its memory is freed" {
    var s: Setup = undefined;
    try s.init(4);
    defer s.deinit();
    try s.standardFeedback();

    var gpu: FakeGpu = .init();
    defer gpu.deinit();
    const pool: *present.BufferPool = try .createDmabuf(testing.allocator, &s.p.conn, s.dmabuf, gpu.allocator(), .{});
    defer pool.destroy();

    try s.p.send(try nextId(&s), &zwp.LinuxBufferParamsV1.interface, 1, &.{}, &.{});
    try testing.expectError(error.BufferCreationFailed, pool.acquire(64, 32, .xrgb8888));
    try testing.expectEqual(@as(usize, 1), gpu.freed);
    try testing.expectEqual(@as(usize, 0), pool.count());

    gpu.refuse = true;
    try testing.expectError(error.AllocationFailed, pool.acquire(64, 32, .xrgb8888));
    try testing.expectEqual(@as(?anyerror, error.OutOfDeviceMemory), pool.allocator_error);

    // A format the compositor never offered never reaches the allocator.
    try testing.expectError(error.UnsupportedFormat, pool.acquire(64, 32, .rgb565));
}

test "explicit sync: both points on every commit, dma-bufs only, released by hand" {
    var s: Setup = undefined;
    try s.init(4);
    defer s.deinit();
    try s.standardFeedback();

    var gpu: FakeGpu = .init();
    defer gpu.deinit();
    const pool: *present.BufferPool = try .createDmabuf(testing.allocator, &s.p.conn, s.dmabuf, gpu.allocator(), .{});
    defer pool.destroy();
    const presenter: *present.Presenter = try .create(testing.allocator, &s.p.conn, s.surface);
    defer presenter.destroy();

    const new_buffer: protocol.ObjectId = @fromBackingInt(protocol.ObjectId.server_start);
    try s.p.send(try nextId(&s), &zwp.LinuxBufferParamsV1.interface, 0, &.{.{ .new_id = new_buffer }}, &.{});
    const buffer = (try pool.acquire(16, 16, .xrgb8888)).?;

    const syncobj: present.Syncobj = .init(&s.p.conn, s.manager);
    const timeline_fd: Fd = @intCast(linux.memfd_create("timeline", linux.MFD.CLOEXEC));
    defer _ = linux.close(timeline_fd);
    const timeline = try syncobj.importTimeline(timeline_fd);
    const points: present.Syncobj.Points = .{
        .acquire = .{ .timeline = timeline, .value = 0x1_0000_0002 },
        .release = .{ .timeline = timeline, .value = 0x1_0000_0003 },
    };

    // Not yet on.
    try testing.expectError(error.ExplicitSyncNotEnabled, presenter.present(buffer, .{ .sync = points }));

    try presenter.enableExplicitSync(syncobj);
    fake.freeRequests(try s.p.requests(null));
    try testing.expectError(error.SyncPointsRequired, presenter.present(buffer, .{}));
    try testing.expectError(error.ConflictingSyncPoints, presenter.present(buffer, .{ .sync = .{
        .acquire = .{ .timeline = timeline, .value = 7 },
        .release = .{ .timeline = timeline, .value = 7 },
    } }));
    // None of that sent anything.
    const nothing = try s.p.requests(null);
    defer fake.freeRequests(nothing);
    try testing.expectEqual(@as(usize, 0), nothing.len);

    try presenter.present(buffer, .{ .sync = points });
    const sent = try s.p.requests(null);
    defer fake.freeRequests(sent);
    const sync_surface = presenter.sync_surface.?;
    var saw_acquire = false;
    var saw_release = false;
    for (sent) |r| {
        if (r.object == sync_surface.id and r.opcode == 1) {
            try testing.expectEqualSlices(u32, &.{ @backingInt(timeline.object.id), 1, 2 }, r.words);
            saw_acquire = true;
        } else if (r.object == sync_surface.id and r.opcode == 2) {
            try testing.expectEqualSlices(u32, &.{ @backingInt(timeline.object.id), 1, 3 }, r.words);
            saw_release = true;
        } else if (r.object == s.surface.id and r.opcode == 6) {
            // The points come before the commit they belong to.
            try testing.expect(saw_acquire and saw_release);
        }
    }
    try testing.expect(saw_acquire and saw_release);

    // wl_buffer.release means nothing now; `released` is what frees it.
    try s.p.send(new_buffer, &wl.Buffer.interface, 0, &.{}, &.{});
    _ = try s.p.conn.dispatch();
    try testing.expectEqual(present.Buffer.State.busy, buffer.state);
    pool.released(buffer);
    try testing.expectEqual(present.Buffer.State.free, buffer.state);

    // And a buffer in shared memory is refused under explicit sync.
    const shm: *present.Shm = try .create(testing.allocator, &s.p.conn, try (try (wl.Display{ .id = .display }).getRegistry(&s.p.conn.session)).bind(&s.p.conn.session, 9, wl.Shm, 1));
    defer shm.destroy();
    const shm_pool: *present.BufferPool = try .create(testing.allocator, &s.p.conn, shm, .{});
    defer shm_pool.destroy();
    const shm_buffer = (try shm_pool.acquire(16, 16, .xrgb8888)).?;
    try testing.expectError(error.SyncRequiresDmabuf, presenter.present(shm_buffer, .{ .sync = points }));
    shm_pool.cancel(shm_buffer);
}

test "the surface feedback is its own object" {
    var s: Setup = undefined;
    try s.init(4);
    defer s.deinit();
    const f = try s.dmabuf.surfaceFeedback(s.surface);
    defer f.destroy();
    try testing.expect(f.object.?.id != s.dmabuf.default.object.?.id);
    try sendBatch(&s.p, f.object.?, &.{.{ .format = .xrgb8888, .modifier = present.modifier.linear }}, &.{
        .{ .device = 0xe280, .scanout = true, .indices = &indices(&.{0}) },
    });
    while (f.generation == 0) _ = try s.p.conn.dispatch();
    try testing.expect(f.tranches.items[0].scanout);
    try testing.expect(!s.dmabuf.supports(.xrgb8888));
}
