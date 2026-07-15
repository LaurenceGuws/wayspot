//! Entrypoint owns exact argv selection, shared picker composition, and cleanup order.

const std = @import("std");
const build_options = @import("build_options");
const wayspot = @import("wayspot");
const candidate = wayspot.picker.candidate;
const sub_cmd = wayspot.picker.sub_cmd;
const notifications_mode = wayspot.picker.mode.notifications;
const sunglasses_mode = wayspot.picker.mode.sunglasses;
const wallpaper_mode = wayspot.picker.mode.wallpaper;

/// CanonicalEntry is the exact top-level process selection result.
/// Resident values are already typed Cmd-tree values; no flag scan or second
/// Candidate representation exists after selection.
const CanonicalEntry = union(enum) {
    help,
    ui,
    cli,
    resident: candidate.Candidate,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    switch (selectEntry(args)) {
        .help => try wayspot.bufferedPrint(),
        .ui => try runPicker(allocator, args, &init, true),
        .cli => try runPicker(allocator, args, &init, false),
        .resident => |value| try runResident(allocator, &init, value),
    }
}

/// selectEntry accepts only exact canonical argv positions.
/// `--ui` is the sole GUI entry flag; resident modes are positional Cmd routes.
fn selectEntry(args: []const []const u8) CanonicalEntry {
    if (args.len == 2 and std.mem.eql(u8, args[1], "--ui")) return .ui;
    if (wayspot.cli.accepts(args)) return .cli;
    if (args.len < 2) return .help;

    if (std.mem.eql(u8, args[1], "notifications")) {
        if (args.len != 2) return .help;
        return .{ .resident = candidate.Candidate.subCmd(notifications_mode.restartSubCmd()) };
    }
    if (std.mem.eql(u8, args[1], "wallpaper")) {
        if (selectWallpaper(args)) |value| return .{ .resident = value };
        return .help;
    }
    if (std.mem.eql(u8, args[1], "sunglasses")) {
        if (selectSunglasses(args)) |value| return .{ .resident = value };
        return .help;
    }
    return .help;
}

fn selectWallpaper(args: []const []const u8) ?candidate.Candidate {
    if (args.len == 2) return candidate.Candidate.subCmd(wallpaper_mode.restartSubCmd());
    if (args.len == 3 and std.mem.eql(u8, args[2], "rotate")) {
        return candidate.Candidate.subCmd(wallpaper_mode.rotateSubCmd());
    }
    return null;
}

fn selectSunglasses(args: []const []const u8) ?candidate.Candidate {
    if (args.len == 2) return candidate.Candidate.subCmd(sunglasses_mode.restartSubCmd());
    if (args.len == 3 and std.mem.eql(u8, args[2], "apply")) {
        return candidate.Candidate.subCmd(sunglasses_mode.applySubCmd());
    }
    if (args.len == 3 and std.mem.eql(u8, args[2], "reconcile")) {
        return candidate.Candidate.subCmd(sunglasses_mode.reconcileSubCmd());
    }
    if (args.len < 5) return null;

    const monitor = args[3];
    const operation = args[4];
    if (std.mem.eql(u8, args[2], "dim")) {
        if (std.mem.eql(u8, operation, "set")) {
            if (args.len != 6) return null;
            const input = scalarInput(args[5], 0, 100) orelse return null;
            return sunglasses_mode.select(.{ .dim = .{ .set = {} } }, monitor, input) catch null;
        }
        if (args.len != 5) return null;
        return toggleSelection(.{ .dim = .{ .on = {} } }, monitor, operation) orelse
            toggleSelection(.{ .dim = .{ .off = {} } }, monitor, operation);
    }
    if (std.mem.eql(u8, args[2], "filter")) {
        if (std.mem.eql(u8, operation, "set")) {
            if (args.len != 6) return null;
            const input = scalarInput(args[5], -100, 100) orelse return null;
            return sunglasses_mode.select(.{ .filter = .{ .set = {} } }, monitor, input) catch null;
        }
        if (args.len != 5) return null;
        return toggleSelection(.{ .filter = .{ .on = {} } }, monitor, operation) orelse
            toggleSelection(.{ .filter = .{ .off = {} } }, monitor, operation);
    }
    if (std.mem.eql(u8, args[2], "image")) {
        if (std.mem.eql(u8, operation, "set")) {
            if (args.len != 6) return null;
            const input = candidate.Input.pathInput(args[5]) catch return null;
            return sunglasses_mode.select(.{ .image = .{ .set = {} } }, monitor, input) catch null;
        }
        if (std.mem.eql(u8, operation, "opacity")) {
            if (args.len != 6) return null;
            const input = scalarInput(args[5], 0, 100) orelse return null;
            return sunglasses_mode.select(.{ .image = .{ .opacity = {} } }, monitor, input) catch null;
        }
        if (std.mem.eql(u8, operation, "clear")) {
            if (args.len != 5) return null;
            return sunglasses_mode.select(.{ .image = .{ .clear = {} } }, monitor, .none) catch null;
        }
        if (args.len != 5) return null;
        return toggleSelection(.{ .image = .{ .on = {} } }, monitor, operation) orelse
            toggleSelection(.{ .image = .{ .off = {} } }, monitor, operation);
    }
    return null;
}

