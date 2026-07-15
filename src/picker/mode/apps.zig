//! Apps owns the default mode, desktop application discovery, fixed local candidates, and candidate string lifetimes.

const std = @import("std");
const candidate_mod = @import("picker_candidate");

const Dependency = union(enum) {
    cmd: []const u8,
};

const Execution = union(enum) {
    shell_cmd: []const u8,
};

const Spec = struct {
    title: []const u8,
    subtitle: []const u8,
    open: []const u8,
    icon: []const u8,
    execution: Execution,
    dependency: Dependency,
};

const local_specs = [_]Spec{
    .{
        .title = "Settings",
        .subtitle = "System",
        .open = "settings",
        .icon = "preferences-system-symbolic",
        .execution = .{ .shell_cmd = "wlrlui" },
        .dependency = .{ .cmd = "wlrlui" },
    },
    .{
        .title = "Power menu",
        .subtitle = "Session",
        .open = "power",
        .icon = "system-shutdown-symbolic",
        .execution = .{ .shell_cmd = "wlogout" },
        .dependency = .{ .cmd = "wlogout" },
    },
};

/// Apps is the first Cmd arm and the sole owner of app and fixed-local candidate composition.
pub const Apps = struct {
    cache_path: []const u8,
    cache_data: ?[]u8 = null,
    owned_strings: std.ArrayListUnmanaged([]u8) = .empty,
    cmd_exists_fn: *const fn (name: []const u8) bool = cmdExists,
    /// desktop_root narrows discovery to one borrowed root when configured; null uses standard roots.
    desktop_root: ?[]const u8 = null,

    /// init records the cache path; candidate strings remain owned by this Apps value after collection.
    pub fn init(cache_path: []const u8) Apps {
        return .{
            .cache_path = cache_path,
        };
    }

    /// deinit releases cache bytes and every producer string exactly once.
    pub fn deinit(self: *Apps, allocator: std.mem.Allocator) void {
        self.freeCacheData(allocator);
        self.freeOwnedStrings(allocator);
        self.owned_strings.deinit(allocator);
    }

    /// collectCandidates appends bounded installed-app and available fixed-local leaves.
    /// Producer-owned strings are released before each retry; the caller owns the Candidate.List storage.
    pub fn collectCandidates(
        self: *Apps,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
    ) !void {
        self.freeCacheData(allocator);
        self.freeOwnedStrings(allocator);
        const data = std.Io.Dir.cwd().readFileAlloc(
            std.Options.debug_io,
            self.cache_path,
            allocator,
            .limited(2 * 1024 * 1024),
        ) catch |err| switch (err) {
            error.FileNotFound, error.NotDir, error.AccessDenied => {
                self.collectFromDesktopFiles(allocator, out) catch |scan_err| switch (scan_err) {
                    error.FileNotFound, error.NotDir, error.AccessDenied => {},
                    else => return scan_err,
                };
                try self.collectOpenCandidates(out);
                return;
            },
            else => return err,
        };

        self.cache_data = data;
        var count: u32 = 0;
        var lines = std.mem.splitScalar(u8, self.cache_data.?, '\n');
        while (lines.next()) |line| {
            const normalized_line = std.mem.trimEnd(u8, line, "\r");
            if (normalized_line.len == 0) continue;
            const delimiter = if (std.mem.indexOfScalar(u8, normalized_line, '\t') != null) "\t" else "\\t";
            var fields = std.mem.splitSequence(u8, normalized_line, delimiter);
            const category = trimCacheField(fields.next() orelse continue);
            const name = trimCacheField(fields.next() orelse continue);
            const exec_cmd = trimCacheField(fields.next() orelse continue);
            const icon_name = trimCacheField(fields.next() orelse "");

            try out.append(
                candidate_mod.Candidate.appLeaf(name, category, exec_cmd, icon_name),
            );
            count += 1;
        }

        if (count == 0) {
            self.freeCacheData(allocator);
            std.log.warn("app candidate cache contained no parsable candidates path={s}", .{self.cache_path});
        }
        try self.collectOpenCandidates(out);
    }

    /// resolve maps one available fixed-local leaf to an executable intent without executing it.
    /// Unknown names return UnknownSelection; known names with missing dependencies return SelectionUnavailable.
    pub fn resolve(self: *const Apps, allocator: std.mem.Allocator, open: []const u8) ![]u8 {
        for (local_specs) |spec| {
            if (!std.mem.eql(u8, spec.open, open)) continue;
            if (!self.openAvailable(spec)) return error.SelectionUnavailable;
            return resolveExecution(allocator, spec.execution);
        }
        return error.UnknownSelection;
    }

    fn collectOpenCandidates(self: *Apps, out: *candidate_mod.Candidate.List) !void {
        for (local_specs) |spec| {
            if (!self.openAvailable(spec)) continue;
            try out.append(candidate_mod.Candidate.openLeaf(spec.title, spec.subtitle, spec.open, spec.icon));
        }
    }

    fn openAvailable(self: *const Apps, spec: Spec) bool {
        return switch (spec.dependency) {
            .cmd => |name| self.cmd_exists_fn(name),
        };
    }

    fn keepString(self: *Apps, allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
        const copy = try allocator.dupe(u8, value);
        try self.owned_strings.append(allocator, copy);
        return copy;
    }

    /// freeOwnedStrings releases producer-owned display strings after staged records are forgotten.
    pub fn freeOwnedStrings(self: *Apps, allocator: std.mem.Allocator) void {
        for (self.owned_strings.items) |item| allocator.free(item);
        self.owned_strings.clearRetainingCapacity();
    }

    /// freeCacheData releases cache bytes borrowed by published Candidates.
    pub fn freeCacheData(self: *Apps, allocator: std.mem.Allocator) void {
        if (self.cache_data) |data| {
            allocator.free(data);
            self.cache_data = null;
        }
    }

    fn collectFromDesktopFiles(
        self: *Apps,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
    ) !void {
        const start_len = out.count;
        var scan = DesktopScanState{};
        defer scan.deinit(allocator);
        if (self.desktop_root) |root| {
            try self.collectFromDesktopRoot(allocator, out, &scan, root);
        } else {
            var roots = try desktopFileRoots(allocator);
            defer {
                for (roots.items) |item| allocator.free(item);
                roots.deinit(allocator);
            }
            for (roots.items) |root| {
                self.collectFromDesktopRoot(allocator, out, &scan, root) catch |err| switch (err) {
                    error.FileNotFound, error.NotDir, error.AccessDenied => continue,
                    else => return err,
                };
            }
        }
        const added = out.count - start_len;
        if (added > 0) {
            writeAppCacheFromCandidates(self.cache_path, out.slice()[start_len..]) catch |err| {
                std.log.warn("app candidates failed to rebuild cache '{s}': {s}", .{ self.cache_path, @errorName(err) });
            };
        }
    }

    fn collectFromDesktopRoot(
        self: *Apps,
        allocator: std.mem.Allocator,
        out: *candidate_mod.Candidate.List,
        scan: *DesktopScanState,
        root_path: []const u8,
    ) !void {
        var dir = if (std.fs.path.isAbsolute(root_path))
            try std.Io.Dir.openDirAbsolute(std.Options.debug_io, root_path, .{ .iterate = true })
        else
            try std.Io.Dir.cwd().openDir(std.Options.debug_io, root_path, .{ .iterate = true });
        defer dir.close(std.Options.debug_io);

        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next(std.Options.debug_io)) |entry| {
            if (entry.kind != .file and entry.kind != .sym_link) continue;
            if (!std.mem.endsWith(u8, entry.path, ".desktop")) continue;
            if (entry.path.len >= 512) continue;
            const data = entry.dir.readFileAlloc(std.Options.debug_io, entry.basename, allocator, .limited(128 * 1024)) catch continue;
            defer allocator.free(data);
            const parsed = parseDesktopEntry(data) orelse continue;
            if (parsed.hidden or parsed.no_display) continue;
            if (parsed.exec_cmd.len == 0 or parsed.name.len == 0) continue;

            const exec_norm = try normalizeDesktopExecAlloc(allocator, parsed.exec_cmd);
            defer allocator.free(exec_norm);
            if (exec_norm.len == 0) continue;

            const is_new = scan.seenExec(allocator, exec_norm) catch continue;
            if (!is_new) continue;

            const category = firstDesktopCategory(parsed.categories) orelse "Applications";
            const kept_name = try self.keepString(allocator, parsed.name);
            const kept_category = try self.keepString(allocator, category);
            const kept_exec = try self.keepString(allocator, exec_norm);
            const kept_icon = try self.keepString(allocator, parsed.icon);
            try out.append(candidate_mod.Candidate.appLeaf(kept_name, kept_category, kept_exec, kept_icon));
        }
    }
};

