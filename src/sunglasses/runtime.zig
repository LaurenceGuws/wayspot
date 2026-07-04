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
const reconcile_lock_file_name = "sunglasses.reconcile.lock";
const max_pid_file_bytes: u32 = 32;
const max_proc_cmdline_bytes: u32 = 4096;
const daemon_stop_poll_sleep_ns: u64 = 10 * std.time.ns_per_ms;
const daemon_start_poll_sleep_ns: u64 = 10 * std.time.ns_per_ms;
const max_daemon_stop_polls: u32 = 100;
const max_daemon_start_polls: u32 = 100;
const daemon_child_fail_code: i32 = 127;
const max_daemon_wait_interrupts: u32 = 8;
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

    pub fn reconcileSavedState(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
        var lock = try ReconcileLock.acquire(allocator, runtime_dir);
        defer lock.deinit(allocator);

        const state = try sunglasses_state.load(allocator);
        const pid_path = try sunglassesPidPath(allocator, runtime_dir);
        defer allocator.free(pid_path);

        const process_state = daemonProcessState(pid_path);
        switch (process_state) {
            .stale => removePidFile(pid_path),
            else => {},
        }

        const process_live = process_state == .live;
        switch (reconcileAction(state.needsDaemon(), process_live)) {
            .idle => {},
            .wake => try sendSignal(process_state.live, .USR1),
            .start => try startDaemonAndWait(allocator, pid_path),
            .stop => try stopDaemon(pid_path, process_state.live),
        }
    }

    fn startDaemon(self: *Runtime, hypr: hyprland.Connection) !void {
        var state = try sunglasses_state.load(self.allocator);
        if (!state.needsDaemon()) return;

        try self.startSdl();
        var runtime_signals = try RuntimeSignals.init();
        defer runtime_signals.deinit();
        try runtime_signals.start();
        var pid_file = try PidFile.create(self.allocator, hypr.runtime_dir);
        defer pid_file.deinit(self.allocator);

        var monitor_watcher = try MonitorWatcher.init(self.allocator, hypr);
        defer monitor_watcher.deinit();
        try monitor_watcher.start();

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
                    if (!state.needsDaemon()) return;
                    try self.redrawSurfaceSlots(state);
                },
                .monitor_changed => {
                    state.* = try sunglasses_state.load(self.allocator);
                    if (!state.needsDaemon()) return;
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

const DaemonProcessState = union(enum) {
    absent,
    stale,
    live: std.os.linux.pid_t,
};

const ReconcileAction = enum {
    idle,
    wake,
    start,
    stop,
};

fn reconcileAction(needs_daemon: bool, process_live: bool) ReconcileAction {
    if (needs_daemon) return if (process_live) .wake else .start;
    return if (process_live) .stop else .idle;
}

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

const ReconcileLock = struct {
    path: []u8,
    file: std.Io.File,

    fn acquire(allocator: std.mem.Allocator, runtime_dir: []const u8) !ReconcileLock {
        const dir_path = try sunglassesPidDirPath(allocator, runtime_dir);
        defer allocator.free(dir_path);
        try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, dir_path);

        const lock_path = try sunglassesReconcileLockPath(allocator, runtime_dir);
        errdefer allocator.free(lock_path);

        const io = std.Options.debug_io;
        const file = try std.Io.Dir.createFileAbsolute(io, lock_path, .{ .truncate = false });
        errdefer file.close(io);
        try flockExclusive(file.handle);
        return .{ .path = lock_path, .file = file };
    }

    fn deinit(self: *ReconcileLock, allocator: std.mem.Allocator) void {
        unlockFile(self.file.handle);
        self.file.close(std.Options.debug_io);
        allocator.free(self.path);
    }
};

fn sunglassesPidDirPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, pid_dir_name });
}

fn sunglassesPidPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ runtime_dir, pid_dir_name, pid_file_name });
}

fn sunglassesReconcileLockPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ runtime_dir, pid_dir_name, reconcile_lock_file_name });
}

