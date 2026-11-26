//! Native layer-shell picker; SDL supplies CPU drawing only.

const std = @import("std");
const apps = @import("../apps/catalog.zig");
const clock = @import("clock.zig");
const icon_path = @import("icon.zig");
const image = @import("image.zig");
const navigator = @import("navigator.zig");
const picker = @import("root.zig");
const pixels = @import("geometry.zig");
const text_draw = @import("../ui/text.zig");
const UiOwner = @import("../ui/owner.zig");
const tray = @import("../tray/host.zig");
const tray_menu = @import("../tray/menu.zig");
const sdl = @import("sdl_c");
const time = @import("time_c");
const shm = @import("../ui/native_surface.zig");
const Input = shm.Input;
const xkb = @import("xkb_c");

/// Native owns one layer and its CPU canvas for the picker lifetime.
pub const Native = struct {
    const font_size = 16;

    const Icon = struct {
        const Rejection = enum {
            invalid_path,
            malformed_png,
            encoded_too_large,
            dimensions_too_large,
        };

        const Texture = union(enum) {
            missing,
            rejected: Rejection,
            loaded: *sdl.SDL_Texture,
        };

        app_index: u16,
        texture: Texture,
    };

    ui_owner: *UiOwner,
    native_display: ?*shm.Display = null,
    native_surface: ?*shm.Surface = null,
    canvas: ?*sdl.SDL_Surface = null,
    canvas_scale: f32 = 1,
    first_attach: bool = false,
    owned_wake: bool = false,
    stop_fd: std.posix.fd_t = -1,
    applications: []const apps.App,
    allocator: std.mem.Allocator,
    io: std.Io,
    home: []const u8,
    renderer: ?*sdl.SDL_Renderer = null,
    text: ?text_draw.Painter = null,
    icons: [picker.visible_row_capacity]Icon = undefined,
    icon_count: usize = 0,
    pending_icons: bool = false,
    initialized: bool = false,
    text_started: bool = false,
    tray_enabled: bool = true,
    tray_wake_fd: std.posix.fd_t = -1,
    tray_fetched: bool = false,
    tray_threads_initialized: bool = false,
    tray_worker: ?std.Thread = null,
    tray_worker_ready: std.atomic.Value(bool) = .init(false),
    tray_stop: std.atomic.Value(bool) = .init(false),
    tray_next_refresh: u64 = 0,
    tray_worker_snapshot: tray.Snapshot = .{},
    tray_snapshot: tray.Snapshot = .{},
    tray_textures: [tray.capacity]?*sdl.SDL_Texture = @splat(null),
    menu: ?tray_menu.Menu = null,
    menu_item: usize = 0,
    menu_hover: ?usize = null,
    pressed_row: ?usize = null,

    /// Acquires the shared display and a tray completion eventfd.
    pub fn init(native: *Native) !void {
        std.debug.assert(!native.initialized);
        native.native_display = try native.ui_owner.acquireNative(native.allocator, native.io);
        errdefer {
            native.ui_owner.releaseNative();
            native.native_display = null;
        }
        if (native.tray_enabled and native.tray_wake_fd < 0) {
            const wake_fd = std.os.linux.eventfd(0, std.os.linux.EFD.CLOEXEC | std.os.linux.EFD.NONBLOCK);
            if (std.os.linux.errno(wake_fd) != .SUCCESS) return error.TrayWakeOpenFailed;
            native.tray_wake_fd = @intCast(wake_fd);
            native.owned_wake = true;
        }
        native.initialized = true;
    }

    /// Create and configure the native overlay before its first pixels.
    pub fn create(native: *Native) !void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.renderer == null);
        comptime std.debug.assert(picker.visible_row_capacity == pixels.visible_rows);
        const display = native.native_display.?;
        const start = std.Io.Clock.awake.now(native.io);
        while (display.status() == .discovering) try native.readUntil(start);
        if (display.status() != .ready) return error.NativeDisplayNotReady;
        native.native_surface = try shm.Surface.create(display, .picker, .{ .width = pixels.window_width, .height = pixels.window_height }, null);
        errdefer {
            native.native_surface.?.destroy() catch {};
            native.native_surface = null;
        }
        while (native.native_surface.?.extent == null and !native.native_surface.?.closed) try native.readUntil(start);
        if (native.native_surface.?.closed) return error.NativePickerClosed;
    }

    /// Enables UTF-8 text events before the picker can wait for input.
    pub fn startText(native: *Native) !void {
        std.debug.assert(!native.text_started);
        native.text_started = true;
    }

    /// Waits on native readiness and bounded visible deadlines.
    pub fn read(native: *Native) !picker.Events {
        std.debug.assert(native.text_started);
        return native.readShm();
    }

    fn keyAction(native: *Native, key: u32) picker.Event {
        native.pressed_row = null;
        return switch (key) {
            xkb.XKB_KEY_Escape => if (native.menu != null) blk: {
                native.menu = null;
                break :blk .redraw;
            } else .escape,
            xkb.XKB_KEY_BackSpace => if (native.menu != null) blk: {
                native.menu = null;
                break :blk .redraw;
            } else .backspace,
            xkb.XKB_KEY_Tab, xkb.XKB_KEY_ISO_Left_Tab => blk: {
                native.menu = null;
                break :blk .tab;
            },
            xkb.XKB_KEY_Up => if (native.menu != null) native.moveMenu(-1) else .up,
            xkb.XKB_KEY_Down => if (native.menu != null) native.moveMenu(1) else .down,
            xkb.XKB_KEY_Return, xkb.XKB_KEY_KP_Enter => if (native.menu != null) native.selectMenu() else .enter,
            else => .ignored,
        };
    }
    fn textAction(native: *Native, bytes: []const u8) !picker.Event {
        native.menu = null;
        native.pressed_row = null;
        return .{ .text = try picker.Text.init(bytes) };
    }
    fn motionAction(native: *Native, x: f32, y: f32) picker.Event {
        return if (native.menu != null) native.hoverMenu(x, y) else hoverAt(x, y) orelse .ignored;
    }
    fn buttonDown(native: *Native, button: u8, x: f32, y: f32) picker.Event {
        return blk: {
            native.pressed_row = null;
            if (native.menu != null) {
                if (native.menuAt(x, y)) |index| {
                    if (button == sdl.SDL_BUTTON_LEFT)
                        break :blk native.clickMenu(index);
                }
                native.menu = null;
                break :blk .redraw;
            }
            if (pixels.trayAt(x, y, native.tray_snapshot.count)) |index| {
                break :blk native.openTray(index, button, x, y);
            }
            if (button == sdl.SDL_BUTTON_LEFT) {
                native.pressed_row = pixels.rowAt(x, y);
                if (native.pressed_row) |row| break :blk .{ .hover = row };
            }
            break :blk .ignored;
        };
    }
    fn buttonUp(native: *Native, button: u8, x: f32, y: f32) picker.Event {
        return blk: {
            // Retire the originating Wayland button grab before asking a
            // different window to receive focus. Only a matching row
            // release selects; tray/menu actions retain their own path.
            if (button != sdl.SDL_BUTTON_LEFT) break :blk .ignored;
            const pressed = native.pressed_row;
            native.pressed_row = null;
            if (pressed == null or native.menu != null or pixels.rowAt(x, y) != pressed) break :blk .ignored;
            break :blk clickAt(x, y) orelse .ignored;
        };
    }
    fn scrollAction(native: *Native, rows: i8) picker.Event {
        native.pressed_row = null;
        return if (native.menu != null) .ignored else .{ .scroll = rows };
    }

    /// Replaces the frame with the current terminated query.
    pub fn draw(native: *Native, frame: *const picker.Frame) !void {
        const surface = native.native_surface.?;
        surface.invalidate();
        const result = try surface.draw(.{ .view = native, .frame = frame }, paintShm);
        if (result == .presented) {
            if (!native.first_attach) {
                native.first_attach = true;
                std.log.info("native picker first attach", .{});
            }
            try native.afterDraw(frame);
        }
    }

    fn drawContents(native: *Native, frame: *const picker.Frame) !void {
        const renderer = native.renderer orelse unreachable;
        native.evict(frame);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;

        const bar_rect = nativeRect(pixels.toolbar);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 29, 33, 43, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderFillRect(renderer, &bar_rect)) return error.SdlDrawFailed;
        try native.drawClock();
        try native.drawTray();

        const query_pane = nativeRect(pixels.query);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 30, 31, 39, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderFillRect(renderer, &query_pane)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlDrawFailed;
        var failure_text: [160]u8 = undefined;
        const query: []const u8 = if (frame.table == .windows and frame.window_error != null and
            frame.window_status == .unavailable)
            std.fmt.bufPrint(&failure_text, "{s}: {s}  ·  Tab: applications", .{
                @as([]const u8, "Windows unavailable"),
                frame.window_error.?,
            }) catch return error.SdlDrawFailed
        else if (frame.query.len == 0) switch (frame.table) {
            .root => "Choose a mode",
            .apps => "Search applications   ·   Tab: windows",
            .windows => switch (frame.window_status) {
                .dormant, .ready => "Search windows   ·   Tab: applications",
                .empty => "No windows   ·   Tab: applications",
                .unavailable => "Windows unavailable   ·   Tab: applications",
            },
            .notifications => "Notification history",
        } else frame.query;
        // The query has its own full-width row, so a long search never
        // overwrites the toolbar's clock or eventual tray icons.
        const query_clip = sdl.SDL_Rect{ .x = 17, .y = 47, .w = 684, .h = 34 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &query_clip)) return error.SdlDrawFailed;
        const query_draw = native.drawQuery(frame, query);
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlDrawFailed;
        try query_draw;
        for (frame.rowSlice(), 0..) |row, index| {
            try native.drawRow(row, index, index == frame.selected_row);
        }
        try drawScrollbar(renderer, frame);
        try native.drawMenu();
    }

    fn afterDraw(native: *Native, frame: *const picker.Frame) !void {
        if (try native.firstMissing(frame)) |app_index| {
            native.pending_icons = true;
            try native.load(app_index);
            native.native_surface.?.invalidate();
        } else {
            native.pending_icons = false;
        }
        // Give application icons priority over tray setup. Both follow the
        // first useful frame; a slow D-Bus item never delays picker results.
        if (native.tray_enabled and !native.tray_fetched and native.tray_worker == null) {
            native.tray_fetched = true;
            native.startTrayFetch();
        }
    }

    fn drawQuery(native: *Native, frame: *const picker.Frame, query: []const u8) !void {
        try native.drawText(if (frame.preedit.len != 0) frame.query else query, .{ 235, 235, 240 }, 20, 52);
        if (frame.preedit.len != 0) {
            const painter = &native.text.?;
            const x = 20 + try painter.width(frame.query);
            try native.drawText(frame.preedit, .{ 130, 190, 255 }, x, 52);
            const renderer = native.renderer.?;
            const width = try painter.width(frame.preedit);
            const underline = sdl.SDL_FRect{ .x = x, .y = 74, .w = width, .h = 1 };
            if (!sdl.SDL_SetRenderDrawColor(renderer, 130, 190, 255, 255) or !sdl.SDL_RenderFillRect(renderer, &underline)) return error.SdlDrawFailed;
            const cursor = frame.preedit_cursor;
            if (cursor[0] >= 0 and cursor[1] >= 0 and cursor[0] <= frame.preedit.len and cursor[1] <= frame.preedit.len) {
                const left = x + try painter.width(frame.preedit[0..@intCast(@min(cursor[0], cursor[1]))]);
                const right = x + try painter.width(frame.preedit[0..@intCast(@max(cursor[0], cursor[1]))]);
                const marker = sdl.SDL_FRect{ .x = left, .y = if (left == right) 52 else 75, .w = @max(1, right - left), .h = if (left == right) 20 else 2 };
                if (!sdl.SDL_RenderFillRect(renderer, &marker)) return error.SdlDrawFailed;
            }
        }
    }

    fn drawRow(native: *Native, row: picker.Row, index: usize, selected: bool) !void {
        const renderer = native.renderer orelse unreachable;
        const row_pixels = pixels.row(index);
        const row_rect = nativeRect(row_pixels);
        const color: [3]u8 = if (selected) .{ 130, 190, 255 } else .{ 210, 210, 215 };
        const background: [3]u8 = if (selected) .{ 48, 55, 72 } else .{ 24, 24, 30 };
        if (!sdl.SDL_SetRenderDrawColor(renderer, background[0], background[1], background[2], 255)) {
            return error.SdlDrawFailed;
        }
        if (!sdl.SDL_RenderFillRect(renderer, &row_rect)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], 255)) {
            return error.SdlDrawFailed;
        }
        switch (row) {
            .table => |table| try native.drawText(
                picker.tableName(table),
                color,
                20,
                pixels.textY(index),
            ),
            .app => |app_index| {
                const app = try native.application(app_index);
                try native.drawAppIcon(app_index, index);
                try native.drawText(app.name, color, 44, pixels.textY(index));
            },
            .window => |window_row| {
                if (window_row.app_index) |app_index| try native.drawAppIcon(app_index, index);
                const title = try native.windowTitle(window_row);
                try native.drawClippedText(title, color, .{
                    .x = 44,
                    .y = @intFromFloat(row_pixels.y),
                    .w = 510,
                    .h = @intFromFloat(row_pixels.h),
                });
                const secondary: [3]u8 = if (selected) .{ 185, 200, 220 } else .{ 145, 150, 160 };
                var meta_buffer: [128]u8 = undefined;
                const metadata = try formatWindowMetadata(window_row, &meta_buffer);
                try native.drawClippedText(metadata, secondary, .{
                    .x = 570,
                    .y = @intFromFloat(row_pixels.y),
                    .w = 126,
                    .h = @intFromFloat(row_pixels.h),
                });
            },
            .notification => |record| {
                const secondary: [3]u8 = if (selected) .{ 180, 190, 205 } else .{ 135, 140, 150 };
                const fields = [_][]const u8{ record.app_name, record.summary, record.body };
                const x = [_]c_int{ 14, 170, 430 };
                const width = [_]c_int{ 150, 250, 270 };
                for (fields, x, width, 0..) |text, left, field_width, field| {
                    try native.drawClippedText(
                        displayText(text),
                        if (field == 1) color else secondary,
                        .{
                            .x = left,
                            .y = @intFromFloat(row_pixels.y),
                            .w = field_width,
                            .h = @intFromFloat(row_pixels.h),
                        },
                    );
                }
            },
        }
    }

    /// Stops text input; failure remains visible while later cleanup continues.
    pub fn stopText(native: *Native) !void {
        std.debug.assert(native.text_started);
        native.text_started = false;
    }

    /// Retires the renderer and surface after text input has stopped.
    pub fn destroy(native: *Native) void {
        std.debug.assert(!native.text_started);
        if (native.tray_worker) |worker| {
            native.tray_stop.store(true, .release);
            worker.join();
            native.tray_worker = null;
            native.tray_worker_snapshot.deinit(std.heap.page_allocator);
        }
        native.clearTray();
        native.dropCanvas();
        if (native.native_surface) |surface| {
            native.native_surface = null;
            surface.destroy() catch |err| {
                native.native_display.?.failed = true;
                std.log.warn("native picker retirement failed: {s}", .{@errorName(err)});
            };
            std.log.info("native picker retired", .{});
        }
    }

    /// Fence exclusive-layer retirement on the original connection before
    /// dispatching a compositor-native focus command.
    pub fn destroyForFocus(native: *Native) !void {
        native.destroy();
        const display = native.native_display.?;
        try display.requestSync();
        const start = std.Io.Clock.awake.now(native.io);
        while (display.sync_pending) try native.readUntil(start);
        std.log.info("native picker dismissal sync", .{});
    }

    /// Releases the display after destroying the role and its CPU canvas.
    pub fn quit(native: *Native) void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.renderer == null);
        std.debug.assert(!native.text_started);
        // The tray worker is joined before its wake descriptor is retired.
        std.debug.assert(native.native_surface == null);
        native.ui_owner.releaseNative();
        native.native_display = null;
        if (native.owned_wake) {
            _ = std.os.linux.close(native.tray_wake_fd);
            native.tray_wake_fd = -1;
        }
        native.initialized = false;
    }

    fn ticks(native: *Native) u64 {
        return @intCast(std.Io.Clock.awake.now(native.io).toMilliseconds());
    }

    fn readUntil(native: *Native, start: std.Io.Timestamp) !void {
        try UiOwner.readBefore(native.native_display.?, native.io, start);
    }

    pub fn fd(native: *const Native) std.posix.fd_t {
        return if (native.native_display) |display| display.fd() else -1;
    }

    pub fn closed(native: *const Native) bool {
        return native.native_surface.?.closed or native.native_display.?.failed;
    }

    pub fn repeatWake(native: *const Native) ?u64 {
        const deadline = native.native_display.?.input.repeatDeadline() orelse return null;
        const delta = @max(0, std.Io.Clock.awake.now(native.io).durationTo(deadline).toNanoseconds());
        return @intCast(@divTrunc(delta + std.time.ns_per_ms - 1, std.time.ns_per_ms));
    }

    pub fn hasPendingDraw(native: *const Native) bool {
        return native.native_surface.?.dirty and native.canDraw();
    }

    fn canDraw(native: *const Native) bool {
        const surface = native.native_surface orelse return false;
        if (surface.closed or surface.extent == null or !surface.presenter.?.ready()) return false;
        var busy: usize = 0;
        for (surface.pool.?.buffers.items) |buffer| if (buffer.state == .busy) {
            busy += 1;
        };
        return busy < shm.max_buffers;
    }

    pub fn nativeEvents(native: *Native, batch: *picker.Events) !void {
        const display = native.native_display.?;
        if (native.closed()) {
            if (batch.count < batch.items.len) {
                batch.items[batch.count] = .quit;
                batch.count += 1;
            }
            return;
        }
        if (display.input.count == 0) _ = try display.input.advanceRepeat(std.Io.Clock.awake.now(native.io));
        while (batch.count < batch.items.len) {
            const event = display.input.popFor(native.native_surface.?.surface.?.id) orelse break;
            batch.items[batch.count] = try native.translateShm(event);
            batch.count += 1;
        }
        batch.more = batch.more or display.input.hasFor(native.native_surface.?.surface.?.id);
        if (batch.count < batch.items.len and native.native_surface.?.dirty and native.canDraw()) {
            batch.items[batch.count] = .redraw;
            batch.count += 1;
        }
    }

    fn readShm(native: *Native) !picker.Events {
        while (true) {
            var batch: picker.Events = .{};
            try native.ui_owner.pumpNative();
            try native.nativeEvents(&batch);
            if (try native.drainTrayWake()) {
                if (batch.count < batch.items.len) {
                    batch.items[batch.count] = .redraw;
                    batch.count += 1;
                } else native.native_surface.?.invalidate();
            }
            if (batch.count != 0 or batch.more) return batch;
            const timeout: u64 = @intCast(native.waitTimeout());
            const wait = if (native.repeatWake()) |repeat| @min(timeout, repeat) else timeout;
            var fds = [_]std.posix.pollfd{ .{ .fd = native.fd(), .events = std.posix.POLL.IN, .revents = 0 }, .{ .fd = native.tray_wake_fd, .events = std.posix.POLL.IN, .revents = 0 }, .{ .fd = native.stop_fd, .events = std.posix.POLL.IN, .revents = 0 } };
            const ready = try std.posix.poll(&fds, @intCast(wait));
            if (fds[2].revents != 0) {
                try @import("../stop.zig").consume(native.io, native.stop_fd);
                batch.items[0] = .quit;
                batch.count = 1;
                return batch;
            }
            if (ready == 0 and wait == timeout) {
                batch.items[0] = native.onDeadline();
                batch.count = 1;
                return batch;
            }
        }
    }

    fn drainTrayWake(native: *Native) !bool {
        if (native.tray_wake_fd < 0) return false;
        var value: u64 = undefined;
        const bytes = std.mem.asBytes(&value);
        const result = std.os.linux.read(native.tray_wake_fd, bytes.ptr, bytes.len);
        switch (std.os.linux.errno(result)) {
            .SUCCESS => if (result != bytes.len) return error.TrayWakeReadFailed,
            .AGAIN, .INTR => {},
            else => return error.TrayWakeReadFailed,
        }
        return native.trayReady();
    }

    fn coordinates(native: *const Native, point: Input.Point) struct { x: f32, y: f32 } {
        const extent = native.native_surface.?.extent.?;
        const w: f64 = @floatFromInt(extent.width);
        const h: f64 = @floatFromInt(extent.height);
        const scale = @min(w / pixels.window_width, h / pixels.window_height);
        return .{ .x = @floatCast((point.x - (w - pixels.window_width * scale) / 2) / scale), .y = @floatCast((point.y - (h - pixels.window_height * scale) / 2) / scale) };
    }

    fn translateShm(native: *Native, event: Input.Event) !picker.Event {
        return switch (event.value) {
            .keyboard_enter => .redraw,
            .keyboard_leave, .ime_cancel => blk: {
                native.pressed_row = null;
                break :blk .cancel_preedit;
            },
            .key => |key| blk: {
                if (!key.pressed) break :blk .ignored;
                native.pressed_row = null;
                if (key.text_len != 0) break :blk try native.textAction(key.utf8());
                if (key.compose_consumed) break :blk .ignored;
                break :blk native.keyAction(key.symbol);
            },
            .ime => |edit| blk: {
                native.menu = null;
                native.pressed_row = null;
                break :blk .{ .edit = .{ .commit = try picker.Text.init(edit.commit.slice()), .preedit = try picker.Text.init(edit.preedit.slice()), .delete_before = edit.delete_before, .delete_after = edit.delete_after, .cursor_begin = edit.cursor_begin, .cursor_end = edit.cursor_end } };
            },
            .pointer_enter, .motion => |point| blk: {
                const at = native.coordinates(point);
                break :blk native.motionAction(at.x, at.y);
            },
            .pointer_leave => blk: {
                native.pressed_row = null;
                break :blk .ignored;
            },
            .button => |button| blk: {
                const at = native.coordinates(button.at);
                const code: u8 = switch (button.code) {
                    272 => sdl.SDL_BUTTON_LEFT,
                    273 => sdl.SDL_BUTTON_RIGHT,
                    274 => sdl.SDL_BUTTON_MIDDLE,
                    else => break :blk .ignored,
                };
                break :blk if (button.pressed) native.buttonDown(code, at.x, at.y) else native.buttonUp(code, at.x, at.y);
            },
            .scroll => |rows| native.scrollAction(rows),
        };
    }

    fn dropCanvas(native: *Native) void {
        native.destroyTrayTextures();
        native.clearIcons();
        native.clearText();
        if (native.renderer) |renderer| sdl.SDL_DestroyRenderer(renderer);
        if (native.canvas) |canvas| sdl.SDL_DestroySurface(canvas);
        native.renderer = null;
        native.canvas = null;
    }

    fn paintShm(context: anytype, frame: shm.Frame) !void {
        const native = context.view;
        const scale: f32 = @min(@as(f32, @floatFromInt(frame.extent.width)) / pixels.window_width, @as(f32, @floatFromInt(frame.extent.height)) / pixels.window_height);
        if (native.canvas == null or native.canvas.?.*.w != frame.extent.width or native.canvas.?.*.h != frame.extent.height) {
            native.dropCanvas();
            native.canvas = sdl.SDL_CreateSurface(@intCast(frame.extent.width), @intCast(frame.extent.height), sdl.SDL_PIXELFORMAT_XRGB8888) orelse return error.NativeCanvasCreate;
            errdefer native.dropCanvas();
            native.renderer = sdl.SDL_CreateSoftwareRenderer(native.canvas.?) orelse return error.NativeCanvasRenderer;
            if (!sdl.SDL_SetRenderLogicalPresentation(native.renderer.?, pixels.window_width, pixels.window_height, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX)) return error.SdlLogicalPresentationFailed;
            native.text = try text_draw.Painter.initScaled(native.allocator, native.renderer.?, font_size, scale);
            native.canvas_scale = scale;
            native.createTrayTextures();
        }
        if (sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO) != 0) return error.NativePickerUnexpectedVideo;
        try native.drawContents(context.frame);
        const display = native.native_display.?;
        if (display.input.ime_manager != null) {
            const width: f64 = @floatFromInt(frame.logical_extent.width);
            const height: f64 = @floatFromInt(frame.logical_extent.height);
            const logical_scale = @min(width / pixels.window_width, height / pixels.window_height);
            const caret: f64 = @floatCast(@min(700, 20 + try native.text.?.width(context.frame.query)));
            try display.input.setImeContext(&display.conn, context.frame.query, .{
                @intFromFloat((width - pixels.window_width * logical_scale) / 2 + caret * logical_scale),
                @intFromFloat((height - pixels.window_height * logical_scale) / 2 + 52 * logical_scale),
                @intFromFloat(@max(1, logical_scale)),
                @intFromFloat(@max(1, 20 * logical_scale)),
            }, context.frame.query_from_ime);
        }
        if (!sdl.SDL_FlushRenderer(native.renderer.?)) return error.NativeCanvasFlush;
        const canvas = native.canvas.?;
        const source: [*]const u8 = @ptrCast(canvas.*.pixels orelse return error.NativeCanvasPixels);
        const pitch: usize = @intCast(canvas.*.pitch);
        const row_bytes = @as(usize, frame.extent.width) * 4;
        for (0..frame.extent.height) |y| @memcpy(frame.pixels[y * frame.stride ..][0..row_bytes], source[y * pitch ..][0..row_bytes]);
    }

    fn drawAppIcon(native: *Native, app_index: u16, row_index: usize) !void {
        if (native.icon(app_index)) |item| switch (item.texture) {
            .missing, .rejected => {},
            .loaded => |texture| {
                const renderer = native.renderer orelse unreachable;
                const target = nativeRect(pixels.icon(row_index));
                if (!sdl.SDL_RenderTexture(renderer, texture, null, &target)) {
                    return error.SdlDrawFailed;
                }
            },
        };
    }

    fn windowTitle(native: *const Native, row: picker.WindowRow) ![]const u8 {
        const title = row.window.title.slice();
        const app_id = row.window.app_id.slice();
        if (title.len > 0 and !std.ascii.eqlIgnoreCase(title, app_id)) return title;
        if (row.app_index) |app_index| return (try native.application(app_index)).name;
        if (app_id.len > 0) return app_id;
        return row.window.stable_id.slice();
    }

    fn application(native: *const Native, app_index: u16) !*const apps.App {
        if (app_index >= native.applications.len) return error.ApplicationIndexInvalid;
        return &native.applications[app_index];
    }

    fn icon(native: *const Native, app_index: u16) ?Icon {
        for (native.icons[0..native.icon_count]) |item| {
            if (item.app_index == app_index) return item;
        }
        return null;
    }

    fn clearIcons(native: *Native) void {
        while (native.icon_count > 0) {
            native.icon_count -= 1;
            destroyIcon(native.icons[native.icon_count]);
        }
        native.pending_icons = false;
    }

    fn clearText(native: *Native) void {
        if (native.text) |*painter| painter.deinit();
        native.text = null;
    }

    pub fn trayReady(native: *Native) !bool {
        if (!native.tray_worker_ready.load(.acquire) or native.tray_worker == null) return false;
        try native.receiveTray();
        return true;
    }

    fn receiveTray(native: *Native) !void {
        if (!native.tray_worker_ready.load(.acquire)) return;
        if (native.tray_worker) |worker| {
            worker.join();
            native.tray_worker = null;
        }
        native.clearTray();
        native.tray_snapshot = native.tray_worker_snapshot;
        native.tray_worker_snapshot = .{};
        if (native.renderer != null) native.createTrayTextures();
    }

    fn createTrayTextures(native: *Native) void {
        for (native.tray_snapshot.entries[0..native.tray_snapshot.count], 0..) |*entry, index| {
            native.tray_textures[index] = native.makeTrayTexture(entry) catch null;
        }
    }

    fn startTrayFetch(native: *Native) void {
        std.debug.assert(native.tray_worker == null);
        // Do not load/initialize libdbus in the fresh picker's critical path.
        // The very first application frame has been presented before this
        // worker setup. Subsequent refreshes reuse the initialized library.
        if (!native.tray_threads_initialized) {
            if (@import("dbus_c").dbus_threads_init_default() == 0) {
                std.log.warn("libdbus thread initialization failed; tray unavailable", .{});
                native.tray_next_refresh = native.ticks() + 30_000;
                return;
            }
            native.tray_threads_initialized = true;
        }
        native.tray_stop.store(false, .release);
        native.tray_worker_ready.store(false, .release);
        native.tray_next_refresh = native.ticks() + 7000;
        native.tray_worker = std.Thread.spawn(.{}, trayFetch, .{native}) catch |err| {
            std.log.warn("tray fetch thread unavailable: {s}", .{@errorName(err)});
            return;
        };
    }

    /// A visible picker supplies a relative wake bound to its caller.
    /// There is no picker deadline while its window is absent.
    pub fn waitTimeout(native: *Native) c_int {
        if (native.hasPendingDraw() or (native.pending_icons and native.canDraw())) return 1;
        const next_clock = clockTimeout();
        if (!native.tray_fetched or native.tray_worker != null) return next_clock;
        const remaining = native.tray_next_refresh -| native.ticks();
        return @intCast(@min(@as(u64, @intCast(next_clock)), @max(1, remaining)));
    }

    pub fn onDeadline(native: *Native) picker.Event {
        if (native.pending_icons and native.canDraw()) return .idle;
        const tray_due = native.tray_fetched and native.tray_worker == null and
            native.ticks() >= native.tray_next_refresh;
        if (tray_due) native.startTrayFetch();
        return if (tray_due) .ignored else .redraw;
    }

    fn destroyTrayTextures(native: *Native) void {
        for (&native.tray_textures) |*value| {
            if (value.*) |texture| sdl.SDL_DestroyTexture(texture);
            value.* = null;
        }
    }

    fn clearTray(native: *Native) void {
        native.menu = null;
        native.destroyTrayTextures();
        native.tray_snapshot.deinit(std.heap.page_allocator);
    }

    fn makeTrayTexture(native: *Native, entry: *const tray.Entry) !?*sdl.SDL_Texture {
        if (entry.pixels) |raw| {
            const surface = sdl.SDL_CreateSurfaceFrom(entry.width, entry.height, sdl.SDL_PIXELFORMAT_ARGB8888, raw.ptr, @as(c_int, entry.width) * 4) orelse
                return error.TraySurfaceFailed;
            defer sdl.SDL_DestroySurface(surface);
            const texture = sdl.SDL_CreateTextureFromSurface(native.renderer, surface) orelse
                return error.TrayTextureFailed;
            if (!sdl.SDL_SetTextureBlendMode(texture, sdl.SDL_BLENDMODE_BLEND)) {
                sdl.SDL_DestroyTexture(texture);
                return error.TrayBlendFailed;
            }
            return texture;
        }
        // A named icon is already an external XDG fact: resolve it fresh like
        // application icons, without a persistent icon-theme index.
        if (entry.iconText().len == 0) return null;
        var candidates: icon_path.Paths = .{ .home = native.home, .icon = entry.iconText() };
        while (candidates.next() catch return null) |filename| {
            const bytes = std.Io.Dir.cwd().readFileAlloc(native.io, filename, native.allocator, .limited(128 * 1024)) catch continue;
            defer native.allocator.free(bytes);
            if (image.inspect(bytes) != null) continue;
            const stream = sdl.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse continue;
            const surface = sdl.SDL_LoadPNG_IO(stream, true) orelse continue;
            defer sdl.SDL_DestroySurface(surface);
            return sdl.SDL_CreateTextureFromSurface(native.renderer, surface);
        }
        return null;
    }

    fn drawTray(native: *Native) !void {
        const renderer = native.renderer orelse unreachable;
        for (native.tray_snapshot.entries[0..native.tray_snapshot.count], 0..) |*entry, index| {
            const cell = pixels.traySlot(index);
            if (native.tray_textures[index]) |texture| {
                const target = sdl.SDL_FRect{
                    .x = cell.x + 2,
                    .y = cell.y + 2,
                    .w = cell.w - 4,
                    .h = cell.h - 4,
                };
                if (!sdl.SDL_RenderTexture(renderer, texture, null, &target)) return error.TrayDrawFailed;
            } else {
                // Missing icons remain clickable, identified by their actual
                // application title, not a fabricated placeholder service.
                if (!sdl.SDL_SetRenderDrawColor(renderer, 48, 55, 70, 255)) return error.TrayDrawFailed;
                const target = nativeRect(cell);
                if (!sdl.SDL_RenderFillRect(renderer, &target)) return error.TrayDrawFailed;
                const title = entry.titleText();
                if (title.len > 0 and title[0] >= 'A' and title[0] <= 'z')
                    try native.drawText(title[0..1], .{ 220, 230, 245 }, cell.x + 7, cell.y + 3);
            }
        }
    }

    fn trayClick(native: *Native, index: usize, button: u8, x: f32, y: f32) void {
        native.tray_snapshot.activate(index, @intFromFloat(x), @intFromFloat(y), button) catch |err| {
            std.log.warn("tray activation failed: {s}", .{@errorName(err)});
        };
    }

    const menu_left: f32 = 398;
    const menu_top: f32 = 42;
    const menu_width: f32 = 306;
    const menu_height: f32 = 27;

    /// Prefer a real DBusMenu on right click or menu-only items; otherwise
    /// call the SNI item's own ContextMenu/Activate method.
    fn openTray(native: *Native, index: usize, button: u8, x: f32, y: f32) picker.Event {
        const item = &native.tray_snapshot.entries[index];
        if ((button == sdl.SDL_BUTTON_RIGHT or item.item_is_menu) and item.menu_len > 0) {
            if (tray_menu.fetch(item.serviceName(), item.menuPath(), 0) catch null) |menu| {
                native.menu = menu;
                native.menu_item = index;
                native.menu_hover = null;
                return .redraw;
            }
        }
        native.trayClick(index, button, x, y);
        return .ignored;
    }

    fn menuAt(native: *const Native, x: f32, y: f32) ?usize {
        const menu = native.menu orelse return null;
        if (x < menu_left or x >= menu_left + menu_width or y < menu_top) return null;
        const index: usize = @intFromFloat((y - menu_top) / menu_height);
        return if (index < menu.count) index else null;
    }

    fn hoverMenu(native: *Native, x: f32, y: f32) picker.Event {
        const next = native.menuAt(x, y);
        if (next == native.menu_hover) return .ignored;
        native.menu_hover = next;
        return .redraw;
    }

    fn moveMenu(native: *Native, direction: i8) picker.Event {
        const count = if (native.menu) |menu| menu.count else return .ignored;
        if (count == 0) return .ignored;
        native.menu_hover = if (native.menu_hover) |current|
            if (direction < 0) current -| 1 else @min(count - 1, current +| 1)
        else if (direction < 0)
            count - 1
        else
            0;
        return .redraw;
    }

    fn selectMenu(native: *Native) picker.Event {
        return native.clickMenu(native.menu_hover orelse 0);
    }

    fn clickMenu(native: *Native, index: usize) picker.Event {
        const menu = native.menu orelse return .ignored;
        if (index >= menu.count or !menu.rows[index].enabled) return .ignored;
        const row = &menu.rows[index];
        const item = &native.tray_snapshot.entries[native.menu_item];
        if (row.submenu) {
            if (tray_menu.fetch(item.serviceName(), item.menuPath(), row.id) catch null) |submenu| {
                native.menu = submenu;
                native.menu_hover = null;
                return .redraw;
            }
        }
        tray_menu.click(item.serviceName(), item.menuPath(), row.id) catch |err| {
            std.log.warn("tray menu action failed: {s}", .{@errorName(err)});
        };
        native.menu = null;
        native.menu_hover = null;
        return .redraw;
    }

    fn drawMenu(native: *Native) !void {
        const menu = if (native.menu) |*value| value else return;
        const renderer = native.renderer orelse unreachable;
        for (menu.rows[0..menu.count], 0..) |*row, index| {
            const top = menu_top + menu_height * @as(f32, @floatFromInt(index));
            const bounds: sdl.SDL_FRect = .{ .x = menu_left, .y = top, .w = menu_width, .h = menu_height };
            const active = native.menu_hover != null and native.menu_hover.? == index;
            const shade: [3]u8 = if (active and row.enabled) .{ 56, 66, 83 } else .{ 30, 34, 44 };
            if (!sdl.SDL_SetRenderDrawColor(renderer, shade[0], shade[1], shade[2], 255))
                return error.TrayMenuDrawFailed;
            if (!sdl.SDL_RenderFillRect(renderer, &bounds)) return error.TrayMenuDrawFailed;
            const clip = sdl.SDL_Rect{ .x = @intFromFloat(menu_left + 8), .y = @intFromFloat(top), .w = @intFromFloat(menu_width - 28), .h = @intFromFloat(menu_height) };
            if (!sdl.SDL_SetRenderClipRect(renderer, &clip)) return error.TrayMenuDrawFailed;
            const result = native.drawText(row.text(), if (row.enabled) .{ 226, 231, 241 } else .{ 122, 129, 145 }, menu_left + 10, top + 4);
            if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.TrayMenuDrawFailed;
            try result;
            if (row.submenu) try native.drawText(">", .{ 185, 195, 215 }, menu_left + menu_width - 20, top + 4);
        }
    }

    fn drawText(native: *Native, value: []const u8, color: [3]u8, x: f32, y: f32) !void {
        const painter = if (native.text) |*owned| owned else return error.TextNotInitialized;
        try painter.draw(value, color, x, y);
    }

    /// A local clock belongs to the existing header, not another Wayland
    /// surface. Time failures do not interrupt application discovery.
    fn drawClock(native: *Native) !void {
        var bytes: [32]u8 = undefined;
        const label = localClock(&bytes) catch "--:--";
        const renderer = native.renderer orelse unreachable;
        const area = pixels.clock_clip;
        const clip = sdl.SDL_Rect{
            .x = @intFromFloat(area.x),
            .y = @intFromFloat(area.y),
            .w = @intFromFloat(area.w),
            .h = @intFromFloat(area.h),
        };
        if (!sdl.SDL_SetRenderClipRect(renderer, &clip)) return error.SdlDrawFailed;
        const result = native.drawText(label, .{ 164, 178, 198 }, 526, 12);
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlDrawFailed;
        try result;
    }

    fn drawClippedText(native: *Native, value: []const u8, color: [3]u8, clip: sdl.SDL_Rect) !void {
        const renderer = native.renderer orelse unreachable;
        if (!sdl.SDL_SetRenderClipRect(renderer, &clip)) return error.SdlDrawFailed;
        const result = native.drawText(value, color, @floatFromInt(clip.x), @floatFromInt(clip.y + 5));
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlDrawFailed;
        try result;
    }

    fn firstMissing(native: *const Native, frame: *const picker.Frame) !?u16 {
        for (frame.rowSlice()) |row| {
            const app_index = rowApp(row) orelse continue;
            const name = (try native.application(app_index)).icon orelse continue;
            if (name.len > 0 and native.icon(app_index) == null) return app_index;
        }
        return null;
    }

    fn evict(native: *Native, frame: *const picker.Frame) void {
        var index: usize = 0;
        while (index < native.icon_count) {
            var visible = false;
            for (frame.rowSlice()) |row| {
                const app_index = rowApp(row) orelse continue;
                if (app_index == native.icons[index].app_index) visible = true;
            }
            if (visible) {
                index += 1;
            } else {
                destroyIcon(native.icons[index]);
                native.icon_count -= 1;
                native.icons[index] = native.icons[native.icon_count];
            }
        }
    }

    fn load(native: *Native, app_index: u16) !void {
        std.debug.assert(native.icon_count < native.icons.len);
        const name = (try native.application(app_index)).icon orelse return;
        var paths: icon_path.Paths = .{ .home = native.home, .icon = name };
        var rejected: ?Icon.Rejection = null;
        while (paths.next() catch {
            native.remember(app_index, .{ .rejected = .invalid_path });
            return;
        }) |path| {
            const bytes = std.Io.Dir.cwd().readFileAlloc(
                native.io,
                path,
                native.allocator,
                .limited(image.encoded_capacity + 1),
            ) catch |failure| switch (failure) {
                error.FileNotFound, error.NotDir => continue,
                error.StreamTooLong => {
                    rejected = .encoded_too_large;
                    continue;
                },
                else => return failure,
            };
            defer native.allocator.free(bytes);
            if (image.inspect(bytes)) |rejection| {
                rejected = switch (rejection) {
                    .malformed => .malformed_png,
                    .dimensions_too_large => .dimensions_too_large,
                };
                continue;
            }
            const stream = sdl.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse return error.SdlIconStreamFailed;
            const surface = sdl.SDL_LoadPNG_IO(stream, true) orelse return error.SdlIconDecodeFailed;
            defer sdl.SDL_DestroySurface(surface);
            if (surface.*.w > image.side_capacity or surface.*.h > image.side_capacity) {
                return error.SdlIconDimensionsChanged;
            }
            const scaled = sdl.SDL_ScaleSurface(
                surface,
                @intFromFloat(@round(pixels.icon_size * native.canvas_scale)),
                @intFromFloat(@round(pixels.icon_size * native.canvas_scale)),
                sdl.SDL_SCALEMODE_LINEAR,
            ) orelse {
                return error.SdlIconScaleFailed;
            };
            defer sdl.SDL_DestroySurface(scaled);
            const created = sdl.SDL_CreateTextureFromSurface(native.renderer, scaled) orelse {
                return error.SdlIconTextureFailed;
            };
            native.remember(app_index, .{ .loaded = created });
            return;
        }
        native.remember(app_index, if (rejected) |reason| .{ .rejected = reason } else .missing);
    }

    fn remember(native: *Native, app_index: u16, texture: Icon.Texture) void {
        std.debug.assert(native.icon_count < native.icons.len);
        native.icons[native.icon_count] = .{ .app_index = app_index, .texture = texture };
        native.icon_count += 1;
    }
};

