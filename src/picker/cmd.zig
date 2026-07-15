//! Cmd owns the bounded top-level mode vocabulary, its fixed mode order, and Picker state.
//!
//! This slice establishes the four-arm Cmd array and consumes typed Candidate
//! leaves; GUI controls, CLI parsing, and Bash serialization remain separate.

const std = @import("std");
const candidate = @import("picker_candidate");
const apps_mode = @import("wayspot_apps_mode");
const history_list = @import("wayspot_history_list");
const notifications_mode = @import("wayspot_notifications_mode");
const sunglasses_mode = @import("wayspot_sunglasses_mode");
const wallpaper_mode = @import("wayspot_wallpaper_mode");
const query_mod = @import("wayspot_query");
const rank = @import("wayspot_rank");
const sub_cmd = @import("picker_sub_cmd");

pub const max_cmd_bytes = 4096;
pub const max_completion_candidates: usize = 256;

comptime {
    std.debug.assert(max_cmd_bytes > 0);
    const fields = std.meta.fields(Cmd);
    std.debug.assert(fields.len == 4);
    std.debug.assert(std.mem.eql(u8, fields[0].name, "apps"));
    std.debug.assert(std.mem.eql(u8, fields[1].name, "notifications"));
    std.debug.assert(std.mem.eql(u8, fields[2].name, "wallpaper"));
    std.debug.assert(std.mem.eql(u8, fields[3].name, "sunglasses"));
}

/// Cmd is the closed top-level mode vocabulary in fixed apps-first order.
pub const Cmd = union(enum) {
    /// apps is the default mode and the first ordered Cmd arm.
    apps: ?*apps_mode.Apps,
    /// notifications selects the notification resident mode.
    notifications: struct {},
    /// wallpaper selects the wallpaper resident mode.
    wallpaper: struct {},
    /// sunglasses selects the sunglasses resident mode.
    sunglasses: struct {},
};

/// CompletionPosition identifies the Cmd-tree level receiving one shell prefix.
pub const CompletionPosition = enum {
    /// mode receives one top-level Cmd name.
    mode,
    /// sub_cmd receives one resident SubCmd name.
    sub_cmd,
    /// operation receives one nested route operation.
    operation,
    /// app receives one application selection.
    app,
};

