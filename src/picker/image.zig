//! Validates the bounded PNG bytes accepted by the picker icon decoder.

const std = @import("std");

/// Maximum encoded application icon bytes admitted to the PNG decoder.
pub const encoded_capacity = 4 * 1024 * 1024;
/// Maximum decoded width or height.
pub const side_capacity = 1024;
const decoded_capacity = side_capacity * side_capacity * 4;
const header_length = 24;
const signature = "\x89PNG\r\n\x1a\n";

/// Preflight refusal; complete PNG validity remains the decoder's responsibility.
pub const Rejection = enum {
    encoded_too_large,
    malformed,
    dimensions_too_large,
};

/// Inspect returns the exact reason bytes must not reach SDL's PNG decoder.
pub fn inspect(bytes: []const u8) ?Rejection {
    if (bytes.len > encoded_capacity) return .encoded_too_large;
    if (bytes.len < header_length or
        !std.mem.eql(u8, bytes[0..signature.len], signature) or
        std.mem.readInt(u32, bytes[8..12], .big) != 13 or
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

/// Reads bounded regular-file bytes, retaining icon-theme symlink support.
/// Nonblocking open avoids waiting for a FIFO peer after a path replacement.
pub fn readRegular(
    io: std.Io,
    allocator: std.mem.Allocator,
    path: [:0]const u8,
    limit: usize,
) ![]u8 {
    if (std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidIconPath;
    const cwd = std.Io.Dir.cwd();
    const known = try cwd.statFile(io, path, .{ .follow_symlinks = true });
    if (known.kind != .file) return error.IconNotRegularFile;
    const fd = try std.posix.openatZ(cwd.handle, path.ptr, .{
        .ACCMODE = .RDONLY,
        .CLOEXEC = true,
        .NONBLOCK = true,
        .NOCTTY = true,
    }, 0);
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file) return error.IconNotRegularFile;
    if (stat.size > limit) return error.StreamTooLong;
    const bytes = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(bytes);
    if (try file.readPositionalAll(io, bytes, 0) != bytes.len) return error.IconFileChanged;
    var extra: [1]u8 = undefined;
    if (try file.readPositionalAll(io, &extra, bytes.len) != 0) {
        if (bytes.len == limit) return error.StreamTooLong;
        return error.IconFileChanged;
    }
    return bytes;
}

test "accepts exact bounded PNG dimensions" {
    var bytes: [header_length]u8 = @splat(0);
    @memcpy(bytes[0..signature.len], signature);
    std.mem.writeInt(u32, bytes[8..12], 13, .big);
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], side_capacity, .big);
    std.mem.writeInt(u32, bytes[20..24], side_capacity, .big);
    try std.testing.expectEqual(null, inspect(&bytes));
}

test "rejects malformed and excessive PNG dimensions" {
    var bytes: [header_length]u8 = @splat(0);
    try std.testing.expectEqual(Rejection.malformed, inspect(&bytes));
    @memcpy(bytes[0..signature.len], signature);
    std.mem.writeInt(u32, bytes[8..12], 13, .big);
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
    const input = bytes[0..smith.slice(&bytes)];
    if (inspect(input) == null) {
        try std.testing.expect(input.len >= header_length);
        try std.testing.expectEqualStrings(signature, input[0..8]);
        try std.testing.expectEqual(@as(u32, 13), std.mem.readInt(u32, input[8..12], .big));
        try std.testing.expectEqualStrings("IHDR", input[12..16]);
        const width = std.mem.readInt(u32, input[16..20], .big);
        const height = std.mem.readInt(u32, input[20..24], .big);
        try std.testing.expect(width > 0 and width <= side_capacity);
        try std.testing.expect(height > 0 and height <= side_capacity);
    }
}

test "PNG preflight refuses a wrong IHDR length and encoded bytes over the limit" {
    const allocator = std.testing.allocator;
    const bytes = try allocator.alloc(u8, encoded_capacity + 1);
    defer allocator.free(bytes);
    @memset(bytes, 0);
    @memcpy(bytes[0..8], signature);
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], 1, .big);
    std.mem.writeInt(u32, bytes[20..24], 1, .big);
    try std.testing.expectEqual(Rejection.malformed, inspect(bytes[0..24]));
    std.mem.writeInt(u32, bytes[8..12], 13, .big);
    try std.testing.expectEqual(null, inspect(bytes[0..encoded_capacity]));
    try std.testing.expectEqual(Rejection.encoded_too_large, inspect(bytes));
}

test "regular icon reader admits exact byte budget and refuses special files" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const linux = std.os.linux;
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    var root_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buf[0..try fixture.dir.realPath(io, &root_buf)];
    try fixture.dir.writeFile(io, .{ .sub_path = "regular", .data = "12345678" });
    try fixture.dir.symLink(io, "regular", "linked", .{});
    try fixture.dir.createDir(io, "directory", .default_dir);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.mknodat(
        fixture.dir.handle,
        "fifo",
        linux.S.IFIFO | 0o600,
        0,
    )));
    try fixture.dir.symLink(io, "fifo", "linked-fifo", .{});
    var path_buf: [std.Io.Dir.max_path_bytes:0]u8 = undefined;
    for ([_][]const u8{ "regular", "linked" }) |name| {
        const path = try std.mem.printSentinel(&path_buf, "{s}/{s}", .{ root, name }, 0);
        const bytes = try readRegular(io, allocator, path, 8);
        defer allocator.free(bytes);
        try std.testing.expectEqualStrings("12345678", bytes);
        try std.testing.expectError(error.StreamTooLong, readRegular(io, allocator, path, 7));
    }
    for ([_][]const u8{ "directory", "fifo", "linked-fifo" }) |name| {
        const path = try std.mem.printSentinel(&path_buf, "{s}/{s}", .{ root, name }, 0);
        try std.testing.expectError(error.IconNotRegularFile, readRegular(io, allocator, path, 8));
    }
    const missing = try std.mem.printSentinel(&path_buf, "{s}/missing", .{root}, 0);
    try std.testing.expectError(error.FileNotFound, readRegular(io, allocator, missing, 8));
}
