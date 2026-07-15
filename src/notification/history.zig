//! Notification history owns bounded persistent JSON rows.

const std = @import("std");

pub const version: u32 = 1;
pub const max_file_bytes: u32 = 2 * 1024 * 1024;
pub const max_rows: u32 = 512;
pub const max_app_name_bytes: u32 = 256;
pub const max_app_icon_bytes: u32 = 256;
pub const max_summary_bytes: u32 = 512;
pub const max_body_bytes: u32 = 4096;
pub const retention_ns: u64 = 7 * 24 * 60 * 60 * 1_000_000_000;

const relative_path = "wayspot/notifications-history.json";

comptime {
    std.debug.assert(max_file_bytes > 0);
    std.debug.assert(max_rows > 0);
    std.debug.assert(max_app_name_bytes > 0);
    std.debug.assert(max_app_icon_bytes > 0);
    std.debug.assert(max_summary_bytes > 0);
    std.debug.assert(max_body_bytes > 0);
    std.debug.assert(retention_ns > 0);
}

/// RowInput is one bounded notification update supplied to History; overlong
/// text returns error.HistoryFieldTooLong.
pub const RowInput = struct {
    id: u32,
    created_ns: u64,
    updated_ns: u64,
    app_name: []const u8 = "",
    app_icon: []const u8 = "",
    summary: []const u8 = "",
    body: []const u8 = "",
    urgency: u8 = 0,
    transient: bool = false,
    active: bool = false,
    closed_reason: u32 = 0,
};

/// Row owns one retained notification history row.
pub const Row = struct {
    id: u32,
    created_ns: u64,
    updated_ns: u64,
    app_name: []u8,
    app_icon: []u8,
    summary: []u8,
    body: []u8,
    urgency: u8,
    transient: bool,
    active: bool,
    closed_reason: u32,
};

/// History owns bounded retained notification rows and their persistence.
pub const History = struct {
    allocator: std.mem.Allocator,
    rows: std.ArrayListUnmanaged(Row) = .empty,
    updated_ns: u64 = 0,

    /// init creates an empty history owned by allocator.
    pub fn init(allocator: std.mem.Allocator) History {
        return .{ .allocator = allocator };
    }

    /// deinit frees every retained row and the backing list.
    pub fn deinit(self: *History) void {
        for (self.rows.items) |row| freeRow(self.allocator, row);
        self.rows.deinit(self.allocator);
    }

    /// len returns the bounded retained row count.
    pub fn len(self: *const History) u32 {
        return @intCast(self.rows.items.len);
    }

    /// upsert replaces or appends one row, enforces retention bounds, and
    /// leaves existing rows unchanged when field validation fails.
    pub fn upsert(self: *History, input: RowInput) !void {
        if (findIndex(self.rows.items, input.id)) |idx| {
            const replacement = try duplicateRow(self.allocator, input);
            freeRow(self.allocator, self.rows.items[idx]);
            self.rows.items[idx] = replacement;
        } else {
            try self.rows.ensureUnusedCapacity(self.allocator, 1);
            const row = try duplicateRow(self.allocator, input);
            self.rows.appendAssumeCapacity(row);
        }
        self.updated_ns = @max(self.updated_ns, input.updated_ns);
        self.keepNewestRows();
    }

    /// pruneOld removes rows older than the retention window.
    pub fn pruneOld(self: *History, now_ns: u64) void {
        const oldest_kept = now_ns -| retention_ns;
        var idx: u32 = 0;
        while (idx < self.rows.items.len) {
            if (self.rows.items[idx].updated_ns >= oldest_kept) {
                idx += 1;
                continue;
            }
            const removed = self.rows.orderedRemove(idx);
            freeRow(self.allocator, removed);
        }
    }

    /// saveAtPath writes the history atomically to one explicit path.
    pub fn saveAtPath(self: *const History, history_path: []const u8) !void {
        const data = try serialize(self.allocator, self);
        defer self.allocator.free(data);
        try writeAtomicAnyPath(history_path, data);
    }

    fn keepNewestRows(self: *History) void {
        while (self.rows.items.len > max_rows) {
            var oldest_idx: u32 = 0;
            var idx: u32 = 1;
            while (idx < self.rows.items.len) : (idx += 1) {
                if (rowNewer(self.rows.items[oldest_idx], self.rows.items[idx])) oldest_idx = idx;
            }
            const removed = self.rows.orderedRemove(oldest_idx);
            freeRow(self.allocator, removed);
        }
    }

    /// load reads the configured notification history path.
    pub fn load(allocator: std.mem.Allocator, now_ns: u64) !History {
        const history_path = try path(allocator);
        defer allocator.free(history_path);
        return History.loadAtPath(allocator, history_path, now_ns);
    }

    /// loadAtPath reads one explicit history path and applies retention bounds.
    pub fn loadAtPath(allocator: std.mem.Allocator, history_path: []const u8, now_ns: u64) !History {
        var history = History.init(allocator);
        const raw = readAnyPath(allocator, history_path) catch |err| switch (err) {
            error.FileNotFound => return history,
            else => return err,
        };
        defer allocator.free(raw);

        parseInto(&history, raw) catch |err| {
            history.deinit();
            return err;
        };
        history.pruneOld(now_ns);
        history.keepNewestRows();
        return history;
    }
};