/// Completion is one borrowed shell argument selected by Cmd semantics.
///
/// The argument is a static Cmd/SubCmd name or a producer-owned application
/// selection. The returned slice owns only the Completion records; the Picker
/// and its producers outlive every argument until the caller frees the slice.
pub const Completion = struct {
    /// argument is exactly one next shell argument, without a Wayspot prefix.
    argument: []const u8,
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

    /// rankQuery returns ranked candidates for the current query string.
    pub fn rankQuery(self: *Picker, allocator: std.mem.Allocator, raw_query: []const u8) ![]rank.RankedCandidate {
        const parsed = try query_mod.parse(raw_query);
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

    /// recordSelection keeps the selected candidate value in bounded oldest-first order.
    pub fn recordSelection(self: *Picker, allocator: std.mem.Allocator, selected_selection: []const u8) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try recordHistory(&self.history, self.max_history, allocator, selected_selection);
    }

    /// loadHistory reads persisted selection history when a path was configured.
    pub fn loadHistory(self: *Picker, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try loadHistorySelections(&self.history, self.max_history, self.history_path, allocator);
    }

    /// saveHistory writes persisted selection history when a path was configured.
    pub fn saveHistory(self: *Picker, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try saveHistorySelections(self.history.items, self.history_path, allocator);
    }

    /// resolveCandidate resolves one terminal leaf and rejects route or
    /// display-only candidates before any process launch is possible.
    pub fn resolveCandidate(
        self: *Picker,
        allocator: std.mem.Allocator,
        value: candidate.Candidate,
    ) ![]u8 {
        std.debug.assert(self.max_history > 0);
        return switch (value) {
            .sub_cmd => |sub_cmd_value| resolveSubCmd(sub_cmd_value),
            .concrete => |leaf| self.resolveConcrete(allocator, leaf),
        };
    }

    /// resolveSubCmd rejects a route node because selection must enter its next
    /// Candidate list; only a Concrete leaf can produce executable intent.
    fn resolveSubCmd(value: sub_cmd.SubCmd) ![]u8 {
        return switch (value) {
            .notifications, .wallpaper, .sunglasses => error.CandidateNotLaunchable,
        };
    }

    /// resolveConcrete validates one Concrete leaf before producing its intent.
    fn resolveConcrete(self: *const Picker, allocator: std.mem.Allocator, leaf: candidate.Concrete) ![]u8 {
        try leaf.validate();
        return switch (leaf) {
            .app => |value| allocator.dupe(u8, value.selection),
            .open => |value| blk: {
                const apps = self.appsOwner() orelse return error.AppsOwnerMissing;
                break :blk try apps.resolve(allocator, value.selection);
            },
            .lifecycle => |value| resolveLifecycle(allocator, value),
            .notification => error.NotificationDisplayOnly,
        };
    }

    /// open resolves one terminal selection value for the current CLI bridge.
    pub fn open(self: *Picker, allocator: std.mem.Allocator, selection: []const u8) ![]u8 {
        try self.loadCandidatesOnce(allocator);
        for (self.candidates.slice()) |value| {
            if (!std.mem.eql(u8, value.selection(), selection)) continue;
            return self.resolveCandidate(allocator, value);
        }
        return error.UnknownSelection;
    }

    /// query writes ranked candidates for a terminal query.
    pub fn query(
        self: *Picker,
        allocator: std.mem.Allocator,
        raw_query: []const u8,
        out: *std.Io.Writer,
    ) !void {
        const ranked = try self.rankQuery(allocator, raw_query);
        defer allocator.free(ranked);
        for (ranked) |item| {
            try printCandidate(out, item.candidate);
        }
    }

    /// complete returns bounded next-argument values for one Cmd-tree position.
    /// Cmd owns route selection and Candidate policy; CLI owns shell quoting.
    pub fn complete(
        self: *Picker,
        allocator: std.mem.Allocator,
        position: CompletionPosition,
        raw_query: []const u8,
    ) ![]Completion {
        var values: [max_completion_candidates]Completion = undefined;
        var count: usize = 0;
        switch (position) {
            .mode => try collectModeCompletions(&values, &count, raw_query),
            .sub_cmd => try collectSubCmdCompletions(&values, &count, raw_query),
            .operation => try collectOperationCompletions(&values, &count, raw_query),
            .app => try self.collectAppCompletions(allocator, &values, &count, raw_query),
        }
        return try allocator.dupe(Completion, values[0..count]);
    }

    fn loadCandidatesOnce(self: *Picker, allocator: std.mem.Allocator) !void {
        if (self.candidates_loaded) return;
        try self.buildCandidatesTransactional(allocator);
    }

    /// buildCandidatesTransactional stages every producer into a fresh bounded list.
    /// The assignment below is the only publication point; rollback clears records before
    /// freeing producer-owned bytes so no published Candidate can dangle or be retried.
    fn buildCandidatesTransactional(self: *Picker, allocator: std.mem.Allocator) !void {
        self.candidates.clearRetainingCapacity();
        var staged = candidate.Candidate.List.empty;
        errdefer {
            staged.clearRetainingCapacity();
            self.candidates.clearRetainingCapacity();
            self.candidates_loaded = false;
            self.clearCandidateProducers(allocator);
        }

        for (self.cmds) |cmd| {
            switch (cmd) {
                .apps => |owner| if (owner) |apps| try apps.collectCandidates(allocator, &staged),
                .notifications => try notifications_mode.collectCandidates(&staged),
                .wallpaper => try wallpaper_mode.collectCandidates(&staged),
                .sunglasses => try sunglasses_mode.collectCandidates(&staged),
            }
        }
        if (self.notification_history) |owner| try owner.collect(allocator, &staged);
        self.candidates = staged;
        self.candidates_loaded = true;
    }

    /// clearCandidateProducers releases every producer allocation after staged records are forgotten.
    fn clearCandidateProducers(self: *Picker, allocator: std.mem.Allocator) void {
        for (self.cmds) |cmd| {
            switch (cmd) {
                .apps => |owner| if (owner) |apps| {
                    apps.freeCacheData(allocator);
                    apps.freeOwnedStrings(allocator);
                },
                .notifications, .wallpaper, .sunglasses => {},
            }
        }
        if (self.notification_history) |owner| owner.clearCandidateProduction(allocator);
    }

    fn appsOwner(self: *const Picker) ?*apps_mode.Apps {
        return switch (self.cmds[0]) {
            .apps => |owner| owner,
            .notifications, .wallpaper, .sunglasses => null,
        };
    }

    /// collectModeCandidates exposes resident Cmd arms as GUI route candidates.
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

    fn collectModeCompletions(
        out: *[max_completion_candidates]Completion,
        count: *usize,
        raw_query: []const u8,
    ) !void {
        const parsed = try query_mod.parse(raw_query);
        if (parsed.route != .modes) return error.CompletionPositionMismatch;
        inline for (std.meta.fields(Cmd)) |field| {
            try appendCompletion(out, count, field.name, parsed.term);
        }
    }

    fn collectSubCmdCompletions(
        out: *[max_completion_candidates]Completion,
        count: *usize,
        raw_query: []const u8,
    ) !void {
        const parsed = try query_mod.parse(raw_query);
        switch (parsed.route) {
            .notifications => try appendNotificationSubCmdCompletions(out, count, parsed.term),
            .wallpapers => try appendWallpaperSubCmdCompletions(out, count, parsed.term),
            .sunglasses => try appendSunglassesSubCmdCompletions(out, count, parsed.term),
            else => return error.CompletionPositionMismatch,
        }
    }

    fn collectOperationCompletions(
        out: *[max_completion_candidates]Completion,
        count: *usize,
        raw_query: []const u8,
    ) !void {
        const parsed = try query_mod.parse(raw_query);
        if (parsed.route != .sunglasses) return error.CompletionPositionMismatch;

        var terms = std.mem.tokenizeAny(u8, parsed.term, " \t");
        const operation = terms.next() orelse return error.CompletionPositionMismatch;
        const prefix = terms.next() orelse "";
        if (terms.next() != null) return error.CompletionPositionMismatch;

        if (std.mem.eql(u8, operation, "dim")) {
            inline for (std.meta.fields(sub_cmd.DimSubCmd)) |field| {
                try appendCompletion(out, count, field.name, prefix);
            }
            return;
        }
        if (std.mem.eql(u8, operation, "filter")) {
            inline for (std.meta.fields(sub_cmd.FilterSubCmd)) |field| {
                try appendCompletion(out, count, field.name, prefix);
            }
            return;
        }
        if (std.mem.eql(u8, operation, "image")) {
            inline for (std.meta.fields(sub_cmd.ImageSubCmd)) |field| {
                try appendCompletion(out, count, field.name, prefix);
            }
            return;
        }
        return error.CompletionPositionMismatch;
    }

    fn collectAppCompletions(
        self: *Picker,
        allocator: std.mem.Allocator,
        out: *[max_completion_candidates]Completion,
        count: *usize,
        raw_query: []const u8,
    ) !void {
        const parsed = try query_mod.parse(raw_query);
        if (parsed.route != .apps) return error.CompletionPositionMismatch;

        const ranked = try self.rankQuery(allocator, raw_query);
        defer allocator.free(ranked);
        if (ranked.len > max_completion_candidates) return error.TooManyCompletionCandidates;
        for (ranked) |item| {
            if (!candidate.Candidate.accepts(.bash_completion, item.candidate)) continue;
            try appendCompletion(out, count, item.candidate.selection(), "");
        }
    }
};