// The eventfd is the sole cross-thread UI completion boundary. The worker
// never touches renderer or Wayland state.
fn trayFetch(native: *Native) void {
    native.tray_worker_snapshot = tray.Snapshot.read(std.heap.page_allocator, &native.tray_stop) catch .{};
    native.tray_worker_ready.store(true, .release);
    if (native.tray_wake_fd >= 0) {
        const value: u64 = 1;
        const bytes = std.mem.asBytes(&value);
        const result = std.os.linux.write(native.tray_wake_fd, bytes.ptr, bytes.len);
        if (std.os.linux.errno(result) != .SUCCESS) std.log.warn("tray completion wake failed", .{});
        return;
    }
    unreachable; // Every tray worker owns a completion eventfd.
}

fn clockTimeout() c_int {
    const epoch = time.time(null);
    if (epoch < 0) return 60_000;
    return clock.nextMinuteMilliseconds(@intCast(epoch));
}

fn localClock(bytes: *[32]u8) ![]const u8 {
    const epoch = time.time(null);
    if (epoch < 0) return error.ClockTimeUnavailable;
    var local: time.struct_tm = undefined;
    if (time.localtime_r(&epoch, &local) == null) return error.ClockLocalTimeUnavailable;
    return clock.format(.{
        .weekday = std.math.cast(u8, local.tm_wday) orelse return error.ClockDateInvalid,
        .month = std.math.cast(u8, local.tm_mon) orelse return error.ClockDateInvalid,
        .day = std.math.cast(u8, local.tm_mday) orelse return error.ClockDateInvalid,
        .hour = std.math.cast(u8, local.tm_hour) orelse return error.ClockDateInvalid,
        .minute = std.math.cast(u8, local.tm_min) orelse return error.ClockDateInvalid,
    }, bytes);
}

