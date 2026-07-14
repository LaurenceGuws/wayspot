//! GUI surface owns the SDL consumer lifecycle from creation to cleanup.
//!
//! It edits one query, consumes command candidates, renders rows, and queues
//! one resolved intent for the surface-owned shutdown handoff. It imports no
//! notification, wallpaper, or sunglasses implementation files.

const std = @import("std");
const picker_owner = @import("wayspot_picker");
const app_icons = picker_owner.icons;
const candidate_owner = picker_owner.candidate;
const command_owner = picker_owner.cmd;
const process_owner = @import("wayspot_process");
const config_defaults = @import("wayspot_config_defaults");
const cursor_blink = picker_owner.cursor_blink;
const rank = picker_owner.rank;
const textbox = picker_owner.textbox;
const viewport = picker_owner.viewport;
const scale_owner = picker_owner.scale;
const signal_owner = picker_owner.signal;
const appearance_owner = picker_owner.appearance;
const text_owner = picker_owner.text;

const c = @import("sdl_c");

/// run owns one GUI picker lifecycle from window creation through cleanup.
pub fn run(
    allocator: std.mem.Allocator,
    picker: *command_owner.Picker,
    home: []const u8,
) !void {
    try picker.loadHistory(allocator);
    defer picker.saveHistory(allocator) catch |err| {
        std.log.err("failed to save history: {s}", .{@errorName(err)});
    };

    var surface = try Surface.init(allocator, picker, home);
    defer surface.deinit();
    var shutdown_signal = try signal_owner.Signal.init();
    try surface.startShutdownSignal(&shutdown_signal);
    try surface.loop();
}

const base_window_width: i32 = @intFromFloat(viewport.default_base_width);
const base_window_height: i32 = @intFromFloat(viewport.default_base_height);
const query_owner = picker_owner.query;
const query_max_bytes: u32 = @intCast(query_owner.max_query_bytes);

const TextDrag = struct {
    anchor: u32,
};

/// LaunchRunner is the process-boundary function consumed by GUI queue drain.
const LaunchRunner = *const fn ([]const u8) process_owner.LaunchError!void;

/// LaunchQueue owns one bounded GUI leaf intent until the interface drains it.
const LaunchQueue = struct {
    intent_buf: [process_owner.max_intent_bytes]u8 = undefined,
    intent_len: usize = 0,
    state: enum { idle, queued } = .idle,

    /// queue stores one non-empty bounded intent without allocation. Process
    /// owns sentinel construction when this intent crosses the launch boundary.
    fn queue(self: *LaunchQueue, intent_bytes: []const u8) !void {
        if (intent_bytes.len == 0) return error.EmptyIntent;
        if (intent_bytes.len > process_owner.max_intent_bytes) return error.IntentTooLong;
        std.debug.assert(self.state == .idle);
        @memcpy(self.intent_buf[0..intent_bytes.len], intent_bytes);
        self.intent_len = intent_bytes.len;
        self.state = .queued;
    }

    fn clear(self: *LaunchQueue) void {
        std.debug.assert(self.state == .queued);
        @memset(self.intent_buf[0..self.intent_len], 0);
        self.intent_len = 0;
        self.state = .idle;
    }

    fn hasQueued(self: *const LaunchQueue) bool {
        return self.state == .queued;
    }

    fn intent(self: *const LaunchQueue) []const u8 {
        std.debug.assert(self.state == .queued);
        std.debug.assert(self.intent_len > 0);
        std.debug.assert(self.intent_len <= process_owner.max_intent_bytes);
        return self.intent_buf[0..self.intent_len];
    }
};

