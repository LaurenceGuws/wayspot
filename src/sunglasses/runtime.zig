//! Sunglasses proof runtime owns overlay slots and shutdown cleanup order.

const std = @import("std");
const hyprland = @import("../wallpaper/hyprland.zig");
const sdl_sunglasses_surface = @import("../ui/sdl_sunglasses_surface.zig");

const c = @import("sdl_c");

const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
var runtime_signal_shutdown_fd = std.atomic.Value(std.posix.fd_t).init(-1);

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    slots: [hyprland.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    sdl_started: bool = false,

    pub fn runProof(allocator: std.mem.Allocator, hypr: hyprland.Connection) !void {
        var runtime = Runtime{ .allocator = allocator };
        defer runtime.deinit();
        try runtime.startProof(hypr);
    }

    fn startProof(self: *Runtime, hypr: hyprland.Connection) !void {
        try self.startSdl();
        var runtime_signals = try RuntimeSignals.init();
        defer runtime_signals.deinit();
        try runtime_signals.start();

        try self.rebuildSurfaceSlots(hypr);
        try waitForShutdown();
    }

    fn startSdl(self: *Runtime) !void {
        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, sdl_sunglasses_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        self.sdl_started = true;
    }

    fn rebuildSurfaceSlots(self: *Runtime, hypr: hyprland.Connection) !void {
        const monitors = try hyprland.queryMonitors(self.allocator, hypr);
        if (monitors.count == 0) return error.NoHyprlandMonitors;

        self.clearSurfaceSlots();
        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            self.slots[self.slot_count] = .{
                .surface = try sdl_sunglasses_surface.SunglassesSurface.init(monitor),
            };
            self.slot_count += 1;
        }
    }

    fn clearSurfaceSlots(self: *Runtime) void {
        var index = self.slot_count;
        while (index > 0) {
            index -= 1;
            self.slots[index].deinit();
        }
        self.slot_count = 0;
    }

    pub fn deinit(self: *Runtime) void {
        self.clearSurfaceSlots();
        if (self.sdl_started) {
            c.SDL_Quit();
            self.sdl_started = false;
        }
    }
};

pub const SurfaceSlot = struct {
    surface: sdl_sunglasses_surface.SunglassesSurface,

    fn deinit(self: *SurfaceSlot) void {
        self.surface.deinit();
    }
};

fn waitForShutdown() !void {
    while (true) {
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEvent(&event)) {
            if (eventIsShutdown(event)) return;
        } else {
            return error.SdlWaitFailed;
        }
    }
}

fn eventIsShutdown(event: c.SDL_Event) bool {
    return event.type == c.SDL_EVENT_QUIT or
        event.type == c.SDL_EVENT_TERMINATING or
        event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
}

/// RuntimeSignals converts process termination into the SDL event loop shutdown path.
const RuntimeSignals = struct {
    shutdown_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init() !RuntimeSignals {
        return .{
            .shutdown_fd = try osEventFd(),
        };
    }

    fn start(self: *RuntimeSignals) !void {
        std.debug.assert(self.shutdown_fd != -1);
        runtime_signal_shutdown_fd.store(self.shutdown_fd, .release);
        self.installHandlers();
        self.thread = try std.Thread.spawn(.{}, runtimeSignalsMain, .{self});
    }

    fn stop(self: *RuntimeSignals) void {
        self.stop_requested.store(true, .release);
        if (self.installed) {
            self.restoreHandlers();
            self.installed = false;
        }
        runtime_signal_shutdown_fd.store(-1, .release);
        if (self.thread) |thread| {
            signalEventFd(self.shutdown_fd, shutdown_eventfd_stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.shutdown_fd != -1) {
            osClose(self.shutdown_fd);
            self.shutdown_fd = -1;
        }
    }

    fn deinit(self: *RuntimeSignals) void {
        self.stop();
    }

    fn installHandlers(self: *RuntimeSignals) void {
        var action = std.posix.Sigaction{
            .handler = .{ .handler = runtimeSignalHandler },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(.INT, &action, &self.old_int_action);
        std.posix.sigaction(.TERM, &action, &self.old_term_action);
        self.installed = true;
    }

    fn restoreHandlers(self: *RuntimeSignals) void {
        std.posix.sigaction(.INT, &self.old_int_action, null);
        std.posix.sigaction(.TERM, &self.old_term_action, null);
    }

    fn pushShutdownWake() void {
        var event = c.SDL_Event{ .quit = .{
            .type = c.SDL_EVENT_QUIT,
        } };
        const pushed = c.SDL_PushEvent(&event);
        if (!pushed) {
            std.log.warn("sunglasses shutdown wake failed", .{});
        }
    }
};

fn runtimeSignalHandler(signal: std.posix.SIG) callconv(.c) void {
    const fd = switch (signal) {
        .INT, .TERM => runtime_signal_shutdown_fd.load(.acquire),
        else => return,
    };
    if (fd == -1) return;
    var value: u64 = shutdown_eventfd_signal_value;
    const written = std.os.linux.write(fd, std.mem.asBytes(&value).ptr, @sizeOf(u64));
    if (std.os.linux.errno(written) != .SUCCESS) return;
}

fn runtimeSignalsMain(runtime_signals: *RuntimeSignals) void {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = runtime_signals.shutdown_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (!runtime_signals.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        const ready = osPoll(&poll_fds, shutdown_signal_poll_timeout_ms) catch |err| {
            std.log.warn("sunglasses signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        drainEventFd(runtime_signals.shutdown_fd) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("sunglasses shutdown read failed err={s}", .{@errorName(err)});
            return;
        };
        if (runtime_signals.stop_requested.load(.acquire)) return;
        RuntimeSignals.pushShutdownWake();
        return;
    }
}

fn drainEventFd(fd: std.posix.fd_t) !void {
    var event_count: u64 = 0;
    const event_bytes = try osRead(fd, std.mem.asBytes(&event_count));
    if (event_bytes != @as(u32, @intCast(@sizeOf(u64)))) {
        return error.SystemCallFailed;
    }
}

fn osEventFd() !std.posix.fd_t {
    const rc = std.os.linux.eventfd(
        0,
        std.os.linux.EFD.CLOEXEC | std.os.linux.EFD.NONBLOCK,
    );
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        else => error.SystemCallFailed,
    };
}

fn signalEventFd(fd: std.posix.fd_t, value: u64) void {
    if (fd == -1) return;
    var writable_value = value;
    const written = osWrite(fd, std.mem.asBytes(&writable_value)) catch |err| {
        std.log.debug("sunglasses shutdown event write failed err={s}", .{@errorName(err)});
        return;
    };
    if (written != @as(u32, @intCast(@sizeOf(u64)))) {
        std.log.debug("sunglasses shutdown short write bytes={d}", .{written});
    }
}

fn osClose(fd: std.posix.fd_t) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) {
        std.log.debug("sunglasses shutdown fd close failed fd={d}", .{fd});
    }
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
