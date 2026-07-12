//! Cmd owns the bounded top-level mode vocabulary, its fixed mode order, and Picker state.
//!
//! This slice establishes the four-arm Cmd array and consumes typed Candidate
//! leaves; GUI controls, CLI parsing, and Bash serialization remain separate.

const std = @import("std");
const candidate = @import("picker_candidate");
const apps_mode = @import("mode/apps.zig");
const history_list = @import("../notification/history_list.zig");
const notifications_mode = @import("mode/notifications.zig");
const sunglasses_mode = @import("mode/sunglasses.zig");
const wallpaper_mode = @import("mode/wallpaper.zig");
const query_mod = @import("query.zig");
const rank = @import("rank.zig");

pub const max_cmd_bytes = 4096;
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
    std.debug.assert(max_cmd_bytes > 0);
    std.debug.assert(max_launch_wait_interrupts > 0);
    const fields = std.meta.fields(Cmd);
    std.debug.assert(fields.len == 4);
    std.debug.assert(std.mem.eql(u8, fields[0].name, "apps"));
    std.debug.assert(std.mem.eql(u8, fields[1].name, "notifications"));
    std.debug.assert(std.mem.eql(u8, fields[2].name, "wallpaper"));
    std.debug.assert(std.mem.eql(u8, fields[3].name, "sunglasses"));
}

/// Cmd is the closed top-level mode vocabulary in fixed apps-first order.
pub const Cmd = union(enum) {
    apps: ?*apps_mode.Apps,
    notifications: struct {},
    wallpaper: struct {},
    sunglasses: struct {},
};

