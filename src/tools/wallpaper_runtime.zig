const std = @import("std");
const wm = @import("../wm/mod.zig");
const theme_registry = @import("theme_registry.zig");

pub const MonitorTarget = union(enum) {
    all,
    focused,
    named: []const u8,
};

pub const SlideshowOptions = struct {
    hyprpaper_config_path: []const u8,
    wallpapers_root: []const u8,
    interval_seconds: u64 = 600,
    run_once: bool = false,
};

const Hints = struct {
    use_all: bool = false,
    use_theme: ?[]u8 = null,
    use_resolution_match: bool = false,

    fn deinit(self: *Hints, allocator: std.mem.Allocator) void {
        if (self.use_theme) |value| allocator.free(value);
        self.* = .{};
    }
};

pub fn runSlideshow(allocator: std.mem.Allocator, hypr_backend: *wm.HyprlandBackend, options: SlideshowOptions) !void {
    while (true) {
        try applyRandomWallpapers(allocator, hypr_backend, options.hyprpaper_config_path, options.wallpapers_root);
        if (options.run_once) return;
        std.Thread.sleep(options.interval_seconds * std.time.ns_per_s);
    }
}

pub fn setWallpaper(allocator: std.mem.Allocator, hypr_backend: *wm.HyprlandBackend, config_path: []const u8, image_path: []const u8, target: MonitorTarget) !void {
    var outputs = try hypr_backend.backend().listOutputs(allocator);
    defer outputs.deinit(allocator);

    const existing = readExistingAssignments(allocator, config_path) catch try allocator.alloc(Assignment, 0);
    defer deinitAssignments(allocator, existing);

    var selected = std.ArrayList(Assignment).empty;
    defer selected.deinit(allocator);

    switch (target) {
        .all => {
            for (outputs.items) |output| {
                try selected.append(allocator, .{
                    .monitor = try allocator.dupe(u8, output.name),
                    .path = try allocator.dupe(u8, image_path),
                });
            }
        },
        .focused => {
            const monitor_name = focusedOutputName(outputs.items) orelse return error.NoFocusedOutput;
            try selected.append(allocator, .{
                .monitor = try allocator.dupe(u8, monitor_name),
                .path = try allocator.dupe(u8, image_path),
            });
        },
        .named => |name| {
            try selected.append(allocator, .{
                .monitor = try allocator.dupe(u8, name),
                .path = try allocator.dupe(u8, image_path),
            });
        },
    }

    try writeHyprpaperConfig(allocator, config_path, .{
        .use_all = false,
        .use_theme = null,
        .use_resolution_match = false,
    }, existing, selected.items);
    try restartHyprpaper(allocator);
}

pub fn applyRandomWallpapers(allocator: std.mem.Allocator, hypr_backend: *wm.HyprlandBackend, config_path: []const u8, wallpapers_root: []const u8) !void {
    var hints = try readHints(allocator, config_path);
    defer hints.deinit(allocator);

    var outputs = try hypr_backend.backend().listOutputs(allocator);
    defer outputs.deinit(allocator);

    const existing = readExistingAssignments(allocator, config_path) catch try allocator.alloc(Assignment, 0);
    defer deinitAssignments(allocator, existing);

    const source_dir = try resolveCandidateDir(allocator, wallpapers_root, hints);
    defer allocator.free(source_dir);

    const candidates = try collectWallpapers(allocator, if (hints.use_all) wallpapers_root else source_dir);
    defer freeStringSlice(allocator, candidates);
    if (candidates.len == 0) return error.NoWallpapersFound;

    var selected = std.ArrayList(Assignment).empty;
    defer {
        for (selected.items) |*item| item.deinit(allocator);
        selected.deinit(allocator);
    }

    var size_cache = try loadSizeCache(allocator);
    defer size_cache.deinit(allocator);

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    for (outputs.items) |output| {
        const picked = if (hints.use_resolution_match)
            try pickMatchingWallpaper(allocator, candidates, output.width, output.height, &size_cache, random)
        else
            try allocator.dupe(u8, candidates[random.uintLessThan(usize, candidates.len)]);
        errdefer allocator.free(picked);
        try selected.append(allocator, .{
            .monitor = try allocator.dupe(u8, output.name),
            .path = picked,
        });
    }

    try persistSizeCache(allocator, &size_cache);
    try writeHyprpaperConfig(allocator, config_path, hints, existing, selected.items);
    try restartHyprpaper(allocator);
}