/// path returns the configured notification history path.
pub fn path(allocator: std.mem.Allocator) ![]u8 {
    const state_home = if (std.c.getenv("XDG_STATE_HOME")) |state_home_z| std.mem.span(state_home_z) else null;
    const home = if (std.c.getenv("HOME")) |home_z| std.mem.span(home_z) else ".";
    return pathFromEnvironment(allocator, state_home, home);
}

fn pathFromEnvironment(allocator: std.mem.Allocator, state_home: ?[]const u8, home: []const u8) ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const formatted = if (state_home) |value|
        std.fmt.bufPrint(&buffer, "{s}/{s}", .{ value, relative_path })
    else
        std.fmt.bufPrint(&buffer, "{s}/.local/state/{s}", .{ home, relative_path });
    const bounded = formatted catch return error.HistoryPathTooLong;
    return allocator.dupe(u8, bounded);
}

fn parseInto(history: *History, raw: []const u8) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, history.allocator, raw, .{}) catch |err| switch (err) {
        error.SyntaxError, error.UnexpectedEndOfInput => return error.InvalidHistoryJson,
        else => return err,
    };
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidHistoryJson;

    const version_value = parsed.value.object.get("version") orelse return error.InvalidHistoryJson;
    if ((jsonU32(version_value) orelse return error.InvalidHistoryJson) != version)
        return error.UnsupportedHistoryVersion;

    const updated_value = parsed.value.object.get("updated_ns") orelse return error.InvalidHistoryJson;
    history.updated_ns = jsonU64(updated_value) orelse return error.InvalidHistoryJson;

    const rows_value = parsed.value.object.get("rows") orelse return error.InvalidHistoryJson;
    if (rows_value != .array) return error.InvalidHistoryJson;

    for (rows_value.array.items) |item| {
        const input = try parseRow(item);
        try history.upsert(input);
    }
}

