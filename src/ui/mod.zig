const build_options = @import("build_options");
const std = @import("std");

pub const gtk_enabled = false;
pub const sdl_enabled = build_options.enable_sdl;
pub const placement = @import("placement/mod.zig");
pub const sdl_text = @import("sdl_text.zig");
pub const surfaces = @import("surfaces/mod.zig");
pub const Shell = @import("sdl_shell.zig").Shell;
