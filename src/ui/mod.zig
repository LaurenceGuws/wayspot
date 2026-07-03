const build_options = @import("build_options");
const std = @import("std");

pub const gtk_enabled = false;
pub const sdl_enabled = build_options.enable_sdl;
pub const sdl_banner = @import("sdl_banner.zig");
pub const surface_config = @import("surface_config.zig");
pub const sdl_text = @import("sdl_text.zig");
pub const Shell = @import("sdl_shell.zig").Shell;