fn parseRow(value: std.json.Value) !RowInput {
    if (value != .object) return error.InvalidHistoryRow;
    return .{
        .id = jsonU32(
            value.object.get("id") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .created_ns = jsonU64(
            value.object.get("created_ns") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .updated_ns = jsonU64(
            value.object.get("updated_ns") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .app_name = jsonString(
            value.object.get("app_name") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .app_icon = jsonString(
            value.object.get("app_icon") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .summary = jsonString(
            value.object.get("summary") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .body = jsonString(
            value.object.get("body") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .urgency = jsonU8(
            value.object.get("urgency") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .transient = jsonBool(
            value.object.get("transient") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .active = jsonBool(
            value.object.get("active") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
        .closed_reason = jsonU32(
            value.object.get("closed_reason") orelse return error.InvalidHistoryRow,
        ) orelse return error.InvalidHistoryRow,
    };
}

fn duplicateRow(allocator: std.mem.Allocator, input: RowInput) !Row {
    var row = Row{
        .id = input.id,
        .created_ns = input.created_ns,
        .updated_ns = input.updated_ns,
        .app_name = &.{},
        .app_icon = &.{},
        .summary = &.{},
        .body = &.{},
        .urgency = input.urgency,
        .transient = input.transient,
        .active = input.active,
        .closed_reason = input.closed_reason,
    };
    errdefer freeRow(allocator, row);

    row.app_name = try duplicateBounded(allocator, input.app_name, max_app_name_bytes);
    row.app_icon = try duplicateBounded(allocator, input.app_icon, max_app_icon_bytes);
    row.summary = try duplicateBounded(allocator, input.summary, max_summary_bytes);
    row.body = try duplicateBounded(allocator, input.body, max_body_bytes);

    return row;
}

fn duplicateBounded(allocator: std.mem.Allocator, text: []const u8, max_bytes: u32) ![]u8 {
    if (text.len > @as(usize, max_bytes)) return error.HistoryFieldTooLong;
    return allocator.dupe(u8, text);
}

fn freeRow(allocator: std.mem.Allocator, row: Row) void {
    allocator.free(row.app_name);
    allocator.free(row.app_icon);
    allocator.free(row.summary);
    allocator.free(row.body);
}

fn findIndex(rows: []const Row, id: u32) ?u32 {
    for (rows, 0..) |row, idx| {
        if (row.id == id) return @intCast(idx);
    }
    return null;
}

fn rowNewer(a: Row, b: Row) bool {
    if (a.updated_ns != b.updated_ns) return a.updated_ns > b.updated_ns;
    return a.id > b.id;
}

const Writer = struct {
    buf: []u8,
    len: u32 = 0,

    fn slice(self: *const Writer) []const u8 {
        return self.buf[0..self.len];
    }

    fn append(self: *Writer, text: []const u8) !void {
        if (text.len > self.buf.len - @as(@TypeOf(self.buf.len), @intCast(self.len))) return error.HistoryJsonTooLarge;
        const end = self.len + @as(u32, @intCast(text.len));
        @memcpy(self.buf[self.len..end], text);
        self.len += @intCast(text.len);
    }

    fn appendByte(self: *Writer, byte: u8) !void {
        if (self.len >= self.buf.len) return error.HistoryJsonTooLarge;
        self.buf[self.len] = byte;
        self.len += 1;
    }

    fn writeU64(self: *Writer, value: u64) !void {
        var tmp: [128]u8 = undefined;
        const text = try std.fmt.bufPrint(&tmp, "{d}", .{value});
        try self.append(text);
    }

    fn writeU32(self: *Writer, value: u32) !void {
        try self.writeU64(value);
    }

    fn writeU8(self: *Writer, value: u8) !void {
        try self.writeU64(value);
    }

    fn string(self: *Writer, text: []const u8) !void {
        try self.append("\"");
        for (text) |byte| {
            switch (byte) {
                '"' => try self.append("\\\""),
                '\\' => try self.append("\\\\"),
                '\n' => try self.append("\\n"),
                '\r' => try self.append("\\r"),
                '\t' => try self.append("\\t"),
                else => if (byte < 0x20) {
                    var tmp: [6]u8 = undefined;
                    const escaped = try std.fmt.bufPrint(&tmp, "\\u{X:0>4}", .{byte});
                    try self.append(escaped);
                } else {
                    try self.appendByte(byte);
                },
            }
        }
        try self.append("\"");
    }
};

fn serialize(allocator: std.mem.Allocator, history: *const History) ![]u8 {
    const buf = try allocator.alloc(u8, max_file_bytes);
    errdefer allocator.free(buf);
    var writer = Writer{ .buf = buf };

    try writer.append("{\"version\":1,\"updated_ns\":");
    try writer.writeU64(history.updated_ns);
    try writer.append(",\"rows\":[");
    for (history.rows.items, 0..) |row, idx| {
        if (idx > 0) try writer.append(",");
        try writer.append("{\"id\":");
        try writer.writeU32(row.id);
        try writer.append(",\"created_ns\":");
        try writer.writeU64(row.created_ns);
        try writer.append(",\"updated_ns\":");
        try writer.writeU64(row.updated_ns);
        try writer.append(",\"app_name\":");
        try writer.string(row.app_name);
        try writer.append(",\"app_icon\":");
        try writer.string(row.app_icon);
        try writer.append(",\"summary\":");
        try writer.string(row.summary);
        try writer.append(",\"body\":");
        try writer.string(row.body);
        try writer.append(",\"urgency\":");
        try writer.writeU8(row.urgency);
        try writer.append(",\"transient\":");
        try writer.append(if (row.transient) "true" else "false");
        try writer.append(",\"active\":");
        try writer.append(if (row.active) "true" else "false");
        try writer.append(",\"closed_reason\":");
        try writer.writeU32(row.closed_reason);
        try writer.append("}");
    }
    try writer.append("]}\n");

    return allocator.realloc(buf, writer.len);
}

fn jsonString(value: std.json.Value) ?[]const u8 {
    return switch (value) {
        .string => |text| text,
        else => null,
    };
}

fn jsonBool(value: std.json.Value) ?bool {
    return switch (value) {
        .bool => |flag| flag,
        else => null,
    };
}

fn jsonU8(value: std.json.Value) ?u8 {
    const number = jsonU64(value) orelse return null;
    if (number > std.math.maxInt(u8)) return null;
    return @intCast(number);
}

fn jsonU32(value: std.json.Value) ?u32 {
    const number = jsonU64(value) orelse return null;
    if (number > std.math.maxInt(u32)) return null;
    return @intCast(number);
}

fn jsonU64(value: std.json.Value) ?u64 {
    return switch (value) {
        .integer => |number| if (number >= 0) @intCast(number) else null,
        else => null,
    };
}

fn readAnyPath(allocator: std.mem.Allocator, history_path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, history_path, allocator, .limited(max_file_bytes));
}

fn writeAtomicAnyPath(history_path: []const u8, data: []const u8) !void {
    try ensureParentDir(history_path);
    const io = std.Options.debug_io;
    const dir_path = std.fs.path.dirname(history_path) orelse ".";
    const file_name = std.fs.path.basename(history_path);

    var dir = if (std.fs.path.isAbsolute(dir_path))
        try std.Io.Dir.openDirAbsolute(io, dir_path, .{})
    else
        try std.Io.Dir.cwd().openDir(io, dir_path, .{});
    defer dir.close(io);

    var atomic_file = try dir.createFileAtomic(io, file_name, .{ .replace = true });
    defer atomic_file.deinit(io);
    try atomic_file.file.writeStreamingAll(io, data);
    try atomic_file.file.sync(io);
    try atomic_file.replace(io);
    try syncParentDir(dir);
}

fn syncParentDir(dir: std.Io.Dir) !void {
    const rc = std.posix.system.fsync(dir.handle);
    switch (std.posix.errno(rc)) {
        .SUCCESS => return,
        .INVAL, .BADF, .ROFS, .OPNOTSUPP => return,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn ensureParentDir(history_path: []const u8) !void {
    const parent = std.fs.path.dirname(history_path) orelse return;
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
}

fn writeTestFile(tmp: std.testing.TmpDir, name: []const u8, data: []const u8) ![]u8 {
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = name, .data = data });
    return testPath(tmp, name);
}

fn testPath(tmp: std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, name });
}

test "path treats XDG state as the parent and falls back below HOME" {
    const xdg_path = try pathFromEnvironment(std.testing.allocator, "/xdg/state", "/home/test");
    defer std.testing.allocator.free(xdg_path);
    try std.testing.expectEqualStrings("/xdg/state/wayspot/notifications-history.json", xdg_path);

    const home_path = try pathFromEnvironment(std.testing.allocator, null, "/home/test");
    defer std.testing.allocator.free(home_path);
    try std.testing.expectEqualStrings("/home/test/.local/state/wayspot/notifications-history.json", home_path);
}

test "path rejects an overlong environment value" {
    var state_home: [std.fs.max_path_bytes]u8 = undefined;
    @memset(&state_home, 'x');
    try std.testing.expectError(
        error.HistoryPathTooLong,
        pathFromEnvironment(std.testing.allocator, &state_home, "/home/test"),
    );
}

test "missing history file loads empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try testPath(tmp, "missing.json");
    defer std.testing.allocator.free(history_path);

    var history = try History.loadAtPath(std.testing.allocator, history_path, 100);
    defer history.deinit();
    try std.testing.expectEqual(@as(u32, 0), history.len());
}

test "directory read error propagates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try testPath(tmp, ".");
    defer std.testing.allocator.free(history_path);

    try std.testing.expectError(error.IsDir, History.loadAtPath(std.testing.allocator, history_path, 100));
}

test "permission read error propagates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try writeTestFile(tmp, "blocked.json", "{}");
    defer std.testing.allocator.free(history_path);

    var file = try tmp.dir.openFile(std.testing.io, "blocked.json", .{});
    defer {
        file.setPermissions(std.testing.io, .fromMode(0o600)) catch {};
        file.close(std.testing.io);
    }
    try file.setPermissions(std.testing.io, .fromMode(0));
    try std.testing.expectError(error.AccessDenied, History.loadAtPath(std.testing.allocator, history_path, 100));
}

test "read allocation error propagates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try writeTestFile(tmp, "history.json", "{}");
    defer std.testing.allocator.free(history_path);

    var failing_allocator_state = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 0,
    });
    try std.testing.expectError(
        error.OutOfMemory,
        History.loadAtPath(failing_allocator_state.allocator(), history_path, 100),
    );
}

test "read byte bound propagates StreamTooLong" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try testPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    const oversized_len: usize = @as(usize, max_file_bytes) + 1;
    const oversized = try std.testing.allocator.alloc(u8, oversized_len);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "history.json", .data = oversized });

    try std.testing.expectError(error.StreamTooLong, History.loadAtPath(std.testing.allocator, history_path, 100));
}

