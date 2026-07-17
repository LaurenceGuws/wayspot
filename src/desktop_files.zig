//! Reads bounded desktop files in deterministic XDG precedence order.

const std = @import("std");
const apps = @import("apps.zig");

pub const file_capacity = 512;
pub const id_capacity = 256;
pub const root_capacity = 16;
pub const data_directories_capacity = root_capacity * std.Io.Dir.max_path_bytes;
pub const path_environment_capacity = 64 * 1024;
pub const terminal_capacity = 256;

pub const Environment = struct {
    home: ?[]const u8,
    data_home: ?[]const u8,
    data_dirs: ?[]const u8,
};

pub const Report = struct {
    roots_unavailable: usize = 0,
    files_unreadable: usize = 0,
    files_too_long: usize = 0,
    ids_too_long: usize = 0,
};

/// Files owns every desktop id and file byte slice in items.
pub const Files = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(apps.DesktopFile) = .empty,
    report: Report = .{},

    pub fn deinit(files: *Files) void {
        for (files.items.items) |file| {
            files.allocator.free(file.id);
            files.allocator.free(file.bytes);
        }
        files.items.deinit(files.allocator);
        files.* = undefined;
    }
};

/// Reads all available XDG application directories or returns no partial Files.
pub fn collect(
    allocator: std.mem.Allocator,
    io: std.Io,
    environment: Environment,
) !Files {
    var files = Files{ .allocator = allocator };
    errdefer files.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const roots = try applicationRoots(arena.allocator(), environment);
    for (roots, 0..) |root, root_index| {
        collectRoot(&files, io, root, @intCast(root_index)) catch |failure| switch (failure) {
            error.FileNotFound, error.NotDir, error.AccessDenied => files.report.roots_unavailable += 1,
            else => return failure,
        };
    }
    std.mem.sortUnstable(apps.DesktopFile, files.items.items, {}, lessThan);
    return files;
}

/// Removes apps whose TryExec is not executable, after every check succeeds.
pub fn applyTryExec(io: std.Io, path_environment: ?[]const u8, list: *apps.List) !void {
    const path = path_environment orelse "";
    if (path.len > path_environment_capacity) return error.PathEnvironmentTooLong;

    var unavailable: [apps.app_capacity]bool = @splat(false);
    for (list.slice(), 0..) |app, index| {
        const try_exec = app.try_exec orelse continue;
        unavailable[index] = !try executable(io, path, try_exec);
    }
    var index = list.count;
    while (index > 0) {
        index -= 1;
        if (unavailable[index]) list.rejectTryExec(index);
    }
}

/// Keeps terminal apps only when this beta can execute the configured terminal.
pub fn applyTerminal(
    io: std.Io,
    path_environment: ?[]const u8,
    terminal: ?[]const u8,
    list: *apps.List,
) !?[]const u8 {
    const name = terminal orelse {
        rejectTerminalApps(list);
        return null;
    };
    if (name.len == 0 or name.len > terminal_capacity) return error.TerminalInvalid;
    if (!std.mem.eql(u8, name, "kitty")) return error.TerminalUnsupported;
    const path = path_environment orelse "";
    if (path.len > path_environment_capacity) return error.PathEnvironmentTooLong;
    if (!try executable(io, path, name)) {
        rejectTerminalApps(list);
        return null;
    }
    return name;
}

fn rejectTerminalApps(list: *apps.List) void {
    var index = list.count;
    while (index > 0) {
        index -= 1;
        if (list.items[index].terminal) list.rejectTerminal(index);
    }
}

fn executable(io: std.Io, path_environment: []const u8, name: []const u8) !bool {
    if (std.fs.path.isAbsolute(name)) return canExecute(io, name);
    var directories = std.mem.splitScalar(u8, path_environment, std.fs.path.delimiter);
    var candidate: [std.Io.Dir.max_path_bytes]u8 = undefined;
    while (directories.next()) |directory| {
        const path = if (directory.len == 0)
            name
        else
            std.fmt.bufPrint(&candidate, "{s}/{s}", .{ directory, name }) catch
                return error.TryExecPathTooLong;
        if (try canExecute(io, path)) return true;
    }
    return false;
}

fn canExecute(io: std.Io, path: []const u8) !bool {
    std.Io.Dir.cwd().access(io, path, .{ .execute = true }) catch |failure| switch (failure) {
        error.FileNotFound, error.AccessDenied, error.PermissionDenied => return false,
        else => return failure,
    };
    return true;
}

fn collectRoot(files: *Files, io: std.Io, path: []const u8, root: u8) !void {
    var directory = try std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true });
    defer directory.close(io);

    var walker = try directory.walk(files.allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .sym_link) continue;
        if (!std.mem.endsWith(u8, entry.path, ".desktop")) continue;
        if (entry.path.len > id_capacity) {
            files.report.ids_too_long += 1;
            continue;
        }
        if (files.items.items.len == file_capacity) return error.TooManyDesktopFiles;

        const bytes = entry.dir.readFileAlloc(
            io,
            entry.basename,
            files.allocator,
            .limited(apps.desktop_file_capacity + 1),
        ) catch |failure| switch (failure) {
            error.FileNotFound, error.NotDir, error.AccessDenied => {
                files.report.files_unreadable += 1;
                continue;
            },
            error.StreamTooLong => {
                files.report.files_too_long += 1;
                continue;
            },
            else => return failure,
        };
        errdefer files.allocator.free(bytes);
        const id = try files.allocator.dupe(u8, entry.path);
        errdefer files.allocator.free(id);
        std.mem.replaceScalar(u8, id, '/', '-');
        try files.items.append(files.allocator, .{
            .root = root,
            .id = id,
            .bytes = bytes,
        });
    }
}

