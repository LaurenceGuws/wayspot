//! AppsProvider owns desktop application discovery and candidate string lifetimes.

const std = @import("std");
const search = @import("../search/mod.zig");

pub const AppsProvider = struct {
    cache_path: []const u8,
    owned_strings: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn init(cache_path: []const u8) AppsProvider {
        return .{
            .cache_path = cache_path,
        };
    }

    pub fn deinit(self: *AppsProvider, allocator: std.mem.Allocator) void {
        self.freeOwnedStrings(allocator);
        self.owned_strings.deinit(allocator);
    }

    /// collect appends launchable desktop application candidates.
    pub fn collect(
        self: *AppsProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !void {
        self.freeOwnedStrings(allocator);
        const data = std.Io.Dir.cwd().readFileAlloc(
            std.Options.debug_io,
            self.cache_path,
            allocator,
            .limited(2 * 1024 * 1024),
        ) catch |err| switch (err) {
            error.FileNotFound => {
                const count = self.collectFromDesktopFiles(allocator, out) catch |scan_err| {
                    std.log.warn("apps provider desktop scan failed: {s}", .{@errorName(scan_err)});
                    return;
                };
                if (count == 0) return;
                return;
            },
            else => {
                std.log.warn("apps provider cache read failed: {s}", .{@errorName(err)});
                return;
            },
        };
        defer allocator.free(data);

        if (cacheContainsThreeColumnRows(data)) {
            std.log.info("apps provider detected three-column cache rows; attempting desktop refresh", .{});
            const added = self.collectFromDesktopFiles(allocator, out) catch |scan_err| blk: {
                std.log.warn("apps provider three-column refresh scan failed: {s}", .{@errorName(scan_err)});
                break :blk 0;
            };
            if (added > 0) {
                return;
            }
        }

        var count: u32 = 0;
        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |line| {
            const normalized_line = std.mem.trimEnd(u8, line, "\r");
            if (normalized_line.len == 0) continue;
            var fields = std.mem.splitScalar(u8, normalized_line, '\t');
            const category = std.mem.trimEnd(u8, fields.next() orelse continue, " \t\r");
            const name = std.mem.trimEnd(u8, fields.next() orelse continue, " \t\r");
            const exec_cmd = std.mem.trimEnd(u8, fields.next() orelse continue, " \t\r");
            const icon_name = std.mem.trimEnd(u8, fields.next() orelse "", " \t\r");

            const kept_name = try self.keepString(allocator, name);
            const kept_category = try self.keepString(allocator, category);
            const kept_exec = try self.keepString(allocator, exec_cmd);
            const kept_icon = try self.keepString(allocator, icon_name);
            try out.append(
                allocator,
                search.Candidate.initWithIcon(.app, kept_name, kept_category, kept_exec, kept_icon),
            );
            count += 1;
        }

        if (count == 0) {
            std.log.warn("apps provider cache contained no parsable rows path={s}", .{self.cache_path});
            return;
        }
    }

    fn keepString(self: *AppsProvider, allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
        const copy = try allocator.dupe(u8, value);
        try self.owned_strings.append(allocator, copy);
        return copy;
    }

    fn freeOwnedStrings(self: *AppsProvider, allocator: std.mem.Allocator) void {
        for (self.owned_strings.items) |item| allocator.free(item);
        self.owned_strings.clearRetainingCapacity();
    }

    fn collectFromDesktopFiles(
        self: *AppsProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !u32 {
        const start_len = out.items.len;
        var scan = DesktopScanState{};
        defer scan.deinit(allocator);
        var roots = try desktopSearchRoots(allocator);
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
        const added = @as(u32, @intCast(out.items.len - start_len));
        if (added > 0) {
            writeAppCacheFromCandidates(self.cache_path, out.items[start_len..]) catch |err| {
                std.log.warn("apps provider failed to rebuild cache '{s}': {s}", .{ self.cache_path, @errorName(err) });
            };
        }
        return added;
    }

    fn collectFromDesktopRoot(
        self: *AppsProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
        scan: *DesktopScanState,
        root_path: []const u8,
    ) !void {
        var dir = try std.Io.Dir.openDirAbsolute(std.Options.debug_io, root_path, .{ .iterate = true });
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
            try out.append(allocator, search.Candidate.initWithIcon(.app, kept_name, kept_category, kept_exec, kept_icon));
        }
    }
};

pub fn invalidateDefaultCache() void {
    const allocator = std.heap.page_allocator;
    const home = if (std.c.getenv("HOME")) |value| std.mem.span(value) else return;
    const cache_path = std.fmt.allocPrint(allocator, "{s}/.cache/waybar/wofi-app-launcher.tsv", .{home}) catch return;
    defer allocator.free(cache_path);
    std.Io.Dir.deleteFileAbsolute(std.Options.debug_io, cache_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => std.log.warn("apps provider cache invalidate failed path={s} err={s}", .{ cache_path, @errorName(err) }),
    };
}

fn cacheContainsThreeColumnRows(data: []const u8) bool {
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, std.mem.trimEnd(u8, line_raw, "\r"), " \t");
        if (line.len == 0) continue;
        var tab_count: u32 = 0;
        for (line) |ch| {
            if (ch == '\t') tab_count += 1;
        }
        if (tab_count == 2) return true;
    }
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

