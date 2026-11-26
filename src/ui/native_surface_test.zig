//! Deterministic native-surface proof. The other end of a real Unix socket
//! acts as the compositor; all production requests, callbacks, memfd buffers
//! and buffer release transitions run through the pinned native Wayland code.
const std = @import("std");
const linux = std.os.linux;
const testing = std.testing;
const native = @import("native_surface.zig");
const Connection = @import("wayland-client").Connection;
const wire = @import("wayland-wire");
const wl = @import("wayland-protocols").wl;
const zwlr = @import("wayland-protocols").zwlr;
const wp = @import("wayland-protocols").wp;
const present = @import("wayland-present");
const sdl = @import("sdl_c");
const Painter = @import("text.zig").Painter;
const Input = native.Input;
const zwp = @import("wayland-protocols").zwp;
const xkb = @import("xkb_c");

const endian = @import("builtin").cpu.arch.endian();
const size = native.Extent{ .width = 64, .height = 32 };

const Requests = struct {
    bytes: [16384]u8 = undefined,
    len: usize = 0,

    fn count(self: *const Requests, object: wire.ObjectId, opcode: u16) usize {
        var found: usize = 0;
        var at: usize = 0;
        while (at < self.len) {
            const h = wire.wire.Header.decode(self.bytes[at..][0..8]);
            std.debug.assert(h.size >= 8 and at + h.size <= self.len);
            if (h.object == object and h.opcode == opcode) found += 1;
            at += h.size;
        }
        return found;
    }

    fn word(self: *const Requests, object: wire.ObjectId, opcode: u16, index: usize) !u32 {
        var at: usize = 0;
        while (at < self.len) {
            const h = wire.wire.Header.decode(self.bytes[at..][0..8]);
            std.debug.assert(h.size >= 8 and at + h.size <= self.len);
            if (h.object == object and h.opcode == opcode) {
                if (h.size < 12 + index * 4) return error.MissingWord;
                return std.mem.readInt(u32, self.bytes[at + 8 + index * 4 ..][0..4], endian);
            }
            at += h.size;
        }
        return error.MissingRequest;
    }

    fn firstWord(self: *const Requests, object: wire.ObjectId, opcode: u16) !u32 {
        return self.word(object, opcode, 0);
    }
};

const Fixture = struct {
    display: *native.Display,
    server: i32,
    registry: wire.ObjectId,

    const Options = struct {
        compositor_version: u32 = 4,
        fractional: bool = false,
        viewport: bool = false,
        outputs: u8 = 0,
    };

    fn open() !Fixture {
        return openWith(.{});
    }

    fn openWith(options: Options) !Fixture {
        var fds: [2]i32 = undefined;
        try testing.expectEqual(@as(usize, 0), linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0, &fds));
        errdefer _ = linux.close(fds[1]);
        const conn = Connection.fromFd(testing.allocator, testing.io, fds[0]) catch |err| {
            _ = linux.close(fds[0]);
            return err;
        };
        var self: Fixture = .{ .display = try native.Display.adopt(testing.allocator, conn), .server = fds[1], .registry = undefined };
        errdefer self.display.destroy();
        try testing.expectEqual(native.Display.Status.discovering, self.display.status());
        const initial = try self.take();
        self.registry = @fromBackingInt(try initial.firstWord(.display, 1));
        const callback: wire.ObjectId = @fromBackingInt(try initial.firstWord(.display, 0));
        for ([_][:0]const u8{ "wl_compositor", "wl_shm", "zwlr_layer_shell_v1" }, [_]u32{ options.compositor_version, 1, 1 }, 1..) |name, version, id| {
            try self.global(@intCast(id), name, version);
        }
        if (options.viewport) try self.global(4, "wp_viewporter", 1);
        if (options.fractional) try self.global(5, "wp_fractional_scale_manager_v1", 1);
        for (0..options.outputs) |i| try self.global(@intCast(6 + i), "wl_output", 4);
        try self.done(callback);
        try testing.expectEqual(native.Display.Status.ready, self.display.status());
        _ = try self.take();
        return self;
    }

    fn global(self: *Fixture, id: u32, name: [:0]const u8, version: u32) !void {
        try self.event(self.registry, &wl.Registry.interface, 0, &.{ .{ .uint = id }, .{ .string = name }, .{ .uint = version } });
    }

    fn scale(self: *Fixture, surface: *native.Surface, numerator: u32) !void {
        try self.event(surface.fractional.?.id, &wp.FractionalScaleV1.interface, 0, &.{.{ .uint = numerator }});
    }

    fn outputScale(self: *Fixture, output: wl.Output, factor: i32) !void {
        try self.event(output.id, &wl.Output.interface, 3, &.{.{ .int = factor }});
    }

    fn outputDone(self: *Fixture, output: wl.Output) !void {
        try self.event(output.id, &wl.Output.interface, 2, &.{});
    }

    fn enter(self: *Fixture, surface: *native.Surface, output: wl.Output) !void {
        try self.event(surface.surface.?.id, &wl.Surface.interface, 0, &.{.{ .object = output.id }});
    }

    fn close(self: *Fixture) void {
        self.display.destroy();
        if (self.server >= 0) _ = linux.close(self.server);
    }

    fn event(self: *Fixture, object: wire.ObjectId, interface: *const wire.Interface, opcode: u16, args: []const wire.Arg) !void {
        try self.eventFd(object, interface, opcode, args, null);
    }

    fn eventFd(self: *Fixture, object: wire.ObjectId, interface: *const wire.Interface, opcode: u16, args: []const wire.Arg, fd: ?i32) !void {
        var bytes: [wire.wire.max_message_size]u8 = undefined;
        const len = try wire.wire.encodedSize(interface.events[opcode].args, args);
        wire.wire.encode(bytes[0..len], object, opcode, args);
        if (fd) |file| {
            var control: [32]u8 align(@alignOf(linux.cmsghdr)) = @splat(0);
            const header: *linux.cmsghdr = @ptrCast(&control);
            header.* = .{ .len = @sizeOf(linux.cmsghdr) + @sizeOf(i32), .level = linux.SOL.SOCKET, .type = linux.SCM.RIGHTS };
            @memcpy(control[@sizeOf(linux.cmsghdr)..][0..@sizeOf(i32)], std.mem.asBytes(&file));
            const iov = [_]std.posix.iovec_const{.{ .base = &bytes, .len = len }};
            const msg: linux.msghdr_const = .{ .name = null, .namelen = 0, .iov = &iov, .iovlen = 1, .control = &control, .controllen = std.mem.alignForward(usize, header.len, @sizeOf(usize)), .flags = 0 };
            try testing.expectEqual(len, linux.sendmsg(self.server, &msg, linux.MSG.NOSIGNAL));
        } else try testing.expectEqual(len, linux.sendto(self.server, &bytes, len, linux.MSG.NOSIGNAL, null, 0));
        // This is a local socketpair, not an unbounded compositor wait.
        var poll = [_]linux.pollfd{.{ .fd = self.display.fd(), .events = linux.POLL.IN, .revents = 0 }};
        try testing.expectEqual(@as(usize, 1), linux.poll(&poll, 1, 1000));
        try self.display.readReady();
    }

    fn done(self: *Fixture, id: wire.ObjectId) !void {
        try self.event(id, &wl.Callback.interface, 0, &.{.{ .uint = 1 }});
        try self.event(.display, &wl.Display.interface, 1, &.{.{ .uint = @backingInt(id) }});
    }

    fn configure(self: *Fixture, surface: *native.Surface, serial: u32, extent: native.Extent) !void {
        try self.event(surface.layer.?.id, &zwlr.LayerSurfaceV1.interface, 0, &.{ .{ .uint = serial }, .{ .uint = extent.width }, .{ .uint = extent.height } });
        const requests = try self.take();
        try testing.expectEqual(serial, try requests.firstWord(surface.layer.?.id, 6));
    }

    fn frame(self: *Fixture, surface: *native.Surface) !void {
        try self.done(surface.presenter.?.frame.?.id);
    }

    fn release(self: *Fixture, id: wire.ObjectId) !void {
        try self.event(id, &wl.Buffer.interface, 0, &.{});
    }

    fn take(self: *Fixture) !Requests {
        // This end only needs the requests, not the received memfds. With
        // recvfrom the kernel discards ancillary descriptors, so none leak.
        var requests: Requests = .{};
        while (requests.len < requests.bytes.len) {
            const n = linux.recvfrom(self.server, requests.bytes[requests.len..].ptr, requests.bytes.len - requests.len, linux.MSG.DONTWAIT, null, null);
            switch (linux.errno(n)) {
                .SUCCESS => {
                    if (n == 0) return error.FixtureDisconnected;
                    requests.len += n;
                },
                .AGAIN => return requests,
                .INTR => continue,
                else => return error.FixtureRead,
            }
        }
        return error.FixtureRequestLimit;
    }
};

const Paint = struct {
    calls: usize = 0,
    byte: u8 = 0x12,
    fail: bool = false,
    last_scale: u32 = 0,
    last_logical: native.Extent = undefined,
    last_pixels: native.Extent = undefined,

    fn draw(self: *Paint, frame: native.Frame) !void {
        self.calls += 1;
        self.last_scale = frame.scale_120;
        self.last_logical = frame.logical_extent;
        self.last_pixels = frame.extent;
        try testing.expectEqual(@as(usize, frame.stride) * frame.extent.height, frame.pixels.len);
        if (self.fail) return error.PaintRefused;
        @memset(frame.pixels, self.byte);
    }
};

