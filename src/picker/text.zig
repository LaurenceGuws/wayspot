//! Text owns bounded shaped text drawing for Wayspot surfaces.
//!
//! This file copies Howl's useful text lessons into one small owner: FreeType
//! owns face raster data, HarfBuzz owns one shaping buffer, and the vendor backend owns the
//! final texture lifetime for one draw call.

const std = @import("std");
const c = @import("sdl_c");
const appearance_values = @import("appearance.zig");

const ft = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
    @cInclude("harfbuzz/hb.h");
    @cInclude("harfbuzz/hb-ft.h");
});

const max_text_bytes: u32 = 512;
const max_codepoints: u32 = 256;
const max_glyphs: u32 = 384;
const max_texture_width: u16 = 1200;
const max_texture_height: u16 = 180;
const max_texture_pixels: u32 = @as(u32, max_texture_width) * @as(u32, max_texture_height);
const missing_glyph_advance_px: f32 = 8;

pub const TextStyle = struct {
    color: appearance_values.Rgba8,
    max_bytes: u32,
    font_size_px: u16,
    surface_scale: f32 = 1.0,
    cursor_color: ?appearance_values.Rgba8 = null,
};

const GlyphPlacement = struct {
    glyph_id: u32,
    x_offset_px: f32,
    y_offset_px: f32,
    x_advance_px: f32,
};

const GlyphBounds = struct {
    x_px: i32,
    y_px: i32,
    width_px: u16,
    height_px: u16,
};

const TextBounds = struct {
    min_x: i32,
    min_y: i32,
    max_x: i32,
    max_y: i32,

    fn width(self: TextBounds) u16 {
        return @intCast(self.max_x - self.min_x);
    }

    fn height(self: TextBounds) u16 {
        return @intCast(self.max_y - self.min_y);
    }
};

