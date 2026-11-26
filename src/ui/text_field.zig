//! Concrete append-only search presentation. The application owns editing,
//! matching, focus and IME protocol state. This value owns only geometry;
//! committed text, placeholder/error text and preedit are frame-local borrows.
const std = @import("std");
const canvas = @import("canvas.zig");
const Canvas = canvas.Canvas;
const Painter = @import("text.zig").Painter;

pub const TextField = struct {
    bounds: canvas.Rect,

    const text_x = 3;
    const text_y = 5;
    const caret_height = 20;
    const underline_y = 27;
    const accent = [3]u8{ 130, 190, 255 };

    pub const Content = struct {
        committed: []const u8,
        display: []const u8,
        preedit: []const u8 = "",
        cursor: [2]i32 = .{ -1, -1 },
    };

    fn contentBounds(self: TextField) canvas.Rect {
        std.debug.assert(self.bounds.w >= 24 and self.bounds.h >= 30);
        return .{ .x = 9, .y = 1, .w = self.bounds.w - 20, .h = self.bounds.h - 2 };
    }

    /// The committed caret anchors candidate-window geometry. This is
    /// logical UI geometry, never a Wayland request or an editing decision.
    pub fn caret(self: TextField, painter: *Painter, committed: []const u8) !canvas.FloatRect {
        const content = self.contentBounds();
        const start: f32 = @floatFromInt(@as(i64, self.bounds.x) + content.x + text_x);
        const end: f32 = @floatFromInt(@as(i64, self.bounds.x) + content.x + content.w - 1);
        return .{
            .x = @min(end, start + try painter.width(committed)),
            .y = @floatFromInt(@as(i64, self.bounds.y) + content.y + text_y),
            .w = 1,
            .h = caret_height,
        };
    }

    fn boundary(bytes: []const u8, offset: i32) bool {
        if (offset < 0 or offset > bytes.len) return false;
        return offset == bytes.len or bytes[@intCast(offset)] & 0xc0 != 0x80;
    }

    pub fn draw(self: TextField, root: Canvas, painter: *Painter, value: Content) !void {
        const panel = try root.child(self.bounds);
        try panel.fill(.{ 30, 31, 39 });
        const content = try panel.child(self.contentBounds());
        try content.text(painter, if (value.preedit.len == 0) value.display else value.committed, .{ 235, 235, 240 }, text_x, text_y);
        if (value.preedit.len == 0) return;
        const x = text_x + try painter.width(value.committed);
        try content.text(painter, value.preedit, accent, x, text_y);
        try content.fillRect(.{ .x = x, .y = underline_y, .w = try painter.width(value.preedit), .h = 1 }, accent);
        const cursor = value.cursor;
        // The editor already checks these byte boundaries. Refuse to slice
        // malformed presentation facts too, without changing editor state.
        if (!boundary(value.preedit, cursor[0]) or !boundary(value.preedit, cursor[1])) return;
        const left = x + try painter.width(value.preedit[0..@intCast(@min(cursor[0], cursor[1]))]);
        const right = x + try painter.width(value.preedit[0..@intCast(@max(cursor[0], cursor[1]))]);
        const collapsed = left == right;
        try content.fillRect(.{ .x = left, .y = if (collapsed) text_y else underline_y + 1, .w = @max(1, right - left), .h = if (collapsed) caret_height else 2 }, accent);
    }
};