test "invalid JSON propagates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try writeTestFile(tmp, "history.json", "{");
    defer std.testing.allocator.free(history_path);

    try std.testing.expectError(error.InvalidHistoryJson, History.loadAtPath(std.testing.allocator, history_path, 100));
}

test "unsupported version propagates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try writeTestFile(tmp, "history.json", "{\"version\":2,\"updated_ns\":1,\"rows\":[]}");
    defer std.testing.allocator.free(history_path);

    try std.testing.expectError(
        error.UnsupportedHistoryVersion,
        History.loadAtPath(std.testing.allocator, history_path, 100),
    );
}

test "wrong or missing rows propagate invalid JSON" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try writeTestFile(tmp, "history.json", "{\"version\":1,\"updated_ns\":1,\"rows\":{}}");
    defer std.testing.allocator.free(history_path);

    try std.testing.expectError(error.InvalidHistoryJson, History.loadAtPath(std.testing.allocator, history_path, 100));

    const missing_path = try writeTestFile(tmp, "missing-rows.json", "{\"version\":1,\"updated_ns\":1}");
    defer std.testing.allocator.free(missing_path);

    try std.testing.expectError(error.InvalidHistoryJson, History.loadAtPath(std.testing.allocator, missing_path, 100));
}

test "malformed row rejects the complete history" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const json =
        \\{"version":1,"updated_ns":10,"rows":[
        \\{"id":"bad"},
        \\{"id":7,"created_ns":1,"updated_ns":10,
        \\ "app_name":"app","app_icon":"","summary":"sum",
        \\ "body":"body","urgency":1,"transient":false,
        \\ "active":true,"closed_reason":0}
        \\]}
    ;
    const history_path = try writeTestFile(tmp, "history.json", json);
    defer std.testing.allocator.free(history_path);

    try std.testing.expectError(error.InvalidHistoryRow, History.loadAtPath(std.testing.allocator, history_path, 10));
}

