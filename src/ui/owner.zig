//! Main-thread native display lifetime shared by the two graphical roles.
const std = @import("std");
const sdl = @import("sdl_c");
const Self = @This();
const shm = @import("native_surface.zig");

// One visible-session owner. Standalone and resident roles borrow the same
// API; the resident retains no native connection while both roles are cold.
env: ?*const std.process.Environ.Map = null,
native: ?*shm.Display = null,
native_users: u8 = 0,

pub fn acquireNative(self: *Self, allocator: std.mem.Allocator, io: std.Io) !*shm.Display {
    if (self.native) |display| {
        if (display.failed) return error.NativeConnectionFailed;
        std.debug.assert(self.native_users < 2);
        self.native_users += 1;
        return display;
    }
    std.debug.assert(self.native_users == 0);
    const env = self.env orelse return error.NativeDisplayEnvironment;
    const display = try shm.Display.open(allocator, io, env);
    errdefer display.destroy();
    const start = std.Io.Clock.awake.now(io);
    while (display.status() == .discovering) try readBefore(display, io, start);
    if (display.status() != .ready) return error.NativeDisplayNotReady;
    self.native = display;
    self.native_users = 1;
    std.log.info("native UI connection opened", .{});
    return display;
}

pub fn releaseNative(self: *Self) void {
    std.debug.assert(self.native_users > 0);
    self.native_users -= 1;
    if (self.native_users != 0) return;
    self.native.?.destroy();
    self.native = null;
    // All software renderers are now gone. Never run global SDL cleanup
    // while a sibling role still owns CPU drawing resources.
    sdl.SDL_Quit();
    std.log.info("native UI connection retired", .{});
}

pub fn readBefore(display: *shm.Display, io: std.Io, start: std.Io.Timestamp) !void {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
    if (elapsed >= 2000) return error.NativeUiDeadline;
    var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, @intCast(2000 - elapsed)) == 0) return error.NativeUiDeadline;
    try display.readReady();
}

pub fn nativeFd(self: *const Self) std.posix.fd_t {
    return if (self.native) |display| display.fd() else -1;
}

pub fn pumpNative(self: *Self) !void {
    const display = self.native orelse return;
    if (display.failed) return error.NativeConnectionFailed;
    var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, 0) != 0) try display.readReady();
}
