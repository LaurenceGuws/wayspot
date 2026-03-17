const std = @import("std");
const theme_registry = @import("theme_registry.zig");

pub const Mode = enum {
    copy,
    move,
};

pub const Options = struct {
    source_dir: []const u8,
    dest_dir: []const u8,
    dry_run: bool = false,
    mode: Mode = .copy,
    verbose: bool = false,
};

const Rgb = theme_registry.Rgb;
const Classification = struct {
    source_path: []u8,
    matches: MatchList,
    err_name: ?[]const u8 = null,
};

pub fn run(allocator: std.mem.Allocator, options: Options) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var source_dir = try std.fs.cwd().openDir(options.source_dir, .{ .iterate = true });
    defer source_dir.close();

    try ensureThemeDirs(options.dest_dir);

    var walker = try source_dir.walk(allocator);
    defer walker.deinit();

    var source_paths = std.ArrayList([]u8).empty;
    defer {
        for (source_paths.items) |path| allocator.free(path);
        source_paths.deinit(allocator);
    }

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!isSupportedImage(entry.path)) continue;
        if (isInsideThemeDir(entry.path)) continue;

        const source_path = try std.fs.path.join(allocator, &.{ options.source_dir, entry.path });
        try source_paths.append(allocator, source_path);
    }

    const classifications = try classifyMany(allocator, source_paths.items);
    defer {
        for (classifications) |item| allocator.free(item.source_path);
        allocator.free(classifications);
    }

    for (classifications) |classification| {
        if (classification.err_name) |err_name| {
            try stdout.print("skip {s}: {s}\n", .{ classification.source_path, err_name });
            continue;
        }
        if (classification.matches.len == 0) continue;

        const basename = std.fs.path.basename(classification.source_path);
        try stdout.print("{s}", .{classification.source_path});
        for (0..classification.matches.len) |idx| {
            try stdout.print("{s}{s} ({d:.2})", .{
                if (idx == 0) " -> " else ", ",
                classification.matches.names[idx],
                classification.matches.scores[idx],
            });
        }
        try stdout.print("\n", .{});

        for (0..classification.matches.len) |idx| {
            const theme_dir = try std.fs.path.join(allocator, &.{ options.dest_dir, classification.matches.names[idx] });
            defer allocator.free(theme_dir);
            const target_path = try std.fs.path.join(allocator, &.{ theme_dir, basename });
            defer allocator.free(target_path);

            if (options.verbose) {
                try stdout.print("  target[{s}]: {s}\n", .{ classification.matches.names[idx], target_path });
            }

            if (!options.dry_run) {
                try copyFile(classification.source_path, target_path);
            }
        }

        if (!options.dry_run and options.mode == .move) {
            try std.fs.deleteFileAbsolute(classification.source_path);
        }
    }
    try stdout.flush();
}

fn classifyMany(allocator: std.mem.Allocator, source_paths: []const []u8) ![]Classification {
    const out = try allocator.alloc(Classification, source_paths.len);
    errdefer allocator.free(out);

    const worker_count = @min(source_paths.len, effectiveWorkerCount());
    if (worker_count <= 1) {
        for (source_paths, 0..) |source_path, idx| {
            out[idx] = try classifyOne(allocator, source_path);
        }
        return out;
    }

    var next_index = std.atomic.Value(usize).init(0);
    const threads = try allocator.alloc(std.Thread, worker_count);
    defer allocator.free(threads);

    const Context = struct {
        allocator: std.mem.Allocator,
        source_paths: []const []u8,
        out: []Classification,
        next_index: *std.atomic.Value(usize),
    };

    var ctx = Context{
        .allocator = allocator,
        .source_paths = source_paths,
        .out = out,
        .next_index = &next_index,
    };

    for (threads, 0..) |*thread, idx| {
        _ = idx;
        thread.* = try std.Thread.spawn(.{}, struct {
            fn run(context: *Context) void {
                while (true) {
                    const index = context.next_index.fetchAdd(1, .monotonic);
                    if (index >= context.source_paths.len) return;
                    context.out[index] = classifyOne(context.allocator, context.source_paths[index]) catch blk: {
                        break :blk .{
                            .source_path = context.allocator.dupe(u8, context.source_paths[index]) catch context.allocator.alloc(u8, 0) catch unreachable,
                            .matches = .{},
                            .err_name = "ClassificationFailed",
                        };
                    };
                }
            }
        }.run, .{&ctx});
    }

    for (threads) |thread| thread.join();
    return out;
}

fn classifyOne(allocator: std.mem.Allocator, source_path: []const u8) !Classification {
    const kept_path = try allocator.dupe(u8, source_path);
    errdefer allocator.free(kept_path);

    const palette = sampleImageColors(allocator, source_path) catch |err| {
        return .{ .source_path = kept_path, .matches = .{}, .err_name = @errorName(err) };
    };
    defer allocator.free(palette);

    const matches = try classifyPixelsMulti(allocator, palette, source_path);
    return .{ .source_path = kept_path, .matches = matches };
}

fn effectiveWorkerCount() usize {
    return @max(@as(usize, 1), std.Thread.getCpuCount() catch 4);
}