fn resolveExecution(allocator: std.mem.Allocator, execution: Execution) ![]u8 {
    return switch (execution) {
        .shell_cmd => |intent| allocator.dupe(u8, intent),
    };
}

fn cmdExists(name: []const u8) bool {
    if (name.len == 0 or name.len > 255) return false;
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path_env = if (std.c.getenv("PATH")) |value| std.mem.span(value) else return false;
    var it = std.mem.splitScalar(u8, path_env, ':');
    while (it.next()) |dir| {
        if (dir.len == 0) continue;
        const joined = std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ dir, name }) catch continue;
        std.Io.Dir.accessAbsolute(std.Options.debug_io, joined, .{}) catch continue;
        return true;
    }
    return false;
}

fn trimCacheField(value: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, value, " \t\r");
    if (std.mem.endsWith(u8, trimmed, "\\r")) return std.mem.trimEnd(u8, trimmed[0 .. trimmed.len - 2], " \t");
    return trimmed;
}

pub fn invalidateDefaultCache() void {
    const allocator = std.heap.page_allocator;
    const home = if (std.c.getenv("HOME")) |value| std.mem.span(value) else return;
    const cache_path = std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home}) catch return;
    defer allocator.free(cache_path);
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, cache_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.warn("app candidate cache invalidate failed path={s} err={s}", .{ cache_path, @errorName(err) }),
    };
}

