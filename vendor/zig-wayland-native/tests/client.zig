// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The client over a real socket, with the test playing the compositor at
//! the other end of a socketpair.
//!
//! Nothing here needs a second thread: a socket buffers in both directions,
//! and object ids are allocated deterministically, so the test can write the
//! compositor's replies before the client asks for them, and read the
//! client's requests after it has sent them.

const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const protocol = @import("protocol");
const Connection = @import("client").Connection;
const wl = @import("wayland-protocols").wl;

const Fd = protocol.Fd;
const Pair = @import("fake.zig").Pair;

const Globals = struct {
    names: std.ArrayList([]u8) = .empty,
    removed: u32 = 0,

    fn deinit(g: *Globals) void {
        for (g.names.items) |n| testing.allocator.free(n);
        g.names.deinit(testing.allocator);
    }

    fn onEvent(g: *Globals, _: *Connection, _: wl.Registry, event: wl.Registry.Event) !void {
        switch (event) {
            .global => |global| try g.names.append(testing.allocator, try testing.allocator.dupe(u8, global.interface)),
            .global_remove => |r| g.removed = r.name,
        }
    }
};

test "a round trip delivers the globals" {
    var p: Pair = try .init();
    defer p.deinit();

    const display: wl.Display = .{ .id = .display };
    const registry = try display.getRegistry(&p.conn.session);
    var globals: Globals = .{};
    defer globals.deinit();
    try p.conn.setListener(registry, &globals, Globals.onEvent);

    // The registry is 2, so the round trip's callback will be 3.
    try p.send(registry.id, &wl.Registry.interface, 0, &.{ .{ .uint = 1 }, .{ .string = "wl_compositor" }, .{ .uint = 6 } }, &.{});
    try p.send(registry.id, &wl.Registry.interface, 0, &.{ .{ .uint = 2 }, .{ .string = "wl_shm" }, .{ .uint = 2 } }, &.{});
    try p.send(registry.id, &wl.Registry.interface, 1, &.{.{ .uint = 1 }}, &.{});
    try p.send(@fromBackingInt(3), &wl.Callback.interface, 0, &.{.{ .uint = 0 }}, &.{});
    try p.send(.display, &wl.Display.interface, 1, &.{.{ .uint = 3 }}, &.{});
    try p.conn.roundtrip();

    try testing.expectEqual(@as(usize, 2), globals.names.items.len);
    try testing.expectEqualStrings("wl_compositor", globals.names.items[0]);
    try testing.expectEqualStrings("wl_shm", globals.names.items[1]);
    try testing.expectEqual(@as(u32, 1), globals.removed);

    // What the compositor received: get_registry, then sync.
    var bytes: [24]u8 = undefined;
    var fds: std.ArrayList(Fd) = .empty;
    defer fds.deinit(testing.allocator);
    try p.receive(&bytes, &fds);
    const words: [6]u32 = @bitCast(bytes);
    try testing.expectEqualSlices(u32, &.{ 1, 12 << 16 | 1, 2, 1, 12 << 16 | 0, 3 }, &words);
}

const Keymap = struct {
    contents: [16]u8 = undefined,
    len: usize = 0,
    size: u32 = 0,

    fn onEvent(k: *Keymap, _: *Connection, _: wl.Keyboard, event: wl.Keyboard.Event) void {
        switch (event) {
            .keymap => |keymap| {
                defer _ = linux.close(keymap.fd);
                k.size = keymap.size;
                k.len = linux.read(keymap.fd, &k.contents, k.contents.len);
            },
            else => {},
        }
    }
};

test "a file descriptor from the compositor reaches the listener" {
    var p: Pair = try .init();
    defer p.deinit();

    const registry = try (wl.Display{ .id = .display }).getRegistry(&p.conn.session);
    const seat = try registry.bind(&p.conn.session, 1, wl.Seat, 7);
    const keyboard = try seat.getKeyboard(&p.conn.session);
    var keymap: Keymap = .{};
    try p.conn.setListener(keyboard, &keymap, Keymap.onEvent);
    try p.conn.flush();

    var pipe: [2]i32 = undefined;
    try testing.expectEqual(@as(usize, 0), linux.pipe2(&pipe, .{ .CLOEXEC = true }));
    try testing.expectEqual(@as(usize, 6), linux.write(pipe[1], "keymap", 6));
    _ = linux.close(pipe[1]);
    try p.send(keyboard.id, &wl.Keyboard.interface, 0, &.{ .{ .uint = @backingInt(wl.Keyboard.KeymapFormat.xkb_v1) }, .{ .fd = 0 }, .{ .uint = 6 } }, &.{pipe[0]});
    // The client has its own copy now.
    _ = linux.close(pipe[0]);

    while (keymap.size == 0) _ = try p.conn.dispatch();
    try testing.expectEqual(@as(u32, 6), keymap.size);
    try testing.expectEqualStrings("keymap", keymap.contents[0..keymap.len]);
}