test "picker clock reads local time without any Wayland or SDL window" {
    var bytes: [32]u8 = undefined;
    const label = try localClock(&bytes);
    try std.testing.expect(label.len > 8 and label.len <= bytes.len);
    try std.testing.expect(std.mem.indexOfScalar(u8, label, ':') != null);
    try std.testing.expectEqual(@as(i32, 1_000), clock.nextMinuteMilliseconds(119));
}

fn destroyIcon(icon: Native.Icon) void {
    switch (icon.texture) {
        .missing, .rejected => {},
        .loaded => |texture| sdl.SDL_DestroyTexture(texture),
    }
}

fn hoverAt(x: f32, y: f32) ?picker.Event {
    return .{ .hover = pixels.rowAt(x, y) orelse return null };
}

fn clickAt(x: f32, y: f32) ?picker.Event {
    return .{ .click = pixels.rowAt(x, y) orelse return null };
}

fn drawScrollbar(renderer: *sdl.SDL_Renderer, frame: *const picker.Frame) !void {
    const thumb = pixels.scrollbar(frame.first, frame.row_count, frame.total_count) orelse return;
    const track = nativeRect(pixels.scrollbar_track);
    const native_thumb = nativeRect(thumb);
    if (!sdl.SDL_SetRenderDrawColor(renderer, 38, 44, 52, 255)) return error.SdlDrawFailed;
    if (!sdl.SDL_RenderFillRect(renderer, &track)) return error.SdlDrawFailed;
    if (!sdl.SDL_SetRenderDrawColor(renderer, 104, 118, 136, 255)) return error.SdlDrawFailed;
    if (!sdl.SDL_RenderFillRect(renderer, &native_thumb)) return error.SdlDrawFailed;
}

