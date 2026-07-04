//! AppIconStore owns bounded app-row icon resolution and SDL textures for one picker lifecycle.

const std = @import("std");

const c = @import("sdl_c");

pub const max_icon_entries = 128;
pub const max_icon_name_bytes = 192;
pub const max_icon_path_bytes = 768;
pub const max_icon_file_bytes: u64 = 2 * 1024 * 1024;
pub const max_icon_source_dimension: i32 = 512;
pub const max_icon_roots: u32 = 8;
pub const max_icon_probes: u32 = 96;

const default_data_dirs = "/usr/local/share:/usr/share";
const hicolor_sizes = [_][]const u8{ "48x48", "64x64", "32x32", "128x128", "256x256" };
const supported_extensions = [_][]const u8{ ".png", ".bmp" };
const unsupported_image_extensions = [_][]const u8{ ".svg", ".xpm", ".jpg", ".jpeg", ".webp", ".ico", ".gif", ".tif", ".tiff", ".avif" };

pub const ResolveRoots = struct {
    home: ?[]const u8 = null,
    xdg_data_home: ?[]const u8 = null,
    xdg_data_dirs: ?[]const u8 = null,

    fn fromEnv() ResolveRoots {
        return .{
            .home = envBytes("HOME"),
            .xdg_data_home = envBytes("XDG_DATA_HOME"),
            .xdg_data_dirs = envBytes("XDG_DATA_DIRS"),
        };
    }
};

const EntryState = enum {
    missing,
    loaded,
};

const Entry = struct {
    key: [max_icon_name_bytes]u8 = undefined,
    key_len: u32 = 0,
    state: EntryState = .missing,
    texture: [*c]c.SDL_Texture = null,

    fn keyBytes(entry: *const Entry) []const u8 {
        return entry.key[0..@intCast(entry.key_len)];
    }
};

pub const AppIconStore = struct {
    entries: [max_icon_entries]Entry = undefined,
    count: u32 = 0,

    pub fn init() AppIconStore {
        return .{};
    }

    pub fn deinit(store: *AppIconStore) void {
        var i: u32 = 0;
        while (i < store.count) : (i += 1) {
            const texture = store.entries[@intCast(i)].texture;
            if (texture != null) c.SDL_DestroyTexture(texture);
            store.entries[@intCast(i)].texture = null;
            store.entries[@intCast(i)].state = .missing;
        }
        store.count = 0;
    }

    pub fn textureFor(store: *AppIconStore, renderer: *c.SDL_Renderer, icon_name: []const u8) ?[*c]c.SDL_Texture {
        return store.textureForWithRoots(renderer, icon_name, ResolveRoots.fromEnv());
    }

    fn textureForWithRoots(store: *AppIconStore, renderer: *c.SDL_Renderer, icon_name: []const u8, roots: ResolveRoots) ?[*c]c.SDL_Texture {
        if (icon_name.len == 0 or icon_name.len > max_icon_name_bytes) return null;
        if (store.find(icon_name)) |entry| {
            return if (entry.state == .loaded) entry.texture else null;
        }

        const entry = store.reserve(icon_name) orelse return null;
        var path_buffer: [max_icon_path_bytes + 1]u8 = undefined;
        const path = resolveIconPath(icon_name, roots, &path_buffer) orelse return null;
        const surface = loadSurface(path);
        if (surface == null) return null;
        defer c.SDL_DestroySurface(surface);

        if (!surfaceDimensionsAccepted(surface)) return null;
        const texture = c.SDL_CreateTextureFromSurface(renderer, surface);
        if (texture == null) return null;

        entry.texture = texture;
        entry.state = .loaded;
        return texture;
    }

    fn find(store: *AppIconStore, icon_name: []const u8) ?*Entry {
        var i: u32 = 0;
        while (i < store.count) : (i += 1) {
            const entry = &store.entries[@intCast(i)];
            if (std.mem.eql(u8, entry.keyBytes(), icon_name)) return entry;
        }
        return null;
    }

    fn reserve(store: *AppIconStore, icon_name: []const u8) ?*Entry {
        if (icon_name.len == 0 or icon_name.len > max_icon_name_bytes) return null;
        if (store.count >= max_icon_entries) return null;
        const entry = &store.entries[@intCast(store.count)];
        @memcpy(entry.key[0..icon_name.len], icon_name);
        entry.key_len = @intCast(icon_name.len);
        entry.state = .missing;
        entry.texture = null;
        store.count += 1;
        return entry;
    }
};

pub fn resolveIconPathForTest(icon_name: []const u8, roots: ResolveRoots, out: []u8) ?[:0]const u8 {
    return resolveIconPath(icon_name, roots, out);
}

