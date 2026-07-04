//! Sunglasses runtime owns overlay slots, apply wakes, and shutdown cleanup order.

const std = @import("std");
const hyprland = @import("../wallpaper/hyprland.zig");
const sunglasses_state = @import("state.zig");
const sdl_sunglasses_surface = @import("../ui/sdl_sunglasses_surface.zig");

const c = @import("sdl_c");

const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
const apply_eventfd_signal_value: u64 = 1;
const monitor_eventfd_stop_value: u64 = 1;
const monitor_changed_event_type: u32 = @intCast(c.SDL_EVENT_USER + 41);
const sunglasses_apply_event_type: u32 = @intCast(c.SDL_EVENT_USER + 42);
const pid_dir_name = "wayspot";
const pid_file_name = "sunglasses.pid";
const max_pid_file_bytes: u32 = 32;
const max_proc_cmdline_bytes: u32 = 4096;
var runtime_signal_shutdown_fd = std.atomic.Value(std.posix.fd_t).init(-1);
var runtime_signal_apply_fd = std.atomic.Value(std.posix.fd_t).init(-1);

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    slots: [hyprland.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    sdl_started: bool = false,

    pub fn runDaemon(allocator: std.mem.Allocator, hypr: hyprland.Connection) !void {
        var runtime = Runtime{ .allocator = allocator };
        defer runtime.deinit();
        try runtime.startDaemon(hypr);
    }

    pub fn applyNow(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
        const pid_path = try sunglassesPidPath(allocator, runtime_dir);
        defer allocator.free(pid_path);
        const pid = try readSunglassesPid(pid_path);
        if (!processLooksLikeSunglassesDaemon(pid)) {
            removePidFile(pid_path);
            return error.SunglassesDaemonNotRunning;
        }
        try sendSignal(pid, .USR1);
    }

    fn startDaemon(self: *Runtime, hypr: hyprland.Connection) !void {
        try self.startSdl();
        var runtime_signals = try RuntimeSignals.init();
        defer runtime_signals.deinit();
        try runtime_signals.start();
        var pid_file = try PidFile.create(self.allocator, hypr.runtime_dir);
        defer pid_file.deinit(self.allocator);

        var monitor_watcher = try MonitorWatcher.init(self.allocator, hypr);
        defer monitor_watcher.deinit();
        try monitor_watcher.start();

        var state = try sunglasses_state.load(self.allocator);
        try self.rebuildSurfaceSlots(hypr, &state);
        try self.runApplyLoop(hypr, &state);
    }

    fn startSdl(self: *Runtime) !void {
        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, sdl_sunglasses_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        self.sdl_started = true;
    }

    fn runApplyLoop(self: *Runtime, hypr: hyprland.Connection, state: *sunglasses_state.State) !void {
        while (true) {
            switch (try waitForRuntimeWake()) {
                .shutdown => return,
                .apply => {
                    state.* = try sunglasses_state.load(self.allocator);
                    try self.redrawSurfaceSlots(state);
                },
                .monitor_changed => {
                    state.* = try sunglasses_state.load(self.allocator);
                    try self.rebuildSurfaceSlots(hypr, state);
                },
            }
        }
    }

    fn rebuildSurfaceSlots(self: *Runtime, hypr: hyprland.Connection, state: *const sunglasses_state.State) !void {
        const monitors = try hyprland.queryMonitors(self.allocator, hypr);
        if (monitors.count == 0) return error.NoHyprlandMonitors;

        self.clearSurfaceSlots();
        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            self.slots[self.slot_count] = .{
                .surface = try sdl_sunglasses_surface.SunglassesSurface.init(monitor, state.get(monitor.name())),
            };
            self.slot_count += 1;
        }
    }

    fn redrawSurfaceSlots(self: *Runtime, state: *const sunglasses_state.State) !void {
        var index: u32 = 0;
        while (index < self.slot_count) : (index += 1) {
            const monitor_name = self.slots[index].surface.monitor.name();
            try self.slots[index].redraw(state.get(monitor_name));
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

    fn redraw(self: *SurfaceSlot, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        try self.surface.redraw(monitor_state);
    }
};

const RuntimeWake = enum {
    shutdown,
    apply,
    monitor_changed,
};

fn waitForRuntimeWake() !RuntimeWake {
    while (true) {
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEvent(&event)) {
            if (eventIsShutdown(event)) return .shutdown;
            if (event.type == sunglasses_apply_event_type) return .apply;
            if (event.type == monitor_changed_event_type) return .monitor_changed;
            while (c.SDL_PollEvent(&event)) {
                if (eventIsShutdown(event)) return .shutdown;
                if (event.type == sunglasses_apply_event_type) return .apply;
                if (event.type == monitor_changed_event_type) return .monitor_changed;
            }
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

/// MonitorWatcher converts Hyprland monitor events into SDL redraw wakes owned by Runtime.
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
            std.log.warn("sunglasses monitor event stream failed err={s}", .{@errorName(err)});
            pushSdlQuit();
            return;
        };
        switch (event) {
            .stopped => return,
            .monitor_changed => pushSdlUserEvent(monitor_changed_event_type),
        }
    }
}

