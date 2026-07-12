//! Picker command model owns rows, ranking, open payloads, and terminal output.

const std = @import("std");
const candidate = @import("picker_candidate");
const apps_mode = @import("mode/apps.zig");
const history_list = @import("../notification/history_list.zig");
const mode = @import("mode/mod.zig");
const open_owner = @import("open.zig");
const query_mod = @import("query.zig");
const rank = @import("rank.zig");

pub const max_command_bytes = 4096;
pub const max_completion_candidates: u32 = 256;
pub const max_completion_output_bytes: u32 = 64 * 1024;
const launch_child_fail_code: i32 = 127;
const max_launch_wait_interrupts: u32 = 16;
pub const LaunchRunError = error{
    CommandFailed,
    ForkFailed,
    WaitFailed,
    WaitInterruptedTooOften,
};

comptime {
    std.debug.assert(max_command_bytes > 0);
    std.debug.assert(max_launch_wait_interrupts > 0);
}

/// Command owns picker rows consumed by the GUI picker and terminal commands.
pub const Command = struct {
    opens: ?*open_owner.Open = null,
    apps: ?*apps_mode.Apps = null,
    modes: ?*mode.Mode = null,
    notification_history: ?*history_list.NotificationHistoryList = null,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    candidates: candidate.Candidate.List = .empty,
    candidates_loaded: bool = false,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,

    /// Builds a command model with optional fixed open and app row owners.
    pub fn init(opens: ?*open_owner.Open, apps: ?*apps_mode.Apps) Command {
        return .{
            .opens = opens,
            .apps = apps,
        };
    }

    /// Builds a command model with persisted history and slash mode rows.
    pub fn initWithHistoryPath(
        opens: ?*open_owner.Open,
        apps: ?*apps_mode.Apps,
        modes: ?*mode.Mode,
        history_path: []const u8,
    ) Command {
        return .{
            .opens = opens,
            .apps = apps,
            .modes = modes,
            .history_path = history_path,
        };
    }

    pub fn deinit(self: *Command, allocator: std.mem.Allocator) void {
        self.candidates.deinit(allocator);
        deinitHistory(&self.history, allocator);
    }

    /// rankQuery returns ranked rows for the current query string.
    pub fn rankQuery(self: *Command, allocator: std.mem.Allocator, raw_query: []const u8) ![]rank.RankedCandidate {
        try self.loadCandidatesOnce(allocator);

        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        return rank.rankCandidatesWithOldestFirstHistory(
            allocator,
            query_mod.parse(raw_query),
            self.candidates.items,
            self.history.items,
        );
    }

    /// recordSelection keeps the selected open payload in bounded oldest-first order.
    pub fn recordSelection(self: *Command, allocator: std.mem.Allocator, selected_open: []const u8) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try recordHistory(&self.history, self.max_history, allocator, selected_open);
    }

    /// loadHistory reads persisted selection history when a path was configured.
    pub fn loadHistory(self: *Command, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try loadHistoryRows(&self.history, self.max_history, self.history_path, allocator);
    }

    /// saveHistory writes persisted selection history when a path was configured.
    pub fn saveHistory(self: *Command, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try saveHistoryRows(self.history.items, self.history_path, allocator);
    }

    /// resolveCandidateCommand returns the shell command opened by an executable row.
    pub fn resolveCandidateCommand(
        self: *Command,
        allocator: std.mem.Allocator,
        row: candidate.Candidate,
    ) ![]u8 {
        std.debug.assert(self.max_history > 0);
        return switch (row.typeOf()) {
            .app => allocator.dupe(u8, row.openPayload()),
            .open => blk: {
                const spec = open_owner.resolveSpec(row.openPayload()) orelse return error.UnknownOpen;
                break :blk try open_owner.resolveExecutionCommand(allocator, spec.execution);
            },
            .lifecycle => blk: {
                const command = mode.resolveRestartLifecycleCommand(row.openPayload()) orelse return error.UnknownOpen;
                break :blk try allocator.dupe(u8, command);
            },
            .mode, .notification, .hint => error.UnknownOpen,
        };
    }

    /// open returns the shell command for a terminal open payload.
    pub fn open(self: *Command, allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
        try self.loadCandidatesOnce(allocator);
        for (self.candidates.items) |row| {
            if (!std.mem.eql(u8, row.openPayload(), payload)) continue;
            return self.resolveCandidateCommand(allocator, row);
        }
        return error.UnknownOpen;
    }

    /// commands writes the current command rows as tab-separated terminal records.
    pub fn commands(self: *Command, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
        try self.loadCandidatesOnce(allocator);
        for (self.candidates.items) |row| {
            try printTerminalRow(out, row);
        }
    }

    /// query writes ranked command rows for a terminal query.
    pub fn query(
        self: *Command,
        allocator: std.mem.Allocator,
        raw_query: []const u8,
        out: *std.Io.Writer,
    ) !void {
        const ranked = try self.rankQuery(allocator, raw_query);
        defer allocator.free(ranked);
        for (ranked) |item| {
            try printTerminalRow(out, item.candidate);
        }
    }

    /// completeBash writes bounded shell-quoted candidates for Bash completion.
    pub fn completeBash(
        self: *Command,
        allocator: std.mem.Allocator,
        raw_query: []const u8,
        out: *std.Io.Writer,
    ) !void {
        const ranked = try self.rankQuery(allocator, raw_query);
        defer allocator.free(ranked);

        if (ranked.len > max_completion_candidates) return error.TooManyCompletionCandidates;
        var output_bytes: u32 = 0;
        for (ranked) |item| {
            const value = item.candidate.openPayload();
            const escaped_bytes = bashEscapedLength(value);
            if (escaped_bytes > max_completion_output_bytes -| output_bytes) return error.CompletionOutputTooLong;
            try writeBashWord(out, value);
            try out.writeByte('\n');
            output_bytes += escaped_bytes + 1;
        }
    }

    fn loadCandidatesOnce(self: *Command, allocator: std.mem.Allocator) !void {
        if (self.candidates_loaded) return;
        if (self.modes) |owner| try owner.collect(allocator, &self.candidates);
        if (self.notification_history) |owner| try owner.collect(allocator, &self.candidates);
        if (self.opens) |owner| try owner.collect(allocator, &self.candidates);
        if (self.apps) |owner| try owner.collect(allocator, &self.candidates);
        self.candidates_loaded = true;
    }
};