fn testApps(cache_path: []const u8) Apps {
    return .{
        .cache_path = cache_path,
        .cmd_exists_fn = testCmdExists,
    };
}

fn testCmdExists(_: []const u8) bool {
    return false;
}

const DesktopScanState = struct {
    seen_execs: std.StringHashMapUnmanaged(void) = .{},

    fn seenExec(self: *DesktopScanState, allocator: std.mem.Allocator, exec_cmd: []const u8) !bool {
        const gop = try self.seen_execs.getOrPut(allocator, exec_cmd);
        if (gop.found_existing) return false;
        gop.key_ptr.* = try allocator.dupe(u8, exec_cmd);
        return true;
    }

    fn deinit(self: *DesktopScanState, allocator: std.mem.Allocator) void {
        var it = self.seen_execs.iterator();
        while (it.next()) |entry| allocator.free(entry.key_ptr.*);
        self.seen_execs.deinit(allocator);
    }
};

const ParsedDesktopEntry = struct {
    name: []const u8 = "",
    exec_cmd: []const u8 = "",
    icon: []const u8 = "",
    categories: []const u8 = "",
    hidden: bool = false,
    no_display: bool = false,
};

fn parseDesktopEntry(data: []const u8) ?ParsedDesktopEntry {
    var in_entry = false;
    var parsed = ParsedDesktopEntry{};
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, std.mem.trimEnd(u8, raw_line, "\r"), " \t");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[' and line[line.len - 1] == ']') {
            in_entry = std.mem.eql(u8, line, "[Desktop Entry]");
            continue;
        }
        if (!in_entry) continue;
        const eq_idx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq_idx], " \t");
        const value = std.mem.trim(u8, line[eq_idx + 1 ..], " \t");
        if (std.mem.eql(u8, key, "Type")) {
            if (!std.ascii.eqlIgnoreCase(value, "Application")) return null;
        } else if (std.mem.eql(u8, key, "NoDisplay")) {
            parsed.no_display = parseDesktopBool(value);
        } else if (std.mem.eql(u8, key, "Hidden")) {
            parsed.hidden = parseDesktopBool(value);
        } else if (std.mem.eql(u8, key, "Name")) {
            if (parsed.name.len == 0) parsed.name = value;
        } else if (std.mem.eql(u8, key, "Exec")) {
            if (parsed.exec_cmd.len == 0) parsed.exec_cmd = value;
        } else if (std.mem.eql(u8, key, "Icon")) {
            if (parsed.icon.len == 0) parsed.icon = value;
        } else if (std.mem.eql(u8, key, "Categories")) {
            if (parsed.categories.len == 0) parsed.categories = value;
        }
    }
    if (parsed.name.len == 0 or parsed.exec_cmd.len == 0) return null;
    return parsed;
}