fn scalarInput(text: []const u8, min: i32, max: i32) ?candidate.Input {
    const value = std.fmt.parseInt(i32, text, 10) catch return null;
    return candidate.Input.scalarInput(value, min, max, 1) catch null;
}

fn toggleSelection(route: sub_cmd.SunglassesSubCmd, monitor: []const u8, operation: []const u8) ?candidate.Candidate {
    const enabled = if (std.mem.eql(u8, operation, "on")) true else if (std.mem.eql(u8, operation, "off")) false else return null;
    return sunglasses_mode.select(route, monitor, candidate.Input.toggleInput(enabled)) catch null;
}

fn runPicker(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    init: *const std.process.Init,
    ui: bool,
) !void {
    const home = init.minimal.environ.getPosix("HOME") orelse ".";
    var picker_bundle = try setupPickerBundle(allocator, home);
    picker_bundle.wirePicker();
    defer picker_bundle.deinit(allocator);

    if (ui) {
        if (!build_options.enable_sdl) {
            std.log.err("UI mode requires SDL build", .{});
            std.process.exit(2);
        }
        try wayspot.identity.set(wayspot.identity.picker);
        try wayspot.gui.run(allocator, &picker_bundle.picker, home);
    } else {
        if (std.mem.eql(u8, args[1], "--icon-diag") and !build_options.enable_sdl) {
            std.log.err("icon diagnostic requires SDL build", .{});
            std.process.exit(2);
        }
        try wayspot.cli.run(allocator, args, &picker_bundle.picker, home);
    }
}

fn runResident(allocator: std.mem.Allocator, init: *const std.process.Init, value: candidate.Candidate) !void {
    switch (value) {
        .sub_cmd => |route| try runSubCmd(allocator, init, route),
        .concrete => |leaf| try runConcrete(allocator, init, leaf),
    }
}

fn runSubCmd(allocator: std.mem.Allocator, init: *const std.process.Init, route: sub_cmd.SubCmd) !void {
    switch (route) {
        .notifications => |value| switch (value) {
            .restart => try wayspot.notification.run(allocator),
            .history => return error.NotificationDisplayOnly,
        },
        .wallpaper => |value| try runWallpaper(allocator, init, value),
        .sunglasses => |value| try runSunglasses(allocator, init, value),
    }
}

fn runConcrete(allocator: std.mem.Allocator, init: *const std.process.Init, value: candidate.Concrete) !void {
    switch (value) {
        .lifecycle => |leaf| try runLifecycle(allocator, init, leaf),
        .app, .open => return error.CandidateNotLaunchable,
        .notification => return error.NotificationDisplayOnly,
    }
}

