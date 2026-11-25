//! Wallpaper catalogue, image validation, and hourly rotation policy.

const std = @import("std");

pub const monitor_capacity = 16;
pub const monitor_pixel_capacity = 33_177_600;
pub const round_pixel_capacity = 67_108_864;
pub const image_path_capacity = 4095;
pub const image_file_capacity = 64 * 1024 * 1024;
pub const catalog_file_capacity = 16 * 1024;
pub const catalog_entry_capacity = 32 * 1024;
pub const catalog_path_capacity = 1024;
pub const image_side_capacity = 16_384;
pub const image_pixel_capacity = 67_108_864;
/// The resident attempts one automatic rotation per hour.
pub const rotation_interval_milliseconds: u64 = 60 * 60 * 1000;

pub const RotationRequest = enum { incomplete, rotate, invalid };

pub fn classifyRotationRequest(bytes: []const u8) RotationRequest {
    if (bytes.len > "rotate\n".len) return .invalid;
    if (!std.mem.eql(u8, bytes, "rotate\n"[0..bytes.len])) return .invalid;
    return if (bytes.len == "rotate\n".len) .rotate else .incomplete;
}
pub const ImageFormat = enum { png, jpeg };
pub const Catalog = struct {
    paths: std.ArrayList([]u8) = .empty,
    order: std.ArrayList(u16) = .empty,
    cursor: usize = 0,
    last: ?u16 = null,
    published: ?u16 = null,
    allocator: std.mem.Allocator,
    prng: std.Random.DefaultPrng,

    pub fn deinit(catalog: *Catalog) void {
        for (catalog.paths.items) |path| catalog.allocator.free(path);
        catalog.paths.deinit(catalog.allocator);
        catalog.order.deinit(catalog.allocator);
    }

    pub fn shuffle(catalog: *Catalog) !void {
        catalog.order.clearRetainingCapacity();
        try catalog.order.ensureTotalCapacity(catalog.allocator, catalog.paths.items.len);
        for (0..catalog.paths.items.len) |index| catalog.order.appendAssumeCapacity(@intCast(index));
        catalog.prng.random().shuffle(u16, catalog.order.items);
        if (catalog.published) |last| if (catalog.order.items.len > 1 and catalog.order.items[0] == last) {
            std.mem.swap(u16, &catalog.order.items[0], &catalog.order.items[1]);
        };
        catalog.cursor = 0;
    }

    pub fn next(catalog: *Catalog) ![]const u8 {
        if (catalog.paths.items.len == 0) return error.WallpaperCatalogEmpty;
        if (catalog.cursor == catalog.order.items.len) try catalog.shuffle();
        const index = catalog.order.items[catalog.cursor];
        catalog.cursor += 1;
        catalog.last = index;
        return catalog.paths.items[index];
    }
};

pub const CatalogEntry = struct { name: []const u8, kind: std.Io.File.Kind };

fn alternativeSelectionLimit(file_count: usize) usize {
    std.debug.assert(file_count > 0 and file_count <= catalog_file_capacity);
    return file_count * 2 - 1;
}