fn readSunglassesPid(pid_path: []const u8) !std.os.linux.pid_t {
    var buf: [max_pid_file_bytes]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFile(std.Options.debug_io, pid_path, &buf);
    const text = std.mem.trim(u8, bytes, " \n\r\t");
    return std.fmt.parseInt(std.os.linux.pid_t, text, 10);
}

fn daemonProcessState(pid_path: []const u8) DaemonProcessState {
    const pid = readSunglassesPid(pid_path) catch |err| switch (err) {
        error.FileNotFound => return .absent,
        else => return .stale,
    };
    if (!processLooksLikeSunglassesDaemon(pid)) return .stale;
    return .{ .live = pid };
}

fn processLooksLikeSunglassesDaemon(pid: std.os.linux.pid_t) bool {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/proc/{d}/cmdline", .{pid}) catch return false;
    var cmdline_buf: [max_proc_cmdline_bytes]u8 = undefined;
    const cmdline = std.Io.Dir.cwd().readFile(std.Options.debug_io, path, &cmdline_buf) catch return false;
    return cmdlineLooksLikeSunglassesDaemon(cmdline);
}

fn cmdlineLooksLikeSunglassesDaemon(cmdline: []const u8) bool {
    var has_binary = false;
    var has_daemon_arg = false;
    var args = std.mem.splitScalar(u8, cmdline, 0);
    while (args.next()) |arg| {
        if (arg.len == 0) continue;
        if (std.mem.eql(u8, arg, "--sunglasses-daemon")) {
            has_daemon_arg = true;
            continue;
        }
        if (std.mem.eql(u8, std.fs.path.basename(arg), "wayspot")) {
            has_binary = true;
        }
    }
    return has_binary and has_daemon_arg;
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

fn stopDaemon(pid_path: []const u8, pid: std.os.linux.pid_t) !void {
    sendSignal(pid, .TERM) catch |err| switch (err) {
        error.SunglassesDaemonNotRunning => {
            removePidFile(pid_path);
            return;
        },
        else => return err,
    };

    var polls: u32 = 0;
    while (polls < max_daemon_stop_polls) : (polls += 1) {
        if (!processLooksLikeSunglassesDaemon(pid)) {
            removePidFile(pid_path);
            return;
        }
        sleepNs(daemon_stop_poll_sleep_ns);
    }
    return error.SunglassesDaemonStillRunning;
}

fn startDaemonAndWait(allocator: std.mem.Allocator, pid_path: []const u8) !void {
    try startDaemonDetached(allocator);
    var polls: u32 = 0;
    while (polls < max_daemon_start_polls) : (polls += 1) {
        switch (daemonProcessState(pid_path)) {
            .live => return,
            .stale => {
                removePidFile(pid_path);
                return error.SunglassesDaemonStartFailed;
            },
            .absent => sleepNs(daemon_start_poll_sleep_ns),
        }
    }
    return error.SunglassesDaemonStartTimedOut;
}

fn startDaemonDetached(allocator: std.mem.Allocator) !void {
    const exe_path_z = try selfExePathZ(allocator);
    defer allocator.free(exe_path_z);

    const wrapper_pid = try forkProcess();
    if (wrapper_pid == 0) daemonWrapperChild(exe_path_z);
    try waitProcess(wrapper_pid);
}

fn selfExePathZ(allocator: std.mem.Allocator) ![:0]u8 {
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const path_len = try std.Io.Dir.readLinkAbsolute(std.Options.debug_io, "/proc/self/exe", &path_buf);
    return try allocator.dupeZ(u8, path_buf[0..path_len]);
}

fn daemonWrapperChild(exe_path_z: [:0]const u8) noreturn {
    const stdio_ok = redirectStdioToNull();
    if (!stdio_ok) std.c._exit(daemon_child_fail_code);

    const session_id = std.c.setsid();
    if (session_id == -1) std.c._exit(daemon_child_fail_code);

    const daemon_pid = forkProcess() catch std.c._exit(daemon_child_fail_code);
    if (daemon_pid == 0) execSunglassesDaemon(exe_path_z);

    std.c._exit(0);
}

fn execSunglassesDaemon(exe_path_z: [:0]const u8) noreturn {
    const daemon_arg = "--sunglasses-daemon";
    const argv: [3:null]?[*:0]const u8 = .{
        exe_path_z.ptr,
        daemon_arg,
        null,
    };
    const exec_rc = std.c.execve(exe_path_z.ptr, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(daemon_child_fail_code);
    std.c._exit(daemon_child_fail_code);
}

fn redirectStdioToNull() bool {
    const dev_null = std.c.open("/dev/null", .{ .ACCMODE = .RDWR, .CLOEXEC = false });
    if (dev_null == -1) return false;

    const stdin_rc = std.c.dup2(dev_null, 0);
    const stdout_rc = std.c.dup2(dev_null, 1);
    const stderr_rc = std.c.dup2(dev_null, 2);
    const close_rc = std.c.close(dev_null);
    if (stdin_rc == -1) return false;
    if (stdout_rc == -1) return false;
    if (stderr_rc == -1) return false;
    if (close_rc == -1) return false;
    return true;
}

fn forkProcess() !std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn waitProcess(pid: std.c.pid_t) !void {
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_daemon_wait_interrupts) {
        const waited = std.c.waitpid(pid, &status, 0);
        if (waited == pid) break;
        if (waited == -1) {
            const errno = std.c._errno().*;
            if (errno == @intFromEnum(std.c.E.INTR)) {
                interrupts += 1;
                continue;
            }
            return error.WaitFailed;
        }
        return error.WaitFailed;
    } else {
        return error.WaitInterruptedTooOften;
    }
    const status_bits: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(status_bits)) return error.CommandFailed;
    if (std.c.W.EXITSTATUS(status_bits) != 0) return error.CommandFailed;
}