fn submitted(f: *Fixture, surface: *native.Surface, paint: *Paint) !*present.Buffer {
    try testing.expectEqual(native.Draw.presented, try surface.draw(paint, Paint.draw));
    const requests = try f.take();
    const id = try requests.firstWord(surface.surface.?.id, 1);
    try testing.expectEqual(@as(usize, 1), requests.count(surface.surface.?.id, 6));
    try testing.expectEqual(surface.extent.?, paint.last_logical);
    try testing.expectEqual(surface.scale_120, paint.last_scale);
    try testing.expectEqual(try surface.extent.?.scaled(surface.scale_120), paint.last_pixels);
    if (surface.viewport) |viewport| {
        try testing.expectEqual(surface.extent.?.width, try requests.word(viewport.id, 2, 0));
        try testing.expectEqual(surface.extent.?.height, try requests.word(viewport.id, 2, 1));
        try testing.expectEqual(@as(i32, 1), surface.presenter.?.scale);
        try testing.expectEqual(@as(usize, 0), requests.count(surface.surface.?.id, 8));
    } else {
        try testing.expectEqual(@as(i32, @intCast(surface.scale_120 / native.scale_unit)), surface.presenter.?.scale);
    }
    for (surface.pool.?.buffers.items) |buffer| {
        if (@backingInt(buffer.wl_buffer.id) == id) {
            try testing.expectEqual(present.Buffer.State.busy, buffer.state);
            try testing.expectEqual(paint.last_pixels.width, buffer.width);
            try testing.expectEqual(paint.last_pixels.height, buffer.height);
            return buffer;
        }
    }
    return error.MissingBuffer;
}

test "configure before pixels; frame and release are separate fences across resize" {
    var f = try Fixture.open();
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size, null);
    defer s.destroy() catch {};
    const open = try f.take();
    try testing.expectEqual(@as(usize, 1), open.count(s.surface.?.id, 6));
    try testing.expectEqual(@as(usize, 0), open.count(s.surface.?.id, 1));
    var paint: Paint = .{};
    try testing.expectEqual(native.Draw.not_configured, try s.draw(&paint, Paint.draw));
    try testing.expectEqual(@as(usize, 0), paint.calls);
    try f.configure(s, 1, .{ .width = 0, .height = 0 });
    const a = try submitted(&f, s, &paint);
    const a_id = a.wl_buffer.id;
    s.invalidate();
    s.invalidate();
    try testing.expectEqual(native.Draw.frame_pending, try s.draw(&paint, Paint.draw));
    try testing.expectEqual(@as(usize, 1), paint.calls);
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
    // A frame done says nothing about buffer release.
    try f.frame(s);
    paint.byte = 0x34;
    const b = try submitted(&f, s, &paint);
    try testing.expect(a != b);
    try testing.expectEqual(@as(u8, 0x12), a.pixels()[0]);
    try f.configure(s, 2, .{ .width = 80, .height = 40 });
    try f.frame(s);
    paint.byte = 0x56;
    const c = try submitted(&f, s, &paint);
    try testing.expectEqual(@as(usize, 3), s.pool.?.count());
    try testing.expect(a.stale and b.stale);
    try testing.expectEqual(@as(u8, 0x34), b.pixels()[0]);
    try f.frame(s);
    // The upstream bound alone permits more stale shapes. The product
    // refuses a fourth buffer even with an entirely new configure size.
    try f.configure(s, 3, .{ .width = 96, .height = 48 });
    try testing.expectEqual(native.Draw.buffers_busy, try s.draw(&paint, Paint.draw));
    try testing.expectEqual(@as(usize, 3), paint.calls);
    try testing.expectEqual(@as(usize, 3), s.pool.?.count());
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
    try f.release(a_id);
    _ = try f.take();
    try testing.expectEqual(@as(usize, 2), s.pool.?.count());
    paint.byte = 0x78;
    const d = try submitted(&f, s, &paint);
    try testing.expectEqual(@as(u32, 96), d.width);
    try testing.expectEqual(@as(usize, 3), s.pool.?.count());
    try testing.expectEqual(@as(u8, 0x56), c.pixels()[0]);
    try f.frame(s);
    try testing.expectEqual(native.Draw.clean, try s.draw(&paint, Paint.draw));
    try f.configure(s, 4, .{ .width = 96, .height = 48 });
    try testing.expectEqual(native.Draw.clean, try s.draw(&paint, Paint.draw));
}

test "aborted painting cancels the borrow without a partial attach" {
    var f = try Fixture.open();
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size, null);
    defer s.destroy() catch {};
    _ = try f.take();
    try f.configure(s, 1, size);
    var paint: Paint = .{ .fail = true };
    try testing.expectError(error.PaintRefused, s.draw(&paint, Paint.draw));
    const first = s.pool.?.buffers.items[0];
    try testing.expectEqual(present.Buffer.State.free, first.state);
    const partial = try f.take();
    try testing.expectEqual(@as(usize, 0), partial.count(s.surface.?.id, 1));
    paint.fail = false;
    try testing.expectEqual(first, try submitted(&f, s, &paint));
    try testing.expectEqual(@as(usize, 1), s.pool.?.count());
}

test "independent roles retire with late events and explicit sync on a shared display" {
    var f = try Fixture.open();
    defer f.close();
    var picker: ?*native.Surface = try native.Surface.create(f.display, .picker, size, null);
    defer if (picker) |s| s.destroy() catch {};
    try testing.expectError(error.NativeRoleAlreadyOwned, native.Surface.create(f.display, .picker, size, null));
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    try testing.expectError(error.NativeSurfaceLimit, native.Surface.create(f.display, .picker, size, null));
    _ = try f.take();
    try f.configure(picker.?, 1, size);
    try f.configure(banner, 2, size);
    var paint: Paint = .{};
    const old_buffer = (try submitted(&f, picker.?, &paint)).wl_buffer.id;
    const old_frame = picker.?.presenter.?.frame.?.id;
    const old_layer = picker.?.layer.?.id;
    _ = try submitted(&f, banner, &paint);
    const old = picker.?;
    picker = null;
    try old.destroy();
    try testing.expectEqual(@as(u8, 1), f.display.surfaces);
    try f.display.requestSync();
    const retire = try f.take();
    try testing.expectEqual(@as(usize, 1), retire.count(old_layer, 7));
    const fence_id: wire.ObjectId = @fromBackingInt(try retire.firstWord(.display, 0));
    try testing.expect(f.display.sync_pending);
    try testing.expectError(error.NativeSyncPending, f.display.requestSync());
    // These can be queued before the server processes destruction. No
    // listener may dereference the retired Surface or the retired Buffer.
    try f.release(old_buffer);
    try f.done(old_frame);
    try f.done(fence_id);
    try testing.expect(!f.display.sync_pending);
    try f.frame(banner);
    banner.invalidate();
    _ = try submitted(&f, banner, &paint);
    try f.event(banner.layer.?.id, &zwlr.LayerSurfaceV1.interface, 1, &.{});
    try testing.expectEqual(native.Draw.closed, try banner.draw(&paint, Paint.draw));
}

test "oversized configure poisons the connection before allocation" {
    var f = try Fixture.open();
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size, null);
    defer s.destroy() catch {};
    _ = try f.take();
    try testing.expectError(error.InvalidSurfaceExtent, f.event(s.layer.?.id, &zwlr.LayerSurfaceV1.interface, 0, &.{ .{ .uint = 1 }, .{ .uint = 4096 }, .{ .uint = 4096 } }));
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
    try testing.expectEqual(@as(usize, 0), s.pool.?.count());
    var paint: Paint = .{};
    try testing.expectError(error.NativeConnectionFailed, s.draw(&paint, Paint.draw));
}

test "raw send failure poisons a libc-linked connection" {
    var f = try Fixture.open();
    defer f.close();
    _ = linux.close(f.server);
    f.server = -1;
    try testing.expectError(error.ConnectionClosed, f.display.requestSync());
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
    try testing.expectError(error.NativeConnectionFailed, f.display.flush());
}

test "raw receive EOF is a connection failure, not an idle frame" {
    var f = try Fixture.open();
    defer f.close();
    _ = linux.close(f.server);
    f.server = -1;
    try testing.expectError(error.ConnectionClosed, f.display.readReady());
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
}

test "fractional scale uses exact rounded pixels and preserves independent logical extents" {
    var f = try Fixture.openWith(.{ .compositor_version = 6, .viewport = true, .fractional = true });
    defer f.close();
    const logical: native.Extent = .{ .width = 63, .height = 31 };
    const picker = try native.Surface.create(f.display, .picker, logical, null);
    defer picker.destroy() catch {};
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    _ = try f.take();
    var paint: Paint = .{};
    try f.scale(picker, 150);
    try f.scale(banner, 210);
    try testing.expectEqual(native.Draw.not_configured, try picker.draw(&paint, Paint.draw));
    try f.configure(picker, 1, logical);
    try f.configure(banner, 2, size);
    const a = try submitted(&f, picker, &paint);
    const a_id = a.wl_buffer.id;
    try testing.expectEqual(@as(u32, 79), a.width);
    try testing.expectEqual(@as(u32, 39), a.height);
    const separate = try submitted(&f, banner, &paint);
    try testing.expectEqual(@as(u32, 112), separate.width);
    try testing.expectEqual(@as(u32, 56), separate.height);
    // A later core preferred integer hint cannot override fractional scale.
    try f.event(picker.surface.?.id, &wl.Surface.interface, 2, &.{.{ .int = 2 }});
    try testing.expectEqual(@as(u32, 150), picker.scale_120);
    try f.scale(picker, 180);
    try testing.expectEqual(native.Draw.frame_pending, try picker.draw(&paint, Paint.draw));
    try f.frame(picker);
    paint.byte = 0x34;
    const b = try submitted(&f, picker, &paint);
    try testing.expectEqual(@as(u32, 95), b.width);
    try testing.expectEqual(@as(u8, 0x12), a.pixels()[0]);
    try f.scale(picker, 210);
    try f.frame(picker);
    const c = try submitted(&f, picker, &paint);
    try testing.expectEqual(@as(u32, 110), c.width);
    try testing.expectEqual(@as(usize, 3), picker.pool.?.count());
    try f.scale(picker, 240);
    try f.frame(picker);
    try testing.expectEqual(native.Draw.buffers_busy, try picker.draw(&paint, Paint.draw));
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
    try testing.expectEqual(@as(usize, 3), picker.pool.?.count());
    try f.scale(picker, 120); // coalesce another scale while all slots are held
    try f.release(a_id);
    _ = try f.take();
    const d = try submitted(&f, picker, &paint);
    try testing.expectEqual(logical.width, d.width);
    try testing.expectEqual(logical.height, d.height);
    try f.frame(picker);
    try f.scale(picker, 120);
    try testing.expectEqual(native.Draw.clean, try picker.draw(&paint, Paint.draw));
    try testing.expectEqual(@as(u32, 210), banner.scale_120);
    try testing.expectEqual(@as(u32, 112), separate.width);
}