const Assignment = struct {
    monitor: []u8,
    path: []u8,

    fn deinit(self: *Assignment, allocator: std.mem.Allocator) void {
        allocator.free(self.monitor);
        allocator.free(self.path);
    }
};

fn focusedOutputName(outputs: []const wm.OutputInfo) ?[]const u8 {
    for (outputs) |output| {
        if (output.focused) return output.name;
    }
    if (outputs.len > 0) return outputs[0].name;
    return null;
}

fn readHints(allocator: std.mem.Allocator, config_path: []const u8) !Hints {
    const contents = std.fs.cwd().readFileAlloc(allocator, config_path, 1024 * 1024) catch return .{};
    defer allocator.free(contents);

    var hints = Hints{};
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "use_all")) {
            hints.use_all = parseBoolValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "use_resolution_match")) {
            hints.use_resolution_match = parseBoolValue(trimmed);
        } else if (std.mem.startsWith(u8, trimmed, "use_theme")) {
            const idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            const raw = std.mem.trim(u8, trimmed[idx + 1 ..], " \t\r");
            if (raw.len == 0) continue;
            hints.use_theme = try allocator.dupe(u8, raw);
        }
    }
    return hints;
}

fn parseBoolValue(line: []const u8) bool {
    const idx = std.mem.indexOfScalar(u8, line, '=') orelse return false;
    const raw = std.mem.trim(u8, line[idx + 1 ..], " \t\r");
    return std.mem.eql(u8, raw, "true") or std.mem.eql(u8, raw, "1");
}

fn resolveCandidateDir(allocator: std.mem.Allocator, wallpapers_root: []const u8, hints: Hints) ![]u8 {
    if (!hints.use_all) {
        if (hints.use_theme) |theme| {
            const themed = try std.fs.path.join(allocator, &.{ wallpapers_root, theme });
            if (pathExists(themed)) return themed;
            allocator.free(themed);

            if (theme_registry.familyForThemeName(theme)) |family| {
                const family_dir = try std.fs.path.join(allocator, &.{ wallpapers_root, family });
                if (pathExists(family_dir)) return family_dir;
                allocator.free(family_dir);
            }
        }
    }
    return allocator.dupe(u8, wallpapers_root);
}

fn collectWallpapers(allocator: std.mem.Allocator, root: []const u8) ![][]u8 {
    var dir = try std.fs.cwd().openDir(root, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var out = std.ArrayList([]u8).empty;
    errdefer {
        for (out.items) |item| allocator.free(item);
        out.deinit(allocator);
    }

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!isImage(entry.path)) continue;
        const full = try std.fs.path.join(allocator, &.{ root, entry.path });
        try out.append(allocator, full);
    }
    return out.toOwnedSlice(allocator);
}

fn isImage(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.ascii.eqlIgnoreCase(ext, ".png") or
        std.ascii.eqlIgnoreCase(ext, ".jpg") or
        std.ascii.eqlIgnoreCase(ext, ".jpeg") or
        std.ascii.eqlIgnoreCase(ext, ".webp");
}

const SizeEntry = struct {
    mtime: i128,
    width: i32,
    height: i32,
};

