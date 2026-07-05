//! UI module export surface for SDL-owned Wayspot runtime views.

const build_options = @import("build_options");
const std = @import("std");

pub const gtk_enabled = false;
pub const sdl_enabled = build_options.enable_sdl;
pub const app_icon_cache = @import("app_icon_cache.zig");
pub const app_icon_diag = @import("app_icon_diag.zig");
pub const app_icons = @import("app_icons.zig");
pub const controls = @import("controls/mod.zig");
pub const sdl_banner = @import("sdl_banner.zig");
pub const sdl_wallpaper_surface = @import("sdl_wallpaper_surface.zig");
pub const picker_viewport = @import("picker_viewport.zig");
pub const surface_config = @import("surface_config.zig");
pub const sdl_text = @import("sdl_text.zig");
pub const Shell = @import("sdl_shell.zig").Shell;
