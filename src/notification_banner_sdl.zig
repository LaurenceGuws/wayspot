//! Owns the notification window, drawing, pointer dismissal, deadlines, and SDL cleanup.

const std = @import("std");
const banner = @import("notification_banner.zig");
const bridge_mod = @import("notification_bridge.zig");
const runtime = @import("notification_banner_run.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

const font_bytes = @embedFile("NotoSans-Regular.ttf");
const width = 420;
const height = 120;
const font_size = 16;
const wake_unset = std.math.maxInt(u32);

var wake_event: std.atomic.Value(u32) = .init(wake_unset);

const Native = struct {
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
    stream: ?*sdl.SDL_IOStream = null,
    font: ?*sdl.TTF_Font = null,
    engine: ?*sdl.TTF_TextEngine = null,
    summary: ?*sdl.TTF_Text = null,
    body: ?*sdl.TTF_Text = null,
    initialized: bool = false,
    ttf_initialized: bool = false,

    /// Acquires SDL, one hidden window, its renderer, and two bounded text owners.
    pub fn start(native: *Native, bridge: *bridge_mod.Bridge) !void {
        std.debug.assert(!native.initialized);
        if (!sdl.SDL_SetAppMetadata("wayspot notification", "0.1.0", "wayspot-notification")) {
            return error.SdlMetadataFailed;
        }
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        native.initialized = true;
        errdefer native.destroy();
        if (!sdl.TTF_Init()) return error.TtfInitFailed;
        native.ttf_initialized = true;

        const event = sdl.SDL_RegisterEvents(1);
        if (event == std.math.maxInt(u32)) return error.SdlEventRegistrationFailed;
        wake_event.store(event, .release);

        native.window = sdl.SDL_CreateWindow(
            "wayspot notification",
            width,
            height,
            sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY |
                sdl.SDL_WINDOW_BORDERLESS |
                sdl.SDL_WINDOW_ALWAYS_ON_TOP |
                sdl.SDL_WINDOW_NOT_FOCUSABLE |
                sdl.SDL_WINDOW_HIDDEN,
        ) orelse return error.SdlCreateFailed;
        native.renderer = sdl.SDL_CreateRenderer(native.window, null) orelse
            return error.SdlRendererCreateFailed;
        if (!sdl.SDL_SetRenderLogicalPresentation(
            native.renderer,
            width,
            height,
            sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
        )) return error.SdlLogicalPresentationFailed;

        native.stream = sdl.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len) orelse
            return error.TtfFontStreamCreateFailed;
        native.font = sdl.TTF_OpenFontIO(native.stream, false, font_size) orelse
            return error.TtfFontOpenFailed;
        native.engine = sdl.TTF_CreateRendererTextEngine(native.renderer) orelse
            return error.TtfTextEngineCreateFailed;
        native.summary = sdl.TTF_CreateText(native.engine, native.font, "", 0) orelse
            return error.TtfTextCreateFailed;
        native.body = sdl.TTF_CreateText(native.engine, native.font, "", 0) orelse
            return error.TtfTextCreateFailed;
        if (!sdl.TTF_SetTextWrapWidth(native.body, width - 32)) return error.TtfTextWrapFailed;
        bridge.ready(wake);
    }

    /// Prevents new worker wakes before releasing every native object in reverse order.
    pub fn stop(native: *Native, bridge: *bridge_mod.Bridge) void {
        bridge.pause();
        native.destroy();
    }

    fn destroy(native: *Native) void {
        wake_event.store(wake_unset, .release);
        if (native.body) |text| sdl.TTF_DestroyText(text);
        if (native.summary) |text| sdl.TTF_DestroyText(text);
        if (native.engine) |engine| sdl.TTF_DestroyRendererTextEngine(engine);
        if (native.font) |font| sdl.TTF_CloseFont(font);
        if (native.stream) |stream| std.debug.assert(sdl.SDL_CloseIO(stream));
        if (native.renderer) |renderer| sdl.SDL_DestroyRenderer(renderer);
        if (native.window) |window| sdl.SDL_DestroyWindow(window);
        if (native.ttf_initialized) sdl.TTF_Quit();
        if (native.initialized) sdl.SDL_Quit();
        native.* = .{};
    }

    /// Returns SDL's monotonic millisecond clock used for banner deadlines.
    pub fn now(_: *const Native) u64 {
        return sdl.SDL_GetTicks();
    }

    /// Draws one visible record or hides the window when no record remains.
    pub fn draw(native: *Native, visible: ?banner.Visible) !void {
        const window = native.window orelse unreachable;
        const renderer = native.renderer orelse unreachable;
        const item = visible orelse {
            if (!sdl.SDL_HideWindow(window)) return error.SdlHideFailed;
            return;
        };
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        if (!sdl.TTF_SetTextString(native.summary, item.record.summary.ptr, item.record.summary.len)) {
            return error.TtfTextSetFailed;
        }
        if (!sdl.TTF_SetTextString(native.body, item.record.body.ptr, item.record.body.len)) {
            return error.TtfTextSetFailed;
        }
        if (!sdl.TTF_SetTextColor(native.summary, 235, 235, 240, 255) or
            !sdl.TTF_SetTextColor(native.body, 190, 192, 202, 255))
        {
            return error.TtfTextColorFailed;
        }
        const summary_clip = sdl.SDL_Rect{ .x = 16, .y = 12, .w = width - 32, .h = 24 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &summary_clip)) return error.SdlClipFailed;
        if (!sdl.TTF_DrawRendererText(native.summary, 16, 14)) return error.TtfTextDrawFailed;
        const body_clip = sdl.SDL_Rect{ .x = 16, .y = 42, .w = width - 32, .h = 60 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &body_clip)) return error.SdlClipFailed;
        if (!sdl.TTF_DrawRendererText(native.body, 16, 44)) return error.TtfTextDrawFailed;
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlClipFailed;
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
        if (!sdl.SDL_ShowWindow(window)) return error.SdlShowFailed;
    }

    /// Sleeps until the next SDL event or the exact visible-record deadline.
    pub fn wait(_: *Native, deadline_ms: u64) !runtime.Event {
        const now_ms = sdl.SDL_GetTicks();
        const wait_ms: i32 = @intCast(@min(deadline_ms -| now_ms, banner.maximum_timeout_ms));
        var event: sdl.SDL_Event = undefined;
        if (!sdl.SDL_WaitEventTimeout(&event, wait_ms)) return .timeout;
        if (event.type == wake_event.load(.acquire)) return .wake;
        if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN and
            event.button.button == sdl.SDL_BUTTON_LEFT) return .dismiss;
        return switch (event.type) {
            sdl.SDL_EVENT_WINDOW_EXPOSED,
            sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
            sdl.SDL_EVENT_RENDER_TARGETS_RESET,
            => .redraw,
            sdl.SDL_EVENT_RENDER_DEVICE_LOST => .device_lost,
            else => .timeout,
        };
    }
};

/// Runs one sleeping banner window until its DBus owner stops or fails.
pub fn run(bridge: *bridge_mod.Bridge, allocator: std.mem.Allocator) !void {
    var native: Native = .{};
    return runtime.run(&native, bridge, allocator);
}

fn wake() bool {
    const event_type = wake_event.load(.acquire);
    if (event_type == wake_unset) return false;
    var event: sdl.SDL_Event = @bitCast(@as([@sizeOf(sdl.SDL_Event)]u8, @splat(0)));
    event.type = event_type;
    return sdl.SDL_PushEvent(&event);
}