test "a file descriptor from the client reaches the compositor" {
    var p: Pair = try .init();
    defer p.deinit();

    const registry = try (wl.Display{ .id = .display }).getRegistry(&p.conn.session);
    const shm = try registry.bind(&p.conn.session, 1, wl.Shm, 1);
    try p.conn.flush();
    try p.drain();

    var pipe: [2]i32 = undefined;
    try testing.expectEqual(@as(usize, 0), linux.pipe2(&pipe, .{ .CLOEXEC = true }));
    defer _ = linux.close(pipe[0]);
    _ = try shm.createPool(&p.conn.session, pipe[1], 4096);
    try p.conn.flush();
    // Sent, so the client's copy may go.
    _ = linux.close(pipe[1]);

    var bytes: [16]u8 = undefined;
    var fds: std.ArrayList(Fd) = .empty;
    defer fds.deinit(testing.allocator);
    try p.receive(&bytes, &fds);
    try testing.expectEqual(@as(usize, 1), fds.items.len);
    defer _ = linux.close(fds.items[0]);

    // It is the same pipe: what goes in one end comes out of the other.
    try testing.expectEqual(@as(usize, 2), linux.write(fds.items[0], "ok", 2));
    var out: [2]u8 = undefined;
    try testing.expectEqual(@as(usize, 2), linux.read(pipe[0], &out, 2));
    try testing.expectEqualStrings("ok", &out);
}

test "more descriptors than one sendmsg carries are all delivered" {
    var p: Pair = try .init();
    defer p.deinit();
    const registry = try (wl.Display{ .id = .display }).getRegistry(&p.conn.session);
    const shm = try registry.bind(&p.conn.session, 1, wl.Shm, 1);
    try p.conn.flush();
    try p.drain();

    var pipe: [2]i32 = undefined;
    try testing.expectEqual(@as(usize, 0), linux.pipe2(&pipe, .{ .CLOEXEC = true }));
    defer _ = linux.close(pipe[0]);
    defer _ = linux.close(pipe[1]);
    const count = protocol.wire.max_fds_out + 12;
    for (0..count) |_| _ = try shm.createPool(&p.conn.session, pipe[1], 4096);
    try p.conn.flush();

    var bytes: [16 * count]u8 = undefined;
    var fds: std.ArrayList(Fd) = .empty;
    defer fds.deinit(testing.allocator);
    try p.receive(&bytes, &fds);
    defer for (fds.items) |fd| {
        _ = linux.close(fd);
    };
    try testing.expectEqual(@as(usize, count), fds.items.len);
}

test "a protocol error comes out of dispatch" {
    var p: Pair = try .init();
    defer p.deinit();
    const registry = try (wl.Display{ .id = .display }).getRegistry(&p.conn.session);
    const compositor = try registry.bind(&p.conn.session, 1, wl.Compositor, 6);
    try p.send(.display, &wl.Display.interface, 0, &.{ .{ .object = compositor.id }, .{ .uint = 0 }, .{ .string = "no" } }, &.{});

    try testing.expectError(error.ProtocolError, p.conn.dispatch());
    const e = p.conn.session.protocol_error.?;
    try testing.expectEqual(compositor.id, e.object);
    try testing.expectEqualStrings("wl_compositor", e.interface.?.name);
    try testing.expectEqualStrings("no", e.message);
}

test "the compositor going away is an error, not a hang" {
    var p: Pair = try .init();
    defer p.deinit();
    _ = linux.close(p.server);
    p.server = -1;
    try testing.expectError(error.ConnectionClosed, p.conn.dispatch());
}

test "connecting finds the socket the environment names" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir = try std.fmt.allocPrint(testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer testing.allocator.free(runtime_dir);
    const socket_path = try std.fs.path.join(testing.allocator, &.{ runtime_dir, "wayland-test" });
    defer testing.allocator.free(socket_path);

    const address = try std.Io.net.UnixAddress.init(socket_path);
    var server = try address.listen(testing.io, .{});
    defer server.deinit(testing.io);

    var environ: std.process.Environ.Map = .init(testing.allocator);
    defer environ.deinit();
    try environ.put("XDG_RUNTIME_DIR", runtime_dir);
    try environ.put("WAYLAND_DISPLAY", "wayland-test");

    var conn: Connection = try .connect(testing.allocator, testing.io, &environ);
    defer conn.deinit();
    const accepted = try server.accept(testing.io);
    defer accepted.close(testing.io);

    try environ.put("WAYLAND_DISPLAY", "wayland-missing");
    try testing.expectError(error.FileNotFound, Connection.connect(testing.allocator, testing.io, &environ));

    var bare: std.process.Environ.Map = .init(testing.allocator);
    defer bare.deinit();
    try testing.expectError(error.NoRuntimeDir, Connection.connect(testing.allocator, testing.io, &bare));

    try bare.put("WAYLAND_SOCKET", "not a number");
    try testing.expectError(error.InvalidWaylandSocket, Connection.connect(testing.allocator, testing.io, &bare));
}
