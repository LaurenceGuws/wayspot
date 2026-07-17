//! Owns native SDL startup, input, drawing, and reverse-order cleanup.

const std = @import("std");
const picker = @import("picker.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

/// Native is the production realization of the picker's exact SDL operations.
pub const Native = struct {
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
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
        if (!sdl.SDL_WaitEvent(&event)) return error.SdlWaitFailed;
        return switch (event.type) {
            sdl.SDL_EVENT_QUIT => .quit,
            sdl.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                sdl.SDLK_ESCAPE => .escape,
                sdl.SDLK_BACKSPACE => .backspace,
                else => .ignored,
            },
            sdl.SDL_EVENT_TEXT_INPUT => .{ .text = try picker.Text.init(std.mem.span(event.text.text)) },
            else => .ignored,
        };
    }

    /// Replaces the beta frame with the current terminated query.
    pub fn draw(native: *Native, query: [:0]const u8) !void {
        const renderer = native.renderer orelse unreachable;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderDebugText(renderer, 24, 24, query.ptr)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
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
};
