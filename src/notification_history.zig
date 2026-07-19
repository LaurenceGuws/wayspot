//! Retains one bounded private JSONL history and atomically replaces its file.

const std = @import("std");
const builtin = @import("builtin");
const notification = @import("notification.zig");

pub const record_capacity = 4096;
pub const file_capacity = 32 * 1024 * 1024;
pub const line_capacity = 18_432;
pub const retention_seconds: i64 = 30 * 24 * 60 * 60;

pub const Error = error{
    OutOfMemory,
    PathMissing,
    HistoryOpenFailed,
    HistoryReadFailed,
    HistoryCorrupt,
    HistoryTooLarge,
    LineTooLong,
    HistoryIdExhausted,
    HistoryWriteFailed,
    HistorySyncFailed,
    HistoryReplaceFailed,
    HistoryCleanupFailed,
    ClockInvalid,
};

/// Record owns exactly the retained text and its complete encoded line length.
pub const Record = struct {
    received_unix_seconds: i64,
    history_id: u64,
    storage: []u8,
    app_name: []u8,
    summary: []u8,
    body: []u8,
    line_bytes: usize,

    fn init(
        allocator: std.mem.Allocator,
        received_unix_seconds: i64,
        history_id: u64,
        app_name: []const u8,
        summary: []const u8,
        body: []const u8,
    ) Error!Record {
        if (received_unix_seconds < 0 or history_id == 0) return error.HistoryCorrupt;
        if (app_name.len > notification.app_name_capacity or
            summary.len > notification.summary_capacity or
            body.len > notification.body_capacity or
            !std.unicode.utf8ValidateSlice(app_name) or
            !std.unicode.utf8ValidateSlice(summary) or
            !std.unicode.utf8ValidateSlice(body))
        {
            return error.HistoryCorrupt;
        }
        const storage = allocator.alloc(u8, app_name.len + summary.len + body.len) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.free(storage);
        var offset: usize = 0;
        const record = Record{
            .received_unix_seconds = received_unix_seconds,
            .history_id = history_id,
            .storage = storage,
            .app_name = copy(storage, &offset, app_name),
            .summary = copy(storage, &offset, summary),
            .body = copy(storage, &offset, body),
            .line_bytes = 0,
        };
        var result = record;
        result.line_bytes = try lineLength(result);
        return result;
    }

    fn deinit(record: *Record, allocator: std.mem.Allocator) void {
        allocator.free(record.storage);
        record.* = undefined;
    }
};

const Active = struct {
    notification_id: u32,
    history_id: u64,
};

/// History owns oldest-first retained records and runtime-only active-id associations.
pub const History = struct {
    records: [record_capacity]?Record = @splat(null),
    count: usize = 0,
    file_bytes: usize = 0,
    next_history_id: u64 = 1,
    active: [notification.capacity]?Active = @splat(null),
    active_count: usize = 0,

    pub fn deinit(history: *History, allocator: std.mem.Allocator) void {
        history.assertValid();
        for (history.records[0..history.count]) |*slot| slot.*.?.deinit(allocator);
        history.* = .{};
    }

    /// Adds or replaces one accepted notification, then prunes oldest records.
    pub fn accepted(
        history: *History,
        allocator: std.mem.Allocator,
        now: i64,
        source: *const notification.Notification,
        replaces: bool,
    ) Error!void {
        history.assertValid();
        const active_index = if (replaces) history.findActive(source.id) else null;
        if (active_index == null and history.active_count == history.active.len) {
            return error.HistoryCorrupt;
        }
        const history_id = if (active_index) |index|
            history.active[index].?.history_id
        else blk: {
            if (history.next_history_id == std.math.maxInt(u64)) {
                return error.HistoryIdExhausted;
            }
            break :blk history.next_history_id;
        };
        var record = try Record.init(
            allocator,
            now,
            history_id,
            source.app_name,
            source.summary,
            source.body,
        );
        errdefer record.deinit(allocator);

        if (history.findRecord(history_id)) |index| history.removeRecord(allocator, index);
        history.retain(allocator, record);
        if (active_index == null) {
            history.active[history.active_count] = .{
                .notification_id = source.id,
                .history_id = history_id,
            };
            history.active_count += 1;
            history.next_history_id += 1;
        }
        history.prune(allocator, now);
        history.assertValid();
    }

    /// Forgets the runtime-only association for one closed Freedesktop id.
    pub fn closed(history: *History, notification_id: u32) void {
        const index = history.findActive(notification_id) orelse return;
        var cursor = index;
        while (cursor + 1 < history.active_count) : (cursor += 1) {
            history.active[cursor] = history.active[cursor + 1];
        }
        history.active_count -= 1;
        history.active[history.active_count] = null;
        history.assertValid();
    }

    fn append(history: *History, record: Record) void {
        std.debug.assert(history.count < history.records.len);
        history.records[history.count] = record;
        history.count += 1;
        history.file_bytes += record.line_bytes;
    }

    fn retain(history: *History, allocator: std.mem.Allocator, record: Record) void {
        if (history.count == history.records.len) {
            if (record.received_unix_seconds <= history.records[0].?.received_unix_seconds) {
                var discarded = record;
                discarded.deinit(allocator);
                return;
            }
            history.removeRecord(allocator, 0);
        }
        var index = history.count;
        while (index > 0 and
            history.records[index - 1].?.received_unix_seconds > record.received_unix_seconds)
        {
            history.records[index] = history.records[index - 1];
            index -= 1;
        }
        history.records[index] = record;
        history.count += 1;
        history.file_bytes += record.line_bytes;
    }

    fn prune(history: *History, allocator: std.mem.Allocator, now: i64) void {
        const cutoff = if (now >= retention_seconds) now - retention_seconds else 0;
        while (history.count > 0 and history.records[0].?.received_unix_seconds < cutoff) {
            history.removeRecord(allocator, 0);
        }
        while (history.count > record_capacity or history.file_bytes > file_capacity) {
            history.removeRecord(allocator, 0);
        }
    }

    fn removeRecord(history: *History, allocator: std.mem.Allocator, index: usize) void {
        std.debug.assert(index < history.count);
        history.file_bytes -= history.records[index].?.line_bytes;
        history.records[index].?.deinit(allocator);
        var cursor = index;
        while (cursor + 1 < history.count) : (cursor += 1) {
            history.records[cursor] = history.records[cursor + 1];
        }
        history.count -= 1;
        history.records[history.count] = null;
    }

    fn findRecord(history: *const History, history_id: u64) ?usize {
        for (history.records[0..history.count], 0..) |slot, index| {
            if (slot.?.history_id == history_id) return index;
        }
        return null;
    }

    fn findActive(history: *const History, notification_id: u32) ?usize {
        for (history.active[0..history.active_count], 0..) |slot, index| {
            if (slot.?.notification_id == notification_id) return index;
        }
        return null;
    }

    fn assertValid(history: *const History) void {
        std.debug.assert(history.count <= record_capacity);
        std.debug.assert(history.active_count <= history.active.len);
        std.debug.assert(history.next_history_id != 0);
        var bytes: usize = 0;
        for (history.records, 0..) |slot, index| {
            std.debug.assert((index < history.count) == (slot != null));
            const record = slot orelse continue;
            std.debug.assert(record.history_id != 0);
            std.debug.assert(record.line_bytes <= line_capacity);
            bytes += record.line_bytes;
            for (history.records[index + 1 .. history.count]) |other| {
                std.debug.assert(record.history_id != other.?.history_id);
            }
        }
        std.debug.assert(bytes == history.file_bytes);
        std.debug.assert(history.file_bytes <= file_capacity);
        for (history.active, 0..) |slot, index| {
            std.debug.assert((index < history.active_count) == (slot != null));
        }
    }
};