fn resolveIconPath(icon_name: []const u8, roots: ResolveRoots, out: []u8) ?[:0]const u8 {
    if (icon_name.len == 0 or icon_name.len > max_icon_name_bytes) return null;
    if (std.fs.path.isAbsolute(icon_name)) {
        if (!hasSupportedExtension(icon_name)) return null;
        if (!fileStatAccepted(icon_name)) return null;
        return copyPathZ(out, icon_name);
    }
    if (std.mem.indexOfScalar(u8, icon_name, '/') != null) return null;
    if (hasUnsupportedImageExtension(icon_name)) return null;

    const base_name = iconNameBase(icon_name) orelse return null;
    if (base_name.len == 0) return null;
    if (endsWithIgnoreCase(base_name, "-symbolic")) return null;

    var probes: u32 = 0;
    if (roots.xdg_data_home) |data_home| {
        if (resolveFromDataRoot(data_home, icon_name, base_name, out, &probes)) |path| return path;
    } else if (roots.home) |home| {
        if (resolveHomeDataRoot(home, icon_name, base_name, out, &probes)) |path| return path;
    }

    const data_dirs = roots.xdg_data_dirs orelse default_data_dirs;
    var root_count: u32 = 0;
    var split = std.mem.splitScalar(u8, data_dirs, ':');
    while (split.next()) |data_root| {
        if (data_root.len == 0) continue;
        root_count += 1;
        if (root_count > max_icon_roots) break;
        if (resolveFromDataRoot(data_root, icon_name, base_name, out, &probes)) |path| return path;
    }
    return null;
}

fn resolveHomeDataRoot(home: []const u8, icon_name: []const u8, base_name: []const u8, out: []u8, probes: *u32) ?[:0]const u8 {
    var root_buffer: [max_icon_path_bytes + 1]u8 = undefined;
    const data_root = std.fmt.bufPrintZ(&root_buffer, "{s}/.local/share", .{home}) catch return null;
    return resolveFromDataRoot(data_root, icon_name, base_name, out, probes);
}

fn resolveFromDataRoot(data_root: []const u8, icon_name: []const u8, base_name: []const u8, out: []u8, probes: *u32) ?[:0]const u8 {
    if (hasSupportedExtension(icon_name)) {
        if (resolveFromDataRootWithExtension(data_root, icon_name, "", out, probes)) |path| return path;
        return null;
    }

    for (supported_extensions) |extension| {
        if (resolveFromDataRootWithExtension(data_root, base_name, extension, out, probes)) |path| return path;
    }
    return null;
}

fn resolveFromDataRootWithExtension(data_root: []const u8, name: []const u8, extension: []const u8, out: []u8, probes: *u32) ?[:0]const u8 {
    for (hicolor_sizes) |size| {
        if (probeHicolor(out, probes, data_root, size, name, extension)) |path| return path;
    }
    return probePixmaps(out, probes, data_root, name, extension);
}

fn probeHicolor(out: []u8, probes: *u32, data_root: []const u8, size: []const u8, name: []const u8, extension: []const u8) ?[:0]const u8 {
    if (probes.* >= max_icon_probes) return null;
    probes.* += 1;
    const path = std.fmt.bufPrintZ(out, "{s}/icons/hicolor/{s}/apps/{s}{s}", .{ data_root, size, name, extension }) catch return null;
    if (!fileStatAccepted(path)) return null;
    return path;
}

fn probePixmaps(out: []u8, probes: *u32, data_root: []const u8, name: []const u8, extension: []const u8) ?[:0]const u8 {
    if (probes.* >= max_icon_probes) return null;
    probes.* += 1;
    const path = std.fmt.bufPrintZ(out, "{s}/pixmaps/{s}{s}", .{ data_root, name, extension }) catch return null;
    if (!fileStatAccepted(path)) return null;
    return path;
}

fn copyPathZ(out: []u8, path: []const u8) ?[:0]const u8 {
    if (path.len > max_icon_path_bytes or out.len <= path.len) return null;
    @memcpy(out[0..path.len], path);
    out[path.len] = 0;
    return out[0..path.len :0];
}

fn fileStatAccepted(path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(std.Options.debug_io, path, .{}) catch return false;
    return stat.size <= max_icon_file_bytes;
}

fn loadSurface(path: [:0]const u8) [*c]c.SDL_Surface {
    if (endsWithIgnoreCase(path, ".png")) return c.SDL_LoadPNG(path.ptr);
    std.debug.assert(endsWithIgnoreCase(path, ".bmp"));
    return c.SDL_LoadBMP(path.ptr);
}

fn surfaceDimensionsAccepted(surface: [*c]c.SDL_Surface) bool {
    return surface.*.w > 0 and
        surface.*.h > 0 and
        surface.*.w <= max_icon_source_dimension and
        surface.*.h <= max_icon_source_dimension;
}

