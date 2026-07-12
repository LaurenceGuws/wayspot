//! AppIconCacheRefresh owns manual SVG-to-PNG app icon cache generation.

const std = @import("std");
const candidate_mod = @import("picker_candidate");
const app_icons = @import("icons.zig");

pub const cache_relative_dir = ".cache/wayspot/icons";
pub const index_relative_path = ".cache/wayspot/icons/index.tsv";
pub const converted_icon_px: u32 = 64;

const max_refresh_rows: u32 = 768;
const max_svg_file_bytes: u64 = 2 * 1024 * 1024;
const max_converter_path_bytes = app_icons.max_icon_path_bytes;
const max_path_entries: u32 = 64;
const max_path_entry_bytes = 512;
const max_command_name_bytes = 128;
const converter_fail_code: i32 = 127;
const max_wait_interrupts: u32 = 8;

const svg_sizes = [_][]const u8{ "scalable", "symbolic" };

pub const RefreshCounts = struct {
    app_rows: u32 = 0,
    already_raster: u32 = 0,
    converted: u32 = 0,
    missing_svg: u32 = 0,
    unsupported: u32 = 0,
    failed: u32 = 0,
    skipped: u32 = 0,
};

pub fn refresh(home: []const u8, candidates: []const candidate_mod.Candidate) !RefreshCounts {
    var converter_path_buffer: [max_converter_path_bytes + 1]u8 = undefined;
    const converter_path = commandPath("rsvg-convert", &converter_path_buffer) orelse {
        std.log.err("rsvg-convert not found in PATH", .{});
        return error.RsvgConvertMissing;
    };

    try ensureCacheDir(home);
    var index_path_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    const index_path = cacheIndexPath(home, &index_path_buffer) orelse return error.IconCachePathTooLong;
    var index_file = try std.Io.Dir.cwd().createFile(std.Options.debug_io, index_path, .{ .truncate = true });
    defer index_file.close(std.Options.debug_io);

    var writer_buffer: [8192]u8 = undefined;
    var writer = index_file.writer(std.Options.debug_io, &writer_buffer);
    const out = &writer.interface;

    var counts = RefreshCounts{};
    const roots = app_icons.ResolveRoots.fromEnv();
    var raster_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    var svg_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    var png_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;

    for (candidates) |candidate| {
        if (candidate.typeOf() != .app) continue;
        counts.app_rows += 1;
        if (counts.app_rows > max_refresh_rows) {
            counts.skipped += 1;
            continue;
        }
        if (candidate.iconName().len == 0) {
            counts.missing_svg += 1;
            continue;
        }
        if (app_icons.resolveRasterIconPath(candidate.iconName(), roots, &raster_buffer) != null) {
            counts.already_raster += 1;
            continue;
        }

        const svg_path = resolveSvgSource(candidate.iconName(), roots, &svg_buffer) orelse {
            if (hasSvgIntent(candidate.iconName())) {
                counts.failed += 1;
            } else if (hasKnownUnsupportedExtension(candidate.iconName())) {
                counts.unsupported += 1;
            } else {
                counts.missing_svg += 1;
            }
            continue;
        };
        const png_path = convertedPngPath(home, candidate.iconName(), &png_buffer) orelse {
            counts.failed += 1;
            continue;
        };
        if (runConverter(converter_path, svg_path, png_path)) {
            try out.print("{s}\t{s}\t{s}\n", .{ candidate.iconName(), png_path, svg_path });
            counts.converted += 1;
        } else {
            counts.failed += 1;
        }
    }

    try out.flush();
    try index_file.sync(std.Options.debug_io);
    return counts;
}

pub fn printRefreshSummary(counts: RefreshCounts) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try stdout_writer.interface.print(
        "icon cache refresh: app_rows={d} converted={d} already_raster={d} missing_svg={d} unsupported={d} failed={d} skipped={d}\n",
        .{ counts.app_rows, counts.converted, counts.already_raster, counts.missing_svg, counts.unsupported, counts.failed, counts.skipped },
    );
    try stdout_writer.interface.flush();
}

