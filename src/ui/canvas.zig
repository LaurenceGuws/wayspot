//! A frame-local spatial view of one borrowed CPU drawing destination.
//! Children compose logical coordinates and clipping by value: no allocation,
//! pixel storage, owning links or retained drawing commands. The presenter
//! owns the renderer, logical scale and lifetime. Text retains its own cache.
const std = @import("std");
const sdl = @import("sdl_c");
const Painter = @import("text.zig").Painter;

pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32,
    h: i32,

    fn validate(self: Rect) !void {
        if (self.w < 0 or self.h < 0) return error.InvalidCanvasGeometry;
        _ = try coordinate(self.x, self.w);
        _ = try coordinate(self.y, self.h);
    }

    fn intersect(a: Rect, b: Rect) ?Rect {
        const left = @max(a.x, b.x);
        const top = @max(a.y, b.y);
        const right = @min(a.x + a.w, b.x + b.w);
        const bottom = @min(a.y + a.h, b.y + b.h);
        if (right <= left or bottom <= top) return null;
        return .{ .x = left, .y = top, .w = right - left, .h = bottom - top };
    }

    /// Half-open logical hit testing. Invalid/non-finite pointer facts miss.
    pub fn contains(self: Rect, x: f32, y: f32) bool {
        if (self.w <= 0 or self.h <= 0) return false;
        return x >= @as(f32, @floatFromInt(self.x)) and x < @as(f32, @floatFromInt(@as(i64, self.x) + self.w)) and
            y >= @as(f32, @floatFromInt(self.y)) and y < @as(f32, @floatFromInt(@as(i64, self.y) + self.h));
    }

    fn drawingRect(self: Rect) sdl.SDL_FRect {
        return .{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y), .w = @floatFromInt(self.w), .h = @floatFromInt(self.h) };
    }

    fn native(self: Rect) sdl.SDL_Rect {
        return .{ .x = self.x, .y = self.y, .w = self.w, .h = self.h };
    }
};

fn coordinate(origin: i32, offset: i32) !i32 {
    return std.math.add(i32, origin, offset) catch error.InvalidCanvasGeometry;
}

