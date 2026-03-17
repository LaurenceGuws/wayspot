const std = @import("std");
const theme_catalog = @import("theme_catalog.zig");
const theme_state = @import("theme_state.zig");

pub fn applyTheme(allocator: std.mem.Allocator, requested_theme: []const u8) !void {
    const family = theme_catalog.canonicalThemeName(requested_theme) orelse return error.UnsupportedTheme;
    try theme_state.setCurrentTheme(allocator, family);

    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    const waybar_content = try std.fmt.allocPrint(allocator,
        "/* Switch this import to swap the active Waybar theme. */\n@import url(\"./{s}.css\");\n",
        .{family},
    );
    defer allocator.free(waybar_content);
    const hypr_content = try std.fmt.allocPrint(allocator,
        "## Switch this source to swap the active Hyprland theme.\nsource = ~/.config/hypr/modules/hypr_theme_{s}.conf\n",
        .{family},
    );
    defer allocator.free(hypr_content);

    const live_waybar_current = try std.fs.path.join(allocator, &.{ home, ".config", "waybar", "themes", "current.css" });
    defer allocator.free(live_waybar_current);
    const live_hypr_current = try std.fs.path.join(allocator, &.{ home, ".config", "hypr", "modules", "hypr_theme_current.conf" });
    defer allocator.free(live_hypr_current);
    const live_hyprpaper = try std.fs.path.join(allocator, &.{ home, ".config", "hypr", "hyprpaper.conf" });
    defer allocator.free(live_hyprpaper);

    try writeFileEnsuringParents(live_waybar_current, waybar_content);
    try writeFileEnsuringParents(live_hypr_current, hypr_content);
    try updateHyprpaperTheme(allocator, live_hyprpaper, family);

    _ = try runBestEffort(allocator, &.{ "hyprctl", "reload" });
    try restartWaybar(allocator);
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

fn spawnDetached(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    child.spawn() catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
}

fn restartWaybar(allocator: std.mem.Allocator) !void {
    _ = try runBestEffort(allocator, &.{ "pkill", "-x", "waybar" });
    std.Thread.sleep(150 * std.time.ns_per_ms);
    try spawnDetached(allocator, &.{ "waybar" });
}
