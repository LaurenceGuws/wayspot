const std = @import("std");

pub fn toggle(allocator: std.mem.Allocator, exe_path: []const u8, config_path: []const u8, source_dir: []const u8) !bool {
    var running = try findRunningPids(allocator);
    defer {
        for (running.items) |pid| allocator.free(pid);
        running.deinit(allocator);
    }

    if (running.items.len > 0) {
        for (running.items) |pid| {
            _ = try std.process.Child.run(.{
                .allocator = allocator,
                .argv = &.{ "kill", pid },
                .max_output_bytes = 0,
            });
        }
        return false;
    }

    var child = std.process.Child.init(&.{ exe_path, "--wallpaper-slideshow", "--config", config_path, "--source", source_dir }, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    return true;
}

fn findRunningPids(allocator: std.mem.Allocator) !std.ArrayList([]u8) {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "pgrep", "-f", "wayspot.*--wallpaper-slideshow" },
        .max_output_bytes = 16 * 1024,
    }) catch |err| switch (err) {
        error.FileNotFound => return std.ArrayList([]u8).empty,
        else => return err,
    };
    defer allocator.free(result.stderr);
    defer allocator.free(result.stdout);

    var out = std.ArrayList([]u8).empty;
    errdefer {
        for (out.items) |item| allocator.free(item);
        out.deinit(allocator);
    }
    if (result.term != .Exited or result.term.Exited != 0) return out;

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try out.append(allocator, try allocator.dupe(u8, trimmed));
    }
    return out;
}
