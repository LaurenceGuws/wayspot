//! SDL shell owns one bounded picker lifecycle from CLI entry to cleanup.
//!
//! Approved happy path: create one SDL window, search app/action candidates,
//! launch one detached command when selected, and release every owned resource.

const std = @import("std");
const app = @import("../app/mod.zig");
const app_icons = @import("app_icons.zig");
const common_dispatch = @import("common/dispatch.zig");
const picker_viewport = @import("picker_viewport.zig");
const query_mod = @import("../search/query.zig");
const hyprland = @import("../wallpaper/hyprland.zig");
const surface_config = @import("surface_config.zig");
const sdl_text = @import("sdl_text.zig");
const sunglasses_form = @import("sunglasses_form.zig");
const sunglasses_runtime = @import("../sunglasses/runtime.zig");
const sunglasses_state = @import("../sunglasses/state.zig");

const c = @import("sdl_c");

pub const Shell = struct {
    pub fn run(
        allocator: std.mem.Allocator,
        service: *app.SearchService,
    ) !void {
        var shell = try SdlShell.init(allocator, service);
        defer shell.deinit();
        var shutdown_signal = try ShutdownSignal.init();
        try shell.startShutdownSignal(&shutdown_signal);
        try shell.loop();
    }
};

const max_command_bytes = 4096;
const base_window_width: i32 = @intFromFloat(picker_viewport.default_base_width);
const base_window_height: i32 = @intFromFloat(picker_viewport.default_base_height);
const launch_child_fail_code: i32 = 127;
const max_launch_wait_interrupts: u32 = 16;
const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
const cursor_blink_interval_ms: u64 = 530;
const LaunchRunError = error{
    CommandFailed,
    ForkFailed,
    WaitFailed,
    WaitInterruptedTooOften,
};
const LaunchRunner = *const fn ([*:0]const u8) LaunchRunError!void;
var shutdown_handler_fd = std.atomic.Value(std.posix.fd_t).init(-1);

comptime {
    std.debug.assert(max_command_bytes > 0);
    std.debug.assert(max_launch_wait_interrupts > 0);
    std.debug.assert(shutdown_eventfd_stop_value > 0);
    std.debug.assert(shutdown_eventfd_signal_value > 0);
    std.debug.assert(cursor_blink_interval_ms > 0);
}

/// LaunchQueue owns one detached command intent between picker activation and controlled drain.
const LaunchQueue = struct {
    command_buf: [max_command_bytes + 1]u8 = undefined,
    command_len: u32 = 0,
    state: enum { idle, queued } = .idle,

    fn queue(self: *LaunchQueue, command_bytes: []const u8) !void {
        if (command_bytes.len == 0) return error.EmptyCommand;
        if (command_bytes.len > max_command_bytes) return error.CommandTooLong;
        std.debug.assert(self.state == .idle);
        @memcpy(self.command_buf[0..command_bytes.len], command_bytes);
        self.command_buf[command_bytes.len] = 0;
        self.command_len = @intCast(command_bytes.len);
        self.state = .queued;
    }

    fn clear(self: *LaunchQueue) void {
        std.debug.assert(self.state == .queued);
        self.command_buf[0] = 0;
        self.command_len = 0;
        self.state = .idle;
    }

    fn hasQueued(self: *const LaunchQueue) bool {
        return self.state == .queued;
    }

    fn commandZ(self: *LaunchQueue) [*:0]const u8 {
        std.debug.assert(self.state == .queued);
        std.debug.assert(self.command_len > 0);
        std.debug.assert(self.command_len <= max_command_bytes);
        std.debug.assert(self.command_buf[self.command_len] == 0);
        return self.command_buf[0..self.command_len :0].ptr;
    }
};

/// ShutdownSignal turns SIGINT and SIGTERM into one SDL wake event owned by the shell.
const ShutdownSignal = struct {
    event_fd: std.posix.fd_t = -1,
    old_int_action: std.posix.Sigaction = undefined,
    old_term_action: std.posix.Sigaction = undefined,
    thread: ?std.Thread = null,
    installed: bool = false,
    stop_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    shutdown_requested: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    wake_event_type: u32 = 0,

    fn init() !ShutdownSignal {
        return .{
            .event_fd = try osEventFd(),
        };
    }

    fn start(self: *ShutdownSignal, wake_event_type: u32) !void {
        std.debug.assert(wake_event_type != 0);
        std.debug.assert(self.event_fd != -1);
        self.wake_event_type = wake_event_type;
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
            std.log.warn("shutdown wake event push failed signo={d}", .{signo});
        }
    }

    fn requested(self: *ShutdownSignal) bool {
        return self.shutdown_requested.load(.acquire);
    }
};