pub fn collectCatalog(source: anytype, allocator: std.mem.Allocator, root_path: []const u8) !Catalog {
    if (root_path.len == 0 or root_path.len > image_path_capacity or
        !std.fs.path.isAbsolute(root_path) or !std.unicode.utf8ValidateSlice(root_path) or
        std.mem.indexOfScalar(u8, root_path, 0) != null)
    {
        return error.WallpaperRootInvalid;
    }
    try source.openRoot(root_path);
    defer source.closeRoot();
    var paths: std.ArrayList([]u8) = .empty;
    errdefer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    var visited: usize = 0;
    while (try source.nextEntry()) |entry| {
        visited += 1;
        if (visited > catalog_entry_capacity) return error.WallpaperEntryCapacityExceeded;
        if (entry.name.len == 0 or entry.name.len > catalog_path_capacity or
            !std.unicode.utf8ValidateSlice(entry.name) or std.mem.indexOfScalar(u8, entry.name, 0) != null)
        {
            return error.WallpaperPathInvalid;
        }
        const kind = if (entry.kind == .unknown) try source.statEntry(entry.name) else entry.kind;
        if (kind != .file) continue;
        _ = imageFormat(entry.name) catch continue;
        if (paths.items.len == catalog_file_capacity) return error.WallpaperFileCapacityExceeded;
        const path = try std.fs.path.join(allocator, &.{ root_path, entry.name });
        errdefer allocator.free(path);
        if (path.len > image_path_capacity) return error.ImagePathTooLong;
        try paths.append(allocator, path);
    }
    if (paths.items.len == 0) return error.WallpaperCatalogEmpty;
    std.mem.sort([]u8, paths.items, {}, struct {
        fn less(_: void, a: []u8, b: []u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.less);
    var catalog = Catalog{
        .paths = paths,
        .allocator = allocator,
        .prng = .init(try source.randomSeed()),
    };
    errdefer catalog.deinit();
    try catalog.shuffle();
    return catalog;
}

pub const Image = struct {
    width: u32,
    height: u32,
    pitch: u32,
    pixels: []u32,

    pub fn deinit(image: *Image, allocator: std.mem.Allocator) void {
        allocator.free(image.pixels);
        image.* = undefined;
    }
};

/// Retains the selected wallpaper's original bytes, not a decoded pixel grid.
/// Newly connected outputs may need the selected image after the file disappears.
/// Decode only for a publication; retain the encoded bytes between rotations.
pub const EncodedImage = struct {
    format: ImageFormat,
    bytes: []u8,

    pub fn deinit(image: *EncodedImage, allocator: std.mem.Allocator) void {
        allocator.free(image.bytes);
        image.* = undefined;
    }
};

pub const Crop = struct { x: u32, y: u32, width: u32, height: u32 };

/// A candidate has independent ownership until all requested buffers are prepared.
pub const Candidate = struct {
    encoded: EncodedImage,
    image: Image,
    index: u16,

    pub fn deinit(self: *Candidate, allocator: std.mem.Allocator) void {
        self.image.deinit(allocator);
        self.encoded.deinit(allocator);
    }
};

pub fn choose(source: anytype, allocator: std.mem.Allocator, catalog: *Catalog) !Candidate {
    if (catalog.paths.items.len == 0) return error.WallpaperCatalogEmpty;
    var attempted: [catalog_file_capacity]bool = @splat(false);
    for (0..alternativeSelectionLimit(catalog.paths.items.len)) |_| {
        const path = try catalog.next();
        const index = catalog.last.?;
        if (catalog.published == index or attempted[index]) continue;
        attempted[index] = true;
        var encoded = readEncodedImage(source, allocator, path) catch |err| {
            if (err == error.OutOfMemory) return err;
            continue;
        };
        const image = decodeImage(source, allocator, &encoded) catch |err| {
            encoded.deinit(allocator);
            if (err == error.OutOfMemory) return err;
            continue;
        };
        return .{ .encoded = encoded, .image = image, .index = index };
    }
    return error.WallpaperCatalogUnusable;
}

/// No display means no timer wake. When outputs return, rotate at most once;
/// a failed automatic rotation also advances the deadline, not a retry storm.
pub const Schedule = struct {
    deadline: ?u64 = null,

    pub fn advance(self: *Schedule, now: u64) !void {
        self.deadline = try std.math.add(u64, now, rotation_interval_milliseconds);
    }

    pub fn attempted(self: *Schedule, now: u64, direct: bool, success: bool) !void {
        if (success or !direct) try self.advance(now);
    }

    pub fn due(self: Schedule, now: u64, ready: bool) bool {
        return ready and if (self.deadline) |end| now >= end else false;
    }

    pub fn wake(self: Schedule, now: u64, ready: bool) ?u64 {
        if (!ready) return null;
        return if (self.deadline) |end| end -| now else null;
    }
};

pub fn loadImage(source: anytype, allocator: std.mem.Allocator, path: []const u8) !Image {
    var encoded = try readEncodedImage(source, allocator, path);
    defer encoded.deinit(allocator);
    return decodeImage(source, allocator, &encoded);
}

/// Read once so the resident can survive changes to the image directory.
pub fn readEncodedImage(source: anytype, allocator: std.mem.Allocator, path: []const u8) !EncodedImage {
    try validateImagePath(path);
    const format = try imageFormat(path);
    try source.open(path);
    defer source.close();
    const stat = try source.stat();
    if (stat.kind != .file) return error.ImageNotRegularFile;
    if (stat.size > image_file_capacity) return error.ImageFileTooLarge;
    const bytes = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(bytes);
    if (try source.read(bytes) != bytes.len) return error.ImageReadIncomplete;
    return .{ .format = format, .bytes = bytes };
}

/// Decode only while constructing surfaces; validate decoded dimensions against
/// the PNG header and our bounded image contract before exposing any pixels.
pub fn decodeImage(source: anytype, allocator: std.mem.Allocator, encoded: *const EncodedImage) !Image {
    const dimensions = if (encoded.format == .png) try inspectPng(encoded.bytes) else null;
    var image = try source.decode(allocator, encoded.format, encoded.bytes);
    errdefer image.deinit(allocator);
    try validateImage(&image);
    if (dimensions) |value| if (image.width != value.width or image.height != value.height) {
        return error.ImageDimensionsChanged;
    };
    return image;
}

pub fn imageFormat(path: []const u8) !ImageFormat {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".png")) return .png;
    if (std.ascii.eqlIgnoreCase(extension, ".jpg") or
        std.ascii.eqlIgnoreCase(extension, ".jpeg")) return .jpeg;
    return error.ImageFormatUnsupported;
}

