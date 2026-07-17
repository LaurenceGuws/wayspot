//! Owns native SDL startup, input, drawing, and reverse-order cleanup.

const std = @import("std");
const apps = @import("apps.zig");
const icon_path = @import("icon.zig");
const picker = @import("picker.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

/// Native is the production realization of the picker's exact SDL operations.
pub const Native = struct {
    const Icon = struct {
        app_index: usize,
        texture: ?*sdl.SDL_Texture,
    };

    applications: []const apps.App,
    home: []const u8,
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
    icons: [picker.visible_row_capacity]Icon = undefined,
    icon_count: usize = 0,
    pending_icons: bool = false,
    initialized: bool = false,
    text_started: bool = false,

    /// Initializes exactly the SDL video subsystem.
    pub fn init(native: *Native) !void {
        std.debug.assert(!native.initialized);
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        native.initialized = true;
    }

    /// Creates the one beta window and its renderer together.
    pub fn create(native: *Native) !void {
        std.debug.assert(native.initialized);
        std.debug.assert(native.window == null);
        std.debug.assert(native.renderer == null);
        if (!sdl.SDL_CreateWindowAndRenderer(
            "wayspot-beta",
            720,
            480,
            0,
            &native.window,
            &native.renderer,
        )) return error.SdlCreateFailed;
    }

    /// Enables UTF-8 text events before the picker can wait for input.
    pub fn startText(native: *Native) !void {
        std.debug.assert(native.window != null);
        std.debug.assert(!native.text_started);
        if (!sdl.SDL_StartTextInput(native.window)) return error.SdlStartTextFailed;
        native.text_started = true;
    }

    /// Waits for one SDL event and copies all returned event data into Event.
    pub fn wait(native: *Native) !picker.Event {
        std.debug.assert(native.text_started);
        var event: sdl.SDL_Event = undefined;
        if (native.pending_icons) {
            if (!sdl.SDL_WaitEventTimeout(&event, 1)) return .idle;
        } else if (!sdl.SDL_WaitEvent(&event)) return error.SdlWaitFailed;
        return switch (event.type) {
            sdl.SDL_EVENT_QUIT => .quit,
            sdl.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                sdl.SDLK_ESCAPE => .escape,
                sdl.SDLK_BACKSPACE => .backspace,
                sdl.SDLK_UP => .up,
                sdl.SDLK_DOWN => .down,
                sdl.SDLK_RETURN => .enter,
                else => .ignored,
            },
            sdl.SDL_EVENT_TEXT_INPUT => .{ .text = try picker.Text.init(std.mem.span(event.text.text)) },
            sdl.SDL_EVENT_MOUSE_MOTION => rowAt(event.motion.x, event.motion.y) orelse .ignored,
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => if (event.button.button == sdl.SDL_BUTTON_LEFT)
                clickAt(event.button.x, event.button.y) orelse .ignored
            else
                .ignored,
            sdl.SDL_EVENT_MOUSE_WHEEL => if (event.wheel.integer_y > 0)
                .scroll_up
            else if (event.wheel.integer_y < 0)
                .scroll_down
            else
                .ignored,
            else => .ignored,
        };
    }

    /// Replaces the beta frame with the current terminated query.
    pub fn draw(native: *Native, frame: *const picker.Frame) !void {
        const renderer = native.renderer orelse unreachable;
        native.evict(frame);
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        const query_pane = sdl.SDL_FRect{ .x = 8, .y = 8, .w = 704, .h = 32 };
        if (!sdl.SDL_SetRenderDrawColor(renderer, 30, 31, 39, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderFillRect(renderer, &query_pane)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlDrawFailed;
        const query = if (frame.query.len == 0) "Search applications" else frame.query.ptr;
        if (!sdl.SDL_RenderDebugText(renderer, 20, 20, query)) return error.SdlDrawFailed;
        for (frame.rowSlice(), 0..) |row, index| {
            const y = picker.query_height + @as(f32, @floatFromInt(index)) * picker.row_height;
            const row_rect = sdl.SDL_FRect{ .x = 8, .y = y, .w = 696, .h = picker.row_height - 2 };
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
            if (native.icon(row.app_index)) |item| if (item.texture) |texture| {
                const target = sdl.SDL_FRect{ .x = 16, .y = y + 3, .w = 16, .h = 16 };
                if (!sdl.SDL_RenderTexture(renderer, texture, null, &target)) return error.SdlDrawFailed;
            };
            if (!sdl.SDL_RenderDebugText(renderer, 40, y + 7, &name)) {
                return error.SdlDrawFailed;
            }
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
        while (native.icon_count > 0) {
            native.icon_count -= 1;
            sdl.SDL_DestroyTexture(native.icons[native.icon_count].texture);
        }
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
        sdl.SDL_Quit();
        native.initialized = false;
    }

    fn icon(native: *const Native, app_index: usize) ?Icon {
        for (native.icons[0..native.icon_count]) |item| {
            if (item.app_index == app_index) return item;
        }
        return null;
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
                sdl.SDL_DestroyTexture(native.icons[index].texture);
                native.icon_count -= 1;
                native.icons[index] = native.icons[native.icon_count];
            }
        }
    }

    fn load(native: *Native, app_index: usize) !void {
        std.debug.assert(native.icon_count < native.icons.len);
        const name = native.applications[app_index].icon orelse return;
        var paths: icon_path.Paths = .{ .home = native.home, .icon = name };
        while (paths.next() catch null) |path| {
            const surface = sdl.SDL_LoadSurface(path.ptr) orelse continue;
            defer sdl.SDL_DestroySurface(surface);
            const scaled = sdl.SDL_ScaleSurface(surface, 16, 16, sdl.SDL_SCALEMODE_LINEAR) orelse {
                return error.SdlIconScaleFailed;
            };
            defer sdl.SDL_DestroySurface(scaled);
            const created = sdl.SDL_CreateTextureFromSurface(native.renderer, scaled) orelse {
                return error.SdlIconTextureFailed;
            };
            native.icons[native.icon_count] = .{ .app_index = app_index, .texture = created };
            native.icon_count += 1;
            return;
        }
        native.icons[native.icon_count] = .{ .app_index = app_index, .texture = null };
        native.icon_count += 1;
    }
};

fn rowAt(x: f32, y: f32) ?picker.Event {
    if (x < 8 or x >= 704 or y < picker.query_height) return null;
    const row: usize = @intFromFloat((y - picker.query_height) / picker.row_height);
    return if (row < picker.visible_row_capacity) .{ .hover = row } else null;
}

fn clickAt(x: f32, y: f32) ?picker.Event {
    const event = rowAt(x, y) orelse return null;
    return .{ .click = event.hover };
}

fn drawScrollbar(renderer: *sdl.SDL_Renderer, frame: *const picker.Frame) !void {
    if (frame.total_count <= frame.row_count) return;
    const track = sdl.SDL_FRect{
        .x = 708,
        .y = picker.query_height,
        .w = 4,
        .h = picker.row_height * @as(f32, @floatFromInt(picker.visible_row_capacity)),
    };
    const visible: f32 = @floatFromInt(frame.row_count);
    const total: f32 = @floatFromInt(frame.total_count);
    const height = @max(16, track.h * visible / total);
    const max_first = frame.total_count - frame.row_count;
    const offset = @as(f32, @floatFromInt(frame.first)) / @as(f32, @floatFromInt(max_first));
    const thumb = sdl.SDL_FRect{ .x = track.x, .y = track.y + (track.h - height) * offset, .w = track.w, .h = height };
    if (!sdl.SDL_SetRenderDrawColor(renderer, 38, 44, 52, 255)) return error.SdlDrawFailed;
    if (!sdl.SDL_RenderFillRect(renderer, &track)) return error.SdlDrawFailed;
    if (!sdl.SDL_SetRenderDrawColor(renderer, 104, 118, 136, 255)) return error.SdlDrawFailed;
    if (!sdl.SDL_RenderFillRect(renderer, &thumb)) return error.SdlDrawFailed;
}

test "pointer row geometry respects panes and bounds" {
    try std.testing.expectEqual(null, rowAt(20, picker.query_height - 1));
    try std.testing.expectEqual(@as(usize, 0), rowAt(20, picker.query_height).?.hover);
    try std.testing.expectEqual(
        @as(usize, picker.visible_row_capacity - 1),
        rowAt(20, picker.query_height + picker.row_height * (picker.visible_row_capacity - 1)).?.hover,
    );
    try std.testing.expectEqual(null, rowAt(20, picker.query_height + picker.row_height * picker.visible_row_capacity));
}