test "integer fallback follows entered outputs atomically and core preferred scale wins" {
    var f = try Fixture.openWith(.{ .compositor_version = 6, .fractional = true, .outputs = 2 });
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size, null);
    defer s.destroy() catch {};
    // The fractional manager alone is insufficient without a viewport.
    try testing.expect(s.fractional == null and s.viewport == null);
    _ = try f.take();
    try f.configure(s, 1, size);
    const left = f.display.outputs[0].?.object;
    const right = f.display.outputs[1].?.object;
    try f.enter(s, left);
    try f.outputScale(left, 2);
    try testing.expectEqual(@as(u32, 120), s.scale_120);
    try f.outputDone(left);
    try testing.expectEqual(@as(u32, 240), s.scale_120);
    try f.outputScale(right, 3);
    try f.outputDone(right);
    try testing.expectEqual(@as(u32, 240), s.scale_120);
    try f.enter(s, right);
    try testing.expectEqual(@as(u32, 360), s.scale_120);
    var paint: Paint = .{};
    const first = try submitted(&f, s, &paint);
    try testing.expectEqual(@as(u32, 192), first.width);
    try f.event(s.surface.?.id, &wl.Surface.interface, 1, &.{.{ .object = right.id }});
    try testing.expectEqual(@as(u32, 240), s.scale_120);
    try f.frame(s);
    try f.release(first.wl_buffer.id);
    _ = try submitted(&f, s, &paint);
    // Retiring an output removes its membership and releases its object.
    try f.event(f.registry, &wl.Registry.interface, 1, &.{.{ .uint = 6 }});
    const retired = try f.take();
    try testing.expectEqual(@as(usize, 1), retired.count(left.id, 0));
    try testing.expectEqual(@as(u32, 120), s.scale_120);
    try f.global(8, "wl_output", 4);
    _ = try f.take();
    const replacement = f.display.outputs[0].?.object;
    try f.outputScale(replacement, 3);
    try f.outputDone(replacement);
    try testing.expectEqual(@as(u32, 120), s.scale_120);
    try f.enter(s, replacement);
    try testing.expectEqual(@as(u32, 360), s.scale_120);
    try f.event(s.surface.?.id, &wl.Surface.interface, 2, &.{.{ .int = 2 }});
    try testing.expectEqual(@as(u32, 240), s.scale_120);
    try f.outputScale(replacement, 4);
    try f.outputDone(replacement);
    try testing.expectEqual(@as(u32, 240), s.scale_120);
}

test "invalid fractional hints and physical extent bounds fail before allocating" {
    try testing.expectEqual(@as(u32, 2), try native.scaledPixels(1, 180));
    try testing.expectEqual(@as(u32, 1), try native.scaledPixels(1, 120));
    try testing.expectError(error.InvalidSurfaceScale, native.scaledPixels(1, 0));
    try testing.expectError(error.InvalidSurfaceScale, native.scaledPixels(1, 961));
    try testing.expectError(error.InvalidSurfaceExtent, (native.Extent{ .width = 2048, .height = 2048 }).scaled(180));
    var f = try Fixture.openWith(.{ .viewport = true, .fractional = true });
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size, null);
    defer s.destroy() catch {};
    _ = try f.take();
    try f.configure(s, 1, size);
    try testing.expectError(error.InvalidSurfaceScale, f.scale(s, 0));
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
    try testing.expectEqual(@as(usize, 0), s.pool.?.count());
}

// Self-contained XKB map, including modifiers. No host layout or locale
// participates in the socket transcript.
const input_keymap = "xkb_keymap { xkb_keycodes { minimum=8; maximum=255; <AC01>=38; <AC02>=39; <TAB>=23; <LFSH>=50; <LCTL>=37; }; xkb_types { type \"ONE_LEVEL\" { modifiers=None; level_name[Level1]=\"Any\"; }; type \"TWO_LEVEL\" { modifiers=Shift; map[Shift]=Level2; level_name[Level1]=\"Base\"; level_name[Level2]=\"Shift\"; }; }; xkb_compatibility {}; xkb_symbols { key <AC01> { type=\"TWO_LEVEL\", [ a, A ] }; key <AC02> { type=\"ONE_LEVEL\", [ dead_acute ] }; key <TAB> { type=\"ONE_LEVEL\", [ Tab ] }; key <LFSH> { type=\"ONE_LEVEL\", [ Shift_L ] }; key <LCTL> { type=\"ONE_LEVEL\", [ Control_L ] }; modifier_map Shift { <LFSH> }; modifier_map Control { <LCTL> }; }; };\x00";

fn seatEvent(f: *Fixture, seat: wl.Seat, name: [:0]const u8) !void {
    try f.event(seat.id, &wl.Seat.interface, 1, &.{.{ .string = name }});
    try f.event(seat.id, &wl.Seat.interface, 0, &.{.{ .uint = 3 }});
}

fn localInput(f: *Fixture) !void {
    try f.global(20, "wl_seat", 8);
    try seatEvent(f, f.display.input.seats[0].?.object, "seat0");
    _ = try f.take();
}

fn keymapEvent(f: *Fixture, bytes: []const u8, declared_size: u32) !void {
    const rc = linux.memfd_create("wayspot-keymap-fixture", linux.MFD.CLOEXEC);
    try testing.expectEqual(linux.E.SUCCESS, linux.errno(rc));
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    try testing.expectEqual(bytes.len, linux.write(fd, bytes.ptr, bytes.len));
    try f.eventFd(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 0, &.{ .{ .uint = 1 }, .{ .fd = fd }, .{ .uint = declared_size } }, fd);
}

fn keyboardEnter(f: *Fixture, surface: *native.Surface, held: []const u8) !void {
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 1, &.{ .{ .uint = 1 }, .{ .object = surface.surface.?.id }, .{ .array = held } });
}

fn keyEvent(f: *Fixture, code: u32, pressed: bool) !void {
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 3, &.{ .{ .uint = 2 }, .{ .uint = 10 }, .{ .uint = code }, .{ .uint = @intFromBool(pressed) } });
}

fn modifiers(f: *Fixture, mask: u32) !void {
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 4, &.{ .{ .uint = 3 }, .{ .uint = mask }, .{ .uint = 0 }, .{ .uint = 0 }, .{ .uint = 0 } });
}

fn pointerEnter(f: *Fixture, surface: *native.Surface, x: f64, y: f64) !void {
    try f.event(f.display.input.pointer.?.id, &wl.Pointer.interface, 0, &.{ .{ .uint = 1 }, .{ .object = surface.surface.?.id }, .{ .fixed = .fromDouble(x) }, .{ .fixed = .fromDouble(y) } });
}

fn buttonEvent(f: *Fixture, pressed: bool) !void {
    try f.event(f.display.input.pointer.?.id, &wl.Pointer.interface, 3, &.{ .{ .uint = 2 }, .{ .uint = 10 }, .{ .uint = 272 }, .{ .uint = @intFromBool(pressed) } });
}

fn nextInput(f: *Fixture, surface: *native.Surface, tag: std.meta.Tag(@FieldType(Input.Event, "value"))) !Input.Event {
    const event = f.display.input.pop() orelse return error.MissingInput;
    try testing.expectEqual(surface.surface.?.id, event.surface);
    try testing.expectEqual(tag, std.meta.activeTag(event.value));
    return event;
}

