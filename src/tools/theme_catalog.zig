const std = @import("std");

pub const supported_themes = [_][]const u8{
    "ayu",
    "nordic",
    "mocha",
};

pub fn canonicalThemeName(requested_theme: []const u8) ?[]const u8 {
    inline for (supported_themes) |theme| {
        if (std.mem.eql(u8, requested_theme, theme)) return theme;
    }

    if (std.mem.eql(u8, requested_theme, "nord")) return "nordic";
    if (std.mem.eql(u8, requested_theme, "catppuccin")) return "mocha";
    if (std.mem.eql(u8, requested_theme, "catppuccin-mocha")) return "mocha";
    if (std.mem.eql(u8, requested_theme, "catppuccin-frappe")) return "mocha";
    if (std.mem.eql(u8, requested_theme, "catppuccin-macchiato")) return "mocha";
    if (std.mem.eql(u8, requested_theme, "catppuccin-latte")) return "mocha";
    return null;
}