fn desktopSearchRoots(allocator: std.mem.Allocator) !std.ArrayList([]u8) {
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

fn writeAppCacheFromCandidates(cache_path: []const u8, rows: []const search.Candidate) !void {
    if (rows.len == 0) return;
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
    for (rows) |row| {
        if (row.kind != .app) continue;
        try writer.interface.print("{s}\t{s}\t{s}\t{s}\n", .{ row.subtitle, row.title, row.action, row.icon });
    }
    try writer.interface.flush();
    try file.sync(std.Options.debug_io);
}

test "apps provider collects rows from cache file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqualStrings("Kitty", list.items[0].title);
    try std.testing.expectEqualStrings("Utilities", list.items[0].subtitle);
    try std.testing.expectEqualStrings("kitty", list.items[0].action);
    try std.testing.expectEqualStrings("kitty", list.items[0].icon);
}

test "apps provider accepts three-column rows with empty icon metadata" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqualStrings("Kitty", list.items[0].title);
    try std.testing.expectEqualStrings("", list.items[0].icon);
    try std.testing.expectEqualStrings("firefox", list.items[1].icon);
}

test "cacheContainsThreeColumnRows detects three-column cache lines" {
    const three_column =
        "Utilities\tKitty\tkitty\n" ++
        "Internet\tFirefox\tfirefox\tfirefox\n";
    const modern =
        "Utilities\tKitty\tkitty\tkitty\n" ++
        "Internet\tFirefox\tfirefox\tfirefox\n";
    try std.testing.expect(cacheContainsThreeColumnRows(three_column));
    try std.testing.expect(!cacheContainsThreeColumnRows(modern));
}

test "apps provider scans desktop files when cache is missing" {
    var apps = AppsProvider.init("/tmp/non-existent-app-cache.tsv");
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(list.items.len)));
}

test "apps provider returns no rows when cache has no valid rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\bad row
        \\still bad
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(list.items.len)));
}

test "apps provider keeps one owned string set across collects" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(u32, 8), @as(u32, @intCast(apps.owned_strings.items.len)));

    list.clearRetainingCapacity();
    try provider.collect(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(u32, 8), @as(u32, @intCast(apps.owned_strings.items.len)));

    list.clearRetainingCapacity();
    try provider.collect(std.testing.allocator, &list);
    try std.testing.expectEqual(@as(u32, 8), @as(u32, @intCast(apps.owned_strings.items.len)));
}

test "apps provider trims crlf and trailing whitespace from stored fields" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities  \tKitty\tkitty  \tkitty  \r
        \\Internet\tFirefox\tfirefox\r
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);

    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    const provider = apps.provider();
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqualStrings("Utilities", list.items[0].subtitle);
    try std.testing.expectEqualStrings("kitty", list.items[0].action);
    try std.testing.expectEqualStrings("kitty", list.items[0].icon);
    try std.testing.expectEqualStrings("firefox", list.items[1].action);
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

test "apps provider can scan desktop root and rebuild cache rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("apps/sub");
    try tmp.dir.writeFile(.{
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

    const root_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps");
    defer std.testing.allocator.free(root_path);
    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(cache_path);
    const cache_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/wofi-app-launcher.tsv", .{cache_path});
    defer std.testing.allocator.free(cache_file);

    var apps = AppsProvider.init(cache_file);
    defer apps.deinit(std.testing.allocator);
    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);
    var scan = DesktopScanState{};
    defer scan.deinit(std.testing.allocator);

    try apps.collectFromDesktopRoot(std.testing.allocator, &list, &scan, root_path);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqualStrings("Test App", list.items[0].title);
    try std.testing.expectEqualStrings("Utility", list.items[0].subtitle);
    try std.testing.expectEqualStrings("test-app", list.items[0].action);

    try writeAppCacheFromCandidates(cache_file, list.items);
    const written = try std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, cache_file, std.testing.allocator, .limited(4096));
    defer std.testing.allocator.free(written);
    try std.testing.expect(std.mem.indexOf(u8, written, "Utility\tTest App\ttest-app\ttest-icon\n") != null);
}
