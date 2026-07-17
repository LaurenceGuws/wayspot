//! Starts one native Wayspot beta picker process.

const std = @import("std");
const apps = @import("apps.zig");
const desktop_files = @import("desktop_files.zig");
const launch = @import("launch.zig");
const picker = @import("picker.zig");
const sdl = @import("sdl.zig");

pub fn main(init: std.process.Init) !void {
    var files = try desktop_files.collect(init.gpa, init.io, .{
        .home = init.environ_map.get("HOME"),
        .data_home = init.environ_map.get("XDG_DATA_HOME"),
        .data_dirs = init.environ_map.get("XDG_DATA_DIRS"),
    });
    defer files.deinit();

    var applications = try apps.load(
        init.gpa,
        files.items.items,
        init.environ_map.get("XDG_CURRENT_DESKTOP"),
    );
    defer applications.deinit();
    try desktop_files.applyTryExec(init.io, init.environ_map.get("PATH"), &applications);
    const terminal = try desktop_files.applyTerminal(
        init.io,
        init.environ_map.get("PATH"),
        init.environ_map.get("TERMINAL"),
        &applications,
    );
    const home = init.environ_map.get("HOME") orelse return error.HomeMissing;
    try launch.apply(&applications, terminal, home);

    std.log.info(
        "desktop files={d} apps={d} malformed={d} duplicates={d} unavailable_roots={d} unreadable={d} oversized={d}",
        .{
            files.items.items.len,
            applications.count,
            applications.report.malformed,
            applications.report.duplicates,
            files.report.roots_unavailable,
            files.report.files_unreadable,
            files.report.files_too_long,
        },
    );
    for (std.enums.values(apps.Decision)) |decision| {
        const count = applications.report.decisions[@intFromEnum(decision)];
        if (count > 0) std.log.info("desktop decision={s} count={d}", .{ @tagName(decision), count });
    }
    for (std.enums.values(apps.Issue)) |issue| {
        const count = applications.report.issues[@intFromEnum(issue)];
        if (count > 0) std.log.info("desktop issue={s} count={d}", .{ @tagName(issue), count });
    }

    var native: sdl.Native = .{};
    if (try picker.run(&native, applications.slice())) |index| {
        var process = launch.Native{ .io = init.io };
        try launch.run(&process, &applications.slice()[index], terminal, home);
    }
}
