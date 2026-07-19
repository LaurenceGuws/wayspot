//! Scans one bounded wallpaper tree into deterministic JSONL on stdout.
//! Exact content hashes identify duplicates; this tool never changes the tree.

const std = @import("std");

const file_capacity = 16384;
const entry_capacity = 32768;
const path_capacity = 1024;
const file_size_capacity = 64 * 1024 * 1024;
const read_capacity = 64 * 1024;

const Format = enum { png, jpeg };
const Entry = struct { path: []const u8, kind: std.Io.File.Kind };
const Item = struct { path: []u8, format: Format, bytes: u64, digest: [32]u8 };

const Catalog = struct {
    items: std.ArrayList(Item) = .empty,
    allocator: std.mem.Allocator,

    fn deinit(catalog: *Catalog) void {
        for (catalog.items.items) |item| catalog.allocator.free(item.path);
        catalog.items.deinit(catalog.allocator);
    }
};

pub fn main(init: std.process.Init) !u8 {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    std.debug.assert(args.skip());
    const root_path = args.next() orelse return 2;
    if (args.next() != null) return 2;
    var native = try Native.init(init.io, root_path);
    defer native.deinit();
    var catalog = try collect(&native, init.gpa);
    defer catalog.deinit();
    var buffer: [read_capacity]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    try emit(&catalog, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn collect(source: anytype, allocator: std.mem.Allocator) !Catalog {
    var catalog = Catalog{ .allocator = allocator };
    errdefer catalog.deinit();
    var visited: usize = 0;
    while (try source.next()) |entry| {
        visited += 1;
        if (visited > entry_capacity) return error.TooManyEntries;
        if (!std.unicode.utf8ValidateSlice(entry.path)) return error.InvalidUtf8;
        try validatePath(entry.path);
        if (entry.kind == .directory and std.mem.indexOfScalar(u8, entry.path, '/') != null) return error.DepthExceeded;
        if (entry.kind != .file) continue;
        const image_format = classify(entry.path) orelse continue;
        if (catalog.items.items.len == file_capacity) return error.TooManyFiles;
        const result = try source.hash(entry.path);
        if (result.bytes > file_size_capacity) return error.FileTooBig;
        try catalog.items.append(allocator, .{
            .path = try allocator.dupe(u8, entry.path),
            .format = image_format,
            .bytes = result.bytes,
            .digest = result.digest,
        });
    }
    std.mem.sort(Item, catalog.items.items, {}, lessPath);
    return catalog;
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path.len > path_capacity or std.fs.path.isAbsolute(path)) return error.PathInvalid;
    var components = std.mem.splitScalar(u8, path, '/');
    var count: u8 = 0;
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return error.PathInvalid;
        count += 1;
        if (count > 2) return error.DepthExceeded;
    }
}

fn classify(path: []const u8) ?Format {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".png")) return .png;
    if (std.ascii.eqlIgnoreCase(extension, ".jpg") or std.ascii.eqlIgnoreCase(extension, ".jpeg")) return .jpeg;
    return null;
}

fn lessPath(_: void, a: Item, b: Item) bool {
    return std.mem.order(u8, a.path, b.path) == .lt;
}

fn lessDigest(items: []const Item, a: u32, b: u32) bool {
    const order = std.mem.order(u8, &items[a].digest, &items[b].digest);
    return order == .lt or order == .eq and std.mem.order(u8, items[a].path, items[b].path) == .lt;
}

