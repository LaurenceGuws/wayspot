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

    fn firstWord(self: *const Requests, object: wire.ObjectId, opcode: u16) !u32 {
        var at: usize = 0;
        while (at < self.len) {
            const h = wire.wire.Header.decode(self.bytes[at..][0..8]);
            std.debug.assert(h.size >= 8 and at + h.size <= self.len);
            if (h.object == object and h.opcode == opcode) {
                if (h.size < 12) return error.MissingWord;
                return std.mem.readInt(u32, self.bytes[at + 8 ..][0..4], endian);
            }
            at += h.size;
        }
        return error.MissingRequest;
    }
};

const Fixture = struct {
    display: *native.Display,
    server: i32,

    fn open() !Fixture {
        var fds: [2]i32 = undefined;
        try testing.expectEqual(@as(usize, 0), linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0, &fds));
        errdefer _ = linux.close(fds[1]);
        const conn = Connection.fromFd(testing.allocator, testing.io, fds[0]) catch |err| {
            _ = linux.close(fds[0]);
            return err;
        };
        var self: Fixture = .{ .display = try native.Display.adopt(testing.allocator, conn), .server = fds[1] };
        errdefer self.display.destroy();
        try testing.expectEqual(native.Display.Status.discovering, self.display.status());
        const initial = try self.take();
        const registry: wire.ObjectId = @fromBackingInt(try initial.firstWord(.display, 1));
        const callback: wire.ObjectId = @fromBackingInt(try initial.firstWord(.display, 0));
        for ([_][:0]const u8{ "wl_compositor", "wl_shm", "zwlr_layer_shell_v1" }, [_]u32{ 4, 1, 1 }, 1..) |name, version, id| {
            try self.event(registry, &wl.Registry.interface, 0, &.{ .{ .uint = @intCast(id) }, .{ .string = name }, .{ .uint = version } });
        }
        try self.done(callback);
        try testing.expectEqual(native.Display.Status.ready, self.display.status());
        _ = try self.take();
        return self;
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

    fn draw(self: *Paint, frame: native.Frame) !void {
        self.calls += 1;
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
    for (surface.pool.?.buffers.items) |buffer| {
        if (@backingInt(buffer.wl_buffer.id) == id) {
            try testing.expectEqual(present.Buffer.State.busy, buffer.state);
            return buffer;
        }
    }
    return error.MissingBuffer;
}

test "configure before pixels; frame and release are separate fences across resize" {
    var f = try Fixture.open();
    defer f.close();
    const s = try native.Surface.create(f.display, .picker, size);
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
    const s = try native.Surface.create(f.display, .picker, size);
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
    var picker: ?*native.Surface = try native.Surface.create(f.display, .picker, size);
    defer if (picker) |s| s.destroy() catch {};
    try testing.expectError(error.NativeRoleAlreadyOwned, native.Surface.create(f.display, .picker, size));
    const banner = try native.Surface.create(f.display, .notification, size);
    defer banner.destroy() catch {};
    try testing.expectError(error.NativeSurfaceLimit, native.Surface.create(f.display, .picker, size));
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
    const s = try native.Surface.create(f.display, .picker, size);
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
        var text = try Painter.init(testing.allocator, renderer, 16);
        defer text.deinit();
        if (!sdl.SDL_SetRenderDrawColor(renderer, self.rgb[0], self.rgb[1], self.rgb[2], 255) or !sdl.SDL_RenderClear(renderer)) return error.CpuClear;
        try text.draw("Wayspot native surface", .{ 235, 235, 240 }, 20, 12);
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
    const start = std.Io.Clock.awake.now(testing.io);
    while (start.durationTo(std.Io.Clock.awake.now(testing.io)).toMilliseconds() < 3000) {
        const result = try std.process.run(testing.allocator, testing.io, .{
            .argv = &.{ "/usr/bin/grim", "-t", "ppm", "-" },
            .environ_map = env,
            .stdout_limit = .limited(4 * 1024 * 1024),
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
        // Fixture is intentionally one scale-1 head. Scaling is a separate
        // gate, not implied by successful logical-size rendering.
        if (width != 1280 or height != 720 or result.stdout.len - offset != width * height * 3) return error.NativeFixtureSize;
        const pixels = result.stdout[offset..];
        const center_at = (360 * width + 640) * 3;
        const corner_at = (36 * width + 1240) * 3;
        if (!std.mem.eql(u8, pixels[center_at..][0..3], &center) or !std.mem.eql(u8, pixels[corner_at..][0..3], &corner)) continue;
        if (text_expected) {
            // Picker occupies [280,100]..[1000,620]. Witness a bright
            // rasterized glyph, not merely the rectangle's background.
            var bright = false;
            for (112..140) |y| {
                for (300..520) |x| {
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

test "private real native layers draw CPU pixels and retire independently" {
    const requested = std.mem.span(getenv("WAYSPOT_NATIVE_PRIVATE_TEST") orelse return);
    const runtime = std.mem.span(getenv("XDG_RUNTIME_DIR") orelse return error.PrivateRuntimeMissing);
    const display_name = std.mem.span(getenv("WAYLAND_DISPLAY") orelse return error.PrivateRuntimeMissing);
    if (!std.mem.eql(u8, requested, runtime) or !std.fs.path.isAbsolute(runtime) or std.mem.startsWith(u8, runtime, "/run/user/") or getenv("WAYLAND_SOCKET") != null or display_name.len == 0 or std.mem.indexOfScalar(u8, display_name, '/') != null) return error.PrivateRuntimeRequired;
    var env = std.process.Environ.Map.init(testing.allocator);
    defer env.deinit();
    try env.put("XDG_RUNTIME_DIR", runtime);
    try env.put("WAYLAND_DISPLAY", display_name);
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
        var picker: ?*native.Surface = try native.Surface.create(display, .picker, .{ .width = 720, .height = 520 });
        defer if (picker) |surface| surface.destroy() catch {};
        var banner: ?*native.Surface = try native.Surface.create(display, .notification, .{ .width = 420, .height = 120 });
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
