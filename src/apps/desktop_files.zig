//! Reads bounded desktop files in deterministic XDG precedence order.

const std = @import("std");
const apps = @import("catalog.zig");

const file_capacity = apps.app_capacity;
// Bound all visited entries, including non-desktop files, across the roots.
// Depth bounds the number of simultaneously open directory handles.
const traversal_entry_capacity = 64 * 1024;
const traversal_depth_capacity = 32;
const id_capacity = 256;
const root_capacity = 16;
const data_directories_capacity = root_capacity * std.Io.Dir.max_path_bytes;
const path_environment_capacity = 64 * 1024;
const terminal_capacity = 256;

/// Borrows the original HOME and XDG data-directory environment for one discovery.
pub const Environment = struct {
    home: ?[]const u8,
    data_home: ?[]const u8,
    data_dirs: ?[]const u8,
};

/// Counts unavailable roots and individual desktop candidates rejected during discovery.
const Report = struct {
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

    /// Frees the owned file bytes and desktop ids, then invalidates this collection.
    pub fn deinit(files: *Files) void {
        for (files.items.items) |file| {
            files.allocator.free(file.id);
            files.allocator.free(file.bytes);
        }
        files.items.deinit(files.allocator);
        files.* = undefined;
    }
};

/// Reads available XDG roots in precedence order, within the discovery bounds.
/// Missing or inaccessible roots and unreadable candidates are counted.
/// Traversal failure returns no partial collection.
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
    var entries_seen: usize = 0;
    for (roots, 0..) |root, root_index| {
        try collectRoot(&files, io, root, @intCast(root_index), &entries_seen);
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

/// Keeps terminal apps only when Wayspot can execute the configured terminal.
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
        error.FileNotFound, error.AccessDenied, error.PermissionDenied, error.SymLinkLoop => {
            return false;
        },
        else => return failure,
    };
    // X_OK alone tests directory search permission as well as file execution.
    return regularFile(io, .cwd(), path);
}

fn collectRoot(
    files: *Files,
    io: std.Io,
    path: []const u8,
    root: u8,
    entries_seen: *usize,
) !void {
    var directory = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch |err|
        switch (err) {
            error.FileNotFound, error.NotDir, error.AccessDenied => {
                files.report.roots_unavailable += 1;
                return;
            },
            else => return err,
        };
    defer directory.close(io);

    var walker = try directory.walkSelectively(files.allocator);
    defer {
        // Zig 0.17's deinit frees walker memory, not the remaining open children.
        // The root handle belongs to this function, not the walker.
        while (walker.stack.items.len > 1) walker.leave(io);
        walker.deinit();
    }
    while (try walker.next(io)) |entry| {
        if (entries_seen.* == traversal_entry_capacity) return error.TooManyDiscoveryEntries;
        entries_seen.* += 1;
        if (entry.kind == .directory) {
            if (entry.depth() > traversal_depth_capacity) return error.DiscoveryTooDeep;
            try walker.enter(io, entry);
            continue;
        }
        try collectDesktopFile(files, io, entry, root);
    }
}

fn collectDesktopFile(
    files: *Files,
    io: std.Io,
    entry: std.Io.Dir.Walker.Entry,
    root: u8,
) !void {
    if (entry.kind != .file and entry.kind != .sym_link) return;
    if (!std.mem.endsWith(u8, entry.path, ".desktop")) return;
    if (entry.path.len > id_capacity) {
        files.report.ids_too_long += 1;
        return;
    }
    if (files.items.items.len == file_capacity) return error.TooManyDesktopFiles;

    // Preserve ordinary desktop-file symlinks, but never intentionally read
    // a known directory, FIFO, device or other non-regular symlink target.
    if (entry.kind == .sym_link and !try regularFile(io, entry.dir, entry.basename)) {
        files.report.files_unreadable += 1;
        return;
    }
    const bytes = entry.dir.readFileAlloc(
        io,
        entry.basename,
        files.allocator,
        .limited(apps.desktop_file_capacity + 1),
    ) catch |failure| switch (failure) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        error.PermissionDenied,
        error.IsDir,
        error.SymLinkLoop,
        => {
            files.report.files_unreadable += 1;
            return;
        },
        error.StreamTooLong => {
            files.report.files_too_long += 1;
            return;
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

fn regularFile(io: std.Io, dir: std.Io.Dir, path: []const u8) !bool {
    const stat = dir.statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        error.PermissionDenied,
        error.SymLinkLoop,
        => return false,
        else => return err,
    };
    return stat.kind == .file;
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
    const path = try std.fmt.allocPrint(
        allocator,
        "{s}/applications",
        .{std.mem.trimEnd(u8, data, "/")},
    );
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
        .{ .root = 1, .id = "a.desktop", .bytes = "" },
        .{ .root = 0, .id = "z.desktop", .bytes = "" },
        .{ .root = 0, .id = "a.desktop", .bytes = "" },
    };
    std.mem.sortUnstable(apps.DesktopFile, &items, {}, lessThan);
    try std.testing.expectEqual(@as(u8, 0), items[0].root);
    try std.testing.expectEqualStrings("a.desktop", items[0].id);
    try std.testing.expectEqualStrings("z.desktop", items[1].id);
    try std.testing.expectEqual(@as(u8, 1), items[2].root);
}