fn lessThan(_: void, left: apps.DesktopFile, right: apps.DesktopFile) bool {
    if (left.root != right.root) return left.root < right.root;
    return std.mem.lessThan(u8, left.id, right.id);
}

fn applicationRoots(allocator: std.mem.Allocator, environment: Environment) ![]const []const u8 {
    var roots: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer roots.deinit(allocator);

    if (absolute(environment.data_home)) |data_home| {
        try appendRoot(&roots, allocator, data_home);
    } else if (absolute(environment.home)) |home| {
        const data_home = try std.fmt.allocPrint(allocator, "{s}/.local/share", .{home});
        try appendRoot(&roots, allocator, data_home);
    }

    const data_dirs = environment.data_dirs orelse "/usr/local/share:/usr/share";
    if (data_dirs.len > data_directories_capacity) return error.DataDirectoriesTooLong;
    var directories = std.mem.splitScalar(u8, data_dirs, ':');
    while (directories.next()) |directory| {
        const path = absolute(directory) orelse continue;
        try appendRoot(&roots, allocator, path);
    }
    return roots.items;
}

fn appendRoot(
    roots: *std.ArrayListUnmanaged([]const u8),
    allocator: std.mem.Allocator,
    data: []const u8,
) !void {
    if (data.len > std.Io.Dir.max_path_bytes - "/applications".len) {
        return error.DataDirectoryTooLong;
    }
    const path = try std.fmt.allocPrint(allocator, "{s}/applications", .{std.mem.trimEnd(u8, data, "/")});
    for (roots.items) |existing| {
        if (std.mem.eql(u8, existing, path)) return;
    }
    if (roots.items.len == root_capacity) return error.TooManyDataDirectories;
    try roots.append(allocator, path);
}

fn absolute(path: ?[]const u8) ?[]const u8 {
    const value = path orelse return null;
    if (value.len == 0 or !std.fs.path.isAbsolute(value)) return null;
    return value;
}

test "XDG roots preserve precedence defaults and reject relative paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const explicit = try applicationRoots(arena.allocator(), .{
        .home = "/home/user",
        .data_home = "/data",
        .data_dirs = "/first:/second:relative:/first",
    });
    try expectRoots(explicit, &.{
        "/data/applications",
        "/first/applications",
        "/second/applications",
    });

    _ = arena.reset(.retain_capacity);
    const defaults = try applicationRoots(arena.allocator(), .{
        .home = "/home/user",
        .data_home = null,
        .data_dirs = null,
    });
    try expectRoots(defaults, &.{
        "/home/user/.local/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications",
    });
}

fn expectRoots(actual: []const []const u8, expected: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (actual, expected) |actual_root, expected_root| {
        try std.testing.expectEqualStrings(expected_root, actual_root);
    }
}

test "failing Io yields no files and counts every absent root" {
    var files = try collect(std.testing.allocator, std.Io.failing, .{
        .home = "/home/user",
        .data_home = null,
        .data_dirs = null,
    });
    defer files.deinit();
    try std.testing.expectEqual(@as(usize, 0), files.items.items.len);
    try std.testing.expectEqual(@as(usize, 3), files.report.roots_unavailable);
}

test "file ordering is root precedence then desktop id" {
    var items = [_]apps.DesktopFile{
        .{ .root = 1, .id = @constCast("a.desktop"), .bytes = @constCast("") },
        .{ .root = 0, .id = @constCast("z.desktop"), .bytes = @constCast("") },
        .{ .root = 0, .id = @constCast("a.desktop"), .bytes = @constCast("") },
    };
    std.mem.sortUnstable(apps.DesktopFile, &items, {}, lessThan);
    try std.testing.expectEqual(@as(u8, 0), items[0].root);
    try std.testing.expectEqualStrings("a.desktop", items[0].id);
    try std.testing.expectEqualStrings("z.desktop", items[1].id);
    try std.testing.expectEqual(@as(u8, 1), items[2].root);
}

test "TryExec removal commits only after bounded availability checks" {
    const source = [_]apps.DesktopFile{
        .{ .root = 0, .id = @constCast("plain.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Plain\nExec=plain",
        ) },
        .{ .root = 0, .id = @constCast("checked.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Checked\nExec=checked\nTryExec=checked",
        ) },
    };
    var list = try apps.load(std.testing.allocator, &source, "Hyprland");
    defer list.deinit();
    try applyTryExec(std.Io.failing, "/bin:/usr/bin", &list);
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqualStrings("Plain", list.slice()[0].name);
    try std.testing.expectEqual(
        @as(usize, 1),
        list.report.decisions[@intFromEnum(apps.Decision.unavailable_try_exec)],
    );
}

test "terminal applications require the supported executable" {
    const source = [_]apps.DesktopFile{.{
        .root = 0,
        .id = @constCast("terminal.desktop"),
        .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Terminal\nExec=btop\nTerminal=true",
        ),
    }};
    var list = try apps.load(std.testing.allocator, &source, "Hyprland");
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqual(null, try applyTerminal(std.Io.failing, "/bin", null, &list));
    try std.testing.expectEqual(@as(usize, 0), list.count);
    try std.testing.expectEqual(
        @as(usize, 1),
        list.report.decisions[@intFromEnum(apps.Decision.unavailable_terminal)],
    );
}
