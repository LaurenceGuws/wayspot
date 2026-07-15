//! NotificationHistoryList owns picker candidates loaded from notification History.

const std = @import("std");
const builtin = @import("builtin");
const history = @import("wayspot_history");
const preview = @import("wayspot_notification_preview");
const candidate_mod = @import("picker_candidate");

const selection_prefix = "notification-history:";
const max_open_bytes: usize = 32;

comptime {
    std.debug.assert(max_open_bytes > selection_prefix.len);
}

pub const NotificationHistoryList = struct {
    /// loaded prevents a second history read until producer strings are cleared.
    loaded: bool = false,
    owned_strings: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn deinit(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        self.clearCandidateProduction(allocator);
        self.owned_strings.deinit(allocator);
    }

    /// clearCandidateProduction releases producer strings and permits another read.
    pub fn clearCandidateProduction(self: *NotificationHistoryList, allocator: std.mem.Allocator) void {
        for (self.owned_strings.items) |text| allocator.free(text);
        self.owned_strings.clearRetainingCapacity();
        self.loaded = false;
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
        if (self.loaded) return;
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
        if (self.loaded) return;
        var loaded_history = try history.History.loadAtPath(allocator, path, now_ns);
        defer loaded_history.deinit();

        var staged = candidate_mod.Candidate.List.empty;
        errdefer self.clearCandidateProduction(allocator);
        std.mem.sort(history.Row, loaded_history.rows.items, {}, rowNewer);
        for (loaded_history.rows.items) |row| {
            try self.appendRow(allocator, &staged, row);
        }

        const remaining = out.items.len - out.count;
        if (staged.count > remaining) return error.TooManyCandidates;
        for (staged.slice()) |candidate| {
            out.append(candidate) catch unreachable;
        }
        self.loaded = true;
    }

    fn appendRow(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        staged: *candidate_mod.Candidate.List,
        row: history.Row,
    ) !void {
        const title = preview.historyTitle(row.app_name, row.summary);
        const subtitle = preview.historySubtitle(row.app_name, row.body);
        const selection = try std.fmt.allocPrint(allocator, "{s}{d}", .{ selection_prefix, row.id });
        try self.appendSelection(allocator, staged, title.slice(), subtitle.slice(), selection);
    }

    fn appendSelection(
        self: *NotificationHistoryList,
        allocator: std.mem.Allocator,
        staged: *candidate_mod.Candidate.List,
        title: []const u8,
        subtitle: []const u8,
        selection: []u8,
    ) !void {
        errdefer allocator.free(selection);
        if (selection.len > max_open_bytes) return error.NotificationHistoryOpenTooLong;
        const owned_title = try allocator.dupe(u8, title);
        errdefer allocator.free(owned_title);
        const owned_subtitle = try allocator.dupe(u8, subtitle);
        errdefer allocator.free(owned_subtitle);

        try self.owned_strings.ensureUnusedCapacity(allocator, 3);
        try staged.append(candidate_mod.Candidate.notificationLeaf(owned_title, owned_subtitle, selection));
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

test "notification History list projects newest rows and loads once" {
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
    try source_history.upsert(.{
        .id = std.math.maxInt(u32),
        .created_ns = 3,
        .updated_ns = now,
        .app_name = "Newest App",
        .summary = "max",
    });
    try source_history.saveAtPath(path);

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();

    try std.testing.expect(!list_owner.loaded);
    try list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now);
    try std.testing.expect(list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 3), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate_mod.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings("max", list.items[0].title());
    try std.testing.expectEqualStrings("notification-history:4294967295", list.items[0].selection());
    try std.testing.expectEqualStrings("new", list.items[1].title());
    try std.testing.expectEqualStrings("notification-history:2", list.items[1].selection());
    try std.testing.expectEqualStrings("old", list.items[2].title());
    try std.testing.expectEqualStrings("notification-history:1", list.items[2].selection());

    try list_owner.collectAtPathForTest(std.testing.allocator, &list, "missing.json", now);
    try std.testing.expectEqual(@as(usize, 3), list.count);
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
    try std.testing.expect(list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 3), list_owner.owned_strings.items.len);

    list.clearRetainingCapacity();
    list_owner.clearCandidateProduction(std.testing.allocator);
    try std.testing.expect(!list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);

    list_owner.clearCandidateProduction(std.testing.allocator);
    try std.testing.expect(!list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);
}

