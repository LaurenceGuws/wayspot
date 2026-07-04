//! Wallpaper library discovery keeps a bounded still-image index from one configured directory.

const std = @import("std");
const image_info = @import("image_info.zig");

pub const max_images: u32 = 4096;
pub const max_path_bytes: u32 = 4096;
pub const max_directory_entries: u32 = 16384;

pub const ImageRecord = struct {
    path: []u8,
    byte_size: u64,
    mtime_ns: i96,
    format: image_info.Format,
    width: u32,
    height: u32,
};

pub const Library = struct {
    records: std.ArrayListUnmanaged(ImageRecord) = .empty,

    pub fn scan(allocator: std.mem.Allocator, directory_path: []const u8) !Library {
        return scanDirectory(allocator, directory_path);
    }

    pub fn deinit(self: *Library, allocator: std.mem.Allocator) void {
        for (self.records.items) |record| allocator.free(record.path);
        self.records.deinit(allocator);
        self.records = .empty;
    }

    pub fn chooseRandom(self: *const Library, random: std.Random) ?*const ImageRecord {
        if (self.records.items.len == 0) return null;
        const index = random.uintLessThan(u32, @intCast(self.records.items.len));
        return &self.records.items[index];
    }
};

pub fn scan(allocator: std.mem.Allocator, directory_path: []const u8) !Library {
    return Library.scan(allocator, directory_path);
}

fn scanDirectory(allocator: std.mem.Allocator, directory_path: []const u8) !Library {
    if (!std.fs.path.isAbsolute(directory_path)) return error.WallpaperLibraryPathMustBeAbsolute;
    var dir = try std.Io.Dir.openDirAbsolute(std.Options.debug_io, directory_path, .{ .iterate = true });
    defer dir.close(std.Options.debug_io);

    var library = Library{};
    errdefer library.deinit(allocator);

    var entries_seen: u32 = 0;
    var iterator = dir.iterate();
    while (try iterator.next(std.Options.debug_io)) |entry| {
        entries_seen += 1;
        if (entries_seen > max_directory_entries) return error.TooManyWallpaperDirectoryEntries;
        if (library.records.items.len >= max_images) return library;
        if (entry.kind != .file and entry.kind != .sym_link) continue;
        if (!hasImageExtension(entry.name)) continue;

        const path = try std.fs.path.join(allocator, &.{ directory_path, entry.name });
        errdefer allocator.free(path);
        if (path.len > max_path_bytes) {
            allocator.free(path);
            continue;
        }

        const stat = dir.statFile(std.Options.debug_io, entry.name, .{}) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied, error.PermissionDenied, error.NotDir => {
                allocator.free(path);
                continue;
            },
            else => return err,
        };
        if (stat.kind != .file) {
            allocator.free(path);
            continue;
        }

        const info = image_info.readInfo(path) catch |err| switch (err) {
            error.UnsupportedImageFormat, error.ImagePathMustBeAbsolute, error.FileNotFound, error.AccessDenied, error.PermissionDenied => {
                allocator.free(path);
                continue;
            },
            else => return err,
        };
        try library.records.append(allocator, .{
            .path = path,
            .byte_size = stat.size,
            .mtime_ns = stat.mtime.nanoseconds,
            .format = info.format,
            .width = info.width,
            .height = info.height,
        });
    }

    return library;
}

fn hasImageExtension(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return std.ascii.eqlIgnoreCase(ext, ".png") or std.ascii.eqlIgnoreCase(ext, ".bmp");
}

test "library scan indexes PNG and BMP records from one directory" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "wall.png",
        .data = "\x89PNG\r\n\x1a\n" ++
            "\x00\x00\x00\x0d" ++
            "IHDR" ++
            "\x00\x00\x00\x40" ++
            "\x00\x00\x00\x20" ++
            "\x08\x02\x00\x00\x00",
    });
    try tmp.dir.writeFile(.{
        .sub_path = "wall.bmp",
        .data = "BM" ++
            "\x36\x00\x00\x00" ++
            "\x00\x00\x00\x00" ++
            "\x36\x00\x00\x00" ++
            "\x28\x00\x00\x00" ++
            "\x10\x00\x00\x00" ++
            "\x20\x00\x00\x00" ++
            "\x01\x00\x18\x00" ++
            "\x00\x00\x00\x00" ++
            "\x00\x00\x00\x00" ++
            "\x00\x00\x00\x00" ++
            "\x00\x00\x00\x00" ++
            "\x00\x00\x00\x00" ++
            "\x00\x00\x00\x00",
    });
    try tmp.dir.writeFile(.{ .sub_path = "notes.txt", .data = "ignored" });

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);

    var library = try scan(std.testing.allocator, base);
    defer library.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(library.records.items.len)));
}

test "library scan requires an absolute directory path" {
    try std.testing.expectError(error.WallpaperLibraryPathMustBeAbsolute, scan(std.testing.allocator, "wallpapers"));
}
