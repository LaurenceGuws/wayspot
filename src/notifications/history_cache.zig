//! Notification history cache owns bounded persistent JSON rows.

const std = @import("std");

pub const version: u32 = 1;
pub const max_file_bytes: u32 = 2 * 1024 * 1024;
pub const max_rows: u32 = 512;
pub const max_app_name_bytes: u32 = 256;
pub const max_app_icon_bytes: u32 = 256;
pub const max_summary_bytes: u32 = 512;
pub const max_body_bytes: u32 = 4096;
pub const retention_ns: u64 = 7 * 24 * 60 * 60 * 1_000_000_000;

const cache_relative_path = ".local/state/wayspot/notifications-history.json";

comptime {
    std.debug.assert(max_file_bytes > 0);
    std.debug.assert(max_rows > 0);
    std.debug.assert(max_app_name_bytes > 0);
    std.debug.assert(max_app_icon_bytes > 0);
    std.debug.assert(max_summary_bytes > 0);
    std.debug.assert(max_body_bytes > 0);
    std.debug.assert(retention_ns > 0);
}

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

pub const Cache = struct {
    allocator: std.mem.Allocator,
    rows: std.ArrayListUnmanaged(Row) = .empty,
    updated_ns: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) Cache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Cache) void {
        for (self.rows.items) |row| freeRow(self.allocator, row);
        self.rows.deinit(self.allocator);
    }

    pub fn len(self: *const Cache) u32 {
        return @intCast(self.rows.items.len);
    }

    pub fn upsert(self: *Cache, input: RowInput) !void {
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

    pub fn pruneOld(self: *Cache, now_ns: u64) void {
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

    pub fn saveAtPath(self: *const Cache, path: []const u8) !void {
        const data = try serialize(self.allocator, self);
        defer self.allocator.free(data);
        try writeAtomicAnyPath(path, data);
    }

    fn keepNewestRows(self: *Cache) void {
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
};

pub fn load(allocator: std.mem.Allocator, now_ns: u64) !Cache {
    const path = try cachePath(allocator);
    defer allocator.free(path);
    return loadAtPath(allocator, path, now_ns);
}

pub fn loadAtPath(allocator: std.mem.Allocator, path: []const u8, now_ns: u64) !Cache {
    var cache = Cache.init(allocator);
    const raw = readAnyPath(allocator, path) catch return cache;
    defer allocator.free(raw);

    parseInto(&cache, raw) catch {
        cache.deinit();
        return Cache.init(allocator);
    };
    cache.pruneOld(now_ns);
    cache.keepNewestRows();
    return cache;
}

pub fn cachePath(allocator: std.mem.Allocator) ![]u8 {
    const home = if (std.c.getenv("HOME")) |home_z| std.mem.span(home_z) else ".";
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, cache_relative_path });
}