test "notification History list retries after a failed read" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "history.json", .data = "{" });

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    const now = history.retention_ns + 100;

    try std.testing.expectError(
        error.InvalidHistoryJson,
        list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now),
    );
    try std.testing.expect(!list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 0), list.count);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);

    var source_history = history.History.init(std.testing.allocator);
    defer source_history.deinit();
    try source_history.upsert(.{
        .id = 7,
        .created_ns = 7,
        .updated_ns = now,
        .app_name = "Mail",
        .summary = "retried",
    });
    try source_history.saveAtPath(path);

    try list_owner.collectAtPathForTest(std.testing.allocator, &list, path, now);
    try std.testing.expect(list_owner.loaded);
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqualStrings("notification-history:7", list.items[0].selection());
}

test "notification History list enforces the selection bound" {
    const exact_selection = "notification-history:12345678901";
    try std.testing.expectEqual(max_open_bytes, exact_selection.len);

    var exact_owner = NotificationHistoryList{};
    defer exact_owner.deinit(std.testing.allocator);
    var exact_staged = candidate_mod.Candidate.List.empty;
    defer exact_staged.deinit();
    const exact_copy = try std.testing.allocator.dupe(u8, exact_selection);
    try exact_owner.appendSelection(
        std.testing.allocator,
        &exact_staged,
        "title",
        "subtitle",
        exact_copy,
    );
    try std.testing.expectEqual(@as(usize, 1), exact_staged.count);
    try std.testing.expectEqualStrings(exact_selection, exact_staged.items[0].selection());

    var overlong_owner = NotificationHistoryList{};
    defer overlong_owner.deinit(std.testing.allocator);
    var overlong_staged = candidate_mod.Candidate.List.empty;
    defer overlong_staged.deinit();
    const overlong = try std.fmt.allocPrint(
        std.testing.allocator,
        "{s}123456789012",
        .{selection_prefix},
    );
    try std.testing.expectError(
        error.NotificationHistoryOpenTooLong,
        overlong_owner.appendSelection(
            std.testing.allocator,
            &overlong_staged,
            "title",
            "subtitle",
            overlong,
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), overlong_staged.count);
    try std.testing.expectEqual(@as(usize, 0), overlong_owner.owned_strings.items.len);
}

test "notification History list allocation failure cleans every owner" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    var source_history = history.History.init(std.testing.allocator);
    defer source_history.deinit();
    try source_history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = history.retention_ns + 100,
        .app_name = "Mail",
        .summary = "one",
    });
    try source_history.upsert(.{
        .id = 2,
        .created_ns = 2,
        .updated_ns = history.retention_ns + 100,
        .app_name = "Mail",
        .summary = "two",
    });
    try source_history.saveAtPath(path);

    const now = history.retention_ns + 100;
    var saw_failure = false;
    var saw_success = false;
    var fail_index: usize = 0;
    while (fail_index < 64) : (fail_index += 1) {
        var failing_state = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        var list_owner = NotificationHistoryList{};
        var list = candidate_mod.Candidate.List.empty;
        const result = list_owner.collectAtPathForTest(
            failing_state.allocator(),
            &list,
            path,
            now,
        );
        if (result) |_| {
            saw_success = true;
        } else |err| {
            saw_failure = true;
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(!list_owner.loaded);
            try std.testing.expectEqual(@as(usize, 0), list.count);
            try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);
        }
        list.deinit();
        list_owner.deinit(failing_state.allocator());
        try std.testing.expectEqual(failing_state.allocated_bytes, failing_state.freed_bytes);
    }
    try std.testing.expect(saw_failure);
    try std.testing.expect(saw_success);
}

test "notification History list stages output before publishing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/history.json", .{tmp.sub_path});
    defer std.testing.allocator.free(path);

    var source_history = history.History.init(std.testing.allocator);
    defer source_history.deinit();
    try source_history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = history.retention_ns + 100,
        .app_name = "Mail",
        .summary = "full",
    });
    try source_history.saveAtPath(path);

    var list_owner = NotificationHistoryList{};
    defer list_owner.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    while (list.count < candidate_mod.max_candidates) {
        try list.append(candidate_mod.Candidate.appLeaf("existing", "", "existing", ""));
    }

    try std.testing.expectError(
        error.TooManyCandidates,
        list_owner.collectAtPathForTest(
            std.testing.allocator,
            &list,
            path,
            history.retention_ns + 100,
        ),
    );
    try std.testing.expect(!list_owner.loaded);
    try std.testing.expectEqual(candidate_mod.max_candidates, list.count);
    try std.testing.expectEqual(@as(usize, 0), list_owner.owned_strings.items.len);
}