/// runDetachedShellCommand starts a shell command and waits only for the launcher wrapper.
pub fn runDetachedShellCommand(command: [*:0]const u8) LaunchRunError!void {
    const wrapper_pid = try launchFork();
    if (wrapper_pid == 0) {
        launchWrapperChild(command);
    }
    try launchWait(wrapper_pid);
}

fn printTerminalRow(out: *std.Io.Writer, row: candidate.Candidate) !void {
        try out.print("{s}\t{s}\t{s}\t{s}\n", .{
        @tagName(row.typeOf()),
        row.openPayload(),
        row.title(),
        row.subtitle(),
    });
}

fn bashEscapedLength(value: []const u8) u32 {
    var length: u32 = 2;
    for (value) |byte| {
        length += if (byte == '\'') 4 else 1;
    }
    return length;
}

fn writeBashWord(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('\'');
    for (value) |byte| {
        if (byte == '\'') try out.writeAll("'\\''") else try out.writeByte(byte);
    }
    try out.writeByte('\'');
}

fn recordHistory(
    history: *std.ArrayListUnmanaged([]u8),
    max_history: u32,
    allocator: std.mem.Allocator,
    selected_open: []const u8,
) !void {
    if (selected_open.len == 0) return;
    const copy = try allocator.dupe(u8, selected_open);
    try history.append(allocator, copy);

    if (history.items.len > max_history) {
        const oldest = history.orderedRemove(0);
        allocator.free(oldest);
    }
}

fn loadHistoryRows(
    history: *std.ArrayListUnmanaged([]u8),
    max_history: u32,
    history_path: ?[]const u8,
    allocator: std.mem.Allocator,
) !void {
    const path = history_path orelse return;
    const data = std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer allocator.free(data);

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try recordHistory(history, max_history, allocator, trimmed);
    }
}

