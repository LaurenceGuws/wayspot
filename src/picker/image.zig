//! Validates the bounded PNG bytes accepted by the picker icon decoder.

const std = @import("std");

pub const encoded_capacity = 4 * 1024 * 1024;
pub const side_capacity = 1024;
pub const decoded_capacity = side_capacity * side_capacity * 4;
const header_length = 24;
const signature = "\x89PNG\r\n\x1a\n";

pub const Rejection = enum {
    malformed,
    dimensions_too_large,
};

/// Inspect returns the exact reason bytes must not reach SDL's PNG decoder.
pub fn inspect(bytes: []const u8) ?Rejection {
    if (bytes.len < header_length or
        !std.mem.eql(u8, bytes[0..signature.len], signature) or
        !std.mem.eql(u8, bytes[12..16], "IHDR"))
    {
        return .malformed;
    }
    const width = std.mem.readInt(u32, bytes[16..20], .big);
    const height = std.mem.readInt(u32, bytes[20..24], .big);
    if (width == 0 or height == 0) return .malformed;
    if (width > side_capacity or height > side_capacity) return .dimensions_too_large;
    const pixels = @as(u64, width) * height * 4;
    if (pixels > decoded_capacity) return .dimensions_too_large;
    return null;
}

test "accepts exact bounded PNG dimensions" {
    var bytes: [header_length]u8 = @splat(0);
    @memcpy(bytes[0..signature.len], signature);
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], side_capacity, .big);
    std.mem.writeInt(u32, bytes[20..24], side_capacity, .big);
    try std.testing.expectEqual(null, inspect(&bytes));
}

test "rejects malformed and excessive PNG dimensions" {
    var bytes: [header_length]u8 = @splat(0);
    try std.testing.expectEqual(Rejection.malformed, inspect(&bytes));
    @memcpy(bytes[0..signature.len], signature);
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], side_capacity + 1, .big);
    std.mem.writeInt(u32, bytes[20..24], 1, .big);
    try std.testing.expectEqual(Rejection.dimensions_too_large, inspect(&bytes));
}

test "arbitrary image headers remain bounded" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzHeader, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzHeader({}, &empty);
}

fn fuzzHeader(_: void, smith: *std.testing.Smith) !void {
    var bytes: [64]u8 = undefined;
    _ = inspect(bytes[0..smith.slice(&bytes)]);
}