pub const Canvas = struct {
    renderer: *sdl.SDL_Renderer,
    // Both are root-logical coordinates. Clipping must never shift the
    // requested origin: a partially visible child still lays out locally.
    bounds: Rect,
    clip: ?Rect,

    /// The caller has selected a logical render target. Neither this value
    /// nor any child can outlive that target or change its scale/viewport.
    pub fn root(renderer: *sdl.SDL_Renderer, width: u16, height: u16) !Canvas {
        if (width == 0 or height == 0) return error.InvalidCanvasGeometry;
        const bounds: Rect = .{ .w = width, .h = height };
        return .{ .renderer = renderer, .bounds = bounds, .clip = bounds };
    }

    /// Compose another local coordinate space, with all ancestor clips.
    /// Zero-sized and wholly clipped children are harmless empty views.
    pub fn child(self: Canvas, local: Rect) !Canvas {
        try local.validate();
        const bounds: Rect = .{
            .x = try coordinate(self.bounds.x, local.x),
            .y = try coordinate(self.bounds.y, local.y),
            .w = local.w,
            .h = local.h,
        };
        try bounds.validate();
        return .{
            .renderer = self.renderer,
            .bounds = bounds,
            .clip = if (self.clip) |clip| clip.intersect(bounds) else null,
        };
    }

    // SDL clip state is shared, unlike a Canvas value. Every operation scopes
    // it explicitly, honors an already-active caller clip and restores it
    // on success or drawing failure. No callback or nested event loop.
    const ClipScope = struct {
        renderer: *sdl.SDL_Renderer,
        previous: ?sdl.SDL_Rect,

        fn restore(self: ClipScope) !void {
            if (!sdl.SDL_SetRenderClipRect(self.renderer, if (self.previous) |*rect| rect else null)) return error.SdlClipFailed;
        }
    };

    fn beginClip(self: Canvas) !?ClipScope {
        var clip = self.clip orelse return null;
        var scope: ClipScope = .{ .renderer = self.renderer, .previous = null };
        if (sdl.SDL_RenderClipEnabled(self.renderer)) {
            var previous: sdl.SDL_Rect = undefined;
            if (!sdl.SDL_GetRenderClipRect(self.renderer, &previous)) return error.SdlClipFailed;
            scope.previous = previous;
            const bounds: Rect = .{ .x = previous.x, .y = previous.y, .w = previous.w, .h = previous.h };
            try bounds.validate();
            clip = clip.intersect(bounds) orelse return null;
        }
        const rect = clip.native();
        if (!sdl.SDL_SetRenderClipRect(self.renderer, &rect)) return error.SdlClipFailed;
        return scope;
    }

    /// Fill the view's requested rectangle. An unclipped shape needs no
    /// extra SDL scissor: the renderer already honors the ambient clip.
    pub fn fill(self: Canvas, color: [3]u8) !void {
        const clip = self.clip orelse return;
        const scope: ?ClipScope = if (std.meta.eql(clip, self.bounds)) null else (try self.beginClip()) orelse return;
        const rect = self.bounds.drawingRect();
        const ok = sdl.SDL_SetRenderDrawColor(self.renderer, color[0], color[1], color[2], 255) and
            sdl.SDL_RenderFillRect(self.renderer, &rect);
        if (scope) |owned| try owned.restore();
        if (!ok) return error.SdlDrawFailed;
    }

    /// Draw one existing texture into the requested view, preserving the
    /// original sampling geometry if an ancestor clips it. The caller
    /// retains texture ownership and supplies a texture of this renderer.
    pub fn texture(self: Canvas, image: *sdl.SDL_Texture) !void {
        const clip = self.clip orelse return;
        const scope: ?ClipScope = if (std.meta.eql(clip, self.bounds)) null else (try self.beginClip()) orelse return;
        const rect = self.bounds.drawingRect();
        const ok = sdl.SDL_RenderTexture(self.renderer, image, null, &rect);
        if (scope) |owned| try owned.restore();
        if (!ok) return error.SdlDrawFailed;
    }

    /// Coordinates are relative to this view, not its clipped intersection.
    pub fn text(self: Canvas, painter: *Painter, bytes: []const u8, color: [3]u8, x: i32, y: i32) !void {
        std.debug.assert(painter.renderer == self.renderer);
        if (self.clip == null or bytes.len == 0) return;
        const left = try coordinate(self.bounds.x, x);
        const top = try coordinate(self.bounds.y, y);
        const scope = (try self.beginClip()) orelse return;
        const result = painter.draw(bytes, color, @floatFromInt(left), @floatFromInt(top));
        try scope.restore();
        try result;
    }

    /// Wrap dimensions are explicit logical text limits, independent of the
    /// inherited clip. Clipping never changes line breaks or text placement.
    pub fn wrappedText(self: Canvas, painter: *Painter, bytes: []const u8, color: [3]u8, x: i32, y: i32, width: u16, height: u16) !void {
        std.debug.assert(painter.renderer == self.renderer);
        if (self.clip == null or bytes.len == 0 or width == 0 or height == 0) return;
        const left = try coordinate(self.bounds.x, x);
        const top = try coordinate(self.bounds.y, y);
        const scope = (try self.beginClip()) orelse return;
        const result = painter.drawWrapped(bytes, color, @floatFromInt(left), @floatFromInt(top), width, height);
        try scope.restore();
        try result;
    }
};