fn saveHistoryRows(history: []const []const u8, history_path: ?[]const u8, allocator: std.mem.Allocator) !void {
    const path = history_path orelse return;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    for (history) |entry| {
        try out.appendSlice(allocator, entry);
        try out.append(allocator, '\n');
    }
    try writeHistoryAtomic(allocator, path, out.items);
}

fn writeHistoryAtomic(allocator: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp_path);
    try ensureParentDir(path);
    const io = std.Options.debug_io;

    if (std.fs.path.isAbsolute(path)) {
        const file = try std.Io.Dir.createFileAbsolute(io, tmp_path, .{ .truncate = true });
        defer file.close(io);
        try file.writeStreamingAll(io, data);
        try file.sync(io);
        try std.Io.Dir.renameAbsolute(tmp_path, path, io);
        try syncParentDir(path);
        return;
    }
    const file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, data);
    try file.sync(io);
    try std.Io.Dir.cwd().rename(tmp_path, std.Io.Dir.cwd(), path, io);
    try syncParentDir(path);
}

fn ensureParentDir(path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
}

fn syncParentDir(path: []const u8) !void {
    const io = std.Options.debug_io;
    const parent = std.fs.path.dirname(path) orelse ".";
    var parent_dir = if (std.fs.path.isAbsolute(path))
        try std.Io.Dir.openDirAbsolute(io, parent, .{})
    else
        try std.Io.Dir.cwd().openDir(io, parent, .{});
    defer parent_dir.close(io);
    const rc = std.posix.system.fsync(parent_dir.handle);
    switch (std.posix.errno(rc)) {
        .SUCCESS => return,
        .INVAL, .BADF, .ROFS, .OPNOTSUPP => return,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn deinitHistory(history: *std.ArrayListUnmanaged([]u8), allocator: std.mem.Allocator) void {
    for (history.items) |item| allocator.free(item);
    history.deinit(allocator);
}

fn launchWrapperChild(command: [*:0]const u8) noreturn {
    const stdio_ok = launchRedirectStdio();
    if (!stdio_ok) std.c._exit(launch_child_fail_code);

    const session_id = std.c.setsid();
    if (session_id == -1) std.c._exit(launch_child_fail_code);

    const app_pid = launchFork() catch std.c._exit(launch_child_fail_code);
    if (app_pid == 0) launchExecShell(command);

    std.c._exit(0);
}

fn launchExecShell(command: [*:0]const u8) noreturn {
    const shell_path = "/bin/sh";
    const shell_name = "sh";
    const shell_arg = "-lc";
    const argv: [4:null]?[*:0]const u8 = .{
        shell_name,
        shell_arg,
        command,
        null,
    };
    const exec_rc = std.c.execve(shell_path, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(launch_child_fail_code);
    std.c._exit(launch_child_fail_code);
}

fn launchRedirectStdio() bool {
    const dev_null = std.c.open("/dev/null", .{ .ACCMODE = .RDWR, .CLOEXEC = false });
    if (dev_null == -1) return false;

    const stdin_rc = std.c.dup2(dev_null, 0);
    const stdout_rc = std.c.dup2(dev_null, 1);
    const stderr_rc = std.c.dup2(dev_null, 2);
    const close_rc = std.c.close(dev_null);
    if (stdin_rc == -1) return false;
    if (stdout_rc == -1) return false;
    if (stderr_rc == -1) return false;
    if (close_rc == -1) return false;
    return true;
}

fn launchFork() LaunchRunError!std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn launchWait(pid: std.c.pid_t) LaunchRunError!void {
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_launch_wait_interrupts) {
        const waited = std.c.waitpid(pid, &status, 0);
        if (waited == pid) break;
        if (waited == -1) {
            const errno = std.c._errno().*;
            if (errno == @intFromEnum(std.c.E.INTR)) {
                interrupts += 1;
                continue;
            }
            return error.WaitFailed;
        }
        return error.WaitFailed;
    } else {
        return error.WaitInterruptedTooOften;
    }
    const status_bits: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(status_bits)) return error.CommandFailed;
    if (std.c.W.EXITSTATUS(status_bits) != 0) return error.CommandFailed;
}

fn launchRunnerOkForTest(command: [*:0]const u8) LaunchRunError!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
}