test "search presentation preserves exact committed and composition pixels at six densities" {
    const sdl = @import("sdl_c");
    const NativeSurface = @import("native_surface.zig");
    const testing = std.testing;
    const field = TextField{ .bounds = .{ .x = 8, .y = 46, .w = 704, .h = 36 } };
    // Composition offsets are bytes, not code-point indices.
    for ([_]i32{ 0, 2, 5, 8 }) |offset| try testing.expect(TextField.boundary("é漢字", offset));
    for ([_]i32{ -1, 1, 3, 4, 6, 7, 9 }) |offset| try testing.expect(!TextField.boundary("é漢字", offset));
    const Reference = struct {
        fn draw(renderer: *sdl.SDL_Renderer, painter: *Painter, value: TextField.Content) !void {
            const panel: sdl.SDL_FRect = .{ .x = 8, .y = 46, .w = 704, .h = 36 };
            try testing.expect(sdl.SDL_SetRenderDrawColor(renderer, 30, 31, 39, 255));
            try testing.expect(sdl.SDL_RenderFillRect(renderer, &panel));
            const clip: sdl.SDL_Rect = .{ .x = 17, .y = 47, .w = 684, .h = 34 };
            try testing.expect(sdl.SDL_SetRenderClipRect(renderer, &clip));
            try painter.draw(if (value.preedit.len == 0) value.display else value.committed, .{ 235, 235, 240 }, 20, 52);
            if (value.preedit.len != 0) {
                const x = 20 + try painter.width(value.committed);
                try painter.draw(value.preedit, .{ 130, 190, 255 }, x, 52);
                const underline: sdl.SDL_FRect = .{ .x = x, .y = 74, .w = try painter.width(value.preedit), .h = 1 };
                try testing.expect(sdl.SDL_SetRenderDrawColor(renderer, 130, 190, 255, 255));
                try testing.expect(sdl.SDL_RenderFillRect(renderer, &underline));
                const cursor = value.cursor;
                if (cursor[0] >= 0 and cursor[1] >= 0 and cursor[0] <= value.preedit.len and cursor[1] <= value.preedit.len) {
                    const left = x + try painter.width(value.preedit[0..@intCast(@min(cursor[0], cursor[1]))]);
                    const right = x + try painter.width(value.preedit[0..@intCast(@max(cursor[0], cursor[1]))]);
                    const marker: sdl.SDL_FRect = .{ .x = left, .y = if (left == right) 52 else 75, .w = @max(1, right - left), .h = if (left == right) 20 else 2 };
                    try testing.expect(sdl.SDL_RenderFillRect(renderer, &marker));
                }
            }
            try testing.expect(sdl.SDL_SetRenderClipRect(renderer, null));
        }

        fn paint(frame: NativeSurface.Frame, cases: []const TextField.Content, expected_frames: []u8, direct: bool) !void {
            const target = sdl.SDL_CreateSurfaceFrom(@intCast(frame.extent.width), @intCast(frame.extent.height), sdl.SDL_PIXELFORMAT_XRGB8888, frame.pixels.ptr, @intCast(frame.stride)) orelse return error.SdlTestSurface;
            defer sdl.SDL_DestroySurface(target);
            const renderer = sdl.SDL_CreateSoftwareRenderer(target) orelse return error.SdlTestRenderer;
            defer sdl.SDL_DestroyRenderer(renderer);
            try testing.expect(sdl.SDL_SetRenderLogicalPresentation(renderer, 720, 520, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX));
            const scale = @min(@as(f32, @floatFromInt(frame.extent.width)) / 720, @as(f32, @floatFromInt(frame.extent.height)) / 520);
            var painter = try Painter.initScaled(testing.allocator, renderer, 16, scale);
            defer painter.deinit();
            const root = try Canvas.root(renderer, 720, 520);
            for (cases, 0..) |value, index| {
                try testing.expect(sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255));
                try testing.expect(sdl.SDL_RenderClear(renderer));
                if (direct) try draw(renderer, &painter, value) else try field.draw(root, &painter, value);
                try testing.expect(!sdl.SDL_RenderClipEnabled(renderer));
                try testing.expect(sdl.SDL_FlushRenderer(renderer));
                // The caller compares each frame, not merely the final draw.
                if (direct) {
                    @memcpy(expected_frames[index * frame.pixels.len ..][0..frame.pixels.len], frame.pixels);
                } else {
                    try testing.expectEqualSlices(u8, expected_frames[index * frame.pixels.len ..][0..frame.pixels.len], frame.pixels);
                }
                const caret = try field.caret(&painter, value.committed);
                try testing.expectEqual(@as(f32, @min(700, 20 + try painter.width(value.committed))), caret.x);
                try testing.expectEqual(@as(f32, 52), caret.y);
                try testing.expectEqual(@as(f32, 1), caret.w);
                try testing.expectEqual(@as(f32, 20), caret.h);
            }
        }
    };
    const long: [180]u8 = @splat('W');
    const cases = [_]TextField.Content{
        .{ .committed = "", .display = "Search applications   ·   Tab: windows" },
        .{ .committed = "", .display = "Windows unavailable: Backend error  ·  Tab: applications" },
        .{ .committed = "aéλ漢", .display = "aéλ漢" },
        .{ .committed = &long, .display = &long },
        .{ .committed = "abc", .display = "ignored", .preedit = "é漢字" },
        .{ .committed = "aé", .display = "ignored", .preedit = "é漢字", .cursor = .{ 2, 2 } },
        .{ .committed = "Wλ", .display = "ignored", .preedit = "é漢字", .cursor = .{ 5, 2 } },
        .{ .committed = "", .display = "placeholder", .preedit = "漢字", .cursor = .{ 0, 0 } },
        .{ .committed = &long, .display = &long, .preedit = "λ", .cursor = .{ 2, 2 } },
    };
    const logical: NativeSurface.Extent = .{ .width = 720, .height = 520 };
    for ([_]u32{ 120, 150, 180, 192, 210, 240 }) |scale| {
        const scaled = try logical.scaled(scale);
        const extent: NativeSurface.Extent = .{ .width = scaled.width, .height = scaled.height + @as(u32, if (scale == 192) 7 else 0) };
        const stride = extent.width * 4;
        const pixels = try testing.allocator.alloc(u8, stride * extent.height);
        defer testing.allocator.free(pixels);
        const expected_frames = try testing.allocator.alloc(u8, pixels.len * cases.len);
        defer testing.allocator.free(expected_frames);
        @memset(pixels, 0x5a);
        const frame: NativeSurface.Frame = .{ .logical_extent = logical, .scale_120 = scale, .extent = extent, .stride = stride, .pixels = pixels };
        try Reference.paint(frame, &cases, expected_frames, true);
        @memset(pixels, 0x5a);
        try Reference.paint(frame, &cases, expected_frames, false);
    }
}
