//! One-shot beta application picker.

const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

const query_capacity = 256;

const Query = struct {
    bytes: [query_capacity:0]u8 = @splat(0),
    len: usize = 0,

    fn append(query: *Query, text: []const u8) !void {
        if (text.len > query_capacity - query.len) return error.QueryTooLong;
        @memcpy(query.bytes[query.len..][0..text.len], text);
        query.len += text.len;
        query.bytes[query.len] = 0;
    }

    fn delete(query: *Query) void {
        if (query.len == 0) return;
        query.len -= 1;
        query.bytes[query.len] = 0;
    }
};

pub fn main() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
    defer sdl.SDL_Quit();

    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer("wayspot-beta", 720, 480, 0, &window, &renderer)) {
        return error.SdlWindowFailed;
    }
    defer sdl.SDL_DestroyRenderer(renderer);
    defer sdl.SDL_DestroyWindow(window);

    if (!sdl.SDL_StartTextInput(window)) return error.SdlTextInputFailed;
    defer std.debug.assert(sdl.SDL_StopTextInput(window));

    var query: Query = .{};

    var running = true;
    while (running) {
        var event: sdl.SDL_Event = undefined;
        if (!sdl.SDL_WaitEvent(&event)) return error.SdlEventFailed;

        switch (event.type) {
            sdl.SDL_EVENT_QUIT => running = false,
            sdl.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                sdl.SDLK_ESCAPE => running = false,
                sdl.SDLK_BACKSPACE => query.delete(),
                else => {},
            },
            sdl.SDL_EVENT_TEXT_INPUT => {
                const text = std.mem.span(event.text.text);
                try query.append(text);
            },
            else => {},
        }

        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlRenderFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlRenderFailed;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 235, 235, 240, 255)) return error.SdlRenderFailed;
        if (!sdl.SDL_RenderDebugText(renderer, 24, 24, &query.bytes)) return error.SdlRenderFailed;
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlRenderFailed;
    }
}

test "query accepts its exact bound and rejects the next byte without mutation" {
    var query: Query = .{};
    try query.append(&([_]u8{'a'} ** query_capacity));
    try std.testing.expectError(error.QueryTooLong, query.append("b"));
    try std.testing.expectEqual(query_capacity, query.len);
    try std.testing.expectEqual(@as(u8, 0), query.bytes[query_capacity]);
}

test "delete maintains termination" {
    var query: Query = .{};
    try query.append("ab");
    query.delete();
    try std.testing.expectEqualStrings("a", query.bytes[0..query.len]);
    try std.testing.expectEqual(@as(u8, 0), query.bytes[query.len]);
}