const CursorBlink = struct {
    visible: bool,
    next_toggle_ms: u64,

    fn init(now_ms: u64) CursorBlink {
        return .{
            .visible = true,
            .next_toggle_ms = now_ms + cursor_blink_interval_ms,
        };
    }

    fn reset(self: *CursorBlink, now_ms: u64) void {
        self.visible = true;
        self.next_toggle_ms = now_ms + cursor_blink_interval_ms;
    }

    fn advance(self: *CursorBlink, now_ms: u64) bool {
        if (now_ms < self.next_toggle_ms) return false;
        const was_visible = self.visible;
        const toggles: u64 = ((now_ms - self.next_toggle_ms) / cursor_blink_interval_ms) + 1;
        if ((toggles & 1) == 1) self.visible = !self.visible;
        self.next_toggle_ms += toggles * cursor_blink_interval_ms;
        return self.visible != was_visible;
    }

    fn waitTimeoutMs(self: *const CursorBlink, now_ms: u64) i32 {
        if (now_ms >= self.next_toggle_ms) return 0;
        const remaining = self.next_toggle_ms - now_ms;
        return @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
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
            std.log.warn("shutdown signal poll failed err={s}", .{@errorName(err)});
            return;
        };
        if (ready == 0) continue;
        if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;

        var event_count: u64 = 0;
        const event_bytes = osRead(shutdown_signal.event_fd, std.mem.asBytes(&event_count)) catch |err| {
            if (err == error.WouldBlock) continue;
            std.log.warn("shutdown event read failed err={s}", .{@errorName(err)});
            return;
        };
        if (event_bytes != @as(u32, @intCast(@sizeOf(u64)))) {
            std.log.warn("shutdown event short read bytes={d}", .{event_bytes});
            return;
        }
        if (shutdown_signal.stop_requested.load(.acquire)) return;
        shutdown_signal.pushShutdownWake(@intFromEnum(std.posix.SIG.TERM));
        return;
    }
}

