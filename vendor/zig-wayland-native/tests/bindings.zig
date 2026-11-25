// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The generated bindings for the core protocol and xdg-shell, driven
//! through a `protocol.Session` with no socket anywhere: requests are checked
//! as the bytes they become, and events are made from bytes a test writes.

const std = @import("std");
const testing = std.testing;
const protocol = @import("protocol");
const wl = @import("wayland-protocols").wl;
const xdg = @import("wayland-protocols").xdg;

const Session = protocol.Session;
const wire = protocol.wire;

/// The session's hand-written interfaces are the same as the ones generated
/// from `wayland.xml`.
fn expectSameInterface(want: *const protocol.Interface, got: *const protocol.Interface) !void {
    try testing.expectEqualStrings(want.name, got.name);
    try testing.expectEqual(want.version, got.version);
    for ([_][2][]const protocol.Interface.Signature{
        .{ want.requests, got.requests },
        .{ want.events, got.events },
    }) |pair| {
        try testing.expectEqual(pair[0].len, pair[1].len);
        for (pair[0], pair[1]) |a, b| {
            try testing.expectEqualStrings(a.name, b.name);
            try testing.expectEqual(a.since, b.since);
            try testing.expectEqual(a.destructor, b.destructor);
            try testing.expectEqual(a.args.len, b.args.len);
            for (a.args, b.args) |x, y| {
                try testing.expectEqual(x.kind, y.kind);
                try testing.expectEqual(x.nullable, y.nullable);
                try testing.expectEqual(x.interface == null, y.interface == null);
                if (x.interface) |i| try testing.expectEqualStrings(i.name, y.interface.?.name);
            }
        }
    }
}

test "the session's own interfaces match wayland.xml" {
    try expectSameInterface(&protocol.core.display, &wl.Display.interface);
    try expectSameInterface(&protocol.core.callback, &wl.Callback.interface);
    try expectSameInterface(&protocol.core.registry, &wl.Registry.interface);
}

fn words(bytes: []const u8) []align(1) const u32 {
    return std.mem.bytesAsSlice(u32, bytes);
}

fn expectWords(expected: []const u32, bytes: []const u8) !void {
    try testing.expectEqual(expected.len * 4, bytes.len);
    for (expected, words(bytes)) |want, got| try testing.expectEqual(want, got);
}

/// Encodes an event as a compositor would send it.
fn event(buf: []u8, object: protocol.ObjectId, interface: *const protocol.Interface, opcode: u16, args: []const protocol.Arg) ![]u8 {
    const size = try wire.encodedSize(interface.events[opcode].args, args);
    wire.encode(buf[0..size], object, opcode, args);
    return buf[0..size];
}

test "binding a global" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();

    const display: wl.Display = .{ .id = .display };
    const registry = try display.getRegistry(&s);
    const compositor = try registry.bind(&s, 7, wl.Compositor, 5);
    try testing.expectEqual(@as(?u32, 5), s.versionOf(compositor.id));

    const sent = s.pending().bytes;
    // get_registry: object 1, opcode 1, new id 2.
    try expectWords(&.{ 1, 12 << 16 | 1, 2 }, sent[0..12]);
    // bind: object 2, opcode 0, name 7, "wl_compositor" (14 with its NUL,
    // padded to 16), version 5, new id 3.
    const bind = sent[12..];
    try testing.expectEqual(@as(usize, 40), bind.len);
    try expectWords(&.{ 2, 40 << 16 | 0, 7, 14 }, bind[0..16]);
    try testing.expectEqualStrings("wl_compositor\x00\x00\x00", bind[16..32]);
    try expectWords(&.{ 5, 3 }, bind[32..40]);

    // A version newer than these bindings know is refused.
    try testing.expectError(error.UnsupportedVersion, registry.bind(&s, 8, wl.Compositor, 99));
}

test "a child takes its parent's version" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const registry = try (wl.Display{ .id = .display }).getRegistry(&s);
    const compositor = try registry.bind(&s, 1, wl.Compositor, 4);
    const surface = try compositor.createSurface(&s);
    try testing.expectEqual(@as(?u32, 4), s.versionOf(surface.id));

    // set_buffer_scale is version 3, offset is version 5.
    try surface.setBufferScale(&s, 2);
    try testing.expectError(error.UnsupportedVersion, surface.offset(&s, 1, 1));
}

test "events come out typed" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    var buf: [128]u8 = undefined;
    const registry = try (wl.Display{ .id = .display }).getRegistry(&s);
    const shm = try registry.bind(&s, 1, wl.Shm, 1);
    const seat = try registry.bind(&s, 2, wl.Seat, 7);

    try s.feed(try event(&buf, registry.id, &wl.Registry.interface, 0, &.{
        .{ .uint = 9 }, .{ .string = "wl_output" }, .{ .uint = 4 },
    }));
    try s.feed(try event(&buf, shm.id, &wl.Shm.interface, 0, &.{.{ .uint = @backingInt(wl.Shm.Format.xrgb8888) }}));
    try s.feed(try event(&buf, shm.id, &wl.Shm.interface, 0, &.{.{ .uint = 0x3432_5258 }}));
    try s.feed(try event(&buf, seat.id, &wl.Seat.interface, 0, &.{.{ .uint = 0b101 }}));

    const global = try wl.Registry.Event.decode((try s.nextEvent()).?);
    try testing.expectEqual(@as(u32, 9), global.global.name);
    try testing.expectEqualStrings("wl_output", global.global.interface);
    try testing.expectEqual(@as(u32, 4), global.global.version);

    const format = try wl.Shm.Event.decode((try s.nextEvent()).?);
    try testing.expectEqual(wl.Shm.Format.xrgb8888, format.format.format);
    // The enums are open: a format these bindings have never heard of is
    // still a format, not a crash.
    const other = try wl.Shm.Event.decode((try s.nextEvent()).?);
    try testing.expectEqual(@as(u32, 0x3432_5258), @backingInt(other.format.format));

    const caps = (try wl.Seat.Event.decode((try s.nextEvent()).?)).capabilities.capabilities;
    try testing.expect(caps.pointer and !caps.keyboard and caps.touch);
}