fn parseDesktopBool(value: []const u8) bool {
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, value, " \t"), "true") or std.mem.eql(u8, std.mem.trim(u8, value, " \t"), "1");
}

fn firstDesktopCategory(categories: []const u8) ?[]const u8 {
    var it = std.mem.splitScalar(u8, categories, ';');
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len > 0) return trimmed;
    }
    return null;
}

fn normalizeDesktopExecAlloc(allocator: std.mem.Allocator, exec_cmd: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var i: u32 = 0;
    var in_single = false;
    var in_double = false;
    while (i < exec_cmd.len) : (i += 1) {
        const ch = exec_cmd[i];
        if (!in_double and ch == '\'') {
            in_single = !in_single;
            try out.append(allocator, ch);
            continue;
        }
        if (!in_single and ch == '"') {
            in_double = !in_double;
            try out.append(allocator, ch);
            continue;
        }
        if (ch == '%' and i + 1 < exec_cmd.len) {
            const code = exec_cmd[i + 1];
            if (std.ascii.isAlphabetic(code) or code == '%') {
                i += 1;
                while (out.items.len > 0 and out.items[out.items.len - 1] == ' ') {
                    out.shrinkRetainingCapacity(out.items.len - 1);
                }
                continue;
            }
        }
        try out.append(allocator, ch);
    }

    const trimmed = std.mem.trim(u8, out.items, " \t");
    return allocator.dupe(u8, trimmed);
}

fn desktopFileRoots(allocator: std.mem.Allocator) !std.ArrayList([]u8) {
    var roots = std.ArrayList([]u8).empty;
    errdefer {
        for (roots.items) |item| allocator.free(item);
        roots.deinit(allocator);
    }

    const home = if (std.c.getenv("HOME")) |value| allocator.dupe(u8, std.mem.span(value)) catch null else null;
    defer if (home) |h| allocator.free(h);
    const xdg_data_home = if (std.c.getenv("XDG_DATA_HOME")) |value| allocator.dupe(u8, std.mem.span(value)) catch null else null;
    defer if (xdg_data_home) |x| allocator.free(x);
    const xdg_data_dirs = if (std.c.getenv("XDG_DATA_DIRS")) |value| allocator.dupe(u8, std.mem.span(value)) catch null else null;
    defer if (xdg_data_dirs) |x| allocator.free(x);

    if (xdg_data_home) |x| {
        try appendDesktopRootUnique(&roots, allocator, try std.fmt.allocPrint(allocator, "{s}/applications", .{x}));
    } else if (home) |h| {
        try appendDesktopRootUnique(&roots, allocator, try std.fmt.allocPrint(allocator, "{s}/.local/share/applications", .{h}));
    }

    if (xdg_data_dirs) |dirs| {
        var it = std.mem.splitScalar(u8, dirs, ':');
        while (it.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t");
            if (trimmed.len == 0) continue;
            try appendDesktopRootUnique(&roots, allocator, try std.fmt.allocPrint(allocator, "{s}/applications", .{trimmed}));
        }
    }
    // Always include canonical system app roots even when XDG_DATA_DIRS is custom.
    try appendDesktopRootUnique(&roots, allocator, try allocator.dupe(u8, "/usr/local/share/applications"));
    try appendDesktopRootUnique(&roots, allocator, try allocator.dupe(u8, "/usr/share/applications"));

    return roots;
}