fn appendCompletion(
    out: *[max_completion_candidates]Completion,
    count: *usize,
    argument: []const u8,
    prefix: []const u8,
) !void {
    if (!std.mem.startsWith(u8, argument, prefix)) return;
    if (count.* >= max_completion_candidates) return error.TooManyCompletionCandidates;
    out[count.*] = .{ .argument = argument };
    count.* += 1;
}

fn appendNotificationSubCmdCompletions(
    out: *[max_completion_candidates]Completion,
    count: *usize,
    prefix: []const u8,
) !void {
    inline for (std.meta.fields(sub_cmd.NotificationsSubCmd)) |field| {
        try appendCompletion(out, count, field.name, prefix);
    }
}

fn appendWallpaperSubCmdCompletions(
    out: *[max_completion_candidates]Completion,
    count: *usize,
    prefix: []const u8,
) !void {
    inline for (std.meta.fields(sub_cmd.WallpaperSubCmd)) |field| {
        try appendCompletion(out, count, field.name, prefix);
    }
}

fn appendSunglassesSubCmdCompletions(
    out: *[max_completion_candidates]Completion,
    count: *usize,
    prefix: []const u8,
) !void {
    inline for (std.meta.fields(sub_cmd.SunglassesSubCmd)) |field| {
        try appendCompletion(out, count, field.name, prefix);
    }
}