fn launchRunnerFailForTest(command: [*:0]const u8) LaunchRunError!void {
    if (!std.mem.eql(u8, "run-me", std.mem.span(command))) return error.CommandFailed;
    return error.CommandFailed;
}

fn drainLaunchForTest(command: [*:0]const u8, runner: *const fn ([*:0]const u8) LaunchRunError!void) LaunchRunError!void {
    try runner(command);
}

test "command model collects candidates once per picker lifecycle" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = apps_mode.Apps.init(cache_path);
    defer apps.deinit(std.testing.allocator);
    var model = Command.init(null, &apps);
    defer model.deinit(std.testing.allocator);

    const first = try model.rankQuery(std.testing.allocator, "kit");
    defer std.testing.allocator.free(first);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));

    const second = try model.rankQuery(std.testing.allocator, "fire");
    defer std.testing.allocator.free(second);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
}

test "command model exposes modes without hiding default app ranking" {
    var modes = mode.Mode{};
    var model = Command{
        .modes = &modes,
    };
    defer model.deinit(std.testing.allocator);

    const mode_results = try model.rankQuery(std.testing.allocator, "/");
    defer std.testing.allocator.free(mode_results);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(mode_results.len)));
    try std.testing.expectEqual(candidate.Candidate.Type.mode, mode_results[0].candidate.typeOf());
}

test "command model ranks retained history without query history allocation" {
    var model = Command.init(null, null);
    defer model.deinit(std.testing.allocator);
    model.candidates_loaded = true;
    try recordHistory(&model.history, model.max_history, std.testing.allocator, "power");

    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const ranked = try model.rankQuery(fba.allocator(), "p");
    defer fba.allocator().free(ranked);

    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(ranked.len)));
}

test "command history save creates nested parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/nested/history/history.log", .{base});
    defer std.testing.allocator.free(path);

    const entries = [_][]const u8{ "settings", "power" };
    try saveHistoryRows(entries[0..], path, std.testing.allocator);

    const saved = try tmp.dir.readFileAlloc(std.Options.debug_io, "nested/history/history.log", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("settings\npower\n", saved);
}

test "command model resolves app and lifecycle commands" {
    var modes = mode.Mode{};
    var model = Command{
        .modes = &modes,
    };
    defer model.deinit(std.testing.allocator);

    const lifecycle = try model.open(std.testing.allocator, mode.notifications.restart_open);
    defer std.testing.allocator.free(lifecycle);
    try std.testing.expect(std.mem.indexOf(u8, lifecycle, "--notifications-daemon") != null);

    try std.testing.expectError(error.UnknownOpen, model.open(std.testing.allocator, "missing-open"));
}

test "command model keeps app open payload behavior" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, candidate.Candidate.makeApp("Terminal", "Utilities", "foot", ""));

    var model = Command{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    const command = try model.open(std.testing.allocator, "foot");
    defer std.testing.allocator.free(command);
    try std.testing.expectEqualStrings("foot", command);
}

test "command model collects notification history list rows" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, candidate.Candidate.makeNotification("Summary", "App", "notification-history:0:1"));

    var model = Command{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try model.commands(std.testing.allocator, &output.writer);

    try std.testing.expectEqualStrings("notification\tnotification-history:0:1\tSummary\tApp\n", output.written());
}

test "command model writes completion records" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);
    try list.append(std.testing.allocator, candidate.Candidate.makeApp("Quote App", "Utilities", "quote'app", ""));

    var model = Command{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try model.completeBash(std.testing.allocator, "quote", &output.writer);

    try std.testing.expectEqualStrings("'quote'\\''app'\n", output.written());
}

test "command launch runner accepts successful command" {
    try drainLaunchForTest("run-me", launchRunnerOkForTest);
}

test "command launch runner returns failures" {
    try std.testing.expectError(error.CommandFailed, drainLaunchForTest("run-me", launchRunnerFailForTest));
}