fn nativeRect(rect: pixels.Rect) sdl.SDL_FRect {
    return .{ .x = rect.x, .y = rect.y, .w = rect.w, .h = rect.h };
}

fn formatWindowMetadata(row: picker.WindowRow, output: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(output);
    if (row.window.workspace_id) |workspace_id| {
        try writer.print("WS {s}", .{workspace_id.slice()});
    } else {
        try writer.writeAll("WS ?");
    }
    if (row.workspace_position) |position| {
        if (position.total > 1) {
            try writer.print(" · {d}/{d}", .{ position.ordinal, position.total });
        }
    }
    const direction = viewportDirection(row.window);
    if (direction.len > 0) try writer.print(" {s}", .{direction});
    return writer.buffered();
}

fn viewportDirection(window: *const navigator.Window) []const u8 {
    return switch (window.viewport) {
        .visible, .unknown => "",
        .partial => if (window.edges.left)
            "<|"
        else if (window.edges.right)
            "|>"
        else if (window.edges.top)
            "^|"
        else if (window.edges.bottom)
            "|v"
        else
            "",
        .offscreen => if (window.edges.left)
            "<"
        else if (window.edges.right)
            ">"
        else if (window.edges.top)
            "^"
        else if (window.edges.bottom)
            "v"
        else
            "",
    };
}