pub fn coverImage(
    source: anytype,
    allocator: std.mem.Allocator,
    image: *const Image,
    width: u32,
    height: u32,
) !Image {
    try validateImage(image);
    const crop = try coverCrop(image.width, image.height, width, height);
    const count = try surfacePixelCount(width, height);
    const pixels = try allocator.alloc(u32, count);
    errdefer allocator.free(pixels);
    try source.scale(image, crop, width, height, pixels);
    return .{ .width = width, .height = height, .pitch = width * 4, .pixels = pixels };
}

pub fn coverCrop(source_width: u32, source_height: u32, width: u32, height: u32) !Crop {
    _ = try surfacePixelCount(source_width, source_height);
    _ = try surfacePixelCount(width, height);
    var crop_width = source_width;
    var crop_height = source_height;
    const source_ratio = @as(u64, source_width) * height;
    const target_ratio = @as(u64, source_height) * width;
    if (source_ratio > target_ratio) {
        crop_width = @intCast(@max(1, @as(u64, source_height) * width / height));
    } else if (source_ratio < target_ratio) {
        crop_height = @intCast(@max(1, @as(u64, source_width) * height / width));
    }
    return .{
        .x = (source_width - crop_width) / 2,
        .y = (source_height - crop_height) / 2,
        .width = crop_width,
        .height = crop_height,
    };
}

fn validateImagePath(path: []const u8) !void {
    if (path.len == 0) return error.ImagePathEmpty;
    if (path.len > image_path_capacity) return error.ImagePathTooLong;
    if (!std.unicode.utf8ValidateSlice(path) or std.mem.indexOfScalar(u8, path, 0) != null) {
        return error.ImagePathInvalid;
    }
}

fn validateImage(image: *const Image) !void {
    const count = try surfacePixelCount(image.width, image.height);
    if (image.pitch != image.width * 4) return error.ImagePitchInvalid;
    if (image.pixels.len != count) return error.ImagePixelsInvalid;
}

pub fn surfacePixelCount(width: u32, height: u32) !usize {
    if (width == 0 or height == 0) return error.ImageDimensionsZero;
    if (width > image_side_capacity or height > image_side_capacity) return error.ImageDimensionsTooLarge;
    const count = @as(u64, width) * height;
    if (count > image_pixel_capacity) return error.ImagePixelsTooMany;
    return @intCast(count);
}

fn inspectPng(bytes: []const u8) !struct { width: u32, height: u32 } {
    if (bytes.len < 24 or !std.mem.eql(u8, bytes[0..8], "\x89PNG\r\n\x1a\n") or
        !std.mem.eql(u8, bytes[12..16], "IHDR"))
    {
        return error.ImagePngInvalid;
    }
    const width = std.mem.readInt(u32, bytes[16..20], .big);
    const height = std.mem.readInt(u32, bytes[20..24], .big);
    _ = try surfacePixelCount(width, height);
    return .{ .width = width, .height = height };
}

const FileStat = struct { kind: std.Io.File.Kind, size: u64 };