fn pushSdlUserEvent(event_type: u32) void {
    var event = c.SDL_Event{ .user = .{
        .type = event_type,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("sunglasses user wake failed type={d}", .{event_type});
    }
}

fn pushSdlQuit() void {
    var event = c.SDL_Event{ .quit = .{
        .type = c.SDL_EVENT_QUIT,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("sunglasses quit wake failed", .{});
    }
}

/// RuntimeSignals converts process termination into the SDL event loop shutdown path.
const RuntimeSignals = struct {
    shutdown_fd: std.posix.fd_t = -1,
    apply_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    old_usr1_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init() !RuntimeSignals {
        const shutdown_fd = try osEventFd();
        errdefer osClose(shutdown_fd);
        const apply_fd = try osEventFd();
        return .{
            .shutdown_fd = shutdown_fd,
            .apply_fd = apply_fd,
        };
    }

    fn start(self: *RuntimeSignals) !void {
        std.debug.assert(self.shutdown_fd != -1);
        std.debug.assert(self.apply_fd != -1);
        runtime_signal_shutdown_fd.store(self.shutdown_fd, .release);
        runtime_signal_apply_fd.store(self.apply_fd, .release);
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
        runtime_signal_apply_fd.store(-1, .release);
        if (self.thread) |thread| {
            signalEventFd(self.shutdown_fd, shutdown_eventfd_stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.shutdown_fd != -1) {
            osClose(self.shutdown_fd);
            self.shutdown_fd = -1;
        }
        if (self.apply_fd != -1) {
            osClose(self.apply_fd);
            self.apply_fd = -1;
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
        std.posix.sigaction(.USR1, &action, &self.old_usr1_action);
        self.installed = true;
    }

    fn restoreHandlers(self: *RuntimeSignals) void {
        std.posix.sigaction(.INT, &self.old_int_action, null);
        std.posix.sigaction(.TERM, &self.old_term_action, null);
        std.posix.sigaction(.USR1, &self.old_usr1_action, null);
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

    fn pushApplyWake() void {
        var event = c.SDL_Event{ .user = .{
            .type = sunglasses_apply_event_type,
        } };
        const pushed = c.SDL_PushEvent(&event);
        if (!pushed) {
            std.log.warn("sunglasses apply wake failed", .{});
        }
    }
};

fn runtimeSignalHandler(signal: std.posix.SIG) callconv(.c) void {
    const fd = switch (signal) {
        .INT, .TERM => runtime_signal_shutdown_fd.load(.acquire),
        .USR1 => runtime_signal_apply_fd.load(.acquire),
        else => return,
    };
    if (fd == -1) return;
    var value: u64 = if (signal == .USR1) apply_eventfd_signal_value else shutdown_eventfd_signal_value;
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
        .{
            .fd = runtime_signals.apply_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (!runtime_signals.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        poll_fds[1].revents = 0;
        const ready = osPoll(&poll_fds, shutdown_signal_poll_timeout_ms) catch |err| {
            std.log.warn("sunglasses signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[1].revents & std.posix.POLL.IN) != 0) {
            drainEventFd(runtime_signals.apply_fd) catch |err| {
                std.log.warn("sunglasses apply read failed err={s}", .{@errorName(err)});
                return;
            };
            if (runtime_signals.stop_requested.load(.acquire)) return;
            RuntimeSignals.pushApplyWake();
        }
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

const PidFile = struct {
    path: []u8,

    fn create(allocator: std.mem.Allocator, runtime_dir: []const u8) !PidFile {
        const dir_path = try sunglassesPidDirPath(allocator, runtime_dir);
        defer allocator.free(dir_path);
        try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, dir_path);

        const pid_path = try sunglassesPidPath(allocator, runtime_dir);
        errdefer allocator.free(pid_path);

        const io = std.Options.debug_io;
        const file = try std.Io.Dir.createFileAbsolute(io, pid_path, .{ .truncate = true });
        defer file.close(io);

        var buf: [max_pid_file_bytes]u8 = undefined;
        const pid_text = try std.fmt.bufPrint(&buf, "{d}\n", .{std.os.linux.getpid()});
        try file.writeStreamingAll(io, pid_text);
        try file.sync(io);
        return .{ .path = pid_path };
    }

    fn deinit(self: *PidFile, allocator: std.mem.Allocator) void {
        removePidFile(self.path);
        allocator.free(self.path);
    }
};

fn sunglassesPidDirPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, pid_dir_name });
}

fn sunglassesPidPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ runtime_dir, pid_dir_name, pid_file_name });
}

fn readSunglassesPid(pid_path: []const u8) !std.os.linux.pid_t {
    var buf: [max_pid_file_bytes]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFile(std.Options.debug_io, pid_path, &buf);
    const text = std.mem.trim(u8, bytes, " \n\r\t");
    return std.fmt.parseInt(std.os.linux.pid_t, text, 10);
}

fn processLooksLikeSunglassesDaemon(pid: std.os.linux.pid_t) bool {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/proc/{d}/cmdline", .{pid}) catch return false;
    var cmdline_buf: [max_proc_cmdline_bytes]u8 = undefined;
    const cmdline = std.Io.Dir.cwd().readFile(std.Options.debug_io, path, &cmdline_buf) catch return false;
    return std.mem.indexOf(u8, cmdline, "wayspot") != null and
        std.mem.indexOf(u8, cmdline, "--sunglasses-daemon") != null;
}

fn removePidFile(pid_path: []const u8) void {
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, pid_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.debug("sunglasses pid file remove failed err={s}", .{@errorName(err)}),
    };
}

fn sendSignal(pid: std.os.linux.pid_t, signal: std.os.linux.SIG) !void {
    const rc = std.os.linux.kill(pid, signal);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .SRCH => error.SunglassesDaemonNotRunning,
        else => error.SystemCallFailed,
    };
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