fn rowApp(row: picker.Row) ?u16 {
    return switch (row) {
        .app => |index| index,
        .window => |window| window.app_index,
        .table, .notification => null,
    };
}

fn displayText(text: []const u8) []const u8 {
    const line_end = std.mem.indexOfAny(u8, text, "\r\n") orelse text.len;
    var end = @min(line_end, 256);
    while (end < text.len and end > 0 and text[end] & 0b1100_0000 == 0b1000_0000) end -= 1;
    return text[0..end];
}

test "window metadata combines workspace spatial identity and viewport direction" {
    var window = navigator.Window{
        .stable_id = try navigator.StableId.exact("kitty-a"),
        .app_id = try navigator.AppId.display("kitty"),
        .title = try navigator.Title.display("~"),
        .workspace_id = try navigator.WorkspaceId.exact("2"),
        .monitor_id = null,
        .geometry = .{ .x = -100, .y = 0, .width = 100, .height = 100 },
        .viewport = .offscreen,
        .edges = .{ .left = true },
        .presentation = .occluded,
        .focus_rank = 1,
        .active = false,
        .floating = false,
        .fullscreen = false,
    };
    var output: [64]u8 = undefined;
    try std.testing.expectEqualStrings(
        "WS 2 · 2/5 <",
        try formatWindowMetadata(.{
            .window = &window,
            .app_index = null,
            .workspace_position = .{ .ordinal = 2, .total = 5 },
        }, &output),
    );
    window.viewport = .partial;
    window.edges = .{ .right = true };
    try std.testing.expectEqualStrings(
        "WS 2 · 2/5 |>",
        try formatWindowMetadata(.{
            .window = &window,
            .app_index = null,
            .workspace_position = .{ .ordinal = 2, .total = 5 },
        }, &output),
    );
}

