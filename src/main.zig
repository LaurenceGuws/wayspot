//! Entrypoint owns CLI mode selection and top-level cleanup order.

const std = @import("std");
const build_options = @import("build_options");
const wayspot = @import("wayspot");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const home = init.minimal.environ.getPosix("HOME") orelse ".";

    if (hasArg(args, "--notifications-daemon")) {
        try wayspot.identity.set(wayspot.identity.notifications);
        try wayspot.notification.run(allocator);
        return;
    }

    if (hasArg(args, "--ui")) {
        try runUi(allocator, home);
        return;
    }

    if (hasArg(args, "--icon-diag")) {
        try runIconDiag(allocator, home);
        return;
    }

    if (hasArg(args, "--icon-cache-refresh")) {
        try runIconCacheRefresh(allocator, home);
        return;
    }

    if (hasArg(args, "--next-wallpaper") or hasArg(args, "--wallpaper-rotate-now")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try wayspot.wallpaper.Loop.rotateNow(allocator, runtime_dir);
        return;
    }

    if (hasArg(args, "--wallpaper")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        const signature = init.minimal.environ.getPosix("HYPRLAND_INSTANCE_SIGNATURE") orelse return error.HyprlandInstanceSignatureMissing;
        runWallpaperLoop(allocator, .{
            .runtime_dir = runtime_dir,
            .signature = signature,
        }) catch |err| {
            std.log.err("wallpaper loop failed: {s}", .{@errorName(err)});
            std.process.exit(2);
        };
        return;
    }

    if (hasArg(args, "--sunglasses-apply")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try wayspot.sunglasses.Overlay.applyNow(allocator, runtime_dir);
        return;
    }

    if (hasArg(args, "--sunglasses-reconcile")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try wayspot.sunglasses.Overlay.reconcileSavedState(allocator, runtime_dir);
        return;
    }

    if (sunglassesImageCommand(args)) |command| {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try applySunglassesImageCommand(allocator, runtime_dir, command);
        return;
    }

    if (hasArg(args, "--sunglasses-daemon")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        const signature = init.minimal.environ.getPosix("HYPRLAND_INSTANCE_SIGNATURE") orelse return error.HyprlandInstanceSignatureMissing;
        runSunglassesOverlay(allocator, .{
            .runtime_dir = runtime_dir,
            .signature = signature,
        }) catch |err| {
            std.log.err("sunglasses overlay failed: {s}", .{@errorName(err)});
            std.process.exit(2);
        };
        return;
    }

    try wayspot.bufferedPrint();
}

