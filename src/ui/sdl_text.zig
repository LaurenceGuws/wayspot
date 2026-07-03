//! SDL text owns the launcher's minimal text drawing path.
//!
//! Foot's useful lesson here is damage-directed pragmatism: draw the changed
//! surface with the smallest renderer that meets the product need, then mature
//! the font path only when the UI needs shaping. This module intentionally does
//! not link Howl's C ABI.

const std = @import("std");
const c = @import("sdl_c");

const max_debug_text_bytes = 256;

pub const Rgba8 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const TextStyle = struct {
    color: Rgba8,
    max_bytes: u32,
};

/// draw writes one bounded ASCII-safe debug-text run using SDL's built-in font.
pub fn draw(
    renderer: *c.SDL_Renderer,
    x: f32,
    y: f32,
    text: []const u8,
    style: TextStyle,
) !void {
    const color_set = c.SDL_SetRenderDrawColor(renderer, style.color.r, style.color.g, style.color.b, style.color.a);
    if (!color_set) return error.SdlTextColorFailed;

    var text_buf: [max_debug_text_bytes:0]u8 = undefined;
    const z = asciiDebugTextZ(&text_buf, text, style.max_bytes);
    const rendered = c.SDL_RenderDebugText(renderer, x, y, z.ptr);
    if (!rendered) return error.SdlTextRenderFailed;
}

fn asciiDebugTextZ(buffer: *[max_debug_text_bytes:0]u8, text: []const u8, max_bytes: u32) [:0]u8 {
    const bounded_max = @min(max_bytes, max_debug_text_bytes);
    const out_len = @min(text.len, bounded_max);
    for (text[0..out_len], 0..) |byte, index| {
        buffer[index] = switch (byte) {
            0...31 => ' ',
            127...255 => '?',
            else => byte,
        };
    }
    if (text.len > out_len and out_len > 0) buffer[out_len - 1] = '~';
    buffer[out_len] = 0;
    return buffer[0..out_len :0];
}

test "asciiDebugTextZ bounds and sanitizes debug text" {
    var buffer: [max_debug_text_bytes:0]u8 = undefined;
    const text = asciiDebugTextZ(&buffer, "ab\ncd\xffef", 6);

    try std.testing.expectEqualStrings("ab cd~", text);
}

test "asciiDebugTextZ clamps caller max to internal buffer" {
    var buffer: [max_debug_text_bytes:0]u8 = undefined;
    const text = asciiDebugTextZ(&buffer, "abcdef", max_debug_text_bytes + 10);

    try std.testing.expectEqualStrings("abcdef", text);
}
