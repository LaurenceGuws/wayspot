//! SDL text owns the launcher's minimal text drawing path.
//!
//! Foot's useful lesson here is damage-directed pragmatism: draw the changed
//! surface with the smallest renderer that meets the product need, then mature
//! the font path only when the UI needs shaping. Howl's text renderer remains
//! the source to copy from when Wayspot needs glyph atlases, fallback fonts, or
//! HarfBuzz shaping; this module intentionally does not link Howl's C ABI.

const std = @import("std");
const c = @import("sdl_c");

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
    allocator: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    x: f32,
    y: f32,
    text: []const u8,
    style: TextStyle,
) !void {
    const color_set = c.SDL_SetRenderDrawColor(renderer, style.color.r, style.color.g, style.color.b, style.color.a);
    if (!color_set) return error.SdlTextColorFailed;

    const z = try asciiDebugTextZ(allocator, text, style.max_bytes);
    defer allocator.free(z);
    const rendered = c.SDL_RenderDebugText(renderer, x, y, z.ptr);
    if (!rendered) return error.SdlTextRenderFailed;
}

fn asciiDebugTextZ(allocator: std.mem.Allocator, text: []const u8, max_bytes: u32) ![:0]u8 {
    const out_len = @min(text.len, max_bytes);
    var out = try allocator.allocSentinel(u8, out_len, 0);
    for (text[0..out_len], 0..) |byte, index| {
        out[index] = switch (byte) {
            0...31 => ' ',
            127...255 => '?',
            else => byte,
        };
    }
    if (text.len > out_len and out_len > 0) out[out_len - 1] = '~';
    return out;
}

test "asciiDebugTextZ bounds and sanitizes debug text" {
    const text = try asciiDebugTextZ(std.testing.allocator, "ab\ncd\xffef", 6);
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings("ab cd~", text);
}