test "native keyboard owns seat0, inherited keys, keymap and compositor modifier facts" {
    var f = try Fixture.open();
    defer f.close();
    try f.global(19, "wl_seat", 8);
    try seatEvent(&f, f.display.input.seats[0].?.object, "agent-seat");
    try testing.expect(f.display.input.keyboard == null and f.display.input.pointer == null);
    try f.global(20, "wl_seat", 8);
    const seat = f.display.input.seats[1].?.object;
    try seatEvent(&f, seat, "seat0");
    _ = try f.take();
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 5, &.{ .{ .int = 25 }, .{ .int = 400 } });
    try testing.expectEqual(@as(i32, 25), f.display.input.repeat_rate);
    try testing.expectEqual(@as(i32, 400), f.display.input.repeat_delay);
    var held: [4]u8 = undefined;
    std.mem.writeInt(u32, &held, 30, endian);
    try keyboardEnter(&f, picker, &held);
    _ = try nextInput(&f, picker, .keyboard_enter);
    try keyEvent(&f, 30, true); // not a new press
    try keyEvent(&f, 30, false); // inherited release
    try testing.expect(f.display.input.pop() == null);
    try keyEvent(&f, 30, true);
    const a = (try nextInput(&f, picker, .key)).value.key;
    try testing.expectEqualStrings("a", a.utf8());
    try testing.expectEqual(@as(u32, 97), a.symbol);
    try testing.expect(a.pressed and a.repeatable);
    try keyEvent(&f, 30, false);
    try testing.expect(!(try nextInput(&f, picker, .key)).value.key.pressed);
    try modifiers(&f, 1); // Shift
    try keyEvent(&f, 30, true);
    const upper = (try nextInput(&f, picker, .key)).value.key;
    try testing.expectEqualStrings("A", upper.utf8());
    try testing.expect(upper.modifiers.shift);
    try keyEvent(&f, 30, false);
    _ = try nextInput(&f, picker, .key);
    try modifiers(&f, 4); // Control
    try keyEvent(&f, 30, true);
    const ctrl = (try nextInput(&f, picker, .key)).value.key;
    try testing.expect(ctrl.modifiers.control and ctrl.text_len == 0);
    try keyEvent(&f, 30, false);
    _ = try nextInput(&f, picker, .key);
    try modifiers(&f, 0);
    try keyEvent(&f, 15, true);
    const tab = (try nextInput(&f, picker, .key)).value.key;
    try testing.expectEqual(@as(u32, 0xff09), tab.symbol);
    try testing.expectEqual(@as(u8, 0), tab.text_len);
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 2, &.{ .{ .uint = 4 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .keyboard_leave);
    try keyboardEnter(&f, banner, &.{});
    try keyEvent(&f, 30, true);
    try testing.expect(f.display.input.pop() == null);
    const old = f.display.input.keyboard.?.id;
    try f.event(seat.id, &wl.Seat.interface, 0, &.{.{ .uint = 1 }});
    try testing.expect(f.display.input.keyboard == null and f.display.input.state == null);
    try f.event(seat.id, &wl.Seat.interface, 0, &.{.{ .uint = 3 }});
    try testing.expect(f.display.input.keyboard.?.id != old);
    try testing.expect(f.display.input.state == null);
}

test "native pointer preserves logical coordinates, matched release and scroll frames" {
    var f = try Fixture.openWith(.{ .fractional = true, .viewport = true });
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    _ = try f.take();
    try f.scale(picker, 210);
    try f.configure(picker, 1, size);
    const pointer = f.display.input.pointer.?.id;
    try pointerEnter(&f, picker, 21.25, 15.5);
    const enter = (try nextInput(&f, picker, .pointer_enter)).value.pointer_enter;
    try testing.expectEqual(@as(f64, 21.25), enter.x);
    try testing.expectEqual(@as(f64, 15.5), enter.y);
    try buttonEvent(&f, false);
    try testing.expect(f.display.input.pop() == null);
    try buttonEvent(&f, true);
    try testing.expect((try nextInput(&f, picker, .button)).value.button.pressed);
    try f.event(pointer, &wl.Pointer.interface, 2, &.{ .{ .uint = 5 }, .{ .fixed = .fromDouble(30.5) }, .{ .fixed = .fromDouble(20.25) } });
    _ = try nextInput(&f, picker, .motion);
    try buttonEvent(&f, false);
    const release = (try nextInput(&f, picker, .button)).value.button;
    try testing.expect(!release.pressed and release.at.x == 30.5 and release.at.y == 20.25);
    for (0..2) |_| {
        try f.event(pointer, &wl.Pointer.interface, 9, &.{ .{ .uint = 0 }, .{ .int = 60 } });
        try f.event(pointer, &wl.Pointer.interface, 4, &.{ .{ .uint = 6 }, .{ .uint = 0 }, .{ .fixed = .fromInt(5) } });
        try f.event(pointer, &wl.Pointer.interface, 5, &.{});
    }
    try testing.expectEqual(@as(i8, 3), (try nextInput(&f, picker, .scroll)).value.scroll);
    try testing.expect(f.display.input.pop() == null);
    try buttonEvent(&f, true);
    _ = try nextInput(&f, picker, .button);
    try f.event(pointer, &wl.Pointer.interface, 1, &.{ .{ .uint = 7 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .pointer_leave);
    try pointerEnter(&f, banner, 4, 5);
    _ = try nextInput(&f, banner, .pointer_enter);
    try buttonEvent(&f, false); // cannot complete another surface's press
    try testing.expect(f.display.input.pop() == null);
    try buttonEvent(&f, true);
    try buttonEvent(&f, false);
    try testing.expect((try nextInput(&f, banner, .button)).value.button.pressed);
    try testing.expect(!(try nextInput(&f, banner, .button)).value.button.pressed);
    try buttonEvent(&f, true);
    try f.event(banner.layer.?.id, &zwlr.LayerSurfaceV1.interface, 1, &.{});
    try testing.expect(f.display.input.pop() == null and f.display.input.pointer_focus == null);
    try buttonEvent(&f, false);
    try testing.expect(f.display.input.pop() == null);
}

test "truncated keymap fails before keymap parsing" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    try testing.expectError(error.NativeKeymapTruncated, keymapEvent(&f, input_keymap, input_keymap.len + 1));
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
    try testing.expect(f.display.input.state == null);
}

test "bounded native input queue refuses overflow instead of dropping a release" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try pointerEnter(&f, picker, 1, 1);
    for (0..Input.max_events * 2) |i| try f.event(f.display.input.pointer.?.id, &wl.Pointer.interface, 2, &.{ .{ .uint = 1 }, .{ .fixed = .fromInt(@intCast(i)) }, .{ .fixed = .fromInt(3) } });
    try testing.expectEqual(@as(usize, 2), f.display.input.count);
    _ = try nextInput(&f, picker, .pointer_enter);
    try testing.expectEqual(@as(f64, Input.max_events * 2 - 1), (try nextInput(&f, picker, .motion)).value.motion.x);
    for (0..Input.max_events) |i| try buttonEvent(&f, i % 2 == 0);
    try testing.expectError(error.NativeInputOverflow, buttonEvent(&f, true));
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
}

test "repeat follows one monotonic deadline, current modifiers and focus cancellation" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 5, &.{ .{ .int = 25 }, .{ .int = 400 } });
    try keyboardEnter(&f, picker, &.{});
    _ = try nextInput(&f, picker, .keyboard_enter);
    try testing.expect(f.display.input.repeatDeadline() == null);
    try keyEvent(&f, 30, true);
    const first = f.display.input.repeatDeadline().?;
    try testing.expect(!try f.display.input.advanceRepeat(first)); // actual input first
    const pressed = (try nextInput(&f, picker, .key)).value.key;
    try testing.expect(!pressed.repeated);
    try testing.expect(!try f.display.input.advanceRepeat(first.subDuration(.fromNanoseconds(1))));
    try testing.expect(try f.display.input.advanceRepeat(first));
    const repeated = (try nextInput(&f, picker, .key)).value.key;
    try testing.expect(repeated.pressed and repeated.repeated and repeated.code == 30);
    try testing.expectEqualStrings("a", repeated.utf8());
    try testing.expectEqual(first.addDuration(.fromMilliseconds(40)), f.display.input.repeatDeadline().?);
    try modifiers(&f, 1);
    const late = first.addDuration(.fromMilliseconds(1000));
    try testing.expect(try f.display.input.advanceRepeat(late));
    try testing.expectEqualStrings("A", (try nextInput(&f, picker, .key)).value.key.utf8());
    try testing.expect(!try f.display.input.advanceRepeat(late));
    try testing.expectEqual(late.addDuration(.fromMilliseconds(40)), f.display.input.repeatDeadline().?);
    try keyEvent(&f, 30, false);
    _ = try nextInput(&f, picker, .key);
    try testing.expect(f.display.input.repeatDeadline() == null);
    try modifiers(&f, 0);
    try keyEvent(&f, 15, true);
    _ = try nextInput(&f, picker, .key);
    try testing.expect(f.display.input.repeatDeadline() == null); // Tab is one shot
    try keyEvent(&f, 15, false);
    _ = try nextInput(&f, picker, .key);
    try keyEvent(&f, 30, true);
    _ = try nextInput(&f, picker, .key);
    try testing.expect(f.display.input.repeatDeadline() != null);
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 2, &.{ .{ .uint = 4 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .keyboard_leave);
    try testing.expect(f.display.input.repeatDeadline() == null);
    try testing.expect(!try f.display.input.advanceRepeat(late));
}

test "compose preparation waits for editable keyboard focus" {
    var f = try Fixture.open();
    defer f.close();
    var env = std.process.Environ.Map.init(testing.allocator);
    defer env.deinit();
    try env.put("LC_ALL", "");
    try env.put("LC_CTYPE", "C.UTF-8");
    try env.put("LANG", "ignored");
    try f.display.input.rememberComposeLocale(testing.allocator, &env);
    try testing.expectEqualStrings("C.UTF-8", f.display.input.compose_locale.?);
    try localInput(&f);
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    try keyboardEnter(&f, banner, &.{});
    try testing.expect(f.display.input.compose == null and f.display.input.compose_locale != null);
    try keyboardEnter(&f, picker, &.{});
    _ = try nextInput(&f, picker, .keyboard_enter);
    try testing.expect(f.display.input.compose_locale == null);
}

