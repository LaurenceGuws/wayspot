//! Picker signal owns SIGINT/SIGTERM capture and one bounded SDL wake event.
//!
//! The signal handler only writes the eventfd. A picker-owned thread waits for
//! that write, records shutdown, and wakes the SDL event loop outside signal
//! context.

const std = @import("std");
const c = @import("sdl_c");

const poll_timeout_ms: i32 = -1;
const stop_value: u64 = 1;
const signal_value: u64 = 1;
var handler_fd = std.atomic.Value(std.posix.fd_t).init(-1);

comptime {
    std.debug.assert(stop_value > 0);
    std.debug.assert(signal_value > 0);
}

/// Signal owns one eventfd, its temporary signal handlers, and its wake thread.
pub const Signal = struct {
    event_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    shutdown_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    /// init creates the nonblocking eventfd used by the signal handler.
    pub fn init() !Signal {
        return .{ .event_fd = try osEventFd() };
    }

    /// start installs SIGINT/SIGTERM handlers and starts the eventfd waiter.
    pub fn start(self: *Signal) !void {
        std.debug.assert(self.event_fd != -1);
        handler_fd.store(self.event_fd, .release);
        self.installHandlers();
        self.thread = try std.Thread.spawn(.{}, signalMain, .{self});
    }

    /// stop restores handlers, joins the waiter, and closes the eventfd once.
    pub fn stop(self: *Signal) void {
        self.stop_requested.store(true, .release);
        if (self.installed) {
            self.restoreHandlers();
            self.installed = false;
        }
        handler_fd.store(-1, .release);
        if (self.thread) |thread| {
            signalEventFd(self.event_fd, stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.event_fd != -1) {
            osClose(self.event_fd);
            self.event_fd = -1;
        }
    }

    /// requested reports whether a process signal has reached the picker loop.
    pub fn requested(self: *const Signal) bool {
        return self.shutdown_requested.load(.acquire);
    }

    fn installHandlers(self: *Signal) void {
        const action = std.posix.Sigaction{
            .handler = .{ .handler = signalHandler },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(.INT, &action, &self.old_int_action);
        std.posix.sigaction(.TERM, &action, &self.old_term_action);
        self.installed = true;
    }

    fn restoreHandlers(self: *Signal) void {
        std.posix.sigaction(.INT, &self.old_int_action, null);
        std.posix.sigaction(.TERM, &self.old_term_action, null);
    }

    fn pushWake(self: *Signal, signo: u32) void {
        self.shutdown_requested.store(true, .release);
        var event = c.SDL_Event{ .quit = .{ .type = c.SDL_EVENT_QUIT } };
        if (!c.SDL_PushEvent(&event)) {
            std.log.warn("shutdown wake event push failed signo={d}", .{signo});
        }
    }
};

fn signalHandler(signal: std.posix.SIG) callconv(.c) void {
    if (signal != .INT and signal != .TERM) return;
    const fd = handler_fd.load(.acquire);
    if (fd == -1) return;
    var value: u64 = signal_value;
    const written = std.os.linux.write(fd, std.mem.asBytes(&value).ptr, @sizeOf(u64));
    if (std.os.linux.errno(written) != .SUCCESS) return;
}

fn signalMain(signal: *Signal) void {
    var poll_fds = [_]std.posix.pollfd{.{
        .fd = signal.event_fd,
        .events = std.posix.POLL.IN,
        .revents = 0,
    }};
    while (!signal.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        const ready = osPoll(&poll_fds, poll_timeout_ms) catch |err| {
            std.log.warn("shutdown signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0 or (poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;
        var event_count: u64 = 0;
        const event_bytes = osRead(signal.event_fd, std.mem.asBytes(&event_count)) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("shutdown event read failed err={s}", .{@errorName(err)});
            return;
        };
        if (event_bytes != @as(u32, @intCast(@sizeOf(u64)))) {
            std.log.warn("shutdown event short read bytes={d}", .{event_bytes});
            return;
        }
        if (signal.stop_requested.load(.acquire)) return;
        signal.pushWake(@intFromEnum(std.posix.SIG.TERM));
        return;
    }
}

fn osEventFd() !std.posix.fd_t {
    const rc = std.os.linux.eventfd(0, std.os.linux.EFD.CLOEXEC | std.os.linux.EFD.NONBLOCK);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        else => error.SystemCallFailed,
    };
}

fn signalEventFd(fd: std.posix.fd_t, value: u64) void {
    if (fd == -1) return;
    var writable_value = value;
    const written = osWrite(fd, std.mem.asBytes(&writable_value)) catch |err| {
        std.log.debug("shutdown event write failed err={s}", .{@errorName(err)});
        return;
    };
    if (written != @as(u32, @intCast(@sizeOf(u64)))) {
        std.log.debug("shutdown event short write bytes={d}", .{written});
    }
}

fn osClose(fd: std.posix.fd_t) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) std.log.debug("shutdown fd close failed fd={d}", .{fd});
}

fn osPoll(fds: []std.posix.pollfd, timeout_ms: i32) !u32 {
    const rc = std.os.linux.poll(fds.ptr, @intCast(fds.len), timeout_ms);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .INTR => error.SignalInterrupted,
        else => error.SystemCallFailed,
    };
}

fn osRead(fd: std.posix.fd_t, buf: []u8) !u32 {
    const rc = std.os.linux.read(fd, buf.ptr, buf.len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .AGAIN => error.WouldBlock,
        else => error.SystemCallFailed,
    };
}

fn osWrite(fd: std.posix.fd_t, bytes: []const u8) !u32 {
    const rc = std.os.linux.write(fd, bytes.ptr, bytes.len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        else => error.SystemCallFailed,
    };
}