fn makeCmds(apps: ?*apps_mode.Apps) [4]Cmd {
    return .{
        .{ .apps = apps },
        .{ .notifications = .{} },
        .{ .wallpaper = .{} },
        .{ .sunglasses = .{} },
    };
}

/// resolveLifecycle exhaustively resolves each resident leaf arm.
fn resolveLifecycle(allocator: std.mem.Allocator, value: candidate.Lifecycle) ![]u8 {
    return switch (value) {
        .notifications_restart => allocator.dupe(u8, notifications_mode.restartIntent()),
        .wallpaper_restart => allocator.dupe(u8, wallpaper_mode.restartIntent()),
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

fn printCandidate(out: *std.Io.Writer, value: candidate.Candidate) !void {
    try out.print("{s}\t{s}\t{s}\t{s}\n", .{
        @tagName(value.typeOf()),
        value.selection(),
        value.title(),
        value.subtitle(),
    });
}

fn recordHistory(
    history: *std.ArrayListUnmanaged([]u8),
    max_history: u32,
    allocator: std.mem.Allocator,
    selected_selection: []const u8,
) !void {
    if (selected_selection.len == 0) return;
    const copy = try allocator.dupe(u8, selected_selection);
    try history.append(allocator, copy);

    if (history.items.len > max_history) {
        const oldest = history.orderedRemove(0);
        allocator.free(oldest);
    }
}

fn loadHistorySelections(
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

fn saveHistorySelections(history: []const []const u8, history_path: ?[]const u8, allocator: std.mem.Allocator) !void {
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

test "Cmd picker collects candidates once per picker lifecycle" {
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

test "candidate loading rolls back overflow and retries without stale candidates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var overflow_data = std.ArrayList(u8).empty;
    defer overflow_data.deinit(std.testing.allocator);
    var index: usize = 0;
    while (index <= candidate.max_candidates) : (index += 1) {
        var line_buffer: [128]u8 = undefined;
        const line = try std.fmt.bufPrint(
            &line_buffer,
            "Utilities\tOverflow-{d}\tcommand-{d}\ticon\n",
            .{ index, index },
        );
        try overflow_data.appendSlice(std.testing.allocator, line);
    }
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data = overflow_data.items,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    const Fake = struct {
        fn cmdExists(_: []const u8) bool {
            return false;
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = cache_path,
        .cmd_exists_fn = Fake.cmdExists,
    };
    defer apps.deinit(std.testing.allocator);

    var model = Picker.init(&apps);
    defer model.deinit(std.testing.allocator);

    try std.testing.expectError(error.TooManyCandidates, model.rankQuery(std.testing.allocator, ""));
    try std.testing.expectEqual(@as(usize, 0), model.candidates.count);
    try std.testing.expect(!model.candidates_loaded);
    try std.testing.expect(apps.cache_data == null);
    try std.testing.expectEqual(@as(usize, 0), apps.owned_strings.items.len);

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data = "Utilities\tRecovered\trecovered\ticon\n",
    });

    const recovered = try model.rankQuery(std.testing.allocator, "recover");
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqual(@as(usize, 1), recovered.len);
    try std.testing.expectEqualStrings("Recovered", recovered[0].candidate.title());
    try std.testing.expectEqualStrings("recovered", recovered[0].candidate.selection());
    var apps_count: usize = 0;
    for (model.candidates.slice()) |candidate_value| {
        if (candidate_value.isApp() or candidate_value.isOpen()) apps_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), apps_count);
}

test "desktop scan overflow reaches transaction and retries cleanly" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const overflow_root = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/overflow", .{tmp.sub_path});
    defer std.testing.allocator.free(overflow_root);
    try tmp.dir.createDirPath(std.Options.debug_io, "overflow");

    var index: usize = 0;
    while (index <= candidate.max_candidates) : (index += 1) {
        var name_buffer: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "app-{d}.desktop", .{index});
        var sub_path_buffer: [128]u8 = undefined;
        const sub_path = try std.fmt.bufPrint(&sub_path_buffer, "overflow/{s}", .{name});
        var data_buffer: [256]u8 = undefined;
        const data = try std.fmt.bufPrint(
            &data_buffer,
            "[Desktop Entry]\nType=Application\nName=Overflow {d}\nExec=overflow-{d}\nIcon=icon\nCategories=Utility;\n",
            .{ index, index },
        );
        try tmp.dir.writeFile(std.Options.debug_io, .{ .sub_path = sub_path, .data = data });
    }

    const recovered_root = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/recovered", .{tmp.sub_path});
    defer std.testing.allocator.free(recovered_root);
    try tmp.dir.createDirPath(std.Options.debug_io, "recovered");
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "recovered/recovered.desktop",
        .data =
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Recovered Desktop App
        \\Exec=recovered-desktop
        \\Icon=icon
        \\Categories=Utility;
        \\
        ,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps-cache.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    const Fake = struct {
        fn cmdExists(_: []const u8) bool {
            return false;
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = cache_path,
        .cmd_exists_fn = Fake.cmdExists,
        .desktop_root = overflow_root,
    };
    defer apps.deinit(std.testing.allocator);

    var model = Picker.init(&apps);
    defer model.deinit(std.testing.allocator);

    try std.testing.expectError(error.TooManyCandidates, model.rankQuery(std.testing.allocator, ""));
    try std.testing.expectEqual(@as(usize, 0), model.candidates.count);
    try std.testing.expect(!model.candidates_loaded);
    try std.testing.expect(apps.cache_data == null);
    try std.testing.expectEqual(@as(usize, 0), apps.owned_strings.items.len);

    apps.desktop_root = recovered_root;
    const recovered = try model.rankQuery(std.testing.allocator, "recovered");
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqual(@as(usize, 1), recovered.len);
    try std.testing.expectEqualStrings("Recovered Desktop App", recovered[0].candidate.title());
    try std.testing.expectEqualStrings("recovered-desktop", recovered[0].candidate.selection());
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

test "Cmd picker exposes typed sunglasses leaves" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const results = try model.rankQuery(std.testing.allocator, "/sunglasses");
    defer std.testing.allocator.free(results);
    try std.testing.expectEqual(@as(u32, 6), @as(u32, @intCast(results.len)));
    try std.testing.expect(results[0].candidate.isLaunchable() or results[0].candidate.isSubCmd());
}

test "Cmd picker exposes every resident mode at the modes route" {
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

test "Cmd query enforces the bounded query input" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    var oversized: [query_mod.max_query_bytes + 1]u8 = undefined;
    @memset(oversized[0..], 'x');
    try std.testing.expectError(error.QueryTooLong, model.rankQuery(std.testing.allocator, oversized[0..]));
    try std.testing.expect(!model.candidates_loaded);
}

test "Cmd Apps route reaches installed and fixed-local leaves" {
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
        fn cmdExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = cache_path,
        .cmd_exists_fn = Fake.cmdExists,
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
    try std.testing.expectEqualStrings("settings", filtered[0].candidate.selection());
}

test "Cmd picker ranks retained history without query history allocation" {
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

test "picker history save creates nested parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/nested/history/history.log", .{base});
    defer std.testing.allocator.free(path);

    const entries = [_][]const u8{ "settings", "power" };
    try saveHistorySelections(entries[0..], path, std.testing.allocator);

    const saved = try tmp.dir.readFileAlloc(std.Options.debug_io, "nested/history/history.log", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("settings\npower\n", saved);
}

test "Cmd picker resolves app and lifecycle intents" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const lifecycle = try model.open(std.testing.allocator, notifications_mode.restart_selection);
    defer std.testing.allocator.free(lifecycle);
    try std.testing.expectEqualStrings("wayspot notifications", lifecycle);

    try std.testing.expectError(error.UnknownSelection, model.open(std.testing.allocator, "missing-selection"));
}