test "local compose produces one UTF8 result and cancels on leave" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    const context = xkb.xkb_context_new(xkb.XKB_CONTEXT_NO_FLAGS) orelse return error.ComposeFixture;
    defer xkb.xkb_context_unref(context);
    const source = "<dead_acute> <a> : \"á\" U00E1\n";
    const table = xkb.xkb_compose_table_new_from_buffer(context, source.ptr, source.len, "C.UTF-8", xkb.XKB_COMPOSE_FORMAT_TEXT_V1, xkb.XKB_COMPOSE_COMPILE_NO_FLAGS) orelse return error.ComposeFixture;
    defer xkb.xkb_compose_table_unref(table);
    f.display.input.compose = xkb.xkb_compose_state_new(table, xkb.XKB_COMPOSE_STATE_NO_FLAGS) orelse return error.ComposeFixture;
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 5, &.{ .{ .int = 25 }, .{ .int = 400 } });
    try keyboardEnter(&f, picker, &.{});
    _ = try nextInput(&f, picker, .keyboard_enter);
    try keyEvent(&f, 31, true);
    const dead = (try nextInput(&f, picker, .key)).value.key;
    try testing.expect(dead.compose_consumed and dead.text_len == 0 and f.display.input.repeatDeadline() == null);
    try keyEvent(&f, 31, false);
    _ = try nextInput(&f, picker, .key);
    try keyEvent(&f, 30, true);
    const composed = (try nextInput(&f, picker, .key)).value.key;
    try testing.expectEqualStrings("á", composed.utf8());
    try testing.expect(composed.compose_consumed and f.display.input.repeatDeadline() == null);
    try keyEvent(&f, 30, false);
    _ = try nextInput(&f, picker, .key);
    try keyEvent(&f, 31, true);
    _ = try nextInput(&f, picker, .key);
    try f.event(f.display.input.keyboard.?.id, &wl.Keyboard.interface, 2, &.{ .{ .uint = 4 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .keyboard_leave);
    try keyboardEnter(&f, picker, &.{});
    _ = try nextInput(&f, picker, .keyboard_enter);
    try keyEvent(&f, 30, true);
    try testing.expectEqualStrings("a", (try nextInput(&f, picker, .key)).value.key.utf8());
}

test "cursor shape uses enter serial; immutable SHM fallback retains one buffer" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try pointerEnter(&f, picker, 5, 6);
    _ = try nextInput(&f, picker, .pointer_enter);
    const cursor = &f.display.input.cursor;
    const pointer = f.display.input.pointer.?.id;
    const initial = try f.take();
    try testing.expectEqual(@as(u32, 1), try initial.word(pointer, 0, 0));
    try testing.expectEqual(@backingInt(cursor.surface.?.id), try initial.word(pointer, 0, 1));
    const buffer = cursor.pool.?.buffers.items[0];
    try testing.expectEqual(@as(usize, 1), cursor.pool.?.count());
    try testing.expectEqual(@as(u32, 48), buffer.width);
    try testing.expectEqual(@as(u32, 48), buffer.height);
    try testing.expectEqual(present.Format.argb8888, buffer.format);
    try testing.expectEqual(@as(u32, 2), try initial.firstWord(cursor.surface.?.id, 8));
    const original = try testing.allocator.dupe(u8, buffer.pixels());
    defer testing.allocator.free(original);
    // The compositor has not released the cursor, but re-enter does not
    // allocate or modify its immutable contents.
    try f.event(pointer, &wl.Pointer.interface, 1, &.{ .{ .uint = 8 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .pointer_leave);
    try pointerEnter(&f, picker, 8, 9);
    _ = try nextInput(&f, picker, .pointer_enter);
    const again = try f.take();
    try testing.expectEqual(@as(usize, 1), again.count(pointer, 0));
    try testing.expectEqual(@as(usize, 0), again.count(cursor.surface.?.id, 6));
    try testing.expectEqualSlices(u8, original, buffer.pixels());
    try f.global(21, "wp_cursor_shape_manager_v1", 1);
    _ = try f.take();
    try f.event(pointer, &wl.Pointer.interface, 1, &.{ .{ .uint = 9 }, .{ .object = picker.surface.?.id } });
    _ = try nextInput(&f, picker, .pointer_leave);
    try f.event(pointer, &wl.Pointer.interface, 0, &.{ .{ .uint = 42 }, .{ .object = picker.surface.?.id }, .{ .fixed = .fromInt(5) }, .{ .fixed = .fromInt(6) } });
    _ = try nextInput(&f, picker, .pointer_enter);
    const shape = try f.take();
    try testing.expectEqual(@as(u32, 42), try shape.word(cursor.device.?.id, 1, 0));
    try testing.expectEqual(@as(u32, 1), try shape.word(cursor.device.?.id, 1, 1));
    try testing.expectEqual(@as(usize, 0), shape.count(pointer, 0));
}

test "IME batches apply only on done and do not suppress forwarded keys" {
    var f = try Fixture.open();
    defer f.close();
    try f.global(21, "zwp_text_input_manager_v3", 1);
    try localInput(&f);
    var picker: ?*native.Surface = try native.Surface.create(f.display, .picker, size, null);
    defer if (picker) |s| s.destroy() catch {};
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    const object = f.display.input.ime_object.?.id;
    try keyboardEnter(&f, picker.?, &.{});
    _ = try nextInput(&f, picker.?, .keyboard_enter);
    try f.event(object, &zwp.TextInputV3.interface, 0, &.{.{ .object = picker.?.surface.?.id }});
    const enabled = try f.take();
    try testing.expectEqual(@as(usize, 1), enabled.count(object, 1));
    try testing.expectEqual(@as(usize, 1), enabled.count(object, 7));
    try keyEvent(&f, 30, true);
    try testing.expectEqualStrings("a", (try nextInput(&f, picker.?, .key)).value.key.utf8());
    try keyEvent(&f, 30, false);
    _ = try nextInput(&f, picker.?, .key);
    try f.event(object, &zwp.TextInputV3.interface, 2, &.{ .{ .string = "漢" }, .{ .int = 3 }, .{ .int = 3 } });
    try f.event(object, &zwp.TextInputV3.interface, 3, &.{.{ .string = "é" }});
    try f.event(object, &zwp.TextInputV3.interface, 4, &.{ .{ .uint = 2 }, .{ .uint = 0 } });
    try testing.expect(f.display.input.pop() == null);
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 0 }});
    const batch = (try nextInput(&f, picker.?, .ime)).value.ime;
    try testing.expectEqualStrings("é", batch.commit.slice());
    try testing.expectEqualStrings("漢", batch.preedit.slice());
    try testing.expectEqual(@as(i32, 3), batch.cursor_begin);
    try testing.expectEqual(@as(u32, 2), batch.delete_before);
    try testing.expect(!batch.serial_matches);
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 1 }});
    const clear = (try nextInput(&f, picker.?, .ime)).value.ime;
    try testing.expect(clear.serial_matches and clear.preedit.len == 0 and clear.commit.len == 0 and clear.delete_before == 0);
    try f.event(object, &zwp.TextInputV3.interface, 1, &.{.{ .object = picker.?.surface.?.id }});
    _ = try nextInput(&f, picker.?, .ime_cancel);
    try f.event(object, &zwp.TextInputV3.interface, 0, &.{.{ .object = banner.surface.?.id }});
    try testing.expectEqual(@as(usize, 0), (try f.take()).count(object, 1));
    try f.event(object, &zwp.TextInputV3.interface, 3, &.{.{ .string = "ignored" }});
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 1 }});
    try testing.expect(f.display.input.pop() == null);
    try f.event(object, &zwp.TextInputV3.interface, 0, &.{.{ .object = picker.?.surface.?.id }});
    _ = try f.take();
    try f.event(object, &zwp.TextInputV3.interface, 3, &.{.{ .string = "retired" }});
    const old = picker.?;
    picker = null;
    try old.destroy();
    const retired = try f.take();
    try testing.expectEqual(@as(usize, 1), retired.count(object, 2));
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 2 }});
    try testing.expect(f.display.input.pop() == null);
}

test "IME rejects a preedit cursor in the middle of a UTF8 code point" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    try f.global(21, "zwp_text_input_manager_v3", 1);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    const object = f.display.input.ime_object.?.id;
    try f.event(object, &zwp.TextInputV3.interface, 0, &.{.{ .object = picker.surface.?.id }});
    try testing.expectError(error.NativeImeCursor, f.event(object, &zwp.TextInputV3.interface, 2, &.{ .{ .string = "é" }, .{ .int = 1 }, .{ .int = 1 } }));
    try testing.expectEqual(native.Display.Status.failed, f.display.status());
}

// The opt-in integration test renders actual SDL CPU pixels, then witnesses
// their composition through a private real Wayland compositor. No synthetic
// SDL events, wall-clock-dependent sleeps, or product runtime replacement.
extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

const CpuPaint = struct {
    rgb: [3]u8,
    fn draw(self: CpuPaint, frame: native.Frame) !void {
        try testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
        const surface = sdl.SDL_CreateSurfaceFrom(@intCast(frame.extent.width), @intCast(frame.extent.height), sdl.SDL_PIXELFORMAT_XRGB8888, frame.pixels.ptr, @intCast(frame.stride)) orelse return error.CpuSurface;
        defer sdl.SDL_DestroySurface(surface);
        const renderer = sdl.SDL_CreateSoftwareRenderer(surface) orelse return error.CpuRenderer;
        defer sdl.SDL_DestroyRenderer(renderer);
        const font_pixels = try native.scaledPixels(16, frame.scale_120);
        var text = try Painter.init(testing.allocator, renderer, @intCast(font_pixels));
        defer text.deinit();
        if (!sdl.SDL_SetRenderDrawColor(renderer, self.rgb[0], self.rgb[1], self.rgb[2], 255) or !sdl.SDL_RenderClear(renderer)) return error.CpuClear;
        try text.draw("Wayspot native surface", .{ 235, 235, 240 }, @floatFromInt(try native.scaledPixels(20, frame.scale_120)), @floatFromInt(try native.scaledPixels(12, frame.scale_120)));
        if (!sdl.SDL_FlushRenderer(renderer)) return error.CpuFlush;
        try testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
    }
};

