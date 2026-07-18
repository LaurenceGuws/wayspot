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

/// Native is the production realization of the picker's exact SDL operations.
pub const Native = struct {
    const font_path = "/usr/share/fonts/noto/NotoSans-Regular.ttf";
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

        app_index: usize,
        texture: Texture,
    };

    applications: []const apps.App,
    allocator: std.mem.Allocator,
    io: std.Io,
    home: []const u8,
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
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

    /// Creates the one beta window and its renderer together.
    pub fn create(native: *Native) !void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.window == null);
        std.debug.assert(native.renderer == null);
        comptime std.debug.assert(picker.visible_row_capacity == pixels.visible_rows);
        if (!sdl.SDL_CreateWindowAndRenderer(
            "wayspot-beta",
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
        native.font = sdl.TTF_OpenFont(font_path, font_size) orelse return error.TtfFontOpenFailed;
        native.text_engine = sdl.TTF_CreateRendererTextEngine(native.renderer) orelse
            return error.TtfTextEngineCreateFailed;
        while (native.text_count < native.texts.len) {
            native.texts[native.text_count] = sdl.TTF_CreateText(
                native.text_engine,
                native.font,
                "",
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

    /// Replaces the beta frame with the current terminated query.
    pub fn draw(native: *Native, frame: *const picker.Frame) !void {
        const renderer = native.renderer orelse unreachable;
        native.evict(frame);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        const query_pane = nativeRect(pixels.query);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 30, 31, 39, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderFillRect(renderer, &query_pane)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlDrawFailed;
        const query = if (frame.query.len == 0) "Search applications" else frame.query.ptr;
        try native.drawText(0, query, .{ 235, 235, 240 }, 20, 14);
        for (frame.rowSlice(), 0..) |row, index| {
            const row_rect = nativeRect(pixels.row(index));
            const selected = index == frame.selected_row;
            const color: [3]u8 = if (index == frame.selected_row)
                .{ 130, 190, 255 }
            else
                .{ 210, 210, 215 };
            if (!sdl.SDL_SetRenderDrawColor(renderer, if (selected) 48 else 24, if (selected) 55 else 24, if (selected) 72 else 30, 255)) {
                return error.SdlDrawFailed;
            }
            if (!sdl.SDL_RenderFillRect(renderer, &row_rect)) return error.SdlDrawFailed;
            if (!sdl.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], 255)) {
                return error.SdlDrawFailed;
            }
            var name: [apps.name_capacity:0]u8 = @splat(0);
            @memcpy(name[0..row.name.len], row.name);
            if (native.icon(row.app_index)) |item| switch (item.texture) {
                .missing, .rejected => {},
                .loaded => |texture| {
                    const target = nativeRect(pixels.icon(index));
                    if (!sdl.SDL_RenderTexture(renderer, texture, null, &target)) return error.SdlDrawFailed;
                },
            };
            try native.drawText(index + 1, &name, color, 44, pixels.textY(index));
        }
        try drawScrollbar(renderer, frame);
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
        if (native.firstMissing(frame)) |app_index| {
            native.pending_icons = true;
            try native.load(app_index);
        } else {
            native.pending_icons = false;
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

    fn icon(native: *const Native, app_index: usize) ?Icon {
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
                "",
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
        native.text_engine = null;
        native.font = null;
    }

    fn drawText(
        native: *Native,
        index: usize,
        text: [*c]const u8,
        color: [3]u8,
        x: f32,
        y: f32,
    ) !void {
        std.debug.assert(index < native.text_count);
        const item = native.texts[index];
        if (!sdl.TTF_SetTextString(item, text, 0)) return error.TtfTextSetFailed;
        if (!sdl.TTF_SetTextColor(item, color[0], color[1], color[2], 255)) {
            return error.TtfTextColorFailed;
        }
        if (!sdl.TTF_DrawRendererText(item, x, y)) return error.TtfTextDrawFailed;
    }

    fn firstMissing(native: *const Native, frame: *const picker.Frame) ?usize {
        for (frame.rowSlice()) |row| {
            const name = native.applications[row.app_index].icon orelse continue;
            if (name.len > 0 and native.icon(row.app_index) == null) return row.app_index;
        }
        return null;
    }

    fn evict(native: *Native, frame: *const picker.Frame) void {
        var index: usize = 0;
        while (index < native.icon_count) {
            var visible = false;
            for (frame.rowSlice()) |row| {
                if (row.app_index == native.icons[index].app_index) visible = true;
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

    fn load(native: *Native, app_index: usize) !void {
        std.debug.assert(native.icon_count < native.icons.len);
        const name = native.applications[app_index].icon orelse return;
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

    fn remember(native: *Native, app_index: usize, texture: Icon.Texture) void {
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