/// Picker owns candidate storage, history, and the concrete source pointers.
pub const Picker = struct {
    /// cmds is the one bounded ordered mode array shared by GUI and CLI consumers.
    cmds: [4]Cmd = makeCmds(null),
    notification_history: ?*history_list.NotificationHistoryList = null,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    candidates: candidate.Candidate.List = .empty,
    candidates_loaded: bool = false,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,

    /// Builds Picker with the optional Apps owner as the first Cmd arm.
    pub fn init(apps: ?*apps_mode.Apps) Picker {
        return .{
            .cmds = makeCmds(apps),
        };
    }

    /// Builds Picker with persisted history and the fixed Cmd mode array.
    pub fn initWithHistoryPath(
        apps: ?*apps_mode.Apps,
        history_path: []const u8,
    ) Picker {
        return .{
            .cmds = makeCmds(apps),
            .history_path = history_path,
        };
    }

    pub fn deinit(self: *Picker, allocator: std.mem.Allocator) void {
        self.candidates.deinit();
        deinitHistory(&self.history, allocator);
    }

    /// rankQuery returns ranked rows for the current query string.
    pub fn rankQuery(self: *Picker, allocator: std.mem.Allocator, raw_query: []const u8) ![]rank.RankedCandidate {
        const parsed = query_mod.parse(raw_query);
        if (parsed.route != .modes) try self.loadCandidatesOnce(allocator);

        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        if (parsed.route == .modes) {
            var modes = candidate.Candidate.List.empty;
            try self.collectModeCandidates(&modes);
            return rank.rankCandidatesWithOldestFirstHistory(
                allocator,
                parsed,
                modes.slice(),
                self.history.items,
            );
        }
        return rank.rankCandidatesWithOldestFirstHistory(
            allocator,
            parsed,
            self.candidates.slice(),
            self.history.items,
        );
    }

    /// recordSelection keeps the selected open payload in bounded oldest-first order.
    pub fn recordSelection(self: *Picker, allocator: std.mem.Allocator, selected_open: []const u8) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try recordHistory(&self.history, self.max_history, allocator, selected_open);
    }

    /// loadHistory reads persisted selection history when a path was configured.
    pub fn loadHistory(self: *Picker, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try loadHistoryRows(&self.history, self.max_history, self.history_path, allocator);
    }

    /// saveHistory writes persisted selection history when a path was configured.
    pub fn saveHistory(self: *Picker, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try saveHistoryRows(self.history.items, self.history_path, allocator);
    }

    /// resolveCandidateCommand resolves one terminal leaf and rejects route or
    /// display-only candidates before any process launch is possible.
    pub fn resolveCandidateCommand(
        self: *Picker,
        allocator: std.mem.Allocator,
        row: candidate.Candidate,
    ) ![]u8 {
        std.debug.assert(self.max_history > 0);
        return switch (row) {
            .sub_cmd => error.CandidateNotLaunchable,
            .concrete => |leaf| self.resolveConcrete(allocator, leaf),
        };
    }

    /// resolveConcrete validates one Concrete leaf before producing its intent.
    fn resolveConcrete(self: *const Picker, allocator: std.mem.Allocator, leaf: candidate.Concrete) ![]u8 {
        try leaf.validate();
        return switch (leaf) {
            .app => |value| allocator.dupe(u8, value.open),
            .open => |value| blk: {
                const apps = self.appsOwner() orelse return error.AppsOwnerMissing;
                break :blk try apps.resolve(allocator, value.open);
            },
            .lifecycle => |value| resolveLifecycleCommand(allocator, value),
            .notification => error.NotificationDisplayOnly,
        };
    }

    /// open returns the shell command for a terminal open payload.
    pub fn open(self: *Picker, allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
        try self.loadCandidatesOnce(allocator);
        for (self.candidates.slice()) |row| {
            if (!std.mem.eql(u8, row.openPayload(), payload)) continue;
            return self.resolveCandidateCommand(allocator, row);
        }
        return error.UnknownOpen;
    }

    /// commands writes the current command rows as tab-separated terminal records.
    pub fn commands(self: *Picker, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
        try self.loadCandidatesOnce(allocator);
        for (self.candidates.slice()) |row| {
            try printTerminalRow(out, row);
        }
    }

    /// query writes ranked command rows for a terminal query.
    pub fn query(
        self: *Picker,
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
        self: *Picker,
        allocator: std.mem.Allocator,
        raw_query: []const u8,
        out: *std.Io.Writer,
    ) !void {
        const ranked = try self.rankQuery(allocator, raw_query);
        defer allocator.free(ranked);

        if (ranked.len > max_completion_candidates) return error.TooManyCompletionCandidates;
        var output_bytes: u32 = 0;
        for (ranked) |item| {
            if (!candidate.Candidate.accepts(.bash_completion, item.candidate)) continue;
            const value = item.candidate.openPayload();
            const escaped_bytes = bashEscapedLength(value);
            if (escaped_bytes > max_completion_output_bytes -| output_bytes) return error.CompletionOutputTooLong;
            try writeBashWord(out, value);
            try out.writeByte('\n');
            output_bytes += escaped_bytes + 1;
        }
    }

    fn loadCandidatesOnce(self: *Picker, allocator: std.mem.Allocator) !void {
        if (self.candidates_loaded) return;
        for (self.cmds) |cmd| {
            switch (cmd) {
                .apps => |owner| if (owner) |apps| try apps.collectCandidates(allocator, &self.candidates),
                .notifications => try notifications_mode.collectCandidates(&self.candidates),
                .wallpaper => try wallpaper_mode.collectCandidates(&self.candidates),
                .sunglasses => try sunglasses_mode.collectCandidates(&self.candidates),
            }
        }
        if (self.notification_history) |owner| try owner.collect(allocator, &self.candidates);
        self.candidates_loaded = true;
    }

    fn appsOwner(self: *const Picker) ?*apps_mode.Apps {
        return switch (self.cmds[0]) {
            .apps => |owner| owner,
            .notifications, .wallpaper, .sunglasses => null,
        };
    }

    /// collectModeCandidates exposes resident Cmd arms as route candidates.
    /// Apps is the default leaf mode and intentionally has no SubCmd arm.
    fn collectModeCandidates(self: *const Picker, out: *candidate.Candidate.List) !void {
        for (self.cmds) |cmd| {
            switch (cmd) {
                .apps => {},
                .notifications => try out.append(candidate.Candidate.subCmd(notifications_mode.restartSubCmd())),
                .wallpaper => try out.append(candidate.Candidate.subCmd(wallpaper_mode.restartSubCmd())),
                .sunglasses => try out.append(candidate.Candidate.subCmd(sunglasses_mode.restartSubCmd())),
            }
        }
    }
};

