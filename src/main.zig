//! Starts one native Wayspot beta picker process.

const std = @import("std");
const apps = @import("apps.zig");
const cli = @import("cli.zig");
const desktop_files = @import("desktop_files.zig");
const launch = @import("launch.zig");
const notification_dbus = @import("notification_dbus.zig");
const notification_dbus_native = @import("notification_dbus_native.zig");
const notification_banner_sdl = @import("notification_banner_sdl.zig");
const notification_bridge = @import("notification_bridge.zig");
const picker = @import("picker.zig");
const sdl = @import("sdl.zig");

var notification_stop: std.atomic.Value(bool) = .init(false);

pub fn main(init: std.process.Init) !u8 {
    var argument_iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer argument_iterator.deinit();
    std.debug.assert(argument_iterator.skip());
    var arguments: [cli.argument_capacity][]const u8 = undefined;
    var argument_count: usize = 0;
    while (argument_iterator.next()) |argument| {
        if (argument_count == arguments.len) return error.TooManyArguments;
        arguments[argument_count] = argument;
        argument_count += 1;
    }

    if (argument_count == 1 and std.mem.eql(u8, arguments[0], "notifications")) {
        try runNotifications(init);
        return 0;
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
        var stdout_buffer: [4096]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
        const stdout = &stdout_writer.interface;
        const selected = cli.run(stdout, arguments[0..argument_count], applications.slice()) catch |err| {
            try stdout.flush();
            return switch (err) {
                error.ArgumentsInvalid,
                error.QueryInvalid,
                error.QueryTooLong,
                error.ApplicationAmbiguous,
                error.ApplicationNotFound,
                => 2,
                else => |other| return other,
            };
        };
        try stdout.flush();
        if (selected) |index| {
            var process = launch.Native{ .io = init.io };
            try launch.spawn(&process, &applications.slice()[index], terminal, home);
        }
        return 0;
    }

    logApplications(&files, &applications);
    var native: sdl.Native = .{
        .applications = applications.slice(),
        .allocator = init.gpa,
        .io = init.io,
        .home = home,
    };
    if (try picker.run(&native, applications.slice())) |index| {
        var process = launch.Native{ .io = init.io };
        try launch.spawn(&process, &applications.slice()[index], terminal, home);
    }
    return 0;
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

    var bridge: notification_bridge.Bridge = undefined;
    bridge.init(init.io);
    defer bridge.deinit(init.gpa);
    var native: notification_dbus_native.Native = .{ .stop = &notification_stop };
    var worker = try init.io.concurrent(notificationWorker, .{ &native, &bridge, init.gpa });

    const banner_result = notification_banner_sdl.run(&bridge, init.gpa);
    if (banner_result) {
        notification_stop.store(true, .release);
    } else |_| {
        notification_stop.store(true, .release);
        bridge.bannerFailed();
    }
    const worker_result = worker.await(init.io);
    try banner_result;
    try worker_result;
}

fn notificationWorker(
    native: *notification_dbus_native.Native,
    bridge: *notification_bridge.Bridge,
    allocator: std.mem.Allocator,
) !void {
    notification_dbus.runWithBanner(native, bridge, allocator) catch |err| {
        bridge.workerFailed();
        return err;
    };
    try bridge.workerStopped();
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
        const count = applications.report.decisions[@intFromEnum(decision)];
        if (count > 0) std.log.info("desktop decision={s} count={d}", .{ @tagName(decision), count });
    }
    for (std.enums.values(apps.Issue)) |issue| {
        const count = applications.report.issues[@intFromEnum(issue)];
        if (count > 0) std.log.info("desktop issue={s} count={d}", .{ @tagName(issue), count });
    }
}
