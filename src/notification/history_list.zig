//! NotificationHistoryList owns picker rows loaded from the persisted notification cache.

const std = @import("std");
const builtin = @import("builtin");
const history_cache = @import("wayspot_history_cache");
const preview = @import("wayspot_notification_preview");
const candidate_mod = @import("picker_candidate");

const open_prefix = "notification-history:";
const max_open_bytes: u32 = 64;

comptime {
    std.debug.assert(max_open_bytes > open_prefix.len);
}

pub const NotificationHistoryList = struct {
    cache: ?history_cache.Cache = null,
    owned_strings: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn deinit(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        self.clearCandidateProduction(allocator);
        self.owned_strings.deinit(allocator);
    }

    /// clearCandidateProduction releases rows and cache state after a staged build fails.
    pub fn clearCandidateProduction(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        for (self.owned_strings.items) |text| allocator.free(text);
        self.owned_strings.clearRetainingCapacity();
        if (self.cache) |*cache| cache.deinit();
        self.cache = null;
    }

    pub fn collect(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
    ) !void {
        const path = try history_cache.cachePath(allocator);
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
        self.cache = try history_cache.Cache.loadAtPath(allocator, path, now_ns);
        std.mem.sort(history_cache.Row, self.cache.?.rows.items, {}, rowNewer);
        for (self.cache.?.rows.items, 0..) |row, idx| {
            try self.appendRow(allocator, out, row, @intCast(idx));
        }
    }

    fn appendRow(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        row: history_cache.Row,
        newest_rank: u32,
    ) !void {
        const title = preview.historyTitle(row.app_name, row.summary);
        const subtitle = preview.historySubtitle(row.app_name, row.body);
        const open_payload = try std.fmt.allocPrint(allocator, "{s}{d}:{d}", .{ open_prefix, newest_rank, row.id });
        errdefer allocator.free(open_payload);
        if (open_payload.len > max_open_bytes) return error.NotificationHistoryOpenTooLong;
        const owned_title = try allocator.dupe(u8, title.slice());
        errdefer allocator.free(owned_title);
        const owned_subtitle = try allocator.dupe(u8, subtitle.slice());
        errdefer allocator.free(owned_subtitle);

        try self.owned_strings.ensureUnusedCapacity(allocator, 3);
        try out.append(candidate_mod.Candidate.notificationLeaf(owned_title, owned_subtitle, open_payload));
        self.owned_strings.appendAssumeCapacity(open_payload);
        self.owned_strings.appendAssumeCapacity(owned_title);
        self.owned_strings.appendAssumeCapacity(owned_subtitle);
    }
};

fn rowNewer(_: void, a: history_cache.Row, b: history_cache.Row) bool {
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

test "notification history list exposes newest cached rows first" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    const now = history_cache.retention_ns + 100;
    var cache = history_cache.Cache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.upsert(.{ .id = 1, .created_ns = 1, .updated_ns = now - 5, .app_name = "Old App", .summary = "old" });
    try cache.upsert(.{ .id = 2, .created_ns = 2, .updated_ns = now, .app_name = "New App", .summary = "new" });
    try cache.saveAtPath(path);

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();

    try list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now);
    try std.testing.expectEqual(@as(usize, 2), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate_mod.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings("new", list.items[0].title());
    try std.testing.expect(std.mem.startsWith(u8, list.items[0].openPayload(), open_prefix));
}

test "notification history candidate cleanup is repeatable" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    const now = history_cache.retention_ns + 100;
    var cache = history_cache.Cache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.upsert(.{ .id = 1, .created_ns = 1, .updated_ns = now, .app_name = "Mail", .summary = "message" });
    try cache.saveAtPath(path);

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
