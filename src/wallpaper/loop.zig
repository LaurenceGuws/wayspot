//! Wallpaper loop owns monitor surface slots, the random timer, and shutdown order.

const std = @import("std");
const config_owner = @import("config.zig");
const env = @import("wayspot_env_native");
const library_owner = @import("library.zig");
const wallpaper_surface = @import("surface.zig");

const c = @import("sdl_c");

const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
const rotate_eventfd_signal_value: u64 = 1;
const monitor_eventfd_stop_value: u64 = 1;
const monitor_changed_event_type: u32 = @intCast(c.SDL_EVENT_USER + 31);
const wallpaper_rotate_event_type: u32 = @intCast(c.SDL_EVENT_USER + 32);
const pid_dir_name = "wayspot";
const pid_file_name = "wallpaper.pid";
const max_pid_file_bytes: u32 = 32;
const max_proc_cmdline_bytes: u32 = 4096;
var signal_shutdown_fd = std.atomic.Value(std.posix.fd_t).init(-1);
var signal_rotate_fd = std.atomic.Value(std.posix.fd_t).init(-1);

pub const Loop = struct {
    allocator: std.mem.Allocator,
    slots: [env.monitor.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    vendor_started: bool = false,

    pub fn run(allocator: std.mem.Allocator, monitor_source: *env.MonitorSource) !void {
        var config = try config_owner.Config.load(allocator);
        defer config.deinit(allocator);

        var library = try library_owner.scan(allocator, config.library_path);
        defer library.deinit(allocator);
        if (library.records.items.len == 0) return error.EmptyWallpaperLibrary;

        var loop = Loop{ .allocator = allocator };
        defer loop.deinit();
        try loop.startWallpaper(monitor_source, &library, config.interval_seconds);
    }

    pub fn rotateNow(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
        const pid_path = try wallpaperPidPath(allocator, runtime_dir);
        defer allocator.free(pid_path);
        const pid = try readWallpaperPid(pid_path);
        if (!pidMatchesWallpaper(pid)) {
            removePidFile(pid_path);
            return error.WallpaperLoopNotRunning;
        }
        try sendSignal(pid, .USR1);
    }

    fn startWallpaper(
        self: *Loop,
        monitor_source: *env.MonitorSource,
        library: *const library_owner.Library,
        interval_seconds: u32,
    ) !void {
        try self.startVendor();
        var signals = try LoopSignals.init();
        defer signals.deinit();
        try signals.start();
        var pid_file = try PidFile.create(self.allocator, monitor_source.runtimeDir());
        defer pid_file.deinit(self.allocator);

        var monitor_watcher = try MonitorWatcher.init(self.allocator, monitor_source);
        defer monitor_watcher.deinit() catch |err| {
            std.log.debug("wallpaper monitor close failed err={s}", .{@errorName(err)});
        };
        try monitor_watcher.start();

        var prng = std.Random.DefaultPrng.init(try randomSeed());
        const random = prng.random();
        try self.rebuildSurfaceSlots(monitor_source, library, random);

        try self.runRandomLoop(monitor_source, library, random, interval_seconds);
    }

    fn startVendor(self: *Loop) !void {
        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, wallpaper_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_EVENTS)) return error.SdlInitFailed;
        self.vendor_started = true;
    }

    fn runRandomLoop(
        self: *Loop,
        monitor_source: *env.MonitorSource,
        library: *const library_owner.Library,
        random: std.Random,
        interval_seconds: u32,
    ) !void {
        const interval_ms = @as(u64, interval_seconds) * 1000;
        var next_deadline = c.SDL_GetTicks() + interval_ms;
        while (true) {
            switch (waitForWake(next_deadline)) {
                .shutdown => return,
                .deadline => {
                    try self.drawRandomImages(library, random);
                    next_deadline = c.SDL_GetTicks() + interval_ms;
                },
                .rotate_now => {
                    std.log.info("wallpaper rotate now", .{});
                    try self.drawRandomImages(library, random);
                    next_deadline = c.SDL_GetTicks() + interval_ms;
                },
                .monitor_changed => {
                    try self.rebuildSurfaceSlots(monitor_source, library, random);
                },
            }
        }
    }

    fn rebuildSurfaceSlots(
        self: *Loop,
        monitor_source: *env.MonitorSource,
        library: *const library_owner.Library,
        random: std.Random,
    ) !void {
        const monitors = try monitor_source.queryMonitors(self.allocator);
        if (monitors.count == 0) return error.NoEnvMonitors;

        self.clearSurfaceSlots();
        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            const surface = try wallpaper_surface.WallpaperSurface.init(monitor);
            self.slots[self.slot_count] = SurfaceSlot{
                .surface = surface,
            };
            self.slot_count += 1;
            try self.slots[self.slot_count - 1].drawRandomImage(library, random);
        }
    }

    fn drawRandomImages(self: *Loop, library: *const library_owner.Library, random: std.Random) !void {
        var index: u32 = 0;
        while (index < self.slot_count) : (index += 1) {
            try self.slots[index].drawRandomImage(library, random);
        }
    }

    fn clearSurfaceSlots(self: *Loop) void {
        var index = self.slot_count;
        while (index > 0) {
            index -= 1;
            self.slots[index].deinit();
        }
        self.slot_count = 0;
    }

    pub fn deinit(self: *Loop) void {
        self.clearSurfaceSlots();
        if (self.vendor_started) {
            c.SDL_Quit();
            self.vendor_started = false;
        }
    }
};