fn readBefore(display: *native.Display, start: std.Io.Timestamp) !void {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(testing.io)).toMilliseconds();
    if (elapsed >= 3000) return error.NativeFixtureDeadline;
    var fds = [_]linux.pollfd{.{ .fd = display.fd(), .events = linux.POLL.IN, .revents = 0 }};
    const rc = linux.poll(&fds, fds.len, @intCast(3000 - elapsed));
    if (linux.errno(rc) != .SUCCESS or rc != 1) return error.NativeFixtureDeadline;
    try display.readReady();
}

fn drawBefore(display: *native.Display, surface: *native.Surface, rgb: [3]u8) !void {
    const start = std.Io.Clock.awake.now(testing.io);
    while (true) {
        switch (try surface.draw(CpuPaint{ .rgb = rgb }, CpuPaint.draw)) {
            .presented => return,
            .not_configured, .frame_pending, .buffers_busy => try readBefore(display, start),
            else => return error.NativeFixtureDraw,
        }
    }
}

fn barrier(display: *native.Display) !void {
    try display.requestSync();
    const start = std.Io.Clock.awake.now(testing.io);
    while (display.sync_pending) try readBefore(display, start);
}

fn expectPixels(env: *const std.process.Environ.Map, center: [3]u8, corner: [3]u8, text_expected: bool) !void {
    return expectOutputPixels(env, null, 120, center, corner, text_expected);
}

fn expectOutputPixels(env: *const std.process.Environ.Map, output: ?[]const u8, scale: u32, center: [3]u8, corner: [3]u8, text_expected: bool) !void {
    var scale_string: [16]u8 = undefined;
    const factor = try std.fmt.bufPrint(&scale_string, "{d:.3}", .{@as(f64, @floatFromInt(scale)) / 120.0});
    const args: []const []const u8 = if (output) |name| &.{ "/usr/bin/grim", "-o", name, "-s", factor, "-t", "ppm", "-" } else &.{ "/usr/bin/grim", "-s", factor, "-t", "ppm", "-" };
    const start = std.Io.Clock.awake.now(testing.io);
    while (start.durationTo(std.Io.Clock.awake.now(testing.io)).toMilliseconds() < 3000) {
        const result = try std.process.run(testing.allocator, testing.io, .{
            .argv = args,
            .environ_map = env,
            .stdout_limit = .limited(12 * 1024 * 1024),
            .stderr_limit = .limited(4096),
            .timeout = .{ .duration = .{ .raw = .fromSeconds(2), .clock = .awake } },
        });
        defer testing.allocator.free(result.stdout);
        defer testing.allocator.free(result.stderr);
        if (result.term != .exited or result.term.exited != 0) return error.NativeFixtureCapture;
        const offset = (std.mem.indexOf(u8, result.stdout[0..@min(result.stdout.len, 150)], "\n255\n") orelse return error.NativeFixtureCapture) + 5;
        var fields = std.mem.tokenizeAny(u8, result.stdout[0..offset], " \r\n\t");
        if (!std.mem.eql(u8, fields.next() orelse "", "P6")) return error.NativeFixtureCapture;
        const width = try std.fmt.parseInt(usize, fields.next() orelse "", 10);
        const height = try std.fmt.parseInt(usize, fields.next() orelse "", 10);
        if (width != try native.scaledPixels(1280, scale) or height != try native.scaledPixels(720, scale) or result.stdout.len - offset != width * height * 3) return error.NativeFixtureSize;
        const pixels = result.stdout[offset..];
        const center_at = (try native.scaledPixels(360, scale) * width + try native.scaledPixels(640, scale)) * 3;
        const corner_at = (try native.scaledPixels(36, scale) * width + try native.scaledPixels(1240, scale)) * 3;
        if (!std.mem.eql(u8, pixels[center_at..][0..3], &center) or !std.mem.eql(u8, pixels[corner_at..][0..3], &corner)) continue;
        if (text_expected) {
            // The logical picker remains 720x520, regardless of the physical
            // buffer density. Check inside and outside its top-left boundary.
            const inside = (try native.scaledPixels(105, scale) * width + try native.scaledPixels(285, scale)) * 3;
            const outside = (try native.scaledPixels(95, scale) * width + try native.scaledPixels(275, scale)) * 3;
            if (!std.mem.eql(u8, pixels[inside..][0..3], &center) or !std.mem.eql(u8, pixels[outside..][0..3], &.{ 0, 0, 0 })) continue;
            var bright = false;
            for (try native.scaledPixels(112, scale)..try native.scaledPixels(140, scale)) |y| {
                for (try native.scaledPixels(300, scale)..try native.scaledPixels(520, scale)) |x| {
                    const rgb = pixels[(y * width + x) * 3 ..][0..3];
                    if (rgb[0] > 200 and rgb[1] > 200 and rgb[2] > 200) bright = true;
                }
            }
            if (!bright) continue;
        }
        return;
    }
    return error.NativeFixturePixels;
}

fn privateEnvironment() !?std.process.Environ.Map {
    const requested = std.mem.span(getenv("WAYSPOT_NATIVE_PRIVATE_TEST") orelse return null);
    const runtime = std.mem.span(getenv("XDG_RUNTIME_DIR") orelse return error.PrivateRuntimeMissing);
    const display_name = std.mem.span(getenv("WAYLAND_DISPLAY") orelse return error.PrivateRuntimeMissing);
    if (!std.mem.eql(u8, requested, runtime) or !std.fs.path.isAbsolute(runtime) or std.mem.startsWith(u8, runtime, "/run/user/") or getenv("WAYLAND_SOCKET") != null or display_name.len == 0 or std.mem.indexOfScalar(u8, display_name, '/') != null) return error.PrivateRuntimeRequired;
    var env = std.process.Environ.Map.init(testing.allocator);
    errdefer env.deinit();
    try env.put("XDG_RUNTIME_DIR", runtime);
    try env.put("WAYLAND_DISPLAY", display_name);
    return env;
}

test "private real native layers draw CPU pixels and retire independently" {
    if (getenv("WAYSPOT_NATIVE_MIXED_TEST") != null or getenv("WAYSPOT_NATIVE_INPUT_TEST") != null) return;
    var env = (try privateEnvironment()) orelse return;
    defer env.deinit();
    const black = [3]u8{ 0, 0, 0 };
    const green = [3]u8{ 20, 110, 60 };
    const blue = [3]u8{ 30, 40, 120 };
    const red = [3]u8{ 130, 30, 60 };
    try expectPixels(&env, black, black, false);
    for (0..3) |_| {
        const display = try native.Display.open(testing.allocator, testing.io, &env);
        defer display.destroy();
        const start = std.Io.Clock.awake.now(testing.io);
        while (display.status() == .discovering) try readBefore(display, start);
        try testing.expectEqual(native.Display.Status.ready, display.status());
        var picker: ?*native.Surface = try native.Surface.create(display, .picker, .{ .width = 720, .height = 520 }, null);
        defer if (picker) |surface| surface.destroy() catch {};
        var banner: ?*native.Surface = try native.Surface.create(display, .notification, .{ .width = 420, .height = 120 }, null);
        defer if (banner) |surface| surface.destroy() catch {};
        try drawBefore(display, picker.?, green);
        try drawBefore(display, banner.?, red);
        try expectPixels(&env, green, red, true);
        picker.?.invalidate();
        try drawBefore(display, picker.?, blue);
        try expectPixels(&env, blue, red, true);
        const old_picker = picker.?;
        picker = null;
        try old_picker.destroy();
        try barrier(display);
        try expectPixels(&env, black, red, false);
        try testing.expectEqual(@as(u8, 1), display.surfaces);
        const old_banner = banner.?;
        banner = null;
        try old_banner.destroy();
        try barrier(display);
        try expectPixels(&env, black, black, false);
        try testing.expectEqual(@as(u8, 0), display.surfaces);
    }
    try testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
    std.debug.print("NATIVE_SURFACE_LIVE_PASS three shared display lifetimes, six roles, actual glyphs and pixels, independent retirement\n", .{});
}

fn cliJson(env: *const std.process.Environ.Map, args: []const []const u8) !std.json.Parsed(std.json.Value) {
    const cli = std.mem.span(getenv("WAYSPOT_NATIVE_CLI") orelse return error.NativeFixtureCliMissing);
    if (!std.fs.path.isAbsolute(cli) or std.mem.startsWith(u8, cli, "/usr/local/bin/")) return error.NativeFixtureCliInvalid;
    var argv: [5][]const u8 = undefined;
    if (args.len >= argv.len) return error.NativeFixtureCliInvalid;
    argv[0] = cli;
    @memcpy(argv[1..][0..args.len], args);
    const result = try std.process.run(testing.allocator, testing.io, .{
        .argv = argv[0 .. args.len + 1],
        .environ_map = env,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(4096),
        .timeout = .{ .duration = .{ .raw = .fromSeconds(4), .clock = .awake } },
    });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);
    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("private display command failed: {s}\n", .{result.stderr});
        return error.NativeFixtureCliFailed;
    }
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, result.stdout, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    if (!parsed.value.object.get("ok").?.bool) return error.NativeFixtureCliFailed;
    return parsed;
}

