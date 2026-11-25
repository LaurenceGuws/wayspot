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
        var bytes: [wire.wire.max_message_size]u8 = undefined;
        const len = try wire.wire.encodedSize(interface.events[opcode].args, args);
        wire.wire.encode(bytes[0..len], object, opcode, args);
        try testing.expectEqual(len, linux.sendto(self.server, &bytes, len, linux.MSG.NOSIGNAL, null, 0));
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
    if (getenv("WAYSPOT_NATIVE_MIXED_TEST") != null) return;
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
