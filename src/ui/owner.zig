//! Main-thread native display lifetime shared by the two graphical roles.
const std = @import("std");
const sdl = @import("wattle").sdl;
const Self = @This();
const shm = @import("native_surface.zig");

// One visible-session owner. Standalone and resident roles borrow the same
// API; the resident retains no native connection while both roles are cold.
env: ?*const std.process.Environ.Map = null,
native: ?*shm.Display = null,
native_users: u8 = 0,

/// Acquires one of the two visible-role leases, discovering a display only on the cold path.
/// The caller must retire its surface before releasing its lease.
pub fn acquireNative(self: *Self, allocator: std.mem.Allocator, io: std.Io) !*shm.Display {
    if (self.native) |display| {
        if (display.failed) return error.NativeConnectionFailed;
        std.debug.assert(self.native_users > 0);
        if (self.native_users >= shm.max_surfaces) return error.NativeLeaseLimit;
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

/// Releases one acquired lease; the last release retires the connection and CPU rendering state.
pub fn releaseNative(self: *Self) void {
    const display = self.native orelse {
        std.debug.assert(false);
        return;
    };
    std.debug.assert(self.native_users > 0 and self.native_users <= shm.max_surfaces);
    self.native_users -= 1;
    if (self.native_users != 0) return;
    self.native = null;
    display.destroy();
    // All software renderers are now gone. Never run global SDL cleanup
    // while a sibling role still owns CPU drawing resources.
    sdl.SDL_Quit();
    std.log.info("native UI connection retired", .{});
}

/// Reads one ready compositor turn within the caller's original two-second wait budget.
/// The transport's synchronous sends retain their separate socket timeout.
pub fn readBefore(display: *shm.Display, io: std.Io, start: std.Io.Timestamp) !void {
    const linux = std.os.linux;
    while (true) {
        if (display.failed) return error.NativeConnectionFailed;
        const timeout = try remainingBefore(start, std.Io.Clock.awake.now(io));
        var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
        const result = linux.poll(&fds, fds.len, timeout);
        switch (linux.errno(result)) {
            .SUCCESS => {
                if (result == 0) return error.NativeUiDeadline;
                // Do not start a blocking read after the wait budget expired.
                const remaining = try remainingBefore(start, std.Io.Clock.awake.now(io));
                std.debug.assert(remaining > 0);
                return display.readReady();
            },
            .INTR => {
                try io.checkCancel();
                continue;
            },
            else => return error.NativeUiPollFailed,
        }
    }
}

fn remainingBefore(start: std.Io.Timestamp, now: std.Io.Timestamp) !i32 {
    const elapsed = start.durationTo(now).toNanoseconds();
    const budget = 2 * std.time.ns_per_s;
    if (elapsed < 0) return error.NativeUiClockInvalid;
    if (elapsed >= budget) return error.NativeUiDeadline;
    return @intCast(@divTrunc(budget - elapsed + std.time.ns_per_ms - 1, std.time.ns_per_ms));
}

test "native UI wait budget uses the original monotonic start" {
    const start: std.Io.Timestamp = .zero;
    try std.testing.expectEqual(@as(i32, 2000), try remainingBefore(start, start));
    try std.testing.expectEqual(
        @as(i32, 1),
        try remainingBefore(start, .fromNanoseconds(2 * std.time.ns_per_s - 1)),
    );
    try std.testing.expectError(
        error.NativeUiDeadline,
        remainingBefore(start, .fromNanoseconds(2 * std.time.ns_per_s)),
    );
    try std.testing.expectError(error.NativeUiClockInvalid, remainingBefore(start, .fromNanoseconds(-1)));
}

/// Borrows the display descriptor, or -1 when neither visible role holds a lease.
pub fn nativeFd(self: *const Self) std.posix.fd_t {
    return if (self.native) |display| display.fd() else -1;
}

/// Pumps a ready display without waiting; a failed display remains owned until its leases retire.
pub fn pumpNative(self: *Self) !void {
    const display = self.native orelse return;
    if (display.failed) return error.NativeConnectionFailed;
    var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, 0) != 0) try display.readReady();
}
