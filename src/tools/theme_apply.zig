const std = @import("std");
const theme_catalog = @import("theme_catalog.zig");
const theme_state = @import("theme_state.zig");
const wallpaper_runtime = @import("wallpaper_runtime.zig");
const wm = @import("../wm/mod.zig");

pub fn applyTheme(allocator: std.mem.Allocator, requested_theme: []const u8) !void {
    const family = theme_catalog.canonicalThemeName(requested_theme) orelse return error.UnsupportedTheme;
    if (!try theme_catalog.isThemeAvailable(allocator, family)) return error.UnsupportedTheme;
    try theme_state.setCurrentTheme(allocator, family);

    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    const hypr_content = try std.fmt.allocPrint(allocator,
        "-- Change this require line to swap the active theme.\nreturn require(\"modules.hypr_theme_{s}\")\n",
        .{family},
    );
    defer allocator.free(hypr_content);

    const live_hypr_current = try std.fs.path.join(allocator, &.{ home, ".config", "hypr", "modules", "hypr_theme_current.lua" });
    defer allocator.free(live_hypr_current);
    const live_hyprpaper = try std.fs.path.join(allocator, &.{ home, ".config", "hypr", "hyprpaper.conf" });
    defer allocator.free(live_hyprpaper);
    const wallpapers_root = try std.fs.path.join(allocator, &.{ home, "Pictures", "wallpapers" });
    defer allocator.free(wallpapers_root);

    try writeFileEnsuringParents(live_hypr_current, hypr_content);
    try updateHyprpaperTheme(allocator, live_hyprpaper, family);

    _ = try runBestEffort(allocator, &.{ "hyprctl", "reload" });
    var hypr_backend = wm.HyprlandBackend{};
    try wallpaper_runtime.applyRandomWallpapers(allocator, &hypr_backend, live_hyprpaper, wallpapers_root);
}

fn updateHyprpaperTheme(allocator: std.mem.Allocator, config_path: []const u8, theme_name: []const u8) !void {
    const existing = std.fs.cwd().readFileAlloc(allocator, config_path, 1024 * 1024) catch {
        const fresh = try std.fmt.allocPrint(allocator,
            "splash = false\nipc = true\nuse_all = false\nuse_theme = {s}\nuse_resolution_match = false\n",
            .{theme_name},
        );
        defer allocator.free(fresh);
        try writeFileEnsuringParents(config_path, fresh);
        return;
    };
    defer allocator.free(existing);

    const updated = if (std.mem.indexOf(u8, existing, "use_theme")) |_|
        try replaceUseThemeLine(allocator, existing, theme_name)
    else
        try std.fmt.allocPrint(allocator, "{s}\nuse_theme = {s}\n", .{ existing, theme_name });
    defer allocator.free(updated);
    try writeFileEnsuringParents(config_path, updated);
}

fn replaceUseThemeLine(allocator: std.mem.Allocator, contents: []const u8, theme_name: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "use_theme")) {
            try std.fmt.format(out.writer(allocator), "use_theme = {s}\n", .{theme_name});
        } else {
            try out.appendSlice(allocator, line);
            try out.append(allocator, '\n');
        }
    }
    return out.toOwnedSlice(allocator);
}

fn writeFileEnsuringParents(path: []const u8, contents: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| try std.fs.cwd().makePath(dir);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = contents });
}

fn runBestEffort(allocator: std.mem.Allocator, argv: []const []const u8) !bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.term == .Exited and result.term.Exited == 0;
}
