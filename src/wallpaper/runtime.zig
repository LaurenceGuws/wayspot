//! Wallpaper runtime owns monitor surface slots, the random timer, and shutdown order.

const std = @import("std");
const config_owner = @import("config.zig");
const hyprland = @import("hyprland.zig");
const library_owner = @import("library.zig");
const sdl_wallpaper_surface = @import("../ui/sdl_wallpaper_surface.zig");

const c = @import("sdl_c");

const proof_runtime_ms: u64 = 10_000;
const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
const monitor_eventfd_stop_value: u64 = 1;
const monitor_changed_event_type: u32 = @intCast(c.SDL_EVENT_USER + 31);
const monitor_focused_event_type: u32 = @intCast(c.SDL_EVENT_USER + 32);
var shutdown_handler_fd = std.atomic.Value(std.posix.fd_t).init(-1);

comptime {
    std.debug.assert(shutdown_eventfd_stop_value > 0);
    std.debug.assert(shutdown_eventfd_signal_value > 0);
    std.debug.assert(monitor_eventfd_stop_value > 0);
}

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    slots: [hyprland.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    sdl_started: bool = false,

    /// Each surface slot is created once for one monitor generation and destroyed by Runtime.deinit.
    pub fn runLifecycleProof(allocator: std.mem.Allocator, hypr: hyprland.Connection) !void {
        var runtime = Runtime{ .allocator = allocator };
        defer runtime.deinit();
        try runtime.startProof(hypr);
    }

    pub fn runWallpaper(allocator: std.mem.Allocator, hypr: hyprland.Connection) !void {
        var config = try config_owner.load(allocator);
        defer config.deinit(allocator);

        var library = try library_owner.scan(allocator, config.library_path);
        defer library.deinit(allocator);
        if (library.records.items.len == 0) return error.EmptyWallpaperLibrary;

        var runtime = Runtime{ .allocator = allocator };
        defer runtime.deinit();
        try runtime.startWallpaper(hypr, &library, config.interval_seconds);
    }

    fn startProof(self: *Runtime, hypr: hyprland.Connection) !void {
        const monitors = try hyprland.queryMonitors(self.allocator, hypr);
        if (monitors.count == 0) return error.NoHyprlandMonitors;

        try self.startSdl();
        var shutdown_signal = try ShutdownSignal.init();
        defer shutdown_signal.deinit();
        try shutdown_signal.start();

        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            const surface = try sdl_wallpaper_surface.WallpaperSurface.init(monitor, 1);
            self.slots[self.slot_count] = SurfaceSlot{
                .surface = surface,
                .state = .created,
            };
            self.slot_count += 1;
        }

        try waitUntilDeadline(proof_runtime_ms);
    }

    fn startWallpaper(self: *Runtime, hypr: hyprland.Connection, library: *const library_owner.Library, interval_seconds: u32) !void {
        try self.startSdl();
        var shutdown_signal = try ShutdownSignal.init();
        defer shutdown_signal.deinit();
        try shutdown_signal.start();

        var monitor_watcher = try MonitorWatcher.init(self.allocator, hypr);
        defer monitor_watcher.deinit();
        try monitor_watcher.start();

        var prng = std.Random.DefaultPrng.init(c.SDL_GetTicks());
        const random = prng.random();
        try self.rebuildSurfaceSlots(hypr, library, random);

        try self.runRandomTimer(hypr, library, random, interval_seconds);
    }

    fn startSdl(self: *Runtime) !void {
        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, sdl_wallpaper_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        self.sdl_started = true;
    }

    fn runRandomTimer(self: *Runtime, hypr: hyprland.Connection, library: *const library_owner.Library, random: std.Random, interval_seconds: u32) !void {
        const interval_ms = @as(u64, interval_seconds) * 1000;
        var next_deadline = c.SDL_GetTicks() + interval_ms;
        while (true) {
            switch (waitForRuntimeWake(next_deadline)) {
                .shutdown => return,
                .deadline => {
                    try self.drawRandomImages(library, random);
                    next_deadline = c.SDL_GetTicks() + interval_ms;
                },
                .monitor_changed => {
                    try self.rebuildSurfaceSlots(hypr, library, random);
                },
                .monitor_focused => {},
            }
        }
    }

    fn rebuildSurfaceSlots(self: *Runtime, hypr: hyprland.Connection, library: *const library_owner.Library, random: std.Random) !void {
        const monitors = try hyprland.queryMonitors(self.allocator, hypr);
        if (monitors.count == 0) return error.NoHyprlandMonitors;

        self.clearSurfaceSlots();
        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            const surface = try sdl_wallpaper_surface.WallpaperSurface.init(monitor, 1);
            self.slots[self.slot_count] = SurfaceSlot{
                .surface = surface,
                .state = .created,
            };
            self.slot_count += 1;
            try self.slots[self.slot_count - 1].drawRandomImage(library, random);
        }
    }

    fn drawRandomImages(self: *Runtime, library: *const library_owner.Library, random: std.Random) !void {
        var index: u32 = 0;
        while (index < self.slot_count) : (index += 1) {
            try self.slots[index].drawRandomImage(library, random);
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
    surface: sdl_wallpaper_surface.WallpaperSurface,
    state: enum { empty, created } = .empty,

    fn deinit(self: *SurfaceSlot) void {
        if (self.state == .created) {
            self.surface.deinit();
            self.state = .empty;
        }
    }

    fn drawRandomImage(self: *SurfaceSlot, library: *const library_owner.Library, random: std.Random) !void {
        const record = library.chooseRandom(random) orelse return error.EmptyWallpaperLibrary;
        var path_buf: [library_owner.max_path_bytes + 1:0]u8 = undefined;
        const path = try std.fmt.bufPrintZ(&path_buf, "{s}", .{record.path});
        try self.surface.drawImage(path);
    }
};

fn waitUntilDeadline(duration_ms: u64) !void {
    const deadline = c.SDL_GetTicks() + duration_ms;
    if (waitForShutdownOrDeadline(deadline)) return;
}

fn waitForShutdownOrDeadline(deadline: u64) bool {
    while (true) {
        const now = c.SDL_GetTicks();
        if (now >= deadline) return false;
        const remaining = deadline - now;
        const timeout: i32 = @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEventTimeout(&event, timeout)) {
            if (event.type == c.SDL_EVENT_QUIT or
                event.type == c.SDL_EVENT_TERMINATING or
                event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED)
            {
                return true;
            }
            while (c.SDL_PollEvent(&event)) {
                if (event.type == c.SDL_EVENT_QUIT or
                    event.type == c.SDL_EVENT_TERMINATING or
                    event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED)
                {
                    return true;
                }
            }
        }
    }
}

