//! Shapes and rasterizes Wayspot UI text with Howl Text; SDL only presents glyphs.
//! The renderer owns a bounded per-glyph texture cache, not another font engine.

const std = @import("std");
const text = @import("howl_text");
const sdl = @import("sdl_c");

const font_bytes = @embedFile("NotoSans-Regular.ttf");
const scalar_capacity = 512;
const glyph_capacity = 1024;
const texture_capacity = 192;

const CachedGlyph = struct {
    face: u8,
    id: u32,
    width: u16,
    height: u16,
    left: i16,
    top: i16,
    texture: ?*sdl.SDL_Texture,
};

/// Borrows one SDL renderer; owns the Howl Text font, shape buffer, and GPU glyphs.
pub const Painter = struct {
    allocator: std.mem.Allocator,
    renderer: *sdl.SDL_Renderer,
    font: *text.FontSet,
    shape_buffer: *text.ShapeBuffer,
    metrics: text.Metrics,
    scalars: [scalar_capacity]u32 = undefined,
    clusters: [scalar_capacity]u32 = undefined,
    glyphs: [glyph_capacity]text.Glyph = undefined,
    textures: [texture_capacity]CachedGlyph = undefined,
    texture_count: usize = 0,
    next_victim: usize = 0,

    /// Opens one embedded font set, once per visible picker/banner lifetime.
    pub fn init(allocator: std.mem.Allocator, renderer: *sdl.SDL_Renderer, font_size: u16) !Painter {
        const font = try text.FontSet.initMemory(allocator, .{
            .primary = font_bytes,
            .size = .{ .pixels = font_size },
        });
        errdefer font.deinit();
        const shape_buffer = try text.ShapeBuffer.init(allocator, glyph_capacity);
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .font = font,
            .shape_buffer = shape_buffer,
            .metrics = font.metrics(),
        };
    }

    /// Drops renderer resources before the SDL renderer, then closes font state.
    pub fn deinit(self: *Painter) void {
        self.reset();
        self.shape_buffer.deinit();
        self.font.deinit();
        self.* = undefined;
    }

    /// Invalidates textures after an SDL renderer reset, retaining font state.
    pub fn reset(self: *Painter) void {
        for (self.textures[0..self.texture_count]) |entry| {
            if (entry.texture) |texture| sdl.SDL_DestroyTexture(texture);
        }
        self.texture_count = 0;
        self.next_victim = 0;
    }

    /// Draws bounded UTF-8 with shaped advances and natural glyph bearings.
    pub fn draw(self: *Painter, bytes: []const u8, color: [3]u8, x: f32, y: f32) !void {
        if (bytes.len == 0) return;
        const run = try self.shape(bytes);
        var pen_x: i64 = 0;
        var pen_y: i64 = 0;
        for (run.glyphs) |glyph| {
            const cached = try self.cachedGlyph(run.face_index, glyph.id);
            if (cached.texture) |texture| {
                if (!sdl.SDL_SetTextureColorMod(texture, color[0], color[1], color[2])) {
                    return error.SdlTextColorFailed;
                }
                const destination = sdl.SDL_FRect{
                    .x = x + unit(pen_x + glyph.x_offset) + @as(f32, @floatFromInt(cached.left)),
                    .y = y + @as(f32, @floatFromInt(self.metrics.baseline)) -
                        @as(f32, @floatFromInt(cached.top)) - unit(pen_y + glyph.y_offset),
                    .w = @floatFromInt(cached.width),
                    .h = @floatFromInt(cached.height),
                };
                if (!sdl.SDL_RenderTexture(self.renderer, texture, null, &destination)) {
                    return error.SdlTextDrawFailed;
                }
            }
            pen_x += glyph.x_advance;
            pen_y += glyph.y_advance;
        }
    }

    /// Measures the advance of a single shaped line, without GPU access.
    pub fn width(self: *Painter, bytes: []const u8) !f32 {
        if (bytes.len == 0) return 0;
        const run = try self.shape(bytes);
        var advance: i64 = 0;
        for (run.glyphs) |glyph| advance += glyph.x_advance;
        return @max(0, unit(advance));
    }

    /// Wraps a short banner to caller-owned width and height. SDL owns clipping.
    pub fn drawWrapped(
        self: *Painter,
        bytes: []const u8,
        color: [3]u8,
        x: f32,
        y: f32,
        width_px: u16,
        height_px: u16,
    ) !void {
        if (bytes.len == 0 or width_px == 0 or height_px == 0) return;
        const step = @as(usize, self.metrics.line_height);
        if (step == 0) return error.FontLineHeightInvalid;
        var start: usize = 0;
        var line: usize = 0;
        while (start < bytes.len and line * step < height_px) : (line += 1) {
            const result = try self.nextLine(bytes, start, @floatFromInt(width_px));
            if (result.end > start) {
                try self.draw(bytes[start..result.end], color, x, y + @as(f32, @floatFromInt(line * step)));
            }
            if (result.next <= start) return error.TextWrapDidNotAdvance;
            start = result.next;
        }
    }

    const Line = struct { end: usize, next: usize };

    fn nextLine(self: *Painter, bytes: []const u8, start: usize, limit: f32) !Line {
        var cursor = start;
        var accepted = start;
        while (cursor < bytes.len) {
            if (bytes[cursor] == '\n') return .{ .end = cursor, .next = cursor + 1 };
            if (bytes[cursor] == '\r') return .{
                .end = cursor,
                .next = cursor + @as(usize, if (cursor + 1 < bytes.len and bytes[cursor + 1] == '\n') 2 else 1),
            };
            const word_start = cursor;
            while (cursor < bytes.len and bytes[cursor] != ' ' and bytes[cursor] != '\t' and
                bytes[cursor] != '\n' and bytes[cursor] != '\r')
            {
                cursor = try nextScalar(bytes, cursor);
            }
            const word_end = cursor;
            while (cursor < bytes.len and (bytes[cursor] == ' ' or bytes[cursor] == '\t')) : (cursor += 1) {}
            if (try self.width(bytes[start..word_end]) <= limit) {
                accepted = cursor;
                continue;
            }
            if (accepted > start) {
                return .{ .end = std.mem.trimEnd(u8, bytes[start..accepted], " \t").len + start, .next = accepted };
            }
            // One long word must still make progress at UTF-8 scalar boundaries.
            var end = word_start;
            while (end < word_end) {
                const next = try nextScalar(bytes, end);
                if (end > start and try self.width(bytes[start..next]) > limit) break;
                end = next;
            }
            return .{ .end = end, .next = end };
        }
        return .{ .end = std.mem.trimEnd(u8, bytes[start..cursor], " \t").len + start, .next = cursor };
    }

    fn shape(self: *Painter, bytes: []const u8) !text.Run {
        var offset: usize = 0;
        var count: usize = 0;
        // Every consumer clips to a 720px or narrower UI region. The first
        // 512 scalars are more than its visible text; bound shaping even when
        // an external desktop entry or notification supplies a huge string.
        while (offset < bytes.len and count < scalar_capacity) {
            const next = try nextScalar(bytes, offset);
            var codepoint = try std.unicode.utf8Decode(bytes[offset..next]);
            if (codepoint == '\t' or codepoint == '\n' or codepoint == '\r') codepoint = ' ';
            self.scalars[count] = codepoint;
            self.clusters[count] = @intCast(offset);
            count += 1;
            offset = next;
        }
        if (count == 0) return .{ .face_index = 0, .glyphs = &.{} };
        const input: text.Text = .{
            .codepoints = self.scalars[0..count],
            .clusters = self.clusters[0..count],
        };
        return self.font.shape(self.shape_buffer, input, &self.glyphs) catch |err| switch (err) {
            error.MissingGlyph => blk: {
                // The embedded primary font has finite coverage. Keep other
                // text visible rather than discarding an entire mixed string.
                for (self.scalars[0..count]) |*scalar| {
                    if (try self.font.faceFor(&.{scalar.*}) == null) scalar.* = '?';
                }
                break :blk try self.font.shape(self.shape_buffer, input, &self.glyphs);
            },
            else => return err,
        };
    }

    fn cachedGlyph(self: *Painter, face: u8, id: u32) !CachedGlyph {
        for (self.textures[0..self.texture_count]) |item| {
            if (item.face == face and item.id == id) return item;
        }
        var raster = try self.font.rasterize(self.allocator, face, id);
        defer raster.deinit();
        const texture: ?*sdl.SDL_Texture = if (raster.width != 0 and raster.height != 0) blk: {
            const pixels = try self.allocator.alloc(u32, raster.pixels.len);
            defer self.allocator.free(pixels);
            const rgba = std.mem.sliceAsBytes(pixels);
            for (raster.pixels, 0..) |alpha, index| {
                // SDL_PIXELFORMAT_RGBA32 is always RGBA *bytes*, independent
                // of the host's integer endianness.
                const offset = index * 4;
                rgba[offset..][0..4].* = .{ 255, 255, 255, alpha };
            }
            const surface = sdl.SDL_CreateSurfaceFrom(
                @intCast(raster.width),
                @intCast(raster.height),
                sdl.SDL_PIXELFORMAT_RGBA32,
                pixels.ptr,
                @intCast(raster.width * 4),
            ) orelse return error.SdlTextSurfaceFailed;
            defer sdl.SDL_DestroySurface(surface);
            const created = sdl.SDL_CreateTextureFromSurface(self.renderer, surface) orelse
                return error.SdlTextTextureFailed;
            errdefer sdl.SDL_DestroyTexture(created);
            if (!sdl.SDL_SetTextureBlendMode(created, sdl.SDL_BLENDMODE_BLEND)) {
                return error.SdlTextBlendFailed;
            }
            break :blk created;
        } else null;
        const result: CachedGlyph = .{
            .face = face,
            .id = id,
            .width = raster.width,
            .height = raster.height,
            .left = raster.left,
            .top = raster.top,
            .texture = texture,
        };
        if (self.texture_count < self.textures.len) {
            self.textures[self.texture_count] = result;
            self.texture_count += 1;
        } else {
            if (self.textures[self.next_victim].texture) |previous| sdl.SDL_DestroyTexture(previous);
            self.textures[self.next_victim] = result;
            self.next_victim = (self.next_victim + 1) % self.textures.len;
        }
        return result;
    }
};