const Wire = struct {
    received_unix_seconds: i64,
    history_id: u64,
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
};

const PublicRecord = struct {
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
};

/// Parses only a complete bounded JSONL file and publishes no partial history.
pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, now: i64) Error!History {
    if (bytes.len > file_capacity) return error.HistoryTooLarge;
    if (bytes.len > 0 and bytes[bytes.len - 1] != '\n') return error.HistoryCorrupt;
    var history: History = .{};
    errdefer history.deinit(allocator);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (lines.peek() == null) break;
            return error.HistoryCorrupt;
        }
        if (line.len + 1 > line_capacity) return error.LineTooLong;
        var parsed = std.json.parseFromSlice(Wire, allocator, line, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
            .max_value_len = line_capacity,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.HistoryCorrupt,
        };
        defer parsed.deinit();
        if (history.findRecord(parsed.value.history_id) != null) return error.HistoryCorrupt;
        var record = try Record.init(
            allocator,
            parsed.value.received_unix_seconds,
            parsed.value.history_id,
            parsed.value.app_name,
            parsed.value.summary,
            parsed.value.body,
        );
        errdefer record.deinit(allocator);
        history.retain(allocator, record);
    }
    history.prune(allocator, now);
    var greatest: u64 = 0;
    for (history.records[0..history.count]) |slot| greatest = @max(greatest, slot.?.history_id);
    if (greatest == std.math.maxInt(u64)) return error.HistoryIdExhausted;
    history.next_history_id = greatest + 1;
    history.assertValid();
    return history;
}

/// Reads one complete byte snapshot, then publishes only a complete parsed history.
pub fn load(source: anytype, allocator: std.mem.Allocator, now: i64) Error!History {
    const bytes = try source.read();
    defer allocator.free(bytes);
    return parse(allocator, bytes, now);
}

pub fn encode(allocator: std.mem.Allocator, history: *const History) Error![]u8 {
    history.assertValid();
    const bytes = allocator.alloc(u8, history.file_bytes) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    for (history.records[0..history.count]) |slot| writeLine(&writer, slot.?) catch {
        return error.HistoryCorrupt;
    };
    std.debug.assert(writer.buffered().len == bytes.len);
    return bytes;
}