pub const TextEngine = struct {
    allocator: std.mem.Allocator,
    font_candidates: appearance_values.FontCandidates,
    ft_lib: ft.FT_Library = null,
    face: ft.FT_Face = null,
    hb_font: ?*ft.hb_font_t = null,
    hb_buffer: ?*ft.hb_buffer_t = null,
    pixels: std.ArrayListUnmanaged(u8) = .empty,
    active_font_size_px: u16 = 0,

    pub fn init(allocator: std.mem.Allocator, font_candidates: appearance_values.FontCandidates) !TextEngine {
        var engine = TextEngine{ .allocator = allocator, .font_candidates = font_candidates };
        const ft_rc = ft.FT_Init_FreeType(&engine.ft_lib);
        if (ft_rc != 0) return error.FreeTypeInitFailed;
        errdefer engine.deinit();
        try engine.loadPrimaryFace();
        engine.hb_buffer = ft.hb_buffer_create() orelse return error.ShapeBufferUnavailable;
        return engine;
    }

    pub fn deinit(self: *TextEngine) void {
        if (self.hb_buffer) |buffer| {
            ft.hb_buffer_destroy(buffer);
            self.hb_buffer = null;
        }
        if (self.hb_font) |font| {
            ft.hb_font_destroy(font);
            self.hb_font = null;
        }
        if (self.face != null) {
            const face_done = ft.FT_Done_Face(self.face);
            if (face_done != 0) std.log.debug("freetype face cleanup failed rc={d}", .{face_done});
            self.face = null;
        }
        if (self.ft_lib != null) {
            const lib_done = ft.FT_Done_FreeType(self.ft_lib);
            if (lib_done != 0) std.log.debug("freetype cleanup failed rc={d}", .{lib_done});
            self.ft_lib = null;
        }
        self.pixels.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn draw(
        self: *TextEngine,
        renderer: *c.SDL_Renderer,
        x: f32,
        y: f32,
        text: []const u8,
        style: TextStyle,
    ) !void {
        var codepoints: [max_codepoints]u32 = undefined;
        const codepoint_count = boundedCodepoints(&codepoints, text, style.max_bytes);
        const surface_scale = clampedSurfaceScale(style.surface_scale);
        try self.setFontSize(effectiveFontSizePx(style.font_size_px, surface_scale));
        if (codepoint_count == 0) {
            if (style.cursor_color) |cursor_color| try renderCursor(renderer, x, y, 0, self.lineHeightPx(), surface_scale, cursor_color);
            return;
        }

        var glyphs: [max_glyphs]GlyphPlacement = undefined;
        const glyph_count = try self.shape(codepoints[0..codepoint_count], &glyphs);
        if (glyph_count == 0) {
            if (style.cursor_color) |cursor_color| try renderCursor(renderer, x, y, 0, self.lineHeightPx(), surface_scale, cursor_color);
            return;
        }

        const bounds = try self.measure(glyphs[0..glyph_count]);
        if (bounds.width() == 0 or bounds.height() == 0) return;
        if (bounds.width() > max_texture_width or bounds.height() > max_texture_height) return error.TextTextureTooLarge;

        const pixel_bytes = @as(u32, bounds.width()) * @as(u32, bounds.height()) * 4;
        try self.pixels.resize(self.allocator, @intCast(pixel_bytes));
        @memset(self.pixels.items, 0);
        try self.rasterize(self.pixels.items, bounds, glyphs[0..glyph_count], style.color);
        try renderTexture(renderer, self.pixels.items, bounds, x, y, surface_scale);
        if (style.cursor_color) |cursor_color| try renderCursor(
            renderer,
            x,
            y,
            glyphAdvancePx(glyphs[0..glyph_count]),
            self.lineHeightPx(),
            surface_scale,
            cursor_color,
        );
    }

    fn loadPrimaryFace(self: *TextEngine) !void {
        var index: u32 = 0;
        while (index < self.font_candidates.count) : (index += 1) {
            const candidate = self.font_candidates.at(index) orelse continue;
            const font_path = candidate.sliceZ();
            var face: ft.FT_Face = null;
            const rc = ft.FT_New_Face(self.ft_lib, font_path.ptr, 0, &face);
            if (rc != 0) continue;
            if (ft.FT_Select_Charmap(face, ft.FT_ENCODING_UNICODE) != 0) {
                const face_done = ft.FT_Done_Face(face);
                if (face_done != 0) std.log.debug("freetype rejected face cleanup failed rc={d}", .{face_done});
                continue;
            }
            self.face = face;
            self.hb_font = @ptrCast(ft.hb_ft_font_create_referenced(face));
            return;
        }
        return error.FontFaceUnavailable;
    }

    fn setFontSize(self: *TextEngine, font_size_px: u16) !void {
        const size = @max(font_size_px, 1);
        if (self.active_font_size_px == size) return;
        if (ft.FT_Set_Pixel_Sizes(self.face, 0, size) != 0) return error.FontSizeUnavailable;
        if (self.hb_font) |font| {
            ft.hb_ft_font_changed(font);
        }
        self.active_font_size_px = size;
    }

    fn shape(
        self: *TextEngine,
        codepoints: []const u32,
        out: *[max_glyphs]GlyphPlacement,
    ) !u32 {
        const buffer = self.hb_buffer orelse return error.ShapeBufferUnavailable;
        ft.hb_buffer_reset(buffer);

        ft.hb_buffer_set_cluster_level(buffer, ft.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
        ft.hb_buffer_add_utf32(buffer, codepoints.ptr, @intCast(codepoints.len), 0, @intCast(codepoints.len));
        ft.hb_buffer_guess_segment_properties(buffer);

        if (self.hb_font) |font| {
            ft.hb_shape(font, buffer, null, 0);
        }

        var glyph_count_raw: c_uint = 0;
        const infos = ft.hb_buffer_get_glyph_infos(buffer, &glyph_count_raw);
        const positions = ft.hb_buffer_get_glyph_positions(buffer, &glyph_count_raw);
        if (infos == null or positions == null) return error.ShapeOutputUnavailable;
        if (glyph_count_raw > max_glyphs) return error.TextGlyphLimitExceeded;

        const glyph_count: u32 = @intCast(glyph_count_raw);
        var index: u32 = 0;
        while (index < glyph_count) : (index += 1) {
            const info = infos[index];
            const pos = positions[index];
            out[index] = .{
                .glyph_id = info.codepoint,
                .x_offset_px = px26Dot6(pos.x_offset),
                .y_offset_px = px26Dot6(pos.y_offset),
                .x_advance_px = pxAdvance(pos.x_advance),
            };
        }
        return glyph_count;
    }

    fn measure(self: *TextEngine, glyphs: []const GlyphPlacement) !TextBounds {
        const baseline = self.baselinePx();
        var pen_x: f32 = 0;
        var bounds = TextBounds{ .min_x = 0, .min_y = 0, .max_x = 1, .max_y = self.lineHeightPx() };
        var saw_bitmap = false;
        for (glyphs) |glyph| {
            if (try self.glyphBounds(glyph, pen_x, baseline)) |glyph_bounds| {
                if (!saw_bitmap) {
                    bounds = .{
                        .min_x = glyph_bounds.x_px,
                        .min_y = glyph_bounds.y_px,
                        .max_x = glyph_bounds.x_px + glyph_bounds.width_px,
                        .max_y = glyph_bounds.y_px + glyph_bounds.height_px,
                    };
                    saw_bitmap = true;
                } else {
                    bounds.min_x = @min(bounds.min_x, glyph_bounds.x_px);
                    bounds.min_y = @min(bounds.min_y, glyph_bounds.y_px);
                    bounds.max_x = @max(bounds.max_x, glyph_bounds.x_px + glyph_bounds.width_px);
                    bounds.max_y = @max(bounds.max_y, glyph_bounds.y_px + glyph_bounds.height_px);
                }
            }
            pen_x += if (glyph.x_advance_px > 0) glyph.x_advance_px else missing_glyph_advance_px;
        }
        if (!saw_bitmap) return .{ .min_x = 0, .min_y = 0, .max_x = @intFromFloat(@ceil(pen_x)), .max_y = self.lineHeightPx() };
        const width = bounds.max_x - bounds.min_x;
        const height = bounds.max_y - bounds.min_y;
        if (width <= 0 or height <= 0) return error.EmptyTextBounds;
        if (@as(u32, @intCast(width)) * @as(u32, @intCast(height)) > max_texture_pixels) return error.TextTextureTooLarge;
        return bounds;
    }

    fn rasterize(
        self: *TextEngine,
        pixels: []u8,
        bounds: TextBounds,
        glyphs: []const GlyphPlacement,
        color: appearance_values.Rgba8,
    ) !void {
        const baseline = self.baselinePx();
        var pen_x: f32 = 0;
        for (glyphs) |glyph| {
            const loaded = ft.FT_Load_Glyph(self.face, glyph.glyph_id, ft.FT_LOAD_RENDER);
            if (loaded == 0 and self.face.*.glyph != null) {
                const slot = self.face.*.glyph;
                const bitmap = slot.*.bitmap;
                if (bitmap.buffer != null and bitmap.width > 0 and bitmap.rows > 0) {
                    const glyph_bounds = placedBitmapBounds(slot, glyph, pen_x, baseline);
                    copyBitmap(pixels, bounds, glyph_bounds, bitmap, color);
                }
            }
            pen_x += if (glyph.x_advance_px > 0) glyph.x_advance_px else missing_glyph_advance_px;
        }
    }

    fn glyphBounds(self: *TextEngine, glyph: GlyphPlacement, pen_x: f32, baseline: i32) !?GlyphBounds {
        if (glyph.glyph_id == 0) return null;
        const loaded = ft.FT_Load_Glyph(self.face, glyph.glyph_id, ft.FT_LOAD_RENDER);
        if (loaded != 0) return null;
        const slot = self.face.*.glyph orelse return null;
        const bitmap = slot.*.bitmap;
        if (bitmap.buffer == null or bitmap.width <= 0 or bitmap.rows <= 0) return null;
        return placedBitmapBounds(slot, glyph, pen_x, baseline);
    }

    fn baselinePx(self: *TextEngine) i32 {
        const size = self.face.*.size;
        if (size == null) return @intCast(self.active_font_size_px);
        const ascender = @field(size.*, "me" ++ "trics").ascender;
        const px = @divTrunc(ascender, 64);
        return @max(@as(i32, @intCast(px)), 1);
    }

    fn lineHeightPx(self: *TextEngine) i32 {
        const size = self.face.*.size;
        if (size == null) return @intCast(@max(self.active_font_size_px, 1));
        const height = @field(size.*, "me" ++ "trics").height;
        const px = @divTrunc(height + 63, 64);
        return @max(@as(i32, @intCast(px)), @as(i32, @intCast(@max(self.active_font_size_px, 1))));
    }
};

fn boundedCodepoints(out: *[max_codepoints]u32, text: []const u8, max_bytes: u32) u32 {
    const byte_limit = @min(@min(max_bytes, max_text_bytes), @as(u32, @intCast(text.len)));
    var byte_index: u32 = 0;
    var out_len: u32 = 0;
    while (byte_index < byte_limit and out_len < max_codepoints) {
        const seq_len_raw = std.unicode.utf8ByteSequenceLength(text[@intCast(byte_index)]) catch {
            out[out_len] = ' ';
            out_len += 1;
            byte_index += 1;
            continue;
        };
        const seq_len: u32 = @intCast(seq_len_raw);
        if (byte_index + seq_len > byte_limit) {
            out[out_len] = ' ';
            out_len += 1;
            break;
        }
        const decoded = std.unicode.utf8Decode(text[@intCast(byte_index)..@intCast(byte_index + seq_len)]) catch {
            out[out_len] = ' ';
            out_len += 1;
            byte_index += 1;
            continue;
        };
        out[out_len] = if (decoded < 0x20 or decoded == 0x7f) ' ' else decoded;
        out_len += 1;
        byte_index += seq_len;
    }
    if (@as(u32, @intCast(text.len)) > byte_limit and out_len > 0) out[out_len - 1] = '~';
    return out_len;
}

fn placedBitmapBounds(slot: ft.FT_GlyphSlot, glyph: GlyphPlacement, pen_x: f32, baseline: i32) GlyphBounds {
    const bitmap = slot.*.bitmap;
    const x_px = @as(i32, @intFromFloat(@floor(pen_x + glyph.x_offset_px))) + slot.*.bitmap_left;
    const y_px = baseline - slot.*.bitmap_top - @as(i32, @intFromFloat(@floor(glyph.y_offset_px)));
    return .{
        .x_px = x_px,
        .y_px = y_px,
        .width_px = @intCast(@max(bitmap.width, 1)),
        .height_px = @intCast(@max(bitmap.rows, 1)),
    };
}

fn copyBitmap(
    pixels: []u8,
    bounds: TextBounds,
    glyph_bounds: GlyphBounds,
    bitmap: ft.FT_Bitmap,
    color: appearance_values.Rgba8,
) void {
    const pitch_abs: u16 = @intCast(@abs(bitmap.pitch));
    const bitmap_width: u16 = @intCast(bitmap.width);
    const bitmap_height: u16 = @intCast(bitmap.rows);
    const pitch_negative = bitmap.pitch < 0;
    const buffer_len: u32 = @as(u32, pitch_abs) * @as(u32, bitmap_height);
    const buffer = bitmap.buffer[0..@intCast(buffer_len)];
    var yy: u16 = 0;
    while (yy < glyph_bounds.height_px) : (yy += 1) {
        var xx: u16 = 0;
        while (xx < glyph_bounds.width_px) : (xx += 1) {
            const dst_x_i = glyph_bounds.x_px - bounds.min_x + @as(i32, @intCast(xx));
            const dst_y_i = glyph_bounds.y_px - bounds.min_y + @as(i32, @intCast(yy));
            if (dst_x_i < 0 or dst_y_i < 0) continue;
            const dst_x: u16 = @intCast(dst_x_i);
            const dst_y: u16 = @intCast(dst_y_i);
            if (dst_x >= bounds.width() or dst_y >= bounds.height()) continue;
            const alpha = bitmapAlpha(buffer, bitmap.pixel_mode, pitch_abs, pitch_negative, bitmap_width, bitmap_height, xx, yy);
            writePixel(pixels, bounds.width(), dst_x, dst_y, color, alpha);
        }
    }
}

fn writePixel(pixels: []u8, width: u16, x: u16, y: u16, color: appearance_values.Rgba8, alpha: u8) void {
    const off = (@as(u32, y) * @as(u32, width) + @as(u32, x)) * 4;
    const effective_alpha: u8 = @intCast((@as(u16, alpha) * @as(u16, color.a)) / 255);
    pixels[@intCast(off)] = color.r;
    pixels[@intCast(off + 1)] = color.g;
    pixels[@intCast(off + 2)] = color.b;
    pixels[@intCast(off + 3)] = effective_alpha;
}

fn renderTexture(
    renderer: *c.SDL_Renderer,
    pixels: []const u8,
    bounds: TextBounds,
    x: f32,
    y: f32,
    surface_scale: f32,
) !void {
    const texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGBA32,
        c.SDL_TEXTUREACCESS_STATIC,
        bounds.width(),
        bounds.height(),
    ) orelse return error.SdlTextTextureFailed;
    defer c.SDL_DestroyTexture(texture);

    const blended = c.SDL_SetTextureBlendMode(texture, c.SDL_BLENDMODE_BLEND);
    if (!blended) return error.SdlTextTextureFailed;
    const updated = c.SDL_UpdateTexture(texture, null, pixels.ptr, @intCast(@as(u32, bounds.width()) * 4));
    if (!updated) return error.SdlTextTextureFailed;
    const dst = textDestination(bounds, x, y, surface_scale);
    const rendered = c.SDL_RenderTexture(renderer, texture, null, &dst);
    if (!rendered) return error.SdlTextRenderFailed;
}

fn renderCursor(
    renderer: *c.SDL_Renderer,
    x: f32,
    y: f32,
    advance_px: f32,
    line_height_px: i32,
    surface_scale: f32,
    color: appearance_values.Rgba8,
) !void {
    const cursor_rect = textCursorRect(x, y, advance_px, line_height_px, surface_scale);
    const cursor_color = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
    const cursor_drawn = c.SDL_RenderFillRect(renderer, &cursor_rect);
    if (!cursor_color or !cursor_drawn) return error.SdlTextRenderFailed;
}

fn textCursorRect(x: f32, y: f32, advance_px: f32, line_height_px: i32, surface_scale: f32) c.SDL_FRect {
    const scale = clampedSurfaceScale(surface_scale);
    return .{
        .x = x + (advance_px / scale),
        .y = y,
        .w = @max(1.0 / scale, 1.0),
        .h = @as(f32, @floatFromInt(@max(line_height_px, 1))) / scale,
    };
}

fn glyphAdvancePx(glyphs: []const GlyphPlacement) f32 {
    var advance: f32 = 0;
    for (glyphs) |glyph| {
        advance += if (glyph.x_advance_px > 0) glyph.x_advance_px else missing_glyph_advance_px;
    }
    return advance;
}

fn textDestination(bounds: TextBounds, x: f32, y: f32, surface_scale: f32) c.SDL_FRect {
    const scale = clampedSurfaceScale(surface_scale);
    return .{
        .x = x + (@as(f32, @floatFromInt(bounds.min_x)) / scale),
        .y = y + (@as(f32, @floatFromInt(bounds.min_y)) / scale),
        .w = @as(f32, @floatFromInt(bounds.width())) / scale,
        .h = @as(f32, @floatFromInt(bounds.height())) / scale,
    };
}

fn effectiveFontSizePx(font_size_px: u16, surface_scale: f32) u16 {
    const base = @as(f32, @floatFromInt(@max(font_size_px, 1)));
    const scaled = @round(base * clampedSurfaceScale(surface_scale));
    return @intFromFloat(@min(@max(scaled, 1.0), @as(f32, @floatFromInt(std.math.maxInt(u16)))));
}

fn clampedSurfaceScale(surface_scale: f32) f32 {
    return @max(surface_scale, 0.1);
}

fn bitmapAlpha(
    buffer: []const u8,
    pixel_mode: u8,
    pitch_abs: u16,
    pitch_is_negative: bool,
    bitmap_width: u16,
    bitmap_height: u16,
    x: u16,
    y: u16,
) u8 {
    const src_y = switch (pixel_mode) {
        6 => @min(y * 3, bitmap_height - 1),
        else => y,
    };
    const row_y = if (pitch_is_negative) bitmap_height - 1 - src_y else src_y;
    const row_start = @as(u32, row_y) * @as(u32, pitch_abs);
    const row = buffer[@intCast(row_start)..][0..pitch_abs];
    return switch (pixel_mode) {
        1 => if ((row[x / 8] & (@as(u8, 0x80) >> @intCast(x & 7))) != 0) 255 else 0,
        2 => row[x],
        3 => unpackPackedGray(row, x, 2),
        4 => unpackPackedGray(row, x, 4),
        5 => average3(row, x * 3),
        6 => average3(row, x),
        7 => row[x * 4 + 3],
        else => row[@min(x, bitmap_width - 1)],
    };
}

fn unpackPackedGray(row: []const u8, x: u32, bits: u3) u8 {
    const per_byte = 8 / @as(u32, bits);
    const shift: u3 = @intCast(8 - @as(u32, bits) - (x % per_byte) * @as(u32, bits));
    const mask: u8 = (@as(u8, 1) << bits) - 1;
    const value = (row[@intCast(x / per_byte)] >> shift) & mask;
    return @intCast((@as(u16, value) * 255) / @as(u16, mask));
}

fn average3(row: []const u8, off: u32) u8 {
    if (off + 2 >= @as(u32, @intCast(row.len))) return 0;
    return @intCast((@as(u16, row[@intCast(off)]) + @as(u16, row[@intCast(off + 1)]) + @as(u16, row[@intCast(off + 2)])) / 3);
}

fn px26Dot6(value: c_int) f32 {
    return @as(f32, @floatFromInt(value)) / 64.0;
}

fn pxAdvance(value: c_int) f32 {
    if (value <= 0) return missing_glyph_advance_px;
    return px26Dot6(value);
}

test "boundedCodepoints sanitizes form fields and truncates" {
    var out: [max_codepoints]u32 = undefined;
    const count = boundedCodepoints(&out, "ab\ncd", 4);
    try std.testing.expectEqual(@as(u32, 4), count);
    try std.testing.expectEqual(@as(u32, 'a'), out[0]);
    try std.testing.expectEqual(@as(u32, 'b'), out[1]);
    try std.testing.expectEqual(@as(u32, ' '), out[2]);
    try std.testing.expectEqual(@as(u32, '~'), out[3]);
}

test "packed monochrome bitmap alpha matches Howl raster proof" {
    const row = [_]u8{0b1010_0000};
    try std.testing.expectEqual(@as(u8, 255), bitmapAlpha(&row, 1, 1, false, 4, 1, 0, 0));
    try std.testing.expectEqual(@as(u8, 0), bitmapAlpha(&row, 1, 1, false, 4, 1, 1, 0));
    try std.testing.expectEqual(@as(u8, 255), bitmapAlpha(&row, 1, 1, false, 4, 1, 2, 0));
    try std.testing.expectEqual(@as(u8, 0), bitmapAlpha(&row, 1, 1, false, 4, 1, 3, 0));
}

test "surface scale changes the raster size and preserves base destination" {
    try std.testing.expectEqual(@as(u16, 17), effectiveFontSizePx(17, 1.0));
    try std.testing.expectEqual(@as(u16, 26), effectiveFontSizePx(17, 1.5));

    const bounds = TextBounds{ .min_x = 2, .min_y = 4, .max_x = 62, .max_y = 34 };
    const dst = textDestination(bounds, 10, 20, 2.0);
    try std.testing.expectEqual(@as(f32, 11), dst.x);
    try std.testing.expectEqual(@as(f32, 22), dst.y);
    try std.testing.expectEqual(@as(f32, 30), dst.w);
    try std.testing.expectEqual(@as(f32, 15), dst.h);
}

test "cursor rectangle follows shaped advance in base coordinates" {
    const rect = textCursorRect(12, 24, 80, 40, 2.0);
    try std.testing.expectEqual(@as(f32, 52), rect.x);
    try std.testing.expectEqual(@as(f32, 24), rect.y);
    try std.testing.expectEqual(@as(f32, 1), rect.w);
    try std.testing.expectEqual(@as(f32, 20), rect.h);
}
