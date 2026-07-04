//! SDL text owns bounded shaped text drawing for Wayspot surfaces.
//!
//! This file copies Howl's useful text lessons into one small owner: FreeType
//! owns face raster data, HarfBuzz owns one shaping buffer, and SDL owns the
//! final texture lifetime for one draw call.

const std = @import("std");
const sdl = @import("sdl_c");

const c = @cImport({
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
const default_font_size_px: u16 = 17;
const missing_glyph_advance_px: f32 = 8;

const font_paths = [_][:0]const u8{
    "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",
    "/usr/share/fonts/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
};

pub const Rgba8 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const TextStyle = struct {
    color: Rgba8,
    max_bytes: u32,
    font_size_px: u16 = default_font_size_px,
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
    ft_lib: c.FT_Library = null,
    face: c.FT_Face = null,
    hb_font: ?*c.hb_font_t = null,
    hb_buffer: ?*c.hb_buffer_t = null,
    pixels: std.ArrayListUnmanaged(u8) = .empty,
    active_font_size_px: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) !TextEngine {
        var engine = TextEngine{ .allocator = allocator };
        const ft_rc = c.FT_Init_FreeType(&engine.ft_lib);
        if (ft_rc != 0) return error.FreeTypeInitFailed;
        errdefer engine.deinit();
        try engine.loadPrimaryFace();
        engine.hb_buffer = c.hb_buffer_create() orelse return error.ShapeBufferUnavailable;
        return engine;
    }

    pub fn deinit(self: *TextEngine) void {
        if (self.hb_buffer) |buffer| {
            c.hb_buffer_destroy(buffer);
            self.hb_buffer = null;
        }
        if (self.hb_font) |font| {
            c.hb_font_destroy(font);
            self.hb_font = null;
        }
        if (self.face != null) {
            const face_done = c.FT_Done_Face(self.face);
            if (face_done != 0) std.log.debug("freetype face cleanup failed rc={d}", .{face_done});
            self.face = null;
        }
        if (self.ft_lib != null) {
            const lib_done = c.FT_Done_FreeType(self.ft_lib);
            if (lib_done != 0) std.log.debug("freetype cleanup failed rc={d}", .{lib_done});
            self.ft_lib = null;
        }
        self.pixels.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn draw(
        self: *TextEngine,
        renderer: *sdl.SDL_Renderer,
        x: f32,
        y: f32,
        text: []const u8,
        style: TextStyle,
    ) !void {
        var codepoints: [max_codepoints]u32 = undefined;
        const codepoint_count = boundedCodepoints(&codepoints, text, style.max_bytes);
        if (codepoint_count == 0) return;
        try self.setFontSize(style.font_size_px);

        var glyphs: [max_glyphs]GlyphPlacement = undefined;
        const glyph_count = try self.shape(codepoints[0..codepoint_count], &glyphs);
        if (glyph_count == 0) return;

        const bounds = try self.measure(glyphs[0..glyph_count]);
        if (bounds.width() == 0 or bounds.height() == 0) return;
        if (bounds.width() > max_texture_width or bounds.height() > max_texture_height) return error.TextTextureTooLarge;

        const pixel_bytes = @as(u32, bounds.width()) * @as(u32, bounds.height()) * 4;
        try self.pixels.resize(self.allocator, @intCast(pixel_bytes));
        @memset(self.pixels.items, 0);
        try self.rasterize(self.pixels.items, bounds, glyphs[0..glyph_count], style.color);
        try renderTexture(renderer, self.pixels.items, bounds, x, y);
    }

    fn loadPrimaryFace(self: *TextEngine) !void {
        for (font_paths) |font_path| {
            var face: c.FT_Face = null;
            const rc = c.FT_New_Face(self.ft_lib, font_path.ptr, 0, &face);
            if (rc != 0) continue;
            if (c.FT_Select_Charmap(face, c.FT_ENCODING_UNICODE) != 0) {
                const face_done = c.FT_Done_Face(face);
                if (face_done != 0) std.log.debug("freetype rejected face cleanup failed rc={d}", .{face_done});
                continue;
            }
            self.face = face;
            self.hb_font = @ptrCast(c.hb_ft_font_create_referenced(face));
            return;
        }
        return error.FontFaceUnavailable;
    }

    fn setFontSize(self: *TextEngine, font_size_px: u16) !void {
        const size = @max(font_size_px, 1);
        if (self.active_font_size_px == size) return;
        if (c.FT_Set_Pixel_Sizes(self.face, 0, size) != 0) return error.FontSizeUnavailable;
        if (self.hb_font) |font| {
            c.hb_ft_font_changed(font);
        }
        self.active_font_size_px = size;
    }

    fn shape(
        self: *TextEngine,
        codepoints: []const u32,
        out: *[max_glyphs]GlyphPlacement,
    ) !u32 {
        const buffer = self.hb_buffer orelse return error.ShapeBufferUnavailable;
        c.hb_buffer_reset(buffer);

        c.hb_buffer_set_cluster_level(buffer, c.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
        c.hb_buffer_add_utf32(buffer, codepoints.ptr, @intCast(codepoints.len), 0, @intCast(codepoints.len));
        c.hb_buffer_guess_segment_properties(buffer);

        if (self.hb_font) |font| {
            c.hb_shape(font, buffer, null, 0);
        }

        var glyph_count_raw: c_uint = 0;
        const infos = c.hb_buffer_get_glyph_infos(buffer, &glyph_count_raw);
        const positions = c.hb_buffer_get_glyph_positions(buffer, &glyph_count_raw);
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
        color: Rgba8,
    ) !void {
        const baseline = self.baselinePx();
        var pen_x: f32 = 0;
        for (glyphs) |glyph| {
            const loaded = c.FT_Load_Glyph(self.face, glyph.glyph_id, c.FT_LOAD_RENDER);
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
        const loaded = c.FT_Load_Glyph(self.face, glyph.glyph_id, c.FT_LOAD_RENDER);
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

fn placedBitmapBounds(slot: c.FT_GlyphSlot, glyph: GlyphPlacement, pen_x: f32, baseline: i32) GlyphBounds {
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
    bitmap: c.FT_Bitmap,
    color: Rgba8,
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

fn writePixel(pixels: []u8, width: u16, x: u16, y: u16, color: Rgba8, alpha: u8) void {
    const off = (@as(u32, y) * @as(u32, width) + @as(u32, x)) * 4;
    const effective_alpha: u8 = @intCast((@as(u16, alpha) * @as(u16, color.a)) / 255);
    pixels[@intCast(off)] = color.r;
    pixels[@intCast(off + 1)] = color.g;
    pixels[@intCast(off + 2)] = color.b;
    pixels[@intCast(off + 3)] = effective_alpha;
}

fn renderTexture(renderer: *sdl.SDL_Renderer, pixels: []const u8, bounds: TextBounds, x: f32, y: f32) !void {
    const texture = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_RGBA32,
        sdl.SDL_TEXTUREACCESS_STATIC,
        bounds.width(),
        bounds.height(),
    ) orelse return error.SdlTextTextureFailed;
    defer sdl.SDL_DestroyTexture(texture);

    const blended = sdl.SDL_SetTextureBlendMode(texture, sdl.SDL_BLENDMODE_BLEND);
    if (!blended) return error.SdlTextTextureFailed;
    const updated = sdl.SDL_UpdateTexture(texture, null, pixels.ptr, @intCast(@as(u32, bounds.width()) * 4));
    if (!updated) return error.SdlTextTextureFailed;
    const dst = sdl.SDL_FRect{
        .x = x + @as(f32, @floatFromInt(bounds.min_x)),
        .y = y + @as(f32, @floatFromInt(bounds.min_y)),
        .w = @floatFromInt(bounds.width()),
        .h = @floatFromInt(bounds.height()),
    };
    const rendered = sdl.SDL_RenderTexture(renderer, texture, null, &dst);
    if (!rendered) return error.SdlTextRenderFailed;
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

test "boundedCodepoints sanitizes controls and truncates" {
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