fn changeScale(env: *const std.process.Environ.Map, numerator: u32) !void {
    const monitors = try cliJson(env, &.{ "monitor", "list" });
    defer monitors.deinit();
    const status = try cliJson(env, &.{ "session", "status" });
    defer status.deinit();
    const Head = struct {
        id: u64,
        enabled: bool = true,
        custom_mode: struct { width: u32, height: u32, refresh_mhz: u32 = 60000 },
        scale: f64,
        at: struct { x: i32, y: i32 = 0 },
    };
    const observed = monitors.value.object.get("data").?.array.items;
    try testing.expectEqual(@as(usize, 2), observed.len);
    var heads: [2]Head = undefined;
    var seen_left = false;
    var seen_right = false;
    for (observed, &heads) |monitor, *head| {
        const name = monitor.object.get("name").?.string;
        const right = std.mem.eql(u8, name, "HEADLESS-1");
        if (right) {
            try testing.expect(!seen_right);
            seen_right = true;
        } else {
            try testing.expectEqualStrings("HEADLESS-2", name);
            try testing.expect(!seen_left);
            seen_left = true;
        }
        const scale = if (right) numerator else 120;
        head.* = .{
            .id = @intCast(monitor.object.get("id").?.integer),
            .custom_mode = .{ .width = try native.scaledPixels(1280, scale), .height = try native.scaledPixels(720, scale) },
            .scale = @as(f64, @floatFromInt(scale)) / 120.0,
            .at = .{ .x = if (right) 1280 else 0 },
        };
    }
    try testing.expect(seen_left and seen_right);
    const payload = try std.json.Stringify.valueAlloc(testing.allocator, .{
        .schema = "snowman-display-config/v1",
        .display_revision = status.value.object.get("data").?.object.get("display_revision").?.integer,
        .heads = heads,
    }, .{});
    defer testing.allocator.free(payload);
    const path = try std.fs.path.join(testing.allocator, &.{ env.get("XDG_RUNTIME_DIR").?, "native-scale.json" });
    defer testing.allocator.free(path);
    try std.Io.Dir.cwd().writeFile(testing.io, .{ .sub_path = path, .data = payload });
    defer std.Io.Dir.cwd().deleteFile(testing.io, path) catch {};
    const applied = try cliJson(env, &.{ "display", "apply", path });
    defer applied.deinit();
    try testing.expectEqualStrings("applied", applied.value.object.get("data").?.object.get("status").?.string);
}

fn settleScale(display: *native.Display, surface: *native.Surface, rgb: [3]u8, expected: u32) !void {
    const start = std.Io.Clock.awake.now(testing.io);
    while (surface.fractional_preferred != expected) try readBefore(display, start);
    if (surface.dirty) try drawBefore(display, surface, rgb);
    try testing.expectEqual(expected, surface.scale_120);
    try testing.expectEqual(surface.requested, surface.extent.?);
    try testing.expectEqual(@as(i32, 1), surface.presenter.?.scale);
    const pixels = try surface.requested.scaled(expected);
    var matching = false;
    for (surface.pool.?.buffers.items) |buffer| {
        if (!buffer.stale and buffer.width == pixels.width and buffer.height == pixels.height) matching = true;
    }
    try testing.expect(matching);
    try testing.expect(surface.pool.?.count() <= native.max_buffers);
    std.debug.print("NATIVE_SCALE_FRAME {s} {d}/120 logical={d}x{d} pixels={d}x{d}\n", .{ @tagName(surface.role), expected, surface.requested.width, surface.requested.height, pixels.width, pixels.height });
}

test "private mixed density layers keep their roles through real output scale changes" {
    if (getenv("WAYSPOT_NATIVE_MIXED_TEST") == null) return;
    var env = (try privateEnvironment()) orelse return error.PrivateRuntimeRequired;
    defer env.deinit();
    const black = [3]u8{ 0, 0, 0 };
    const green = [3]u8{ 20, 110, 60 };
    const red = [3]u8{ 130, 30, 60 };
    const display = try native.Display.open(testing.allocator, testing.io, &env);
    defer display.destroy();
    const start = std.Io.Clock.awake.now(testing.io);
    while (display.status() == .discovering) try readBefore(display, start);
    try testing.expectEqual(native.Display.Status.ready, display.status());
    // Registry discovery and output property delivery are separate fences.
    try barrier(display);
    var left: ?wl.Output = null;
    var right: ?wl.Output = null;
    for (display.outputs) |slot| {
        const output = slot orelse continue;
        if (output.scale == 120 and left == null) left = output.object else if (output.scale == 240 and right == null) right = output.object else return error.NativeFixtureOutputs;
    }
    var picker: ?*native.Surface = try native.Surface.create(display, .picker, .{ .width = 720, .height = 520 }, right orelse return error.NativeFixtureOutputs);
    defer if (picker) |surface| surface.destroy() catch {};
    var banner: ?*native.Surface = try native.Surface.create(display, .notification, .{ .width = 420, .height = 120 }, left orelse return error.NativeFixtureOutputs);
    defer if (banner) |surface| surface.destroy() catch {};
    try drawBefore(display, picker.?, green);
    try drawBefore(display, banner.?, red);
    try settleScale(display, picker.?, green, 180);
    try settleScale(display, banner.?, red, 120);
    const role_id = picker.?.layer.?.id;
    const surface_id = picker.?.surface.?.id;
    try expectOutputPixels(&env, "HEADLESS-1", 180, green, black, true);
    try expectOutputPixels(&env, "HEADLESS-2", 120, black, red, false);
    // The right output retains its logical size and placement. Only its
    // physical mode and scale change; the live roles must never remap.
    for ([_]u32{ 210, 240, 120, 180 }) |scale| {
        try changeScale(&env, scale);
        try settleScale(display, picker.?, green, scale);
        try testing.expectEqual(role_id, picker.?.layer.?.id);
        try testing.expectEqual(surface_id, picker.?.surface.?.id);
        try testing.expectEqual(@as(u32, 120), banner.?.scale_120);
        try testing.expect(!banner.?.dirty);
        try expectOutputPixels(&env, "HEADLESS-1", scale, green, black, true);
        try expectOutputPixels(&env, "HEADLESS-2", 120, black, red, false);
    }
    const old_picker = picker.?;
    picker = null;
    try old_picker.destroy();
    try barrier(display);
    try expectOutputPixels(&env, "HEADLESS-1", 180, black, black, false);
    try expectOutputPixels(&env, "HEADLESS-2", 120, black, red, false);
    const old_banner = banner.?;
    banner = null;
    try old_banner.destroy();
    try barrier(display);
    try expectOutputPixels(&env, "HEADLESS-2", 120, black, black, false);
    try testing.expectEqual(@as(u8, 0), display.surfaces);
    try testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
    std.debug.print("NATIVE_SCALE_LIVE_PASS mixed density, four live scale transitions, stable role identity, native raster pixels and independent retirement\n", .{});
}

fn awaitInput(display: *native.Display, surface: wire.ObjectId, tag: std.meta.Tag(@FieldType(Input.Event, "value"))) !Input.Event {
    const start = std.Io.Clock.awake.now(testing.io);
    while (true) {
        while (display.input.pop()) |event| {
            if (event.surface == surface and std.meta.activeTag(event.value) == tag) return event;
        }
        try readBefore(display, start);
    }
}

/// The private actor places the cursor on a flat picker-color region. A
/// capture with the cursor must contain the fallback arrow's light interior
/// and dark outline; a capture without it must contain only the picker color.
fn expectCursorPixels(env: *const std.process.Environ.Map, enabled: bool) !void {
    const args: []const []const u8 = if (enabled) &.{ "/usr/bin/grim", "-c", "-o", "HEADLESS-1", "-s", "1.75", "-t", "ppm", "-" } else &.{ "/usr/bin/grim", "-o", "HEADLESS-1", "-s", "1.75", "-t", "ppm", "-" };
    const start = std.Io.Clock.awake.now(testing.io);
    while (start.durationTo(std.Io.Clock.awake.now(testing.io)).toMilliseconds() < 3000) {
        const result = try std.process.run(testing.allocator, testing.io, .{
            .argv = args,
            .environ_map = env,
            .stdout_limit = .limited(12 * 1024 * 1024),
            .stderr_limit = .limited(4096),
            .timeout = .{ .duration = .{ .raw = .fromSeconds(2), .clock = .awake } },
        });
        defer testing.allocator.free(result.stdout);
        defer testing.allocator.free(result.stderr);
        if (result.term != .exited or result.term.exited != 0) return error.NativeFixtureCapture;
        const offset = (std.mem.indexOf(u8, result.stdout[0..@min(result.stdout.len, 150)], "\n255\n") orelse return error.NativeFixtureCapture) + 5;
        var fields = std.mem.tokenizeAny(u8, result.stdout[0..offset], " \r\n\t");
        try testing.expectEqualStrings("P6", fields.next() orelse "");
        const width = try std.fmt.parseInt(usize, fields.next() orelse "", 10);
        const height = try std.fmt.parseInt(usize, fields.next() orelse "", 10);
        if (width != 2240 or height != 1260 or result.stdout.len - offset != width * height * 3) return error.NativeFixtureSize;
        const pixels = result.stdout[offset..];
        var white: usize = 0;
        var dark: usize = 0;
        var changed: usize = 0;
        for (622..675) |y| {
            for (552..605) |x| {
                const rgb = pixels[(y * width + x) * 3 ..][0..3];
                if (!std.mem.eql(u8, rgb, &.{ 20, 110, 60 })) changed += 1;
                if (rgb[0] > 220 and rgb[1] > 220 and rgb[2] > 220) white += 1;
                if (rgb[0] < 45 and rgb[1] < 45 and rgb[2] < 45) dark += 1;
            }
        }
        if (if (enabled) white >= 10 and dark >= 10 else changed == 0) return;
    }
    return error.NativeCursorPixels;
}