/// Formats one complete newest-first public view before any caller writes it.
pub fn format(allocator: std.mem.Allocator, history: *const History) Error![]u8 {
    history.assertValid();
    var length: usize = 0;
    var line: [line_capacity]u8 = undefined;
    for (history.records[0..history.count]) |slot| {
        var writer: std.Io.Writer = .fixed(&line);
        writePublicLine(&writer, slot.?) catch return error.LineTooLong;
        length = std.math.add(usize, length, writer.buffered().len) catch {
            return error.HistoryTooLarge;
        };
        if (length > file_capacity) return error.HistoryTooLarge;
    }
    const bytes = allocator.alloc(u8, length) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    var index = history.count;
    while (index > 0) {
        index -= 1;
        writePublicLine(&writer, history.records[index].?) catch return error.HistoryCorrupt;
    }
    std.debug.assert(writer.buffered().len == bytes.len);
    return bytes;
}

fn lineLength(record: Record) Error!usize {
    var bytes: [line_capacity]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    writeLine(&writer, record) catch return error.LineTooLong;
    return writer.buffered().len;
}

fn writeLine(writer: *std.Io.Writer, record: Record) !void {
    try std.json.Stringify.value(Wire{
        .received_unix_seconds = record.received_unix_seconds,
        .history_id = record.history_id,
        .app_name = record.app_name,
        .summary = record.summary,
        .body = record.body,
    }, .{}, writer);
    try writer.writeByte('\n');
}

fn writePublicLine(writer: *std.Io.Writer, record: Record) !void {
    try std.json.Stringify.value(PublicRecord{
        .app_name = record.app_name,
        .summary = record.summary,
        .body = record.body,
    }, .{}, writer);
    try writer.writeByte('\n');
}

fn copy(storage: []u8, offset: *usize, bytes: []const u8) []u8 {
    const result = storage[offset.*..][0..bytes.len];
    @memcpy(result, bytes);
    offset.* += bytes.len;
    return result;
}

/// Executes one exact temporary-write, sync, replace, and parent-sync history.
pub fn persist(source: anytype, bytes: []const u8) !void {
    try source.begin();
    source.write(bytes) catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    source.syncFile() catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    source.adopt() catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    try source.syncParent();
}

/// Native owns the private state directory and at most one PID-qualified sibling file.
pub const Native = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    directory_path: []u8,
    directory: std.Io.Dir,
    temporary_name: [64]u8,
    temporary_name_length: usize,
    temporary: ?std.Io.File = null,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
    ) Error!Native {
        const owned_path = try directoryPath(allocator, state_home, home);
        errdefer allocator.free(owned_path);
        const directory = std.Io.Dir.cwd().createDirPathOpen(io, owned_path, .{
            .open_options = .{ .iterate = true },
            .permissions = .fromMode(0o700),
        }) catch return error.HistoryOpenFailed;
        errdefer directory.close(io);
        directory.setPermissions(io, .fromMode(0o700)) catch return error.HistoryOpenFailed;
        var temporary_name: [64]u8 = undefined;
        const name = std.fmt.bufPrint(
            &temporary_name,
            "notifications.{d}.tmp",
            .{std.os.linux.getpid()},
        ) catch unreachable;
        return .{
            .allocator = allocator,
            .io = io,
            .directory_path = owned_path,
            .directory = directory,
            .temporary_name = temporary_name,
            .temporary_name_length = name.len,
        };
    }

    pub fn deinit(native: *Native) void {
        std.debug.assert(native.temporary == null);
        native.directory.close(native.io);
        native.allocator.free(native.directory_path);
        native.* = undefined;
    }

    pub fn read(native: *Native) Error![]u8 {
        const file = native.directory.openFile(native.io, "notifications.jsonl", .{}) catch |err| switch (err) {
            error.FileNotFound => return native.allocator.alloc(u8, 0) catch error.OutOfMemory,
            else => return error.HistoryOpenFailed,
        };
        defer file.close(native.io);
        file.setPermissions(native.io, .fromMode(0o600)) catch return error.HistoryOpenFailed;
        const size = file.length(native.io) catch return error.HistoryReadFailed;
        if (size > file_capacity) return error.HistoryTooLarge;
        const bytes = native.allocator.alloc(u8, @intCast(size)) catch return error.OutOfMemory;
        errdefer native.allocator.free(bytes);
        const count = file.readPositionalAll(native.io, bytes, 0) catch return error.HistoryReadFailed;
        if (count != bytes.len) return error.HistoryReadFailed;
        return bytes;
    }

    pub fn begin(native: *Native) Error!void {
        std.debug.assert(native.temporary == null);
        const temporary_name = native.temporary_name[0..native.temporary_name_length];
        native.directory.deleteFile(native.io, temporary_name) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return error.HistoryCleanupFailed,
        };
        native.temporary = native.directory.createFile(native.io, temporary_name, .{
            .permissions = .fromMode(0o600),
            .exclusive = true,
        }) catch return error.HistoryOpenFailed;
    }

    pub fn write(native: *Native, bytes: []const u8) Error!void {
        const temporary = native.temporary orelse return error.HistoryWriteFailed;
        temporary.writeStreamingAll(native.io, bytes) catch return error.HistoryWriteFailed;
    }

    pub fn syncFile(native: *Native) Error!void {
        const temporary = native.temporary orelse return error.HistorySyncFailed;
        temporary.sync(native.io) catch return error.HistorySyncFailed;
    }

    pub fn adopt(native: *Native) Error!void {
        const temporary = native.temporary orelse return error.HistoryReplaceFailed;
        temporary.close(native.io);
        native.temporary = null;
        native.directory.rename(
            native.temporary_name[0..native.temporary_name_length],
            native.directory,
            "notifications.jsonl",
            native.io,
        ) catch return error.HistoryReplaceFailed;
    }

    pub fn syncParent(native: *Native) Error!void {
        const parent_file = std.Io.File{
            .handle = native.directory.handle,
            .flags = .{ .nonblocking = false },
        };
        parent_file.sync(native.io) catch return error.HistorySyncFailed;
    }

    pub fn abort(native: *Native) Error!void {
        if (native.temporary) |temporary| {
            temporary.close(native.io);
            native.temporary = null;
        }
        native.directory.deleteFile(
            native.io,
            native.temporary_name[0..native.temporary_name_length],
        ) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return error.HistoryCleanupFailed,
        };
    }
};