fn makeCmds(apps: ?*apps_mode.Apps) [4]Cmd {
    return .{
        .{ .apps = apps },
        .{ .notifications = .{} },
        .{ .wallpaper = .{} },
        .{ .sunglasses = .{} },
    };
}

/// resolveLifecycleCommand exhaustively dispatches each resident leaf arm.
fn resolveLifecycleCommand(allocator: std.mem.Allocator, value: candidate.Lifecycle) ![]u8 {
    return switch (value) {
        .notifications_restart => allocator.dupe(u8, notifications_mode.restartCommand()),
        .wallpaper_restart => allocator.dupe(u8, wallpaper_mode.restartCommand()),
        .wallpaper_rotate => allocator.dupe(u8, "wayspot wallpaper rotate"),
        .sunglasses_restart => allocator.dupe(u8, "wayspot sunglasses"),
        .sunglasses_apply => allocator.dupe(u8, "wayspot sunglasses apply"),
        .sunglasses_reconcile => allocator.dupe(u8, "wayspot sunglasses reconcile"),
        .sunglasses_dim => |leaf| resolveSunglassesDim(allocator, leaf),
        .sunglasses_filter => |leaf| resolveSunglassesFilter(allocator, leaf),
        .sunglasses_image => |leaf| resolveSunglassesImage(allocator, leaf),
    };
}

fn resolveSunglassesDim(allocator: std.mem.Allocator, leaf: candidate.MonitorLeaf) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "wayspot sunglasses dim ");
    try appendShellQuoted(&out, allocator, leaf.monitor.slice());
    switch (leaf.input) {
        .scalar => |value| {
            try out.appendSlice(allocator, " set ");
            try out.print(allocator, "{d}", .{value.value});
        },
        .toggle => |value| {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, if (value.enabled) "on" else "off");
        },
        .none, .path => return error.InvalidSunglassesInput,
    }
    return out.toOwnedSlice(allocator);
}

fn resolveSunglassesFilter(allocator: std.mem.Allocator, leaf: candidate.MonitorLeaf) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "wayspot sunglasses filter ");
    try appendShellQuoted(&out, allocator, leaf.monitor.slice());
    switch (leaf.input) {
        .scalar => |value| {
            try out.appendSlice(allocator, " set ");
            try out.print(allocator, "{d}", .{value.value});
        },
        .toggle => |value| {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, if (value.enabled) "on" else "off");
        },
        .none, .path => return error.InvalidSunglassesInput,
    }
    return out.toOwnedSlice(allocator);
}

fn resolveSunglassesImage(allocator: std.mem.Allocator, leaf: candidate.MonitorLeaf) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "wayspot sunglasses image ");
    try appendShellQuoted(&out, allocator, leaf.monitor.slice());
    switch (leaf.input) {
        .none => try out.appendSlice(allocator, " clear"),
        .scalar => |value| {
            try out.appendSlice(allocator, " opacity ");
            try out.print(allocator, "{d}", .{value.value});
        },
        .toggle => |value| {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, if (value.enabled) "on" else "off");
        },
        .path => |value| {
            try out.appendSlice(allocator, " set ");
            try appendShellQuoted(&out, allocator, value.slice());
        },
    }
    return out.toOwnedSlice(allocator);
}

