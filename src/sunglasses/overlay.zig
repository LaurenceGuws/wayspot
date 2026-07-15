//! Sunglasses overlay owns overlay slots, apply wakes, and shutdown cleanup order.

const std = @import("std");
const env = @import("wayspot_env");
const sunglasses_state = @import("state.zig");
const sunglasses_surface = @import("surface.zig");

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
const startup_status_file_name = "sunglasses.startup.status";
const max_pid_file_bytes: u32 = 32;
const max_startup_status_bytes: u32 = 96;
const max_proc_cmdline_bytes: u32 = 4096;
const overlay_stop_poll_sleep_ns: u64 = 10 * std.time.ns_per_ms;
const overlay_start_poll_sleep_ns: u64 = 10 * std.time.ns_per_ms;
const max_overlay_stop_polls: u32 = 100;
const max_overlay_start_polls: u32 = 100;
const overlay_child_fail_code: i32 = 127;
const max_child_wait_interrupts: u32 = 8;
var signal_shutdown_fd = std.atomic.Value(std.posix.fd_t).init(-1);
var signal_apply_fd = std.atomic.Value(std.posix.fd_t).init(-1);

pub const Overlay = struct {
    allocator: std.mem.Allocator,
    slots: [env.monitor.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    vendor_started: bool = false,

    pub fn runOverlay(allocator: std.mem.Allocator, monitor_source: env.MonitorSource) !void {
        var overlay = Overlay{ .allocator = allocator };
        defer overlay.deinit();
        try overlay.startOverlay(monitor_source);
    }

    pub fn applyNow(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
        const pid_path = try sunglassesPidPath(allocator, runtime_dir);
        defer allocator.free(pid_path);
        const pid = try readSunglassesPid(pid_path);
        if (!pidMatchesSunglassesOverlay(pid)) {
            removePidFile(pid_path);
            return error.SunglassesOverlayNotRunning;
        }
        try sendSignal(pid, .USR1);
    }

    pub fn reconcileSavedState(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
        const state = try sunglasses_state.State.load(allocator);
        const pid_path = try sunglassesPidPath(allocator, runtime_dir);
        defer allocator.free(pid_path);
        const status_path = try sunglassesStartupStatusPath(allocator, runtime_dir);
        defer allocator.free(status_path);

        const child_state = childState(pid_path);
        switch (child_state) {
            .stale => removePidFile(pid_path),
            else => {},
        }

        const child_live = child_state == .live;
        switch (reconcileAction(state.needsOverlay(), child_live)) {
            .idle => {},
            .wake => try sendSignal(child_state.live, .USR1),
            .start => try startOverlayAndWait(allocator, pid_path, status_path),
            .stop => try stopOverlay(pid_path, child_state.live),
        }
    }

    /// saveAndApply persists edited state, then starts, wakes, or stops the one overlay owner.
    pub fn saveAndApply(allocator: std.mem.Allocator, state: sunglasses_state.State) !void {
        try state.save(allocator);
        const runtime_dir_z = std.c.getenv("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try reconcileSavedState(allocator, std.mem.span(runtime_dir_z));
    }

    /// Records one bounded child startup failure beside the pid file for the parent poller.
    pub fn recordStartupFailure(allocator: std.mem.Allocator, runtime_dir: []const u8, err: anyerror) void {
        writeStartupStatus(allocator, runtime_dir, err) catch |write_err| {
            std.log.debug("sunglasses startup status write failed err={s}", .{@errorName(write_err)});
        };
    }

    fn startOverlay(self: *Overlay, monitor_source: env.MonitorSource) !void {
        var state = try sunglasses_state.State.load(self.allocator);
        if (!state.needsOverlay()) return;

        try self.startVendor();
        var signals = try OverlaySignals.init();
        defer signals.deinit();
        try signals.start();
        var pid_file = try PidFile.create(self.allocator, monitor_source.runtimeDir());
        defer pid_file.deinit(self.allocator);

        var monitor_watcher = try MonitorWatcher.init(self.allocator, monitor_source);
        defer monitor_watcher.deinit();
        try monitor_watcher.start();

        try self.rebuildSurfaceSlots(monitor_source, &state);
        try self.runApplyLoop(monitor_source, &state);
    }

    fn startVendor(self: *Overlay) !void {
        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, sunglasses_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        self.vendor_started = true;
    }

    fn runApplyLoop(self: *Overlay, monitor_source: env.MonitorSource, state: *sunglasses_state.State) !void {
        while (true) {
            switch (try waitForWake()) {
                .shutdown => return,
                .apply => {
                    state.* = try sunglasses_state.State.load(self.allocator);
                    if (!state.needsOverlay()) return;
                    try self.redrawSurfaceSlots(state);
                },
                .monitor_changed => {
                    state.* = try sunglasses_state.State.load(self.allocator);
                    if (!state.needsOverlay()) return;
                    try self.rebuildSurfaceSlots(monitor_source, state);
                },
            }
        }
    }

    fn rebuildSurfaceSlots(self: *Overlay, monitor_source: env.MonitorSource, state: *const sunglasses_state.State) !void {
        const monitors = try monitor_source.queryMonitors(self.allocator);
        if (monitors.count == 0) return error.NoEnvMonitors;

        self.clearSurfaceSlots();
        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            self.slots[self.slot_count] = .{
                .surface = try sunglasses_surface.SunglassesSurface.init(monitor, state.get(monitor.nameText())),
            };
            self.slot_count += 1;
        }
    }

    fn redrawSurfaceSlots(self: *Overlay, state: *const sunglasses_state.State) !void {
        var index: u32 = 0;
        while (index < self.slot_count) : (index += 1) {
            const monitor_name = self.slots[index].surface.monitor.nameText();
            try self.slots[index].redraw(state.get(monitor_name));
        }
    }

    fn clearSurfaceSlots(self: *Overlay) void {
        var index = self.slot_count;
        while (index > 0) {
            index -= 1;
            self.slots[index].deinit();
        }
        self.slot_count = 0;
    }

    pub fn deinit(self: *Overlay) void {
        self.clearSurfaceSlots();
        if (self.vendor_started) {
            c.SDL_Quit();
            self.vendor_started = false;
        }
    }
};

pub const SurfaceSlot = struct {
    surface: sunglasses_surface.SunglassesSurface,

    fn deinit(self: *SurfaceSlot) void {
        self.surface.deinit();
    }

    fn redraw(self: *SurfaceSlot, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        try self.surface.redraw(monitor_state);
    }
};

const OverlayWake = enum {
    shutdown,
    apply,
    monitor_changed,
};

const ChildState = union(enum) {
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

const StartupStatus = enum {
    sunglasses_image_load_failed,
    sunglasses_unsupported_image_extension,
    sunglasses_image_convert_failed,
    sunglasses_image_target_failed,
    sunglasses_image_scale_failed,
    sunglasses_image_opacity_invalid,
    sunglasses_invalid_buffer_size,
    sunglasses_memfd_failed,
    sunglasses_truncate_failed,
    sunglasses_mmap_failed,
    sunglasses_shm_pool_failed,
    sunglasses_wl_buffer_failed,
    layer_shell_missing,
    layer_shell_compositor_missing,
    layer_shell_shm_missing,
    layer_shell_output_missing,
    layer_shell_surface_create_failed,
    layer_shell_input_region_failed,
    no_env_monitors,
    sunglasses_overlay_start_failed,
};

fn reconcileAction(needs_overlay: bool, child_live: bool) ReconcileAction {
    if (needs_overlay) return if (child_live) .wake else .start;
    return if (child_live) .stop else .idle;
}

fn waitForWake() !OverlayWake {
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

/// MonitorWatcher converts env monitor fact changes into vendor redraw wakes owned by Overlay.
const MonitorWatcher = struct {
    stream: env.MonitorFactStream,
    stop_fd: std.posix.fd_t = -1,
    thread: ?std.Thread = null,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init(allocator: std.mem.Allocator, monitor_source: env.MonitorSource) !MonitorWatcher {
        var stream = try monitor_source.monitorStream(allocator);
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
        const wake = watcher.stream.wait(watcher.stop_fd) catch |err| {
            if (watcher.stop_requested.load(.acquire)) return;
            std.log.warn("sunglasses monitor event stream failed err={s}", .{@errorName(err)});
            pushVendorQuit();
            return;
        };
        switch (wake) {
            .stopped => return,
            .changed => pushVendorUserEvent(monitor_changed_event_type),
        }
    }
}

fn pushVendorUserEvent(event_type: u32) void {
    var event = c.SDL_Event{ .user = .{
        .type = event_type,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("sunglasses user wake failed type={d}", .{event_type});
    }
}

fn pushVendorQuit() void {
    var event = c.SDL_Event{ .quit = .{
        .type = c.SDL_EVENT_QUIT,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("sunglasses quit wake failed", .{});
    }
}

/// OverlaySignals converts signal termination into the vendor event loop shutdown path.
const OverlaySignals = struct {
    shutdown_fd: std.posix.fd_t = -1,
    apply_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    old_usr1_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init() !OverlaySignals {
        const shutdown_fd = try osEventFd();
        errdefer osClose(shutdown_fd);
        const apply_fd = try osEventFd();
        return .{
            .shutdown_fd = shutdown_fd,
            .apply_fd = apply_fd,
        };
    }

    fn start(self: *OverlaySignals) !void {
        std.debug.assert(self.shutdown_fd != -1);
        std.debug.assert(self.apply_fd != -1);
        signal_shutdown_fd.store(self.shutdown_fd, .release);
        signal_apply_fd.store(self.apply_fd, .release);
        self.installHandlers();
        self.thread = try std.Thread.spawn(.{}, signalsMain, .{self});
    }

    fn stop(self: *OverlaySignals) void {
        self.stop_requested.store(true, .release);
        if (self.installed) {
            self.restoreHandlers();
            self.installed = false;
        }
        signal_shutdown_fd.store(-1, .release);
        signal_apply_fd.store(-1, .release);
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

    fn deinit(self: *OverlaySignals) void {
        self.stop();
    }

    fn installHandlers(self: *OverlaySignals) void {
        var action = std.posix.Sigaction{
            .handler = .{ .handler = signalHandler },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };
        std.posix.sigaction(.INT, &action, &self.old_int_action);
        std.posix.sigaction(.TERM, &action, &self.old_term_action);
        std.posix.sigaction(.USR1, &action, &self.old_usr1_action);
        self.installed = true;
    }

    fn restoreHandlers(self: *OverlaySignals) void {
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

fn signalHandler(signal: std.posix.SIG) callconv(.c) void {
    const fd = switch (signal) {
        .INT, .TERM => signal_shutdown_fd.load(.acquire),
        .USR1 => signal_apply_fd.load(.acquire),
        else => return,
    };
    if (fd == -1) return;
    var value: u64 = if (signal == .USR1) apply_eventfd_signal_value else shutdown_eventfd_signal_value;
    const written = std.os.linux.write(fd, std.mem.asBytes(&value).ptr, @sizeOf(u64));
    if (std.os.linux.errno(written) != .SUCCESS) return;
}

fn signalsMain(signals: *OverlaySignals) void {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = signals.shutdown_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
        .{
            .fd = signals.apply_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (!signals.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        poll_fds[1].revents = 0;
        const ready = osPoll(&poll_fds, shutdown_signal_poll_timeout_ms) catch |err| {
            std.log.warn("sunglasses signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[1].revents & std.posix.POLL.IN) != 0) {
            drainEventFd(signals.apply_fd) catch |err| {
                std.log.warn("sunglasses apply read failed err={s}", .{@errorName(err)});
                return;
            };
            if (signals.stop_requested.load(.acquire)) return;
            OverlaySignals.pushApplyWake();
        }
        if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        drainEventFd(signals.shutdown_fd) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("sunglasses shutdown read failed err={s}", .{@errorName(err)});
            return;
        };
        if (signals.stop_requested.load(.acquire)) return;
        OverlaySignals.pushShutdownWake();
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
        const file = std.Io.Dir.createFileAbsolute(io, pid_path, .{ .truncate = true, .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => return error.SunglassesOverlayAlreadyRunning,
            else => return err,
        };
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

fn sunglassesStartupStatusPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ runtime_dir, pid_dir_name, startup_status_file_name });
}

fn readSunglassesPid(pid_path: []const u8) !std.os.linux.pid_t {
    var buf: [max_pid_file_bytes]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFile(std.Options.debug_io, pid_path, &buf);
    const text = std.mem.trim(u8, bytes, " \n\r\t");
    return std.fmt.parseInt(std.os.linux.pid_t, text, 10);
}

fn childState(pid_path: []const u8) ChildState {
    const pid = readSunglassesPid(pid_path) catch |err| switch (err) {
        error.FileNotFound => return .absent,
        else => return .stale,
    };
    if (!pidMatchesSunglassesOverlay(pid)) return .stale;
    return .{ .live = pid };
}

fn pidMatchesSunglassesOverlay(pid: std.os.linux.pid_t) bool {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/proc/{d}/cmdline", .{pid}) catch return false;
    var cmdline_buf: [max_proc_cmdline_bytes]u8 = undefined;
    const cmdline = std.Io.Dir.cwd().readFile(std.Options.debug_io, path, &cmdline_buf) catch return false;
    return cmdlineMatchesSunglassesOverlay(cmdline);
}

/// Returns true only for one exact sunglasses resident argv or the exact
/// legacy identity retained by the bounded rerun transition.
fn cmdlineMatchesSunglassesOverlay(cmdline: []const u8) bool {
    var has_binary = false;
    var resident_arg: []const u8 = "";
    var extra_argument = false;
    var argument_index: usize = 0;
    var arg_start: usize = 0;
    while (arg_start < cmdline.len) {
        var arg_end = arg_start;
        while (arg_end < cmdline.len and cmdline[arg_end] != 0) : (arg_end += 1) {}
        const arg = cmdline[arg_start..arg_end];
        switch (argument_index) {
            0 => has_binary = std.mem.eql(u8, std.fs.path.basename(arg), "wayspot"),
            1 => resident_arg = arg,
            else => extra_argument = true,
        }
        argument_index += 1;
        if (arg_end == cmdline.len) break;
        arg_start = arg_end + 1;
    }
    if (!has_binary or extra_argument or argument_index != 2) return false;
    return std.mem.eql(u8, resident_arg, "sunglasses") or
        std.mem.eql(u8, resident_arg, "--sunglasses-daemon");
}

fn removePidFile(pid_path: []const u8) void {
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, pid_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.debug("sunglasses pid file remove failed err={s}", .{@errorName(err)}),
    };
}

fn removeStartupStatus(status_path: []const u8) void {
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, status_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.debug("sunglasses startup status remove failed err={s}", .{@errorName(err)}),
    };
}

fn sendSignal(pid: std.os.linux.pid_t, signal: std.os.linux.SIG) !void {
    const rc = std.os.linux.kill(pid, signal);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .SRCH => error.SunglassesOverlayNotRunning,
        else => error.SystemCallFailed,
    };
}

fn stopOverlay(pid_path: []const u8, pid: std.os.linux.pid_t) !void {
    sendSignal(pid, .TERM) catch |err| switch (err) {
        error.SunglassesOverlayNotRunning => {
            removePidFile(pid_path);
            return;
        },
        else => return err,
    };

    var polls: u32 = 0;
    while (polls < max_overlay_stop_polls) : (polls += 1) {
        if (!pidMatchesSunglassesOverlay(pid)) {
            removePidFile(pid_path);
            return;
        }
        sleepNs(overlay_stop_poll_sleep_ns);
    }
    return error.SunglassesOverlayStillRunning;
}

fn startOverlayAndWait(allocator: std.mem.Allocator, pid_path: []const u8, status_path: []const u8) !void {
    removeStartupStatus(status_path);
    try startOverlayDetached(allocator);
    var polls: u32 = 0;
    while (polls < max_overlay_start_polls) : (polls += 1) {
        const status_error = try readStartupStatus(status_path);
        switch (try overlayStartPoll(childState(pid_path), status_error)) {
            .ready => return,
            .wait => sleepNs(overlay_start_poll_sleep_ns),
            .failed_stale => {
                removePidFile(pid_path);
                return error.SunglassesOverlayStartFailed;
            },
        }
    }
    return error.SunglassesOverlayStartTimedOut;
}

const OverlayStartPoll = enum {
    ready,
    wait,
    failed_stale,
};

fn overlayStartPoll(child_state: ChildState, startup_status: ?StartupStatus) !OverlayStartPoll {
    if (startup_status) |status| return startupStatusFailure(status);
    return switch (child_state) {
        .live => .ready,
        .stale => .failed_stale,
        .absent => .wait,
    };
}

/// Startup status is a local one-shot file, removed before each start and capped at max_startup_status_bytes.
fn writeStartupStatus(allocator: std.mem.Allocator, runtime_dir: []const u8, err: anyerror) !void {
    const dir_path = try sunglassesPidDirPath(allocator, runtime_dir);
    defer allocator.free(dir_path);
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, dir_path);

    const status_path = try sunglassesStartupStatusPath(allocator, runtime_dir);
    defer allocator.free(status_path);

    const status = startupStatusName(startupStatusFromError(err));
    std.debug.assert(status.len <= max_startup_status_bytes);
    const io = std.Options.debug_io;
    const file = try std.Io.Dir.createFileAbsolute(io, status_path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, status);
    try file.writeStreamingAll(io, "\n");
    try file.sync(io);
}

fn readStartupStatus(status_path: []const u8) !?StartupStatus {
    var buf: [max_startup_status_bytes + 1]u8 = undefined;
    const bytes = std.Io.Dir.cwd().readFile(std.Options.debug_io, status_path, &buf) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    if (bytes.len > max_startup_status_bytes) return error.SunglassesStartupStatusTooLarge;
    const text = std.mem.trim(u8, bytes, " \n\r\t");
    return try parseStartupStatus(text);
}

fn startupStatusFromError(err: anyerror) StartupStatus {
    return switch (err) {
        error.SunglassesImageLoadFailed => .sunglasses_image_load_failed,
        error.SunglassesUnsupportedImageExtension => .sunglasses_unsupported_image_extension,
        error.SunglassesImageConvertFailed => .sunglasses_image_convert_failed,
        error.SunglassesImageTargetFailed => .sunglasses_image_target_failed,
        error.SunglassesImageScaleFailed => .sunglasses_image_scale_failed,
        error.SunglassesImageOpacityInvalid => .sunglasses_image_opacity_invalid,
        error.SunglassesInvalidBufferSize => .sunglasses_invalid_buffer_size,
        error.SunglassesMemfdFailed => .sunglasses_memfd_failed,
        error.SunglassesTruncateFailed => .sunglasses_truncate_failed,
        error.SunglassesMmapFailed => .sunglasses_mmap_failed,
        error.SunglassesShmPoolFailed => .sunglasses_shm_pool_failed,
        error.SunglassesWlBufferFailed => .sunglasses_wl_buffer_failed,
        error.LayerShellMissing => .layer_shell_missing,
        error.LayerShellCompositorMissing => .layer_shell_compositor_missing,
        error.LayerShellShmMissing => .layer_shell_shm_missing,
        error.LayerShellOutputMissing => .layer_shell_output_missing,
        error.LayerShellSurfaceCreateFailed => .layer_shell_surface_create_failed,
        error.LayerShellInputRegionFailed => .layer_shell_input_region_failed,
        error.NoEnvMonitors => .no_env_monitors,
        else => .sunglasses_overlay_start_failed,
    };
}

fn startupStatusName(status: StartupStatus) []const u8 {
    return switch (status) {
        .sunglasses_image_load_failed => "SunglassesImageLoadFailed",
        .sunglasses_unsupported_image_extension => "SunglassesUnsupportedImageExtension",
        .sunglasses_image_convert_failed => "SunglassesImageConvertFailed",
        .sunglasses_image_target_failed => "SunglassesImageTargetFailed",
        .sunglasses_image_scale_failed => "SunglassesImageScaleFailed",
        .sunglasses_image_opacity_invalid => "SunglassesImageOpacityInvalid",
        .sunglasses_invalid_buffer_size => "SunglassesInvalidBufferSize",
        .sunglasses_memfd_failed => "SunglassesMemfdFailed",
        .sunglasses_truncate_failed => "SunglassesTruncateFailed",
        .sunglasses_mmap_failed => "SunglassesMmapFailed",
        .sunglasses_shm_pool_failed => "SunglassesShmPoolFailed",
        .sunglasses_wl_buffer_failed => "SunglassesWlBufferFailed",
        .layer_shell_missing => "LayerShellMissing",
        .layer_shell_compositor_missing => "LayerShellCompositorMissing",
        .layer_shell_shm_missing => "LayerShellShmMissing",
        .layer_shell_output_missing => "LayerShellOutputMissing",
        .layer_shell_surface_create_failed => "LayerShellSurfaceCreateFailed",
        .layer_shell_input_region_failed => "LayerShellInputRegionFailed",
        .no_env_monitors => "NoEnvMonitors",
        .sunglasses_overlay_start_failed => "SunglassesOverlayStartFailed",
    };
}

fn parseStartupStatus(text: []const u8) !StartupStatus {
    if (std.mem.eql(u8, text, "SunglassesImageLoadFailed")) return .sunglasses_image_load_failed;
    if (std.mem.eql(u8, text, "SunglassesUnsupportedImageExtension")) return .sunglasses_unsupported_image_extension;
    if (std.mem.eql(u8, text, "SunglassesImageConvertFailed")) return .sunglasses_image_convert_failed;
    if (std.mem.eql(u8, text, "SunglassesImageTargetFailed")) return .sunglasses_image_target_failed;
    if (std.mem.eql(u8, text, "SunglassesImageScaleFailed")) return .sunglasses_image_scale_failed;
    if (std.mem.eql(u8, text, "SunglassesImageOpacityInvalid")) return .sunglasses_image_opacity_invalid;
    if (std.mem.eql(u8, text, "SunglassesInvalidBufferSize")) return .sunglasses_invalid_buffer_size;
    if (std.mem.eql(u8, text, "SunglassesMemfdFailed")) return .sunglasses_memfd_failed;
    if (std.mem.eql(u8, text, "SunglassesTruncateFailed")) return .sunglasses_truncate_failed;
    if (std.mem.eql(u8, text, "SunglassesMmapFailed")) return .sunglasses_mmap_failed;
    if (std.mem.eql(u8, text, "SunglassesShmPoolFailed")) return .sunglasses_shm_pool_failed;
    if (std.mem.eql(u8, text, "SunglassesWlBufferFailed")) return .sunglasses_wl_buffer_failed;
    if (std.mem.eql(u8, text, "LayerShellMissing")) return .layer_shell_missing;
    if (std.mem.eql(u8, text, "LayerShellCompositorMissing")) return .layer_shell_compositor_missing;
    if (std.mem.eql(u8, text, "LayerShellShmMissing")) return .layer_shell_shm_missing;
    if (std.mem.eql(u8, text, "LayerShellOutputMissing")) return .layer_shell_output_missing;
    if (std.mem.eql(u8, text, "LayerShellSurfaceCreateFailed")) return .layer_shell_surface_create_failed;
    if (std.mem.eql(u8, text, "LayerShellInputRegionFailed")) return .layer_shell_input_region_failed;
    if (std.mem.eql(u8, text, "NoEnvMonitors")) return .no_env_monitors;
    if (std.mem.eql(u8, text, "SunglassesOverlayStartFailed")) return .sunglasses_overlay_start_failed;
    return error.UnknownSunglassesStartupStatus;
}

fn startupStatusFailure(status: StartupStatus) anyerror {
    return switch (status) {
        .sunglasses_image_load_failed => error.SunglassesImageLoadFailed,
        .sunglasses_unsupported_image_extension => error.SunglassesUnsupportedImageExtension,
        .sunglasses_image_convert_failed => error.SunglassesImageConvertFailed,
        .sunglasses_image_target_failed => error.SunglassesImageTargetFailed,
        .sunglasses_image_scale_failed => error.SunglassesImageScaleFailed,
        .sunglasses_image_opacity_invalid => error.SunglassesImageOpacityInvalid,
        .sunglasses_invalid_buffer_size => error.SunglassesInvalidBufferSize,
        .sunglasses_memfd_failed => error.SunglassesMemfdFailed,
        .sunglasses_truncate_failed => error.SunglassesTruncateFailed,
        .sunglasses_mmap_failed => error.SunglassesMmapFailed,
        .sunglasses_shm_pool_failed => error.SunglassesShmPoolFailed,
        .sunglasses_wl_buffer_failed => error.SunglassesWlBufferFailed,
        .layer_shell_missing => error.LayerShellMissing,
        .layer_shell_compositor_missing => error.LayerShellCompositorMissing,
        .layer_shell_shm_missing => error.LayerShellShmMissing,
        .layer_shell_output_missing => error.LayerShellOutputMissing,
        .layer_shell_surface_create_failed => error.LayerShellSurfaceCreateFailed,
        .layer_shell_input_region_failed => error.LayerShellInputRegionFailed,
        .no_env_monitors => error.NoEnvMonitors,
        .sunglasses_overlay_start_failed => error.SunglassesOverlayStartFailed,
    };
}

fn startOverlayDetached(allocator: std.mem.Allocator) !void {
    const exe_path_z = try selfExePathZ(allocator);
    defer allocator.free(exe_path_z);

    const wrapper_pid = try forkChild();
    if (wrapper_pid == 0) overlayWrapperChild(exe_path_z);
    try waitChild(wrapper_pid);
}

fn selfExePathZ(allocator: std.mem.Allocator) ![:0]u8 {
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const path_len = try std.Io.Dir.readLinkAbsolute(std.Options.debug_io, "/proc/self/exe", &path_buf);
    return try allocator.dupeZ(u8, path_buf[0..path_len]);
}

fn overlayWrapperChild(exe_path_z: [:0]const u8) noreturn {
    const stdio_ok = redirectStdioToNull();
    if (!stdio_ok) std.c._exit(overlay_child_fail_code);

    const session_id = std.c.setsid();
    if (session_id == -1) std.c._exit(overlay_child_fail_code);

    const overlay_pid = forkChild() catch std.c._exit(overlay_child_fail_code);
    if (overlay_pid == 0) execSunglassesOverlay(exe_path_z);

    std.c._exit(0);
}

fn execSunglassesOverlay(exe_path_z: [:0]const u8) noreturn {
    const canonical_mode = "sunglasses";
    const argv: [3:null]?[*:0]const u8 = .{
        exe_path_z.ptr,
        canonical_mode,
        null,
    };
    const exec_rc = std.c.execve(exe_path_z.ptr, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(overlay_child_fail_code);
    std.c._exit(overlay_child_fail_code);
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

fn forkChild() !std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn waitChild(pid: std.c.pid_t) !void {
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_child_wait_interrupts) {
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
    if (!std.c.W.IFEXITED(status_bits)) return error.ChildFailed;
    if (std.c.W.EXITSTATUS(status_bits) != 0) return error.ChildFailed;
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

test "sunglasses overlay cmdline check requires exact argv entries" {
    try std.testing.expect(cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00sunglasses\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00sunglasses\x00apply\x00"));
    try std.testing.expect(cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00--sunglasses-daemon\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("bash\x00-c\x00wayspot --sunglasses-daemon\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("bash\x00-c\x00wayspot sunglasses\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00--sunglasses-apply\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00foo\x00sunglasses\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00sunglasses\x00unknown\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00sunglasses\x00extra\x00args\x00"));
    try std.testing.expect(!cmdlineMatchesSunglassesOverlay("/home/home/.local/bin/wayspot\x00--sunglasses-daemon\x00extra\x00"));
}

test "sunglasses overlay reconciliation action follows saved state need and live child" {
    try std.testing.expectEqual(ReconcileAction.idle, reconcileAction(false, false));
    try std.testing.expectEqual(ReconcileAction.stop, reconcileAction(false, true));
    try std.testing.expectEqual(ReconcileAction.start, reconcileAction(true, false));
    try std.testing.expectEqual(ReconcileAction.wake, reconcileAction(true, true));
}

test "sunglasses overlay slots are bounded by env monitor facts" {
    const overlay = Overlay{ .allocator = std.testing.allocator };
    try std.testing.expectEqual(@as(u32, env.monitor.max_monitors), @as(u32, @intCast(overlay.slots.len)));
}

test "sunglasses owner rejects a second live pid file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir = try testRuntimeDir(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(runtime_dir);

    var owner = try PidFile.create(std.testing.allocator, runtime_dir);
    defer owner.deinit(std.testing.allocator);
    try std.testing.expectError(error.SunglassesOverlayAlreadyRunning, PidFile.create(std.testing.allocator, runtime_dir));
}

test "sunglasses startup status path stays beside pid file" {
    const path = try sunglassesStartupStatusPath(std.testing.allocator, "/run/user/1000");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/run/user/1000/wayspot/sunglasses.startup.status", path);
}

test "sunglasses startup poll reports status before timeout" {
    try std.testing.expectError(error.SunglassesImageLoadFailed, overlayStartPoll(.absent, .sunglasses_image_load_failed));
    try std.testing.expectError(error.SunglassesImageLoadFailed, overlayStartPoll(.stale, .sunglasses_image_load_failed));
}

test "sunglasses startup poll keeps ready wait and stale outcomes without status" {
    try std.testing.expectEqual(OverlayStartPoll.ready, try overlayStartPoll(.{ .live = 1 }, null));
    try std.testing.expectEqual(OverlayStartPoll.wait, try overlayStartPoll(.absent, null));
    try std.testing.expectEqual(OverlayStartPoll.failed_stale, try overlayStartPoll(.stale, null));
}

test "sunglasses startup status parses known and rejects unknown" {
    try std.testing.expectEqual(StartupStatus.sunglasses_image_load_failed, try parseStartupStatus("SunglassesImageLoadFailed"));
    try std.testing.expectError(error.UnknownSunglassesStartupStatus, parseStartupStatus("SunglassesOverlayStartTimedOut"));
}

test "sunglasses startup status round trips missing image failure" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir = try testRuntimeDir(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(runtime_dir);

    try writeStartupStatus(std.testing.allocator, runtime_dir, error.SunglassesImageLoadFailed);
    const status_path = try sunglassesStartupStatusPath(std.testing.allocator, runtime_dir);
    defer std.testing.allocator.free(status_path);

    try std.testing.expectEqual(StartupStatus.sunglasses_image_load_failed, (try readStartupStatus(status_path)).?);
    try std.testing.expectError(error.SunglassesImageLoadFailed, overlayStartPoll(.absent, try readStartupStatus(status_path)));
}

test "sunglasses startup status rejects oversized file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir = try testRuntimeDir(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(runtime_dir);
    const dir_path = try sunglassesPidDirPath(std.testing.allocator, runtime_dir);
    defer std.testing.allocator.free(dir_path);
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, dir_path);
    const status_path = try sunglassesStartupStatusPath(std.testing.allocator, runtime_dir);
    defer std.testing.allocator.free(status_path);

    var too_large: [max_startup_status_bytes + 1]u8 = undefined;
    @memset(&too_large, 'A');
    const file = try std.Io.Dir.createFileAbsolute(std.Options.debug_io, status_path, .{ .truncate = true });
    defer file.close(std.Options.debug_io);
    try file.writeStreamingAll(std.Options.debug_io, &too_large);

    try std.testing.expectError(error.SunglassesStartupStatusTooLarge, readStartupStatus(status_path));
}

test "sunglasses startup status cleanup removes stale status on new start" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir = try testRuntimeDir(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(runtime_dir);
    try writeStartupStatus(std.testing.allocator, runtime_dir, error.SunglassesImageLoadFailed);
    const status_path = try sunglassesStartupStatusPath(std.testing.allocator, runtime_dir);
    defer std.testing.allocator.free(status_path);

    removeStartupStatus(status_path);
    try std.testing.expectEqual(@as(?StartupStatus, null), try readStartupStatus(status_path));
}

fn testRuntimeDir(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir) ![]u8 {
    const cwd = try std.Io.Dir.cwd().realPathFileAlloc(std.Options.debug_io, ".", allocator);
    defer allocator.free(cwd);
    return std.fmt.allocPrint(allocator, "{s}/.zig-cache/tmp/{s}", .{ cwd, &tmp.sub_path });
}
