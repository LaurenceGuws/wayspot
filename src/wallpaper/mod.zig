//! Wallpaper is the resident loop owner.
//!
//! `run` owns identity setup, SDL lifecycle, image and monitor lifecycle,
//! recovery, and cleanup. Picker mode code carries only typed route meaning.

const std = @import("std");
const env = @import("../env/mod.zig");
const identity = @import("../identity.zig");

pub const config = @import("config.zig");

pub const Loop = @import("loop.zig").Loop;

/// run owns one wallpaper resident loop lifecycle and its vendor cleanup.
pub fn run(allocator: std.mem.Allocator, monitor_source: env.MonitorSource) !void {
    try identity.set(identity.wallpaper);
    Loop.run(allocator, monitor_source) catch |err| {
        std.log.err("wallpaper loop failed: {s}", .{@errorName(err)});
        std.process.exit(2);
    };
}

/// rotateNow owns one direct rotation request and the wallpaper owner identity.
pub fn rotateNow(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
    try identity.set(identity.wallpaper);
    try Loop.rotateNow(allocator, runtime_dir);
}

test "wallpaper module reaches resident loop and rotation owners" {
    std.testing.refAllDecls(config);
    std.testing.refAllDecls(Loop);
}