test "single window metadata stays quiet" {
    var window = navigator.Window{
        .stable_id = try navigator.StableId.exact("only"),
        .app_id = try navigator.AppId.display("kitty"),
        .title = try navigator.Title.display("~"),
        .workspace_id = try navigator.WorkspaceId.exact("9"),
        .monitor_id = null,
        .geometry = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .viewport = .visible,
        .edges = .{},
        .presentation = .presented,
        .focus_rank = 0,
        .active = true,
        .floating = false,
        .fullscreen = false,
    };
    var output: [64]u8 = undefined;
    try std.testing.expectEqualStrings(
        "WS 9",
        try formatWindowMetadata(.{
            .window = &window,
            .app_index = null,
            .workspace_position = .{ .ordinal = 1, .total = 1 },
        }, &output),
    );
}

test "native key events expose the window finder mode toggle" {
    var native: Native = undefined;
    native.menu = null;
    const event: Input.Event = .{ .surface = .display, .value = .{ .key = .{ .code = 15, .symbol = xkb.XKB_KEY_Tab, .pressed = true, .repeatable = false, .modifiers = .{} } } };
    try std.testing.expectEqual(picker.Event.tab, try native.translateShm(event));
}

test "native app and icon lookup preserve the exact checked row index" {
    const applications = [_]apps.App{
        testApp("Zero"),
        testApp("One"),
    };
    var native: Native = undefined;
    native.applications = &applications;
    native.icon_count = 0;
    try std.testing.expect((try native.application(1)) == &applications[1]);
    try std.testing.expectError(error.ApplicationIndexInvalid, native.application(2));

    var with_icon = applications;
    with_icon[1].icon = "one";
    native.applications = &with_icon;
    var frame = picker.Frame{ .query = "" };
    frame.rows[0] = .{ .app = 1 };
    frame.row_count = 1;
    try std.testing.expectEqual(@as(?u16, 1), try native.firstMissing(&frame));
    frame.rows[0] = .{ .app = 2 };
    try std.testing.expectError(error.ApplicationIndexInvalid, native.firstMissing(&frame));
}