fn runLifecycle(allocator: std.mem.Allocator, init: *const std.process.Init, value: candidate.Lifecycle) !void {
    switch (value) {
        .notifications_restart => try wayspot.notification.run(allocator),
        .wallpaper_restart => try runWallpaper(allocator, init, .restart),
        .wallpaper_rotate => try runWallpaper(allocator, init, .rotate),
        .sunglasses_restart => try runSunglasses(allocator, init, .restart),
        .sunglasses_apply => try runSunglasses(allocator, init, .apply),
        .sunglasses_reconcile => try runSunglasses(allocator, init, .reconcile),
        .sunglasses_dim, .sunglasses_filter, .sunglasses_image => {
            const runtime_dir = try runtimeDir(init);
            try wayspot.sunglasses.applyLeaf(allocator, runtime_dir, value);
        },
    }
}

fn runWallpaper(allocator: std.mem.Allocator, init: *const std.process.Init, value: sub_cmd.WallpaperSubCmd) !void {
    const runtime_dir = try runtimeDir(init);
    switch (value) {
        .restart => {
            const signature = try instanceSignature(init);
            try wayspot.wallpaper.run(allocator, wayspot.env.MonitorSource.init(.{
                .runtime_dir = runtime_dir,
                .signature = signature,
            }));
        },
        .rotate => try wayspot.wallpaper.rotateNow(allocator, runtime_dir),
    }
}

fn runSunglasses(allocator: std.mem.Allocator, init: *const std.process.Init, value: sub_cmd.SunglassesSubCmd) !void {
    switch (value) {
        .restart => {
            const runtime_dir = try runtimeDir(init);
            const signature = try instanceSignature(init);
            try wayspot.sunglasses.run(allocator, wayspot.env.MonitorSource.init(.{
                .runtime_dir = runtime_dir,
                .signature = signature,
            }));
        },
        .apply => try wayspot.sunglasses.applyNow(allocator, try runtimeDir(init)),
        .reconcile => try wayspot.sunglasses.reconcileSavedState(allocator, try runtimeDir(init)),
        .dim, .filter, .image => return error.CandidateNotLaunchable,
    }
}

fn runtimeDir(init: *const std.process.Init) ![]const u8 {
    return init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse error.HyprlandRuntimeDirMissing;
}

fn instanceSignature(init: *const std.process.Init) ![]const u8 {
    return init.minimal.environ.getPosix("HYPRLAND_INSTANCE_SIGNATURE") orelse error.HyprlandInstanceSignatureMissing;
}

const PickerBundle = struct {
    app_cache_path: []u8,
    history_path: []u8,
    notification_history: wayspot.notification.history_list.NotificationHistoryList = .{},
    apps: wayspot.picker.mode.apps.Apps,
    picker: wayspot.picker.Picker,

    fn deinit(self: *PickerBundle, allocator: std.mem.Allocator) void {
        self.picker.deinit(allocator);
        self.notification_history.deinit(allocator);
        self.apps.deinit(allocator);
        allocator.free(self.app_cache_path);
        allocator.free(self.history_path);
    }

    fn wirePicker(self: *PickerBundle) void {
        self.picker = wayspot.picker.Picker.initWithHistoryPath(&self.apps, self.history_path);
        self.picker.notification_history = &self.notification_history;
        self.picker.max_history = 64;
    }
};

fn setupPickerBundle(allocator: std.mem.Allocator, home: []const u8) !PickerBundle {
    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    errdefer allocator.free(app_cache);
    const history_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/wayspot/history.log", .{home});
    errdefer allocator.free(history_path);

    return .{
        .app_cache_path = app_cache,
        .history_path = history_path,
        .apps = wayspot.picker.mode.apps.Apps.init(app_cache),
        .picker = undefined,
    };
}

fn expectHelp(args: []const []const u8) !void {
    switch (selectEntry(args)) {
        .help => {},
        else => return error.ExpectedHelp,
    }
}

fn expectSubCmd(args: []const []const u8, expected: sub_cmd.SubCmd) !void {
    switch (selectEntry(args)) {
        .resident => |value| switch (value) {
            .sub_cmd => |route| try std.testing.expectEqual(expected, route),
            .concrete => return error.ExpectedSubCmd,
        },
        else => return error.ExpectedSubCmd,
    }
}