fn emit(catalog: *const Catalog, writer: *std.Io.Writer) !void {
    for (catalog.items.items) |item| {
        const hex = std.fmt.bytesToHex(item.digest, .lower);
        try std.json.Stringify.value(.{
            .kind = "file",
            .path = item.path,
            .format = @tagName(item.format),
            .bytes = item.bytes,
            .sha256 = &hex,
        }, .{}, writer);
        try writer.writeByte('\n');
    }
    var indices: [file_capacity]u32 = undefined;
    for (indices[0..catalog.items.items.len], 0..) |*index, value| index.* = @intCast(value);
    const Context = struct {
        items: []const Item,
        pub fn lessThan(context: @This(), a: u32, b: u32) bool {
            return lessDigest(context.items, a, b);
        }
    };
    const sorted = indices[0..catalog.items.items.len];
    std.mem.sort(u32, sorted, Context{ .items = catalog.items.items }, Context.lessThan);
    var first: usize = 0;
    while (first < sorted.len) {
        var end = first + 1;
        while (end < sorted.len and std.mem.eql(u8, &catalog.items.items[sorted[first]].digest, &catalog.items.items[sorted[end]].digest)) : (end += 1) {}
        if (end - first > 1) for (sorted[first..end]) |index| {
            const item = catalog.items.items[index];
            const hex = std.fmt.bytesToHex(item.digest, .lower);
            try std.json.Stringify.value(.{
                .kind = "duplicate",
                .sha256 = &hex,
                .path = item.path,
                .group_count = @as(u32, @intCast(end - first)),
            }, .{}, writer);
            try writer.writeByte('\n');
        };
        first = end;
    }
}

const Native = struct {
    io: std.Io,
    root: std.Io.Dir,
    root_iterator: std.Io.Dir.Iterator,
    child: ?std.Io.Dir = null,
    child_iterator: std.Io.Dir.Iterator = undefined,
    directory_name: [path_capacity]u8 = undefined,
    directory_length: usize = 0,
    path: [path_capacity]u8 = undefined,

    fn init(io: std.Io, root_path: []const u8) !Native {
        const root = try std.Io.Dir.openDirAbsolute(io, root_path, .{ .iterate = true, .follow_symlinks = false });
        return .{ .io = io, .root = root, .root_iterator = root.iterate() };
    }

    fn deinit(native: *Native) void {
        if (native.child) |dir| dir.close(native.io);
        native.root.close(native.io);
    }

    fn next(native: *Native) !?Entry {
        while (true) {
            if (native.child) |dir| {
                if (try native.child_iterator.next(native.io)) |entry| {
                    const kind = if (entry.kind == .unknown)
                        (try dir.statFile(native.io, entry.name, .{ .follow_symlinks = false })).kind
                    else
                        entry.kind;
                    const length = native.directory_length + 1 + entry.name.len;
                    if (length > path_capacity) return error.PathInvalid;
                    @memcpy(native.path[0..native.directory_length], native.directory_name[0..native.directory_length]);
                    native.path[native.directory_length] = '/';
                    @memcpy(native.path[native.directory_length + 1 .. length], entry.name);
                    return .{ .path = native.path[0..length], .kind = kind };
                }
                dir.close(native.io);
                native.child = null;
                continue;
            }
            const entry = try native.root_iterator.next(native.io) orelse return null;
            if (entry.name.len > path_capacity) return error.PathInvalid;
            const kind = if (entry.kind == .unknown)
                (try native.root.statFile(native.io, entry.name, .{ .follow_symlinks = false })).kind
            else
                entry.kind;
            if (kind == .directory) {
                @memcpy(native.directory_name[0..entry.name.len], entry.name);
                native.directory_length = entry.name.len;
                native.child = try native.root.openDir(native.io, entry.name, .{ .iterate = true, .follow_symlinks = false });
                native.child_iterator = native.child.?.iterate();
            }
            @memcpy(native.path[0..entry.name.len], entry.name);
            return .{ .path = native.path[0..entry.name.len], .kind = kind };
        }
    }

    fn hash(native: *Native, path: []const u8) !struct { bytes: u64, digest: [32]u8 } {
        const file = try native.root.openFile(native.io, path, .{ .mode = .read_only, .allow_directory = false, .follow_symlinks = false });
        defer file.close(native.io);
        const before = try metadata(native.io, file);
        try validateBefore(before);
        var sha = std.crypto.hash.sha2.Sha256.init(.{});
        var buffer: [read_capacity]u8 = undefined;
        var total: u64 = 0;
        while (total < before.size) {
            const count = file.readStreaming(native.io, &.{buffer[0..@intCast(@min(buffer.len, before.size - total))]}) catch |err| switch (err) {
                error.EndOfStream => return error.FileReadIncomplete,
                else => return err,
            };
            if (count == 0) return error.FileReadIncomplete;
            sha.update(buffer[0..count]);
            total += count;
        }
        const after = try metadata(native.io, file);
        try validateAfter(before, after);
        var digest: [32]u8 = undefined;
        sha.final(&digest);
        return .{ .bytes = total, .digest = digest };
    }
};