const ImageStep = union(enum) {
    open: bool,
    stat: ?FileStat,
    read: enum { complete, short, fail },
    close,
    decode: union(enum) {
        image: struct { width: u32, height: u32 },
        failed,
        dimensions_failed,
        format_failed,
        convert_failed,
    },
    scale: bool,
};

const ImageTranscript = struct {
    steps: []const ImageStep,
    index: usize = 0,
    opened: bool = false,

    fn open(transcript: *ImageTranscript, _: []const u8) !void {
        const success = switch (try transcript.next()) {
            .open => |value| value,
            else => return error.ImageTranscriptMismatch,
        };
        if (!success) return error.ImageOpenFailed;
        transcript.opened = true;
    }

    fn stat(transcript: *ImageTranscript) !FileStat {
        std.debug.assert(transcript.opened);
        return switch (try transcript.next()) {
            .stat => |value| value orelse error.ImageStatFailed,
            else => error.ImageTranscriptMismatch,
        };
    }

    fn read(transcript: *ImageTranscript, bytes: []u8) !usize {
        std.debug.assert(transcript.opened);
        return switch (try transcript.next()) {
            .read => |result| switch (result) {
                .complete => blk: {
                    pngHeader(bytes, 4, 3);
                    break :blk bytes.len;
                },
                .short => bytes.len - 1,
                .fail => error.ImageReadFailed,
            },
            else => error.ImageTranscriptMismatch,
        };
    }

    fn close(transcript: *ImageTranscript) void {
        std.debug.assert(transcript.opened);
        std.debug.assert((transcript.next() catch unreachable) == .close);
        transcript.opened = false;
    }

    fn decode(transcript: *ImageTranscript, allocator: std.mem.Allocator, _: ImageFormat, _: []const u8) !Image {
        std.debug.assert(!transcript.opened);
        const dimensions = switch (try transcript.next()) {
            .decode => |result| switch (result) {
                .image => |value| value,
                .failed => return error.ImageDecodeFailed,
                .dimensions_failed => return error.ImageDimensionsTooLarge,
                .format_failed => return error.ImageFormatInvalid,
                .convert_failed => return error.ImageConvertFailed,
            },
            else => return error.ImageTranscriptMismatch,
        };
        const pixels = try allocator.alloc(u32, try surfacePixelCount(dimensions.width, dimensions.height));
        @memset(pixels, 0xff102030);
        return .{
            .width = dimensions.width,
            .height = dimensions.height,
            .pitch = dimensions.width * 4,
            .pixels = pixels,
        };
    }

    fn scale(
        transcript: *ImageTranscript,
        _: *const Image,
        crop: Crop,
        width: u32,
        height: u32,
        output: []u32,
    ) !void {
        const success = switch (try transcript.next()) {
            .scale => |value| value,
            else => return error.ImageTranscriptMismatch,
        };
        if (!success) return error.ImageScaleFailed;
        try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 4, .height = 3 }, crop);
        try std.testing.expectEqual(@as(u32, 8), width);
        try std.testing.expectEqual(@as(u32, 6), height);
        @memset(output, 0xff102030);
    }

    fn done(transcript: *const ImageTranscript) !void {
        try std.testing.expectEqual(transcript.steps.len, transcript.index);
        try std.testing.expect(!transcript.opened);
    }

    fn next(transcript: *ImageTranscript) !ImageStep {
        if (transcript.index == transcript.steps.len) return error.ImageTranscriptMismatch;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

test "image task owns exact file decode and scale history" {
    const steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 4, .height = 3 } } },
        .{ .scale = true },
    };
    var transcript = ImageTranscript{ .steps = &steps };
    var image = try loadImage(&transcript, std.testing.allocator, "wallpaper.png");
    defer image.deinit(std.testing.allocator);
    var pixels = try coverImage(&transcript, std.testing.allocator, &image, 8, 6);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 32), pixels.pitch);
    try std.testing.expectEqual(@as(u32, 0xff102030), pixels.pixels[47]);
    try transcript.done();
}

