const std = @import("std");
const wallpaper = @import("wallpaper.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const Native = struct {
    io: std.Io,
    file: ?std.Io.File = null,

    pub fn open(native: *Native, path: []const u8) !void {
        std.debug.assert(native.file == null);
        native.file = if (std.fs.path.isAbsolute(path))
            try std.Io.Dir.openFileAbsolute(native.io, path, .{})
        else
            try std.Io.Dir.cwd().openFile(native.io, path, .{});
    }

    pub fn stat(native: *Native) !struct { kind: std.Io.File.Kind, size: u64 } {
        const value = try (native.file orelse unreachable).stat(native.io);
        return .{ .kind = value.kind, .size = value.size };
    }

    pub fn read(native: *Native, bytes: []u8) !usize {
        return (native.file orelse unreachable).readPositionalAll(native.io, bytes, 0);
    }

    pub fn close(native: *Native) void {
        const file = native.file orelse unreachable;
        file.close(native.io);
        native.file = null;
    }

    pub fn decode(_: *Native, allocator: std.mem.Allocator, bytes: []const u8) !wallpaper.Image {
        const stream = sdl.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse return error.ImageStreamFailed;
        const decoded = sdl.SDL_LoadPNG_IO(stream, true) orelse return error.ImageDecodeFailed;
        defer sdl.SDL_DestroySurface(decoded);
        const width = try surfaceSide(decoded.*.w);
        const height = try surfaceSide(decoded.*.h);
        if (@as(u64, width) * height > wallpaper.image_pixel_capacity) return error.ImageDimensionsTooLarge;
        const pixels = try allocator.alloc(u32, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        @memset(pixels, 0xff000000);
        const normalized = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            pixels.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(normalized);
        try xrgbSurface(normalized, width, height);
        if (!sdl.SDL_BlitSurface(decoded, null, normalized, null)) return error.ImageConvertFailed;
        return .{
            .width = width,
            .height = height,
            .pitch = width * 4,
            .pixels = pixels,
        };
    }

    pub fn scale(
        _: *Native,
        image: *const wallpaper.Image,
        crop: wallpaper.Crop,
        width: u32,
        height: u32,
        output: []u32,
    ) !void {
        const source = sdl.SDL_CreateSurfaceFrom(
            @intCast(image.width),
            @intCast(image.height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            @constCast(image.pixels.ptr),
            @intCast(image.pitch),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(source);
        const target = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            output.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(target);
        try xrgbSurface(source, image.width, image.height);
        try xrgbSurface(target, width, height);
        const source_rect = rect(crop.x, crop.y, crop.width, crop.height);
        const target_rect = rect(0, 0, width, height);
        if (!sdl.SDL_BlitSurfaceScaled(source, &source_rect, target, &target_rect, sdl.SDL_SCALEMODE_LINEAR)) {
            return error.ImageScaleFailed;
        }
    }
};

fn surfaceSide(value: c_int) !u32 {
    if (value <= 0) return error.ImageDimensionsZero;
    if (value > wallpaper.image_side_capacity) return error.ImageDimensionsTooLarge;
    return @intCast(value);
}

fn xrgbSurface(surface: *sdl.SDL_Surface, width: u32, height: u32) !void {
    if (surface.*.format != sdl.SDL_PIXELFORMAT_XRGB8888 or surface.*.w != width or
        surface.*.h != height or surface.*.pitch != width * 4 or surface.*.pixels == null)
    {
        return error.ImageFormatInvalid;
    }
}

fn rect(x: u32, y: u32, width: u32, height: u32) sdl.SDL_Rect {
    return .{ .x = @intCast(x), .y = @intCast(y), .w = @intCast(width), .h = @intCast(height) };
}

test "native PNG file decode and linear cover scaling" {
    const png =
        "\x89PNG\r\n\x1a\n" ++
        "\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89" ++
        "\x00\x00\x00\x0dIDAT\x78\x9c\x63\xf8\xcf\xc0\xd0\x00\x00\x04\x81\x01\x80\x2c\x55\xce\xb0" ++
        "\x00\x00\x00\x00IEND\xae\x42\x60\x82";
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "one.png", .data = png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "one.png", std.testing.allocator);
    defer std.testing.allocator.free(path);

    var native = Native{ .io = std.testing.io };
    var image = try wallpaper.loadImage(&native, std.testing.allocator, path);
    defer image.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 1), image.width);
    try std.testing.expectEqual(@as(u32, 1), image.height);
    try std.testing.expectEqual(@as(u32, 0xff800000), image.pixels[0]);
    var pixels = try wallpaper.coverImage(&native, std.testing.allocator, &image, 3, 2);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 12), pixels.pitch);
    for (pixels.pixels) |pixel| try std.testing.expectEqual(@as(u32, 0xff800000), pixel);
    try std.testing.expect(native.file == null);
}

test "native malformed PNG closes its file and publishes no image" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var png: [24]u8 = @splat(0);
    @memcpy(png[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(png[12..16], "IHDR");
    std.mem.writeInt(u32, png[16..20], 1, .big);
    std.mem.writeInt(u32, png[20..24], 1, .big);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "broken.png", .data = &png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "broken.png", std.testing.allocator);
    defer std.testing.allocator.free(path);
    var native = Native{ .io = std.testing.io };
    try std.testing.expectError(
        error.ImageDecodeFailed,
        wallpaper.loadImage(&native, std.testing.allocator, path),
    );
    try std.testing.expect(native.file == null);
}

test "native unsupported IO acquires no file" {
    var native = Native{ .io = std.Io.failing };
    if (native.open("wallpaper.png")) |_| {
        return error.ExpectedOpenFailure;
    } else |_| {}
    try std.testing.expect(native.file == null);
}

test "bounded malformed PNG data publishes no partial image" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzPng, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzPng({}, &empty);
}

fn fuzzPng(_: void, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var native = Native{ .io = std.Io.failing };
    if (native.decode(std.testing.allocator, input)) |value| {
        var image = value;
        defer image.deinit(std.testing.allocator);
        try std.testing.expect(image.width > 0 and image.width <= wallpaper.image_side_capacity);
        try std.testing.expect(image.height > 0 and image.height <= wallpaper.image_side_capacity);
        try std.testing.expectEqual(@as(usize, image.width) * image.height, image.pixels.len);
    } else |_| {}
}