fn resolveSvgSource(icon_name: []const u8, roots: app_icons.ResolveRoots, out: []u8) ?[:0]const u8 {
    if (icon_name.len == 0 or icon_name.len > app_icons.max_icon_name_bytes) return null;
    if (std.fs.path.isAbsolute(icon_name)) {
        if (!endsWithIgnoreCase(icon_name, ".svg")) return null;
        if (!svgFileAccepted(icon_name)) return null;
        return copyPathZ(out, icon_name);
    }
    if (std.mem.indexOfScalar(u8, icon_name, '/') != null) return null;
    if (endsWithIgnoreCase(icon_name, "-symbolic")) return null;
    if (hasKnownUnsupportedExtension(icon_name) and !endsWithIgnoreCase(icon_name, ".svg")) return null;

    const base_name = iconBaseName(icon_name);
    if (base_name.len == 0) return null;

    var probes: u32 = 0;
    if (roots.xdg_data_home) |data_home| {
        if (resolveSvgFromDataRoot(data_home, base_name, out, &probes)) |path| return path;
    } else if (roots.home) |home| {
        var data_home_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
        const data_home = std.fmt.bufPrintZ(&data_home_buffer, "{s}/.local/share", .{home}) catch return null;
        if (resolveSvgFromDataRoot(data_home, base_name, out, &probes)) |path| return path;
    }

    const data_dirs = roots.xdg_data_dirs orelse "/usr/local/share:/usr/share";
    var root_count: u32 = 0;
    var split = std.mem.splitScalar(u8, data_dirs, ':');
    while (split.next()) |data_root| {
        if (data_root.len == 0) continue;
        root_count += 1;
        if (root_count > app_icons.max_icon_roots) break;
        if (resolveSvgFromDataRoot(data_root, base_name, out, &probes)) |path| return path;
    }
    return null;
}

fn resolveSvgFromDataRoot(data_root: []const u8, base_name: []const u8, out: []u8, probes: *u32) ?[:0]const u8 {
    for (svg_sizes) |size| {
        if (probeSvg(out, probes, data_root, size, base_name)) |path| return path;
    }
    if (probePixmapsSvg(out, probes, data_root, base_name)) |path| return path;
    return null;
}

fn probeSvg(out: []u8, probes: *u32, data_root: []const u8, size: []const u8, base_name: []const u8) ?[:0]const u8 {
    if (probes.* >= app_icons.max_icon_probes) return null;
    probes.* += 1;
    const path = std.fmt.bufPrintZ(out, "{s}/icons/hicolor/{s}/apps/{s}.svg", .{ data_root, size, base_name }) catch return null;
    if (!svgFileAccepted(path)) return null;
    return path;
}

fn probePixmapsSvg(out: []u8, probes: *u32, data_root: []const u8, base_name: []const u8) ?[:0]const u8 {
    if (probes.* >= app_icons.max_icon_probes) return null;
    probes.* += 1;
    const path = std.fmt.bufPrintZ(out, "{s}/pixmaps/{s}.svg", .{ data_root, base_name }) catch return null;
    if (!svgFileAccepted(path)) return null;
    return path;
}

fn convertedPngPath(home: []const u8, icon_name: []const u8, out: []u8) ?[:0]const u8 {
    const hash = std.hash.Crc32.hash(icon_name);
    return std.fmt.bufPrintZ(out, "{s}/{s}/icon-{d}.png", .{ home, cache_relative_dir, hash }) catch null;
}

fn cacheIndexPath(home: []const u8, out: []u8) ?[:0]const u8 {
    return std.fmt.bufPrintZ(out, "{s}/{s}", .{ home, index_relative_path }) catch null;
}

fn ensureCacheDir(home: []const u8) !void {
    var path_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buffer, "{s}/{s}", .{ home, cache_relative_dir }) catch return error.IconCachePathTooLong;
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, path);
}

fn runConverter(converter_path: [:0]const u8, svg_path: [:0]const u8, png_path: [:0]const u8) bool {
    const width = "64";
    const height = "64";
    const pid = std.c.fork();
    if (pid == -1) return false;
    if (pid == 0) {
        const argv: [11:null]?[*:0]const u8 = .{
            converter_path.ptr,
            "-w",
            width,
            "-h",
            height,
            "-f",
            "png",
            "-o",
            png_path.ptr,
            svg_path.ptr,
            null,
        };
        const exec_rc = std.c.execve(converter_path.ptr, &argv, std.c.environ);
        if (exec_rc == -1) std.c._exit(converter_fail_code);
        std.c._exit(converter_fail_code);
    }

    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_wait_interrupts) {
        const waited = std.c.waitpid(pid, &status, 0);
        if (waited == pid) break;
        if (waited == -1 and std.c._errno().* == @intFromEnum(std.c.E.INTR)) {
            interrupts += 1;
            continue;
        }
        return false;
    } else {
        return false;
    }
    const status_bits: u32 = @bitCast(status);
    return std.c.W.IFEXITED(status_bits) and std.c.W.EXITSTATUS(status_bits) == 0;
}