test "selectEntry routes canonical resident modes through owning SubCmds" {
    try expectSubCmd(&.{ "wayspot", "notifications" }, notifications_mode.restartSubCmd());
    try expectSubCmd(&.{ "wayspot", "wallpaper" }, wallpaper_mode.restartSubCmd());
    try expectSubCmd(&.{ "wayspot", "wallpaper", "rotate" }, wallpaper_mode.rotateSubCmd());
    try expectSubCmd(&.{ "wayspot", "sunglasses" }, sunglasses_mode.restartSubCmd());
    try expectSubCmd(&.{ "wayspot", "sunglasses", "apply" }, sunglasses_mode.applySubCmd());
    try expectSubCmd(&.{ "wayspot", "sunglasses", "reconcile" }, sunglasses_mode.reconcileSubCmd());
}

test "selectEntry constructs typed sunglasses leaves from canonical argv" {
    switch (selectEntry(&.{ "wayspot", "sunglasses", "dim", "DP-1", "set", "35" })) {
        .resident => |value| switch (value) {
            .concrete => |leaf| switch (leaf) {
                .lifecycle => |lifecycle| switch (lifecycle) {
                    .sunglasses_dim => |monitor| {
                        try std.testing.expectEqualStrings("DP-1", monitor.monitor.slice());
                        try std.testing.expectEqual(std.meta.Tag(candidate.Input).scalar, std.meta.activeTag(monitor.input));
                    },
                    else => return error.ExpectedDimLeaf,
                },
                else => return error.ExpectedLifecycleLeaf,
            },
            .sub_cmd => return error.ExpectedConcreteLeaf,
        },
        else => return error.ExpectedConcreteLeaf,
    }

    switch (selectEntry(&.{ "wayspot", "sunglasses", "image", "DP-1", "clear" })) {
        .resident => |value| switch (value) {
            .concrete => |leaf| switch (leaf) {
                .lifecycle => |lifecycle| switch (lifecycle) {
                    .sunglasses_image => |monitor| try std.testing.expectEqual(std.meta.Tag(candidate.Input).none, std.meta.activeTag(monitor.input)),
                    else => return error.ExpectedImageLeaf,
                },
                else => return error.ExpectedLifecycleLeaf,
            },
            .sub_cmd => return error.ExpectedConcreteLeaf,
        },
        else => return error.ExpectedConcreteLeaf,
    }
}

test "selectEntry keeps apps CLI and UI entry boundaries exact" {
    switch (selectEntry(&.{ "wayspot", "apps" })) {
        .cli => {},
        else => return error.ExpectedCliEntry,
    }
    switch (selectEntry(&.{ "wayspot", "--ui" })) {
        .ui => {},
        else => return error.ExpectedUiEntry,
    }
    try expectHelp(&.{ "wayspot", "--ui", "apps" });
    try expectHelp(&.{ "wayspot", "unknown" });
}

test "selectEntry rejects every legacy resident flag" {
    try expectHelp(&.{ "wayspot", "--notifications-daemon" });
    try expectHelp(&.{ "wayspot", "--wallpaper" });
    try expectHelp(&.{ "wayspot", "--next-wallpaper" });
    try expectHelp(&.{ "wayspot", "--wallpaper-rotate-now" });
    try expectHelp(&.{ "wayspot", "--sunglasses-daemon" });
    try expectHelp(&.{ "wayspot", "--sunglasses-apply" });
    try expectHelp(&.{ "wayspot", "--sunglasses-reconcile" });
    try expectHelp(&.{ "wayspot", "--sunglasses-set-image", "DP-1", "/tmp/image.png" });
    try expectHelp(&.{ "wayspot", "--sunglasses-clear-image", "DP-1" });
}

test "resident identity names remain explicit" {
    try std.testing.expectEqualStrings("wayspot-notify", wayspot.identity.notifications);
    try std.testing.expectEqualStrings("wayspot-wall", wayspot.identity.wallpaper);
    try std.testing.expectEqualStrings("wayspot-sunglas", wayspot.identity.sunglasses);
}