pub const SurfaceSlot = struct {
    surface: wallpaper_surface.WallpaperSurface,

    fn deinit(self: *SurfaceSlot) void {
        self.surface.deinit();
    }

    fn drawRandomImage(self: *SurfaceSlot, library: *const library_owner.Library, random: std.Random) !void {
        const record = library.chooseRandom(random) orelse return error.EmptyWallpaperLibrary;
        var path_buf: [library_owner.max_path_bytes + 1:0]u8 = undefined;
        const path = try std.fmt.bufPrintZ(&path_buf, "{s}", .{record.path});
        try self.surface.drawImage(path);
    }
};

const LoopWake = enum {
    shutdown,
    deadline,
    rotate_now,
    monitor_changed,
};

fn waitForWake(deadline: u64) LoopWake {
    while (true) {
        const now = c.SDL_GetTicks();
        if (now >= deadline) return .deadline;
        const remaining = deadline - now;
        const timeout: i32 = @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEventTimeout(&event, timeout)) {
            if (eventIsShutdown(event)) return .shutdown;
            if (event.type == wallpaper_rotate_event_type) return .rotate_now;
            if (event.type == monitor_changed_event_type) return .monitor_changed;
            while (c.SDL_PollEvent(&event)) {
                if (eventIsShutdown(event)) return .shutdown;
                if (event.type == wallpaper_rotate_event_type) return .rotate_now;
                if (event.type == monitor_changed_event_type) return .monitor_changed;
            }
        }
    }
}

fn eventIsShutdown(event: c.SDL_Event) bool {
    return event.type == c.SDL_EVENT_QUIT or
        event.type == c.SDL_EVENT_TERMINATING or
        event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
}