fn validateBefore(value: Metadata) !void {
    if (value.kind != .file) return error.FileNotRegular;
    if (value.size > file_size_capacity) return error.FileTooBig;
}

fn validateAfter(before: Metadata, after: Metadata) !void {
    if (after.kind != .file) return error.FileKindChanged;
    if (!before.eql(after)) return error.FileChanged;
}

const Metadata = struct {
    device: u64,
    inode: u64,
    size: u64,
    mtime: i96,
    kind: std.Io.File.Kind,

    fn eql(a: Metadata, b: Metadata) bool {
        return a.device == b.device and a.inode == b.inode and a.size == b.size and a.mtime == b.mtime and a.kind == b.kind;
    }
};

fn metadata(io: std.Io, file: std.Io.File) !Metadata {
    const stat = try file.stat(io);
    const linux = std.os.linux;
    var statx = std.mem.zeroes(linux.Statx);
    switch (linux.errno(linux.statx(file.handle, "", linux.AT.EMPTY_PATH, .{
        .TYPE = true,
        .INO = true,
        .SIZE = true,
        .MTIME = true,
    }, &statx))) {
        .SUCCESS => {},
        else => return error.FileStatFailed,
    }
    return .{
        .device = @as(u64, statx.dev_major) << 32 | statx.dev_minor,
        .inode = stat.inode,
        .size = stat.size,
        .mtime = stat.mtime.nanoseconds,
        .kind = stat.kind,
    };
}

const ScriptFile = struct { path: []const u8, kind: std.Io.File.Kind = .file, bytes: []const u8 = "", changed: bool = false, fail: bool = false, chunks: u8 = 1 };
const ScriptOperation = enum { walk, open, stat, read, close };
const Transcript = struct {
    files: []const ScriptFile,
    index: usize = 0,
    open: usize = 0,
    closes: usize = 0,
    operations: [128]ScriptOperation = undefined,
    operation_count: usize = 0,

    fn record(transcript: *Transcript, operation: ScriptOperation) void {
        std.debug.assert(transcript.operation_count < transcript.operations.len);
        transcript.operations[transcript.operation_count] = operation;
        transcript.operation_count += 1;
    }

    fn next(transcript: *Transcript) !?Entry {
        if (transcript.index == transcript.files.len) return null;
        transcript.record(.walk);
        defer transcript.index += 1;
        const file = transcript.files[transcript.index];
        return .{ .path = file.path, .kind = file.kind };
    }

    fn hash(transcript: *Transcript, path: []const u8) !struct { bytes: u64, digest: [32]u8 } {
        const file = transcript.files[transcript.index - 1];
        try std.testing.expectEqualStrings(file.path, path);
        transcript.open += 1;
        transcript.record(.open);
        transcript.record(.stat);
        defer {
            transcript.record(.close);
            transcript.closes += 1;
        }
        for (0..file.chunks) |_| {
            transcript.record(.read);
            if (file.fail) return error.ReadFailed;
        }
        transcript.record(.stat);
        if (file.changed) return error.FileChanged;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(file.bytes, &digest, .{});
        return .{ .bytes = file.bytes.len, .digest = digest };
    }
};