const RuntimeWake = enum {
    shutdown,
    deadline,
    monitor_changed,
    monitor_focused,
};

fn waitForRuntimeWake(deadline: u64) RuntimeWake {
    while (true) {
        const now = c.SDL_GetTicks();
        if (now >= deadline) return .deadline;
        const remaining = deadline - now;
        const timeout: i32 = @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEventTimeout(&event, timeout)) {
            if (eventIsShutdown(event)) return .shutdown;
            if (event.type == monitor_changed_event_type) return .monitor_changed;
            if (event.type == monitor_focused_event_type) return .monitor_focused;
            while (c.SDL_PollEvent(&event)) {
                if (eventIsShutdown(event)) return .shutdown;
                if (event.type == monitor_changed_event_type) return .monitor_changed;
                if (event.type == monitor_focused_event_type) return .monitor_focused;
            }
        }
    }
}

fn eventIsShutdown(event: c.SDL_Event) bool {
    return event.type == c.SDL_EVENT_QUIT or
        event.type == c.SDL_EVENT_TERMINATING or
        event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
}

/// MonitorWatcher converts Hyprland socket2 monitor events into SDL wake events owned by Runtime.
const MonitorWatcher = struct {
    stream: hyprland.EventStream,
    stop_fd: std.posix.fd_t = -1,
    thread: ?std.Thread = null,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init(allocator: std.mem.Allocator, hypr: hyprland.Connection) !MonitorWatcher {
        var stream = try hyprland.EventStream.init(allocator, hypr);
        errdefer stream.deinit();
        return .{
            .stream = stream,
            .stop_fd = try osEventFd(),
        };
    }

    fn start(self: *MonitorWatcher) !void {
        std.debug.assert(self.stop_fd != -1);
        self.thread = try std.Thread.spawn(.{}, monitorWatcherMain, .{self});
    }

    fn stop(self: *MonitorWatcher) void {
        self.stop_requested.store(true, .release);
        if (self.thread) |thread| {
            signalEventFd(self.stop_fd, monitor_eventfd_stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.stop_fd != -1) {
            osClose(self.stop_fd);
            self.stop_fd = -1;
        }
    }

    fn deinit(self: *MonitorWatcher) void {
        self.stop();
        self.stream.deinit();
    }
};

fn monitorWatcherMain(watcher: *MonitorWatcher) void {
    while (!watcher.stop_requested.load(.acquire)) {
        const event = watcher.stream.wait(watcher.stop_fd) catch |err| {
            if (watcher.stop_requested.load(.acquire)) return;
            std.log.warn("wallpaper monitor event stream failed err={s}", .{@errorName(err)});
            pushSdlQuit();
            return;
        };
        switch (event) {
            .stopped => return,
            .monitor_changed => pushSdlUserEvent(monitor_changed_event_type),
            .focused_monitor => pushSdlUserEvent(monitor_focused_event_type),
        }
    }
}

fn pushSdlUserEvent(event_type: u32) void {
    var event = c.SDL_Event{ .user = .{
        .type = event_type,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("wallpaper monitor event wake failed type={d}", .{event_type});
    }
}

fn pushSdlQuit() void {
    var event = c.SDL_Event{ .quit = .{
        .type = c.SDL_EVENT_QUIT,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("wallpaper quit wake failed", .{});
    }
}

/// ShutdownSignal turns SIGINT and SIGTERM into one SDL quit event owned by wallpaper runtime.
const ShutdownSignal = struct {
    event_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    shutdown_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init() !ShutdownSignal {
        return .{
            .event_fd = try osEventFd(),
        };
    }

    fn start(self: *ShutdownSignal) !void {
        std.debug.assert(self.event_fd != -1);
        shutdown_handler_fd.store(self.event_fd, .release);
        self.installHandlers();
        self.thread = try std.Thread.spawn(.{}, shutdownSignalMain, .{self});
    }

    fn stop(self: *ShutdownSignal) void {
        self.stop_requested.store(true, .release);
        if (self.installed) {
            self.restoreHandlers();
            self.installed = false;
        }
        shutdown_handler_fd.store(-1, .release);
        if (self.thread) |thread| {
            signalEventFd(self.event_fd, shutdown_eventfd_stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.event_fd != -1) {
            osClose(self.event_fd);
            self.event_fd = -1;
        }
    }

    fn deinit(self: *ShutdownSignal) void {
        self.stop();
    }

    fn installHandlers(self: *ShutdownSignal) void {
        var action = std.posix.Sigaction{
            .handler = .{ .handler = shutdownSignalHandler },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(.INT, &action, &self.old_int_action);
        std.posix.sigaction(.TERM, &action, &self.old_term_action);
        self.installed = true;
    }

    fn restoreHandlers(self: *ShutdownSignal) void {
        std.posix.sigaction(.INT, &self.old_int_action, null);
        std.posix.sigaction(.TERM, &self.old_term_action, null);
    }

    fn pushShutdownWake(self: *ShutdownSignal, signo: u32) void {
        self.shutdown_requested.store(true, .release);
        var event = c.SDL_Event{ .quit = .{
            .type = c.SDL_EVENT_QUIT,
        } };
        const pushed = c.SDL_PushEvent(&event);
        if (!pushed) {
            std.log.warn("wallpaper shutdown wake failed signo={d}", .{signo});
        }
    }
};

fn shutdownSignalHandler(signal: std.posix.SIG) callconv(.c) void {
    if (signal != .INT and signal != .TERM) return;
    const fd = shutdown_handler_fd.load(.acquire);
    if (fd == -1) return;
    var value: u64 = shutdown_eventfd_signal_value;
    const written = std.os.linux.write(fd, std.mem.asBytes(&value).ptr, @sizeOf(u64));
    if (std.os.linux.errno(written) != .SUCCESS) return;
}

fn shutdownSignalMain(shutdown_signal: *ShutdownSignal) void {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = shutdown_signal.event_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (!shutdown_signal.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        const ready = osPoll(&poll_fds, shutdown_signal_poll_timeout_ms) catch |err| {
            std.log.warn("wallpaper shutdown poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        var event_count: u64 = 0;
        const event_bytes = osRead(shutdown_signal.event_fd, std.mem.asBytes(&event_count)) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("wallpaper shutdown read failed err={s}", .{@errorName(err)});
            return;
        };
        if (event_bytes != @as(u32, @intCast(@sizeOf(u64)))) {
            std.log.warn("wallpaper shutdown short read bytes={d}", .{event_bytes});
            return;
        }
        if (shutdown_signal.stop_requested.load(.acquire)) return;
        shutdown_signal.pushShutdownWake(@intFromEnum(std.posix.SIG.TERM));
        return;
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
        std.log.debug("wallpaper shutdown event write failed err={s}", .{@errorName(err)});
        return;
    };
    if (written != @as(u32, @intCast(@sizeOf(u64)))) {
        std.log.debug("wallpaper shutdown short write bytes={d}", .{written});
    }
}

fn osClose(fd: std.posix.fd_t) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) {
        std.log.debug("wallpaper shutdown fd close failed fd={d}", .{fd});
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
