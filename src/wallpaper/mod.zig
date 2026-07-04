//! Wallpaper owns bounded per-monitor SDL surfaces and Hyprland placement.

pub const config = @import("config.zig");
pub const hyprland = @import("hyprland.zig");
pub const image_info = @import("image_info.zig");
pub const library = @import("library.zig");

pub const Config = config.Config;
pub const Library = library.Library;
pub const Runtime = @import("runtime.zig").Runtime;
pub const Monitor = hyprland.Monitor;