test "notification display is one bounded complete UTF-8 line" {
    try std.testing.expectEqualStrings("line", displayText("line\nprivate"));
    const long: [300]u8 = @splat('x');
    try std.testing.expectEqual(@as(usize, 256), displayText(&long).len);
    const x: [255]u8 = @splat('x');
    const prefix = x ++ "λtail";
    try std.testing.expectEqual(@as(usize, 255), displayText(prefix).len);
}

fn testApp(name: []const u8) apps.App {
    return .{
        .storage = @constCast(""),
        .id = "test.desktop",
        .name = name,
        .generic_name = null,
        .keywords = null,
        .icon = null,
        .exec = "test",
        .try_exec = null,
        .only_show_in = null,
        .not_show_in = null,
        .path = null,
        .terminal = false,
        .issues = .empty,
    };
}

test "tray menu overlays only its bounded picker rectangle and remains navigable" {
    const surface = sdl.SDL_CreateSurface(pixels.window_width, pixels.window_height, sdl.SDL_PIXELFORMAT_RGBA32) orelse return error.SdlTestSurfaceFailed;
    defer sdl.SDL_DestroySurface(surface);
    const renderer = sdl.SDL_CreateSoftwareRenderer(surface) orelse return error.SdlTestRendererFailed;
    defer sdl.SDL_DestroyRenderer(renderer);
    var ui_owner: UiOwner = .{};
    var native = Native{ .ui_owner = &ui_owner, .applications = &.{}, .allocator = std.testing.allocator, .io = undefined, .home = "/home/test", .renderer = renderer };
    native.text = try text_draw.Painter.init(std.testing.allocator, renderer, 16);
    defer native.clearText();
    var menu: tray_menu.Menu = .{};
    menu.rows[0] = .{ .id = 7, .length = 13 };
    @memcpy(menu.rows[0].label[0..13], "Open settings");
    menu.rows[1] = .{ .id = 8, .length = 8, .enabled = false };
    @memcpy(menu.rows[1].label[0..8], "Disabled");
    menu.count = 2;
    native.menu = menu;
    try std.testing.expectEqual(@as(?usize, 0), native.menuAt(420, 45));
    try std.testing.expectEqual(@as(?usize, 1), native.menuAt(420, 74));
    try std.testing.expectEqual(@as(?usize, null), native.menuAt(300, 45));
    try std.testing.expectEqual(@as(?usize, null), native.menuAt(420, 120));
    try std.testing.expectEqual(picker.Event.redraw, native.hoverMenu(420, 45));
    try std.testing.expectEqual(@as(?usize, 0), native.menu_hover);
    try std.testing.expectEqual(picker.Event.ignored, native.hoverMenu(420, 45));
    try std.testing.expectEqual(picker.Event.redraw, native.moveMenu(1));
    try std.testing.expectEqual(@as(?usize, 1), native.menu_hover);
    if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255) or
        !sdl.SDL_RenderClear(renderer)) return error.SdlTestRenderFailed;
    try native.drawMenu();
    if (!sdl.SDL_RenderPresent(renderer)) return error.SdlTestRenderFailed;
    const data: [*]const u8 = @ptrCast(surface.*.pixels orelse return error.SdlSurfaceNoPixels);
    const offset = 50 * @as(usize, @intCast(surface.*.pitch)) + 420 * 4;
    try std.testing.expect(data[offset] != 18 or data[offset + 1] != 18 or data[offset + 2] != 24);
}

