//! Starts one native Wayspot process.

const std = @import("std");
const apps = @import("apps/catalog.zig");
const cli = @import("cli.zig");
const cmd = @import("cmd.zig");
const tray_watcher = @import("tray/watcher.zig");
const desktop_files = @import("apps/desktop_files.zig");
const launch = @import("apps/launch.zig");
const notification = @import("notifications/root.zig");
const navigator = @import("picker/navigator.zig");
const picker = @import("picker/root.zig");
const sdl = @import("picker/view.zig");
const Video = @import("ui/video.zig");
const wallpaper = @import("wallpaper/wayland.zig");
const resident = @import("resident.zig");

pub fn main(init: std.process.Init) !u8 {
    var argument_iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer argument_iterator.deinit();
    std.debug.assert(argument_iterator.skip());
    var arguments: [cmd.argument_capacity + 1][]const u8 = undefined;
    var argument_count: usize = 0;
    while (argument_iterator.next()) |argument| {
        if (argument_count == arguments.len) return error.TooManyArguments;
        arguments[argument_count] = argument;
        argument_count += 1;
    }

    const argv = arguments[0..argument_count];
    if (argument_count > 0 and std.mem.eql(u8, argv[0], "--launch-plan")) {
        try launch.runPlan(init, argv[1..]);
        return 0;
    }
    if (argument_count > cmd.argument_capacity) return 2;
    if (argument_count > 0 and std.mem.eql(u8, argv[0], "resident")) {
        if (argument_count != 2) return 2;
        if (std.mem.eql(u8, argv[1], "status")) {
            try resident.request(init, .status);
        } else {
            try resident.run(init, argv[1]);
        }
        return 0;
    }
    if (argument_count > 0 and std.mem.eql(u8, argv[0], "picker")) {
        if (argument_count == 1) try resident.request(init, .summon) else if (argument_count == 2 and std.mem.eql(u8, argv[1], "dismiss")) try resident.request(init, .dismiss) else return 2;
        return 0;
    }
    if (argument_count > 0) {
        if (std.mem.eql(u8, argv[0], "tray")) {
            if (argument_count != 1) return 2;
            try tray_watcher.run(init.io);
            return 0;
        }
        if (cmd.resolveCompletion(argv) catch return 2) |meaning| {
            return perform(init, meaning, &.{}, null, null);
        }
        if (cmd.resolveWallpaper(argv) catch return 2) |meaning| {
            return perform(init, meaning, &.{}, null, null);
        }
        if (cmd.resolveNotifications(argv) catch return 2) |meaning| {
            return perform(init, meaning, &.{}, null, null);
        }
    }

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

    if (argument_count > 0) {
        var query_bytes: [cmd.query_capacity]u8 = undefined;
        const meaning = cmd.resolveApps(argv, applications.slice(), &query_bytes) catch |err| {
            return switch (err) {
                error.ArgumentsInvalid,
                error.QueryInvalid,
                error.QueryTooLong,
                error.ApplicationAmbiguous,
                error.ApplicationNotFound,
                => {
                    var stdout_buffer: [4096]u8 = undefined;
                    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
                    try stdout_writer.interface.writeAll(cli.help);
                    try stdout_writer.interface.flush();
                    return 2;
                },
                else => |other| return other,
            };
        };
        return perform(init, meaning, applications.slice(), terminal, home);
    }

    try Video.prepareProcess(init.io);
    runPicker(init, &files, &applications, terminal, home) catch |failure| {
        if (navigator.backendForSession(init.environ_map.get("XDG_SESSION_DESKTOP")) != .snowman) return failure;
        navigator.reportFailure(init, failure);
        return 4;
    };
    return 0;
}