test "TryExec removal commits only after bounded availability checks" {
    const source = [_]apps.DesktopFile{
        .{
            .root = 0,
            .id = "plain.desktop",
            .bytes = "[Desktop Entry]\nType=Application\nName=Plain\nExec=plain",
        },
        .{
            .root = 0,
            .id = "checked.desktop",
            .bytes = "[Desktop Entry]\nType=Application\nName=Checked\n" ++
                "Exec=checked\nTryExec=checked",
        },
    };
    var list = try apps.load(std.testing.allocator, &source, "Hyprland");
    defer list.deinit();
    try applyTryExec(std.Io.failing, "/bin:/usr/bin", &list);
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqualStrings("Plain", list.slice()[0].name);
    try std.testing.expectEqual(
        @as(usize, 1),
        list.report.decisions[@backingInt(apps.Decision.unavailable_try_exec)],
    );
}

test "terminal applications require the supported executable" {
    const source = [_]apps.DesktopFile{.{
        .root = 0,
        .id = "terminal.desktop",
        .bytes = "[Desktop Entry]\nType=Application\nName=Terminal\nExec=btop\nTerminal=true",
    }};
    var list = try apps.load(std.testing.allocator, &source, "Hyprland");
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqual(null, try applyTerminal(std.Io.failing, "/bin", null, &list));
    try std.testing.expectEqual(@as(usize, 0), list.count);
    try std.testing.expectEqual(
        @as(usize, 1),
        list.report.decisions[@backingInt(apps.Decision.unavailable_terminal)],
    );
}

fn countOpenDirectoryTest(path: []const u8) !usize {
    const io = std.testing.io;
    var dir = try std.Io.Dir.openDirAbsolute(io, "/proc/self/fd", .{ .iterate = true });
    defer dir.close(io);
    var iter = dir.iterate();
    var count: usize = 0;
    while (try iter.next(io)) |entry| {
        var target: [std.Io.Dir.max_path_bytes]u8 = undefined;
        const length = dir.readLink(io, entry.name, &target) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        if (std.mem.eql(u8, target[0..length], path)) count += 1;
    }
    return count;
}

test "execute access to a directory is not an executable file" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    const io = std.testing.io;
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const path = buffer[0..try fixture.dir.realPath(io, &buffer)];
    try std.testing.expect(!try canExecute(io, path));
}

test "early desktop discovery failure retires nested directory handles" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    const io = std.testing.io;
    try fixture.dir.createDirPath(io, "nested");
    try fixture.dir.writeFile(io, .{ .sub_path = "nested/one.desktop", .data = "test" });
    var root_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buffer[0..try fixture.dir.realPath(io, &root_buffer)];
    var nested_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const nested = try std.fmt.bufPrint(&nested_buffer, "{s}/nested", .{root});
    var files = Files{ .allocator = std.testing.allocator };
    defer files.deinit();
    try files.items.resize(files.allocator, file_capacity);
    @memset(files.items.items, .{ .root = 0, .id = &.{}, .bytes = &.{} });
    try std.testing.expectEqual(@as(usize, 0), try countOpenDirectoryTest(nested));
    var entries_seen: usize = 0;
    try std.testing.expectError(
        error.TooManyDesktopFiles,
        collectRoot(&files, io, root, 0, &entries_seen),
    );
    try std.testing.expectEqual(@as(usize, 0), try countOpenDirectoryTest(nested));
}

test "discovery bounds all entries and nested directory handles" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    const io = std.testing.io;
    var root_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buffer[0..try fixture.dir.realPath(io, &root_buffer)];

    var files = Files{ .allocator = std.testing.allocator };
    defer files.deinit();
    try fixture.dir.writeFile(io, .{ .sub_path = "ignored.txt", .data = "" });
    var entries_seen: usize = traversal_entry_capacity;
    try std.testing.expectError(
        error.TooManyDiscoveryEntries,
        collectRoot(&files, io, root, 0, &entries_seen),
    );

    var nested: [traversal_depth_capacity * 2 + 1]u8 = undefined;
    for (0..traversal_depth_capacity) |depth| {
        nested[depth * 2] = 'd';
        nested[depth * 2 + 1] = '/';
    }
    nested[nested.len - 1] = 'd';
    try fixture.dir.createDirPath(io, &nested);
    entries_seen = 0;
    try std.testing.expectError(
        error.DiscoveryTooDeep,
        collectRoot(&files, io, root, 0, &entries_seen),
    );
    var child_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const child = try std.fmt.bufPrint(&child_buffer, "{s}/d", .{root});
    try std.testing.expectEqual(@as(usize, 0), try countOpenDirectoryTest(child));
}

test "desktop discovery follows regular links and skips missing or special targets" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    const io = std.testing.io;
    const linux = std.os.linux;
    try fixture.dir.writeFile(io, .{ .sub_path = "source", .data = "desktop bytes" });
    try fixture.dir.symLink(io, "source", "regular.desktop", .{});
    try fixture.dir.symLink(io, "missing", "missing.desktop", .{});
    try fixture.dir.symLink(io, ".", "directory.desktop", .{});
    try fixture.dir.symLink(io, "loop.desktop", "loop.desktop", .{});
    try std.testing.expectEqual(
        linux.E.SUCCESS,
        linux.errno(linux.mknodat(fixture.dir.handle, "fifo", linux.S.IFIFO | 0o600, 0)),
    );
    try fixture.dir.symLink(io, "fifo", "pipe.desktop", .{});
    var root_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buffer[0..try fixture.dir.realPath(io, &root_buffer)];
    var files = Files{ .allocator = std.testing.allocator };
    defer files.deinit();
    var entries_seen: usize = 0;
    try collectRoot(&files, io, root, 0, &entries_seen);
    try std.testing.expectEqual(@as(usize, 1), files.items.items.len);
    try std.testing.expectEqualStrings("regular.desktop", files.items.items[0].id);
    try std.testing.expectEqualStrings("desktop bytes", files.items.items[0].bytes);
    try std.testing.expectEqual(@as(usize, 4), files.report.files_unreadable);
}
