const std = @import("std");
const wayspot = @import("wayspot");

pub fn main(init: std.process.Init) !void {
    const startup_sw = wayspot.app.Stopwatch.start();
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const home = init.minimal.environ.getPosix("HOME") orelse ".";

    if (hasArg(args, "--ctl")) {
        const raw_cmd = argValueAfterFlag(args, "--ctl") orelse {
            try printCtlUsage();
            return;
        };
        if (std.mem.eql(u8, raw_cmd, "--help")) {
            try printCtlUsage();
            return;
        }
        const cmd = parseControlCommand(raw_cmd) orelse std.process.exit(13);
        const response = wayspot.ipc.control.executeCommand(allocator, cmd) catch |err| {
            std.log.err("control command failure route={s} err={s}", .{ raw_cmd, @errorName(err) });
            std.process.exit(10);
        };
        defer {
            allocator.free(response.code);
            allocator.free(response.message);
        }
        if (response.ok and std.mem.eql(u8, response.code, "ok")) {
            if (response.message.len > 0 and cmd == .version) {
                try printLine(response.message);
            }
            std.process.exit(0);
        }
        std.log.err(
            "control command rejected route={s} exit_code={s} elapsed_ns={d} message={s}",
            .{ raw_cmd, response.code, response.elapsed_ns, response.message },
        );
        std.process.exit(10);
    }

    if (hasArg(args, "--print-config")) {
        const cfg = wayspot.config.load();
        try printResolvedConfig(cfg);
        return;
    }

    const ui_mode = hasArg(args, "--ui") or hasArg(args, "--ui-resident") or hasArg(args, "--ui-daemon");
    if (ui_mode) {
        if (!wayspot.ui.sdl_enabled) {
            std.log.err("UI mode requires SDL build", .{});
            std.process.exit(2);
        }

        const cfg = wayspot.config.load();

        const resident_mode = hasArg(args, "--ui-resident") or hasArg(args, "--ui-daemon");
        const start_hidden = hasArg(args, "--ui-daemon");
        if (resident_mode and isCommandOk(allocator, .ping)) {
            if (!start_hidden) {
                const summoned = isCommandOk(allocator, .summon);
                if (!summoned) std.log.debug("resident shell pinged but summon failed", .{});
            }
            return;
        }
        if (!resident_mode and hasArg(args, "--ui") and isCommandOk(allocator, .summon)) return;

        var runtime = try setupRuntime(allocator, home);
        runtime.wireProviders();
        defer runtime.deinit(allocator);
        try runtime.service.loadHistory(allocator);
        defer runtime.service.saveHistory(allocator) catch |err| {
            std.log.err("failed to save history: {s}", .{@errorName(err)});
        };

        std.log.info("runtime ready in {d:.2} ms", .{startup_sw.elapsedMs()});
        try wayspot.ui.Shell.run(allocator, &runtime.service, &runtime.telemetry, .{
            .resident_mode = resident_mode,
            .start_hidden = start_hidden,
            .surface_mode = cfg.surface_mode,
            .placement_policy = cfg.placement_policy,
            .show_nerd_stats = cfg.ui.show_nerd_stats,
            .notifications_show_close_button = cfg.notifications.show_close_button,
            .notifications_show_dbus_actions = cfg.notifications.show_dbus_actions,
        });
        return;
    }

    std.log.info("startup ready in {d:.2} ms", .{startup_sw.elapsedMs()});
    try wayspot.bufferedPrint();
}

const Runtime = struct {
    app_cache_path: []u8,
    history_path: []u8,
    telemetry_path: []u8,
    actions: wayspot.providers.ActionsProvider = .{},
    apps: wayspot.providers.AppsProvider,
    provider_list: [2]wayspot.providers.Provider,
    service: wayspot.app.SearchService,
    telemetry: wayspot.app.TelemetrySink,

    fn deinit(self: *Runtime, allocator: std.mem.Allocator) void {
        self.apps.deinit(allocator);
        self.service.deinit(allocator);
        allocator.free(self.app_cache_path);
        allocator.free(self.history_path);
        allocator.free(self.telemetry_path);
    }

    fn wireProviders(self: *Runtime) void {
        self.provider_list = .{
            .{ .actions = &self.actions },
            .{ .apps = &self.apps },
        };
        const registry = wayspot.providers.ProviderRegistry.init(&self.provider_list);
        self.service = wayspot.app.SearchService.initWithHistoryPath(registry, self.history_path);
        self.service.max_history = 64;
    }
};

fn setupRuntime(allocator: std.mem.Allocator, home: []const u8) !Runtime {
    const app_cache = try std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home});
    errdefer allocator.free(app_cache);
    const history_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/wayspot/history.log", .{home});
    errdefer allocator.free(history_path);
    const telemetry_path = try std.fmt.allocPrint(allocator, "{s}/.local/state/wayspot/telemetry.log", .{home});
    errdefer allocator.free(telemetry_path);

    var runtime = Runtime{
        .app_cache_path = app_cache,
        .history_path = history_path,
        .telemetry_path = telemetry_path,
        .apps = wayspot.providers.AppsProvider.init(app_cache),
        .provider_list = undefined,
        .service = undefined,
        .telemetry = undefined,
    };

    runtime.telemetry = wayspot.app.TelemetrySink.init(telemetry_path);
    return runtime;
}

fn isCommandOk(allocator: std.mem.Allocator, cmd: wayspot.ipc.control.Command) bool {
    const response = wayspot.ipc.control.executeCommand(allocator, cmd) catch return false;
    defer {
        allocator.free(response.code);
        allocator.free(response.message);
    }
    return response.ok and std.mem.eql(u8, response.code, "ok");
}

fn printCtlUsage() !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const out = &stdout_writer.interface;
    try out.print(
        \\Usage: wayspot --ctl <command>
        \\Commands: ping, summon, hide, toggle, version
        \\
    , .{});
    try out.flush();
}

fn printLine(message: []const u8) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const out = &stdout_writer.interface;
    try out.print("{s}\n", .{message});
    try out.flush();
}

fn hasArg(args: []const []const u8, needle: []const u8) bool {
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, needle)) return true;
    }
    return false;
}

fn argValueAfterFlag(args: []const []const u8, flag: []const u8) ?[]const u8 {
    if (args.len < 3) return null;
    var i: u32 = 1;
    while (i + 1 < args.len) : (i += 1) {
        const index: u32 = i;
        if (std.mem.eql(u8, args[index], flag)) return args[index + 1];
    }
    return null;
}

fn parseControlCommand(value: []const u8) ?wayspot.ipc.control.Command {
    if (std.mem.eql(u8, value, "ping")) return .ping;
    if (std.mem.eql(u8, value, "summon")) return .summon;
    if (std.mem.eql(u8, value, "hide")) return .hide;
    if (std.mem.eql(u8, value, "toggle")) return .toggle;
    if (std.mem.eql(u8, value, "version")) return .version;
    return null;
}

fn printResolvedConfig(cfg: wayspot.config.Settings) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const out = &stdout_writer.interface;

    try out.print(
        \\{{
        \\  "surface_mode": "{s}",
        \\  "notifications": {{
        \\    "actions": {{
        \\      "show_close_button": {s},
        \\      "show_dbus_actions": {s}
        \\    }}
        \\  }}
        \\}}
        \\
    , .{
        @tagName(cfg.surface_mode),
        if (cfg.notifications.show_close_button) "true" else "false",
        if (cfg.notifications.show_dbus_actions) "true" else "false",
    });

    try out.flush();
}