fn directoryPath(
    allocator: std.mem.Allocator,
    state_home: ?[]const u8,
    home: ?[]const u8,
) Error![]u8 {
    if (state_home) |path| {
        if (path.len > 0 and std.fs.path.isAbsolute(path)) {
            return std.fs.path.join(allocator, &.{ path, "wayspot" }) catch error.OutOfMemory;
        }
    }
    const path = home orelse return error.PathMissing;
    if (path.len == 0 or !std.fs.path.isAbsolute(path)) return error.PathMissing;
    return std.fs.path.join(allocator, &.{ path, ".local", "state", "wayspot" }) catch error.OutOfMemory;
}

const ReadStat = struct {
    kind: std.Io.File.Kind,
    mode: u16,
    size: u64,
};

/// Reads one complete retained byte snapshot and closes each opened handle once.
fn readRetained(source: anytype, allocator: std.mem.Allocator) Error!?[]u8 {
    if (!try source.openDirectory()) return null;
    defer source.closeDirectory();
    const directory = try source.statDirectory();
    if (directory.kind != .directory or directory.mode != 0o700) return error.HistoryOpenFailed;

    if (!try source.openFile()) return null;
    defer source.closeFile();
    const file = try source.statFile();
    if (file.kind != .file or file.mode != 0o600) return error.HistoryOpenFailed;
    if (file.size > file_capacity) return error.HistoryTooLarge;

    const bytes = allocator.alloc(u8, @intCast(file.size)) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    if (try source.read(bytes) != bytes.len) return error.HistoryReadFailed;
    return bytes;
}

/// Owns read-only handles for the one retained notification file.
const ReadNative = struct {
    io: std.Io,
    path: []const u8,
    directory: ?std.Io.Dir = null,
    file: ?std.Io.File = null,

    fn openDirectory(native: *ReadNative) Error!bool {
        std.debug.assert(native.directory == null);
        native.directory = std.Io.Dir.cwd().openDir(native.io, native.path, .{
            .follow_symlinks = true,
        }) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return error.HistoryOpenFailed,
        };
        return true;
    }

    fn statDirectory(native: *ReadNative) Error!ReadStat {
        const stat = (native.directory orelse return error.HistoryOpenFailed).stat(native.io) catch {
            return error.HistoryOpenFailed;
        };
        return statValue(stat);
    }

    fn openFile(native: *ReadNative) Error!bool {
        std.debug.assert(native.file == null);
        const directory = native.directory orelse return error.HistoryOpenFailed;
        native.file = directory.openFile(native.io, "notifications.jsonl", .{
            .follow_symlinks = true,
        }) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return error.HistoryOpenFailed,
        };
        return true;
    }

    fn statFile(native: *ReadNative) Error!ReadStat {
        const stat = (native.file orelse return error.HistoryOpenFailed).stat(native.io) catch {
            return error.HistoryReadFailed;
        };
        return statValue(stat);
    }

    fn read(native: *ReadNative, bytes: []u8) Error!usize {
        const file = native.file orelse return error.HistoryReadFailed;
        return file.readPositionalAll(native.io, bytes, 0) catch error.HistoryReadFailed;
    }

    fn closeFile(native: *ReadNative) void {
        const file = native.file orelse unreachable;
        file.close(native.io);
        native.file = null;
    }

    fn closeDirectory(native: *ReadNative) void {
        std.debug.assert(native.file == null);
        const directory = native.directory orelse unreachable;
        directory.close(native.io);
        native.directory = null;
    }
};

fn statValue(stat: std.Io.File.Stat) ReadStat {
    return .{
        .kind = stat.kind,
        .mode = @intCast(stat.permissions.toMode() & 0o777),
        .size = stat.size,
    };
}

/// Reads and prunes retained records without creating or changing filesystem state.
///
/// std.Io follows path and file symlinks here. Privacy and regular-file checks
/// apply to the opened targets, avoiding a separate path-stat race.
pub fn inspect(
    allocator: std.mem.Allocator,
    io: std.Io,
    state_home: ?[]const u8,
    home: ?[]const u8,
) Error!History {
    const path = try directoryPath(allocator, state_home, home);
    defer allocator.free(path);
    var native = ReadNative{ .io = io, .path = path };
    const bytes = try readRetained(&native, allocator) orelse return .{};
    defer allocator.free(bytes);
    std.debug.assert(native.directory == null);
    std.debug.assert(native.file == null);
    return parse(allocator, bytes, try unixSeconds(io));
}

