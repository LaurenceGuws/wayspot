//! ActionsProvider owns fixed local action candidates and their command mapping.

const std = @import("std");
const search = @import("../search/mod.zig");
const tool_check = @import("tool_check.zig");
var test_command_capture: ?[]const u8 = null;

const Dependency = union(enum) {
    none,
    command: []const u8,
    home_relative_path: []const u8,
};

pub const ActionExecution = union(enum) {
    shell_command: []const u8,
    home_relative_shell_command: []const u8,
};

pub const ActionSpec = struct {
    title: []const u8,
    subtitle: []const u8,
    action: []const u8,
    icon: []const u8,
    execution: ActionExecution,
    dependency: Dependency,
    confirm: bool = false,
    help: []const u8 = "",
};

pub const action_specs = [_]ActionSpec{
    .{
        .title = "Settings",
        .subtitle = "System",
        .action = "settings",
        .icon = "preferences-system-symbolic",
        .execution = .{ .shell_command = "wlrlui" },
        .dependency = .{ .command = "wlrlui" },
        .help = "Open the application launcher settings panel (requires `wlrlui`).",
    },
    .{
        .title = "Power menu",
        .subtitle = "Session",
        .action = "power",
        .icon = "system-shutdown-symbolic",
        .execution = .{ .shell_command = "wlogout" },
        .dependency = .{ .command = "wlogout" },
        .confirm = false,
        .help = "Open the session power/logout menu via `wlogout`.",
    },
};