test "formats and shuffled catalog boundaries are exact" {
    try std.testing.expectEqual(ImageFormat.png, try imageFormat("A.PNG"));
    try std.testing.expectEqual(ImageFormat.jpeg, try imageFormat("a.JpEg"));
    try std.testing.expectError(error.ImageFormatUnsupported, imageFormat("a.webp"));
    var catalog = Catalog{ .allocator = std.testing.allocator, .prng = .init(7) };
    defer catalog.deinit();
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "a.png"));
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "b.jpg"));
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "c.jpeg"));
    try catalog.shuffle();
    var seen: u3 = 0;
    for (0..3) |_| {
        const path = try catalog.next();
        const index: u2 = if (path[0] == 'a') 0 else if (path[0] == 'b') 1 else 2;
        seen |= @as(u3, 1) << index;
    }
    try std.testing.expectEqual(@as(u3, 0b111), seen);
    const prior = catalog.last.?;
    catalog.published = prior;
    _ = try catalog.next();
    try std.testing.expect(catalog.last.? != prior);
}

test "alternative selection draw bound covers every cursor and skipped index" {
    const file_count = 7;
    try std.testing.expectEqual(@as(usize, 1), alternativeSelectionLimit(1));
    try std.testing.expectEqual(
        @as(usize, catalog_file_capacity * 2 - 1),
        alternativeSelectionLimit(catalog_file_capacity),
    );
    for (0..file_count + 1) |cursor| for (0..file_count) |published| {
        var catalog = Catalog{ .allocator = std.testing.allocator, .prng = .init(19) };
        defer catalog.deinit();
        for (0..file_count) |index| {
            const name = try std.fmt.allocPrint(std.testing.allocator, "{d}.png", .{index});
            try catalog.paths.append(std.testing.allocator, name);
            try catalog.order.append(std.testing.allocator, @intCast(index));
        }
        catalog.cursor = cursor;
        catalog.published = @intCast(published);
        var attempted: [catalog_file_capacity]bool = @splat(false);
        var alternatives: usize = 0;
        var draws: usize = 0;
        for (0..alternativeSelectionLimit(file_count)) |_| {
            if (alternatives == file_count - 1) break;
            _ = try catalog.next();
            draws += 1;
            const index = catalog.last.?;
            if (index == catalog.published.? or attempted[index]) continue;
            attempted[index] = true;
            alternatives += 1;
        }
        try std.testing.expectEqual(file_count - 1, alternatives);
        try std.testing.expect(draws <= alternativeSelectionLimit(file_count));
    };
}

test "rotation request framing is exact and unconditionally fuzz discoverable" {
    try std.testing.expectEqual(RotationRequest.incomplete, classifyRotationRequest(""));
    try std.testing.expectEqual(RotationRequest.incomplete, classifyRotationRequest("rot"));
    try std.testing.expectEqual(RotationRequest.rotate, classifyRotationRequest("rotate\n"));
    try std.testing.expectEqual(RotationRequest.incomplete, classifyRotationRequest("rotate"));
    try std.testing.expectEqual(RotationRequest.invalid, classifyRotationRequest("rotate\nextra"));
    try std.testing.fuzz({}, fuzzRotationRequest, .{
        .corpus = &.{ "", "r", "rotate\n", "rotate", "rotate\nextra", "\x00" },
    });
}

fn fuzzRotationRequest(_: void, smith: *std.testing.Smith) !void {
    var bytes: [32]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    switch (classifyRotationRequest(input)) {
        .incomplete => try std.testing.expect(
            input.len < "rotate\n".len and std.mem.eql(u8, input, "rotate\n"[0..input.len]),
        ),
        .rotate => try std.testing.expectEqualStrings("rotate\n", input),
        .invalid => {},
    }
}

const CatalogScriptEntry = struct {
    name: []const u8,
    kind: std.Io.File.Kind,
    stat_kind: std.Io.File.Kind = .file,
    stat_fails: bool = false,
};

