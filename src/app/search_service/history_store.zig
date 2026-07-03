const std = @import("std");

pub fn recordSelection(
    history: *std.ArrayListUnmanaged([]u8),
    max_history: u32,
    allocator: std.mem.Allocator,
    action: []const u8,
) !void {
    if (action.len == 0) return;
    const copy = try allocator.dupe(u8, action);
    try history.append(allocator, copy);

    if (history.items.len > max_history) {
        const oldest = history.orderedRemove(0);
        allocator.free(oldest);
    }
}

pub fn loadHistory(
    history: *std.ArrayListUnmanaged([]u8),
    max_history: u32,
    history_path: ?[]const u8,
    allocator: std.mem.Allocator,
) !void {
    const path = history_path orelse return;
    const data = readFileAnyPath(allocator, path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer allocator.free(data);

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try recordSelection(history, max_history, allocator, trimmed);
    }
}

pub fn saveHistory(history: []const []u8, history_path: ?[]const u8, allocator: std.mem.Allocator) !void {
    const path = history_path orelse return;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    for (history) |entry| {
        try out.appendSlice(allocator, entry);
        try out.append(allocator, '\n');
    }
    try writeFileAnyPathAtomic(allocator, path, out.items);
}

pub fn historyViewNewestFirst(history: []const []u8, allocator: std.mem.Allocator) ![]const []const u8 {
    var out = std.ArrayList([]const u8).empty;
    defer out.deinit(allocator);

    var idx = history.len;
    while (idx > 0) : (idx -= 1) {
        try out.append(allocator, history[idx - 1]);
    }
    return out.toOwnedSlice(allocator);
}

pub fn historySnapshotNewestFirstOwned(history: []const []u8, allocator: std.mem.Allocator) ![]const []const u8 {
    var out = try allocator.alloc([]const u8, history.len);
    errdefer allocator.free(out);

    var out_idx: u32 = 0;
    var idx = history.len;
    while (idx > 0) : (idx -= 1) {
        const dup = allocator.dupe(u8, history[idx - 1]) catch |err| {
            for (out[0..out_idx]) |entry| allocator.free(@constCast(entry));
            return err;
        };
        out[out_idx] = dup;
        out_idx += 1;
    }
    return out;
}

pub fn freeOwnedHistorySnapshot(allocator: std.mem.Allocator, history_snapshot: []const []const u8) void {
    for (history_snapshot) |entry| allocator.free(@constCast(entry));
    allocator.free(history_snapshot);
}

fn readFileAnyPath(allocator: std.mem.Allocator, path: []const u8, max_bytes: u32) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, allocator, .limited(max_bytes));
}

fn writeFileAnyPathAtomic(allocator: std.mem.Allocator, path: []const u8, data: []const u8) !void {
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
        // Some filesystems/dirfds do not support directory fsync; keep write atomic
        // semantics via rename, but treat parent dir sync as best-effort.
        .INVAL, .BADF, .ROFS, .OPNOTSUPP => return,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

test "saveHistory creates relative nested parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var original_cwd = try std.fs.cwd().openDir(".", .{});
    defer original_cwd.close();
    defer original_cwd.setAsCwd() catch unreachable;
    try tmp.dir.setAsCwd();

    const entries = [_][]const u8{ "settings", "power" };
    try saveHistory(entries[0..], "nested/history/history.log", std.testing.allocator);

    const saved = try tmp.dir.readFileAlloc(std.testing.allocator, "nested/history/history.log", 1024);
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("settings\npower\n", saved);
}

test "saveHistory creates absolute nested parent directories" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);

    const history_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/nested/history/history.log", .{base});
    defer std.testing.allocator.free(history_path);

    const entries = [_][]const u8{ "settings", "power" };
    try saveHistory(entries[0..], history_path, std.testing.allocator);

    const file = try std.fs.openFileAbsolute(history_path, .{});
    defer file.close();
    const saved = try file.readToEndAlloc(std.testing.allocator, 1024);
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("settings\npower\n", saved);
}