fn iconNameBase(icon_name: []const u8) ?[]const u8 {
    for (supported_extensions) |extension| {
        if (endsWithIgnoreCase(icon_name, extension)) return icon_name[0 .. icon_name.len - extension.len];
    }
    return icon_name;
}

fn hasSupportedExtension(path: []const u8) bool {
    for (supported_extensions) |extension| {
        if (endsWithIgnoreCase(path, extension)) return true;
    }
    return false;
}

fn hasUnsupportedImageExtension(path: []const u8) bool {
    for (unsupported_image_extensions) |extension| {
        if (endsWithIgnoreCase(path, extension)) return true;
    }
    return false;
}

fn endsWithIgnoreCase(bytes: []const u8, suffix: []const u8) bool {
    if (bytes.len < suffix.len) return false;
    return std.ascii.eqlIgnoreCase(bytes[bytes.len - suffix.len ..], suffix);
}

fn envBytes(name: [*:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name) orelse return null;
    return std.mem.span(value);
}

test "icon resolver rejects unsupported and unbounded names" {
    var buffer: [max_icon_path_bytes + 1]u8 = undefined;
    const roots = ResolveRoots{};
    try std.testing.expect(resolveIconPathForTest("", roots, &buffer) == null);
    try std.testing.expect(resolveIconPathForTest("folder/icon", roots, &buffer) == null);
    try std.testing.expect(resolveIconPathForTest("app-symbolic", roots, &buffer) == null);
    try std.testing.expect(resolveIconPathForTest("app.svg", roots, &buffer) == null);

    var long_name: [max_icon_name_bytes + 1]u8 = undefined;
    @memset(&long_name, 'a');
    try std.testing.expect(resolveIconPathForTest(&long_name, roots, &buffer) == null);
}

test "icon resolver accepts bounded absolute png path" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{ .sub_path = "app.png", .data = "" });
    const absolute = try tmp.dir.realpathAlloc(std.testing.allocator, "app.png");
    defer std.testing.allocator.free(absolute);

    var buffer: [max_icon_path_bytes + 1]u8 = undefined;
    const resolved = resolveIconPathForTest(absolute, .{}, &buffer) orelse return error.TestExpectedEqual;
    try std.testing.expectEqualStrings(absolute, resolved);
}

test "icon resolver searches bounded hicolor and pixmaps roots" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("data/icons/hicolor/48x48/apps");
    try tmp.dir.writeFile(.{ .sub_path = "data/icons/hicolor/48x48/apps/kitty.png", .data = "" });
    try tmp.dir.makePath("data/pixmaps");
    try tmp.dir.writeFile(.{ .sub_path = "data/pixmaps/foot.bmp", .data = "" });

    const data_root = try tmp.dir.realpathAlloc(std.testing.allocator, "data");
    defer std.testing.allocator.free(data_root);

    var buffer: [max_icon_path_bytes + 1]u8 = undefined;
    const roots = ResolveRoots{ .xdg_data_home = data_root, .xdg_data_dirs = data_root };
    const kitty = resolveIconPathForTest("kitty", roots, &buffer) orelse return error.TestExpectedEqual;
    try std.testing.expect(endsWithIgnoreCase(kitty, "/data/icons/hicolor/48x48/apps/kitty.png"));

    const foot = resolveIconPathForTest("foot.bmp", roots, &buffer) orelse return error.TestExpectedEqual;
    try std.testing.expect(endsWithIgnoreCase(foot, "/data/pixmaps/foot.bmp"));
}

test "icon store records bounded negative entries" {
    var store = AppIconStore.init();
    var name_buffer: [32]u8 = undefined;

    var i: u32 = 0;
    while (i < max_icon_entries) : (i += 1) {
        const name = try std.fmt.bufPrint(&name_buffer, "missing-{d}", .{i});
        try std.testing.expect(store.reserve(name) != null);
    }
    try std.testing.expectEqual(@as(u32, max_icon_entries), store.count);
    try std.testing.expect(store.reserve("one-more") == null);
}

test "icon store retains missing result for repeated lookup" {
    var store = AppIconStore.init();
    const renderer: *c.SDL_Renderer = @ptrFromInt(1);
    const roots = ResolveRoots{ .xdg_data_home = "/wayspot-test-empty", .xdg_data_dirs = "/wayspot-test-empty" };

    try std.testing.expect(store.textureForWithRoots(renderer, "not-installed", roots) == null);
    try std.testing.expectEqual(@as(u32, 1), store.count);
    try std.testing.expect(store.textureForWithRoots(renderer, "not-installed", roots) == null);
    try std.testing.expectEqual(@as(u32, 1), store.count);
}
