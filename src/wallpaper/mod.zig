//! Wallpaper owns the resident loop, bounded per-monitor vendor surfaces, and image rotation.

pub const config = @import("config.zig");

pub const Loop = @import("loop.zig").Loop;
/// run owns one wallpaper resident loop lifecycle.
pub const run = Loop.run;
/// rotateNow owns one direct rotation request for the resident wallpaper loop.
pub const rotateNow = Loop.rotateNow;