fn commandPath(name: []const u8, out: []u8) ?[:0]const u8 {
    if (name.len == 0 or name.len > max_command_name_bytes) return null;
    if (std.mem.indexOfScalar(u8, name, '/') != null) return null;
    const path_value = if (std.c.getenv("PATH")) |value| std.mem.span(value) else return null;
    var entries = std.mem.splitScalar(u8, path_value, ':');
    var entry_count: u32 = 0;
    while (entries.next()) |entry| {
        if (entry.len == 0) continue;
        if (entry.len > max_path_entry_bytes) return null;
        if (entry_count >= max_path_entries) return null;
        entry_count += 1;
        if (pathEntryContainsCommand(entry, name, out)) |path| return path;
    }
    return null;
}

fn pathEntryContainsCommand(entry: []const u8, name: []const u8, out: []u8) ?[:0]const u8 {
    if (entry.len + 1 + name.len > max_converter_path_bytes or out.len <= entry.len + 1 + name.len) return null;
    @memcpy(out[0..entry.len], entry);
    out[entry.len] = '/';
    @memcpy(out[entry.len + 1 .. entry.len + 1 + name.len], name);
    const len = entry.len + 1 + name.len;
    out[len] = 0;
    const path = out[0..len :0];
    const rc = std.c.access(path.ptr, std.c.X_OK);
    return if (rc == 0) path else null;
}

test "command path rejects invalid command names" {
    var path_buffer: [max_converter_path_bytes + 1]u8 = undefined;
    try std.testing.expect(commandPath("", &path_buffer) == null);
    try std.testing.expect(commandPath("bin/rsvg-convert", &path_buffer) == null);
}

fn svgFileAccepted(path: []const u8) bool {
    if (path.len > max_converter_path_bytes) return false;
    const stat = std.Io.Dir.cwd().statFile(std.Options.debug_io, path, .{}) catch return false;
    return stat.size > 0 and stat.size <= max_svg_file_bytes;
}

fn iconBaseName(icon_name: []const u8) []const u8 {
    if (endsWithIgnoreCase(icon_name, ".svg")) return icon_name[0 .. icon_name.len - 4];
    return icon_name;
}

fn hasSvgIntent(icon_name: []const u8) bool {
    return endsWithIgnoreCase(icon_name, ".svg");
}

fn hasKnownUnsupportedExtension(icon_name: []const u8) bool {
    return endsWithIgnoreCase(icon_name, ".xpm") or
        endsWithIgnoreCase(icon_name, ".jpg") or
        endsWithIgnoreCase(icon_name, ".jpeg") or
        endsWithIgnoreCase(icon_name, ".webp") or
        endsWithIgnoreCase(icon_name, ".ico") or
        endsWithIgnoreCase(icon_name, ".gif") or
        endsWithIgnoreCase(icon_name, ".tif") or
        endsWithIgnoreCase(icon_name, ".tiff") or
        endsWithIgnoreCase(icon_name, ".avif");
}

fn copyPathZ(out: []u8, path: []const u8) ?[:0]const u8 {
    if (path.len > app_icons.max_icon_path_bytes or out.len <= path.len) return null;
    @memcpy(out[0..path.len], path);
    out[path.len] = 0;
    return out[0..path.len :0];
}

fn endsWithIgnoreCase(bytes: []const u8, suffix: []const u8) bool {
    if (bytes.len < suffix.len) return false;
    return std.ascii.eqlIgnoreCase(bytes[bytes.len - suffix.len ..], suffix);
}

test "converted png path is deterministic and bounded" {
    var buffer_a: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    var buffer_b: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    const first = convertedPngPath("/tmp/wayspot-home", "app.svg", &buffer_a) orelse return error.TestExpectedEqual;
    const second = convertedPngPath("/tmp/wayspot-home", "app.svg", &buffer_b) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(endsWithIgnoreCase(first, ".png"));
}