pub fn printUsage() !void {
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\Usage: wayspot --sort-wallpapers [--source DIR] [--dest DIR] [--dry-run] [--move] [--verbose]
        \\Defaults:
        \\  --source ~/Pictures/wallpapers
        \\  --dest   ~/Pictures/wallpapers
        \\
        \\Behavior:
        \\  Scans wallpapers, samples colors with ImageMagick, and sorts them into:
        \\    ayu/
        \\    nordic/
        \\
        \\Notes:
        \\  Files already under ayu/ or nordic/ are skipped.
        \\  Default mode is copy; use --move to relocate files.
        \\
    , .{});
    try stdout.flush();
}

fn isSupportedImage(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.ascii.eqlIgnoreCase(ext, ".png") or
        std.ascii.eqlIgnoreCase(ext, ".jpg") or
        std.ascii.eqlIgnoreCase(ext, ".jpeg") or
        std.ascii.eqlIgnoreCase(ext, ".webp");
}

fn isInsideThemeDir(relative_path: []const u8) bool {
    const slash_idx = std.mem.indexOfScalar(u8, relative_path, '/') orelse return false;
    const first_segment = relative_path[0..slash_idx];
    inline for (theme_registry.families) |family| {
        if (std.mem.eql(u8, first_segment, family.name)) return true;
    }
    return false;
}

fn ensureThemeDirs(dest_dir: []const u8) !void {
    try std.fs.cwd().makePath(dest_dir);
    inline for (theme_registry.families) |family| {
        const family_dir = try std.fs.path.join(std.heap.page_allocator, &.{ dest_dir, family.name });
        defer std.heap.page_allocator.free(family_dir);
        try std.fs.cwd().makePath(family_dir);
    }
}

fn sampleImageColors(allocator: std.mem.Allocator, image_path: []const u8) ![]Rgb {
    const argv = [_][]const u8{
        "magick",
        image_path,
        "-alpha",
        "off",
        "-resize",
        "16x16!",
        "-colorspace",
        "sRGB",
        "txt:-",
    };

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
        .max_output_bytes = 256 * 1024,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) return error.MagickFailed;
    return parseMagickText(allocator, result.stdout);
}

fn parseMagickText(allocator: std.mem.Allocator, text: []const u8) ![]Rgb {
    var pixels = std.ArrayList(Rgb).empty;
    errdefer pixels.deinit(allocator);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const coord_end = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        if (coord_end == 0) continue;
        const open_paren = std.mem.indexOfScalar(u8, line, '(') orelse continue;
        const close_paren = std.mem.indexOfScalarPos(u8, line, open_paren, ')') orelse continue;
        if (close_paren <= open_paren + 1) continue;

        const tuple = line[open_paren + 1 .. close_paren];
        var parts = std.mem.splitScalar(u8, tuple, ',');
        const r_txt = parts.next() orelse continue;
        const g_txt = parts.next() orelse continue;
        const b_txt = parts.next() orelse continue;

        const r = try std.fmt.parseFloat(f64, std.mem.trim(u8, r_txt, " "));
        const g = try std.fmt.parseFloat(f64, std.mem.trim(u8, g_txt, " "));
        const b = try std.fmt.parseFloat(f64, std.mem.trim(u8, b_txt, " "));
        try pixels.append(allocator, .{ .r = r, .g = g, .b = b });
    }

    if (pixels.items.len == 0) return error.NoPixelsParsed;
    return pixels.toOwnedSlice(allocator);
}

const Match = struct {
    theme: []const u8,
    primary_score: f64,
    secondary_score: f64,
};

const MatchList = struct {
    names: [theme_registry.families.len][]const u8 = undefined,
    scores: [theme_registry.families.len]f64 = undefined,
    len: usize = 0,
};

fn classifyPixels(pixels: []const Rgb) Match {
    var best_index: usize = 0;
    var best_score: f64 = scoreThemePixels(theme_registry.families[0], pixels);
    var next_best: f64 = -std.math.inf(f64);

    var i: usize = 1;
    while (i < theme_registry.families.len) : (i += 1) {
        const score = scoreThemePixels(theme_registry.families[i], pixels);
        if (score > best_score) {
            next_best = best_score;
            best_score = score;
            best_index = i;
        } else if (score > next_best) {
            next_best = score;
        }
    }

    return .{
        .theme = theme_registry.families[best_index].name,
        .primary_score = best_score,
        .secondary_score = next_best,
    };
}

