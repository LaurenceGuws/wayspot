//! Open owns fixed local picker rows and their launch command mapping.

const std = @import("std");
const candidate_mod = @import("picker_candidate");
var test_command_capture: ?[]const u8 = null;

const Dependency = union(enum) {
    none,
    command: []const u8,
    home_relative_path: []const u8,
};

pub const Execution = union(enum) {
    shell_command: []const u8,
    home_relative_shell_command: []const u8,
};

pub const Spec = struct {
    title: []const u8,
    subtitle: []const u8,
    open: []const u8,
    icon: []const u8,
    execution: Execution,
    dependency: Dependency,
};

pub const specs = [_]Spec{
    .{
        .title = "Settings",
        .subtitle = "System",
        .open = "settings",
        .icon = "preferences-system-symbolic",
        .execution = .{ .shell_command = "wlrlui" },
        .dependency = .{ .command = "wlrlui" },
    },
    .{
        .title = "Power menu",
        .subtitle = "Session",
        .open = "power",
        .icon = "system-shutdown-symbolic",
        .execution = .{ .shell_command = "wlogout" },
        .dependency = .{ .command = "wlogout" },
    },
};

pub const Open = struct {
    command_exists_fn: *const fn (name: []const u8) bool = commandExists,
    path_exists_fn: *const fn (path: []const u8) bool = pathExists,

    /// collect appends fixed open rows whose local dependencies are present.
    pub fn collect(
        self: *Open,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
    ) !void {
        for (specs) |spec| {
            if (!self.openAvailable(spec)) continue;
            try out.append(
                allocator,
                candidate_mod.Candidate.initWithIcon(
                    .open,
                    spec.title,
                    spec.subtitle,
                    spec.open,
                    spec.icon,
                ),
            );
        }
    }

    fn openAvailable(self: *Open, spec: Spec) bool {
        return switch (spec.dependency) {
            .none => true,
            .command => |name| self.command_exists_fn(name),
            .home_relative_path => |relative_path| self.homeRelativePathExists(relative_path),
        };
    }

    fn homeRelativePathExists(self: *Open, relative_path: []const u8) bool {
        const home = if (std.c.getenv("HOME")) |value| std.mem.span(value) else return false;

        const path = std.fs.path.join(std.heap.page_allocator, &.{ home, relative_path }) catch return false;
        defer std.heap.page_allocator.free(path);

        return self.path_exists_fn(path);
    }
};

pub fn resolveSpec(open: []const u8) ?Spec {
    for (specs) |spec| {
        if (std.mem.eql(u8, open, spec.open)) return spec;
    }
    return null;
}

pub fn allSpecs() []const Spec {
    return specs[0..];
}

pub fn execute(
    open: []const u8,
    runner: *const fn (command: []const u8) anyerror!void,
) !void {
    const spec = resolveSpec(open) orelse return error.UnknownOpen;
    const allocator = std.heap.page_allocator;
    const command = try resolveExecutionCommand(allocator, spec.execution);
    defer allocator.free(command);
    try runner(command);
}

pub fn resolveExecutionCommand(allocator: std.mem.Allocator, execution: Execution) ![]u8 {
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

test "open rows collect available entries only" {
    const Fake = struct {
        fn commandExists(name: []const u8) bool {
            return !std.mem.eql(u8, name, "wlogout");
        }

        fn pathExists(path: []const u8) bool {
            return path.len == 0;
        }
    };

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);

    var open = Open{
        .command_exists_fn = Fake.commandExists,
        .path_exists_fn = Fake.pathExists,
    };
    try open.collect(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.open, list.items[0].kind);
    try std.testing.expectEqualStrings("settings", list.items[0].open);
    try std.testing.expectEqualStrings("preferences-system-symbolic", list.items[0].icon);
}

test "execute resolves command mapping" {
    const Runner = struct {
        fn run(command: []const u8) !void {
            test_command_capture = try std.testing.allocator.dupe(u8, command);
        }
    };

    if (test_command_capture) |buf| std.testing.allocator.free(buf);
    test_command_capture = null;
    try execute("settings", Runner.run);
    try std.testing.expect(test_command_capture != null);
    try std.testing.expectEqualStrings("wlrlui", test_command_capture.?);
    std.testing.allocator.free(test_command_capture.?);
    test_command_capture = null;
}

test "execute returns runner errors for failed commands" {
    const Runner = struct {
        fn run(_: []const u8) !void {
            return error.CommandFailed;
        }
    };

    try std.testing.expectError(error.CommandFailed, execute("settings", Runner.run));
}

fn commandExists(name: []const u8) bool {
    if (name.len == 0 or name.len > 255) return false;
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path_env = if (std.c.getenv("PATH")) |value| std.mem.span(value) else return false;
    var it = std.mem.splitScalar(u8, path_env, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const joined = std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ dir, name }) catch continue;
        std.Io.Dir.accessAbsolute(std.Options.debug_io, joined, .{}) catch continue;
        return true;
    }
    return false;
}