/// appendShellQuoted encodes one dynamic word for the /bin/sh launcher.
/// Single quotes preserve spaces, punctuation, substitutions, and operators;
/// an embedded quote closes, escapes, and reopens the quoted word.
fn appendShellQuoted(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try out.append(allocator, '\'');
    for (value) |byte| {
        if (byte == '\'') {
            try out.appendSlice(allocator, "'\\''");
        } else {
            try out.append(allocator, byte);
        }
    }
    try out.append(allocator, '\'');
}

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
    var model = Picker.init(&apps);
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

test "Cmd array is exhaustive, bounded, and apps-first" {
    const expected = [_]std.meta.Tag(Cmd){ .apps, .notifications, .wallpaper, .sunglasses };
    var picker = Picker.init(null);
    defer picker.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected.len, picker.cmds.len);
    for (picker.cmds, expected) |value, tag| {
        try std.testing.expectEqual(tag, std.meta.activeTag(value));
    }
}

test "Picker initializers share the one Cmd composition" {
    var first = Picker.init(null);
    defer first.deinit(std.testing.allocator);
    var second = Picker.initWithHistoryPath(null, "history");
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u32, 4), @as(u32, @intCast(first.cmds.len)));
    try std.testing.expectEqual(@TypeOf(first), @TypeOf(second));
}

test "command model exposes typed sunglasses leaves" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const results = try model.rankQuery(std.testing.allocator, "/sunglasses");
    defer std.testing.allocator.free(results);
    try std.testing.expectEqual(@as(u32, 6), @as(u32, @intCast(results.len)));
    try std.testing.expect(results[0].candidate.isLaunchable() or results[0].candidate.isSubCmd());
}

test "command model exposes every resident mode at the modes route" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const results = try model.rankQuery(std.testing.allocator, "/");
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 3), results.len);
    var saw_notifications = false;
    var saw_wallpapers = false;
    var saw_sunglasses = false;
    for (results) |result| {
        try std.testing.expect(result.candidate.isSubCmd());
        const route_query = result.candidate.routeQuery().?;
        if (std.mem.eql(u8, route_query, "/notifications")) saw_notifications = true;
        if (std.mem.eql(u8, route_query, "/wallpapers")) saw_wallpapers = true;
        if (std.mem.eql(u8, route_query, "/sunglasses")) saw_sunglasses = true;
    }
    try std.testing.expect(saw_notifications);
    try std.testing.expect(saw_wallpapers);
    try std.testing.expect(saw_sunglasses);
}

test "command Apps route reaches installed and fixed-local leaves" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\
        ,
    });
    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    const Fake = struct {
        fn commandExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = cache_path,
        .command_exists_fn = Fake.commandExists,
    };
    defer apps.deinit(std.testing.allocator);

    var model = Picker.init(&apps);
    defer model.deinit(std.testing.allocator);

    const all = try model.rankQuery(std.testing.allocator, "/apps");
    defer std.testing.allocator.free(all);
    try std.testing.expectEqual(@as(usize, 2), all.len);
    try std.testing.expect(all[0].candidate.isApp());
    try std.testing.expect(all[1].candidate.isOpen());

    const filtered = try model.rankQuery(std.testing.allocator, "/apps set");
    defer std.testing.allocator.free(filtered);
    try std.testing.expectEqual(@as(usize, 1), filtered.len);
    try std.testing.expect(filtered[0].candidate.isOpen());
    try std.testing.expectEqualStrings("settings", filtered[0].candidate.openPayload());
}

test "command model ranks retained history without query history allocation" {
    var model = Picker.init(null);
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
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const lifecycle = try model.open(std.testing.allocator, notifications_mode.restart_open);
    defer std.testing.allocator.free(lifecycle);
    try std.testing.expect(std.mem.indexOf(u8, lifecycle, "--notifications-daemon") != null);

    try std.testing.expectError(error.UnknownOpen, model.open(std.testing.allocator, "missing-open"));
}