test "old rows are pruned by updated timestamp" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.upsert(.{ .id = 1, .created_ns = 1, .updated_ns = 10 });
    try history.upsert(.{ .id = 2, .created_ns = 2, .updated_ns = retention_ns + 20 });

    history.pruneOld(retention_ns + 20);
    try std.testing.expectEqual(@as(u32, 1), history.len());
    try std.testing.expectEqual(@as(u32, 2), history.rows.items[0].id);
}

test "count cap keeps newest rows" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    var id: u32 = 0;
    while (id < max_rows + 3) : (id += 1) {
        try history.upsert(.{ .id = id + 1, .created_ns = id + 1, .updated_ns = id + 1 });
    }

    try std.testing.expectEqual(max_rows, history.len());
    try std.testing.expect(findIndex(history.rows.items, 1) == null);
    try std.testing.expect(findIndex(history.rows.items, 2) == null);
    try std.testing.expect(findIndex(history.rows.items, 3) == null);
    try std.testing.expect(findIndex(history.rows.items, max_rows + 3) != null);
}

test "row text fields accept their exact byte bounds" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    const app_name_len: usize = @as(usize, max_app_name_bytes);
    const app_icon_len: usize = @as(usize, max_app_icon_bytes);
    const summary_len: usize = @as(usize, max_summary_bytes);
    const body_len: usize = @as(usize, max_body_bytes);
    var app_name: [app_name_len]u8 = undefined;
    var app_icon: [app_icon_len]u8 = undefined;
    var summary: [summary_len]u8 = undefined;
    var body: [body_len]u8 = undefined;
    @memset(&app_name, 'n');
    @memset(&app_icon, 'i');
    @memset(&summary, 's');
    @memset(&body, 'b');
    try history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 1,
        .app_name = &app_name,
        .app_icon = &app_icon,
        .summary = &summary,
        .body = &body,
    });

    try std.testing.expectEqual(app_name_len, history.rows.items[0].app_name.len);
    try std.testing.expectEqual(app_icon_len, history.rows.items[0].app_icon.len);
    try std.testing.expectEqual(summary_len, history.rows.items[0].summary.len);
    try std.testing.expectEqual(body_len, history.rows.items[0].body.len);
}

