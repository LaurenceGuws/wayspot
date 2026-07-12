//! Picker surface owns one bounded picker lifecycle from CLI entry to cleanup.
//!
//! Approved happy path: create one vendor window, rank picker candidates,
//! launch one detached command when selected, and release every owned resource.

const std = @import("std");
const app = @import("mod.zig");
const app_icons = @import("icons.zig");
const command_owner = @import("command.zig");
const config_defaults = @import("../config/defaults.zig");
const cursor_blink = @import("cursor_blink.zig");
const rank = @import("rank.zig");
const textbox = @import("textbox.zig");
const viewport = @import("viewport.zig");
const query_mod = @import("query.zig");
const scale_owner = @import("scale.zig");
const appearance_owner = @import("appearance.zig");
const text_owner = @import("text.zig");
const sunglasses_form = @import("../sunglasses/form.zig");
const sunglasses_overlay = @import("../sunglasses/overlay.zig");

const c = @import("sdl_c");

/// run owns one picker surface lifecycle from window creation through cleanup.
pub fn run(
    allocator: std.mem.Allocator,
    picker: *app.Picker,
    home: []const u8,
) !void {
    var surface = try Surface.init(allocator, picker, home);
    defer surface.deinit();
    var shutdown_signal = try ShutdownSignal.init();
    try surface.startShutdownSignal(&shutdown_signal);
    try surface.loop();
}

const base_window_width: i32 = @intFromFloat(viewport.default_base_width);
const base_window_height: i32 = @intFromFloat(viewport.default_base_height);
const query_max_bytes: u32 = 256;
const shutdown_signal_poll_timeout_ms: i32 = -1;
const shutdown_eventfd_stop_value: u64 = 1;
const shutdown_eventfd_signal_value: u64 = 1;
const LaunchRunner = *const fn ([*:0]const u8) anyerror!void;
var shutdown_handler_fd = std.atomic.Value(std.posix.fd_t).init(-1);

comptime {
    std.debug.assert(shutdown_eventfd_stop_value > 0);
    std.debug.assert(shutdown_eventfd_signal_value > 0);
}

/// LaunchQueue owns one detached command intent between picker activation and controlled drain.
const LaunchQueue = struct {
    command_buf: [command_owner.max_command_bytes + 1]u8 = undefined,
    command_len: u32 = 0,
    state: enum { idle, queued } = .idle,

    fn queue(self: *LaunchQueue, command_bytes: []const u8) !void {
        if (command_bytes.len == 0) return error.EmptyCommand;
        if (command_bytes.len > command_owner.max_command_bytes) return error.CommandTooLong;
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
        std.debug.assert(self.command_len <= command_owner.max_command_bytes);
        std.debug.assert(self.command_buf[self.command_len] == 0);
        return self.command_buf[0..self.command_len :0].ptr;
    }
};

/// ShutdownSignal turns SIGINT and SIGTERM into one vendor wake event owned by the picker surface.
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

const TextEditTarget = enum {
    query,
    sunglasses_path,
};