const CatalogTranscript = struct {
    entries: []const CatalogScriptEntry,
    index: usize = 0,
    opened: bool = false,
    closed: bool = false,
    entropy_fails: bool = false,
    operations: [64]enum { open, next, stat, random, close } = undefined,
    operation_count: usize = 0,

    fn record(source: *CatalogTranscript, operation: @TypeOf(source.operations[0])) void {
        std.debug.assert(source.operation_count < source.operations.len);
        source.operations[source.operation_count] = operation;
        source.operation_count += 1;
    }
    fn openRoot(source: *CatalogTranscript, _: []const u8) !void {
        source.record(.open);
        source.opened = true;
    }
    fn closeRoot(source: *CatalogTranscript) void {
        source.record(.close);
        source.closed = true;
    }
    fn nextEntry(source: *CatalogTranscript) !?CatalogEntry {
        source.record(.next);
        if (source.index == source.entries.len) return null;
        defer source.index += 1;
        const entry = source.entries[source.index];
        return .{ .name = entry.name, .kind = entry.kind };
    }
    fn statEntry(source: *CatalogTranscript, _: []const u8) !std.Io.File.Kind {
        source.record(.stat);
        const entry = source.entries[source.index - 1];
        if (entry.stat_fails) return error.StatFailed;
        return entry.stat_kind;
    }
    fn randomSeed(source: *CatalogTranscript) !u64 {
        source.record(.random);
        if (source.entropy_fails) return error.EntropyUnavailable;
        return 9;
    }
};

test "catalog transcript sorts before shuffle and closes on every outcome" {
    const entries_a = [_]CatalogScriptEntry{
        .{ .name = "z.jpg", .kind = .file },
        .{ .name = "palette", .kind = .directory },
        .{ .name = "ignored.txt", .kind = .file },
        .{ .name = "a.PNG", .kind = .unknown, .stat_kind = .file },
    };
    const entries_b = [_]CatalogScriptEntry{ entries_a[3], entries_a[2], entries_a[1], entries_a[0] };
    var first = CatalogTranscript{ .entries = &entries_a };
    var second = CatalogTranscript{ .entries = &entries_b };
    var a = try collectCatalog(&first, std.testing.allocator, "/root");
    defer a.deinit();
    var b = try collectCatalog(&second, std.testing.allocator, "/root");
    defer b.deinit();
    try std.testing.expect(first.closed and second.closed);
    try std.testing.expectEqualStrings("/root/a.PNG", a.paths.items[0]);
    try std.testing.expectEqualStrings("/root/z.jpg", a.paths.items[1]);
    for (a.paths.items, b.paths.items) |left, right| try std.testing.expectEqualStrings(left, right);
    try std.testing.expectEqualSlices(u16, a.order.items, b.order.items);

    var stat_failure = CatalogTranscript{
        .entries = &.{.{ .name = "a.png", .kind = .unknown, .stat_fails = true }},
    };
    try std.testing.expectError(error.StatFailed, collectCatalog(&stat_failure, std.testing.allocator, "/root"));
    try std.testing.expect(stat_failure.closed);
    var entropy_failure = CatalogTranscript{
        .entries = &.{.{ .name = "a.png", .kind = .file }},
        .entropy_fails = true,
    };
    try std.testing.expectError(
        error.EntropyUnavailable,
        collectCatalog(&entropy_failure, std.testing.allocator, "/root"),
    );
    try std.testing.expect(entropy_failure.closed);
}

const GeneratedCatalog = struct {
    count: usize,
    accepted: usize,
    index: usize = 0,
    opened: bool = false,
    closed: bool = false,

    fn openRoot(source: *GeneratedCatalog, _: []const u8) !void {
        source.opened = true;
    }
    fn closeRoot(source: *GeneratedCatalog) void {
        source.closed = true;
    }
    fn nextEntry(source: *GeneratedCatalog) !?CatalogEntry {
        if (source.index == source.count) return null;
        defer source.index += 1;
        return .{ .name = if (source.index < source.accepted) "same.png" else "ignored.txt", .kind = .file };
    }
    fn statEntry(_: *GeneratedCatalog, _: []const u8) !std.Io.File.Kind {
        unreachable;
    }
    fn randomSeed(_: *GeneratedCatalog) !u64 {
        return 1;
    }
};

