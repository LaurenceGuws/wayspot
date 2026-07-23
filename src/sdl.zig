//! Owns native SDL startup, input, drawing, and reverse-order cleanup.

const std = @import("std");
const apps = @import("apps.zig");
const icon_path = @import("icon.zig");
const image = @import("image.zig");
const picker = @import("picker.zig");
const sdl_event = @import("sdl_event.zig");
const pixels = @import("sdl_pixels.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const font_bytes = @embedFile("NotoSans-Regular.ttf");

/// Native is the production realization of the picker's exact SDL operations.
pub const Native = struct {
    const font_size = 16;
    const text_capacity = picker.visible_row_capacity + 1;

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

    applications: []const apps.App,
    allocator: std.mem.Allocator,
    io: std.Io,
    home: []const u8,
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
    font_stream: ?*sdl.SDL_IOStream = null,
    font: ?*sdl.TTF_Font = null,
    text_engine: ?*sdl.TTF_TextEngine = null,
    texts: [text_capacity]*sdl.TTF_Text = undefined,
    text_count: usize = 0,
    icons: [picker.visible_row_capacity]Icon = undefined,
    icon_count: usize = 0,
    pending_icons: bool = false,
    events_pending: bool = false,
    initialized: bool = false,
    ttf_initialized: bool = false,
    text_started: bool = false,

    /// Initializes exactly the SDL video subsystem.
    pub fn init(native: *Native) !void {
        std.debug.assert(!native.initialized);
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        native.initialized = true;
        errdefer {
            sdl.SDL_Quit();
            native.initialized = false;
        }
        if (!sdl.TTF_Init()) return error.TtfInitFailed;
        native.ttf_initialized = true;
    }

    /// Creates the one picker window and its renderer together.
    pub fn create(native: *Native) !void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.window == null);
        std.debug.assert(native.renderer == null);
        comptime std.debug.assert(picker.visible_row_capacity == pixels.visible_rows);
        if (!sdl.SDL_CreateWindowAndRenderer(
            "wayspot",
            pixels.window_width,
            pixels.window_height,
            sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
            &native.window,
            &native.renderer,
        )) return error.SdlCreateFailed;
        errdefer {
            native.clearText();
            sdl.SDL_DestroyRenderer(native.renderer);
            sdl.SDL_DestroyWindow(native.window);
            native.renderer = null;
            native.window = null;
        }
        if (!sdl.SDL_SetRenderLogicalPresentation(
            native.renderer,
            pixels.window_width,
            pixels.window_height,
            sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
        )) return error.SdlLogicalPresentationFailed;
        native.font_stream = sdl.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len) orelse
            return error.TtfFontStreamCreateFailed;
        native.font = sdl.TTF_OpenFontIO(native.font_stream, false, font_size) orelse
            return error.TtfFontOpenFailed;
        native.text_engine = sdl.TTF_CreateRendererTextEngine(native.renderer) orelse
            return error.TtfTextEngineCreateFailed;
        while (native.text_count < native.texts.len) {
            native.texts[native.text_count] = sdl.TTF_CreateText(
                native.text_engine,
                native.font,
                null,
                0,
            ) orelse return error.TtfTextCreateFailed;
            native.text_count += 1;
        }
    }

    /// Enables UTF-8 text events before the picker can wait for input.
    pub fn startText(native: *Native) !void {
        std.debug.assert(native.window != null);
        std.debug.assert(!native.text_started);
        if (!sdl.SDL_StartTextInput(native.window)) return error.SdlStartTextFailed;
        native.text_started = true;
    }

    /// Waits for input, then drains one bounded portion of SDL's event queue.
    pub fn read(native: *Native) !picker.Events {
        std.debug.assert(native.text_started);
        var events: picker.Events = .{};
        while (events.count < picker.event_capacity) {
            var native_event: sdl.SDL_Event = undefined;
            if (events.count > 0 or native.events_pending) {
                if (!sdl.SDL_PollEvent(&native_event)) {
                    native.events_pending = false;
                    break;
                }
            } else if (native.pending_icons) {
                if (!sdl.SDL_WaitEventTimeout(&native_event, 1)) {
                    events.items[0] = .idle;
                    events.count = 1;
                    return events;
                }
            } else if (!sdl.SDL_WaitEvent(&native_event)) {
                return error.SdlWaitFailed;
            }
            if (!sdl.SDL_ConvertEventToRenderCoordinates(native.renderer, &native_event)) {
                return error.SdlCoordinateConversionFailed;
            }
            events.items[events.count] = try native.translate(native_event);
            events.count += 1;
        }
        events.more = sdl.SDL_PollEvent(null);
        native.events_pending = events.more;
        return events;
    }

    fn translate(native: *Native, event: sdl.SDL_Event) !picker.Event {
        return switch (event.type) {
            sdl.SDL_EVENT_QUIT => .quit,
            sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => .quit,
            sdl.SDL_EVENT_WINDOW_EXPOSED,
            sdl.SDL_EVENT_WINDOW_RESIZED,
            sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            sdl.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
            sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
            sdl.SDL_EVENT_RENDER_TARGETS_RESET,
            => .redraw,
            sdl.SDL_EVENT_RENDER_DEVICE_RESET => reset: {
                native.clearIcons();
                try native.resetText();
                break :reset .redraw;
            },
            sdl.SDL_EVENT_RENDER_DEVICE_LOST => error.SdlRenderDeviceLost,
            sdl.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                sdl.SDLK_ESCAPE => .escape,
                sdl.SDLK_BACKSPACE => .backspace,
                sdl.SDLK_UP => .up,
                sdl.SDLK_DOWN => .down,
                sdl.SDLK_RETURN => .enter,
                else => .ignored,
            },
            sdl.SDL_EVENT_TEXT_INPUT => .{ .text = try picker.Text.init(std.mem.span(event.text.text)) },
            sdl.SDL_EVENT_MOUSE_MOTION => hoverAt(event.motion.x, event.motion.y) orelse .ignored,
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => if (event.button.button == sdl.SDL_BUTTON_LEFT)
                clickAt(event.button.x, event.button.y) orelse .ignored
            else
                .ignored,
            sdl.SDL_EVENT_MOUSE_WHEEL => .{ .scroll = sdl_event.wheelRows(
                event.wheel.integer_y,
                event.wheel.direction == sdl.SDL_MOUSEWHEEL_FLIPPED,
            ) },
            else => .ignored,
        };
    }

    /// Replaces the frame with the current terminated query.
    pub fn draw(native: *Native, frame: *const picker.Frame) !void {
        const renderer = native.renderer orelse unreachable;
        native.evict(frame);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        const query_pane = nativeRect(pixels.query);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 30, 31, 39, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderFillRect(renderer, &query_pane)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlDrawFailed;
        const query: []const u8 = if (frame.query.len == 0) switch (frame.table) {
            .root => "Choose a mode",
            .apps => "Search applications",
            .notifications => "Notification history",
        } else frame.query;
        try native.drawText(0, query, .{ 235, 235, 240 }, 20, 14);
        for (frame.rowSlice(), 0..) |row, index| {
            try native.drawRow(row, index, index == frame.selected_row);
        }
        try drawScrollbar(renderer, frame);
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
        if (try native.firstMissing(frame)) |app_index| {
            native.pending_icons = true;
            try native.load(app_index);
        } else {
            native.pending_icons = false;
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
        const text_index = textIndex(index);
        switch (row) {
            .table => |table| try native.drawText(
                text_index,
                picker.tableName(table),
                color,
                20,
                pixels.textY(index),
            ),
            .app => |app_index| {
                const app = try native.application(app_index);
                if (native.icon(app_index)) |item| switch (item.texture) {
                    .missing, .rejected => {},
                    .loaded => |texture| {
                        const target = nativeRect(pixels.icon(index));
                        if (!sdl.SDL_RenderTexture(renderer, texture, null, &target)) {
                            return error.SdlDrawFailed;
                        }
                    },
                };
                try native.drawText(text_index, app.name, color, 44, pixels.textY(index));
            },
            .notification => |record| {
                const secondary: [3]u8 = if (selected) .{ 180, 190, 205 } else .{ 135, 140, 150 };
                const fields = [_][]const u8{ record.app_name, record.summary, record.body };
                const x = [_]c_int{ 14, 170, 430 };
                const width = [_]c_int{ 150, 250, 270 };
                for (fields, x, width, 0..) |text, left, field_width, field| {
                    try native.drawClippedText(
                        text_index,
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
        if (!sdl.SDL_StopTextInput(native.window)) return error.SdlStopTextFailed;
    }

    /// Destroys the renderer and window after text input has stopped.
    pub fn destroy(native: *Native) void {
        std.debug.assert(native.window != null);
        std.debug.assert(native.renderer != null);
        std.debug.assert(!native.text_started);
        native.clearIcons();
        native.clearText();
        sdl.SDL_DestroyRenderer(native.renderer);
        sdl.SDL_DestroyWindow(native.window);
        native.renderer = null;
        native.window = null;
    }

    /// Quits SDL after every native object has been destroyed.
    pub fn quit(native: *Native) void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.window == null);
        std.debug.assert(native.renderer == null);
        std.debug.assert(!native.text_started);
        std.debug.assert(native.ttf_initialized);
        sdl.TTF_Quit();
        native.ttf_initialized = false;
        sdl.SDL_Quit();
        native.initialized = false;
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

    fn resetText(native: *Native) !void {
        native.clearTexts();
        sdl.TTF_DestroyRendererTextEngine(native.text_engine);
        native.text_engine = sdl.TTF_CreateRendererTextEngine(native.renderer) orelse
            return error.TtfTextEngineCreateFailed;
        while (native.text_count < native.texts.len) {
            native.texts[native.text_count] = sdl.TTF_CreateText(
                native.text_engine,
                native.font,
                null,
                0,
            ) orelse return error.TtfTextCreateFailed;
            native.text_count += 1;
        }
    }

    fn clearTexts(native: *Native) void {
        while (native.text_count > 0) {
            native.text_count -= 1;
            sdl.TTF_DestroyText(native.texts[native.text_count]);
        }
    }

    fn clearText(native: *Native) void {
        native.clearTexts();
        sdl.TTF_DestroyRendererTextEngine(native.text_engine);
        sdl.TTF_CloseFont(native.font);
        if (native.font_stream) |stream| {
            std.debug.assert(sdl.SDL_CloseIO(stream));
        }
        native.text_engine = null;
        native.font = null;
        native.font_stream = null;
    }

    fn drawText(
        native: *Native,
        index: usize,
        text: []const u8,
        color: [3]u8,
        x: f32,
        y: f32,
    ) !void {
        std.debug.assert(index < native.text_count);
        const item = native.texts[index];
        if (!sdl.TTF_SetTextString(item, textPointer(text), text.len)) return error.TtfTextSetFailed;
        if (!sdl.TTF_SetTextColor(item, color[0], color[1], color[2], 255)) {
            return error.TtfTextColorFailed;
        }
        if (!sdl.TTF_DrawRendererText(item, x, y)) return error.TtfTextDrawFailed;
    }

    fn drawClippedText(
        native: *Native,
        index: usize,
        text: []const u8,
        color: [3]u8,
        clip: sdl.SDL_Rect,
    ) !void {
        const renderer = native.renderer orelse unreachable;
        if (!sdl.SDL_SetRenderClipRect(renderer, &clip)) return error.SdlDrawFailed;
        const result = native.drawText(
            index,
            text,
            color,
            @floatFromInt(clip.x),
            @floatFromInt(clip.y + 5),
        );
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
                pixels.icon_size,
                pixels.icon_size,
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

fn rowApp(row: picker.Row) ?u16 {
    return switch (row) {
        .app => |index| index,
        .table, .notification => null,
    };
}

fn textIndex(row: usize) usize {
    std.debug.assert(row < picker.visible_row_capacity);
    return row + 1;
}

fn displayText(text: []const u8) []const u8 {
    const line_end = std.mem.indexOfAny(u8, text, "\r\n") orelse text.len;
    var end = @min(line_end, 256);
    while (end < text.len and end > 0 and text[end] & 0b1100_0000 == 0b1000_0000) end -= 1;
    return text[0..end];
}

fn textPointer(text: []const u8) ?[*]const u8 {
    return if (text.len == 0) null else text.ptr;
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
    try std.testing.expectEqual(@as(usize, 256), displayText("x" ** 300).len);
    const prefix = ("x" ** 255) ++ "λtail";
    try std.testing.expectEqual(@as(usize, 255), displayText(prefix).len);
}

test "empty picker text clears SDL_ttf without borrowing a strlen pointer" {
    try std.testing.expect(sdl.TTF_Init());
    defer sdl.TTF_Quit();
    const stream = sdl.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len) orelse return error.FontStreamFailed;
    defer std.debug.assert(sdl.SDL_CloseIO(stream));
    const font = sdl.TTF_OpenFontIO(stream, false, 16) orelse return error.FontOpenFailed;
    defer sdl.TTF_CloseFont(font);
    const item = sdl.TTF_CreateText(null, font, null, 0) orelse return error.TextCreateFailed;
    defer sdl.TTF_DestroyText(item);
    const prior = [_]u8{ 'p', 'r', 'i', 'o', 'r' };
    try std.testing.expect(sdl.TTF_SetTextString(item, textPointer(&prior), prior.len));
    var width: c_int = 0;
    var height: c_int = 0;
    try std.testing.expect(sdl.TTF_GetTextSize(item, &width, &height));
    try std.testing.expect(width > 0);
    const empty = prior[0..0];
    try std.testing.expect(textPointer(empty) == null);
    try std.testing.expect(sdl.TTF_SetTextString(item, textPointer(empty), empty.len));
    try std.testing.expect(sdl.TTF_GetTextSize(item, &width, &height));
    try std.testing.expectEqual(@as(c_int, 0), width);
    const exact = [_]u8{ 'o', 'k' };
    try std.testing.expect(textPointer(&exact).? == exact[0..].ptr);
    try std.testing.expect(sdl.TTF_SetTextString(item, textPointer(&exact), exact.len));
    try std.testing.expect(sdl.TTF_GetTextSize(item, &width, &height));
    try std.testing.expect(width > 0);
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
        .issues = .initEmpty(),
    };
}
