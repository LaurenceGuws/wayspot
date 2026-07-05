const std = @import("std");
const wayspot = @import("wayspot");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const home = init.minimal.environ.getPosix("HOME") orelse ".";

    if (hasArg(args, "--notifications-daemon")) {
        try wayspot.process_identity.set(wayspot.process_identity.notifications);
        try wayspot.notifications.run(allocator);
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
        try wayspot.wallpaper.Runtime.rotateNow(allocator, runtime_dir);
        return;
    }

    if (hasArg(args, "--wallpaper")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        const signature = init.minimal.environ.getPosix("HYPRLAND_INSTANCE_SIGNATURE") orelse return error.HyprlandInstanceSignatureMissing;
        runWallpaper(allocator, .{
            .runtime_dir = runtime_dir,
            .signature = signature,
        }) catch |err| {
            std.log.err("wallpaper daemon failed: {s}", .{@errorName(err)});
            std.process.exit(2);
        };
        return;
    }

    if (hasArg(args, "--sunglasses-apply")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try wayspot.sunglasses.Runtime.applyNow(allocator, runtime_dir);
        return;
    }

    if (hasArg(args, "--sunglasses-reconcile")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        try wayspot.sunglasses.Runtime.reconcileSavedState(allocator, runtime_dir);
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
        runSunglassesDaemon(allocator, .{
            .runtime_dir = runtime_dir,
            .signature = signature,
        }) catch |err| {
            std.log.err("sunglasses daemon failed: {s}", .{@errorName(err)});
            std.process.exit(2);
        };
        return;
    }

    try wayspot.bufferedPrint();
}

fn runUi(allocator: std.mem.Allocator, home: []const u8) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("UI mode requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.process_identity.set(wayspot.process_identity.picker);
    var runtime = try setupRuntime(allocator, home);
    runtime.wireProviders();
    defer runtime.deinit(allocator);
    try runtime.service.loadHistory(allocator);
    defer runtime.service.saveHistory(allocator) catch |err| {
        std.log.err("failed to save history: {s}", .{@errorName(err)});
    };

    try wayspot.ui.Shell.run(allocator, &runtime.service, home);
}

fn runIconDiag(allocator: std.mem.Allocator, home: []const u8) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("icon diagnostic requires SDL build", .{});
        std.process.exit(2);
    }

    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    defer allocator.free(app_cache);

    var apps = wayspot.providers.AppsProvider.init(app_cache);
    defer apps.deinit(allocator);
    var candidates = wayspot.search.CandidateList.empty;
    defer candidates.deinit(allocator);

    try apps.collect(allocator, &candidates);
    try wayspot.ui.app_icon_diag.writeReceipt(candidates.items);
}

fn runIconCacheRefresh(allocator: std.mem.Allocator, home: []const u8) !void {
    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    defer allocator.free(app_cache);

    var apps = wayspot.providers.AppsProvider.init(app_cache);
    defer apps.deinit(allocator);
    var candidates = wayspot.search.CandidateList.empty;
    defer candidates.deinit(allocator);

    try apps.collect(allocator, &candidates);
    const counts = try wayspot.ui.app_icon_cache.refresh(home, candidates.items);
    try wayspot.ui.app_icon_cache.printRefreshSummary(counts);
}

fn runWallpaper(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("wallpaper daemon requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.process_identity.set(wayspot.process_identity.wallpaper);
    try wayspot.wallpaper.Runtime.runWallpaper(allocator, hypr);
}

fn runSunglassesDaemon(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("sunglasses daemon requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.process_identity.set(wayspot.process_identity.sunglasses);
    try wayspot.sunglasses.Runtime.runDaemon(allocator, hypr);
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
    try wayspot.sunglasses.Runtime.reconcileSavedState(allocator, runtime_dir);
}

const Runtime = struct {
    app_cache_path: []u8,
    history_path: []u8,
    actions: wayspot.providers.ActionsProvider = .{},
    modes: wayspot.providers.ModesProvider = .{},
    notification_history: wayspot.providers.NotificationHistoryProvider = .{},
    apps: wayspot.providers.AppsProvider,
    service: wayspot.app.SearchService,

    fn deinit(self: *Runtime, allocator: std.mem.Allocator) void {
        self.service.deinit(allocator);
        self.notification_history.deinit(allocator);
        self.apps.deinit(allocator);
        allocator.free(self.app_cache_path);
        allocator.free(self.history_path);
    }

    fn wireProviders(self: *Runtime) void {
        self.service = wayspot.app.SearchService.initWithHistoryPath(&self.actions, &self.apps, &self.modes, self.history_path);
        self.service.notification_history = &self.notification_history;
        self.service.max_history = 64;
    }
};

fn setupRuntime(allocator: std.mem.Allocator, home: []const u8) !Runtime {
    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    errdefer allocator.free(app_cache);
    const history_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/wayspot/history.log", .{home});
    errdefer allocator.free(history_path);

    return .{
        .app_cache_path = app_cache,
        .history_path = history_path,
        .apps = wayspot.providers.AppsProvider.init(app_cache),
        .service = undefined,
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