test "command model resolves resident lifecycle owners" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const wallpaper = try model.resolveCandidateCommand(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.wallpaperRestart()));
    defer std.testing.allocator.free(wallpaper);
    try std.testing.expect(std.mem.indexOf(u8, wallpaper, "--wallpaper") != null);

    const rotate = try model.resolveCandidateCommand(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.wallpaperRotate()));
    defer std.testing.allocator.free(rotate);
    try std.testing.expectEqualStrings("wayspot wallpaper rotate", rotate);

    const sunglasses = try model.resolveCandidateCommand(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesRestart()));
    defer std.testing.allocator.free(sunglasses);
    try std.testing.expectEqualStrings("wayspot sunglasses", sunglasses);

    const apply = try model.resolveCandidateCommand(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesApply()));
    defer std.testing.allocator.free(apply);
    try std.testing.expectEqualStrings("wayspot sunglasses apply", apply);

    const reconcile = try model.resolveCandidateCommand(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesReconcile()));
    defer std.testing.allocator.free(reconcile);
    try std.testing.expectEqualStrings("wayspot sunglasses reconcile", reconcile);
}

test "command model resolves typed sunglasses leaves" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim_input = try candidate.Input.scalarInput(35, 0, 100, 1);
    const dim = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP-1", dim_input));
    const dim_command = try model.resolveCandidateCommand(std.testing.allocator, dim);
    defer std.testing.allocator.free(dim_command);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP-1' set 35", dim_command);

    const filter_input = try candidate.Input.scalarInput(-35, -100, 100, 1);
    const filter = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP-1", filter_input));
    const filter_command = try model.resolveCandidateCommand(std.testing.allocator, filter);
    defer std.testing.allocator.free(filter_command);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP-1' set -35", filter_command);

    const image_input = try candidate.Input.pathInput("/tmp/sunglasses.png");
    const image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", image_input));
    const image_command = try model.resolveCandidateCommand(std.testing.allocator, image);
    defer std.testing.allocator.free(image_command);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' set '/tmp/sunglasses.png'", image_command);
}

test "command model resolves every typed sunglasses Input arm" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim_toggle = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP-1", candidate.Input.toggleInput(false)));
    const dim_toggle_command = try model.resolveCandidateCommand(std.testing.allocator, dim_toggle);
    defer std.testing.allocator.free(dim_toggle_command);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP-1' off", dim_toggle_command);

    const filter_toggle = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP-1", candidate.Input.toggleInput(true)));
    const filter_toggle_command = try model.resolveCandidateCommand(std.testing.allocator, filter_toggle);
    defer std.testing.allocator.free(filter_toggle_command);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP-1' on", filter_toggle_command);

    const image_opacity = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", try candidate.Input.scalarInput(55, 0, 100, 1)));
    const image_opacity_command = try model.resolveCandidateCommand(std.testing.allocator, image_opacity);
    defer std.testing.allocator.free(image_opacity_command);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' opacity 55", image_opacity_command);

    const image_clear = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", .none));
    const image_clear_command = try model.resolveCandidateCommand(std.testing.allocator, image_clear);
    defer std.testing.allocator.free(image_clear_command);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' clear", image_clear_command);
}