test "catalog exact entry file and path bounds accept then reject without partial ownership" {
    var entries_ok = GeneratedCatalog{ .count = catalog_entry_capacity, .accepted = 1 };
    var one = try collectCatalog(&entries_ok, std.testing.allocator, "/r");
    one.deinit();
    try std.testing.expect(entries_ok.closed);
    var entries_over = GeneratedCatalog{ .count = catalog_entry_capacity + 1, .accepted = 1 };
    try std.testing.expectError(
        error.WallpaperEntryCapacityExceeded,
        collectCatalog(&entries_over, std.testing.allocator, "/r"),
    );
    try std.testing.expect(entries_over.closed);
    var files_ok = GeneratedCatalog{ .count = catalog_file_capacity, .accepted = catalog_file_capacity };
    var full = try collectCatalog(&files_ok, std.testing.allocator, "/r");
    full.deinit();
    var files_over = GeneratedCatalog{ .count = catalog_file_capacity + 1, .accepted = catalog_file_capacity + 1 };
    try std.testing.expectError(
        error.WallpaperFileCapacityExceeded,
        collectCatalog(&files_over, std.testing.allocator, "/r"),
    );
    const exact: [catalog_path_capacity]u8 = @splat('a');
    var path_ok = CatalogTranscript{ .entries = &.{.{ .name = exact[0 .. exact.len - 4] ++ ".png", .kind = .file }} };
    var bounded = try collectCatalog(&path_ok, std.testing.allocator, "/r");
    bounded.deinit();
    const over: [catalog_path_capacity + 1]u8 = @splat('a');
    var path_over = CatalogTranscript{ .entries = &.{.{ .name = &over, .kind = .file }} };
    try std.testing.expectError(error.WallpaperPathInvalid, collectCatalog(&path_over, std.testing.allocator, "/r"));
}

test "image file failures close exactly once before decode" {
    const histories = [_]struct { expected: anyerror, steps: []const ImageStep }{
        .{ .expected = error.ImageOpenFailed, .steps = &.{.{ .open = false }} },
        .{ .expected = error.ImageStatFailed, .steps = &.{ .{ .open = true }, .{ .stat = null }, .close } },
        .{
            .expected = error.ImageNotRegularFile,
            .steps = &.{ .{ .open = true }, .{ .stat = .{ .kind = .directory, .size = 24 } }, .close },
        },
        .{
            .expected = error.ImageFileTooLarge,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = image_file_capacity + 1 } },
                .close,
            },
        },
        .{
            .expected = error.ImageReadIncomplete,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .short },
                .close,
            },
        },
        .{
            .expected = error.ImageReadFailed,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .fail },
                .close,
            },
        },
        .{
            .expected = error.ImageDecodeFailed,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .complete },
                .close,
                .{ .decode = .failed },
            },
        },
    };
    for (histories) |history| {
        var transcript = ImageTranscript{ .steps = history.steps };
        try std.testing.expectError(
            history.expected,
            loadImage(&transcript, std.testing.allocator, "wallpaper.png"),
        );
        try transcript.done();
    }
}

test "image path dimensions crop and allocation endpoints are exact" {
    var transcript = ImageTranscript{ .steps = &.{} };
    try std.testing.expectError(error.ImagePathEmpty, loadImage(&transcript, std.testing.allocator, ""));
    var path: [image_path_capacity + 1]u8 = @splat('a');
    try std.testing.expectError(error.ImagePathTooLong, loadImage(&transcript, std.testing.allocator, &path));
    const valid_path_steps = [_]ImageStep{.{ .open = false }};
    transcript = .{ .steps = &valid_path_steps };
    @memcpy(path[image_path_capacity - 4 .. image_path_capacity], ".png");
    try std.testing.expectError(
        error.ImageOpenFailed,
        loadImage(&transcript, std.testing.allocator, path[0..image_path_capacity]),
    );
    try transcript.done();
    transcript = .{ .steps = &.{} };
    path[0] = 0;
    try std.testing.expectError(error.ImagePathInvalid, loadImage(&transcript, std.testing.allocator, path[0..1]));
    path[0] = 0xff;
    try std.testing.expectError(error.ImagePathInvalid, loadImage(&transcript, std.testing.allocator, path[0..1]));
    try std.testing.expectError(error.ImageDimensionsZero, coverCrop(0, 1, 1, 1));
    try std.testing.expectError(error.ImageDimensionsTooLarge, coverCrop(image_side_capacity + 1, 1, 1, 1));
    try std.testing.expectError(error.ImagePixelsTooMany, coverCrop(8192, 8193, 1, 1));

    try std.testing.expectEqual(Crop{ .x = 2, .y = 0, .width = 5, .height = 5 }, try coverCrop(9, 5, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 2, .y = 0, .width = 5, .height = 5 }, try coverCrop(10, 5, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 2, .width = 5, .height = 5 }, try coverCrop(5, 9, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 7, .height = 3 }, try coverCrop(7, 3, 14, 6));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 1, .height = 1 }, try coverCrop(1, 1, 3, 2));
    try std.testing.expectEqual(
        Crop{ .x = 0, .y = 0, .width = 8192, .height = 8192 },
        try coverCrop(8192, 8192, 1, 1),
    );

    const steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = image_file_capacity } },
        .close,
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    transcript = .{ .steps = &steps };
    try std.testing.expectError(error.OutOfMemory, loadImage(&transcript, failing.allocator(), "wallpaper.png"));
    try transcript.done();
}