test "nested canvas preserves local origin and intersects every ancestor" {
    // Spatial composition requires no renderer call or allocation.
    const root = try Canvas.root(undefined, 100, 60);
    const panel = try root.child(.{ .x = 10, .y = 8, .w = 40, .h = 30 });
    const row = try panel.child(.{ .x = -4, .y = 20, .w = 30, .h = 20 });
    try std.testing.expectEqual(Rect{ .x = 6, .y = 28, .w = 30, .h = 20 }, row.bounds);
    try std.testing.expectEqual(@as(?Rect, .{ .x = 10, .y = 28, .w = 26, .h = 10 }), row.clip);
    const nested = try row.child(.{ .x = 0, .y = 0, .w = 8, .h = 8 });
    try std.testing.expectEqual(@as(?Rect, .{ .x = 10, .y = 28, .w = 4, .h = 8 }), nested.clip);
    const outside = try panel.child(.{ .x = 45, .w = 10, .h = 10 });
    try std.testing.expect(outside.clip == null);
    try std.testing.expect((try outside.child(.{ .x = -45, .w = 10, .h = 10 })).clip == null);
    try std.testing.expect((try panel.child(.{ .w = 0, .h = 10 })).clip == null);
    try std.testing.expectError(error.InvalidCanvasGeometry, panel.child(.{ .w = -1, .h = 2 }));
    try std.testing.expectError(error.InvalidCanvasGeometry, panel.child(.{ .x = std.math.maxInt(i32), .w = 1, .h = 1 }));
    try std.testing.expectError(error.InvalidCanvasGeometry, panel.child(.{ .x = std.math.maxInt(i32) - 1, .w = 1, .h = 1 }));
    try std.testing.expectError(error.InvalidCanvasGeometry, Canvas.root(undefined, 0, 1));
    try std.testing.expectEqual(@as(?Rect, panel.bounds), panel.clip);
}

test "canvas text honors ambient clip and restores it even on invalid UTF8" {
    const surface = sdl.SDL_CreateSurface(120, 60, sdl.SDL_PIXELFORMAT_XRGB8888) orelse return error.SdlTestSurface;
    defer sdl.SDL_DestroySurface(surface);
    const renderer = sdl.SDL_CreateSoftwareRenderer(surface) orelse return error.SdlTestRenderer;
    defer sdl.SDL_DestroyRenderer(renderer);
    var painter = try Painter.init(std.testing.allocator, renderer, 16);
    defer painter.deinit();
    const root = try Canvas.root(renderer, 120, 60);
    const parent = try root.child(.{ .x = 12, .y = 12, .w = 16, .h = 16 });
    const pane = try parent.child(.{ .x = -4, .y = -2, .w = 80, .h = 20 });
    const original: sdl.SDL_Rect = .{ .x = 16, .y = 12, .w = 14, .h = 16 };
    try std.testing.expect(sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255));
    try std.testing.expect(sdl.SDL_RenderClear(renderer));
    try std.testing.expect(sdl.SDL_SetRenderClipRect(renderer, &original));
    try pane.text(&painter, "MMMMMMMMMMMMMM", .{ 255, 255, 255 }, 0, 0);
    var actual: sdl.SDL_Rect = undefined;
    try std.testing.expect(sdl.SDL_GetRenderClipRect(renderer, &actual));
    try std.testing.expectEqualDeep(original, actual);
    try std.testing.expectError(error.Utf8ExpectedContinuation, pane.text(&painter, &.{ 0xc3, 'z' }, .{ 255, 255, 255 }, 0, 0));
    try std.testing.expect(sdl.SDL_RenderClipEnabled(renderer));
    try std.testing.expect(sdl.SDL_GetRenderClipRect(renderer, &actual));
    try std.testing.expectEqualDeep(original, actual);
    try std.testing.expect(sdl.SDL_SetRenderClipRect(renderer, null));
    try std.testing.expectError(error.Utf8ExpectedContinuation, pane.text(&painter, &.{ 0xc3, 'z' }, .{ 255, 255, 255 }, 0, 0));
    try std.testing.expect(!sdl.SDL_RenderClipEnabled(renderer));
    const invisible = try root.child(.{ .x = 121, .w = 10, .h = 10 });
    // A clipped-away subtree cannot touch a text resource or clip state.
    try invisible.text(&painter, &.{ 0xc3, 'z' }, .{ 255, 255, 255 }, 0, 0);
    try std.testing.expect(!sdl.SDL_RenderClipEnabled(renderer));
    try std.testing.expect(sdl.SDL_FlushRenderer(renderer));
    const pixels: [*]const u32 = @ptrCast(@alignCast(surface.*.pixels orelse return error.SdlTestPixels));
    const stride: usize = @intCast(@divExact(surface.*.pitch, 4));
    var visible: usize = 0;
    for (0..60) |y| {
        for (0..120) |x| {
            if (pixels[y * stride + x] & 0x00ffffff == 0) continue;
            try std.testing.expect(x >= 16 and x < 28 and y >= 12 and y < 28);
            visible += 1;
        }
    }
    try std.testing.expect(visible > 0);
}