test "command model shell-quotes dynamic sunglasses words" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP 1;$(touch x)", try candidate.Input.scalarInput(35, 0, 100, 1)));
    const dim_command = try model.resolveCandidateCommand(std.testing.allocator, dim);
    defer std.testing.allocator.free(dim_command);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP 1;$(touch x)' set 35", dim_command);

    const filter = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP`1 $HOME", candidate.Input.toggleInput(true)));
    const filter_command = try model.resolveCandidateCommand(std.testing.allocator, filter);
    defer std.testing.allocator.free(filter_command);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP`1 $HOME' on", filter_command);

    const path = try candidate.Input.pathInput("/tmp/a; touch /tmp/b $ `");
    const image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", path));
    const image_command = try model.resolveCandidateCommand(std.testing.allocator, image);
    defer std.testing.allocator.free(image_command);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' set '/tmp/a; touch /tmp/b $ `'", image_command);

    const quoted_path = try candidate.Input.pathInput("/tmp/a'b");
    const quoted_image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", quoted_path));
    const quoted_command = try model.resolveCandidateCommand(std.testing.allocator, quoted_image);
    defer std.testing.allocator.free(quoted_command);
    try std.testing.expect(std.mem.indexOf(u8, quoted_command, "'\\''") != null);
}

test "command model rejects newline dynamic words before resolution" {
    const scalar = try candidate.Input.scalarInput(35, 0, 100, 1);

    try std.testing.expectError(error.MonitorByteInvalid, candidate.sunglassesDim("DP-1\n", scalar));
    try std.testing.expectError(error.PathByteInvalid, candidate.Input.pathInput("/tmp/a\nb"));
}

test "command model explicitly rejects routes and display-only notifications" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const route = candidate.Candidate.subCmd(.{ .sunglasses = .{ .dim = .{ .set = {} } } });
    try std.testing.expectError(error.CandidateNotLaunchable, model.resolveCandidateCommand(std.testing.allocator, route));

    const notification = candidate.Candidate.notificationLeaf("Summary", "App", "notification-history:0:1");
    try std.testing.expectError(error.NotificationDisplayOnly, model.resolveCandidateCommand(std.testing.allocator, notification));
}

test "command model rejects invalid typed leaf at resolution" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const invalid = candidate.Candidate.lifecycleLeaf(.{
        .sunglasses_dim = .{
            .monitor = .{},
            .input = .none,
        },
    });
    try std.testing.expectError(error.MonitorEmpty, model.resolveCandidateCommand(std.testing.allocator, invalid));
}

test "command model keeps app open payload behavior" {
    const Fake = struct {
        fn commandExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = "unused",
        .command_exists_fn = Fake.commandExists,
    };
    defer apps.deinit(std.testing.allocator);

    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    try list.append(candidate.Candidate.appLeaf("Terminal", "Utilities", "foot", ""));

    var model = Picker.init(&apps);
    model.candidates = list;
    model.candidates_loaded = true;
    list = .empty;
    defer model.deinit(std.testing.allocator);

    const command = try model.open(std.testing.allocator, "foot");
    defer std.testing.allocator.free(command);
    try std.testing.expectEqualStrings("foot", command);

    const open_leaf = candidate.Candidate.openLeaf("Settings", "System", "settings", "");
    const open_command = try model.resolveCandidateCommand(std.testing.allocator, open_leaf);
    defer std.testing.allocator.free(open_command);
    try std.testing.expectEqualStrings("wlrlui", open_command);
}

test "command model collects notification history list rows" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    try list.append(candidate.Candidate.notificationLeaf("Summary", "App", "notification-history:0:1"));

    var model = Picker{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try model.commands(std.testing.allocator, &output.writer);

    try std.testing.expectEqualStrings("concrete\tnotification-history:0:1\tSummary\tApp\n", output.written());
}

test "command model writes completion records" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    try list.append(candidate.Candidate.appLeaf("Quote App", "Utilities", "quote'app", ""));

    var model = Picker{
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

test "bash completion excludes notification records by input policy" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    try list.append(candidate.Candidate.subCmd(.{ .notifications = .{ .history = {} } }));
    try list.append(candidate.Candidate.notificationLeaf("Summary", "App", "notification-history:0:1"));

    var model = Picker{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try model.completeBash(std.testing.allocator, "/notifications", &output.writer);

    try std.testing.expectEqualStrings("'/notifications history'\n", output.written());
}

test "command launch runner accepts successful command" {
    try drainLaunchForTest("run-me", launchRunnerOkForTest);
}

test "command launch runner returns failures" {
    try std.testing.expectError(error.CommandFailed, drainLaunchForTest("run-me", launchRunnerFailForTest));
}