test "Tab, Backspace, and Escape dismiss tray menus without stealing picker controls" {
    var ui_owner: UiOwner = .{};
    var native = Native{ .ui_owner = &ui_owner, .applications = &.{}, .allocator = std.testing.allocator, .io = undefined, .home = "" };
    native.menu = .{};
    try std.testing.expectEqual(picker.Event.tab, native.keyAction(xkb.XKB_KEY_Tab));
    try std.testing.expect(native.menu == null);
    native.menu = .{};
    try std.testing.expectEqual(picker.Event.redraw, native.keyAction(xkb.XKB_KEY_BackSpace));
    try std.testing.expect(native.menu == null);
    try std.testing.expectEqual(picker.Event.backspace, native.keyAction(xkb.XKB_KEY_BackSpace));
    native.menu = .{};
    try std.testing.expectEqual(picker.Event.redraw, native.keyAction(xkb.XKB_KEY_Escape));
    try std.testing.expect(native.menu == null);
    try std.testing.expectEqual(picker.Event.escape, native.keyAction(xkb.XKB_KEY_Escape));
}

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

test "private-bus picker pointer events open the real tray menu and send its action" {
    // This explicit integration probe runs only under an isolated D-Bus
    // session hosting one known mock item. Regular CI never touches the user's
    // production StatusNotifierWatcher or graphical seat.
    const enabled = getenv("WAYSPOT_TRAY_PRIVATE_TEST") orelse return;
    if (!std.mem.eql(u8, std.mem.span(enabled), "1")) return;
    var ui_owner: UiOwner = .{};
    var native = Native{
        .ui_owner = &ui_owner,
        .applications = &.{},
        .allocator = std.testing.allocator,
        .io = undefined,
        .home = "/home/test",
    };
    native.tray_snapshot = try tray.Snapshot.read(std.testing.allocator, null);
    defer native.tray_snapshot.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), native.tray_snapshot.count);

    try std.testing.expectEqual(picker.Event.redraw, native.buttonDown(sdl.SDL_BUTTON_RIGHT, 495, 23));
    try std.testing.expect(native.menu != null);
    try std.testing.expectEqualStrings("Open Mock Settings", native.menu.?.rows[0].text());
    // The actual action adapter is exercised against the private mock menu.
    try std.testing.expectEqual(picker.Event.redraw, native.buttonDown(sdl.SDL_BUTTON_LEFT, 420, 50));
    try std.testing.expect(native.menu == null);
}

test "row selection waits for its matching left-button release" {
    var ui_owner: UiOwner = .{};
    var native = Native{ .ui_owner = &ui_owner, .applications = &.{}, .allocator = std.testing.allocator, .io = undefined, .home = "" };
    try std.testing.expectEqual(picker.Event{ .hover = 0 }, native.buttonDown(sdl.SDL_BUTTON_LEFT, 20, 100));
    try std.testing.expectEqual(picker.Event{ .click = 0 }, native.buttonUp(sdl.SDL_BUTTON_LEFT, 20, 100));
    try std.testing.expectEqual(picker.Event.ignored, native.buttonUp(sdl.SDL_BUTTON_LEFT, 20, 100));
    try std.testing.expectEqual(picker.Event{ .hover = 0 }, native.buttonDown(sdl.SDL_BUTTON_LEFT, 20, 100));
    try std.testing.expectEqual(picker.Event.ignored, native.buttonUp(sdl.SDL_BUTTON_LEFT, 20, 140));
}