/// Owner keeps retained memory and its canonical file synchronized in the DBus worker.
pub const Owner = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    history: History,
    native: Native,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
    ) Error!Owner {
        return initAt(allocator, io, state_home, home, try unixSeconds(io));
    }

    fn initAt(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
        now: i64,
    ) Error!Owner {
        var native = try Native.init(allocator, io, state_home, home);
        errdefer native.deinit();
        var history = try load(&native, allocator, now);
        errdefer history.deinit(allocator);
        const encoded = try encode(allocator, &history);
        defer allocator.free(encoded);
        try persist(&native, encoded);
        return .{ .allocator = allocator, .io = io, .history = history, .native = native };
    }

    pub fn deinit(owner: *Owner) void {
        owner.history.deinit(owner.allocator);
        owner.native.deinit();
        owner.* = undefined;
    }

    /// Persists accepted text after its DBus reply; failure stops the resident process visibly.
    pub fn accepted(
        owner: *Owner,
        source: *const notification.Notification,
        replaces: bool,
    ) Error!void {
        try owner.history.accepted(owner.allocator, try unixSeconds(owner.io), source, replaces);
        const bytes = try encode(owner.allocator, &owner.history);
        defer owner.allocator.free(bytes);
        try persist(&owner.native, bytes);
    }

    pub fn closed(owner: *Owner, notification_id: u32) void {
        owner.history.closed(notification_id);
    }
};

fn unixSeconds(io: std.Io) Error!i64 {
    const nanoseconds = std.Io.Clock.real.now(io).nanoseconds;
    if (nanoseconds < 0) return error.ClockInvalid;
    const seconds = @divFloor(nanoseconds, std.time.ns_per_s);
    if (seconds > std.math.maxInt(i64)) return error.ClockInvalid;
    return @intCast(seconds);
}

fn sampleStore(
    allocator: std.mem.Allocator,
    id: u32,
    summary: []const u8,
) !notification.Store {
    var store: notification.Store = .{ .last_id = id - 1 };
    errdefer store.deinit(allocator);
    const actual = try store.notify(allocator, .{
        .replaces_id = 0,
        .app_name = "app",
        .app_icon = "",
        .summary = summary,
        .body = "body",
        .expire_timeout = -1,
    });
    std.debug.assert(actual == id);
    return store;
}

test "new records replace active identity and close ends replacement identity" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleStore(std.testing.allocator, 7, "first");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 100, first.get(7).?, false);
    try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
    var replacement = try sampleStore(std.testing.allocator, 7, "replacement");
    defer replacement.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 200, replacement.get(7).?, true);
    try std.testing.expectEqual(@as(usize, 1), history.count);
    try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
    try std.testing.expectEqualStrings("replacement", history.records[0].?.summary);
    history.closed(7);
    try history.accepted(std.testing.allocator, 300, replacement.get(7).?, true);
    try std.testing.expectEqual(@as(u64, 2), history.records[1].?.history_id);
}

test "age is strict and JSONL round trips escaped private text" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleStore(std.testing.allocator, 1, "quote \" slash \\\\");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 10, first.get(1).?, false);
    const bytes = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    var retained = try parse(std.testing.allocator, bytes, 10 + retention_seconds);
    defer retained.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), retained.count);
    var pruned = try parse(std.testing.allocator, bytes, 11 + retention_seconds);
    defer pruned.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), pruned.count);
}

test "public JSONL is complete newest first and excludes retained identity" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleStore(std.testing.allocator, 1, "first\nline");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 10, first.get(1).?, false);
    var second = try sampleStore(std.testing.allocator, 2, "quote \" and $HOME");
    defer second.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 20, second.get(2).?, false);
    const bytes = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings(
        "{\"app_name\":\"app\",\"summary\":\"quote \\\" and $HOME\",\"body\":\"body\"}\n" ++
            "{\"app_name\":\"app\",\"summary\":\"first\\nline\",\"body\":\"body\"}\n",
        bytes,
    );
    try std.testing.expect(std.mem.indexOf(u8, bytes, "history_id") == null);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "received_unix_seconds") == null);
}

test "empty public history is empty output" {
    const history: History = .{};
    const bytes = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "corrupt incomplete oversized and duplicate input publishes no history" {
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, "{}", 0));
    var oversized: [line_capacity + 1]u8 = @splat('x');
    oversized[oversized.len - 1] = '\n';
    try std.testing.expectError(error.LineTooLong, parse(std.testing.allocator, &oversized, 0));
    const line =
        \\{"received_unix_seconds":1,"history_id":1,"app_name":"a","summary":"s","body":"b"}
    ;
    const duplicate = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}\n", .{ line, line });
    defer std.testing.allocator.free(duplicate);
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, duplicate, 0));
}

test "greatest retained id allocates next and max never wraps" {
    const last_line =
        \\{"received_unix_seconds":1,"history_id":18446744073709551614,"app_name":"a","summary":"s","body":"b"}
        \\
    ;
    var last = try parse(std.testing.allocator, last_line, 1);
    defer last.deinit(std.testing.allocator);
    try std.testing.expectEqual(std.math.maxInt(u64), last.next_history_id);
    const max_line =
        \\{"received_unix_seconds":1,"history_id":18446744073709551615,"app_name":"a","summary":"s","body":"b"}
        \\
    ;
    try std.testing.expectError(error.HistoryIdExhausted, parse(std.testing.allocator, max_line, 1));
}