fn flockExclusive(fd: std.c.fd_t) !void {
    while (true) switch (std.c.errno(std.c.flock(fd, std.c.LOCK.EX))) {
        .SUCCESS => return,
        .INTR => {},
        .BADF => return error.SystemCallFailed,
        .INVAL => return error.SystemCallFailed,
        .NOLCK => return error.SystemCallFailed,
        .OPNOTSUPP => return error.SystemCallFailed,
        else => return error.SystemCallFailed,
    };
}

fn unlockFile(fd: std.c.fd_t) void {
    while (true) switch (std.c.errno(std.c.flock(fd, std.c.LOCK.UN))) {
        .SUCCESS => return,
        .INTR => {},
        else => return,
    };
}

fn sleepNs(ns: u64) void {
    var request = std.c.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    while (std.c.nanosleep(&request, &request) == -1) {
        const errno = std.c._errno().*;
        if (errno != @intFromEnum(std.c.E.INTR)) return;
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

test "sunglasses daemon cmdline check requires exact argv entries" {
    try std.testing.expect(cmdlineLooksLikeSunglassesDaemon("/home/home/.local/bin/wayspot\x00--sunglasses-daemon\x00"));
    try std.testing.expect(!cmdlineLooksLikeSunglassesDaemon("bash\x00-c\x00wayspot --sunglasses-daemon\x00"));
    try std.testing.expect(!cmdlineLooksLikeSunglassesDaemon("/home/home/.local/bin/wayspot\x00--sunglasses-apply\x00"));
}

test "sunglasses runtime reconciliation action follows saved state need and live process" {
    try std.testing.expectEqual(ReconcileAction.idle, reconcileAction(false, false));
    try std.testing.expectEqual(ReconcileAction.stop, reconcileAction(false, true));
    try std.testing.expectEqual(ReconcileAction.start, reconcileAction(true, false));
    try std.testing.expectEqual(ReconcileAction.wake, reconcileAction(true, true));
}

test "sunglasses reconcile lock path stays beside pid file" {
    const path = try sunglassesReconcileLockPath(std.testing.allocator, "/run/user/1000");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/run/user/1000/wayspot/sunglasses.reconcile.lock", path);
}