/// MonitorWatcher converts env monitor fact changes into vendor wake events owned by Loop.
const MonitorWatcher = struct {
    stream: env.MonitorFactStream,
    stop_fd: std.posix.fd_t = -1,
    thread: ?std.Thread = null,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init(allocator: std.mem.Allocator, monitor_source: *env.MonitorSource) !MonitorWatcher {
        var stream = try monitor_source.monitorStream(allocator);
        errdefer stream.deinit() catch |err| {
            std.log.debug("wallpaper event close failed err={s}", .{@errorName(err)});
        };
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

    fn deinit(self: *MonitorWatcher) !void {
        self.stop();
        try self.stream.deinit();
    }
};

fn monitorWatcherMain(watcher: *MonitorWatcher) void {
    while (!watcher.stop_requested.load(.acquire)) {
        const wake = watcher.stream.wait(watcher.stop_fd) catch |err| {
            if (watcher.stop_requested.load(.acquire)) return;
            std.log.warn("wallpaper monitor event stream failed err={s}", .{@errorName(err)});
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
        std.log.warn("wallpaper monitor event wake failed type={d}", .{event_type});
    }
}

fn pushVendorQuit() void {
    var event = c.SDL_Event{ .quit = .{
        .type = c.SDL_EVENT_QUIT,
    } };
    const pushed = c.SDL_PushEvent(&event);
    if (!pushed) {
        std.log.warn("wallpaper quit wake failed", .{});
    }
}

/// LoopSignals converts signal wakes into vendor events owned by the wallpaper loop.
const LoopSignals = struct {
    shutdown_fd: std.posix.fd_t = -1,
    rotate_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    old_usr1_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    fn init() !LoopSignals {
        const shutdown_fd = try osEventFd();
        errdefer osClose(shutdown_fd);
        const rotate_fd = try osEventFd();
        return .{
            .shutdown_fd = shutdown_fd,
            .rotate_fd = rotate_fd,
        };
    }

    fn start(self: *LoopSignals) !void {
        std.debug.assert(self.shutdown_fd != -1);
        std.debug.assert(self.rotate_fd != -1);
        signal_shutdown_fd.store(self.shutdown_fd, .release);
        signal_rotate_fd.store(self.rotate_fd, .release);
        self.installHandlers();
        self.thread = try std.Thread.spawn(.{}, signalsMain, .{self});
    }

    fn stop(self: *LoopSignals) void {
        self.stop_requested.store(true, .release);
        if (self.installed) {
            self.restoreHandlers();
            self.installed = false;
        }
        signal_shutdown_fd.store(-1, .release);
        signal_rotate_fd.store(-1, .release);
        if (self.thread) |thread| {
            signalEventFd(self.shutdown_fd, shutdown_eventfd_stop_value);
            thread.join();
            self.thread = null;
        }
        if (self.shutdown_fd != -1) {
            osClose(self.shutdown_fd);
            self.shutdown_fd = -1;
        }
        if (self.rotate_fd != -1) {
            osClose(self.rotate_fd);
            self.rotate_fd = -1;
        }
    }

    fn deinit(self: *LoopSignals) void {
        self.stop();
    }

    fn installHandlers(self: *LoopSignals) void {
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

    fn restoreHandlers(self: *LoopSignals) void {
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
            std.log.warn("wallpaper shutdown wake failed", .{});
        }
    }

    fn pushRotateWake() void {
        var event = c.SDL_Event{ .user = .{
            .type = wallpaper_rotate_event_type,
        } };
        const pushed = c.SDL_PushEvent(&event);
        if (!pushed) {
            std.log.warn("wallpaper rotate wake failed", .{});
        }
    }
};

fn signalHandler(signal: std.posix.SIG) callconv(.c) void {
    const fd = switch (signal) {
        .INT, .TERM => signal_shutdown_fd.load(.acquire),
        .USR1 => signal_rotate_fd.load(.acquire),
        else => return,
    };
    if (fd == -1) return;
    var value: u64 = if (signal == .USR1) rotate_eventfd_signal_value else shutdown_eventfd_signal_value;
    const written = std.os.linux.write(fd, std.mem.asBytes(&value).ptr, @sizeOf(u64));
    if (std.os.linux.errno(written) != .SUCCESS) return;
}

fn signalsMain(signals: *LoopSignals) void {
    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = signals.shutdown_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
        .{
            .fd = signals.rotate_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (!signals.stop_requested.load(.acquire)) {
        poll_fds[0].revents = 0;
        poll_fds[1].revents = 0;
        const ready = osPoll(&poll_fds, shutdown_signal_poll_timeout_ms) catch |err| {
            std.log.warn("wallpaper signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[1].revents & std.posix.POLL.IN) != 0) {
            drainEventFd(signals.rotate_fd) catch |err| {
                std.log.warn("wallpaper rotate read failed err={s}", .{@errorName(err)});
                return;
            };
            if (signals.stop_requested.load(.acquire)) return;
            LoopSignals.pushRotateWake();
        }
        if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        drainEventFd(signals.shutdown_fd) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("wallpaper shutdown read failed err={s}", .{@errorName(err)});
            return;
        };
        if (signals.stop_requested.load(.acquire)) return;
        LoopSignals.pushShutdownWake();
        return;
    }
}

const PidFile = struct {
    path: []u8,

    fn create(allocator: std.mem.Allocator, runtime_dir: []const u8) !PidFile {
        const dir_path = try wallpaperPidDirPath(allocator, runtime_dir);
        defer allocator.free(dir_path);
        try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, dir_path);

        const pid_path = try wallpaperPidPath(allocator, runtime_dir);
        errdefer allocator.free(pid_path);

        const io = std.Options.debug_io;
        const file = std.Io.Dir.createFileAbsolute(io, pid_path, .{ .truncate = true, .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => return error.WallpaperAlreadyRunning,
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

fn wallpaperPidDirPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, pid_dir_name });
}

fn wallpaperPidPath(allocator: std.mem.Allocator, runtime_dir: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ runtime_dir, pid_dir_name, pid_file_name });
}

fn readWallpaperPid(pid_path: []const u8) !std.os.linux.pid_t {
    var buf: [max_pid_file_bytes]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFile(std.Options.debug_io, pid_path, &buf);
    const text = std.mem.trim(u8, bytes, " \n\r\t");
    return std.fmt.parseInt(std.os.linux.pid_t, text, 10);
}

fn pidMatchesWallpaper(pid: std.os.linux.pid_t) bool {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/proc/{d}/cmdline", .{pid}) catch return false;
    var cmdline_buf: [max_proc_cmdline_bytes]u8 = undefined;
    const cmdline = std.Io.Dir.cwd().readFile(std.Options.debug_io, path, &cmdline_buf) catch return false;
    return cmdlineMatchesWallpaper(cmdline);
}

/// Returns true only for one exact wallpaper resident argv or the exact legacy
/// identity retained by the bounded rerun transition.
fn cmdlineMatchesWallpaper(cmdline: []const u8) bool {
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
    return std.mem.eql(u8, resident_arg, "wallpaper") or
        std.mem.eql(u8, resident_arg, "--wallpaper");
}

fn removePidFile(pid_path: []const u8) void {
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, pid_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.debug("wallpaper pid file remove failed err={s}", .{@errorName(err)}),
    };
}