test "max minus one is last assignable id and reserved max fails atomically" {
    var history: History = .{ .next_history_id = std.math.maxInt(u64) - 1 };
    defer history.deinit(std.testing.allocator);
    var last = try sampleStore(std.testing.allocator, 1, "last");
    defer last.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 1, last.get(1).?, false);
    try std.testing.expectEqual(std.math.maxInt(u64) - 1, history.records[0].?.history_id);
    try std.testing.expectEqual(std.math.maxInt(u64), history.next_history_id);

    const count = history.count;
    const active_count = history.active_count;
    const file_bytes = history.file_bytes;
    var rejected = try sampleStore(std.testing.allocator, 2, "rejected");
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expectError(
        error.HistoryIdExhausted,
        history.accepted(std.testing.allocator, 2, rejected.get(2).?, false),
    );
    try std.testing.expectEqual(count, history.count);
    try std.testing.expectEqual(active_count, history.active_count);
    try std.testing.expectEqual(file_bytes, history.file_bytes);
    try std.testing.expectEqual(std.math.maxInt(u64), history.next_history_id);
    for (history.records[0..history.count]) |slot| {
        try std.testing.expect(slot.?.history_id != std.math.maxInt(u64));
    }
    const encoded = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(
        u8,
        encoded,
        "\"history_id\":18446744073709551615",
    ) == null);
}

test "state path uses absolute XDG state then absolute HOME fallback" {
    const xdg = try directoryPath(std.testing.allocator, "/state", "/home/user");
    defer std.testing.allocator.free(xdg);
    try std.testing.expectEqualStrings("/state/wayspot", xdg);
    const fallback = try directoryPath(std.testing.allocator, "", "/home/user");
    defer std.testing.allocator.free(fallback);
    try std.testing.expectEqualStrings("/home/user/.local/state/wayspot", fallback);
    const relative = try directoryPath(std.testing.allocator, "relative", "/home/user");
    defer std.testing.allocator.free(relative);
    try std.testing.expectEqualStrings("/home/user/.local/state/wayspot", relative);
    try std.testing.expectError(error.PathMissing, directoryPath(std.testing.allocator, null, null));
}

test "count and byte bounds remove oldest complete records" {
    var count_history: History = .{};
    defer count_history.deinit(std.testing.allocator);
    for (1..record_capacity + 2) |id| {
        if (count_history.count == record_capacity) {
            count_history.removeRecord(std.testing.allocator, 0);
        }
        count_history.append(try Record.init(
            std.testing.allocator,
            @intCast(id),
            @intCast(id),
            "app",
            "summary",
            "body",
        ));
    }
    count_history.assertValid();
    try std.testing.expectEqual(@as(usize, record_capacity), count_history.count);
    try std.testing.expectEqual(@as(u64, 2), count_history.records[0].?.history_id);

    var body: [notification.body_capacity]u8 = @splat('b');
    var byte_history: History = .{};
    defer byte_history.deinit(std.testing.allocator);
    for (1..record_capacity + 1) |id| {
        byte_history.append(try Record.init(
            std.testing.allocator,
            @intCast(id),
            @intCast(id),
            "app",
            "summary",
            &body,
        ));
        byte_history.prune(std.testing.allocator, @intCast(id));
    }
    byte_history.assertValid();
    try std.testing.expect(byte_history.file_bytes <= file_capacity);
    try std.testing.expect(byte_history.records[0].?.history_id > 1);
}

test "replacement allocation failure preserves the prior complete record" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, replaceAllocationFailure, .{});
}

fn replaceAllocationFailure(allocator: std.mem.Allocator) !void {
    var history: History = .{};
    defer history.deinit(allocator);
    var first = try sampleStore(allocator, 1, "first");
    defer first.deinit(allocator);
    try history.accepted(allocator, 1, first.get(1).?, false);
    var replacement = try sampleStore(allocator, 1, "replacement");
    defer replacement.deinit(allocator);
    history.accepted(allocator, 2, replacement.get(1).?, true) catch |err| {
        try std.testing.expectEqualStrings("first", history.records[0].?.summary);
        try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
        return err;
    };
}

const OpenRead = enum { opened, missing, failed };
const StatRead = union(enum) { value: ReadStat, failed };
const BytesRead = union(enum) {
    complete: []const u8,
    short: usize,
    failed,
};

const ReadStep = union(enum) {
    open_directory: OpenRead,
    stat_directory: StatRead,
    open_file: OpenRead,
    stat_file: StatRead,
    read: BytesRead,
    close_file,
    close_directory,
};

