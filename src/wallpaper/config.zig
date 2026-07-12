//! Wallpaper configuration admits one image library path and one bounded timer.

const std = @import("std");

/// max_file_bytes bounds one wallpaper configuration file.
pub const max_file_bytes: u32 = 4096;
/// min_interval_seconds is the smallest accepted rotation interval.
pub const min_interval_seconds: u32 = 30;
/// max_interval_seconds is the largest accepted rotation interval.
pub const max_interval_seconds: u32 = 86400;
/// default_interval_seconds is used when no interval is configured.
pub const default_interval_seconds: u32 = 900;

const config_relative_path = ".config/wayspot/wallpaper.conf";

/// Config owns one absolute wallpaper library path and one bounded interval.
pub const Config = struct {
    /// load reads the configured wallpaper file.
    library_path: []u8,
    interval_seconds: u32 = default_interval_seconds,

    pub fn load(allocator: std.mem.Allocator) !Config {
        const path = try defaultPath(allocator);
        defer allocator.free(path);
        return Config.loadAtPath(allocator, path);
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.library_path);
        self.library_path = "";
    }

    /// loadAtPath reads one bounded wallpaper configuration path.
    pub fn loadAtPath(allocator: std.mem.Allocator, path: []const u8) !Config {
        const raw = try std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, allocator, .limited(max_file_bytes));
        defer allocator.free(raw);
        return parse(allocator, raw);
    }
};

/// parse validates one bounded wallpaper configuration buffer.
pub fn parse(allocator: std.mem.Allocator, raw: []const u8) !Config {
    var library_path: ?[]const u8 = null;
    var interval_seconds = default_interval_seconds;

    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, std.mem.trimEnd(u8, raw_line, "\r"), " \t");
        if (line.len == 0 or line[0] == '#') continue;
        const split_at = std.mem.indexOfScalar(u8, line, '=') orelse return error.InvalidWallpaperConfig;
        const key = std.mem.trim(u8, line[0..split_at], " \t");
        const value = std.mem.trim(u8, line[split_at + 1 ..], " \t");
        if (std.mem.eql(u8, key, "library_path")) {
            if (!std.fs.path.isAbsolute(value)) return error.InvalidWallpaperLibraryPath;
            if (value.len == 0) return error.InvalidWallpaperLibraryPath;
            library_path = value;
        } else if (std.mem.eql(u8, key, "interval_seconds")) {
            if (value.len == 0) return error.InvalidWallpaperInterval;
            const parsed = try std.fmt.parseInt(u32, value, 10);
            interval_seconds = @min(max_interval_seconds, @max(min_interval_seconds, parsed));
        } else {
            return error.InvalidWallpaperConfig;
        }
    }

    const path = library_path orelse return error.MissingWallpaperLibraryPath;
    return .{
        .library_path = try allocator.dupe(u8, path),
        .interval_seconds = interval_seconds,
    };
}

fn defaultPath(allocator: std.mem.Allocator) ![]u8 {
    const home = if (std.c.getenv("HOME")) |home_z| std.mem.span(home_z) else return error.HomeNotSet;
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, config_relative_path });
}

test "config parser accepts absolute library path and default interval" {
    var config = try parse(std.testing.allocator, "library_path=/tmp/wallpapers\n");
    defer config.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("/tmp/wallpapers", config.library_path);
    try std.testing.expectEqual(default_interval_seconds, config.interval_seconds);
}

test "config parser clamps interval bounds" {
    var low = try parse(std.testing.allocator, "library_path=/tmp/wallpapers\ninterval_seconds=1\n");
    defer low.deinit(std.testing.allocator);
    try std.testing.expectEqual(min_interval_seconds, low.interval_seconds);

    var high = try parse(std.testing.allocator, "library_path=/tmp/wallpapers\ninterval_seconds=900000\n");
    defer high.deinit(std.testing.allocator);
    try std.testing.expectEqual(max_interval_seconds, high.interval_seconds);
}

test "config parser rejects missing and relative library path" {
    try std.testing.expectError(error.MissingWallpaperLibraryPath, parse(std.testing.allocator, "interval_seconds=60\n"));
    try std.testing.expectError(error.InvalidWallpaperLibraryPath, parse(std.testing.allocator, "library_path=wallpapers\n"));
}

test "config loader rejects oversized file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var data: [max_file_bytes + 1]u8 = undefined;
    @memset(&data, 'x');
    try tmp.dir.writeFile(.{ .sub_path = "wallpaper.conf", .data = &data });

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/wallpaper.conf", .{base});
    defer std.testing.allocator.free(path);

    try std.testing.expectError(error.StreamTooLong, Config.loadAtPath(std.testing.allocator, path));
}