test "requests with enums, bitfields, objects and file descriptors" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const registry = try (wl.Display{ .id = .display }).getRegistry(&s);
    const shm = try registry.bind(&s, 1, wl.Shm, 1);
    const wm_base = try registry.bind(&s, 2, xdg.WmBase, 6);
    const compositor = try registry.bind(&s, 3, wl.Compositor, 6);
    s.consumed(s.pending().bytes.len, 0);

    const pool = try shm.createPool(&s, 42, 4096);
    var batch = s.pending();
    try testing.expectEqualSlices(protocol.Fd, &.{42}, batch.fds);
    // The descriptor is not in the bytes: new id, then size.
    try expectWords(&.{ @backingInt(shm.id), 16 << 16 | 0, @backingInt(pool.id), 4096 }, batch.bytes);
    s.consumed(batch.bytes.len, batch.fds.len);

    const buffer = try pool.createBuffer(&s, 0, 16, 16, 64, .argb8888);
    const surface = try compositor.createSurface(&s);
    try surface.attach(&s, buffer, 0, 0);
    try surface.attach(&s, null, 0, 0);
    const xdg_surface = try wm_base.getXdgSurface(&s, surface);
    const toplevel = try xdg_surface.getToplevel(&s);
    try toplevel.setTitle(&s, "hello");
    try toplevel.resize(&s, .{ .id = @fromBackingInt(9) }, 1, .bottom_right);
    batch = s.pending();

    var offset: usize = 0;
    const create_buffer = words(batch.bytes[offset..][0..32]);
    try testing.expectEqual(@backingInt(wl.Shm.Format.argb8888), create_buffer[7]);
    offset += 32 + 12;
    const attach = words(batch.bytes[offset..][0..20]);
    try testing.expectEqual(@backingInt(buffer.id), attach[2]);
    offset += 20;
    const detach = words(batch.bytes[offset..][0..20]);
    try testing.expectEqual(@as(u32, 0), detach[2]);
    offset += 20 + 16 + 12;
    const title = batch.bytes[offset..][0..20];
    try expectWords(&.{ @backingInt(toplevel.id), 20 << 16 | 2, 6 }, title[0..12]);
    try testing.expectEqualStrings("hello\x00\x00\x00", title[12..20]);
    offset += 20;
    try expectWords(&.{ 9, 1, @backingInt(xdg.Toplevel.ResizeEdge.bottom_right) }, batch.bytes[offset + 8 ..][0..12]);
    try testing.expectEqual(batch.bytes.len, offset + 20);
}

test "xdg-shell's handshake" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    var buf: [128]u8 = undefined;
    const registry = try (wl.Display{ .id = .display }).getRegistry(&s);
    const wm_base = try registry.bind(&s, 1, xdg.WmBase, 6);
    const compositor = try registry.bind(&s, 2, wl.Compositor, 6);
    const xdg_surface = try wm_base.getXdgSurface(&s, try compositor.createSurface(&s));
    const toplevel = try xdg_surface.getToplevel(&s);
    s.consumed(s.pending().bytes.len, 0);

    try s.feed(try event(&buf, wm_base.id, &xdg.WmBase.interface, 0, &.{.{ .uint = 77 }}));
    var states: [2]u32 = .{ @backingInt(xdg.Toplevel.State.maximized), @backingInt(xdg.Toplevel.State.activated) };
    try s.feed(try event(&buf, toplevel.id, &xdg.Toplevel.interface, 0, &.{
        .{ .int = 800 }, .{ .int = 600 }, .{ .array = std.mem.sliceAsBytes(&states) },
    }));
    try s.feed(try event(&buf, xdg_surface.id, &xdg.Surface.interface, 0, &.{.{ .uint = 5 }}));

    const ping = try xdg.WmBase.Event.decode((try s.nextEvent()).?);
    try wm_base.pong(&s, ping.ping.serial);

    const configure = (try xdg.Toplevel.Event.decode((try s.nextEvent()).?)).configure;
    try testing.expectEqual(@as(i32, 800), configure.width);
    try testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&states), configure.states);

    const surface_configure = try xdg.Surface.Event.decode((try s.nextEvent()).?);
    try xdg_surface.ackConfigure(&s, surface_configure.configure.serial);

    try expectWords(&.{
        @backingInt(wm_base.id),     12 << 16 | 3, 77,
        @backingInt(xdg_surface.id), 12 << 16 | 4, 5,
    }, s.pending().bytes);
}

test "a destroyed object's id waits for delete_id" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    var buf: [64]u8 = undefined;
    const registry = try (wl.Display{ .id = .display }).getRegistry(&s);
    const compositor = try registry.bind(&s, 1, wl.Compositor, 6);
    const region = try compositor.createRegion(&s);
    try region.destroy(&s);
    try testing.expectError(error.InvalidObject, region.add(&s, 0, 0, 1, 1));

    const next = try compositor.createRegion(&s);
    try testing.expect(next.id != region.id);

    try s.feed(try event(&buf, .display, &wl.Display.interface, 1, &.{.{ .uint = @backingInt(region.id) }}));
    try testing.expectEqual(@as(?protocol.Message, null), try s.nextEvent());
    try testing.expectEqual(region.id, (try compositor.createRegion(&s)).id);
}
