const std = @import("std");
const wayspot = @import("wayspot");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const home = init.minimal.environ.getPosix("HOME") orelse ".";

    if (hasArg(args, "--notifications-daemon")) {
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

    if (hasArg(args, "--wallpaper-lifecycle-proof")) {
        const runtime_dir = init.minimal.environ.getPosix("XDG_RUNTIME_DIR") orelse return error.HyprlandRuntimeDirMissing;
        const signature = init.minimal.environ.getPosix("HYPRLAND_INSTANCE_SIGNATURE") orelse return error.HyprlandInstanceSignatureMissing;
        try runWallpaperLifecycleProof(allocator, .{
            .runtime_dir = runtime_dir,
            .signature = signature,
        });
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

    try wayspot.bufferedPrint();
}

fn runUi(allocator: std.mem.Allocator, home: []const u8) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("UI mode requires SDL build", .{});
        std.process.exit(2);
    }

    var runtime = try setupRuntime(allocator, home);
    runtime.wireProviders();
    defer runtime.deinit(allocator);
    try runtime.service.loadHistory(allocator);
    defer runtime.service.saveHistory(allocator) catch |err| {
        std.log.err("failed to save history: {s}", .{@errorName(err)});
    };

    try wayspot.ui.Shell.run(allocator, &runtime.service);
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

fn runWallpaperLifecycleProof(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("wallpaper lifecycle proof requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.wallpaper.Runtime.runLifecycleProof(allocator, hypr);
}

fn runWallpaper(allocator: std.mem.Allocator, hypr: wayspot.wallpaper.hyprland.Connection) !void {
    if (!wayspot.ui.sdl_enabled) {
        std.log.err("wallpaper daemon requires SDL build", .{});
        std.process.exit(2);
    }

    try wayspot.wallpaper.Runtime.runWallpaper(allocator, hypr);
}

const Runtime = struct {
    app_cache_path: []u8,
    history_path: []u8,
    actions: wayspot.providers.ActionsProvider = .{},
    apps: wayspot.providers.AppsProvider,
    service: wayspot.app.SearchService,

    fn deinit(self: *Runtime, allocator: std.mem.Allocator) void {
        self.service.deinit(allocator);
        self.apps.deinit(allocator);
        allocator.free(self.app_cache_path);
        allocator.free(self.history_path);
    }

    fn wireProviders(self: *Runtime) void {
        self.service = wayspot.app.SearchService.initWithHistoryPath(&self.actions, &self.apps, self.history_path);
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