test "private actual Wayland keyboard and pointer reach the native fractional picker" {
    if (getenv("WAYSPOT_NATIVE_INPUT_TEST") == null) return;
    var env = (try privateEnvironment()) orelse return error.PrivateRuntimeRequired;
    defer env.deinit();
    const actor_path = std.mem.span(getenv("WAYSPOT_NATIVE_ACTOR") orelse return error.NativeFixtureActorMissing);
    if (!std.fs.path.isAbsolute(actor_path) or std.mem.startsWith(u8, actor_path, "/usr/local/bin/") or !std.mem.eql(u8, std.fs.path.basename(actor_path), "snowman-sim-client")) return error.NativeFixtureActorInvalid;
    var actor = try std.process.spawn(testing.io, .{ .argv = &.{ actor_path, "red", "ff0000" }, .environ_map = &env, .stdin = .pipe, .stdout = .ignore, .stderr = .inherit });
    defer actor.kill(testing.io);
    try actor.stdin.?.writeStreamingAll(testing.io, "input\n");
    const display = try native.Display.open(testing.allocator, testing.io, &env);
    defer display.destroy();
    const start = std.Io.Clock.awake.now(testing.io);
    while (display.status() == .discovering or display.input.pointer == null or display.input.state == null) try readBefore(display, start);
    try testing.expectEqual(native.Display.Status.ready, display.status());
    var seat_count: usize = 0;
    for (display.input.seats) |seat| if (seat != null) {
        seat_count += 1;
    };
    try testing.expectEqual(@as(usize, 2), seat_count);
    var picker: ?*native.Surface = try native.Surface.create(display, .picker, .{ .width = 720, .height = 520 }, null);
    defer if (picker) |s| s.destroy() catch {};
    const id = picker.?.surface.?.id;
    try drawBefore(display, picker.?, .{ 20, 110, 60 });
    try settleScale(display, picker.?, .{ 20, 110, 60 }, 210);
    _ = try awaitInput(display, id, .keyboard_enter);
    try actor.stdin.?.writeStreamingAll(testing.io, "move-left\n");
    const motion_start = std.Io.Clock.awake.now(testing.io);
    while (display.input.pointer_focus != id or @abs(display.input.point.x - 40) > 2 or @abs(display.input.point.y - 260) > 2) try readBefore(display, motion_start);
    try testing.expectApproxEqAbs(@as(f64, 40), display.input.point.x, 2);
    try testing.expectApproxEqAbs(@as(f64, 260), display.input.point.y, 2);
    try testing.expect(display.input.cursor.surface != null);
    try barrier(display);
    try expectCursorPixels(&env, false);
    try expectCursorPixels(&env, true);
    std.debug.print("NATIVE_CURSOR_LIVE_PASS immutable fallback arrow, actual cursor-inclusive pixels\n", .{});
    while (display.input.pop()) |_| {}
    try actor.stdin.?.writeStreamingAll(testing.io, "key-and-click\n");
    const press = (try awaitInput(display, id, .key)).value.key;
    const release = (try awaitInput(display, id, .key)).value.key;
    try testing.expect(press.pressed and !release.pressed and press.code == 30 and release.code == 30);
    try testing.expectEqualStrings("a", press.utf8());
    try testing.expectEqual(@as(u8, 0), release.text_len);
    const down = (try awaitInput(display, id, .button)).value.button;
    const up = (try awaitInput(display, id, .button)).value.button;
    try testing.expect(down.pressed and !up.pressed and down.code == 272 and up.code == 272);
    try testing.expectApproxEqAbs(@as(f64, 40), up.at.x, 2);
    try testing.expectApproxEqAbs(@as(f64, 260), up.at.y, 2);
    try actor.stdin.?.writeStreamingAll(testing.io, "key-tab\nkey-escape\n");
    for ([_]u32{ 0xff09, 0xff1b }) |symbol| {
        const key_down = (try awaitInput(display, id, .key)).value.key;
        const key_up = (try awaitInput(display, id, .key)).value.key;
        try testing.expect(key_down.pressed and !key_up.pressed and key_down.symbol == symbol and key_up.symbol == symbol and key_down.text_len == 0);
    }
    const old = picker.?;
    picker = null;
    try old.destroy();
    try barrier(display);
    try testing.expect(display.input.keyboard_focus == null and display.input.pointer_focus == null and display.input.count == 0 and display.input.repeatDeadline() == null);
    try actor.stdin.?.writeStreamingAll(testing.io, "exit\n");
    const term = try actor.wait(testing.io);
    try testing.expect(term == .exited and term.exited == 0);
    try testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
    std.debug.print("NATIVE_INPUT_LIVE_PASS local seat only, real XKB text and navigation, matched pointer press/release at 1.75x, retired focus\n", .{});
}

test "IME surrounding context is committed once and waits for a matching done" {
    var f = try Fixture.open();
    defer f.close();
    try f.global(21, "zwp_text_input_manager_v3", 1);
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    const object = f.display.input.ime_object.?.id;
    const rect: [4]i32 = .{ 20, 52, 1, 20 };
    try f.display.input.setImeContext(&f.display.conn, "a", rect, false);
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
    try f.event(object, &zwp.TextInputV3.interface, 0, &.{.{ .object = picker.surface.?.id }});
    const initial = try f.take();
    try testing.expectEqual(@as(usize, 1), initial.count(object, 3));
    try testing.expectEqual(@as(usize, 1), initial.count(object, 6));
    try testing.expectEqual(@as(usize, 1), initial.count(object, 7));
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 0 }});
    _ = try nextInput(&f, picker, .ime);
    try f.display.input.setImeContext(&f.display.conn, "aé", rect, true);
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
    try f.event(object, &zwp.TextInputV3.interface, 5, &.{.{ .uint = 1 }});
    _ = try nextInput(&f, picker, .ime);
    try f.display.input.setImeContext(&f.display.conn, "aé", rect, true);
    const update = try f.take();
    try testing.expectEqual(@as(usize, 1), update.count(object, 3));
    try testing.expectEqual(@as(usize, 1), update.count(object, 7));
    try testing.expectEqual(@as(u32, 0), try update.firstWord(object, 4));
    try f.display.input.setImeContext(&f.display.conn, "aé", rect, true);
    try testing.expectEqual(@as(usize, 0), (try f.take()).len);
}

test "shared native display drains each role without discarding sibling input" {
    var f = try Fixture.open();
    defer f.close();
    try localInput(&f);
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    const banner = try native.Surface.create(f.display, .notification, size, null);
    defer banner.destroy() catch {};
    _ = try f.take();
    const pointer = f.display.input.pointer.?.id;
    const picker_id = picker.surface.?.id;
    const banner_id = banner.surface.?.id;
    try pointerEnter(&f, picker, 4, 5);
    try buttonEvent(&f, true);
    try buttonEvent(&f, false);
    try f.event(pointer, &wl.Pointer.interface, 1, &.{ .{ .uint = 3 }, .{ .object = picker_id } });
    try pointerEnter(&f, banner, 6, 7);
    try buttonEvent(&f, true);
    try buttonEvent(&f, false);
    const input = &f.display.input;
    try testing.expect(input.hasFor(picker_id) and input.hasFor(banner_id));
    try testing.expectEqual(@as(usize, 7), input.count);
    try testing.expectEqual(.pointer_enter, std.meta.activeTag(input.popFor(banner_id).?.value));
    try testing.expect(input.popFor(banner_id).?.value.button.pressed);
    try testing.expect(!input.popFor(banner_id).?.value.button.pressed);
    try testing.expect(!input.hasFor(banner_id) and input.hasFor(picker_id));
    try testing.expectEqual(@as(usize, 4), input.count);
    try testing.expectEqual(.pointer_enter, std.meta.activeTag(input.popFor(picker_id).?.value));
    try testing.expect(input.popFor(picker_id).?.value.button.pressed);
    try testing.expect(!input.popFor(picker_id).?.value.button.pressed);
    try testing.expectEqual(.pointer_leave, std.meta.activeTag(input.popFor(picker_id).?.value));
    try testing.expect(input.count == 0 and input.popFor(banner_id) == null);
}

test "Hyprland selects its named seat even when seat0 is advertised first" {
    var f = try Fixture.open();
    defer f.close();
    f.display.input.selectSessionSeat("Hyprland");
    try f.global(19, "wl_seat", 8);
    try seatEvent(&f, f.display.input.seats[0].?.object, "seat0");
    try testing.expect(f.display.input.selected == null and f.display.input.pointer == null and f.display.input.keyboard == null);
    try f.global(20, "wl_seat", 9);
    const seat = f.display.input.seats[1].?.object;
    // Hyprland can report capabilities before the name.
    try f.event(seat.id, &wl.Seat.interface, 0, &.{.{ .uint = 3 }});
    try testing.expect(f.display.input.selected == null);
    try f.event(seat.id, &wl.Seat.interface, 1, &.{.{ .string = "Hyprland" }});
    try testing.expectEqual(seat.id, f.display.input.selected.?.id);
    try testing.expect(f.display.input.pointer != null and f.display.input.keyboard != null);
    _ = try f.take();
    const picker = try native.Surface.create(f.display, .picker, size, null);
    defer picker.destroy() catch {};
    _ = try f.take();
    try keymapEvent(&f, input_keymap, input_keymap.len);
    try keyboardEnter(&f, picker, &.{});
    _ = try nextInput(&f, picker, .keyboard_enter);
    try keyEvent(&f, 30, true);
    try testing.expectEqualStrings("a", (try nextInput(&f, picker, .key)).value.key.utf8());
    try pointerEnter(&f, picker, 5, 6);
    _ = try nextInput(&f, picker, .pointer_enter);
    try buttonEvent(&f, true);
    try testing.expect((try nextInput(&f, picker, .button)).value.button.pressed);
}