const Generated = struct {
    count: usize,
    index: usize = 0,
    path: []const u8,
    kind: std.Io.File.Kind,
    bytes: u64 = 0,

    fn next(generated: *Generated) !?Entry {
        if (generated.index == generated.count) return null;
        generated.index += 1;
        return .{ .path = generated.path, .kind = generated.kind };
    }

    fn hash(generated: *Generated, _: []const u8) !struct { bytes: u64, digest: [32]u8 } {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(std.mem.asBytes(&generated.index), &digest, .{});
        return .{ .bytes = generated.bytes, .digest = digest };
    }
};

fn render(allocator: std.mem.Allocator, files: []const ScriptFile) ![]u8 {
    var transcript = Transcript{ .files = files };
    var catalog = try collect(&transcript, allocator);
    defer catalog.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try emit(&catalog, &output.writer);
    try std.testing.expectEqual(transcript.open, transcript.closes);
    return output.toOwnedSlice();
}

test "deterministic catalog and content duplicate report" {
    const a = [_]ScriptFile{
        .{ .path = "z/same.JPG", .bytes = "equal" },
        .{ .path = "ignored.webp", .bytes = "equal" },
        .{ .path = "a/name.png", .bytes = "different" },
        .{ .path = "b/other.JPEG", .bytes = "equal" },
        .{ .path = "link.png", .kind = .sym_link },
        .{ .path = "x/name.png", .bytes = "left" },
        .{ .path = "y/name.png", .bytes = "right" },
    };
    const b = [_]ScriptFile{ a[4], a[2], a[6], a[0], a[1], a[5], a[3] };
    const first = try render(std.testing.allocator, &a);
    defer std.testing.allocator.free(first);
    const second = try render(std.testing.allocator, &b);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
    var lines = std.mem.splitScalar(u8, first, '\n');
    try std.testing.expectEqualStrings("{\"kind\":\"file\",\"path\":\"a/name.png\",\"format\":\"png\",\"bytes\":9,\"sha256\":\"9d6f965ac832e40a5df6c06afe983e3b449c07b843ff51ce76204de05c690d11\"}", lines.next().?);
    try std.testing.expect(std.mem.count(u8, first, "\"kind\":\"duplicate\"") == 2);
}

test "format and relative path bounds are exact" {
    try std.testing.expectEqual(Format.png, classify("a.PNG").?);
    try std.testing.expectEqual(Format.jpeg, classify("a.jpg").?);
    try std.testing.expectEqual(Format.jpeg, classify("a.JPEG").?);
    try std.testing.expect(classify("a.webp") == null);
    for ([_][]const u8{ "a.png", "a/b.png" }) |path| try validatePath(path);
    for ([_][]const u8{ "", "/a.png", "../a.png", "a/../b.png", "a//b.png" }) |path| try std.testing.expectError(error.PathInvalid, validatePath(path));
    try std.testing.expectError(error.DepthExceeded, validatePath("a/b/c.png"));
}