fn parseInto(cache: *Cache, raw: []const u8) !void {
    const parsed = try std.json.parseFromSlice(std.json.Value, cache.allocator, raw, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidHistoryJson;

    const version_value = parsed.value.object.get("version") orelse return error.InvalidHistoryJson;
    if ((jsonU32(version_value) orelse return error.InvalidHistoryJson) != version) return error.UnsupportedHistoryVersion;

    const updated_value = parsed.value.object.get("updated_ns") orelse return error.InvalidHistoryJson;
    cache.updated_ns = jsonU64(updated_value) orelse return error.InvalidHistoryJson;

    const rows_value = parsed.value.object.get("rows") orelse return error.InvalidHistoryJson;
    if (rows_value != .array) return error.InvalidHistoryJson;

    for (rows_value.array.items) |item| {
        const input = parseRow(item) catch continue;
        try cache.upsert(input);
    }
}

fn parseRow(value: std.json.Value) !RowInput {
    if (value != .object) return error.InvalidHistoryRow;
    return .{
        .id = jsonU32(value.object.get("id") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .created_ns = jsonU64(value.object.get("created_ns") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .updated_ns = jsonU64(value.object.get("updated_ns") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .app_name = jsonString(value.object.get("app_name") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .app_icon = jsonString(value.object.get("app_icon") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .summary = jsonString(value.object.get("summary") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .body = jsonString(value.object.get("body") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .urgency = jsonU8(value.object.get("urgency") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .transient = jsonBool(value.object.get("transient") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .active = jsonBool(value.object.get("active") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
        .closed_reason = jsonU32(value.object.get("closed_reason") orelse return error.InvalidHistoryRow) orelse return error.InvalidHistoryRow,
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
    const out_len = @min(text.len, max_bytes);
    const out = try allocator.dupe(u8, text[0..out_len]);
    if (text.len > out_len and out_len > 0) out[out_len - 1] = '~';
    return out;
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

fn serialize(allocator: std.mem.Allocator, cache: *const Cache) ![]u8 {
    const buf = try allocator.alloc(u8, max_file_bytes);
    errdefer allocator.free(buf);
    var writer = Writer{ .buf = buf };

    try writer.append("{\"version\":1,\"updated_ns\":");
    try writer.writeU64(cache.updated_ns);
    try writer.append(",\"rows\":[");
    for (cache.rows.items, 0..) |row, idx| {
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

fn readAnyPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, allocator, .limited(max_file_bytes));
}

fn writeAtomicAnyPath(path: []const u8, data: []const u8) !void {
    try ensureParentDir(path);
    const io = std.Options.debug_io;
    const dir_path = std.fs.path.dirname(path) orelse ".";
    const file_name = std.fs.path.basename(path);

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
}

fn ensureParentDir(path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
}

fn writeTestFile(tmp: std.testing.TmpDir, name: []const u8, data: []const u8) ![]u8 {
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = name, .data = data });
    return testPath(tmp, name);
}

fn testPath(tmp: std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, name });
}

test "missing history cache file loads empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try testPath(tmp, "missing.json");
    defer std.testing.allocator.free(path);

    var cache = try loadAtPath(std.testing.allocator, path, 100);
    defer cache.deinit();
    try std.testing.expectEqual(@as(u32, 0), cache.len());
}

test "invalid JSON loads empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try writeTestFile(tmp, "history.json", "{");
    defer std.testing.allocator.free(path);

    var cache = try loadAtPath(std.testing.allocator, path, 100);
    defer cache.deinit();
    try std.testing.expectEqual(@as(u32, 0), cache.len());
}

test "unsupported version loads empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try writeTestFile(tmp, "history.json", "{\"version\":2,\"updated_ns\":1,\"rows\":[]}");
    defer std.testing.allocator.free(path);

    var cache = try loadAtPath(std.testing.allocator, path, 100);
    defer cache.deinit();
    try std.testing.expectEqual(@as(u32, 0), cache.len());
}

test "wrong or missing rows loads empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try writeTestFile(tmp, "history.json", "{\"version\":1,\"updated_ns\":1,\"rows\":{}}");
    defer std.testing.allocator.free(path);

    var cache = try loadAtPath(std.testing.allocator, path, 100);
    defer cache.deinit();
    try std.testing.expectEqual(@as(u32, 0), cache.len());

    const missing_path = try writeTestFile(tmp, "missing-rows.json", "{\"version\":1,\"updated_ns\":1}");
    defer std.testing.allocator.free(missing_path);

    var missing_cache = try loadAtPath(std.testing.allocator, missing_path, 100);
    defer missing_cache.deinit();
    try std.testing.expectEqual(@as(u32, 0), missing_cache.len());
}

test "malformed row is skipped while valid row survives" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const json =
        \\{"version":1,"updated_ns":10,"rows":[
        \\{"id":"bad"},
        \\{"id":7,"created_ns":1,"updated_ns":10,"app_name":"app","app_icon":"","summary":"sum","body":"body","urgency":1,"transient":false,"active":true,"closed_reason":0}
        \\]}
    ;
    const path = try writeTestFile(tmp, "history.json", json);
    defer std.testing.allocator.free(path);

    var cache = try loadAtPath(std.testing.allocator, path, 10);
    defer cache.deinit();
    try std.testing.expectEqual(@as(u32, 1), cache.len());
    try std.testing.expectEqual(@as(u32, 7), cache.rows.items[0].id);
}

test "old rows are pruned by updated timestamp" {
    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.upsert(.{ .id = 1, .created_ns = 1, .updated_ns = 10 });
    try cache.upsert(.{ .id = 2, .created_ns = 2, .updated_ns = retention_ns + 20 });

    cache.pruneOld(retention_ns + 20);
    try std.testing.expectEqual(@as(u32, 1), cache.len());
    try std.testing.expectEqual(@as(u32, 2), cache.rows.items[0].id);
}

test "count cap keeps newest rows" {
    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();

    var id: u32 = 0;
    while (id < max_rows + 3) : (id += 1) {
        try cache.upsert(.{ .id = id + 1, .created_ns = id + 1, .updated_ns = id + 1 });
    }

    try std.testing.expectEqual(max_rows, cache.len());
    try std.testing.expect(findIndex(cache.rows.items, 1) == null);
    try std.testing.expect(findIndex(cache.rows.items, 2) == null);
    try std.testing.expect(findIndex(cache.rows.items, 3) == null);
    try std.testing.expect(findIndex(cache.rows.items, max_rows + 3) != null);
}

test "upsert replaces same id" {
    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();

    try cache.upsert(.{ .id = 5, .created_ns = 1, .updated_ns = 1, .summary = "old" });
    try cache.upsert(.{ .id = 5, .created_ns = 1, .updated_ns = 2, .summary = "new" });

    try std.testing.expectEqual(@as(u32, 1), cache.len());
    try std.testing.expectEqualStrings("new", cache.rows.items[0].summary);
    try std.testing.expectEqual(@as(u64, 2), cache.rows.items[0].updated_ns);
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
    var cache = Cache.init(failing_allocator);
    defer cache.deinit();

    try std.testing.expectError(error.OutOfMemory, cache.upsert(.{
        .id = 1,
        .created_ns = 1,
        .updated_ns = 1,
        .app_name = "app",
        .app_icon = "icon",
        .summary = "summary",
        .body = "body",
    }));
    try std.testing.expectEqual(@as(u32, 0), cache.len());
    try std.testing.expectEqual(failing_allocator_state.allocated_bytes, failing_allocator_state.freed_bytes);
}

test "save writes one JSON object with version and rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try testPath(tmp, "history.json");
    defer std.testing.allocator.free(path);

    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.upsert(.{
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
    try cache.saveAtPath(path);

    const raw = try std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, std.testing.allocator, .limited(max_file_bytes));
    defer std.testing.allocator.free(raw);
    try std.testing.expect(std.mem.startsWith(u8, raw, "{\"version\":1,"));
    try std.testing.expect(std.mem.indexOf(u8, raw, "\"rows\":[{") != null);

    var loaded = try loadAtPath(std.testing.allocator, path, 2);
    defer loaded.deinit();
    try std.testing.expectEqual(@as(u32, 1), loaded.len());
    try std.testing.expectEqualStrings("line\nbody", loaded.rows.items[0].body);
}

test "save creates nested absolute parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_root = try testPath(tmp, ".");
    defer std.testing.allocator.free(tmp_root);
    const tmp_root_abs = try std.Io.Dir.cwd().realPathFileAlloc(std.testing.io, tmp_root, std.testing.allocator);
    defer std.testing.allocator.free(tmp_root_abs);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/one/two/history.json", .{tmp_root_abs});
    defer std.testing.allocator.free(path);

    var cache = Cache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.upsert(.{ .id = 11, .created_ns = 1, .updated_ns = 2, .summary = "created" });
    try cache.saveAtPath(path);

    var loaded = try loadAtPath(std.testing.allocator, path, 2);
    defer loaded.deinit();
    try std.testing.expectEqual(@as(u32, 1), loaded.len());
    try std.testing.expectEqual(@as(u32, 11), loaded.rows.items[0].id);
}
