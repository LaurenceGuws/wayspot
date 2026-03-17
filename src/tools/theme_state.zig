const std = @import("std");
const config = @import("../config/mod.zig");
const theme_catalog = @import("theme_catalog.zig");

pub fn getCurrentTheme(allocator: std.mem.Allocator) !?[]u8 {
    var settings = config.load(allocator);
    defer settings.deinit(allocator);
    if (settings.theme.current.len == 0) return null;
    return try allocator.dupe(u8, settings.theme.current);
}

pub fn setCurrentTheme(allocator: std.mem.Allocator, theme: []const u8) !void {
    const family = theme_catalog.canonicalThemeName(theme) orelse return error.UnsupportedTheme;

    var settings = config.load(allocator);
    defer settings.deinit(allocator);
    settings.theme.deinit(allocator);
    settings.theme.current = try allocator.dupe(u8, family);
    try config.save(allocator, settings);
}