test "every named catalog bound accepts its endpoint and rejects one more" {
    var exact_path: [path_capacity]u8 = @splat('a');
    @memcpy(exact_path[exact_path.len - 4 ..], ".png");
    var path_source = Generated{ .count = 1, .path = &exact_path, .kind = .file };
    var catalog = try collect(&path_source, std.testing.allocator);
    catalog.deinit();
    var long_path: [path_capacity + 1]u8 = @splat('a');
    @memcpy(long_path[long_path.len - 4 ..], ".png");
    path_source = .{ .count = 1, .path = &long_path, .kind = .file };
    try std.testing.expectError(error.PathInvalid, collect(&path_source, std.testing.allocator));

    var depth_source = Generated{ .count = 1, .path = "a/b.png", .kind = .file };
    catalog = try collect(&depth_source, std.testing.allocator);
    catalog.deinit();
    depth_source = .{ .count = 1, .path = "a/b/c.png", .kind = .file };
    try std.testing.expectError(error.DepthExceeded, collect(&depth_source, std.testing.allocator));

    var size_source = Generated{ .count = 1, .path = "a.png", .kind = .file, .bytes = file_size_capacity };
    catalog = try collect(&size_source, std.testing.allocator);
    catalog.deinit();
    size_source.bytes += 1;
    size_source.index = 0;
    try std.testing.expectError(error.FileTooBig, collect(&size_source, std.testing.allocator));

    var file_source = Generated{ .count = file_capacity, .path = "a.png", .kind = .file };
    catalog = try collect(&file_source, std.testing.allocator);
    try std.testing.expectEqual(file_capacity, catalog.items.items.len);
    catalog.deinit();
    file_source = .{ .count = file_capacity + 1, .path = "a.png", .kind = .file };
    try std.testing.expectError(error.TooManyFiles, collect(&file_source, std.testing.allocator));

    var entry_source = Generated{ .count = entry_capacity, .path = "directory", .kind = .directory };
    catalog = try collect(&entry_source, std.testing.allocator);
    catalog.deinit();
    entry_source.count += 1;
    entry_source.index = 0;
    try std.testing.expectError(error.TooManyEntries, collect(&entry_source, std.testing.allocator));
}

test "metadata kind size and race failures retain exact meaning" {
    const regular = Metadata{ .device = 1, .inode = 2, .size = file_size_capacity, .mtime = 3, .kind = .file };
    try validateBefore(regular);
    var value = regular;
    value.kind = .directory;
    try std.testing.expectError(error.FileNotRegular, validateBefore(value));
    value = regular;
    value.size += 1;
    try std.testing.expectError(error.FileTooBig, validateBefore(value));
    value = regular;
    value.kind = .sym_link;
    try std.testing.expectError(error.FileKindChanged, validateAfter(regular, value));
    value = regular;
    value.mtime += 1;
    try std.testing.expectError(error.FileChanged, validateAfter(regular, value));
}

test "scripted partial reads have one open close and two stable stats" {
    var transcript = Transcript{ .files = &.{.{ .path = "a.png", .bytes = "abcdef", .chunks = 3 }} };
    var catalog = try collect(&transcript, std.testing.allocator);
    defer catalog.deinit();
    try std.testing.expectEqualSlices(ScriptOperation, &.{ .walk, .open, .stat, .read, .read, .read, .stat, .close }, transcript.operations[0..transcript.operation_count]);
    try std.testing.expectEqual(@as(usize, 1), transcript.open);
    try std.testing.expectEqual(transcript.open, transcript.closes);
}

test "bounds failures close every opened scripted file" {
    const cases = [_]ScriptFile{
        .{ .path = "broken.png", .fail = true },
        .{ .path = "changed.jpg", .changed = true },
    };
    for (cases) |file| {
        var transcript = Transcript{ .files = &.{file} };
        try std.testing.expectError(if (file.fail) error.ReadFailed else error.FileChanged, collect(&transcript, std.testing.allocator));
        try std.testing.expectEqual(transcript.open, transcript.closes);
    }
    var too_long: [path_capacity + 1]u8 = @splat('x');
    @memcpy(too_long[too_long.len - 4 ..], ".png");
    var transcript = Transcript{ .files = &.{.{ .path = &too_long }} };
    try std.testing.expectError(error.PathInvalid, collect(&transcript, std.testing.allocator));
}

test "JSON path escaping and empty catalog are exact" {
    const output = try render(std.testing.allocator, &.{.{ .path = "a/quote\"line\n.png", .bytes = "x" }});
    defer std.testing.allocator.free(output);
    try std.testing.expect(std.mem.indexOf(u8, output, "a/quote\\\"line\\n.png") != null);
    const empty = try render(std.testing.allocator, &.{});
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}

test "output failure is visible only after collection owns complete hashes" {
    var transcript = Transcript{ .files = &.{.{ .path = "a.png", .bytes = "x" }} };
    var catalog = try collect(&transcript, std.testing.allocator);
    defer catalog.deinit();
    try std.testing.expectEqual(transcript.open, transcript.closes);
    var bytes: [1]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.testing.expectError(error.WriteFailed, emit(&catalog, &writer));
}