fn runUi(allocator: std.mem.Allocator, home: []const u8) !void {
    if (!build_options.enable_sdl) {
        std.log.err("UI mode requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.identity.set(wayspot.identity.picker);
    var picker_bundle = try setupPickerBundle(allocator, home);
    picker_bundle.wirePicker();
    defer picker_bundle.deinit(allocator);
    try picker_bundle.picker.loadHistory(allocator);
    defer picker_bundle.picker.saveHistory(allocator) catch |err| {
        std.log.err("failed to save history: {s}", .{@errorName(err)});
    };

    try wayspot.picker.surface.run(allocator, &picker_bundle.picker, home);
}

fn runIconDiag(allocator: std.mem.Allocator, home: []const u8) !void {
    if (!build_options.enable_sdl) {
        std.log.err("icon diagnostic requires SDL build", .{});
        std.process.exit(2);
    }

    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    defer allocator.free(app_cache);

    var apps = wayspot.picker.mode.apps.Apps.init(app_cache);
    defer apps.deinit(allocator);
    var candidates = wayspot.picker.candidate.Candidate.List.empty;
    defer candidates.deinit(allocator);

    try apps.collect(allocator, &candidates);
    try wayspot.picker.icon_diag.writeReceipt(candidates.items);
}

fn runIconCacheRefresh(allocator: std.mem.Allocator, home: []const u8) !void {
    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    defer allocator.free(app_cache);

    var apps = wayspot.picker.mode.apps.Apps.init(app_cache);
    defer apps.deinit(allocator);
    var candidates = wayspot.picker.candidate.Candidate.List.empty;
    defer candidates.deinit(allocator);

    try apps.collect(allocator, &candidates);
    const counts = try wayspot.picker.icon_cache.refresh(home, candidates.items);
    try wayspot.picker.icon_cache.printRefreshSummary(counts);
}

fn runWallpaperLoop(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!build_options.enable_sdl) {
        std.log.err("wallpaper loop requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.identity.set(wayspot.identity.wallpaper);
    try wayspot.wallpaper.Loop.run(allocator, hypr);
}

fn runSunglassesOverlay(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!build_options.enable_sdl) {
        std.log.err("sunglasses overlay requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.identity.set(wayspot.identity.sunglasses);
    try wayspot.sunglasses.Overlay.runOverlay(allocator, hypr);
}

const SunglassesImageCommand = union(enum) {
    set: struct {
        monitor: []const u8,
        path: []const u8,
    },
    clear: struct {
        monitor: []const u8,
    },
};

fn sunglassesImageCommand(args: []const []const u8) ?SunglassesImageCommand {
    if (args.len == 4 and std.mem.eql(u8, args[1], "--sunglasses-set-image")) {
        return .{ .set = .{
            .monitor = args[2],
            .path = args[3],
        } };
    }
    if (args.len == 3 and std.mem.eql(u8, args[1], "--sunglasses-clear-image")) {
        return .{ .clear = .{
            .monitor = args[2],
        } };
    }
    return null;
}

fn applySunglassesImageCommand(
    allocator: std.mem.Allocator,
    runtime_dir: []const u8,
    command: SunglassesImageCommand,
) !void {
    var state = try wayspot.sunglasses.state.load(allocator);
    switch (command) {
        .set => |set| {
            const monitor = try state.ensureMonitor(set.monitor);
            try monitor.setImagePath(set.path);
        },
        .clear => |clear| {
            const monitor = try state.ensureMonitor(clear.monitor);
            monitor.image_enabled = false;
            monitor.clearImagePath();
        },
    }
    try wayspot.sunglasses.state.save(state, allocator);
    try wayspot.sunglasses.Overlay.reconcileSavedState(allocator, runtime_dir);
}

const PickerBundle = struct {
    app_cache_path: []u8,
    history_path: []u8,
    opens: wayspot.picker.open.Open = .{},
    modes: wayspot.picker.mode.Mode = .{},
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
        self.picker = wayspot.picker.Picker.initWithHistoryPath(&self.opens, &self.apps, &self.modes, self.history_path);
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

fn hasArg(args: []const []const u8, needle: []const u8) bool {
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, needle)) return true;
    }
    return false;
}

test "sunglasses image command parser accepts exact hidden setter and clearer" {
    const set_args = [_][]const u8{ "wayspot", "--sunglasses-set-image", "DP-1", "/tmp/overlay.png" };
    const set = sunglassesImageCommand(&set_args) orelse return error.ExpectedSetImageCommand;
    switch (set) {
        .set => |value| {
            try std.testing.expectEqualStrings("DP-1", value.monitor);
            try std.testing.expectEqualStrings("/tmp/overlay.png", value.path);
        },
        .clear => return error.ExpectedSetImageCommand,
    }

    const clear_args = [_][]const u8{ "wayspot", "--sunglasses-clear-image", "DP-1" };
    const clear = sunglassesImageCommand(&clear_args) orelse return error.ExpectedClearImageCommand;
    switch (clear) {
        .set => return error.ExpectedClearImageCommand,
        .clear => |value| try std.testing.expectEqualStrings("DP-1", value.monitor),
    }
}

test "sunglasses image command parser rejects partial hidden commands" {
    const missing_path = [_][]const u8{ "wayspot", "--sunglasses-set-image", "DP-1" };
    try std.testing.expect(sunglassesImageCommand(&missing_path) == null);

    const extra_arg = [_][]const u8{ "wayspot", "--sunglasses-clear-image", "DP-1", "/tmp/overlay.png" };
    try std.testing.expect(sunglassesImageCommand(&extra_arg) == null);
}