fn runPicker(
    init: std.process.Init,
    files: *const desktop_files.Files,
    applications: *const apps.List,
    terminal: ?[]const u8,
    home: []const u8,
) !void {
    logApplications(files, applications);
    var video: Video = .{};
    var native: sdl.Native = .{
        .video = &video,
        .applications = applications.slice(),
        .allocator = init.gpa,
        .io = init.io,
        .home = home,
    };
    var history_reader = HistoryReader{ .process = &init, .home = home };
    const window_backend = navigator.backendForSession(init.environ_map.get("XDG_SESSION_DESKTOP"));
    if (try picker.run(
        &native,
        &history_reader,
        navigator.Native{ .io = init.io, .environ_map = init.environ_map },
        window_backend,
        init.gpa,
        @intCast(std.os.linux.getpid()),
        applications.slice(),
    )) |index| {
        var process = launch.Native{ .io = init.io, .environ_map = init.environ_map };
        try launch.spawn(&process, &applications.slice()[index], terminal, home);
    }
}

const HistoryReader = struct {
    process: *const std.process.Init,
    home: []const u8,

    pub fn readHistory(reader: *HistoryReader) !notification.History {
        return notification.inspect(
            reader.process.gpa,
            reader.process.io,
            reader.process.environ_map.get("XDG_STATE_HOME"),
            reader.home,
        );
    }
};

fn perform(
    init: std.process.Init,
    meaning: cmd.Cmd,
    applications: []const apps.App,
    terminal: ?[]const u8,
    home: ?[]const u8,
) !u8 {
    switch (meaning) {
        .completion => {
            var stdout_buffer: [4096]u8 = undefined;
            var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
            try cli.writeBash(&stdout_writer.interface);
            try stdout_writer.interface.flush();
        },
        .wallpaper => |wallpaper_command| switch (wallpaper_command) {
            .run => |root| try runWallpaper(init, root),
            .rotate => {
                if (resident.request(init, .rotate)) |_| return 0 else |err| if (err != error.ResidentUnavailable) return err;
                const identifier = try wallpaper.sessionIdentifier(
                    init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.RuntimeDirectoryMissing,
                    init.environ_map.get("WAYLAND_DISPLAY") orelse return error.WaylandDisplayMissing,
                );
                try wallpaper.requestRotation(init.io, &identifier);
            },
        },
        .apps => |app| switch (app) {
            .list => |query| {
                var stdout_buffer: [4096]u8 = undefined;
                var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
                try cli.writeApps(&stdout_writer.interface, applications, query);
                try stdout_writer.interface.flush();
            },
            .open => |index| {
                const cwd = home orelse return error.HomeMissing;
                if (index >= applications.len) return error.ApplicationIndexInvalid;
                var process = launch.Native{ .io = init.io, .environ_map = init.environ_map };
                try launch.spawn(&process, &applications[index], terminal, cwd);
            },
        },
        .notifications => |notification_command| switch (notification_command) {
            .run => try runNotifications(init),
            .history => try printNotificationHistory(init),
        },
    }
    return 0;
}

fn runWallpaper(init: std.process.Init, root: []const u8) !void {
    try wallpaper.run(init, root);
}

fn runNotifications(init: std.process.Init) !void {
    try Video.prepareProcess(init.io);
    try notification.run(init.gpa, init.io, init.environ_map.get("XDG_STATE_HOME"), init.environ_map.get("HOME"));
}

fn printNotificationHistory(init: std.process.Init) !void {
    var history = try notification.inspect(
        init.gpa,
        init.io,
        init.environ_map.get("XDG_STATE_HOME"),
        init.environ_map.get("HOME"),
    );
    defer history.deinit(init.gpa);
    const bytes = try notification.format(init.gpa, &history);
    defer init.gpa.free(bytes);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(bytes);
    try stdout_writer.interface.flush();
}

fn logApplications(files: *const desktop_files.Files, applications: *const apps.List) void {
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
        const count = applications.report.decisions[@backingInt(decision)];
        if (count > 0) std.log.info("desktop decision={s} count={d}", .{ @tagName(decision), count });
    }
    for (std.enums.values(apps.Issue)) |issue| {
        const count = applications.report.issues[@backingInt(issue)];
        if (count > 0) std.log.info("desktop issue={s} count={d}", .{ @tagName(issue), count });
    }
}
