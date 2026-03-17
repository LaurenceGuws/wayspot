const std = @import("std");

pub fn canonicalThemeName(requested_theme: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, requested_theme, "ayu")) return "ayu";
    if (std.mem.eql(u8, requested_theme, "catppuccin")) return "catppuccin";
    if (std.mem.eql(u8, requested_theme, "dracula")) return "dracula";
    if (std.mem.eql(u8, requested_theme, "everforest")) return "everforest";
    if (std.mem.eql(u8, requested_theme, "gruvbox")) return "gruvbox";
    if (std.mem.eql(u8, requested_theme, "kanagawa")) return "kanagawa";
    if (std.mem.eql(u8, requested_theme, "material")) return "material";
    if (std.mem.eql(u8, requested_theme, "monokai")) return "monokai";
    if (std.mem.eql(u8, requested_theme, "nordic")) return "nordic";
    if (std.mem.eql(u8, requested_theme, "onedark")) return "onedark";
    if (std.mem.eql(u8, requested_theme, "oxocarbon")) return "oxocarbon";
    if (std.mem.eql(u8, requested_theme, "poimandres")) return "poimandres";
    if (std.mem.eql(u8, requested_theme, "rose-pine")) return "rose-pine";
    if (std.mem.eql(u8, requested_theme, "tokyonight")) return "tokyonight";

    if (std.mem.eql(u8, requested_theme, "nord")) return "nordic";
    if (std.mem.eql(u8, requested_theme, "mocha")) return "catppuccin";
    if (std.mem.eql(u8, requested_theme, "catppuccin-mocha")) return "catppuccin";
    if (std.mem.eql(u8, requested_theme, "catppuccin-frappe")) return "catppuccin";
    if (std.mem.eql(u8, requested_theme, "catppuccin-macchiato")) return "catppuccin";
    if (std.mem.eql(u8, requested_theme, "catppuccin-latte")) return "catppuccin";
    return null;
}

pub fn discoverAvailableThemes(allocator: std.mem.Allocator) ![][]u8 {
    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    const wallpapers_root = try std.fs.path.join(allocator, &.{ home, "Pictures", "wallpapers" });
    defer allocator.free(wallpapers_root);
    const waybar_root = try std.fs.path.join(allocator, &.{ home, ".config", "waybar", "themes" });
    defer allocator.free(waybar_root);
    const hypr_root = try std.fs.path.join(allocator, &.{ home, ".config", "hypr", "modules" });
    defer allocator.free(hypr_root);

    var wallpapers_dir = std.fs.cwd().openDir(wallpapers_root, .{ .iterate = true }) catch return allocator.alloc([]u8, 0);
    defer wallpapers_dir.close();

    var iter = wallpapers_dir.iterate();
    var out = std.ArrayList([]u8).empty;
    errdefer {
        for (out.items) |item| allocator.free(item);
        out.deinit(allocator);
    }

    while (try iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        const family = canonicalThemeName(entry.name) orelse continue;
        if (!themeAssetsExist(allocator, waybar_root, hypr_root, family)) continue;
        const theme_wallpaper_dir = try std.fs.path.join(allocator, &.{ wallpapers_root, entry.name });
        defer allocator.free(theme_wallpaper_dir);
        if (!dirHasImages(allocator, theme_wallpaper_dir)) continue;
        if (containsString(out.items, family)) continue;
        try out.append(allocator, try allocator.dupe(u8, family));
    }

    std.mem.sort([]u8, out.items, {}, lessThanStrings);
    return out.toOwnedSlice(allocator);
}

pub fn isThemeAvailable(allocator: std.mem.Allocator, theme: []const u8) !bool {
    const canonical = canonicalThemeName(theme) orelse return false;
    const themes = try discoverAvailableThemes(allocator);
    defer {
        for (themes) |item| allocator.free(item);
        allocator.free(themes);
    }
    for (themes) |item| {
        if (std.mem.eql(u8, item, canonical)) return true;
    }
    return false;
}

pub fn printAvailableThemes(allocator: std.mem.Allocator) !void {
    const themes = try discoverAvailableThemes(allocator);
    defer {
        for (themes) |item| allocator.free(item);
        allocator.free(themes);
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const out = &stdout_writer.interface;
    for (themes) |theme| {
        try out.print("{s}\n", .{theme});
    }
    try out.flush();
}

fn themeAssetsExist(allocator: std.mem.Allocator, waybar_root: []const u8, hypr_root: []const u8, family: []const u8) bool {
    const waybar_name = std.fmt.allocPrint(allocator, "{s}.css", .{family}) catch return false;
    defer allocator.free(waybar_name);
    const waybar_file = std.fs.path.join(allocator, &.{ waybar_root, waybar_name }) catch return false;
    defer allocator.free(waybar_file);
    const hypr_name = std.fmt.allocPrint(allocator, "hypr_theme_{s}.conf", .{family}) catch return false;
    defer allocator.free(hypr_name);
    const hypr_file = std.fs.path.join(allocator, &.{ hypr_root, hypr_name }) catch return false;
    defer allocator.free(hypr_file);
    return pathExists(waybar_file) and pathExists(hypr_file);
}

fn dirHasImages(allocator: std.mem.Allocator, dir_path: []const u8) bool {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return false;
    defer dir.close();

    var walker = dir.walk(allocator) catch return false;
    defer walker.deinit();
    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (isImage(entry.path)) return true;
    }
    return false;
}

fn isImage(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.ascii.eqlIgnoreCase(ext, ".png") or
        std.ascii.eqlIgnoreCase(ext, ".jpg") or
        std.ascii.eqlIgnoreCase(ext, ".jpeg") or
        std.ascii.eqlIgnoreCase(ext, ".webp");
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn containsString(items: []const []u8, needle: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item, needle)) return true;
    }
    return false;
}

fn lessThanStrings(_: void, a: []u8, b: []u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}