pub const ActionsProvider = struct {
    command_exists_fn: *const fn (name: []const u8) bool = tool_check.commandExists,
    path_exists_fn: *const fn (path: []const u8) bool = pathExists,

    /// collect appends action candidates whose local dependencies are present.
    pub fn collect(
        self: *ActionsProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !void {
        for (action_specs) |spec| {
            if (!self.actionAvailable(spec)) continue;
            try out.append(
                allocator,
                search.Candidate.initWithIcon(
                    .action,
                    spec.title,
                    spec.subtitle,
                    spec.action,
                    spec.icon,
                ),
            );
        }
    }

    /// health reports whether the configured action commands are available.
    pub fn health(self: *ActionsProvider) search.ProviderHealth {
        var available_count: u32 = 0;
        for (action_specs) |spec| {
            if (self.actionAvailable(spec)) available_count += 1;
        }
        if (available_count == 0) return .unavailable;
        if (available_count < action_specs.len) return .degraded;
        return .ready;
    }

    fn actionAvailable(self: *ActionsProvider, spec: ActionSpec) bool {
        return switch (spec.dependency) {
            .none => true,
            .command => |name| self.command_exists_fn(name),
            .home_relative_path => |relative_path| self.homeRelativePathExists(relative_path),
        };
    }

    fn homeRelativePathExists(self: *ActionsProvider, relative_path: []const u8) bool {
        const home = if (std.c.getenv("HOME")) |value| std.mem.span(value) else return false;

        const path = std.fs.path.join(std.heap.page_allocator, &.{ home, relative_path }) catch return false;
        defer std.heap.page_allocator.free(path);

        return self.path_exists_fn(path);
    }
};

pub fn resolveActionSpec(action: []const u8) ?ActionSpec {
    for (action_specs) |spec| {
        if (std.mem.eql(u8, action, spec.action)) return spec;
    }
    return null;
}

pub fn allSpecs() []const ActionSpec {
    return action_specs[0..];
}

pub fn requiresConfirmation(action: []const u8) bool {
    for (action_specs) |spec| {
        if (std.mem.eql(u8, action, spec.action)) return spec.confirm;
    }
    return false;
}

pub fn executeAction(
    action: []const u8,
    runner: *const fn (command: []const u8) anyerror!void,
) !void {
    // `action` is an internal action id; `runner` executes the resolved runtime command.
    const spec = resolveActionSpec(action) orelse return error.UnknownAction;
    const allocator = std.heap.page_allocator;
    const command = try resolveExecutionCommand(allocator, spec.execution);
    defer allocator.free(command);
    try runner(command);
}

pub fn resolveExecutionCommand(allocator: std.mem.Allocator, execution: ActionExecution) ![]u8 {
    return switch (execution) {
        .shell_command => |command| allocator.dupe(u8, command),
        .home_relative_shell_command => |relative| resolveHomeRelativeCommand(allocator, relative),
    };
}

fn pathExists(path: []const u8) bool {
    if (std.fs.path.isAbsolute(path)) {
        std.Io.Dir.accessAbsolute(std.Options.debug_io, path, .{}) catch return false;
        return true;
    }
    std.Io.Dir.cwd().access(std.Options.debug_io, path, .{}) catch return false;
    return true;
}

fn resolveHomeRelativeCommand(allocator: std.mem.Allocator, relative_command: []const u8) ![]u8 {
    const home = if (std.c.getenv("HOME")) |value| std.mem.span(value) else ".";

    const split_idx = std.mem.indexOfScalar(u8, relative_command, ' ');
    const relative_path = if (split_idx) |idx| relative_command[0..idx] else relative_command;
    const tail = if (split_idx) |idx| relative_command[idx..] else "";
    const path = try std.fs.path.join(allocator, &.{ home, relative_path });
    defer allocator.free(path);

    return std.fmt.allocPrint(allocator, "{s}{s}", .{ path, tail });
}

test "actions provider collects available action candidates only" {
    const Fake = struct {
        fn commandExists(name: []const u8) bool {
            return !std.mem.eql(u8, name, "wlogout");
        }

        fn pathExists(path: []const u8) bool {
            return path.len == 0;
        }
    };

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    var provider_impl = ActionsProvider{
        .command_exists_fn = Fake.commandExists,
        .path_exists_fn = Fake.pathExists,
    };
    try provider_impl.collect(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(search.CandidateKind.action, list.items[0].kind);
    try std.testing.expectEqualStrings("settings", list.items[0].action);
    try std.testing.expectEqualStrings("preferences-system-symbolic", list.items[0].icon);
}

test "actions provider health reflects dependency availability" {
    const FakeAllMissing = struct {
        fn commandExists(_: []const u8) bool {
            return false;
        }

        fn pathExists(_: []const u8) bool {
            return false;
        }
    };
    const FakePartial = struct {
        fn commandExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }

        fn pathExists(_: []const u8) bool {
            return false;
        }
    };

    var none_provider_impl = ActionsProvider{
        .command_exists_fn = FakeAllMissing.commandExists,
        .path_exists_fn = FakeAllMissing.pathExists,
    };
    try std.testing.expectEqual(search.ProviderHealth.unavailable, none_provider_impl.health());

    var partial_provider_impl = ActionsProvider{
        .command_exists_fn = FakePartial.commandExists,
        .path_exists_fn = FakePartial.pathExists,
    };
    try std.testing.expectEqual(search.ProviderHealth.degraded, partial_provider_impl.health());
}

test "execute action resolves command mapping" {
    const Runner = struct {
        fn run(command: []const u8) !void {
            test_command_capture = try std.testing.allocator.dupe(u8, command);
        }
    };

    if (test_command_capture) |buf| std.testing.allocator.free(buf);
    test_command_capture = null;
    try executeAction("settings", Runner.run);
    try std.testing.expect(test_command_capture != null);
    try std.testing.expectEqualStrings("wlrlui", test_command_capture.?);
    std.testing.allocator.free(test_command_capture.?);
    test_command_capture = null;
}

test "execute action returns runner errors for failed commands" {
    const Runner = struct {
        fn run(_: []const u8) !void {
            return error.CommandFailed;
        }
    };

    try std.testing.expectError(error.CommandFailed, executeAction("settings", Runner.run));
}

test "power action has no confirmation gating" {
    try std.testing.expect(!requiresConfirmation("power"));
    try std.testing.expect(!requiresConfirmation("settings"));
}