fn appendDesktopRootUnique(roots: *std.ArrayList([]u8), allocator: std.mem.Allocator, candidate_owned: []u8) !void {
    for (roots.items) |existing| {
        if (std.mem.eql(u8, existing, candidate_owned)) {
            allocator.free(candidate_owned);
            return;
        }
    }
    try roots.append(allocator, candidate_owned);
}

fn writeAppCacheFromCandidates(cache_path: []const u8, candidates: []const candidate_mod.Candidate) !void {
    if (candidates.len == 0) return;
    const parent = std.fs.path.dirname(cache_path) orelse return;
    if (std.fs.path.isAbsolute(parent)) {
        std.Io.Dir.createDirAbsolute(std.Options.debug_io, parent, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    } else {
        try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
    }

    var file = if (std.fs.path.isAbsolute(cache_path))
        try std.Io.Dir.createFileAbsolute(std.Options.debug_io, cache_path, .{ .truncate = true })
    else
        try std.Io.Dir.cwd().createFile(std.Options.debug_io, cache_path, .{ .truncate = true });
    defer file.close(std.Options.debug_io);

    var file_buffer: [4096]u8 = undefined;
    var writer = file.writer(std.Options.debug_io, &file_buffer);
    for (candidates) |candidate| {
        if (!candidate.isApp()) continue;
        try writer.interface.print("{s}\t{s}\t{s}\t{s}\n", .{ candidate.subtitle(), candidate.title(), candidate.selection(), candidate.iconName() });
    }
    try writer.interface.flush();
    try file.sync(std.Options.debug_io);
}

test "apps owns fixed local candidates and executable resolution" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\
        ,
    });
    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    const Fake = struct {
        fn cmdExists(name: []const u8) bool {
            return std.mem.eql(u8, name, "wlrlui");
        }
    };

    var apps = Apps{
        .cache_path = cache_path,
        .cmd_exists_fn = Fake.cmdExists,
    };
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(usize, 2), list.count);
    try std.testing.expect(list.items[0].isApp());
    try std.testing.expect(list.items[1].isOpen());
    try std.testing.expectEqualStrings("Kitty", list.items[0].title());
    try std.testing.expectEqualStrings("settings", list.items[1].selection());

    const intent = try apps.resolve(std.testing.allocator, "settings");
    defer std.testing.allocator.free(intent);
    try std.testing.expectEqualStrings("wlrlui", intent);
    try std.testing.expectError(error.SelectionUnavailable, apps.resolve(std.testing.allocator, "power"));
    try std.testing.expectError(error.UnknownSelection, apps.resolve(std.testing.allocator, "missing"));
}

test "unexpected app cache read errors propagate" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.Options.debug_io, "cache-dir");
    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/cache-dir", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();

    try std.testing.expectError(error.IsDir, apps.collectCandidates(std.testing.allocator, &list));
    try std.testing.expectEqual(@as(usize, 0), list.count);
    try std.testing.expect(apps.cache_data == null);
}

test "apps collects candidates from cache file" {
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

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), list.count);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqualStrings("Kitty", list.items[0].title());
    try std.testing.expectEqualStrings("Utilities", list.items[0].subtitle());
    try std.testing.expectEqualStrings("kitty", list.items[0].selection());
    try std.testing.expectEqualStrings("kitty", list.items[0].iconName());
}

test "apps accepts candidates without icon metadata" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), list.count);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqualStrings("Kitty", list.items[0].title());
    try std.testing.expectEqualStrings("", list.items[0].iconName());
    try std.testing.expectEqualStrings("firefox", list.items[1].iconName());
}

test "apps scans desktop files when cache is missing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/missing.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);

    try std.testing.expect(apps.cache_data == null);
}