fn unit(value: i64) f32 {
    return @as(f32, @floatFromInt(value)) / 64.0;
}

fn nextScalar(bytes: []const u8, offset: usize) !usize {
    const length = try std.unicode.utf8ByteSequenceLength(bytes[offset]);
    if (offset + length > bytes.len) return error.InvalidUtf8;
    _ = try std.unicode.utf8Decode(bytes[offset .. offset + length]);
    return offset + length;
}

test "Howl Text shapes embedded font and bounded Unicode without presenting" {
    const font = try text.FontSet.initMemory(std.testing.allocator, .{
        .primary = font_bytes,
        .size = .{ .pixels = 16 },
    });
    defer font.deinit();
    const shape_buffer = try text.ShapeBuffer.init(std.testing.allocator, glyph_capacity);
    defer shape_buffer.deinit();
    var painter = Painter{
        .allocator = std.testing.allocator,
        .renderer = undefined,
        .font = font,
        .shape_buffer = shape_buffer,
        .metrics = font.metrics(),
    };
    try std.testing.expectEqual(@as(f32, 0), try painter.width(""));
    try std.testing.expect(try painter.width("hello") > 0);
    try std.testing.expect(try painter.width("λ漢字") > 0);
    try std.testing.expectError(error.Utf8ExpectedContinuation, painter.width(&.{ 0xc3, 'z' }));
}