const Surface = struct {
    allocator: std.mem.Allocator,
    picker: *command_owner.Picker,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    text: text_owner.TextEngine,
    appearance: appearance_owner.Appearance,
    icons: app_icons.AppIconStore = app_icons.AppIconStore.init(),
    config: scale_owner.SurfaceConfig,
    base_width: f32 = @floatFromInt(base_window_width),
    base_height: f32 = @floatFromInt(base_window_height),
    cursor: cursor_blink.CursorBlink = cursor_blink.CursorBlink.init(0, cursor_blink.cursor_blink_interval_ms),
    shutdown_signal: ?*signal_owner.Signal = null,
    query: textbox.Textbox(query_max_bytes) = .{},
    results: []rank.RankedCandidate = &.{},
    /// The viewport is the only owner of picker selection and scroll offset.
    viewport: viewport.Viewport = viewport.Viewport.init(),
    dirty: bool = true,
    launch_queue: LaunchQueue = .{},
    shutdown_after_launch: bool = false,
    text_drag: ?TextDrag = null,

    fn init(allocator: std.mem.Allocator, picker: *command_owner.Picker, home: []const u8) !Surface {
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
        var self = Surface{
            .allocator = allocator,
            .picker = picker,
            .window = window,
            .renderer = renderer,
            .text = text_engine,
            .appearance = appearance_state,
            .config = config,
            .cursor = cursor_blink.CursorBlink.init(vendorNowMs(), cursor_blink.cursor_blink_interval_ms),
        };
        try self.refreshResults();
        const shown = c.SDL_ShowWindow(window);
        const raised = c.SDL_RaiseWindow(window);
        if (!shown or !raised) return error.SdlShowFailed;
        try self.updateViewportForWindow();
        return self;
    }

    fn startShutdownSignal(self: *Surface, shutdown_signal: *signal_owner.Signal) !void {
        self.shutdown_signal = shutdown_signal;
        try shutdown_signal.start();
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
                try self.applyTextInput(input_text);
            },
            c.SDL_EVENT_MOUSE_WHEEL => {
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
                if (self.visibleRowAtPoint(event.motion.x, event.motion.y)) |visible_row| {
                    if (self.viewport.selectVisibleRow(visible_row)) self.dirty = true;
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
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
                    try self.applyTextEditAction(action);
                    return true;
                }
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return false;
                    },
                    c.SDLK_BACKSPACE => {
                        try self.applyTextEditAction(.backspace);
                    },
                    c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                        try self.queueSelectedLaunch();
                    },
                    c.SDLK_UP => {
                        if (self.viewport.moveSelection(-1)) self.dirty = true;
                    },
                    c.SDLK_DOWN => {
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

    /// queueLaunchAtResult enters a SubCmd route directly or queues one resolved Concrete leaf.
    fn queueLaunchAtResult(self: *Surface, result_index: u32) !void {
        if (result_index >= self.results.len) return error.ResultIndexOutOfBounds;
        std.debug.assert(result_index < self.results.len);
        if (self.launch_queue.hasQueued()) return error.LaunchAlreadyPending;
        const candidate = self.results[@intCast(result_index)].candidate;
        if (!candidate_owner.Candidate.accepts(.selection, candidate)) return;
        if (candidate.isSubCmd()) {
            try self.switchMode(try routeQueryForSelection(candidate));
            return;
        }
        if (!candidate.isLaunchable()) return;
        const command = try self.picker.resolveCandidateCommand(self.allocator, candidate);
        defer self.allocator.free(command);
        if (candidate.isApp() or candidate.isOpen()) {
            try self.picker.recordSelection(self.allocator, candidate.openPayload());
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
        try drainLaunchQueue(&self.launch_queue, process_owner.runDetached);
    }

    fn render(self: *Surface) !void {
        const surface_scale = self.config.scale();
        const scaled = c.SDL_SetRenderScale(self.renderer, surface_scale, surface_scale);
        if (!scaled) return error.SdlRenderFailed;
        const background_color = setDrawColor(self.renderer, self.appearance.picker.background);
        const cleared = c.SDL_RenderClear(self.renderer);
        if (!background_color or !cleared) return error.SdlRenderFailed;

        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        try self.drawChrome(layout);
        try self.drawResults(range, layout);
        try self.drawScrollbar(layout);

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

    fn applyTextInput(self: *Surface, input_text: []const u8) !void {
        const edit = self.query.insertText(input_text);
        if (edit == .changed) {
            self.resetCursorBlink();
            try self.refreshResults();
        }
    }

    fn applyTextEditAction(self: *Surface, action: PickerTextEditAction) !void {
        switch (action) {
            .select_all => {
                if (self.query.selectAll() == .changed) {
                    self.resetCursorBlink();
                    self.dirty = true;
                }
            },
            .copy => try self.copySelectedText(),
            .cut => {
                try self.copySelectedText();
                try self.cutSelectedText();
            },
            .paste => try self.pasteClipboardText(),
            .backspace => try self.applyDeletion(.backspace),
            .delete_forward => try self.applyDeletion(.delete_forward),
            .move_left => try self.moveTextCursor(.left, false),
            .move_right => try self.moveTextCursor(.right, false),
            .move_home => try self.moveTextCursor(.home, false),
            .move_end => try self.moveTextCursor(.end, false),
            .select_left => try self.moveTextCursor(.left, true),
            .select_right => try self.moveTextCursor(.right, true),
            .select_home => try self.moveTextCursor(.home, true),
            .select_end => try self.moveTextCursor(.end, true),
        }
    }

    fn applyDeletion(self: *Surface, deletion: TextDeletion) !void {
        const changed = switch (deletion) {
            .backspace => self.query.backspace() == .changed,
            .delete_forward => self.query.deleteForward() == .changed,
        };
        if (!changed) return;
        self.resetCursorBlink();
        self.dirty = true;
        try self.refreshResults();
    }

    fn moveTextCursor(self: *Surface, movement: textbox.Movement, extend: bool) !void {
        const changed = switch (movement) {
            .left => self.query.moveLeft(extend) == .changed,
            .right => self.query.moveRight(extend) == .changed,
            .home => self.query.moveHome(extend) == .changed,
            .end => self.query.moveEnd(extend) == .changed,
        };
        if (changed) {
            self.resetCursorBlink();
            self.dirty = true;
        }
    }

    fn cutSelectedText(self: *Surface) !void {
        const changed = self.query.cutSelection() == .changed;
        if (!changed) return;
        self.resetCursorBlink();
        self.dirty = true;
        try self.refreshResults();
    }

    fn pasteClipboardText(self: *Surface) !void {
        const clipboard = c.SDL_GetClipboardText();
        if (clipboard == null) return;
        defer c.SDL_free(clipboard);
        const text = std.mem.span(clipboard);
        if (text.len == 0) return;
        try self.applyTextInput(text);
    }

    fn copySelectedText(self: *Surface) !void {
        const selected = self.query.selectedText() orelse return;
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
        self.text_drag = .{ .anchor = offset };
        self.dirty = true;
        return true;
    }

    fn dragTextSelection(self: *Surface, drag: TextDrag, x: f32) !void {
        const surface_scale = self.config.scale();
        std.debug.assert(surface_scale > 0);
        const base_x = x / surface_scale;
        const range = self.viewport.visibleRange();
        const layout = self.currentResultLayout(range.count);
        const rect = queryContentRect(layout, self.appearance.picker);
        const offset = textbox.byteOffsetForMouseX(self.query.slice(), rect.x, rect.x + rect.w, base_x);
        if (self.query.selectToByteOffset(drag.anchor, offset) == .changed) {
            self.resetCursorBlink();
            self.dirty = true;
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

            try self.text.draw(self.renderer, layout.title_x, layout.titleY(i), result.title(), .{
                .color = if (selected)
                    picker.title_selected.color
                else
                    picker.title_normal.color,
                .max_bytes = 72,
                .font_size_px = if (selected) picker.title_selected.font_px else picker.title_normal.font_px,
                .surface_scale = surface_scale,
            });
            try self.text.draw(self.renderer, layout.title_x, layout.subtitleY(i), result.subtitle(), .{
                .color = if (selected)
                    picker.subtitle_selected.color
                else
                    picker.subtitle_normal.color,
                .max_bytes = 82,
                .font_size_px = if (selected) picker.subtitle_selected.font_px else picker.subtitle_normal.font_px,
                .surface_scale = surface_scale,
            });
            if (result.isApp()) try self.drawResultIcon(layout.iconRect(i), result.iconName());
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
    var buf: [query_max_bytes + 1:0]u8 = undefined;
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

/// routeQueryForSelection converts only a reachable SubCmd Candidate into the
/// next GUI query; Concrete leaves never enter another route.
fn routeQueryForSelection(value: candidate_owner.Candidate) ![]const u8 {
    return value.routeQuery() orelse error.RouteMissing;
}

/// drainLaunchQueue hands one resolved intent to process and clears the queue
/// on both success and failure before returning.
fn drainLaunchQueue(queue: *LaunchQueue, runner: LaunchRunner) process_owner.LaunchError!void {
    if (!queue.hasQueued()) return;
    defer queue.clear();
    try runner(queue.intent());
}

fn launchQueueRunnerOkForTest(intent: []const u8) process_owner.LaunchError!void {
    if (!std.mem.eql(u8, "run-me", intent)) return error.CommandFailed;
}

fn launchQueueRunnerFailForTest(intent: []const u8) process_owner.LaunchError!void {
    if (!std.mem.eql(u8, "run-me", intent)) return error.CommandFailed;
    return error.CommandFailed;
}

test "surface launch queue clears after successful drain" {
    var queue = LaunchQueue{};
    try queue.queue("run-me");
    try drainLaunchQueue(&queue, launchQueueRunnerOkForTest);
    try std.testing.expect(!queue.hasQueued());
}

test "surface launch queue clears after failed drain" {
    var queue = LaunchQueue{};
    try queue.queue("run-me");
    try std.testing.expectError(error.CommandFailed, drainLaunchQueue(&queue, launchQueueRunnerFailForTest));
    try std.testing.expect(!queue.hasQueued());
}

test "surface launch queue rejects empty and oversized intents" {
    var queue = LaunchQueue{};
    try std.testing.expectError(error.EmptyIntent, queue.queue(""));
    const oversized = [_]u8{'x'} ** (process_owner.max_intent_bytes + 1);
    try std.testing.expectError(error.IntentTooLong, queue.queue(&oversized));
    try std.testing.expect(!queue.hasQueued());
}

test "surface launch queue clears after process rejects an embedded NUL" {
    var queue = LaunchQueue{};
    try queue.queue("run\x00me");
    try std.testing.expectError(error.IntentContainsNul, drainLaunchQueue(&queue, process_owner.runDetached));
    try std.testing.expect(!queue.hasQueued());
}

test "GUI route selection consumes shared Candidate without changing Cmd order" {
    const picker = command_owner.Picker{};
    const before = picker.cmds;
    const route = candidate_owner.Candidate.subCmd(.{ .sunglasses = .{ .image = .{ .opacity = {} } } });

    try std.testing.expectEqualStrings("/sunglasses image", try routeQueryForSelection(route));
    try std.testing.expectEqual(before, picker.cmds);
    try std.testing.expectError(error.RouteMissing, routeQueryForSelection(candidate_owner.Candidate.appLeaf("Kitty", "Terminal", "kitty", "")));
}

test "text edit key combos stay owned by GUI text handling" {
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