test "apps returns no candidates when cache has no valid candidates" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\bad candidate
        \\still bad
        \\
        ,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 0), list.count);
    try std.testing.expect(apps.cache_data == null);
}

test "apps replaces cache data across candidate collects" {
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

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqualStrings("Kitty", list.items[0].title());

    list.clearRetainingCapacity();
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Graphics\tGimp\tgimp\tgimp
        \\
        ,
    });
    try apps.collectCandidates(std.testing.allocator, &list);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqual(@as(u32, 1), list.count);
    try std.testing.expectEqualStrings("Gimp", list.items[0].title());

    list.clearRetainingCapacity();
    try apps.collectCandidates(std.testing.allocator, &list);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqualStrings("Gimp", list.items[0].title());
}

test "apps trims crlf and trailing whitespace from candidate fields" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities  \tKitty\tkitty  \tkitty  \r
        \\Internet\tFirefox\tfirefox\r
        \\
        ,
    });

    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps.tsv", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);

    var apps = testApps(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    try apps.collectCandidates(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), list.count);
    try std.testing.expectEqualStrings("Utilities", list.items[0].subtitle());
    try std.testing.expectEqualStrings("kitty", list.items[0].selection());
    try std.testing.expectEqualStrings("kitty", list.items[0].iconName());
    try std.testing.expectEqualStrings("firefox", list.items[1].selection());
}

test "desktop entry parser extracts app metadata and strips exec field codes" {
    const data =
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Zen Browser
        \\Exec=/usr/bin/zen-browser --new-window %U
        \\Icon=zen-browser
        \\Categories=Network;WebBrowser;
        \\
    ;
    const parsed = parseDesktopEntry(data) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("Zen Browser", parsed.name);
    try std.testing.expectEqualStrings("/usr/bin/zen-browser --new-window %U", parsed.exec_cmd);
    try std.testing.expectEqualStrings("zen-browser", parsed.icon);
    try std.testing.expectEqualStrings("Network", firstDesktopCategory(parsed.categories).?);

    const normalized = try normalizeDesktopExecAlloc(std.testing.allocator, parsed.exec_cmd);
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("/usr/bin/zen-browser --new-window", normalized);
}

test "apps scans desktop root and rebuilds candidate cache" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.createDirPath(std.Options.debug_io, "apps/sub");
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "apps/sub/test.desktop",
        .data =
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Test App
        \\Exec=test-app %F
        \\Icon=test-icon
        \\Categories=Utility;
        \\
        ,
    });

    const root_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/apps", .{tmp.sub_path});
    defer std.testing.allocator.free(root_path);
    const cache_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer std.testing.allocator.free(cache_path);
    const cache_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/wofi-app-launcher.tsv", .{cache_path});
    defer std.testing.allocator.free(cache_file);

    var apps = testApps(cache_file);
    defer apps.deinit(std.testing.allocator);
    var list = candidate_mod.Candidate.List.empty;
    defer list.deinit();
    var scan = DesktopScanState{};
    defer scan.deinit(std.testing.allocator);

    try apps.collectFromDesktopRoot(std.testing.allocator, &list, &scan, root_path);
    try std.testing.expectEqual(@as(u32, 1), list.count);
    try std.testing.expect(apps.cache_data == null);
    try std.testing.expectEqual(@as(u32, 4), @as(u32, @intCast(apps.owned_strings.items.len)));
    try std.testing.expectEqualStrings("Test App", list.items[0].title());
    try std.testing.expectEqualStrings("Utility", list.items[0].subtitle());
    try std.testing.expectEqualStrings("test-app", list.items[0].selection());

    try writeAppCacheFromCandidates(cache_file, list.slice());
    const written = try std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, cache_file, std.testing.allocator, .limited(4096));
    defer std.testing.allocator.free(written);
    try std.testing.expect(std.mem.indexOf(u8, written, "Utility\tTest App\ttest-app\ttest-icon\n") != null);

    apps.freeOwnedStrings(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), apps.owned_strings.items.len);
    apps.freeOwnedStrings(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), apps.owned_strings.items.len);
}