test "banner wraps at spaces, preserves Unicode scalar boundaries, and advances" {
    const font = try text.FontSet.initMemory(std.testing.allocator, .{
        .primary = font_bytes,
        .size = .{ .pixels = 16 },
    });
    defer font.deinit();
    const shape_buffer = try text.ShapeBuffer.init(std.testing.allocator, glyph_capacity);
    defer shape_buffer.deinit();
    var painter = Painter{
        .allocator = std.testing.allocator,
        .renderer = undefined,
        .font = font,
        .shape_buffer = shape_buffer,
        .metrics = font.metrics(),
    };
    const joined = "hello wide world λλ";
    const first = try painter.nextLine(joined, 0, try painter.width("hello wide"));
    try std.testing.expectEqualStrings("hello wide", joined[0..first.end]);
    const next = try painter.nextLine(joined, first.next, 500);
    try std.testing.expectEqualStrings("world λλ", joined[first.next..next.end]);
    const oversized = "λ漢字";
    const cropped = try painter.nextLine(oversized, 0, 1);
    try std.testing.expectEqualStrings("λ", oversized[0..cropped.end]);
    const crlf = "first\r\nsecond";
    const line = try painter.nextLine(crlf, 0, 500);
    try std.testing.expectEqualStrings("first", crlf[0..line.end]);
    try std.testing.expectEqual(@as(usize, 7), line.next);
    try std.testing.expectEqualStrings("second", crlf[line.next..]);
}

test "Howl glyph masks survive SDL software drawing, tinting, and renderer cache reset" {
    // A software renderer exercises the actual SDL pixel/alpha boundary without
    // stealing focus or depending on the current Hyprland desktop.
    const surface = sdl.SDL_CreateSurface(280, 80, sdl.SDL_PIXELFORMAT_RGBA32) orelse
        return error.SdlSurfaceFailed;
    defer sdl.SDL_DestroySurface(surface);
    const renderer = sdl.SDL_CreateSoftwareRenderer(surface) orelse return error.SdlRendererCreateFailed;
    defer sdl.SDL_DestroyRenderer(renderer);
    var painter = try Painter.init(std.testing.allocator, renderer, 16);
    defer painter.deinit();

    if (!sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)) return error.SdlDrawFailed;
    if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
    try painter.draw("Howl Text λ", .{ 235, 100, 50 }, 12, 12);
    const glyph_count = painter.texture_count;
    try std.testing.expect(glyph_count > 0);
    if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;

    const pixels: [*]const u8 = @ptrCast(surface.*.pixels orelse return error.SdlSurfaceNoPixels);
    var bright: usize = 0;
    for (0..@intCast(surface.*.h)) |row| {
        for (0..@intCast(surface.*.w)) |column| {
            const offset = row * @as(usize, @intCast(surface.*.pitch)) + column * 4;
            if (pixels[offset] > 30 and pixels[offset + 1] > 10) bright += 1;
        }
    }
    try std.testing.expect(bright > 25);

    try painter.draw("Howl Text λ", .{ 20, 200, 100 }, 12, 42);
    try std.testing.expectEqual(glyph_count, painter.texture_count);
    try painter.draw("", .{ 0, 0, 0 }, 0, 0);
    try std.testing.expectEqual(glyph_count, painter.texture_count);
    painter.reset();
    try std.testing.expectEqual(@as(usize, 0), painter.texture_count);
    try painter.draw("Reset", .{ 255, 255, 255 }, 12, 12);
    try std.testing.expect(painter.texture_count > 0);
}