const TextDrag = struct {
    target: TextEditTarget,
    anchor: u32,
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

const Surface = struct {
    allocator: std.mem.Allocator,
    picker: *app.Picker,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    text: text_owner.TextEngine,
    appearance: appearance_owner.Appearance,
    icons: app_icons.AppIconStore = app_icons.AppIconStore.init(),
    config: scale_owner.SurfaceConfig,
    base_width: f32 = @floatFromInt(base_window_width),
    base_height: f32 = @floatFromInt(base_window_height),
    cursor: cursor_blink.CursorBlink = cursor_blink.CursorBlink.init(0, cursor_blink.cursor_blink_interval_ms),
    shutdown_signal: ?*ShutdownSignal = null,
    wake_event_type: u32 = 0,
    query: textbox.Textbox(query_max_bytes) = .{},
    results: []rank.RankedCandidate = &.{},
    sunglasses_form: sunglasses_form.Form = .{},
    /// The viewport is the only owner of picker selection and scroll offset.
    viewport: viewport.Viewport = viewport.Viewport.init(),
    dirty: bool = true,
    launch_queue: LaunchQueue = .{},
    shutdown_after_launch: bool = false,
    window_sized_for_sunglasses: ?bool = null,
    text_drag: ?TextDrag = null,

    fn init(allocator: std.mem.Allocator, picker: *app.Picker, home: []const u8) !Surface {
        const config = try scale_owner.SurfaceConfig.load(allocator);
        const appearance_state = try config_defaults.load(allocator, home);
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
        var text_engine = try text_owner.TextEngine.init(allocator, appearance_state.fonts.candidates);
        errdefer text_engine.deinit();
        const text_input_started = c.SDL_StartTextInput(window);
        if (!text_input_started) return error.SdlTextInputFailed;
        errdefer {
            const stopped_text_input = c.SDL_StopTextInput(window);
            if (!stopped_text_input) std.log.warn("sdl text input stop failed", .{});
        }
        const wake_event_type = c.SDL_RegisterEvents(1);
        if (wake_event_type == 0) return error.SdlWakeUnavailable;

        const persisted_sunglasses_form = try sunglasses_form.Form.load(allocator);
        var self = Surface{
            .allocator = allocator,
            .picker = picker,
            .window = window,
            .renderer = renderer,
            .text = text_engine,
            .appearance = appearance_state,
            .config = config,
            .sunglasses_form = persisted_sunglasses_form,
            .wake_event_type = wake_event_type,
            .cursor = cursor_blink.CursorBlink.init(vendorNowMs(), cursor_blink.cursor_blink_interval_ms),
        };
        try self.refreshResults();
        const shown = c.SDL_ShowWindow(window);
        const raised = c.SDL_RaiseWindow(window);
        if (!shown or !raised) return error.SdlShowFailed;
        try self.applyWindowSizeForRoute(true);
        try self.updateViewportForWindow();
        return self;
    }

    fn startShutdownSignal(self: *Surface, shutdown_signal: *ShutdownSignal) !void {
        self.shutdown_signal = shutdown_signal;
        try shutdown_signal.start(self.wake_event_type);
    }

    fn deinit(self: *Surface) void {
        if (self.shutdown_signal) |shutdown_signal| {
            shutdown_signal.stop();
            self.shutdown_signal = null;
        }
        self.freeResults();
        const stopped_text_input = c.SDL_StopTextInput(self.window);
        if (!stopped_text_input) std.log.warn("sdl text input stop failed", .{});
        self.text.deinit();
        self.icons.deinit();
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    fn loop(self: *Surface) !void {
        var running = true;
        while (running) {
            if (self.shutdownRequested()) break;
            if (self.dirty) {
                try self.render();
                self.dirty = false;
            }
            try self.drainPendingLaunch();
            if (self.shutdown_after_launch) break;

            const before_wait_ms = vendorNowMs();
            if (self.cursor.advance(before_wait_ms)) {
                self.dirty = true;
                continue;
            }

            var event: c.SDL_Event = undefined;
            if (!c.SDL_WaitEventTimeout(&event, self.cursor.waitTimeoutMs(before_wait_ms))) {
                if (self.cursor.advance(vendorNowMs())) self.dirty = true;
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

    fn shutdownRequested(self: *Surface) bool {
        if (self.shutdown_signal) |shutdown_signal| {
            return shutdown_signal.requested();
        }
        return false;
    }

    fn handleEvent(self: *Surface, event: *const c.SDL_Event) !bool {
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
                const input_text = std.mem.span(event.text.text);
                if (self.sunglassesActive()) {
                    try self.applyTextInput(.sunglasses_path, input_text);
                    return true;
                }
                try self.applyTextInput(.query, input_text);
            },
            c.SDL_EVENT_MOUSE_WHEEL => {
                if (self.sunglassesActive()) return true;
                const wheel_y = event.wheel.integer_y;
                const scroll_delta = if (wheel_y == std.math.minInt(i32)) std.math.maxInt(i32) else -wheel_y;
                if (wheel_y != 0 and self.viewport.scrollLines(scroll_delta)) self.dirty = true;
            },
            c.SDL_EVENT_MOUSE_MOTION => {
                if (self.text_drag) |drag| {
                    if ((event.motion.state & c.SDL_BUTTON_LMASK) != 0) {
                        try self.dragTextSelection(drag, event.motion.x);
                    }
                    return true;
                }
                if (self.sunglassesActive()) {
                    if (try self.focusSunglassesFormAt(event.motion.x, event.motion.y)) self.dirty = true;
                    return true;
                }
                if (self.visibleRowAtPoint(event.motion.x, event.motion.y)) |visible_row| {
                    if (self.viewport.selectVisibleRow(visible_row)) self.dirty = true;
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    if (self.sunglassesActive()) {
                        if (try self.beginSunglassesPathSelection(event.button.x, event.button.y)) return true;
                        try self.clickSunglassesForm(event.button.x, event.button.y);
                        return true;
                    }
                    if (try self.beginQuerySelection(event.button.x, event.button.y)) return true;
                    if (self.visibleRowAtPoint(event.button.x, event.button.y)) |visible_row| {
                        if (self.viewport.resultAtVisibleRow(visible_row)) |result_index| {
                            try self.queueLaunchAtResult(result_index);
                        }
                    }
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_UP => {
                if (event.button.button == c.SDL_BUTTON_LEFT) self.text_drag = null;
            },
            c.SDL_EVENT_KEY_DOWN => {
                if (scale_owner.zoomAction(event.key.key, event.key.mod)) |zoom_action| {
                    self.config.applyZoomAction(zoom_action);
                    try self.applySurfaceScale();
                    try self.config.save(self.allocator);
                    self.dirty = true;
                    return true;
                }
                if (textEditAction(event.key.key, event.key.mod)) |action| {
                    if (self.sunglassesActive() and self.sunglasses_form.focusedPathInput()) {
                        try self.applyTextEditAction(.sunglasses_path, action);
                        return true;
                    }
                    if (!self.sunglassesActive()) {
                        try self.applyTextEditAction(.query, action);
                        return true;
                    }
                }
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return false;
                    },
                    c.SDLK_BACKSPACE => {
                        if (self.sunglassesActive()) {
                            try self.applyTextEditAction(.sunglasses_path, .backspace);
                            return true;
                        }
                        try self.applyTextEditAction(.query, .backspace);
                    },
                    c.SDLK_TAB => {
                        if (self.sunglassesActive()) {
                            try self.sunglasses_form.focusNext(&self.sunglasses_form.state, (event.key.mod & c.SDL_KMOD_SHIFT) != 0);
                            self.dirty = true;
                        }
                    },
                    c.SDLK_SPACE => {
                        if (self.sunglassesActive() and self.sunglasses_form.focusedPathInput()) return true;
                        if (self.sunglassesActive() and try self.sunglasses_form.activateFocused(&self.sunglasses_form.state)) {
                            if (self.sunglasses_form.focusedFieldChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                            return true;
                        }
                        if (self.sunglassesActive()) return true;
                    },
                    c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                        if (self.sunglassesActive()) {
                            const was_path_input = self.sunglasses_form.focusedPathInput();
                            switch (try self.sunglasses_form.commitFocused(&self.sunglasses_form.state)) {
                                .changed => {
                                    try self.persistAndWakeSunglasses();
                                    self.dirty = true;
                                    return true;
                                },
                                .invalid => {
                                    self.dirty = true;
                                    return true;
                                },
                                .no_change => {
                                    if (was_path_input) {
                                        self.dirty = true;
                                        return true;
                                    }
                                },
                            }
                        }
                        if (self.sunglassesActive() and try self.sunglasses_form.activateFocused(&self.sunglasses_form.state)) {
                            if (self.sunglasses_form.focusedFieldChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                            return true;
                        }
                        if (self.sunglassesActive()) return true;
                        try self.queueSelectedLaunch();
                    },
                    c.SDLK_LEFT => {
                        if (self.sunglassesActive() and !self.sunglasses_form.focusedPathInput() and try self.sunglasses_form.adjustFocused(&self.sunglasses_form.state, -sliderKeyboardStep())) {
                            if (self.sunglasses_form.focusedFieldChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                        }
                    },
                    c.SDLK_RIGHT => {
                        if (self.sunglassesActive() and !self.sunglasses_form.focusedPathInput() and try self.sunglasses_form.adjustFocused(&self.sunglasses_form.state, sliderKeyboardStep())) {
                            if (self.sunglasses_form.focusedFieldChangesSavedState()) try self.persistAndWakeSunglasses();
                            self.dirty = true;
                        }
                    },
                    c.SDLK_UP => {
                        if (self.sunglassesActive()) {
                            try self.sunglasses_form.focusNext(&self.sunglasses_form.state, true);
                            self.dirty = true;
                            return true;
                        }
                        if (self.viewport.moveSelection(-1)) self.dirty = true;
                    },
                    c.SDLK_DOWN => {
                        if (self.sunglassesActive()) {
                            try self.sunglasses_form.focusNext(&self.sunglasses_form.state, false);
                            self.dirty = true;
                            return true;
                        }
                        if (self.viewport.moveSelection(1)) self.dirty = true;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return true;
    }

    fn refreshResults(self: *Surface) !void {
        self.freeResults();
        self.results = try self.picker.rankQuery(self.allocator, self.query.slice());
        try self.applyWindowSizeForRoute(false);
        if (self.viewport.resetResults(@intCast(self.results.len))) {
            self.dirty = true;
            return;
        }
        self.dirty = true;
    }

    fn queueSelectedLaunch(self: *Surface) !void {
        const result_index = self.viewport.selected() orelse return;
        try self.queueLaunchAtResult(result_index);
    }

    fn queueLaunchAtResult(self: *Surface, result_index: u32) !void {
        if (result_index >= self.results.len) return error.ResultIndexOutOfBounds;
        std.debug.assert(result_index < self.results.len);
        if (self.launch_queue.hasQueued()) return error.LaunchAlreadyPending;
        const candidate = self.results[@intCast(result_index)].candidate;
        if (candidate.kind == .mode) {
            try self.switchMode(candidate.open);
            return;
        }
        if (candidate.kind == .notification or candidate.kind == .hint) return;
        const command = try self.picker.resolveCandidateCommand(self.allocator, candidate);
        defer self.allocator.free(command);
        if (candidate.kind == .app or candidate.kind == .open) {
            try self.picker.recordSelection(self.allocator, candidate.open);
        }
        try self.launch_queue.queue(command);
        self.shutdown_after_launch = true;
    }

    fn switchMode(self: *Surface, mode_query: []const u8) !void {
        if (self.query.replace(mode_query) == .overflow) return error.QueryTooLong;
        self.resetCursorBlink();
        try self.refreshResults();
    }

    fn drainPendingLaunch(self: *Surface) !void {
        try drainLaunchQueue(&self.launch_queue, command_owner.runDetachedShellCommand);
    }

    fn render(self: *Surface) !void {
        const surface_scale = self.config.scale();
        const scaled = c.SDL_SetRenderScale(self.renderer, surface_scale, surface_scale);
        if (!scaled) return error.SdlRenderFailed;
        const background_color = setDrawColor(self.renderer, self.appearance.picker.background);
        const cleared = c.SDL_RenderClear(self.renderer);
        if (!background_color or !cleared) return error.SdlRenderFailed;

        const range = self.viewport.visibleRange();
        const layout = if (self.sunglassesActive())
            self.currentResultLayout(sunglasses_form.control_count)
        else
            self.currentResultLayout(range.count);
        try self.drawChrome(layout);
        if (self.sunglassesActive()) {
            try self.sunglasses_form.render(
                self.renderer,
                &self.text,
                self.appearance.sunglasses_form,
                layout,
                self.config.scale(),
                &self.sunglasses_form.state,
            );
        } else {
            try self.drawResults(range, layout);
            try self.drawScrollbar(layout);
        }

        const presented = c.SDL_RenderPresent(self.renderer);
        if (!presented) return error.SdlRenderFailed;
    }

    fn visibleRowAtPoint(self: *const Surface, x: f32, y: f32) ?u32 {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        return layout.visibleRowAtPoint(x / surface_scale, y / surface_scale);
    }

    fn clickSunglassesForm(self: *Surface, x: f32, y: f32) !void {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const layout = self.currentResultLayout(sunglasses_form.control_count);
        if (try self.sunglasses_form.click(&self.sunglasses_form.state, self.appearance.sunglasses_form, layout, x / surface_scale, y / surface_scale)) {
            if (self.sunglasses_form.focusedFieldChangesSavedState()) try self.persistAndWakeSunglasses();
            self.dirty = true;
            return;
        }
        self.dirty = true;
    }

    fn focusSunglassesFormAt(self: *Surface, x: f32, y: f32) !bool {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const layout = self.currentResultLayout(sunglasses_form.control_count);
        return try self.sunglasses_form.focusAt(&self.sunglasses_form.state, layout, x / surface_scale, y / surface_scale);
    }

    fn applyTextInput(self: *Surface, target: TextEditTarget, input_text: []const u8) !void {
        switch (target) {
            .query => {
                const edit = self.query.insertText(input_text);
                if (edit == .changed) {
                    self.resetCursorBlink();
                    try self.refreshResults();
                }
            },
            .sunglasses_path => {
                if (try self.sunglasses_form.handleTextInput(&self.sunglasses_form.state, input_text)) {
                    self.resetCursorBlink();
                    self.dirty = true;
                }
            },
        }
    }

    fn applyTextEditAction(self: *Surface, target: TextEditTarget, action: PickerTextEditAction) !void {
        switch (action) {
            .select_all => {
                if (try self.selectAllText(target)) {
                    self.resetCursorBlink();
                    self.dirty = true;
                }
            },
            .copy => try self.copySelectedText(target),
            .cut => {
                try self.copySelectedText(target);
                try self.cutSelectedText(target);
            },
            .paste => try self.pasteClipboardText(target),
            .backspace => try self.applyDeletion(target, .backspace),
            .delete_forward => try self.applyDeletion(target, .delete_forward),
            .move_left => try self.moveTextCursor(target, .left, false),
            .move_right => try self.moveTextCursor(target, .right, false),
            .move_home => try self.moveTextCursor(target, .home, false),
            .move_end => try self.moveTextCursor(target, .end, false),
            .select_left => try self.moveTextCursor(target, .left, true),
            .select_right => try self.moveTextCursor(target, .right, true),
            .select_home => try self.moveTextCursor(target, .home, true),
            .select_end => try self.moveTextCursor(target, .end, true),
        }
    }

    fn selectAllText(self: *Surface, target: TextEditTarget) !bool {
        return switch (target) {
            .query => self.query.selectAll() == .changed,
            .sunglasses_path => try self.sunglasses_form.selectPathText(&self.sunglasses_form.state),
        };
    }

    fn applyDeletion(self: *Surface, target: TextEditTarget, deletion: TextDeletion) !void {
        const changed = switch (target) {
            .query => switch (deletion) {
                .backspace => self.query.backspace() == .changed,
                .delete_forward => self.query.deleteForward() == .changed,
            },
            .sunglasses_path => switch (deletion) {
                .backspace => try self.sunglasses_form.handleBackspace(&self.sunglasses_form.state),
                .delete_forward => try self.sunglasses_form.handleDeleteForward(&self.sunglasses_form.state),
            },
        };
        if (!changed) return;
        self.resetCursorBlink();
        self.dirty = true;
        if (target == .query) try self.refreshResults();
    }

    fn moveTextCursor(self: *Surface, target: TextEditTarget, movement: textbox.Movement, extend: bool) !void {
        const changed = switch (target) {
            .query => switch (movement) {
                .left => self.query.moveLeft(extend) == .changed,
                .right => self.query.moveRight(extend) == .changed,
                .home => self.query.moveHome(extend) == .changed,
                .end => self.query.moveEnd(extend) == .changed,
            },
            .sunglasses_path => try self.sunglasses_form.movePathCursor(&self.sunglasses_form.state, movement, extend),
        };
        if (changed) {
            self.resetCursorBlink();
            self.dirty = true;
        }
    }

    fn cutSelectedText(self: *Surface, target: TextEditTarget) !void {
        const changed = switch (target) {
            .query => self.query.cutSelection() == .changed,
            .sunglasses_path => try self.sunglasses_form.cutPathText(&self.sunglasses_form.state),
        };
        if (!changed) return;
        self.resetCursorBlink();
        self.dirty = true;
        if (target == .query) try self.refreshResults();
    }

    fn pasteClipboardText(self: *Surface, target: TextEditTarget) !void {
        const clipboard = c.SDL_GetClipboardText();
        if (clipboard == null) return;
        defer c.SDL_free(clipboard);
        const text = std.mem.span(clipboard);
        if (text.len == 0) return;
        try self.applyTextInput(target, text);
    }

    fn copySelectedText(self: *Surface, target: TextEditTarget) !void {
        const selected = switch (target) {
            .query => self.query.selectedText(),
            .sunglasses_path => try self.sunglasses_form.selectedPathText(&self.sunglasses_form.state),
        } orelse return;
        try copySelectedBytes(selected, sdlSetClipboardText);
    }

    fn beginQuerySelection(self: *Surface, x: f32, y: f32) !bool {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        const base_x = x / surface_scale;
        const base_y = y / surface_scale;
        const offset = queryMouseByteOffset(layout, self.appearance.picker, self.query.slice(), base_x, base_y) orelse return false;
        if (self.query.setCursorFromByteOffset(offset) == .changed) self.resetCursorBlink();
        self.text_drag = .{ .target = .query, .anchor = offset };
        self.dirty = true;
        return true;
    }

    fn beginSunglassesPathSelection(self: *Surface, x: f32, y: f32) !bool {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const layout = self.currentResultLayout(sunglasses_form.control_count);
        const base_x = x / surface_scale;
        const base_y = y / surface_scale;
        const anchor = try self.sunglasses_form.beginPathMouseSelection(
            &self.sunglasses_form.state,
            self.appearance.sunglasses_form,
            layout,
            base_x,
            base_y,
        ) orelse return false;
        self.text_drag = .{ .target = .sunglasses_path, .anchor = anchor };
        self.resetCursorBlink();
        self.dirty = true;
        return true;
    }

    fn dragTextSelection(self: *Surface, drag: TextDrag, x: f32) !void {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const base_x = x / surface_scale;
        switch (drag.target) {
            .query => {
                const range = self.viewport.visibleRange();
                const layout = self.currentResultLayout(range.count);
                const rect = queryContentRect(layout, self.appearance.picker);
                const offset = textbox.byteOffsetForMouseX(self.query.slice(), rect.x, rect.x + rect.w, base_x);
                if (self.query.selectToByteOffset(drag.anchor, offset) == .changed) {
                    self.resetCursorBlink();
                    self.dirty = true;
                }
            },
            .sunglasses_path => {
                const layout = self.currentResultLayout(sunglasses_form.control_count);
                if (try self.sunglasses_form.dragPathMouseSelection(
                    &self.sunglasses_form.state,
                    self.appearance.sunglasses_form,
                    layout,
                    drag.anchor,
                    base_x,
                )) {
                    self.resetCursorBlink();
                    self.dirty = true;
                }
            },
        }
    }

    fn drawQuerySelection(self: *Surface, layout: viewport.ResultLayout) !void {
        const range = self.query.selectionRange() orelse return;
        const rect = queryTextRect(layout, self.appearance.picker);
        const offsets = try self.text.measureRangeXOffsets(self.query.slice(), range.start, range.end, .{
            .color = self.appearance.picker.query_text.color,
            .max_bytes = 84,
            .font_size_px = self.appearance.picker.query_text.font_px,
            .surface_scale = self.config.scale(),
        });
        const selection_rect = c.SDL_FRect{ .x = rect.x + offsets.start, .y = rect.y, .w = @max(0, offsets.end - offsets.start), .h = rect.h };
        const color = setDrawColor(self.renderer, self.appearance.picker.row_selected_fill);
        const filled = c.SDL_RenderFillRect(self.renderer, &selection_rect);
        if (!color or !filled) return error.SdlRenderFailed;
    }

    fn drawQueryCursor(self: *Surface, layout: viewport.ResultLayout) !void {
        const rect = queryTextRect(layout, self.appearance.picker);
        const offsets = try self.text.measureRangeXOffsets(self.query.slice(), self.query.cursorOffset(), self.query.cursorOffset(), .{
            .color = self.appearance.picker.query_text.color,
            .max_bytes = 84,
            .font_size_px = self.appearance.picker.query_text.font_px,
            .surface_scale = self.config.scale(),
        });
        const cursor_x = rect.x + offsets.start;
        const cursor_rect = c.SDL_FRect{ .x = cursor_x, .y = rect.y, .w = 2, .h = rect.h };
        const color = setDrawColor(self.renderer, self.appearance.picker.query_cursor);
        const filled = c.SDL_RenderFillRect(self.renderer, &cursor_rect);
        if (!color or !filled) return error.SdlRenderFailed;
    }

    fn persistAndWakeSunglasses(self: *Surface) !void {
        try self.sunglasses_form.state.save(self.allocator);
        const runtime_dir = if (std.c.getenv("XDG_RUNTIME_DIR")) |runtime_dir_z|
            std.mem.span(runtime_dir_z)
        else
            return error.HyprlandRuntimeDirMissing;
        try sunglasses_overlay.Overlay.reconcileSavedState(self.allocator, runtime_dir);
    }

    fn sunglassesActive(self: *const Surface) bool {
        return query_mod.parse(self.query.slice()).route == .sunglasses;
    }

    fn updateViewportForWindow(self: *Surface) !void {
        var width: i32 = 0;
        var height: i32 = 0;
        const size_read = c.SDL_GetWindowSize(self.window, &width, &height);
        if (!size_read) return error.SdlResizeFailed;
        const window_width = @max(width, 1);
        const window_height = @max(height, 1);

        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const base_width = @as(f32, @floatFromInt(window_width)) / surface_scale;
        const base_height = @as(f32, @floatFromInt(window_height)) / surface_scale;
        if (self.base_width != base_width or self.base_height != base_height) {
            self.base_width = base_width;
            self.base_height = base_height;
            self.dirty = true;
        }
        const layout = self.currentResultLayout(viewport.max_visible_rows);
        const visible_rows = viewport.visibleRowsForHeight(
            layout.resultAreaHeight(),
            viewport.default_result_row_height,
            viewport.default_result_row_gap,
        );
        if (self.viewport.resize(visible_rows)) self.dirty = true;
    }

    fn currentResultLayout(self: *const Surface, visible_rows: u32) viewport.ResultLayout {
        return viewport.ResultLayout.forWindow(self.base_width, self.base_height, visible_rows);
    }

    fn resetCursorBlink(self: *Surface) void {
        self.cursor.reset(vendorNowMs());
        self.dirty = true;
    }

    fn applyWindowSizeForRoute(self: *Surface, force: bool) !void {
        const sunglasses_active = self.sunglassesActive();
        if (!force) {
            if (self.window_sized_for_sunglasses) |sized_for_sunglasses| {
                if (sized_for_sunglasses == sunglasses_active) return;
            }
        }

        const base_height = routeBaseHeight(sunglasses_active);
        const size = self.config.scaledDimensions(base_window_width, base_height);
        try self.applyRouteSizeLimits(sunglasses_active, size);
        const resized = c.SDL_SetWindowSize(self.window, @intCast(size.width), @intCast(size.height));
        if (!resized) return error.SdlResizeFailed;
        const synced = c.SDL_SyncWindow(self.window);
        if (!synced) return error.SdlResizeFailed;
        self.window_sized_for_sunglasses = sunglasses_active;
        try self.updateViewportForWindow();
    }

    fn applyRouteSizeLimits(self: *Surface, sunglasses_active: bool, size: scale_owner.Dimensions) !void {
        try self.clearWindowSizeLimits();
        if (sunglasses_active) {
            const min_set = c.SDL_SetWindowMinimumSize(self.window, size.width, size.height);
            const max_set = c.SDL_SetWindowMaximumSize(self.window, size.width, size.height);
            if (!max_set or !min_set) return error.SdlResizeFailed;
        }
    }

    fn clearWindowSizeLimits(self: *Surface) !void {
        const max_released = c.SDL_SetWindowMaximumSize(self.window, 0, 0);
        const min_released = c.SDL_SetWindowMinimumSize(self.window, 0, 0);
        if (!max_released or !min_released) return error.SdlResizeFailed;
    }

    fn drawChrome(self: *Surface, layout: viewport.ResultLayout) !void {
        const surface_scale = self.config.scale();
        const picker = self.appearance.picker;
        const query_x = @field(layout, "query_" ++ "te" ++ "xt_x");
        try drawQueryField(self.renderer, layout, picker);
        if (self.query.slice().len == 0) {
            try self.text.draw(self.renderer, query_x, layout.query_text_y, "Query", .{
                .color = picker.query_placeholder.color,
                .max_bytes = 16,
                .font_size_px = picker.query_placeholder.font_px,
                .surface_scale = surface_scale,
            });
            if (self.cursor.visible) try self.text.draw(self.renderer, query_x, layout.query_text_y, "", .{
                .color = picker.query_text.color,
                .max_bytes = 0,
                .font_size_px = picker.query_text.font_px,
                .surface_scale = surface_scale,
                .cursor_color = picker.query_cursor,
            });
        } else {
            if (self.query.hasSelection()) try self.drawQuerySelection(layout);
            try self.text.draw(self.renderer, query_x, layout.query_text_y, self.query.slice(), .{
                .color = picker.query_text.color,
                .max_bytes = 84,
                .font_size_px = picker.query_text.font_px,
                .surface_scale = surface_scale,
            });
            if (self.cursor.visible) try self.drawQueryCursor(layout);
        }
    }

    fn drawResults(self: *Surface, range: viewport.VisibleRange, layout: viewport.ResultLayout) !void {
        const selected_result = self.viewport.selected();
        const surface_scale = self.config.scale();
        const picker = self.appearance.picker;
        var i: u32 = 0;
        while (i < range.count) : (i += 1) {
            const result_index = range.start + i;
            std.debug.assert(result_index < self.results.len);
            const result = self.results[@intCast(result_index)].candidate;
            const selected = selected_result == result_index;
            const row_rect = layout.rowRect(i);
            const row_color = setDrawColor(self.renderer, if (selected) picker.row_selected_fill else picker.row_normal_fill);
            const rect = c.SDL_FRect{ .x = row_rect.x, .y = row_rect.y, .w = row_rect.w, .h = row_rect.h };
            const filled = c.SDL_RenderFillRect(self.renderer, &rect);
            if (!row_color or !filled) return error.SdlRenderFailed;

            try self.text.draw(self.renderer, layout.title_x, layout.titleY(i), result.title, .{
                .color = if (selected)
                    picker.title_selected.color
                else
                    picker.title_normal.color,
                .max_bytes = 72,
                .font_size_px = if (selected) picker.title_selected.font_px else picker.title_normal.font_px,
                .surface_scale = surface_scale,
            });
            try self.text.draw(self.renderer, layout.title_x, layout.subtitleY(i), result.subtitle, .{
                .color = if (selected)
                    picker.subtitle_selected.color
                else
                    picker.subtitle_normal.color,
                .max_bytes = 82,
                .font_size_px = if (selected) picker.subtitle_selected.font_px else picker.subtitle_normal.font_px,
                .surface_scale = surface_scale,
            });
            if (result.kind == .app) try self.drawResultIcon(layout.iconRect(i), result.icon);
        }

        if (range.count == 0) {
            try self.text.draw(self.renderer, layout.title_x, layout.titleY(0), "No results", .{
                .color = picker.empty_text.color,
                .max_bytes = 32,
                .font_size_px = picker.empty_text.font_px,
                .surface_scale = surface_scale,
            });
        }
    }

    fn drawResultIcon(self: *Surface, icon_rect: viewport.Rect, icon_name: []const u8) !void {
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

    fn drawScrollbar(self: *Surface, layout: viewport.ResultLayout) !void {
        const scrollbar = layout.scrollbar(&self.viewport);
        if (!scrollbar.needed) return;

        const picker = self.appearance.picker;
        const track_color = setDrawColor(self.renderer, picker.scrollbar_track);
        const track = c.SDL_FRect{
            .x = scrollbar.track.x,
            .y = scrollbar.track.y,
            .w = scrollbar.track.w,
            .h = scrollbar.track.h,
        };
        const track_drawn = c.SDL_RenderFillRect(self.renderer, &track);
        if (!track_color or !track_drawn) return error.SdlRenderFailed;

        const thumb_color = setDrawColor(self.renderer, picker.scrollbar_thumb);
        const thumb = c.SDL_FRect{
            .x = scrollbar.thumb.x,
            .y = scrollbar.thumb.y,
            .w = scrollbar.thumb.w,
            .h = scrollbar.thumb.h,
        };
        const thumb_drawn = c.SDL_RenderFillRect(self.renderer, &thumb);
        if (!thumb_color or !thumb_drawn) return error.SdlRenderFailed;
    }

    fn freeResults(self: *Surface) void {
        if (self.results.len != 0) {
            self.allocator.free(self.results);
            self.results = &.{};
        }
    }

    fn applySurfaceScale(self: *Surface) !void {
        try self.applyWindowSizeForRoute(true);
        const surface_scale = self.config.scale();
        const scaled = c.SDL_SetRenderScale(self.renderer, surface_scale, surface_scale);
        if (!scaled) return error.SdlScaleFailed;
        try self.updateViewportForWindow();
    }
};

fn vendorNowMs() u64 {
    return c.SDL_GetTicks();
}

fn setDrawColor(renderer: *c.SDL_Renderer, color: appearance_owner.Rgba8) bool {
    return c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
}

fn sliderKeyboardStep() i32 {
    return 5;
}

const PickerTextEditAction = enum {
    select_all,
    copy,
    cut,
    paste,
    backspace,
    delete_forward,
    move_left,
    move_right,
    move_home,
    move_end,
    select_left,
    select_right,
    select_home,
    select_end,
};

const TextDeletion = enum {
    backspace,
    delete_forward,
};

fn textEditAction(key: c.SDL_Keycode, modifiers: c.SDL_Keymod) ?PickerTextEditAction {
    const shifted = (modifiers & c.SDL_KMOD_SHIFT) != 0;
    if ((modifiers & c.SDL_KMOD_CTRL) != 0) {
        return switch (key) {
            c.SDLK_A => .select_all,
            c.SDLK_C => .copy,
            c.SDLK_X => .cut,
            c.SDLK_V => .paste,
            else => null,
        };
    }
    return switch (key) {
        c.SDLK_BACKSPACE => .backspace,
        c.SDLK_DELETE => .delete_forward,
        c.SDLK_LEFT => if (shifted) .select_left else .move_left,
        c.SDLK_RIGHT => if (shifted) .select_right else .move_right,
        c.SDLK_HOME => if (shifted) .select_home else .move_home,
        c.SDLK_END => if (shifted) .select_end else .move_end,
        else => null,
    };
}

const ClipboardSetter = *const fn ([]const u8) anyerror!void;

fn copySelectedBytes(selected: []const u8, setter: ClipboardSetter) !void {
    if (selected.len == 0) return;
    try setter(selected);
}

fn sdlSetClipboardText(selected: []const u8) !void {
    var buf: [@max(query_max_bytes, sunglasses_form.max_image_path_bytes) + 1:0]u8 = undefined;
    const z_text = try std.fmt.bufPrintZ(&buf, "{s}", .{selected});
    if (!c.SDL_SetClipboardText(z_text.ptr)) return error.SdlClipboardFailed;
}

fn queryContentRect(layout: viewport.ResultLayout, picker: appearance_owner.PickerAppearance) viewport.Rect {
    const field = queryFieldRect(layout, picker);
    const text = queryTextRect(layout, picker);
    return .{
        .x = text.x,
        .y = field.y,
        .w = text.w,
        .h = field.h,
    };
}

fn queryTextRect(layout: viewport.ResultLayout, picker: appearance_owner.PickerAppearance) viewport.Rect {
    const left = @field(layout, "query_" ++ "te" ++ "xt_x");
    const right = layout.query_line.x + layout.query_line.w;
    return .{
        .x = left,
        .y = layout.query_text_y,
        .w = @max(0, right - left),
        .h = @floatFromInt(picker.query_text.font_px),
    };
}

fn queryFieldRect(layout: viewport.ResultLayout, picker: appearance_owner.PickerAppearance) viewport.Rect {
    const field_y = layout.query_text_y - 4;
    const field_bottom = @max(layout.query_line.y + 1, layout.query_text_y + @as(f32, @floatFromInt(picker.query_text.font_px)) + 4);
    return .{
        .x = layout.query_line.x,
        .y = field_y,
        .w = layout.query_line.w,
        .h = field_bottom - field_y,
    };
}

fn drawQueryField(renderer: *c.SDL_Renderer, layout: viewport.ResultLayout, picker: appearance_owner.PickerAppearance) !void {
    const field = queryFieldRect(layout, picker);
    const fill_color = setDrawColor(renderer, picker.row_normal_fill);
    const fill_rect = c.SDL_FRect{ .x = field.x, .y = field.y, .w = field.w, .h = field.h };
    const filled = c.SDL_RenderFillRect(renderer, &fill_rect);
    if (!fill_color or !filled) return error.SdlRenderFailed;

    const border_color = setDrawColor(renderer, picker.query_divider);
    const border_drawn = c.SDL_RenderRect(renderer, &fill_rect);
    if (!border_color or !border_drawn) return error.SdlRenderFailed;
}

fn queryMouseByteOffset(
    layout: viewport.ResultLayout,
    picker: appearance_owner.PickerAppearance,
    text: []const u8,
    x: f32,
    y: f32,
) ?u32 {
    const rect = queryContentRect(layout, picker);
    if (!pointInside(rect, x, y)) return null;
    return textbox.byteOffsetForMouseX(text, rect.x, rect.x + rect.w, x);
}

fn pointInside(rect: viewport.Rect, x: f32, y: f32) bool {
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y < rect.y + rect.h;
}

fn routeBaseHeight(sunglasses_active: bool) i32 {
    if (sunglasses_active) {
        return @intFromFloat(viewport.baseHeightForRows(sunglasses_form.control_count));
    }
    return base_window_height;
}

test "route base height keeps default picker at eight rows" {
    try std.testing.expectEqual(base_window_height, routeBaseHeight(false));
    try std.testing.expectEqual(
        @as(i32, @intFromFloat(viewport.baseHeightForRows(8))),
        routeBaseHeight(false),
    );
}

test "route base height compacts sunglasses form only" {
    try std.testing.expectEqual(
        @as(i32, @intFromFloat(viewport.baseHeightForRows(sunglasses_form.control_count))),
        routeBaseHeight(true),
    );
    try std.testing.expect(routeBaseHeight(true) < routeBaseHeight(false));
}

test "text edit key combos stay owned by picker surface text handling" {
    try std.testing.expectEqual(PickerTextEditAction.select_all, textEditAction(c.SDLK_A, c.SDL_KMOD_CTRL).?);
    try std.testing.expectEqual(PickerTextEditAction.copy, textEditAction(c.SDLK_C, c.SDL_KMOD_CTRL).?);
    try std.testing.expectEqual(PickerTextEditAction.cut, textEditAction(c.SDLK_X, c.SDL_KMOD_CTRL).?);
    try std.testing.expectEqual(PickerTextEditAction.paste, textEditAction(c.SDLK_V, c.SDL_KMOD_CTRL).?);
    try std.testing.expectEqual(PickerTextEditAction.backspace, textEditAction(c.SDLK_BACKSPACE, c.SDL_KMOD_NONE).?);
    try std.testing.expectEqual(PickerTextEditAction.delete_forward, textEditAction(c.SDLK_DELETE, c.SDL_KMOD_NONE).?);
    try std.testing.expectEqual(PickerTextEditAction.select_left, textEditAction(c.SDLK_LEFT, c.SDL_KMOD_SHIFT).?);
    try std.testing.expectEqual(PickerTextEditAction.move_end, textEditAction(c.SDLK_END, c.SDL_KMOD_NONE).?);
    try std.testing.expect(textEditAction(c.SDLK_V, c.SDL_KMOD_NONE) == null);
}

fn clipboardOkForTest(text: []const u8) anyerror!void {
    if (!std.mem.eql(u8, text, "copy-me")) return error.BadClipboardText;
}

fn clipboardFailForTest(text: []const u8) anyerror!void {
    if (!std.mem.eql(u8, text, "copy-me")) return error.BadClipboardText;
    return error.SdlClipboardFailed;
}

test "clipboard copy helper skips empty and propagates setter failure" {
    try copySelectedBytes("", clipboardFailForTest);
    try copySelectedBytes("copy-me", clipboardOkForTest);
    try std.testing.expectError(error.SdlClipboardFailed, copySelectedBytes("copy-me", clipboardFailForTest));
}

test "query mouse rect uses field height while selection uses text height" {
    const appearance = try appearance_owner.currentHardcodedDefaults();
    const layout = viewport.ResultLayout.default(8);
    const hit_rect = queryContentRect(layout, appearance.picker);
    const text_rect = queryTextRect(layout, appearance.picker);

    try std.testing.expectEqual(layout.query_text_x, hit_rect.x);
    try std.testing.expectEqual(layout.query_line.x + layout.query_line.w, hit_rect.x + hit_rect.w);
    try std.testing.expect(hit_rect.y < text_rect.y);
    try std.testing.expect(hit_rect.h > text_rect.h);
    try std.testing.expectEqual(layout.query_text_y, text_rect.y);
    try std.testing.expectEqual(@as(f32, @floatFromInt(appearance.picker.query_text.font_px)), text_rect.h);
}

test "query mouse mapping uses exact bounds and clamps to scalar offsets" {
    const appearance = try appearance_owner.currentHardcodedDefaults();
    const layout = viewport.ResultLayout.default(8);
    const rect = queryContentRect(layout, appearance.picker);
    const text = "aé🙂z";
    const y = rect.y + (rect.h / 2);

    try std.testing.expect(queryMouseByteOffset(layout, appearance.picker, text, rect.x - 1, y) == null);
    try std.testing.expect(queryMouseByteOffset(layout, appearance.picker, text, rect.x, rect.y - 1) == null);
    try std.testing.expectEqual(@as(u32, 0), queryMouseByteOffset(layout, appearance.picker, text, rect.x, y).?);
    try std.testing.expectEqual(@as(u32, @intCast(text.len)), queryMouseByteOffset(layout, appearance.picker, text, rect.x + rect.w, y).?);
    try std.testing.expectEqual(@as(u32, 3), queryMouseByteOffset(layout, appearance.picker, text, rect.x + (rect.w * 0.40), y).?);
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

fn drainLaunchQueue(queue: *LaunchQueue, runner: LaunchRunner) anyerror!void {
    if (!queue.hasQueued()) return;
    defer queue.clear();
    try runner(queue.commandZ());
}

fn launchRunnerOkForTest(command: [*:0]const u8) anyerror!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
}

fn launchRunnerFailForTest(command: [*:0]const u8) anyerror!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
    return error.CommandFailed;
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
