//! Starts one native Wayspot process.

const std = @import("std");
const apps = @import("apps.zig");
const cli = @import("cli.zig");
const cmd = @import("cmd.zig");
const desktop_files = @import("desktop_files.zig");
const launch = @import("launch.zig");
const notification = @import("notification.zig");
const picker = @import("picker.zig");
const sdl = @import("sdl.zig");
const wallpaper = @import("wallpaper.zig");
const wallpaper_native = @import("wallpaper_native.zig");

var notification_stop: std.atomic.Value(bool) = .init(false);

pub fn main(init: std.process.Init) !u8 {
    var argument_iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer argument_iterator.deinit();
    std.debug.assert(argument_iterator.skip());
    var arguments: [cmd.argument_capacity][]const u8 = undefined;
    var argument_count: usize = 0;
    while (argument_iterator.next()) |argument| {
        if (argument_count == arguments.len) return error.TooManyArguments;
        arguments[argument_count] = argument;
        argument_count += 1;
    }

    const argv = arguments[0..argument_count];
    if (argument_count > 0) {
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

    try runPicker(init, &files, &applications, terminal, home);
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
    var native: sdl.Native = .{
        .applications = applications.slice(),
        .allocator = init.gpa,
        .io = init.io,
        .home = home,
    };
    var history_reader = HistoryReader{ .process = &init, .home = home };
    if (try picker.run(&native, &history_reader, init.gpa, applications.slice())) |index| {
        var process = launch.Native{ .io = init.io };
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
        .wallpaper => |wallpaper_command| switch (wallpaper_command) {
            .run => |root| try runWallpaper(init, root),
            .rotate => try wallpaper_native.requestRotation(
                init.io,
                init.environ_map.get("HYPRLAND_INSTANCE_SIGNATURE") orelse
                    return error.HyprlandSignatureMissing,
            ),
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
                var process = launch.Native{ .io = init.io };
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

/// Owns one image and resident lifetime; teardown disconnects before local owners are freed.
fn runWallpaper(init: std.process.Init, root: []const u8) !void {
    var catalog = try wallpaper_native.discoverCatalog(init.io, init.gpa, root);
    defer catalog.deinit();
    const signature = init.environ_map.get("HYPRLAND_INSTANCE_SIGNATURE") orelse
        return error.HyprlandSignatureMissing;
    const paths = try wallpaper_native.buildSocketPaths(
        init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.RuntimeDirectoryMissing,
        signature,
    );
    var resident = wallpaper_native.Native{ .io = init.io };
    try resident.openRotation(signature);
    defer resident.closeRotation();
    const native = try resident.createNative(init.gpa);
    var current = wallpaper.Current(wallpaper_native.Native){ .native = native, .round = .{} };
    defer init.gpa.destroy(current.native);
    var image: ?wallpaper.Image = null;
    for (0..catalog.paths.items.len) |_| {
        image = wallpaper.loadImage(&resident, init.gpa, try catalog.next()) catch continue;
        break;
    }
    if (image == null) return error.WallpaperCatalogUnusable;
    catalog.published = catalog.last;
    var selected = image.?;
    defer selected.deinit(init.gpa);
    const stop = try wallpaper_native.openStop();
    defer wallpaper_native.closeStop(stop);
    var event_fd: std.posix.fd_t = -1;
    defer {
        current.native.disconnectAfterDisplayLoss();
        current.round = .{};
        if (event_fd >= 0) resident.closeEvent(&event_fd);
    }
    wallpaper.runRotation(
        &resident,
        init.gpa,
        &catalog,
        &selected,
        &current,
        stop.fd,
        &event_fd,
        &paths,
        wallpaper.rotation_interval_milliseconds,
    ) catch |err| {
        if (err != error.Stopped) return err;
    };
}

fn runNotifications(init: std.process.Init) !void {
    notification_stop.store(false, .release);
    const action: std.posix.Sigaction = .{
        .handler = .{ .handler = stopNotification },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    var old_interrupt: std.posix.Sigaction = undefined;
    var old_terminate: std.posix.Sigaction = undefined;
    std.posix.sigaction(.INT, &action, &old_interrupt);
    defer std.posix.sigaction(.INT, &old_interrupt, null);
    std.posix.sigaction(.TERM, &action, &old_terminate);
    defer std.posix.sigaction(.TERM, &old_terminate, null);

    try notification.run(
        init.gpa,
        init.io,
        init.environ_map.get("XDG_STATE_HOME"),
        init.environ_map.get("HOME"),
        &notification_stop,
    );
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

fn stopNotification(_: std.posix.SIG) callconv(.c) void {
    notification_stop.store(true, .release);
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