fn sendSignal(pid: std.os.linux.pid_t, signal: std.os.linux.SIG) !void {
    const rc = std.os.linux.kill(pid, signal);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .SRCH => error.WallpaperLoopNotRunning,
        else => error.SystemCallFailed,
    };
}

fn randomSeed() !u64 {
    var bytes: [@sizeOf(u64)]u8 = undefined;
    const read_count = std.os.linux.getrandom(bytes[0..].ptr, bytes.len, 0);
    if (read_count != bytes.len) return error.WallpaperRandomSeedFailed;
    return std.mem.readInt(u64, &bytes, .little);
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

test "wallpaper slots are bounded by env monitor facts" {
    const loop = Loop{ .allocator = std.testing.allocator };
    try std.testing.expectEqual(@as(u32, env.monitor.max_monitors), @as(u32, @intCast(loop.slots.len)));
}

test "wallpaper owner rejects a second live pid file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const runtime_dir_z = try tmp.dir.realPathFileAlloc(std.Options.debug_io, ".", std.testing.allocator);
    defer std.testing.allocator.free(runtime_dir_z);
    const runtime_dir = std.mem.sliceTo(runtime_dir_z, 0);

    var owner = try PidFile.create(std.testing.allocator, runtime_dir);
    defer owner.deinit(std.testing.allocator);
    try std.testing.expectError(error.WallpaperAlreadyRunning, PidFile.create(std.testing.allocator, runtime_dir));
}

test "wallpaper pid identity accepts canonical root and rejects rotate leaf" {
    try std.testing.expect(cmdlineMatchesWallpaper("/usr/bin/wayspot\x00wallpaper\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("/usr/bin/wayspot\x00wallpaper\x00rotate\x00"));
    try std.testing.expect(cmdlineMatchesWallpaper("/usr/bin/wayspot\x00--wallpaper\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("bash\x00-c\x00wayspot wallpaper\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("/usr/bin/wayspot\x00foo\x00wallpaper\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("/usr/bin/wayspot\x00wallpaper\x00unknown\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("/usr/bin/wayspot\x00wallpaper\x00extra\x00args\x00"));
    try std.testing.expect(!cmdlineMatchesWallpaper("/usr/bin/wayspot\x00--wallpaper\x00extra\x00"));
}