const HistoryReadTranscript = struct {
    steps: []const ReadStep,
    index: usize = 0,
    directory_open: bool = false,
    file_open: bool = false,

    fn openDirectory(transcript: *HistoryReadTranscript) Error!bool {
        const result = switch (try transcript.next()) {
            .open_directory => |value| value,
            else => return error.HistoryOpenFailed,
        };
        return switch (result) {
            .opened => blk: {
                transcript.directory_open = true;
                break :blk true;
            },
            .missing => false,
            .failed => error.HistoryOpenFailed,
        };
    }

    fn statDirectory(transcript: *HistoryReadTranscript) Error!ReadStat {
        std.debug.assert(transcript.directory_open);
        return switch (try transcript.next()) {
            .stat_directory => |result| switch (result) {
                .value => |value| value,
                .failed => error.HistoryOpenFailed,
            },
            else => error.HistoryOpenFailed,
        };
    }

    fn openFile(transcript: *HistoryReadTranscript) Error!bool {
        std.debug.assert(transcript.directory_open);
        const result = switch (try transcript.next()) {
            .open_file => |value| value,
            else => return error.HistoryOpenFailed,
        };
        return switch (result) {
            .opened => blk: {
                transcript.file_open = true;
                break :blk true;
            },
            .missing => false,
            .failed => error.HistoryOpenFailed,
        };
    }

    fn statFile(transcript: *HistoryReadTranscript) Error!ReadStat {
        std.debug.assert(transcript.file_open);
        return switch (try transcript.next()) {
            .stat_file => |result| switch (result) {
                .value => |value| value,
                .failed => error.HistoryReadFailed,
            },
            else => error.HistoryReadFailed,
        };
    }

    fn read(transcript: *HistoryReadTranscript, bytes: []u8) Error!usize {
        std.debug.assert(transcript.file_open);
        return switch (try transcript.next()) {
            .read => |result| switch (result) {
                .complete => |source| blk: {
                    if (source.len != bytes.len) return error.HistoryReadFailed;
                    @memcpy(bytes, source);
                    break :blk bytes.len;
                },
                .short => |count| blk: {
                    if (count >= bytes.len) return error.HistoryReadFailed;
                    @memset(bytes[0..count], 0);
                    break :blk count;
                },
                .failed => error.HistoryReadFailed,
            },
            else => error.HistoryReadFailed,
        };
    }

    fn closeFile(transcript: *HistoryReadTranscript) void {
        std.debug.assert(transcript.file_open);
        const step = transcript.next() catch unreachable;
        std.debug.assert(step == .close_file);
        transcript.file_open = false;
    }

    fn closeDirectory(transcript: *HistoryReadTranscript) void {
        std.debug.assert(transcript.directory_open);
        std.debug.assert(!transcript.file_open);
        const step = transcript.next() catch unreachable;
        std.debug.assert(step == .close_directory);
        transcript.directory_open = false;
    }

    fn done(transcript: *const HistoryReadTranscript) !void {
        try std.testing.expectEqual(transcript.steps.len, transcript.index);
        try std.testing.expect(!transcript.directory_open);
        try std.testing.expect(!transcript.file_open);
    }

    fn next(transcript: *HistoryReadTranscript) Error!ReadStep {
        if (transcript.index == transcript.steps.len) return error.HistoryReadFailed;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

const private_directory = ReadStat{ .kind = .directory, .mode = 0o700, .size = 0 };

fn privateFile(size: u64) ReadStat {
    return .{ .kind = .file, .mode = 0o600, .size = size };
}

fn expectReadFailure(expected: Error, steps: []const ReadStep) !void {
    var transcript = HistoryReadTranscript{ .steps = steps };
    try std.testing.expectError(expected, readRetained(&transcript, std.testing.allocator));
    try transcript.done();
}

test "history read transcript opens stats reads and closes in exact order" {
    const line =
        \\{"received_unix_seconds":1,"history_id":1,"app_name":"app","summary":"summary","body":"body"}
        \\
    ;
    var transcript = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(line.len) } },
        .{ .read = .{ .complete = line } },
        .close_file,
        .close_directory,
    } };
    const bytes = (try readRetained(&transcript, std.testing.allocator)).?;
    defer std.testing.allocator.free(bytes);
    try transcript.done();
    var history = try parse(std.testing.allocator, bytes, 1);
    defer history.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), history.count);
}

test "missing history directory and file are empty success with exact cleanup" {
    var no_directory = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .missing },
    } };
    try std.testing.expectEqual(null, try readRetained(&no_directory, std.testing.allocator));
    try no_directory.done();

    var no_file = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .missing },
        .close_directory,
    } };
    try std.testing.expectEqual(null, try readRetained(&no_file, std.testing.allocator));
    try no_file.done();
}

test "history open stat kind and private-mode failures close exact handles" {
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .failed },
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .failed },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = .{ .kind = .file, .mode = 0o700, .size = 0 } } },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = .{ .kind = .directory, .mode = 0o755, .size = 0 } } },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .failed },
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .failed },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = .{ .kind = .directory, .mode = 0o600, .size = 0 } } },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = .{ .kind = .file, .mode = 0o640, .size = 0 } } },
        .close_file,
        .close_directory,
    });
}

test "history size read short-read and malformed failures publish nothing" {
    try expectReadFailure(error.HistoryTooLarge, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(file_capacity + 1) } },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .{ .read = .failed },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .{ .read = .{ .short = 3 } },
        .close_file,
        .close_directory,
    });

    var malformed = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(2) } },
        .{ .read = .{ .complete = "{}" } },
        .close_file,
        .close_directory,
    } };
    const bytes = (try readRetained(&malformed, std.testing.allocator)).?;
    defer std.testing.allocator.free(bytes);
    try malformed.done();
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, bytes, 1));
}

