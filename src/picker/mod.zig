//! Picker owns one CLI-summoned selection lifecycle, query ranking, and rows.

const std = @import("std");
pub const appearance = @import("appearance.zig");
pub const candidate = @import("picker_candidate");
pub const cursor_blink = @import("cursor_blink.zig");
pub const icon_cache = @import("icon_cache.zig");
pub const icon_diag = @import("icon_diag.zig");
pub const icons = @import("icons.zig");
pub const mode = @import("mode/mod.zig");
pub const open = @import("open.zig");
pub const query = @import("query.zig");
pub const rank = @import("rank.zig");
pub const scale = @import("scale.zig");
pub const slider = @import("slider.zig");
pub const surface = @import("surface.zig");
pub const text = @import("text.zig");
pub const textbox = @import("textbox.zig");
pub const viewport = @import("viewport.zig");

const apps_mode = @import("mode/apps.zig");
const history_list = @import("../notification/history_list.zig");

/// Picker keeps candidate rows and persisted selection history for one picker lifecycle.
pub const Picker = struct {
    opens: ?*open.Open = null,
    apps: ?*apps_mode.Apps = null,
    modes: ?*mode.Mode = null,
    notification_history: ?*history_list.NotificationHistoryList = null,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    candidates: candidate.Candidate.List = .empty,
    candidates_loaded: bool = false,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,

    /// Builds a picker with optional fixed open and app row owners.
    pub fn init(opens: ?*open.Open, apps: ?*apps_mode.Apps) Picker {
        return .{
            .opens = opens,
            .apps = apps,
        };
    }

    /// Builds a picker with persisted history and slash mode rows.
    pub fn initWithHistoryPath(
        opens: ?*open.Open,
        apps: ?*apps_mode.Apps,
        modes: ?*mode.Mode,
        history_path: []const u8,
    ) Picker {
        return .{
            .opens = opens,
            .apps = apps,
            .modes = modes,
            .history_path = history_path,
        };
    }

    pub fn deinit(self: *Picker, allocator: std.mem.Allocator) void {
        self.candidates.deinit(allocator);
        deinitHistory(&self.history, allocator);
    }

    /// rankQuery returns ranked rows for the current query string.
    pub fn rankQuery(self: *Picker, allocator: std.mem.Allocator, raw_query: []const u8) ![]rank.RankedCandidate {
        try self.loadCandidatesOnce(allocator);

        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        const ranked = try rank.rankCandidatesWithOldestFirstHistory(
            allocator,
            query.parse(raw_query),
            self.candidates.items,
            self.history.items,
        );
        return ranked;
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

    fn loadCandidatesOnce(self: *Picker, allocator: std.mem.Allocator) !void {
        if (self.candidates_loaded) return;
        if (self.modes) |owner| try owner.collect(allocator, &self.candidates);
        if (self.notification_history) |owner| try owner.collect(allocator, &self.candidates);
        if (self.opens) |owner| try owner.collect(allocator, &self.candidates);
        if (self.apps) |owner| try owner.collect(allocator, &self.candidates);
        self.candidates_loaded = true;
    }
};

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

test "picker collects candidates once per picker lifecycle" {
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
    var picker = Picker.init(null, &apps);
    defer picker.deinit(std.testing.allocator);

    const first = try picker.rankQuery(std.testing.allocator, "kit");
    defer std.testing.allocator.free(first);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));

    const second = try picker.rankQuery(std.testing.allocator, "fire");
    defer std.testing.allocator.free(second);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
}

test "picker exposes modes without hiding default app ranking" {
    var modes = mode.Mode{};
    var picker = Picker{
        .modes = &modes,
    };
    defer picker.deinit(std.testing.allocator);

    const mode_results = try picker.rankQuery(std.testing.allocator, "/");
    defer std.testing.allocator.free(mode_results);
    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(mode_results.len)));
    try std.testing.expectEqual(candidate.Candidate.Kind.mode, mode_results[0].candidate.kind);
}

test "picker ranks retained history without query history allocation" {
    var picker = Picker.init(null, null);
    defer picker.deinit(std.testing.allocator);
    picker.candidates_loaded = true;
    try recordHistory(&picker.history, picker.max_history, std.testing.allocator, "power");

    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const ranked = try picker.rankQuery(fba.allocator(), "p");
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
    try saveHistoryRows(entries[0..], path, std.testing.allocator);

    const saved = try tmp.dir.readFileAlloc(std.Options.debug_io, "nested/history/history.log", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("settings\npower\n", saved);
}