const SizeCache = struct {
    map: std.StringHashMapUnmanaged(SizeEntry) = .{},

    fn deinit(self: *SizeCache, allocator: std.mem.Allocator) void {
        var it = self.map.iterator();
        while (it.next()) |entry| allocator.free(entry.key_ptr.*);
        self.map.deinit(allocator);
    }
};

fn loadSizeCache(allocator: std.mem.Allocator) !SizeCache {
    var cache = SizeCache{};
    const path = try cachePath(allocator);
    defer allocator.free(path);
    const contents = std.fs.cwd().readFileAlloc(allocator, path, 8 * 1024 * 1024) catch return cache;
    defer allocator.free(contents);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var cols = std.mem.splitScalar(u8, line, '\t');
        const path_col = cols.next() orelse continue;
        const mtime_col = cols.next() orelse continue;
        const width_col = cols.next() orelse continue;
        const height_col = cols.next() orelse continue;
        try cache.map.put(allocator, try allocator.dupe(u8, path_col), .{
            .mtime = std.fmt.parseInt(i128, mtime_col, 10) catch 0,
            .width = std.fmt.parseInt(i32, width_col, 10) catch 0,
            .height = std.fmt.parseInt(i32, height_col, 10) catch 0,
        });
    }
    return cache;
}

fn persistSizeCache(allocator: std.mem.Allocator, cache: *SizeCache) !void {
    const path = try cachePath(allocator);
    defer allocator.free(path);
    if (std.fs.path.dirname(path)) |dir| try std.fs.cwd().makePath(dir);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    var it = cache.map.iterator();
    while (it.next()) |entry| {
        try std.fmt.format(out.writer(allocator), "{s}\t{d}\t{d}\t{d}\n", .{
            entry.key_ptr.*,
            entry.value_ptr.mtime,
            entry.value_ptr.width,
            entry.value_ptr.height,
        });
    }
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.items });
}

fn cachePath(allocator: std.mem.Allocator) ![]u8 {
    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".cache", "wayspot-wallpaper-sizes.tsv" });
}

fn pickMatchingWallpaper(allocator: std.mem.Allocator, candidates: [][]u8, width: i32, height: i32, cache: *SizeCache, random: std.Random) ![]u8 {
    var matches = std.ArrayList([]const u8).empty;
    defer matches.deinit(allocator);
    for (candidates) |candidate| {
        const size = try imageSize(allocator, candidate, cache);
        if (size.width == width and size.height == height) {
            try matches.append(allocator, candidate);
        }
    }
    if (matches.items.len == 0) return allocator.dupe(u8, candidates[random.uintLessThan(usize, candidates.len)]);
    return allocator.dupe(u8, matches.items[random.uintLessThan(usize, matches.items.len)]);
}

fn imageSize(allocator: std.mem.Allocator, path: []const u8, cache: *SizeCache) !SizeEntry {
    const stat = try std.fs.cwd().statFile(path);
    if (cache.map.get(path)) |cached| {
        if (cached.mtime == stat.mtime) return cached;
    }

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "magick", "identify", "-format", "%w %h", path },
        .max_output_bytes = 4096,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.term != .Exited or result.term.Exited != 0) return error.ImageSizeFailed;

    var parts = std.mem.splitScalar(u8, std.mem.trim(u8, result.stdout, " \t\r\n"), ' ');
    const width = try std.fmt.parseInt(i32, parts.next() orelse return error.ImageSizeFailed, 10);
    const height = try std.fmt.parseInt(i32, parts.next() orelse return error.ImageSizeFailed, 10);
    const entry = SizeEntry{ .mtime = stat.mtime, .width = width, .height = height };
    if (!cache.map.contains(path)) {
        try cache.map.put(allocator, try allocator.dupe(u8, path), entry);
    } else {
        cache.map.getPtr(path).?.* = entry;
    }
    return entry;
}