test "decode dimension format convert and scale failures publish no pixels" {
    const failures = [_]struct { expected: anyerror, result: ImageStep }{
        .{ .expected = error.ImageDecodeFailed, .result = .{ .decode = .failed } },
        .{ .expected = error.ImageDimensionsTooLarge, .result = .{ .decode = .dimensions_failed } },
        .{ .expected = error.ImageFormatInvalid, .result = .{ .decode = .format_failed } },
        .{ .expected = error.ImageConvertFailed, .result = .{ .decode = .convert_failed } },
    };
    for (failures) |failure| {
        const steps = [_]ImageStep{
            .{ .open = true },
            .{ .stat = .{ .kind = .file, .size = 24 } },
            .{ .read = .complete },
            .close,
            failure.result,
        };
        var failed = ImageTranscript{ .steps = &steps };
        try std.testing.expectError(
            failure.expected,
            loadImage(&failed, std.testing.allocator, "wallpaper.png"),
        );
        try failed.done();
    }

    const decode_steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 3, .height = 3 } } },
    };
    var transcript = ImageTranscript{ .steps = &decode_steps };
    try std.testing.expectError(
        error.ImageDimensionsChanged,
        loadImage(&transcript, std.testing.allocator, "wallpaper.png"),
    );
    try transcript.done();

    var source_pixels: [12]u32 = @splat(0xff000000);
    const image = Image{ .width = 4, .height = 3, .pitch = 16, .pixels = &source_pixels };
    const scale_steps = [_]ImageStep{.{ .scale = false }};
    transcript = .{ .steps = &scale_steps };
    try std.testing.expectError(
        error.ImageScaleFailed,
        coverImage(&transcript, std.testing.allocator, &image, 8, 6),
    );
    try transcript.done();

    const allocation_steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 4, .height = 3 } } },
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    transcript = .{ .steps = &allocation_steps };
    try std.testing.expectError(
        error.OutOfMemory,
        loadImage(&transcript, failing.allocator(), "wallpaper.png"),
    );
    try transcript.done();

    failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    transcript = .{ .steps = &.{} };
    try std.testing.expectError(
        error.OutOfMemory,
        coverImage(&transcript, failing.allocator(), &image, 8, 6),
    );
    try transcript.done();
}

test "Smith crop arithmetic and PNG headers remain bounded" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzImage, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzImage({}, &empty);
}

fn pngHeader(bytes: []u8, width: u32, height: u32) void {
    @memset(bytes, 0);
    @memcpy(bytes[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], width, .big);
    std.mem.writeInt(u32, bytes[20..24], height, .big);
}

fn fuzzImage(_: void, smith: *std.testing.Smith) !void {
    const source_width = smith.value(u32);
    const source_height = smith.value(u32);
    const width = smith.value(u32);
    const height = smith.value(u32);
    if (coverCrop(source_width, source_height, width, height)) |crop| {
        try std.testing.expect(crop.width > 0 and crop.height > 0);
        try std.testing.expect(crop.x + crop.width <= source_width);
        try std.testing.expect(crop.y + crop.height <= source_height);
    } else |_| {}
    var bytes: [64]u8 = undefined;
    const slice = bytes[0..smith.slice(&bytes)];
    if (inspectPng(slice)) |dimensions| {
        try std.testing.expect(dimensions.width <= image_side_capacity);
        try std.testing.expect(dimensions.height <= image_side_capacity);
    } else |_| {}
}