test "clipped canvas shapes and textures retain original placement and caller clip" {
    const surface = sdl.SDL_CreateSurface(40, 20, sdl.SDL_PIXELFORMAT_XRGB8888) orelse return error.SdlTestSurface;
    defer sdl.SDL_DestroySurface(surface);
    const renderer = sdl.SDL_CreateSoftwareRenderer(surface) orelse return error.SdlTestRenderer;
    defer sdl.SDL_DestroyRenderer(renderer);
    var source = [_]u32{ 0xffff0000, 0xff00ff00 };
    const image = sdl.SDL_CreateSurfaceFrom(2, 1, sdl.SDL_PIXELFORMAT_ARGB8888, &source, 8) orelse return error.SdlTestSurface;
    defer sdl.SDL_DestroySurface(image);
    const texture = sdl.SDL_CreateTextureFromSurface(renderer, image) orelse return error.SdlTestTexture;
    defer sdl.SDL_DestroyTexture(texture);
    try std.testing.expect(sdl.SDL_SetTextureScaleMode(texture, sdl.SDL_SCALEMODE_NEAREST));
    try std.testing.expect(sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255));
    try std.testing.expect(sdl.SDL_RenderClear(renderer));
    const root = try Canvas.root(renderer, 40, 20);
    const parent = try root.child(.{ .x = 8, .y = 4, .w = 12, .h = 10 });
    const child = try parent.child(.{ .x = -4, .y = 2, .w = 16, .h = 8 });
    const original: sdl.SDL_Rect = .{ .x = 9, .y = 8, .w = 7, .h = 4 };
    try std.testing.expect(sdl.SDL_SetRenderClipRect(renderer, &original));
    try child.fill(.{ 9, 10, 11 });
    try std.testing.expect(sdl.SDL_FlushRenderer(renderer));
    const pixels: [*]const u32 = @ptrCast(@alignCast(surface.*.pixels orelse return error.SdlTestPixels));
    const stride: usize = @intCast(@divExact(surface.*.pitch, 4));
    for (0..20) |y| {
        for (0..40) |x| {
            const inside = x >= 9 and x < 16 and y >= 8 and y < 12;
            try std.testing.expectEqual(@as(u32, if (inside) 0x090a0b else 0), pixels[y * stride + x] & 0x00ffffff);
        }
    }
    try child.texture(texture);
    try std.testing.expect(sdl.SDL_FlushRenderer(renderer));
    for (0..20) |y| {
        for (0..40) |x| {
            const inside = x >= 9 and x < 16 and y >= 8 and y < 12;
            // The image starts at x=4, not the ancestor's clip at x=8.
            const expected: u32 = if (inside) (if (x < 12) 0xff0000 else 0x00ff00) else 0;
            try std.testing.expectEqual(expected, pixels[y * stride + x] & 0x00ffffff);
        }
    }
    var actual: sdl.SDL_Rect = undefined;
    try std.testing.expect(sdl.SDL_RenderClipEnabled(renderer));
    try std.testing.expect(sdl.SDL_GetRenderClipRect(renderer, &actual));
    try std.testing.expectEqualDeep(original, actual);
}