test "history read allocation failure closes file and directory" {
    var transcript = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .close_file,
        .close_directory,
    } };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, readRetained(&transcript, failing.allocator()));
    try transcript.done();
}

const Step = union(enum) {
    begin: bool,
    write: struct { bytes: []const u8, ok: bool },
    sync_file: bool,
    adopt: bool,
    sync_parent: bool,
    abort: bool,
};

const Transcript = struct {
    steps: []const Step,
    index: usize = 0,
    canonical: []const u8 = "old\n",
    temporary: ?[]const u8 = null,

    fn begin(transcript: *Transcript) !void {
        if (!try transcript.boolean(.begin)) return error.BeginFailed;
        transcript.temporary = "";
    }

    fn write(transcript: *Transcript, bytes: []const u8) !void {
        const expected = switch (try transcript.next()) {
            .write => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (!std.mem.eql(u8, expected.bytes, bytes)) return error.TranscriptMismatch;
        if (!expected.ok) return error.WriteFailed;
        transcript.temporary = bytes;
    }

    fn syncFile(transcript: *Transcript) !void {
        if (!try transcript.boolean(.sync_file)) return error.SyncFailed;
    }

    fn adopt(transcript: *Transcript) !void {
        if (!try transcript.boolean(.adopt)) return error.AdoptFailed;
        transcript.canonical = transcript.temporary orelse return error.TranscriptMismatch;
        transcript.temporary = null;
    }

    fn syncParent(transcript: *Transcript) !void {
        if (!try transcript.boolean(.sync_parent)) return error.ParentSyncFailed;
    }

    fn abort(transcript: *Transcript) !void {
        const ok = switch (try transcript.next()) {
            .abort => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (!ok) return error.AbortFailed;
        transcript.temporary = null;
    }

    fn boolean(transcript: *Transcript, tag: std.meta.Tag(Step)) !bool {
        const step = try transcript.next();
        if (std.meta.activeTag(step) != tag) return error.TranscriptMismatch;
        return switch (step) {
            .begin, .sync_file, .adopt, .sync_parent => |value| value,
            else => unreachable,
        };
    }

    fn next(transcript: *Transcript) !Step {
        if (transcript.index == transcript.steps.len) return error.TranscriptMismatch;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

test "replacement transcript writes exact bytes and aborts every pre-adoption failure" {
    var success = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = true },
        .{ .sync_parent = true },
    } };
    try persist(&success, "complete\n");
    try std.testing.expectEqual(success.steps.len, success.index);
    try std.testing.expectEqualStrings("complete\n", success.canonical);

    var write_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = false } },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.WriteFailed, persist(&write_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", write_failed.canonical);

    var sync_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = false },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.SyncFailed, persist(&sync_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", sync_failed.canonical);

    var adopt_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = false },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.AdoptFailed, persist(&adopt_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", adopt_failed.canonical);

    var cleanup_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = false } },
        .{ .abort = false },
    } };
    try std.testing.expectError(error.HistoryCleanupFailed, persist(&cleanup_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", cleanup_failed.canonical);

    var parent_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = true },
        .{ .sync_parent = false },
    } };
    try std.testing.expectError(error.ParentSyncFailed, persist(&parent_failed, "complete\n"));
    try std.testing.expectEqual(parent_failed.steps.len, parent_failed.index);
    try std.testing.expectEqualStrings("complete\n", parent_failed.canonical);
}

test "generated JSONL bytes and record histories remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzHistory, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzHistory({}, &empty);
}

test "generated malformed JSONL publishes either one complete history or an exact error" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzBytes, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzBytes({}, &empty);
}

fn fuzzBytes(_: void, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var history = parse(std.testing.allocator, input, @as(i64, smith.value(u32))) catch |err| switch (err) {
        error.HistoryCorrupt, error.LineTooLong, error.HistoryIdExhausted => return,
        else => return err,
    };
    defer history.deinit(std.testing.allocator);
    history.assertValid();
}

fn fuzzHistory(_: void, smith: *std.testing.Smith) !void {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var bytes: [128]u8 = undefined;
    for (0..512) |_| {
        if (smith.eosWeightedSimple(1, 7)) break;
        const text = bytes[0..smith.slice(&bytes)];
        const id = @as(u32, smith.value(u8)) + 1;
        var source = sampleStore(
            std.testing.allocator,
            id,
            text,
        ) catch continue;
        defer source.deinit(std.testing.allocator);
        history.accepted(
            std.testing.allocator,
            @as(i64, smith.value(u32)),
            source.get(id).?,
            smith.value(bool),
        ) catch |err| switch (err) {
            error.HistoryCorrupt, error.LineTooLong => {},
            else => return err,
        };
        if (smith.value(bool)) history.closed(id);
        history.assertValid();
    }
    const encoded = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(encoded);
    const public = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(public);
    try std.testing.expect(public.len <= file_capacity);
    if (public.len > 0) try std.testing.expectEqual(@as(u8, '\n'), public[public.len - 1]);
    var parsed = try parse(std.testing.allocator, encoded, 0);
    defer parsed.deinit(std.testing.allocator);
}