const SdlShell = struct {
    allocator: std.mem.Allocator,
    service: *app.SearchService,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    text: sdl_text.TextEngine,
    icons: app_icons.AppIconStore = app_icons.AppIconStore.init(),
    config: surface_config.SurfaceConfig,
    base_width: f32 = @floatFromInt(base_window_width),
    base_height: f32 = @floatFromInt(base_window_height),
    cursor: CursorBlink = CursorBlink.init(0),
    shutdown_signal: ?*ShutdownSignal = null,
    wake_event_type: u32 = 0,
    query: std.ArrayList(u8) = .empty,
    results: []@import("../search/mod.zig").ScoredCandidate = &.{},
    sunglasses_state: sunglasses_state.State = sunglasses_state.defaultState(),
    sunglasses_form: sunglasses_form.Form = .{},
    /// The viewport is the only owner of picker selection and scroll offset.
    viewport: picker_viewport.Viewport = picker_viewport.Viewport.init(),
    dirty: bool = true,
    launch_queue: LaunchQueue = .{},
    shutdown_after_launch: bool = false,

    fn init(allocator: std.mem.Allocator, service: *app.SearchService) !SdlShell {
        const config = try surface_config.load(allocator);
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        errdefer c.SDL_Quit();

        const window_size = config.scaledDimensions(base_window_width, base_window_height);
        const window = c.SDL_CreateWindow(
            "Wayspot",
            @intCast(window_size.width),
            @intCast(window_size.height),
            c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_RESIZABLE,
        ) orelse return error.SdlWindowFailed;
        errdefer c.SDL_DestroyWindow(window);
        const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SdlRendererFailed;
        errdefer c.SDL_DestroyRenderer(renderer);
        var text = try sdl_text.TextEngine.init(allocator);
        errdefer text.deinit();
        const text_input_started = c.SDL_StartTextInput(window);
        if (!text_input_started) return error.SdlTextInputFailed;
        errdefer {
            const stopped_text_input = c.SDL_StopTextInput(window);
            if (!stopped_text_input) std.log.warn("sdl text input stop failed", .{});
        }
        const wake_event_type = c.SDL_RegisterEvents(1);
        if (wake_event_type == 0) return error.SdlWakeUnavailable;

        const persisted_sunglasses_state = try loadSunglassesStateForSession(allocator);
        var self = SdlShell{
            .allocator = allocator,
            .service = service,
            .window = window,
            .renderer = renderer,
            .text = text,
            .config = config,
            .sunglasses_state = persisted_sunglasses_state,
            .wake_event_type = wake_event_type,
            .cursor = CursorBlink.init(sdlNowMs()),
        };
        try self.applyDefaultWindowSize();
        const shown = c.SDL_ShowWindow(window);
        const raised = c.SDL_RaiseWindow(window);
        if (!shown or !raised) return error.SdlShowFailed;
        try self.applyDefaultWindowSize();
        try self.updateViewportForWindow();
        try self.refreshResults();
        return self;
    }

    fn startShutdownSignal(self: *SdlShell, shutdown_signal: *ShutdownSignal) !void {
        self.shutdown_signal = shutdown_signal;
        try shutdown_signal.start(self.wake_event_type);
    }

    fn deinit(self: *SdlShell) void {
        if (self.shutdown_signal) |shutdown_signal| {
            shutdown_signal.stop();
            self.shutdown_signal = null;
        }
        self.freeResults();
        self.query.deinit(self.allocator);
        const stopped_text_input = c.SDL_StopTextInput(self.window);
        if (!stopped_text_input) std.log.warn("sdl text input stop failed", .{});
        self.text.deinit();
        self.icons.deinit();
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    fn loop(self: *SdlShell) !void {
        var running = true;
        while (running) {
            if (self.shutdownRequested()) break;
            if (self.dirty) {
                try self.render();
                self.dirty = false;
            }
            try self.drainPendingLaunch();
            if (self.shutdown_after_launch) break;

            const before_wait_ms = sdlNowMs();
            if (self.cursor.advance(before_wait_ms)) {
                self.dirty = true;
                continue;
            }

            var event: c.SDL_Event = undefined;
            if (!c.SDL_WaitEventTimeout(&event, self.cursor.waitTimeoutMs(before_wait_ms))) {
                if (self.cursor.advance(sdlNowMs())) self.dirty = true;
                continue;
            }
            running = try self.handleEvent(&event);
            while (c.SDL_PollEvent(&event)) {
                if (!try self.handleEvent(&event)) {
                    running = false;
                    break;
                }
            }
        }
    }

    fn shutdownRequested(self: *SdlShell) bool {
        if (self.shutdown_signal) |shutdown_signal| {
            return shutdown_signal.requested();
        }
        return false;
    }

    fn handleEvent(self: *SdlShell, event: *const c.SDL_Event) !bool {
        if (event.type == self.wake_event_type) {
            if (self.shutdown_signal) |shutdown_signal| {
                if (shutdown_signal.requested()) return false;
            }
            return true;
        }
        switch (event.type) {
            c.SDL_EVENT_QUIT,
            c.SDL_EVENT_TERMINATING,
            c.SDL_EVENT_WINDOW_DESTROYED,
            => return false,
            c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => return false,
            c.SDL_EVENT_WINDOW_RESIZED,
            c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            => {
                try self.updateViewportForWindow();
            },
            c.SDL_EVENT_TEXT_INPUT => {
                if (self.sunglassesActive()) return true;
                const text = std.mem.span(event.text.text);
                try self.query.appendSlice(self.allocator, text);
                self.resetCursorBlink();
                try self.refreshResults();
            },
            c.SDL_EVENT_MOUSE_WHEEL => {
                if (self.sunglassesActive()) return true;
                const wheel_y = event.wheel.integer_y;
                const scroll_delta = if (wheel_y == std.math.minInt(i32)) std.math.maxInt(i32) else -wheel_y;
                if (wheel_y != 0 and self.viewport.scrollLines(scroll_delta)) self.dirty = true;
            },
            c.SDL_EVENT_MOUSE_MOTION => {
                if (self.sunglassesActive()) return true;
                if (self.visibleRowAtPoint(event.motion.x, event.motion.y)) |visible_row| {
                    if (self.viewport.selectVisibleRow(visible_row)) self.dirty = true;
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    if (self.sunglassesActive()) {
                        try self.clickSunglassesForm(event.button.x, event.button.y);
                        return true;
                    }
                    if (self.visibleRowAtPoint(event.button.x, event.button.y)) |visible_row| {
                        if (self.viewport.resultAtVisibleRow(visible_row)) |result_index| {
                            try self.queueLaunchAtResult(result_index);
                        }
                    }
                }
            },
            c.SDL_EVENT_KEY_DOWN => {
                if (surface_config.zoomAction(event.key.key, event.key.mod)) |zoom_action| {
                    self.config.applyZoomAction(zoom_action);
                    try self.applySurfaceScale();
                    try self.config.save(self.allocator);
                    self.dirty = true;
                    return true;
                }
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return false;
                    },
                    c.SDLK_BACKSPACE => {
                        trimLastUtf8(&self.query);
                        self.resetCursorBlink();
                        try self.refreshResults();
                    },
                    c.SDLK_TAB => {
                        if (self.sunglassesActive()) {
                            self.sunglasses_form.focusNext((event.key.mod & c.SDL_KMOD_SHIFT) != 0);
                            self.dirty = true;
                        }
                    },
                    c.SDLK_SPACE => {
                        if (self.sunglassesActive() and try self.sunglasses_form.activateFocused(&self.sunglasses_state)) {
                            if (self.sunglasses_form.focusedControlChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                            return true;
                        }
                        if (self.sunglassesActive()) return true;
                    },
                    c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                        if (self.sunglassesActive() and try self.sunglasses_form.activateFocused(&self.sunglasses_state)) {
                            if (self.sunglasses_form.focusedControlChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                            return true;
                        }
                        if (self.sunglassesActive()) return true;
                        try self.queueSelectedLaunch();
                    },
                    c.SDLK_LEFT => {
                        if (self.sunglassesActive() and try self.sunglasses_form.adjustFocused(&self.sunglasses_state, -sliderKeyboardStep())) {
                            if (self.sunglasses_form.focusedControlChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                        }
                    },
                    c.SDLK_RIGHT => {
                        if (self.sunglassesActive() and try self.sunglasses_form.adjustFocused(&self.sunglasses_state, sliderKeyboardStep())) {
                            if (self.sunglasses_form.focusedControlChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                        }
                    },
                    c.SDLK_UP => {
                        if (self.sunglassesActive()) return true;
                        if (self.viewport.moveSelection(-1)) self.dirty = true;
                    },
                    c.SDLK_DOWN => {
                        if (self.sunglassesActive()) return true;
                        if (self.viewport.moveSelection(1)) self.dirty = true;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return true;
    }

    fn refreshResults(self: *SdlShell) !void {
        self.freeResults();
        self.results = try self.service.searchQuery(self.allocator, self.query.items);
        if (self.viewport.resetResults(@intCast(self.results.len))) {
            self.dirty = true;
            return;
        }
        self.dirty = true;
    }

    fn queueSelectedLaunch(self: *SdlShell) !void {
        const result_index = self.viewport.selected() orelse return;
        try self.queueLaunchAtResult(result_index);
    }

    fn queueLaunchAtResult(self: *SdlShell, result_index: u32) !void {
        if (result_index >= self.results.len) return error.ResultIndexOutOfBounds;
        std.debug.assert(result_index < self.results.len);
        if (self.launch_queue.hasQueued()) return error.LaunchAlreadyPending;
        const candidate = self.results[@intCast(result_index)].candidate;
        if (candidate.kind == .mode) {
            try self.switchMode(candidate.action);
            return;
        }
        var plan = try common_dispatch.planCommandKind(self.allocator, uiKind(candidate.kind), candidate.action);
        defer plan.deinit(self.allocator);
        if (!plan.detach_command) return error.LaunchMustDetach;
        if (common_dispatch.shouldRecordCandidate(candidate.kind)) {
            try self.service.recordSelection(self.allocator, candidate.action);
        }
        try self.launch_queue.queue(plan.command);
        self.shutdown_after_launch = true;
    }

    fn switchMode(self: *SdlShell, mode_query: []const u8) !void {
        self.query.clearRetainingCapacity();
        try self.query.appendSlice(self.allocator, mode_query);
        self.resetCursorBlink();
        try self.refreshResults();
    }

    fn drainPendingLaunch(self: *SdlShell) !void {
        try drainLaunchQueue(&self.launch_queue, runDetachedCommand);
    }

    fn render(self: *SdlShell) !void {
        const scale = self.config.scale();
        const scaled = c.SDL_SetRenderScale(self.renderer, scale, scale);
        if (!scaled) return error.SdlRenderFailed;
        const background_color = c.SDL_SetRenderDrawColor(self.renderer, 18, 18, 22, 255);
        const cleared = c.SDL_RenderClear(self.renderer);
        if (!background_color or !cleared) return error.SdlRenderFailed;

        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        try self.drawChrome(layout);
        if (self.sunglassesActive()) {
            try self.sunglasses_form.render(self.renderer, &self.text, layout, self.config.scale(), &self.sunglasses_state);
        } else {
            try self.drawResults(range, layout);
            try self.drawScrollbar(layout);
        }

        const presented = c.SDL_RenderPresent(self.renderer);
        if (!presented) return error.SdlRenderFailed;
    }

    fn visibleRowAtPoint(self: *const SdlShell, x: f32, y: f32) ?u32 {
        const scale = self.config.scale();
        std.debug.assert(scale > 0);
        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        return layout.visibleRowAtPoint(x / scale, y / scale);
    }

    fn clickSunglassesForm(self: *SdlShell, x: f32, y: f32) !void {
        const scale = self.config.scale();
        std.debug.assert(scale > 0);
        const layout = self.currentResultLayout(picker_viewport.max_visible_rows);
        if (try self.sunglasses_form.click(&self.sunglasses_state, layout, x / scale, y / scale)) {
            if (self.sunglasses_form.focusedControlChangesSavedState()) try self.persistAndWakeSunglasses();
            self.dirty = true;
            return;
        }
        self.dirty = true;
    }

    fn persistAndWakeSunglasses(self: *SdlShell) !void {
        try sunglasses_state.save(self.sunglasses_state, self.allocator);
        const runtime_dir = if (std.c.getenv("XDG_RUNTIME_DIR")) |runtime_dir_z|
            std.mem.span(runtime_dir_z)
        else
            return error.HyprlandRuntimeDirMissing;
        try sunglasses_runtime.Runtime.reconcileSavedState(self.allocator, runtime_dir);
    }

    fn sunglassesActive(self: *const SdlShell) bool {
        return query_mod.parse(self.query.items).route == .sunglasses;
    }

    fn updateViewportForWindow(self: *SdlShell) !void {
        var width: i32 = 0;
        var height: i32 = 0;
        const size_read = c.SDL_GetWindowSize(self.window, &width, &height);
        if (!size_read) return error.SdlResizeFailed;
        const window_width = @max(width, 1);
        const window_height = @max(height, 1);

        const scale = self.config.scale();
        std.debug.assert(scale > 0);
        const base_width = @as(f32, @floatFromInt(window_width)) / scale;
        const base_height = @as(f32, @floatFromInt(window_height)) / scale;
        if (self.base_width != base_width or self.base_height != base_height) {
            self.base_width = base_width;
            self.base_height = base_height;
            self.dirty = true;
        }
        const layout = self.currentResultLayout(picker_viewport.max_visible_rows);
        const visible_rows = picker_viewport.visibleRowsForHeight(
            layout.resultAreaHeight(),
            picker_viewport.default_result_row_height,
            picker_viewport.default_result_row_gap,
        );
        if (self.viewport.resize(visible_rows)) self.dirty = true;
    }

    fn currentResultLayout(self: *const SdlShell, visible_rows: u32) picker_viewport.ResultLayout {
        return picker_viewport.ResultLayout.forWindow(self.base_width, self.base_height, visible_rows);
    }

    fn resetCursorBlink(self: *SdlShell) void {
        self.cursor.reset(sdlNowMs());
        self.dirty = true;
    }

    fn applyDefaultWindowSize(self: *SdlShell) !void {
        const size = self.config.scaledDimensions(base_window_width, base_window_height);
        const resized = c.SDL_SetWindowSize(self.window, @intCast(size.width), @intCast(size.height));
        if (!resized) return error.SdlResizeFailed;
    }

    fn drawChrome(self: *SdlShell, layout: picker_viewport.ResultLayout) !void {
        const surface_scale = self.config.scale();
        if (self.query.items.len == 0) {
            try self.text.draw(self.renderer, layout.query_text_x, layout.query_text_y, "Search", .{
                .color = .{ .r = 96, .g = 108, .b = 124 },
                .max_bytes = 16,
                .font_size_px = 17,
                .surface_scale = surface_scale,
            });
            if (self.cursor.visible) try self.text.draw(self.renderer, layout.query_text_x, layout.query_text_y, "", .{
                .color = .{ .r = 168, .g = 185, .b = 204 },
                .max_bytes = 0,
                .font_size_px = 17,
                .surface_scale = surface_scale,
                .cursor_color = .{ .r = 214, .g = 226, .b = 244 },
            });
        } else {
            try self.text.draw(self.renderer, layout.query_text_x, layout.query_text_y, self.query.items, .{
                .color = .{ .r = 168, .g = 185, .b = 204 },
                .max_bytes = 84,
                .font_size_px = 17,
                .surface_scale = surface_scale,
                .cursor_color = if (self.cursor.visible) .{ .r = 214, .g = 226, .b = 244 } else null,
            });
        }

        const query_rect = c.SDL_FRect{
            .x = layout.query_line.x,
            .y = layout.query_line.y,
            .w = layout.query_line.w,
            .h = layout.query_line.h,
        };
        const line_color = c.SDL_SetRenderDrawColor(self.renderer, 64, 74, 84, 255);
        const line_drawn = c.SDL_RenderFillRect(self.renderer, &query_rect);
        if (!line_color or !line_drawn) return error.SdlRenderFailed;
    }

    fn drawResults(self: *SdlShell, range: picker_viewport.VisibleRange, layout: picker_viewport.ResultLayout) !void {
        const selected_result = self.viewport.selected();
        const surface_scale = self.config.scale();
        var i: u32 = 0;
        while (i < range.count) : (i += 1) {
            const result_index = range.start + i;
            std.debug.assert(result_index < self.results.len);
            const result = self.results[@intCast(result_index)].candidate;
            const selected = selected_result == result_index;
            const shade: u8 = if (selected) 64 else 31;
            const row_rect = layout.rowRect(i);
            const row_color = c.SDL_SetRenderDrawColor(
                self.renderer,
                shade,
                shade,
                if (selected) 82 else 38,
                255,
            );
            const rect = c.SDL_FRect{ .x = row_rect.x, .y = row_rect.y, .w = row_rect.w, .h = row_rect.h };
            const filled = c.SDL_RenderFillRect(self.renderer, &rect);
            if (!row_color or !filled) return error.SdlRenderFailed;

            try self.text.draw(self.renderer, layout.title_x, layout.titleY(i), result.title, .{
                .color = if (selected)
                    .{ .r = 246, .g = 248, .b = 252 }
                else
                    .{ .r = 216, .g = 222, .b = 230 },
                .max_bytes = 72,
                .font_size_px = 17,
                .surface_scale = surface_scale,
            });
            try self.text.draw(self.renderer, layout.title_x, layout.subtitleY(i), result.subtitle, .{
                .color = if (selected)
                    .{ .r = 186, .g = 202, .b = 224 }
                else
                    .{ .r = 140, .g = 152, .b = 166 },
                .max_bytes = 82,
                .font_size_px = 14,
                .surface_scale = surface_scale,
            });
            if (result.kind == .app) try self.drawResultIcon(layout.iconRect(i), result.icon);
        }

        if (range.count == 0) {
            try self.text.draw(self.renderer, layout.title_x, layout.titleY(0), "No results", .{
                .color = .{ .r = 190, .g = 198, .b = 208 },
                .max_bytes = 32,
                .font_size_px = 17,
                .surface_scale = surface_scale,
            });
        }
    }

    fn drawResultIcon(self: *SdlShell, icon_rect: picker_viewport.Rect, icon_name: []const u8) !void {
        const texture = self.icons.textureFor(self.renderer, icon_name) orelse return;
        const rect = c.SDL_FRect{
            .x = icon_rect.x,
            .y = icon_rect.y,
            .w = icon_rect.w,
            .h = icon_rect.h,
        };
        const drawn = c.SDL_RenderTexture(self.renderer, texture, null, &rect);
        if (!drawn) return error.SdlRenderFailed;
    }

    fn drawScrollbar(self: *SdlShell, layout: picker_viewport.ResultLayout) !void {
        const scrollbar = layout.scrollbar(&self.viewport);
        if (!scrollbar.needed) return;

        const track_color = c.SDL_SetRenderDrawColor(self.renderer, 38, 44, 52, 255);
        const track = c.SDL_FRect{
            .x = scrollbar.track.x,
            .y = scrollbar.track.y,
            .w = scrollbar.track.w,
            .h = scrollbar.track.h,
        };
        const track_drawn = c.SDL_RenderFillRect(self.renderer, &track);
        if (!track_color or !track_drawn) return error.SdlRenderFailed;

        const thumb_color = c.SDL_SetRenderDrawColor(self.renderer, 104, 118, 136, 255);
        const thumb = c.SDL_FRect{
            .x = scrollbar.thumb.x,
            .y = scrollbar.thumb.y,
            .w = scrollbar.thumb.w,
            .h = scrollbar.thumb.h,
        };
        const thumb_drawn = c.SDL_RenderFillRect(self.renderer, &thumb);
        if (!thumb_color or !thumb_drawn) return error.SdlRenderFailed;
    }

    fn freeResults(self: *SdlShell) void {
        if (self.results.len != 0) {
            self.allocator.free(self.results);
            self.results = &.{};
        }
    }

    fn applySurfaceScale(self: *SdlShell) !void {
        try self.applyDefaultWindowSize();
        const scale = self.config.scale();
        const scaled = c.SDL_SetRenderScale(self.renderer, scale, scale);
        if (!scaled) return error.SdlScaleFailed;
        try self.updateViewportForWindow();
    }
};

fn trimLastUtf8(query: *std.ArrayList(u8)) void {
    if (query.items.len == 0) return;
    var idx = query.items.len - 1;
    while (idx > 0 and (query.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
    query.shrinkRetainingCapacity(idx);
}

fn sdlNowMs() u64 {
    return c.SDL_GetTicks();
}

fn uiKind(kind: @import("../search/mod.zig").CandidateKind) common_dispatch.kinds.UiKind {
    return switch (kind) {
        .app => .app,
        .action => .action,
        .mode => .mode,
        .daemon => .daemon,
        .notification => .notification,
        .hint => .hint,
    };
}

fn loadSunglassesStateForSession(allocator: std.mem.Allocator) !sunglasses_state.State {
    const loaded = try sunglasses_state.load(allocator);
    const runtime_dir = if (std.c.getenv("XDG_RUNTIME_DIR")) |runtime_dir_z|
        std.mem.span(runtime_dir_z)
    else
        return loaded;
    const signature = if (std.c.getenv("HYPRLAND_INSTANCE_SIGNATURE")) |signature_z|
        std.mem.span(signature_z)
    else
        return loaded;

    const monitors = hyprland.queryMonitors(allocator, .{
        .runtime_dir = runtime_dir,
        .signature = signature,
    }) catch |err| {
        std.log.warn("sunglasses monitor state seed skipped err={s}", .{@errorName(err)});
        return loaded;
    };
    if (monitors.count == 0) return loaded;

    return normalizeSunglassesStateForMonitors(loaded, monitors);
}

fn normalizeSunglassesStateForMonitors(loaded: sunglasses_state.State, monitors: hyprland.MonitorList) !sunglasses_state.State {
    var normalized = sunglasses_state.defaultState();
    var index: u32 = 0;
    while (index < monitors.count) : (index += 1) {
        const monitor_name = monitors.items[index].name();
        var monitor_state = if (loaded.get(monitor_name)) |existing|
            existing.*
        else if (loaded.get("default")) |fallback|
            fallback.*
        else
            try sunglasses_state.MonitorState.init(monitor_name);
        try monitor_state.setName(monitor_name);
        try normalized.append(monitor_state);
    }
    return normalized;
}

fn sliderKeyboardStep() i32 {
    return 5;
}

test "sunglasses state maps legacy default values onto real monitor names" {
    var loaded = sunglasses_state.defaultState();
    var fallback = try sunglasses_state.MonitorState.init("default");
    fallback.red_blue_enabled = true;
    fallback.setRedBlueValue(35);
    try loaded.append(fallback);

    var monitors = hyprland.MonitorList{};
    monitors.items[0] = .{};
    const monitor_name = "DP-1";
    @memcpy(monitors.items[0].name_buf[0..monitor_name.len], monitor_name);
    monitors.items[0].name_len = @intCast(monitor_name.len);
    monitors.count = 1;

    const normalized = try normalizeSunglassesStateForMonitors(loaded, monitors);
    try std.testing.expectEqual(@as(u32, 1), normalized.count);
    const monitor = normalized.get("DP-1") orelse return error.MissingMonitorState;
    try std.testing.expect(monitor.red_blue_enabled);
    try std.testing.expectEqual(@as(i32, 35), monitor.red_blue_value);
    try std.testing.expect(normalized.get("default") == null);
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
        std.log.debug("shutdown event write failed err={s}", .{@errorName(err)});
        return;
    };
    if (written != @as(u32, @intCast(@sizeOf(u64)))) {
        std.log.debug("shutdown event short write bytes={d}", .{written});
    }
}

fn osClose(fd: std.posix.fd_t) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) {
        std.log.debug("shutdown fd close failed fd={d}", .{fd});
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

fn drainLaunchQueue(queue: *LaunchQueue, runner: LaunchRunner) LaunchRunError!void {
    if (!queue.hasQueued()) return;
    defer queue.clear();
    try runner(queue.commandZ());
}

fn runDetachedCommand(command: [*:0]const u8) LaunchRunError!void {
    const wrapper_pid = try launchFork();
    if (wrapper_pid == 0) {
        launchWrapperChild(command);
    }
    try launchWait(wrapper_pid);
}

fn launchWrapperChild(command: [*:0]const u8) noreturn {
    const stdio_ok = launchRedirectStdio();
    if (!stdio_ok) std.c._exit(launch_child_fail_code);

    const session_id = std.c.setsid();
    if (session_id == -1) std.c._exit(launch_child_fail_code);

    const app_pid = launchFork() catch std.c._exit(launch_child_fail_code);
    if (app_pid == 0) launchExecShell(command);

    std.c._exit(0);
}

fn launchExecShell(command: [*:0]const u8) noreturn {
    const shell_path = "/bin/sh";
    const shell_name = "sh";
    const shell_arg = "-lc";
    const argv: [4:null]?[*:0]const u8 = .{
        shell_name,
        shell_arg,
        command,
        null,
    };
    const exec_rc = std.c.execve(shell_path, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(launch_child_fail_code);
    std.c._exit(launch_child_fail_code);
}

fn launchRedirectStdio() bool {
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

fn launchFork() LaunchRunError!std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn launchWait(pid: std.c.pid_t) LaunchRunError!void {
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_launch_wait_interrupts) {
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

fn launchRunnerOkForTest(command: [*:0]const u8) LaunchRunError!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
}

fn launchRunnerFailForTest(command: [*:0]const u8) LaunchRunError!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
    return error.CommandFailed;
}

test "cursor blink advances only at its deadline" {
    var cursor = CursorBlink.init(100);

    try std.testing.expect(cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(100));
    try std.testing.expect(!cursor.advance(629));
    try std.testing.expect(cursor.visible);
    try std.testing.expect(cursor.advance(630));
    try std.testing.expect(!cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(630));
}

test "cursor reset shows cursor and restarts deadline" {
    var cursor = CursorBlink.init(0);

    try std.testing.expect(cursor.advance(530));
    try std.testing.expect(!cursor.visible);
    cursor.reset(900);
    try std.testing.expect(cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(900));
    try std.testing.expect(!cursor.advance(1429));
    try std.testing.expect(cursor.advance(1430));
    try std.testing.expect(!cursor.visible);
}

test "launch queue clears after successful drain" {
    var queue = LaunchQueue{};
    try queue.queue("run-me");
    try drainLaunchQueue(&queue, launchRunnerOkForTest);
    try std.testing.expect(!queue.hasQueued());
}

test "launch queue clears after failed drain" {
    var queue = LaunchQueue{};
    try queue.queue("run-me");
    try std.testing.expectError(error.CommandFailed, drainLaunchQueue(&queue, launchRunnerFailForTest));
    try std.testing.expect(!queue.hasQueued());
}