test "Cmd picker resolves resident lifecycle owners" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const wallpaper = try model.resolveCandidate(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.wallpaperRestart()));
    defer std.testing.allocator.free(wallpaper);
    try std.testing.expectEqualStrings("wayspot wallpaper", wallpaper);

    const rotate = try model.resolveCandidate(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.wallpaperRotate()));
    defer std.testing.allocator.free(rotate);
    try std.testing.expectEqualStrings("wayspot wallpaper rotate", rotate);

    const sunglasses = try model.resolveCandidate(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesRestart()));
    defer std.testing.allocator.free(sunglasses);
    try std.testing.expectEqualStrings("wayspot sunglasses", sunglasses);

    const apply = try model.resolveCandidate(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesApply()));
    defer std.testing.allocator.free(apply);
    try std.testing.expectEqualStrings("wayspot sunglasses apply", apply);

    const reconcile = try model.resolveCandidate(std.testing.allocator, candidate.Candidate.lifecycleLeaf(candidate.sunglassesReconcile()));
    defer std.testing.allocator.free(reconcile);
    try std.testing.expectEqualStrings("wayspot sunglasses reconcile", reconcile);
}

test "Cmd picker resolves typed sunglasses leaves" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim_input = try candidate.Input.scalarInput(35, 0, 100, 1);
    const dim = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP-1", dim_input));
    const dim_intent = try model.resolveCandidate(std.testing.allocator, dim);
    defer std.testing.allocator.free(dim_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP-1' set 35", dim_intent);

    const filter_input = try candidate.Input.scalarInput(-35, -100, 100, 1);
    const filter = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP-1", filter_input));
    const filter_intent = try model.resolveCandidate(std.testing.allocator, filter);
    defer std.testing.allocator.free(filter_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP-1' set -35", filter_intent);

    const image_input = try candidate.Input.pathInput("/tmp/sunglasses.png");
    const image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", image_input));
    const image_intent = try model.resolveCandidate(std.testing.allocator, image);
    defer std.testing.allocator.free(image_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' set '/tmp/sunglasses.png'", image_intent);
}

test "Cmd picker resolves every typed sunglasses Input arm" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim_toggle = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP-1", candidate.Input.toggleInput(false)));
    const dim_toggle_intent = try model.resolveCandidate(std.testing.allocator, dim_toggle);
    defer std.testing.allocator.free(dim_toggle_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP-1' off", dim_toggle_intent);

    const filter_toggle = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP-1", candidate.Input.toggleInput(true)));
    const filter_toggle_intent = try model.resolveCandidate(std.testing.allocator, filter_toggle);
    defer std.testing.allocator.free(filter_toggle_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP-1' on", filter_toggle_intent);

    const image_opacity = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", try candidate.Input.scalarInput(55, 0, 100, 1)));
    const image_opacity_intent = try model.resolveCandidate(std.testing.allocator, image_opacity);
    defer std.testing.allocator.free(image_opacity_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' opacity 55", image_opacity_intent);

    const image_clear = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", .none));
    const image_clear_intent = try model.resolveCandidate(std.testing.allocator, image_clear);
    defer std.testing.allocator.free(image_clear_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' clear", image_clear_intent);
}

test "Cmd picker shell-quotes dynamic sunglasses words" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const dim = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesDim("DP 1;$(touch x)", try candidate.Input.scalarInput(35, 0, 100, 1)));
    const dim_intent = try model.resolveCandidate(std.testing.allocator, dim);
    defer std.testing.allocator.free(dim_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses dim 'DP 1;$(touch x)' set 35", dim_intent);

    const filter = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesFilter("DP`1 $HOME", candidate.Input.toggleInput(true)));
    const filter_intent = try model.resolveCandidate(std.testing.allocator, filter);
    defer std.testing.allocator.free(filter_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses filter 'DP`1 $HOME' on", filter_intent);

    const path = try candidate.Input.pathInput("/tmp/a; touch /tmp/b $ `");
    const image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", path));
    const image_intent = try model.resolveCandidate(std.testing.allocator, image);
    defer std.testing.allocator.free(image_intent);
    try std.testing.expectEqualStrings("wayspot sunglasses image 'DP-1' set '/tmp/a; touch /tmp/b $ `'", image_intent);

    const quoted_path = try candidate.Input.pathInput("/tmp/a'b");
    const quoted_image = candidate.Candidate.lifecycleLeaf(try candidate.sunglassesImage("DP-1", quoted_path));
    const quoted_intent = try model.resolveCandidate(std.testing.allocator, quoted_image);
    defer std.testing.allocator.free(quoted_intent);
    try std.testing.expect(std.mem.indexOf(u8, quoted_intent, "'\\''") != null);
}

test "Cmd picker rejects newline dynamic words before resolution" {
    const scalar = try candidate.Input.scalarInput(35, 0, 100, 1);

    try std.testing.expectError(error.MonitorByteInvalid, candidate.sunglassesDim("DP-1\n", scalar));
    try std.testing.expectError(error.PathByteInvalid, candidate.Input.pathInput("/tmp/a\nb"));
}

test "Cmd picker explicitly rejects every route and display-only notification" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const routes = [_]candidate.Candidate{
        candidate.Candidate.subCmd(.{ .notifications = .{ .history = {} } }),
        candidate.Candidate.subCmd(.{ .wallpaper = .{ .rotate = {} } }),
        candidate.Candidate.subCmd(.{ .sunglasses = .{ .dim = .{ .set = {} } } }),
    };
    for (routes) |route| {
        try std.testing.expectError(error.CandidateNotLaunchable, model.resolveCandidate(std.testing.allocator, route));
    }

    const notification = candidate.Candidate.notificationLeaf("Summary", "App", "notification-history:0:1");
    try std.testing.expectError(error.NotificationDisplayOnly, model.resolveCandidate(std.testing.allocator, notification));
}

test "Cmd picker rejects invalid typed leaf at resolution" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const invalid = candidate.Candidate.lifecycleLeaf(.{
        .sunglasses_dim = .{
            .monitor = .{},
            .input = .none,
        },
    });
    try std.testing.expectError(error.MonitorEmpty, model.resolveCandidate(std.testing.allocator, invalid));
}

test "Cmd picker keeps app selection behavior" {
    const Fake = struct {
        fn cmdExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }
    };

    var apps = apps_mode.Apps{
        .cache_path = "unused",
        .cmd_exists_fn = Fake.cmdExists,
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

    const intent = try model.open(std.testing.allocator, "foot");
    defer std.testing.allocator.free(intent);
    try std.testing.expectEqualStrings("foot", intent);

    const open_leaf = candidate.Candidate.openLeaf("Settings", "System", "settings", "");
    const open_intent = try model.resolveCandidate(std.testing.allocator, open_leaf);
    defer std.testing.allocator.free(open_intent);
    try std.testing.expectEqualStrings("wlrlui", open_intent);
}

test "Cmd picker writes notification candidates" {
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
    try model.query(std.testing.allocator, "/notifications history", &output.writer);

    try std.testing.expectEqualStrings("concrete\tnotification-history:0:1\tSummary\tApp\n", output.written());
}

test "Cmd picker returns next app arguments" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    try list.append(candidate.Candidate.appLeaf("Quote App", "Utilities", "quote'app", ""));

    var model = Picker{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    const completed = try model.complete(std.testing.allocator, .app, "/apps quote");
    defer std.testing.allocator.free(completed);
    try std.testing.expectEqual(@as(usize, 1), completed.len);
    try std.testing.expectEqualStrings("quote'app", completed[0].argument);
}

test "Cmd completion returns route words and excludes notification records" {
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

    const completed = try model.complete(std.testing.allocator, .sub_cmd, "/notifications");
    defer std.testing.allocator.free(completed);
    try std.testing.expectEqual(@as(usize, 2), completed.len);
    try std.testing.expectEqualStrings("history", completed[0].argument);
    try std.testing.expectEqualStrings("restart", completed[1].argument);
    for (completed) |value| {
        try std.testing.expect(std.mem.indexOf(u8, value.argument, "notification-history") == null);
    }
}

test "Cmd completion enforces its bounded app result" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();
    var index: usize = 0;
    while (index <= max_completion_candidates) : (index += 1) {
        try list.append(candidate.Candidate.appLeaf("App", "Utilities", "app", ""));
    }

    var model = Picker{
        .candidates = list,
        .candidates_loaded = true,
    };
    list = .empty;
    defer model.deinit(std.testing.allocator);

    try std.testing.expectError(error.TooManyCompletionCandidates, model.complete(std.testing.allocator, .app, "/apps"));
}

test "Cmd completion returns one next word at every routed position" {
    var model = Picker{};
    defer model.deinit(std.testing.allocator);

    const modes = try model.complete(std.testing.allocator, .mode, "/");
    defer std.testing.allocator.free(modes);
    try std.testing.expectEqual(@as(usize, 4), modes.len);
    try std.testing.expectEqualStrings("apps", modes[0].argument);
    try std.testing.expectEqualStrings("notifications", modes[1].argument);
    try std.testing.expectEqualStrings("wallpaper", modes[2].argument);
    try std.testing.expectEqualStrings("sunglasses", modes[3].argument);

    const sub_cmds = try model.complete(std.testing.allocator, .sub_cmd, "/sunglasses ");
    defer std.testing.allocator.free(sub_cmds);
    try std.testing.expectEqual(@as(usize, 6), sub_cmds.len);
    try std.testing.expectEqualStrings("restart", sub_cmds[0].argument);
    try std.testing.expectEqualStrings("apply", sub_cmds[1].argument);
    try std.testing.expectEqualStrings("reconcile", sub_cmds[2].argument);
    try std.testing.expectEqualStrings("dim", sub_cmds[3].argument);
    try std.testing.expectEqualStrings("filter", sub_cmds[4].argument);
    try std.testing.expectEqualStrings("image", sub_cmds[5].argument);

    const operations = try model.complete(std.testing.allocator, .operation, "/sunglasses dim ");
    defer std.testing.allocator.free(operations);
    try std.testing.expectEqual(@as(usize, 3), operations.len);
    try std.testing.expectEqualStrings("set", operations[0].argument);
    try std.testing.expectEqualStrings("on", operations[1].argument);
    try std.testing.expectEqualStrings("off", operations[2].argument);
}