fn classifyPixelsMulti(allocator: std.mem.Allocator, pixels: []const Rgb, source_path: []const u8) !MatchList {
    const lowered_path = try std.ascii.allocLowerString(allocator, std.fs.path.basename(source_path));
    defer allocator.free(lowered_path);

    var scored: [theme_registry.families.len]Match = undefined;
    for (theme_registry.families, 0..) |theme, idx| {
        const score = scoreThemePixels(theme, pixels) + filenameBias(theme, lowered_path);
        scored[idx] = .{
            .theme = theme.name,
            .primary_score = @min(score, 1.0),
            .secondary_score = 0,
        };
    }

    std.mem.sort(Match, scored[0..], {}, struct {
        fn lessThan(_: void, a: Match, b: Match) bool {
            return a.primary_score > b.primary_score;
        }
    }.lessThan);

    var out = MatchList{};
    const best = scored[0].primary_score;
    if (best < 0.30) return out;

    const inclusion_margin = 0.025;
    const minimum_gap = 0.04;
    const max_matches = 3;
    for (scored) |item| {
        if (best - item.primary_score > inclusion_margin) continue;
        if (out.len > 0 and best - item.primary_score >= minimum_gap) continue;
        out.names[out.len] = item.theme;
        out.scores[out.len] = item.primary_score;
        out.len += 1;
        if (out.len >= max_matches) break;
    }
    return out;
}

fn scoreThemePixels(theme: theme_registry.Family, pixels: []const Rgb) f64 {
    var background_total: f64 = 0;
    var accent_total: f64 = 0;
    var neutral_count: usize = 0;
    var accent_count: usize = 0;

    for (pixels) |px| {
        const sat = saturation01(px);
        const lum = luminance01(px);
        if (sat < 0.18 or lum < 0.22) {
            background_total += nearestAnchorScore(theme.anchors[0..3], px, 38.0);
            neutral_count += 1;
        } else {
            accent_total += nearestAnchorScore(theme.anchors[3..], px, 26.0);
            accent_count += 1;
        }
    }

    const background_score = if (neutral_count > 0)
        background_total / @as(f64, @floatFromInt(neutral_count))
    else
        0.0;
    const accent_score = if (accent_count > 0)
        accent_total / @as(f64, @floatFromInt(accent_count))
    else
        0.0;
    const accent_presence = @as(f64, @floatFromInt(accent_count)) / @as(f64, @floatFromInt(pixels.len));

    if (accent_count == 0) {
        return background_score * 0.85;
    }

    return background_score * 0.45 +
        accent_score * 0.45 +
        @min(accent_presence * 0.35, 0.10);
}

fn nearestAnchorScore(anchors: []const Rgb, pixel: Rgb, spread: f64) f64 {
    var best_distance = distance(pixel, anchors[0]);
    for (anchors[1..]) |anchor| {
        const dist = distance(pixel, anchor);
        if (dist < best_distance) best_distance = dist;
    }
    return std.math.exp(-(best_distance / spread));
}

fn distance(a: Rgb, b: Rgb) f64 {
    const dr = a.r - b.r;
    const dg = a.g - b.g;
    const db = a.b - b.b;
    return std.math.sqrt(dr * dr + dg * dg + db * db);
}

fn luminance01(pixel: Rgb) f64 {
    return (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) / 255.0;
}

fn saturation01(pixel: Rgb) f64 {
    const max_v = @max(pixel.r, @max(pixel.g, pixel.b));
    const min_v = @min(pixel.r, @min(pixel.g, pixel.b));
    if (max_v <= 0.0) return 0.0;
    return (max_v - min_v) / max_v;
}

fn filenameBias(theme: theme_registry.Family, lowered_path: []const u8) f64 {
    var best: f64 = 0.0;
    if (std.mem.indexOf(u8, lowered_path, theme.name) != null) {
        best = 0.18;
    }
    for (theme.aliases) |alias| {
        if (alias.len < 4) continue;
        if (std.mem.indexOf(u8, lowered_path, alias) != null) {
            best = @max(best, 0.16);
        }
    }
    return best;
}

fn copyFile(source_path: []const u8, target_path: []const u8) !void {
    try std.fs.cwd().makePath(std.fs.path.dirname(target_path) orelse ".");
    try std.fs.copyFileAbsolute(source_path, target_path, .{});
}

test "classify ayu-like pixels as ayu" {
    const pixels = [_]Rgb{
        .{ .r = 0xff, .g = 0xb4, .b = 0x54 },
        .{ .r = 0xff, .g = 0xd1, .b = 0x73 },
        .{ .r = 0x39, .g = 0xba, .b = 0xe6 },
    };
    const match = classifyPixels(&pixels);
    try std.testing.expectEqualStrings("ayu", match.theme);
}

test "classify nordic-like pixels as nordic" {
    const pixels = [_]Rgb{
        .{ .r = 0x88, .g = 0xc0, .b = 0xd0 },
        .{ .r = 0x81, .g = 0xa1, .b = 0xc1 },
        .{ .r = 0x2e, .g = 0x34, .b = 0x40 },
    };
    const match = classifyPixels(&pixels);
    try std.testing.expectEqualStrings("nordic", match.theme);
}

test "multi-classify includes all close matches" {
    const pixels = [_]Rgb{
        .{ .r = 0x88, .g = 0xc0, .b = 0xd0 },
        .{ .r = 0xff, .g = 0xd1, .b = 0x73 },
        .{ .r = 0x2e, .g = 0x34, .b = 0x40 },
    };
    const matches = try classifyPixelsMulti(std.testing.allocator, &pixels, "/tmp/nord_triangles.png");
    try std.testing.expect(matches.len >= 1);
}
