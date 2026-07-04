//! Image info reads only enough header bytes to index still-image resolution.

const std = @import("std");

pub const max_header_read_bytes: u32 = 65536;

pub const Format = enum {
    png,
    bmp,
};

pub const ImageInfo = struct {
    format: Format,
    width: u32,
    height: u32,
};

pub fn readInfo(path: []const u8) !ImageInfo {
    if (!std.fs.path.isAbsolute(path)) return error.ImagePathMustBeAbsolute;
    var header: [max_header_read_bytes]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFile(std.Options.debug_io, path, &header);
    return parseHeader(bytes);
}

pub fn parseHeader(bytes: []const u8) !ImageInfo {
    if (parsePng(bytes)) |info| return info;
    if (parseBmp(bytes)) |info| return info;
    return error.UnsupportedImageFormat;
}

fn parsePng(bytes: []const u8) ?ImageInfo {
    const signature = "\x89PNG\r\n\x1a\n";
    if (bytes.len < 24) return null;
    if (!std.mem.eql(u8, bytes[0..8], signature)) return null;
    if (!std.mem.eql(u8, bytes[12..16], "IHDR")) return null;
    const width = std.mem.readInt(u32, bytes[16..20], .big);
    const height = std.mem.readInt(u32, bytes[20..24], .big);
    if (width == 0 or height == 0) return null;
    return .{ .format = .png, .width = width, .height = height };
}

fn parseBmp(bytes: []const u8) ?ImageInfo {
    if (bytes.len < 26) return null;
    if (!std.mem.eql(u8, bytes[0..2], "BM")) return null;
    const dib_size = std.mem.readInt(u32, bytes[14..18], .little);
    if (dib_size == 12) {
        const width = std.mem.readInt(u16, bytes[18..20], .little);
        const height = std.mem.readInt(u16, bytes[20..22], .little);
        if (width == 0 or height == 0) return null;
        return .{ .format = .bmp, .width = width, .height = height };
    }
    if (dib_size < 40 or bytes.len < 54) return null;
    const width_signed = std.mem.readInt(i32, bytes[18..22], .little);
    const height_signed = std.mem.readInt(i32, bytes[22..26], .little);
    if (width_signed <= 0 or height_signed == 0) return null;
    return .{
        .format = .bmp,
        .width = @intCast(width_signed),
        .height = @intCast(@abs(height_signed)),
    };
}

test "image info reads PNG dimensions from header" {
    const header =
        "\x89PNG\r\n\x1a\n" ++
        "\x00\x00\x00\x0d" ++
        "IHDR" ++
        "\x00\x00\x07\x80" ++
        "\x00\x00\x04\x38" ++
        "\x08\x02\x00\x00\x00";
    const info = try parseHeader(header);
    try std.testing.expectEqual(Format.png, info.format);
    try std.testing.expectEqual(@as(u32, 1920), info.width);
    try std.testing.expectEqual(@as(u32, 1080), info.height);
}

test "image info reads BMP dimensions from header" {
    const header =
        "BM" ++
        "\x36\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x36\x00\x00\x00" ++
        "\x28\x00\x00\x00" ++
        "\x80\x07\x00\x00" ++
        "\x38\x04\x00\x00" ++
        "\x01\x00\x18\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00" ++
        "\x00\x00\x00\x00";
    const info = try parseHeader(header);
    try std.testing.expectEqual(Format.bmp, info.format);
    try std.testing.expectEqual(@as(u32, 1920), info.width);
    try std.testing.expectEqual(@as(u32, 1080), info.height);
}

test "image info rejects unsupported headers" {
    try std.testing.expectError(error.UnsupportedImageFormat, parseHeader("not an image"));
}
