//! NotificationHistoryList owns picker candidates loaded from notification History.

const std = @import("std");
const builtin = @import("builtin");
const history = @import("wayspot_history");
const preview = @import("wayspot_notification_preview");
const candidate_mod = @import("picker_candidate");

const open_prefix = "notification-history:";
const max_open_bytes: u32 = 64;

comptime {
    std.debug.assert(max_open_bytes > open_prefix.len);
}

pub const NotificationHistoryList = struct {
    cache: ?history.History = null,
    owned_strings: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn deinit(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        self.clearCandidateProduction(allocator);
        self.owned_strings.deinit(allocator);
    }

    /// clearCandidateProduction releases candidates and loaded History state after a staged build fails.
    pub fn clearCandidateProduction(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        for (self.owned_strings.items) |text| allocator.free(text);
        self.owned_strings.clearRetainingCapacity();
        if (self.cache) |*loaded_history| loaded_history.deinit();
        self.cache = null;
    }

    pub fn collect(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
    ) !void {
        const path = try history.path(allocator);
        defer allocator.free(path);
        try self.collectAtPath(allocator, out, path);
    }

    fn collectAtPath(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        path: []const u8,
    ) !void {
        if (self.cache != null) return;
        try self.collectAtPathAtTime(allocator, out, path, realtimeNs());
    }

    pub fn collectAtPathForTest(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        path: []const u8,
        now_ns: u64,
    ) !void {
        if (!builtin.is_test) @compileError("collectAtPathForTest is test-only");
        try self.collectAtPathAtTime(allocator, out, path, now_ns);
    }

    fn collectAtPathAtTime(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        path: []const u8,
        now_ns: u64,
    ) !void {
        if (self.cache != null) return;
        self.cache = try history.History.loadAtPath(allocator, path, now_ns);
        std.mem.sort(history.Row, self.cache.?.rows.items, {}, rowNewer);
        for (self.cache.?.rows.items, 0..) |row, idx| {
            try self.appendRow(allocator, out, row, @intCast(idx));
        }
    }

    fn appendRow(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        row: history.Row,
        newest_rank: u32,
    ) !void {
        const title = preview.historyTitle(row.app_name, row.summary);
        const subtitle = preview.historySubtitle(row.app_name, row.body);
        const selection = try std.fmt.allocPrint(allocator, "{s}{d}:{d}", .{ open_prefix, newest_rank, row.id });
        errdefer allocator.free(selection);
        if (selection.len > max_open_bytes) return error.NotificationHistoryOpenTooLong;
        const owned_title = try allocator.dupe(u8, title.slice());
        errdefer allocator.free(owned_title);
        const owned_subtitle = try allocator.dupe(u8, subtitle.slice());
        errdefer allocator.free(owned_subtitle);

        try self.owned_strings.ensureUnusedCapacity(allocator, 3);
        try out.append(candidate_mod.Candidate.notificationLeaf(owned_title, owned_subtitle, selection));
        self.owned_strings.appendAssumeCapacity(selection);
        self.owned_strings.appendAssumeCapacity(owned_title);
        self.owned_strings.appendAssumeCapacity(owned_subtitle);
    }
};

fn rowNewer(_: void, a: history.Row, b: history.Row) bool {
    if (a.updated_ns != b.updated_ns) return a.updated_ns > b.updated_ns;
    return a.id > b.id;
}

fn realtimeNs() u64 {
    var ts: std.os.linux.timespec = undefined;
    const rc = std.os.linux.clock_gettime(.REALTIME, &ts);
    if (std.os.linux.errno(rc) != .SUCCESS) return 0;
    const seconds_ns: u64 = @intCast(ts.sec * std.time.ns_per_s);
    const nanos: u64 = @intCast(ts.nsec);
    return seconds_ns + nanos;
}

test "notification History list exposes newest rows first" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    const now = history.retention_ns + 100;
    var source_history = history.History.init(std.testing.allocator);
    defer source_history.deinit();
    try source_history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = now - 5,
        .app_name = "Old App",
        .summary = "old",
    });
    try source_history.upsert(.{
        .id = 2,
        .created_ns = 2,
        .updated_ns = now,
        .app_name = "New App",
        .summary = "new",
    });
    try source_history.saveAtPath(path);

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();

    try list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now);
    try std.testing.expectEqual(@as(usize, 2), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate_mod.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings("new", list.items[0].title());
    try std.testing.expect(std.mem.startsWith(u8, list.items[0].selection(), open_prefix));
}

test "notification history candidate cleanup is repeatable" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    const now = history.retention_ns + 100;
    var source_history = history.History.init(std.testing.allocator);
    defer source_history.deinit();
    try source_history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = now,
        .app_name = "Mail",
        .summary = "message",
    });
    try source_history.saveAtPath(path);

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();

    try list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now);
    try std.testing.expect(list_owner.cache != null);
    try std.testing.expectEqual(@as(usize, 3), list_owner.owned_strings.items.len);

    list.clearRetainingCapacity();
    list_owner.clearCandidateProduction(std.testing.allocator);
    try std.testing.expect(list_owner.cache == null);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);

    list_owner.clearCandidateProduction(std.testing.allocator);
    try std.testing.expect(list_owner.cache == null);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);
}