fn expectStableRow(history: *const History) !void {
    try std.testing.expectEqual(@as(u32, 1), history.len());
    try std.testing.expectEqual(@as(u64, 1), history.rows.items[0].updated_ns);
    try std.testing.expectEqualStrings("stable-app", history.rows.items[0].app_name);
    try std.testing.expectEqualStrings("stable-icon", history.rows.items[0].app_icon);
    try std.testing.expectEqualStrings("stable-summary", history.rows.items[0].summary);
    try std.testing.expectEqualStrings("stable-body", history.rows.items[0].body);
}

test "row text fields reject one byte over without changing the row" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 1,
        .app_name = "stable-app",
        .app_icon = "stable-icon",
        .summary = "stable-summary",
        .body = "stable-body",
    });

    const app_name_len: usize = @as(usize, max_app_name_bytes) + 1;
    const app_icon_len: usize = @as(usize, max_app_icon_bytes) + 1;
    const summary_len: usize = @as(usize, max_summary_bytes) + 1;
    const body_len: usize = @as(usize, max_body_bytes) + 1;
    var app_name: [app_name_len]u8 = undefined;
    var app_icon: [app_icon_len]u8 = undefined;
    var summary: [summary_len]u8 = undefined;
    var body: [body_len]u8 = undefined;
    @memset(&app_name, 'n');
    @memset(&app_icon, 'i');
    @memset(&summary, 's');
    @memset(&body, 'b');

    try std.testing.expectError(error.HistoryFieldTooLong, history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = &app_name,
    }));
    try expectStableRow(&history);

    try std.testing.expectError(error.HistoryFieldTooLong, history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = "replacement",
        .app_icon = &app_icon,
    }));
    try expectStableRow(&history);

    try std.testing.expectError(error.HistoryFieldTooLong, history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = "replacement",
        .app_icon = "replacement",
        .summary = &summary,
    }));
    try expectStableRow(&history);

    try std.testing.expectError(error.HistoryFieldTooLong, history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = "replacement",
        .app_icon = "replacement",
        .summary = "replacement",
        .body = &body,
    }));
    try expectStableRow(&history);
}

test "parse returns HistoryFieldTooLong and frees prior rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try testPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    const app_name_len: usize = @as(usize, max_app_name_bytes) + 1;
    var app_name: [app_name_len]u8 = undefined;
    @memset(&app_name, 'n');
    const prefix = "{\"version\":1,\"updated_ns\":10,\"rows\":[" ++
        "{\"id\":1,\"created_ns\":1,\"updated_ns\":1," ++
        "\"app_name\":\"kept\",\"app_icon\":\"\",\"summary\":\"\"," ++
        "\"body\":\"\",\"urgency\":0,\"transient\":false," ++
        "\"active\":false,\"closed_reason\":0}," ++
        "{\"id\":2,\"created_ns\":2,\"updated_ns\":2," ++
        "\"app_name\":\"";
    const suffix = "\",\"app_icon\":\"\",\"summary\":\"\",\"body\":\"\"," ++
        "\"urgency\":0,\"transient\":false,\"active\":false," ++
        "\"closed_reason\":0}]}";
    const json = try std.fmt.allocPrint(std.testing.allocator, "{s}{s}{s}", .{ prefix, &app_name, suffix });
    defer std.testing.allocator.free(json);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "history.json", .data = json });

    try std.testing.expectError(
        error.HistoryFieldTooLong,
        History.loadAtPath(std.testing.allocator, history_path, 10),
    );
}