fn fuzzCatalog(_: void, smith: *std.testing.Smith) !void {
    const extensions = [_][]const u8{ ".png", ".JPG", ".jpeg", ".webp", ".txt" };
    const contents = [_][]const u8{ "duplicate", "duplicate", "unique", "other" };
    const rejected = [_][]const u8{ "", "/a.png", "../a.png", "a/../b.png", "a//b.png", "a/b/c.png" };
    const rejected_path = rejected[smith.index(rejected.len)];
    if (std.mem.count(u8, rejected_path, "/") > 1 and std.mem.indexOf(u8, rejected_path, "..") == null and std.mem.indexOf(u8, rejected_path, "//") == null)
        try std.testing.expectError(error.DepthExceeded, validatePath(rejected_path))
    else
        try std.testing.expectError(error.PathInvalid, validatePath(rejected_path));
    try std.testing.expect(classify("ignored.webp") == null);

    var storage: [16][32]u8 = undefined;
    var files: [16]ScriptFile = undefined;
    const count = smith.valueRangeAtMost(u8, 3, files.len);
    for (files[0..count], 0..) |*file, index| {
        const extension = if (index < 3) extensions[index] else extensions[smith.index(extensions.len)];
        const path = if (smith.value(bool))
            try std.fmt.bufPrint(&storage[index], "d/{d}{s}", .{ index, extension })
        else
            try std.fmt.bufPrint(&storage[index], "{d}{s}", .{ index, extension });
        file.* = .{ .path = path, .bytes = contents[if (index < 3) index else smith.index(contents.len)] };
    }
    var shuffled = files;
    var remaining: usize = count;
    while (remaining > 1) {
        const swap = smith.index(remaining);
        remaining -= 1;
        std.mem.swap(ScriptFile, &shuffled[remaining], &shuffled[swap]);
    }
    const output = try render(std.testing.allocator, files[0..count]);
    defer std.testing.allocator.free(output);
    const permutation = try render(std.testing.allocator, shuffled[0..count]);
    defer std.testing.allocator.free(permutation);
    try std.testing.expectEqualStrings(output, permutation);

    var hashes: [16][64]u8 = undefined;
    var hash_count: usize = 0;
    var duplicate_records: usize = 0;
    var parsed = std.mem.splitScalar(u8, output, '\n');
    while (parsed.next()) |line| if (line.len != 0) {
        var value = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, line, .{});
        defer value.deinit();
        const object = value.value.object;
        const kind = object.get("kind").?.string;
        const hash = object.get("sha256").?.string;
        if (std.mem.eql(u8, kind, "file")) {
            @memcpy(&hashes[hash_count], hash);
            hash_count += 1;
        } else {
            duplicate_records += 1;
            var matching: usize = 0;
            for (hashes[0..hash_count]) |file_hash| if (std.mem.eql(u8, &file_hash, hash)) {
                matching += 1;
            };
            try std.testing.expect(matching > 1);
            try std.testing.expectEqual(@as(i64, @intCast(matching)), object.get("group_count").?.integer);
        }
    };
    var expected_duplicates: usize = 0;
    for (hashes[0..hash_count]) |hash| {
        var matching: usize = 0;
        for (hashes[0..hash_count]) |other| if (std.mem.eql(u8, &hash, &other)) {
            matching += 1;
        };
        if (matching > 1) expected_duplicates += 1;
    }
    try std.testing.expectEqual(expected_duplicates, duplicate_records);
}

test "bounded arbitrary paths and bytes remain valid deterministic JSONL" {
    try std.testing.fuzz({}, fuzzCatalog, .{ .corpus = &.{
        "catalog-a",
        "catalog-b",
        "paths",
        "duplicates",
        "extensions",
        "permutations",
    } });
}