fn readExistingAssignments(allocator: std.mem.Allocator, config_path: []const u8) ![]Assignment {
    const contents = std.fs.cwd().readFileAlloc(allocator, config_path, 1024 * 1024) catch return allocator.alloc(Assignment, 0);
    defer allocator.free(contents);

    var out = std.ArrayList(Assignment).empty;
    errdefer {
        for (out.items) |*item| item.deinit(allocator);
        out.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, contents, '\n');
    var in_block = false;
    var monitor: ?[]u8 = null;
    var path: ?[]u8 = null;
    defer {
        if (monitor) |value| allocator.free(value);
        if (path) |value| allocator.free(value);
    }

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.eql(u8, trimmed, "wallpaper {")) {
            in_block = true;
            continue;
        }
        if (!in_block) continue;
        if (std.mem.eql(u8, trimmed, "}")) {
            if (monitor != null and path != null) {
                try out.append(allocator, .{ .monitor = monitor.?, .path = path.? });
                monitor = null;
                path = null;
            }
            in_block = false;
            continue;
        }
        if (std.mem.startsWith(u8, trimmed, "monitor")) {
            const idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            monitor = try allocator.dupe(u8, std.mem.trim(u8, trimmed[idx + 1 ..], " \t\r"));
        } else if (std.mem.startsWith(u8, trimmed, "path")) {
            const idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            path = try allocator.dupe(u8, std.mem.trim(u8, trimmed[idx + 1 ..], " \t\r"));
        }
    }

    return out.toOwnedSlice(allocator);
}

fn deinitAssignments(allocator: std.mem.Allocator, items: []Assignment) void {
    for (items) |*item| item.deinit(allocator);
    allocator.free(items);
}

fn writeHyprpaperConfig(allocator: std.mem.Allocator, config_path: []const u8, hints: Hints, existing: []const Assignment, replacements: []const Assignment) !void {
    var final_items = std.ArrayList(Assignment).empty;
    defer {
        for (final_items.items) |*item| item.deinit(allocator);
        final_items.deinit(allocator);
    }

    for (replacements) |item| {
        try final_items.append(allocator, .{
            .monitor = try allocator.dupe(u8, item.monitor),
            .path = try allocator.dupe(u8, item.path),
        });
    }

    outer: for (existing) |item| {
        for (replacements) |replacement| {
            if (std.mem.eql(u8, item.monitor, replacement.monitor)) continue :outer;
        }
        try final_items.append(allocator, .{
            .monitor = try allocator.dupe(u8, item.monitor),
            .path = try allocator.dupe(u8, item.path),
        });
    }

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "splash = false\nipc = true\n");
    try std.fmt.format(out.writer(allocator), "use_all = {s}\n", .{if (hints.use_all) "true" else "false"});
    if (hints.use_theme) |theme| {
        try std.fmt.format(out.writer(allocator), "use_theme = {s}\n", .{theme});
    }
    try std.fmt.format(out.writer(allocator), "use_resolution_match = {s}\n\n", .{if (hints.use_resolution_match) "true" else "false"});

    for (final_items.items) |item| {
        try std.fmt.format(out.writer(allocator),
            "wallpaper {{\n  monitor = {s}\n  path = {s}\n  fit_mode = cover\n}}\n\n",
            .{ item.monitor, item.path });
    }

    if (std.fs.path.dirname(config_path)) |dir| try std.fs.cwd().makePath(dir);
    try std.fs.cwd().writeFile(.{ .sub_path = config_path, .data = out.items });
}

fn restartHyprpaper(allocator: std.mem.Allocator) !void {
    const kill_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "sh", "-lc", "pkill -x hyprpaper >/dev/null 2>&1 || true" },
    });
    allocator.free(kill_result.stdout);
    allocator.free(kill_result.stderr);

    var child = std.process.Child.init(&.{ "hyprpaper" }, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = try child.spawn();
}

fn freeStringSlice(allocator: std.mem.Allocator, items: [][]u8) void {
    for (items) |item| allocator.free(item);
    allocator.free(items);
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