test "serialize rejects a history beyond the file byte bound" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    const body_len: usize = @as(usize, max_body_bytes);
    var body: [body_len]u8 = undefined;
    @memset(&body, 'b');
    var id: u32 = 1;
    while (id <= max_rows) : (id += 1) {
        try history.upsert(.{ .id = id, .created_ns = id, .updated_ns = id, .body = &body });
    }

    try std.testing.expectError(error.HistoryJsonTooLarge, serialize(std.testing.allocator, &history));
}

test "upsert replaces same id" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    try history.upsert(.{ .id = 5, .created_ns = 1, .updated_ns = 1, .summary = "old" });
    try history.upsert(.{ .id = 5, .created_ns = 1, .updated_ns = 2, .summary = "new" });

    try std.testing.expectEqual(@as(u32, 1), history.len());
    try std.testing.expectEqualStrings("new", history.rows.items[0].summary);
    try std.testing.expectEqual(@as(u64, 2), history.rows.items[0].updated_ns);
}

test "row duplication frees partial fields after allocation failure" {
    var failing_allocator_state = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 2,
    });
    const failing_allocator = failing_allocator_state.allocator();

    try std.testing.expectError(error.OutOfMemory, duplicateRow(failing_allocator, .{
        .id = 7,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = "app",
        .app_icon = "icon",
        .summary = "summary",
        .body = "body",
    }));
    try std.testing.expectEqual(failing_allocator_state.allocated_bytes, failing_allocator_state.freed_bytes);
}

test "upsert does not allocate row when list growth fails" {
    var failing_allocator_state = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 0,
    });
    const failing_allocator = failing_allocator_state.allocator();
    var history = History.init(failing_allocator);
    defer history.deinit();

    try std.testing.expectError(error.OutOfMemory, history.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 1,
        .app_name = "app",
        .app_icon = "icon",
        .summary = "summary",
        .body = "body",
    }));
    try std.testing.expectEqual(@as(u32, 0), history.len());
    try std.testing.expectEqual(failing_allocator_state.allocated_bytes, failing_allocator_state.freed_bytes);
}

test "save writes and replaces one JSON object atomically" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try testPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.upsert(.{
        .id = 9,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = "app",
        .app_icon = "icon",
        .summary = "hello",
        .body = "line\nbody",
        .urgency = 2,
        .transient = true,
        .active = false,
        .closed_reason = 3,
    });
    try history.saveAtPath(history_path);

    const raw = try std.Io.Dir.cwd().readFileAlloc(
        std.Options.debug_io,
        history_path,
        std.testing.allocator,
        .limited(max_file_bytes),
    );
    defer std.testing.allocator.free(raw);
    try std.testing.expect(std.mem.startsWith(u8, raw, "{\"version\":1,"));
    try std.testing.expect(std.mem.indexOf(u8, raw, "\"rows\":[{") != null);

    try history.upsert(.{
        .id = 9,
        .created_ns = 1,
        .updated_ns = 3,
        .app_name = "app",
        .app_icon = "icon",
        .summary = "replacement",
        .body = "line\nbody",
    });
    try history.saveAtPath(history_path);

    var loaded = try History.loadAtPath(std.testing.allocator, history_path, 2);
    defer loaded.deinit();
    try std.testing.expectEqual(@as(u32, 1), loaded.len());
    try std.testing.expectEqualStrings("replacement", loaded.rows.items[0].summary);
}

test "save creates nested absolute parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_root = try testPath(tmp, ".");
    defer std.testing.allocator.free(tmp_root);
    const tmp_root_abs = try std.Io.Dir.cwd().realPathFileAlloc(std.testing.io, tmp_root, std.testing.allocator);
    defer std.testing.allocator.free(tmp_root_abs);
    const history_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/one/two/history.json", .{tmp_root_abs});
    defer std.testing.allocator.free(history_path);

    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.upsert(.{ .id = 11, .created_ns = 1, .updated_ns = 2, .summary = "created" });
    try history.saveAtPath(history_path);

    var loaded = try History.loadAtPath(std.testing.allocator, history_path, 2);
    defer loaded.deinit();
    try std.testing.expectEqual(@as(u32, 1), loaded.len());
    try std.testing.expectEqual(@as(u32, 11), loaded.rows.items[0].id);
}
