//! One Wayland connection and one persistent background surface per output.

const std = @import("std");
const wallpaper = @import("root.zig");
const sdl = @import("sdl_c");
const wl = @import("wayland_c");
const outputs = @import("outputs.zig");
const Stop = @import("../stop.zig");

extern fn wayspot_jpeg_decode(
    bytes: [*]const u8,
    length: usize,
    side_limit: u32,
    pixel_limit: u64,
    width: *u32,
    height: *u32,
) callconv(.c) ?[*]u8;
extern fn wayspot_jpeg_free(pixels: *anyopaque) callconv(.c) void;

pub fn discoverCatalog(io: std.Io, allocator: std.mem.Allocator, root_path: []const u8) !wallpaper.Catalog {
    var source = Discovery{ .io = io };
    return wallpaper.collectCatalog(&source, allocator, root_path);
}

const Discovery = struct {
    io: std.Io,
    root: ?std.Io.Dir = null,
    iterator: std.Io.Dir.Iterator = undefined,

    pub fn openRoot(source: *Discovery, path: []const u8) !void {
        source.root = try std.Io.Dir.openDirAbsolute(source.io, path, .{ .iterate = true, .follow_symlinks = false });
        source.iterator = source.root.?.iterate();
    }

    pub fn closeRoot(source: *Discovery) void {
        source.root.?.close(source.io);
        source.root = null;
    }

    pub fn nextEntry(source: *Discovery) !?wallpaper.CatalogEntry {
        const entry = try source.iterator.next(source.io) orelse return null;
        return .{ .name = entry.name, .kind = entry.kind };
    }

    pub fn statEntry(source: *Discovery, name: []const u8) !std.Io.File.Kind {
        return (try source.root.?.statFile(source.io, name, .{ .follow_symlinks = false })).kind;
    }

    pub fn randomSeed(source: *Discovery) !u64 {
        var seed: u64 = undefined;
        try source.io.randomSecure(std.mem.asBytes(&seed));
        return seed;
    }
};

/// File/image I/O and the existing per-display rotation endpoint.
const Source = struct {
    io: std.Io,
    file: ?std.Io.File = null,
    rotate_listener: std.posix.fd_t = -1,
    rotate_client: std.posix.fd_t = -1,
    rotate_bytes: [16]u8 = undefined,
    rotate_length: u8 = 0,
    pub fn open(source: *Source, path: []const u8) !void {
        std.debug.assert(source.file == null);
        source.file = if (std.fs.path.isAbsolute(path))
            try std.Io.Dir.openFileAbsolute(source.io, path, .{})
        else
            try std.Io.Dir.cwd().openFile(source.io, path, .{});
    }

    pub fn stat(source: *Source) !struct { kind: std.Io.File.Kind, size: u64 } {
        const value = try (source.file orelse unreachable).stat(source.io);
        return .{ .kind = value.kind, .size = value.size };
    }

    pub fn read(source: *Source, bytes: []u8) !usize {
        return (source.file orelse unreachable).readPositionalAll(source.io, bytes, 0);
    }

    pub fn close(source: *Source) void {
        const file = source.file orelse unreachable;
        file.close(source.io);
        source.file = null;
    }

    pub fn openRotation(source: *Source, signature: []const u8) !void {
        std.debug.assert(source.rotate_listener < 0 and source.rotate_client < 0);
        const address = try abstractAddress(signature);
        const result = std.posix.system.socket(
            std.posix.AF.UNIX,
            std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
            0,
        );
        const fd: std.posix.fd_t = if (std.posix.errno(result) == .SUCCESS)
            @intCast(result)
        else
            return error.RotationSocketOpenFailed;
        errdefer _ = std.posix.system.close(fd);
        switch (std.posix.errno(std.posix.system.bind(fd, @ptrCast(&address.value), address.length))) {
            .SUCCESS => {},
            .ADDRINUSE => return error.RotationNameInUse,
            else => return error.RotationSocketBindFailed,
        }
        if (std.posix.errno(std.posix.system.listen(fd, 4)) != .SUCCESS) {
            return error.RotationSocketListenFailed;
        }
        source.rotate_listener = fd;
    }

    pub fn closeRotation(source: *Source) void {
        if (source.rotate_client >= 0) _ = std.posix.system.close(source.rotate_client);
        if (source.rotate_listener >= 0) _ = std.posix.system.close(source.rotate_listener);
        source.rotate_client = -1;
        source.rotate_listener = -1;
        source.rotate_length = 0;
    }

    pub fn receiveRotation(source: *Source) !bool {
        if (source.rotate_client >= 0) source.rejectBusy();
        if (source.rotate_client < 0) {
            const accepted = std.os.linux.accept4(
                source.rotate_listener,
                null,
                null,
                std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
            );
            source.rotate_client = if (std.os.linux.errno(accepted) == .SUCCESS)
                @intCast(accepted)
            else
                return error.RotationAcceptFailed;
            errdefer {
                _ = std.posix.system.close(source.rotate_client);
                source.rotate_client = -1;
            }
            try authenticatePeer(source.rotate_client, std.os.linux.geteuid());
        }
        const file: std.Io.File = .{ .handle = source.rotate_client, .flags = .{ .nonblocking = true } };
        const suffix = source.rotate_bytes[source.rotate_length..];
        const count = file.readStreaming(source.io, &.{suffix}) catch |err| switch (err) {
            error.WouldBlock => return false,
            error.EndOfStream => return error.RotationRequestIncomplete,
            else => return err,
        };
        source.rotate_length += @intCast(count);
        const bytes = source.rotate_bytes[0..source.rotate_length];
        return switch (wallpaper.classifyRotationRequest(bytes)) {
            .incomplete => false,
            .rotate => true,
            .invalid => error.RotationRequestInvalid,
        };
    }

    fn rejectBusy(source: *Source) void {
        const accepted = std.os.linux.accept4(
            source.rotate_listener,
            null,
            null,
            std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        );
        if (std.os.linux.errno(accepted) != .SUCCESS) return;
        const fd: std.posix.fd_t = @intCast(accepted);
        defer _ = std.posix.system.close(fd);
        authenticatePeer(fd, std.os.linux.geteuid()) catch return;
        const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
        file.writeStreamingAll(source.io, "error\n") catch {};
    }

    pub fn replyRotation(source: *Source, success: bool) void {
        if (source.rotate_client < 0) return;
        const file: std.Io.File = .{ .handle = source.rotate_client, .flags = .{ .nonblocking = true } };
        file.writeStreamingAll(source.io, if (success) "ok\n" else "error\n") catch {};
        _ = std.posix.system.close(source.rotate_client);
        source.rotate_client = -1;
        source.rotate_length = 0;
    }

    /// Returns the borrowed I/O clock in monotonic milliseconds for bounded waits.
    pub fn now(source: *Source) u64 {
        return @intCast(std.Io.Clock.awake.now(source.io).toMilliseconds());
    }

    pub fn decode(
        _: *Source,
        allocator: std.mem.Allocator,
        format: wallpaper.ImageFormat,
        bytes: []const u8,
    ) !wallpaper.Image {
        if (format == .jpeg) return decodeJpeg(allocator, bytes);
        const stream = sdl.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse return error.ImageStreamFailed;
        const decoded = sdl.SDL_LoadPNG_IO(stream, true) orelse return error.ImageDecodeFailed;
        defer sdl.SDL_DestroySurface(decoded);
        const width = try surfaceSide(decoded.*.w);
        const height = try surfaceSide(decoded.*.h);
        if (@as(u64, width) * height > wallpaper.image_pixel_capacity) return error.ImageDimensionsTooLarge;
        const pixels = try allocator.alloc(u32, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        @memset(pixels, 0xff000000);
        const normalized = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            pixels.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(normalized);
        try xrgbSurface(normalized, width, height);
        if (!sdl.SDL_BlitSurface(decoded, null, normalized, null)) return error.ImageConvertFailed;
        return .{
            .width = width,
            .height = height,
            .pitch = width * 4,
            .pixels = pixels,
        };
    }

    pub fn scale(
        _: *Source,
        image: *const wallpaper.Image,
        crop: wallpaper.Crop,
        width: u32,
        height: u32,
        output: []u32,
    ) !void {
        const source = sdl.SDL_CreateSurfaceFrom(
            @intCast(image.width),
            @intCast(image.height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            @constCast(image.pixels.ptr),
            @intCast(image.pitch),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(source);
        const target = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            output.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(target);
        try xrgbSurface(source, image.width, image.height);
        try xrgbSurface(target, width, height);
        const source_rect = rect(crop.x, crop.y, crop.width, crop.height);
        const target_rect = rect(0, 0, width, height);
        if (!sdl.SDL_BlitSurfaceScaled(source, &source_rect, target, &target_rect, sdl.SDL_SCALEMODE_LINEAR)) {
            return error.ImageScaleFailed;
        }
    }
};

const AbstractAddress = struct { value: std.posix.sockaddr.un, length: std.posix.socklen_t };

fn abstractAddress(signature: []const u8) !AbstractAddress {
    const prefix = "wayspot-wallpaper:";
    if (signature.len == 0 or !std.unicode.utf8ValidateSlice(signature) or
        std.mem.indexOfAny(u8, signature, "\x00/") != null or
        prefix.len + signature.len > 107)
    {
        return error.RotationInstanceInvalid;
    }
    var value: std.posix.sockaddr.un = .{ .family = std.posix.AF.UNIX, .path = @splat(0) };
    @memcpy(value.path[1..][0..prefix.len], prefix);
    @memcpy(value.path[1 + prefix.len ..][0..signature.len], signature);
    return .{
        .value = value,
        .length = @intCast(@offsetOf(std.posix.sockaddr.un, "path") + 1 + prefix.len + signature.len),
    };
}

const Credentials = extern struct { pid: c_int, uid: c_uint, gid: c_uint };

fn authenticatePeer(fd: std.posix.fd_t, expected_uid: c_uint) !void {
    var credentials: Credentials = undefined;
    var length: std.posix.socklen_t = @sizeOf(Credentials);
    if (std.posix.errno(std.posix.system.getsockopt(
        fd,
        std.posix.SOL.SOCKET,
        std.os.linux.SO.PEERCRED,
        @ptrCast(&credentials),
        &length,
    )) != .SUCCESS or length != @sizeOf(Credentials)) return error.RotationPeerCredentialsFailed;
    try requireUid(credentials.uid, expected_uid);
}

fn requireUid(actual: c_uint, expected: c_uint) !void {
    if (actual != expected) return error.RotationPeerInvalid;
}

pub fn requestRotation(io: std.Io, signature: []const u8) !void {
    const started = std.Io.Clock.awake.now(io);
    const address = try abstractAddress(signature);
    const result = std.posix.system.socket(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        0,
    );
    const fd: std.posix.fd_t = if (std.posix.errno(result) == .SUCCESS)
        @intCast(result)
    else
        return error.RotationSocketOpenFailed;
    defer _ = std.posix.system.close(fd);
    switch (std.posix.errno(std.posix.system.connect(fd, @ptrCast(&address.value), address.length))) {
        .SUCCESS => {},
        .INPROGRESS => {
            try pollDirect(io, fd, std.posix.POLL.OUT, started);
            var socket_error: c_int = 0;
            var length: std.posix.socklen_t = @sizeOf(c_int);
            if (std.posix.errno(std.posix.system.getsockopt(
                fd,
                std.posix.SOL.SOCKET,
                std.posix.SO.ERROR,
                @ptrCast(&socket_error),
                &length,
            )) != .SUCCESS or length != @sizeOf(c_int)) return error.RotationSocketConnectFailed;
            if (socket_error != 0) return switch (@as(std.posix.E, @fromBackingInt(@intCast(socket_error)))) {
                .CONNREFUSED => error.WallpaperResidentUnavailable,
                .TIMEDOUT => error.RotationTimedOut,
                else => error.RotationSocketConnectFailed,
            };
        },
        .CONNREFUSED => return error.WallpaperResidentUnavailable,
        else => return error.RotationSocketConnectFailed,
    }
    try authenticatePeer(fd, std.os.linux.geteuid());
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    var written: usize = 0;
    for (0..16) |_| {
        written += file.writeStreaming(io, &.{}, &.{"rotate\n"[written..]}, 1) catch |err| switch (err) {
            error.WouldBlock => {
                try pollDirect(io, fd, std.posix.POLL.OUT, started);
                continue;
            },
            else => return err,
        };
        if (written == "rotate\n".len) break;
    }
    if (written != "rotate\n".len) return error.RotationRequestIncomplete;
    var reply: [16]u8 = undefined;
    var used: usize = 0;
    for (0..16) |_| {
        used += file.readStreaming(io, &.{reply[used..]}) catch |err| switch (err) {
            error.WouldBlock => {
                try pollDirect(io, fd, std.posix.POLL.IN, started);
                continue;
            },
            error.EndOfStream => break,
            else => return err,
        };
        if (std.mem.indexOfScalar(u8, reply[0..used], '\n') != null) break;
    }
    if (!std.mem.eql(u8, reply[0..used], "ok\n")) return error.RotationRejected;
}

const rotation_request_timeout_milliseconds = 30_000;

fn requestMillisecondsRemaining(elapsed: i64) !i32 {
    if (elapsed >= rotation_request_timeout_milliseconds) return error.RotationTimedOut;
    return @intCast(rotation_request_timeout_milliseconds - elapsed);
}

fn pollDirect(io: std.Io, fd: std.posix.fd_t, events: i16, started: std.Io.Timestamp) !void {
    var descriptors = [1]std.posix.pollfd{.{ .fd = fd, .events = events, .revents = 0 }};
    const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
    if (try std.posix.poll(&descriptors, try requestMillisecondsRemaining(elapsed)) == 0) {
        return error.RotationTimedOut;
    }
    if (descriptors[0].revents & (std.posix.POLL.ERR | std.posix.POLL.NVAL) != 0) {
        return error.RotationSocketFailed;
    }
    if (events == std.posix.POLL.OUT and descriptors[0].revents & std.posix.POLL.HUP != 0) {
        return error.RotationSocketFailed;
    }
}

/// Stable per-display identity for Wayspot rotation control, independent of
/// compositor-specific sockets and without ever accepting PAM credentials.
pub fn sessionIdentifier(runtime: []const u8, display: []const u8) ![32]u8 {
    if (runtime.len == 0 or runtime.len > 4096 or runtime[0] != '/' or
        display.len == 0 or display.len > 4096 or
        std.mem.indexOfScalar(u8, runtime, 0) != null or
        std.mem.indexOfScalar(u8, display, 0) != null or
        (display[0] != '/' and std.mem.indexOfAny(u8, display, "/\\") != null))
        return error.InvalidWaylandSession;
    var digest: [32]u8 = undefined;
    var sha = std.crypto.hash.sha2.Sha256.init(.{});
    sha.update(runtime);
    sha.update(&.{0});
    sha.update(display);
    sha.final(&digest);
    return std.fmt.bytesToHex(digest[0..16], .lower);
}

fn surfaceSide(value: c_int) !u32 {
    if (value <= 0) return error.ImageDimensionsZero;
    if (value > wallpaper.image_side_capacity) return error.ImageDimensionsTooLarge;
    return @intCast(value);
}

fn decodeJpeg(allocator: std.mem.Allocator, bytes: []const u8) !wallpaper.Image {
    var width: u32 = 0;
    var height: u32 = 0;
    const decoded = wayspot_jpeg_decode(
        bytes.ptr,
        bytes.len,
        wallpaper.image_side_capacity,
        wallpaper.image_pixel_capacity,
        &width,
        &height,
    ) orelse return error.ImageDecodeFailed;
    defer wayspot_jpeg_free(decoded);
    const count = @as(usize, width) * height;
    const pixels = try allocator.alloc(u32, count);
    errdefer allocator.free(pixels);
    const rgba = decoded[0 .. count * 4];
    for (pixels, 0..) |*pixel, index| {
        const source = rgba[index * 4 ..][0..4];
        pixel.* = 0xff000000 | @as(u32, source[0]) << 16 | @as(u32, source[1]) << 8 | source[2];
    }
    return .{ .width = width, .height = height, .pitch = width * 4, .pixels = pixels };
}

fn xrgbSurface(surface: *sdl.SDL_Surface, width: u32, height: u32) !void {
    if (surface.*.format != sdl.SDL_PIXELFORMAT_XRGB8888 or surface.*.w != width or
        surface.*.h != height or surface.*.pitch != width * 4 or surface.*.pixels == null)
    {
        return error.ImageFormatInvalid;
    }
}

fn rect(x: u32, y: u32, width: u32, height: u32) sdl.SDL_Rect {
    return .{ .x = @intCast(x), .y = @intCast(y), .w = @intCast(width), .h = @intCast(height) };
}

test "rotation socket identity is stable per Wayland display and rejects malformed context" {
    const one = try sessionIdentifier("/run/user/1000", "wayland-0");
    const same = try sessionIdentifier("/run/user/1000", "wayland-0");
    const different = try sessionIdentifier("/run/user/1000", "wayland-1");
    try std.testing.expectEqual(one, same);
    try std.testing.expect(!std.mem.eql(u8, &one, &different));
    try std.testing.expectError(error.InvalidWaylandSession, sessionIdentifier("relative", "wayland-0"));
    try std.testing.expectError(error.InvalidWaylandSession, sessionIdentifier("/run/user/1000", "abc/def"));
    try std.testing.expectError(error.InvalidWaylandSession, sessionIdentifier("/run/user/1000", ""));
}

test "source PNG decode and linear cover scaling" {
    const png =
        "\x89PNG\r\n\x1a\n" ++
        "\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89" ++
        "\x00\x00\x00\x0dIDAT\x78\x9c\x63\xf8\xcf\xc0\xd0\x00\x00\x04\x81\x01\x80\x2c\x55\xce\xb0" ++
        "\x00\x00\x00\x00IEND\xae\x42\x60\x82";
    var source = Source{ .io = std.testing.io };
    var image = try source.decode(std.testing.allocator, .png, png);
    defer image.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 1), image.width);
    try std.testing.expectEqual(@as(u32, 1), image.height);
    try std.testing.expectEqual(@as(u32, 0xff800000), image.pixels[0]);
    var pixels = try wallpaper.coverImage(&source, std.testing.allocator, &image, 3, 2);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 12), pixels.pitch);
    for (pixels.pixels) |pixel| try std.testing.expectEqual(@as(u32, 0xff800000), pixel);
}

test "source malformed PNG publishes no image" {
    var png: [24]u8 = @splat(0);
    @memcpy(png[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(png[12..16], "IHDR");
    std.mem.writeInt(u32, png[16..20], 1, .big);
    std.mem.writeInt(u32, png[20..24], 1, .big);
    var source = Source{ .io = std.testing.io };
    try std.testing.expectError(
        error.ImageDecodeFailed,
        source.decode(std.testing.allocator, .png, &png),
    );
}

test "source JPEG memory boundary decodes and frees one bounded image" {
    const encoded =
        "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4R" ++
        "DgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU" ++
        "FBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAA" ++
        "CP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAH/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP" ++
        "/aAAwDAQACEQMRAD8APg3Lr//Z";
    var bytes: [285]u8 = undefined;
    try std.base64.standard.Decoder.decode(&bytes, encoded);
    var source = Source{ .io = std.testing.io };
    var image = try source.decode(std.testing.allocator, .jpeg, &bytes);
    defer image.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 1), image.width);
    try std.testing.expectEqual(@as(u32, 1), image.height);
    try std.testing.expectEqual(@as(usize, 1), image.pixels.len);
}

test "abstract rotation endpoint is exact single-instance kernel state" {
    const signature: [62]u8 = @splat('x');
    const address = try abstractAddress(&signature);
    try std.testing.expectEqual(
        @as(std.posix.socklen_t, @offsetOf(std.posix.sockaddr.un, "path") + 1 + 80),
        address.length,
    );
    try std.testing.expectEqual(@as(u8, 0), address.value.path[0]);
    try std.testing.expectEqualStrings("wayspot-wallpaper:" ++ signature, address.value.path[1..][0..80]);
    var resident = Source{ .io = std.testing.io };
    try resident.openRotation(&signature);
    defer resident.closeRotation();
    var duplicate = Source{ .io = std.testing.io };
    try std.testing.expectError(error.RotationNameInUse, duplicate.openRotation(&signature));
    var requester = try std.testing.io.concurrent(requestRotation, .{ std.testing.io, &signature });
    while (true) {
        const ready = try wait(&resident, null, -1, 100);
        if (ready.rotate and try resident.receiveRotation()) break;
    }
    resident.replyRotation(true);
    try requester.await(std.testing.io);
    resident.closeRotation();
    try duplicate.openRotation(&signature);
    duplicate.closeRotation();
}

test "partial request client HUP busy peer and closed fd ownership are exact" {
    const signature = "partial-test";
    var resident = Source{ .io = std.testing.io };
    try resident.openRotation(signature);
    defer resident.closeRotation();
    const client = try connectRotationTest(signature);
    defer _ = std.posix.system.close(client);
    const file: std.Io.File = .{ .handle = client, .flags = .{ .nonblocking = true } };
    try file.writeStreamingAll(std.testing.io, "rot");
    while (!(try wait(&resident, null, -1, 100)).rotate) {}
    try std.testing.expect(!try resident.receiveRotation());
    try file.writeStreamingAll(std.testing.io, "ate\n");
    while (!(try wait(&resident, null, -1, 100)).rotate) {}
    try std.testing.expect(try resident.receiveRotation());

    var busy = try std.testing.io.concurrent(requestRotation, .{ std.testing.io, signature });
    while (!(try wait(&resident, null, -1, 100)).rotate) {}
    resident.rejectBusy();
    if (busy.await(std.testing.io)) |_| return error.BusyRequestAccepted else |err| {
        try std.testing.expect(err == error.RotationRejected or err == error.RotationSocketFailed);
    }
    resident.replyRotation(true);

    const disconnected = try connectRotationTest(signature);
    _ = std.posix.system.close(disconnected);
    while (!(try wait(&resident, null, -1, 100)).rotate) {}
    try std.testing.expectError(error.RotationRequestIncomplete, resident.receiveRotation());
    resident.replyRotation(false);
    const ready = try wait(&resident, null, -1, 0);
    try std.testing.expect(!ready.rotate);
}

fn connectRotationTest(signature: []const u8) !std.posix.fd_t {
    const address = try abstractAddress(signature);
    const result = std.posix.system.socket(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        0,
    );
    const fd: std.posix.fd_t = if (std.posix.errno(result) == .SUCCESS)
        @intCast(result)
    else
        return error.TestSocketFailed;
    errdefer _ = std.posix.system.close(fd);
    switch (std.posix.errno(std.posix.system.connect(fd, @ptrCast(&address.value), address.length))) {
        .SUCCESS => {},
        .INPROGRESS => try pollDirect(std.testing.io, fd, std.posix.POLL.OUT, std.Io.Clock.awake.now(std.testing.io)),
        else => return error.TestSocketFailed,
    }
    try authenticatePeer(fd, std.os.linux.geteuid());
    return fd;
}

test "rotation request has one exact total wait bound" {
    try std.testing.expectEqual(@as(i32, 30_000), try requestMillisecondsRemaining(0));
    try std.testing.expectEqual(@as(i32, 1), try requestMillisecondsRemaining(29_999));
    try std.testing.expectError(error.RotationTimedOut, requestMillisecondsRemaining(30_000));
    try std.testing.expectError(error.RotationTimedOut, requestMillisecondsRemaining(30_001));
}

test "socket credential transcript rejects either wrong uid before protocol bytes" {
    const own: c_uint = 1000;
    for ([_]struct { peer: c_uint, accepted: bool }{
        .{ .peer = own, .accepted = true },
        .{ .peer = own + 1, .accepted = false },
    }) |step| {
        if (requireUid(step.peer, own)) |_| {
            try std.testing.expect(step.accepted);
        } else |err| {
            try std.testing.expectEqual(error.RotationPeerInvalid, err);
            try std.testing.expect(!step.accepted);
        }
    }
}

test "source unsupported IO acquires no file" {
    var source = Source{ .io = std.Io.failing };
    if (source.open("wallpaper.png")) |_| {
        return error.ExpectedOpenFailure;
    } else |_| {}
    try std.testing.expect(source.file == null);
}

test "bounded malformed image data publishes no partial image" {
    try std.testing.fuzz(wallpaper.ImageFormat.png, fuzzImage, .{ .corpus = &.{ "", "not png" } });
    try std.testing.fuzz(wallpaper.ImageFormat.jpeg, fuzzImage, .{
        .corpus = &.{ "", "\xff\xd8\xff\xd9", "not jpeg" },
    });
}

fn fuzzImage(format: wallpaper.ImageFormat, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var source = Source{ .io = std.Io.failing };
    if (source.decode(std.testing.allocator, format, input)) |value| {
        var image = value;
        defer image.deinit(std.testing.allocator);
        try std.testing.expect(image.width > 0 and image.width <= wallpaper.image_side_capacity);
        try std.testing.expect(image.height > 0 and image.height <= wallpaper.image_side_capacity);
        try std.testing.expectEqual(@as(usize, image.width) * image.height, image.pixels.len);
    } else |_| {}
}

// A stable array entry owns the wl_output and its layer. Geometry changes
// replace pixels, never the surface. Only registry removal or layer.closed
// retires that role. The array is never moved while callbacks borrow entries.
const Output = struct {
    id: ?u32 = null,
    proxy: ?*wl.wl_output = null,
    surface: ?*wl.wl_surface = null,
    layer: ?*wl.zwlr_layer_surface_v1 = null,
    viewport: ?*wl.wp_viewport = null,
    buffer: ?*wl.wl_buffer = null,
    facts: outputs.Facts = .{},
    suspended: bool = false,
    reopen_at: ?u64 = null,

    fn destroyRole(self: *Output) void {
        if (self.buffer) |buffer| wl.wl_buffer_destroy(buffer);
        if (self.viewport) |viewport| wl.wayspot_viewport_destroy(viewport);
        if (self.layer) |layer| wl.wayspot_layer_surface_destroy(layer);
        if (self.surface) |surface| wl.wl_surface_destroy(surface);
        self.buffer = null;
        self.viewport = null;
        self.layer = null;
        self.surface = null;
        self.facts.logical = null;
        self.facts.published = null;
    }

    fn destroy(self: *Output) void {
        self.destroyRole();
        if (self.proxy) |proxy| wl.wl_output_release(proxy);
        self.* = .{};
    }

    fn mayCreate(self: *Output, now: u64) bool {
        if (self.id == null or self.facts.pixels == null or self.surface != null) return false;
        if (!self.suspended) return true;
        // A closed role on a still-advertised output is exceptional.
        // Recover at a bounded deadline, not immediately in the callback.
        const end = self.reopen_at orelse blk: {
            self.reopen_at = now + 5000;
            break :blk self.reopen_at.?;
        };
        if (now < end) return false;
        self.suspended = false;
        self.reopen_at = null;
        return true;
    }

    fn createRole(self: *Output, display: *Display) !void {
        std.debug.assert(self.surface == null and self.proxy != null);
        self.surface = wl.wl_compositor_create_surface(display.compositor.?) orelse return error.SurfaceCreateFailed;
        errdefer self.destroyRole();
        const region = wl.wl_compositor_create_region(display.compositor.?) orelse return error.SurfaceRegionFailed;
        wl.wl_surface_set_input_region(self.surface.?, region);
        wl.wl_region_destroy(region);
        self.layer = wl.wayspot_layer_shell_get_surface(display.shell.?, self.surface.?, self.proxy.?, wl.WAYSPOT_LAYER_BACKGROUND, "wayspot-wallpaper") orelse return error.SurfaceLayerFailed;
        if (wl.wayspot_layer_surface_add_listener(self.layer.?, &layer_listener, self) != 0) return error.SurfaceLayerFailed;
        const layer = self.layer.?;
        wl.wayspot_layer_surface_set_size(layer, 0, 0);
        wl.wayspot_layer_surface_set_anchor(layer, wl.WAYSPOT_ANCHOR_TOP | wl.WAYSPOT_ANCHOR_BOTTOM | wl.WAYSPOT_ANCHOR_LEFT | wl.WAYSPOT_ANCHOR_RIGHT);
        wl.wayspot_layer_surface_set_exclusive_zone(layer, -1);
        wl.wayspot_layer_surface_set_keyboard(layer, wl.WAYSPOT_KEYBOARD_NONE);
        self.viewport = wl.wayspot_viewporter_get_viewport(display.viewporter.?, self.surface.?) orelse return error.SurfaceViewportFailed;
        wl.wl_surface_commit(self.surface.?);
    }
};

const Display = struct {
    connection: ?*wl.wl_display = null,
    registry: ?*wl.wl_registry = null,
    initial_sync: ?*wl.wl_callback = null,
    compositor: ?*wl.wl_compositor = null,
    shm: ?*wl.wl_shm = null,
    viewporter: ?*wl.wp_viewporter = null,
    shell: ?*wl.zwlr_layer_shell_v1 = null,
    records: [wallpaper.monitor_capacity]Output = @splat(.{}),
    ready: bool = false,
    failed: bool = false,

    fn connect(self: *Display) !void {
        self.connection = wl.wl_display_connect(null) orelse return error.WaylandConnectFailed;
        errdefer self.deinit();
        self.registry = wl.wl_display_get_registry(self.connection.?) orelse return error.WaylandRegistryFailed;
        if (wl.wl_registry_add_listener(self.registry.?, &registry_listener, self) != 0) return error.WaylandRegistryFailed;
        self.initial_sync = wl.wl_display_sync(self.connection.?) orelse return error.WaylandSyncFailed;
        if (wl.wl_callback_add_listener(self.initial_sync.?, &sync_listener, self) != 0) return error.WaylandSyncFailed;
    }

    fn deinit(self: *Display) void {
        if (self.connection) |connection| {
            // Never retain or recycle backing memory; even a compositor that
            // still references a retired wl_buffer owns its immutable SHM.
            for (&self.records) |*output| output.destroy();
            if (self.initial_sync) |sync| wl.wl_callback_destroy(sync);
            if (self.shell) |shell| wl.wayspot_layer_shell_destroy(shell);
            if (self.viewporter) |viewporter| wl.wayspot_viewporter_destroy(viewporter);
            if (self.shm) |shm| wl.wl_shm_destroy(shm);
            if (self.compositor) |compositor| wl.wl_compositor_destroy(compositor);
            if (self.registry) |registry| wl.wl_registry_destroy(registry);
            _ = wl.wl_display_flush(connection);
            wl.wl_display_disconnect(connection);
        }
        self.* = .{};
    }

    fn dispatch(self: *Display) !void {
        if (wl.wl_display_dispatch_pending(self.connection.?) < 0) return displayError(self.connection.?);
        if (self.failed) return error.WaylandOutputRegistrationFailed;
        if (self.ready and (self.compositor == null or self.shm == null or self.viewporter == null or self.shell == null)) return error.WaylandGlobalMissing;
    }

    fn ensureRoles(self: *Display, now: u64) !void {
        if (!self.ready) return;
        for (&self.records) |*output| {
            if (output.mayCreate(now)) try output.createRole(self);
        }
    }

    fn roleWake(self: *const Display, now: u64) ?u64 {
        var result: ?u64 = null;
        for (&self.records) |*output| if (output.reopen_at) |end| {
            result = if (result) |old| @min(old, end -| now) else end -| now;
        };
        return result;
    }

    fn count(self: *const Display) usize {
        var n: usize = 0;
        for (&self.records) |*output| if (output.id != null) {
            n += 1;
        };
        return n;
    }

    fn allReady(self: *const Display) bool {
        if (!self.ready) return false;
        var n: usize = 0;
        for (&self.records) |*output| {
            if (output.id == null) continue;
            if (output.suspended or output.facts.geometry() == null) return false;
            n += 1;
        }
        return n > 0;
    }

    const Plan = struct {
        targets: [wallpaper.monitor_capacity]?outputs.Geometry = @splat(null),
        count: usize = 0,
    };

    fn plan(self: *const Display, force: bool) !Plan {
        var result: Plan = .{};
        var pixels: u64 = 0;
        for (&self.records, 0..) |*output, i| {
            if (output.id == null or output.suspended) continue;
            const geometry = output.facts.geometry() orelse continue;
            pixels += @as(u64, geometry.pixels.width) * geometry.pixels.height;
            if (pixels > wallpaper.round_pixel_capacity) return error.RoundPixelsTooMany;
            if (!force and !output.facts.needsBuffer()) continue;
            result.targets[i] = geometry;
            result.count += 1;
        }
        return result;
    }

    fn publish(self: *Display, source: *Source, allocator: std.mem.Allocator, image: *const wallpaper.Image, pending: Plan, stop_fd: std.posix.fd_t) !void {
        try publishBuffers(*wl.wl_buffer, self, source, allocator, image, pending);
        try flush(source, self.connection.?, stop_fd);
        if (pending.count != 0) std.log.info("wallpaper published {d} output surfaces", .{self.publishedCount()});
    }

    fn discardBuffer(_: *Display, buffer: *wl.wl_buffer) void {
        wl.wl_buffer_destroy(buffer);
    }

    fn commitBuffer(self: *Display, index: usize, geometry: outputs.Geometry, buffer: *wl.wl_buffer) void {
        const output = &self.records[index];
        wl.wayspot_viewport_set_destination(output.viewport.?, @intCast(geometry.logical.width), @intCast(geometry.logical.height));
        wl.wl_surface_attach(output.surface.?, buffer, 0, 0);
        wl.wl_surface_damage_buffer(output.surface.?, 0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        wl.wl_surface_commit(output.surface.?);
        // wl_surface.attach permits destroying a committed wl_buffer before
        // release when its backing storage is never reused. No NULL attach,
        // release wait, frame callback, or second layer is necessary.
        if (output.buffer) |old| wl.wl_buffer_destroy(old);
        output.buffer = buffer;
        output.facts.published = geometry;
    }

    fn publishedCount(self: *const Display) usize {
        var n: usize = 0;
        for (&self.records) |*output| if (output.facts.published != null) {
            n += 1;
        };
        return n;
    }

    fn createBuffer(self: *Display, io: std.Io, pixels: *const wallpaper.Image) !*wl.wl_buffer {
        const length = pixels.pixels.len * @sizeOf(u32);
        const fd = try std.posix.memfd_create("wayspot-wallpaper", std.os.linux.MFD.CLOEXEC);
        defer _ = std.posix.system.close(fd);
        try (std.Io.File{ .handle = fd, .flags = .{ .nonblocking = false } }).setLength(io, length);
        const mapping = try std.posix.mmap(null, length, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);
        defer std.posix.munmap(mapping);
        @memcpy(mapping[0..length], std.mem.sliceAsBytes(pixels.pixels));
        const pool = wl.wl_shm_create_pool(self.shm.?, fd, @intCast(length)) orelse return error.SurfacePoolFailed;
        defer wl.wl_shm_pool_destroy(pool);
        const buffer = wl.wl_shm_pool_create_buffer(pool, 0, @intCast(pixels.width), @intCast(pixels.height), @intCast(pixels.pitch), wl.WL_SHM_FORMAT_XRGB8888) orelse return error.SurfaceBufferFailed;
        errdefer wl.wl_buffer_destroy(buffer);
        if (wl.wl_buffer_add_listener(buffer, &buffer_listener, null) != 0) return error.SurfaceBufferFailed;
        return buffer;
    }
};

// Prepare every required immutable buffer before touching any displayed
// content. Failed allocation/scale/buffer creation retires only candidates.
// The same bounded transaction is exercised by the failure-injection test.
fn publishBuffers(comptime Buffer: type, destination: anytype, source: anytype, allocator: std.mem.Allocator, image: *const wallpaper.Image, plan: Display.Plan) !void {
    var buffers: [wallpaper.monitor_capacity]?Buffer = @splat(null);
    errdefer for (&buffers) |*buffer| {
        if (buffer.*) |value| destination.discardBuffer(value);
    };
    for (plan.targets, 0..) |target, index| {
        const geometry = target orelse continue;
        var pixels = try wallpaper.coverImage(source, allocator, image, geometry.pixels.width, geometry.pixels.height);
        defer pixels.deinit(allocator);
        buffers[index] = try destination.createBuffer(source.io, &pixels);
    }
    for (plan.targets, 0..) |target, index| {
        const geometry = target orelse continue;
        destination.commitBuffer(index, geometry, buffers[index].?);
        buffers[index] = null;
    }
}

fn displayError(connection: *wl.wl_display) error{ WaylandDisplayLost, WaylandProtocolError } {
    return if (wl.wl_display_get_error(connection) == @backingInt(std.posix.E.PROTO)) error.WaylandProtocolError else error.WaylandDisplayLost;
}

const registry_listener = wl.wl_registry_listener{ .global = registryGlobal, .global_remove = registryRemove };
const sync_listener = wl.wl_callback_listener{ .done = registryReady };
fn registryReady(data: ?*anyopaque, callback: ?*wl.wl_callback, _: u32) callconv(.c) void {
    const self: *Display = @ptrCast(@alignCast(data));
    wl.wl_callback_destroy(callback);
    self.initial_sync = null;
    self.ready = true;
}

fn registryGlobal(data: ?*anyopaque, registry: ?*wl.wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const self: *Display = @ptrCast(@alignCast(data));
    const name = std.mem.span(interface);
    if (std.mem.eql(u8, name, "wl_output")) {
        if (version < 3) {
            self.failed = true;
            return;
        }
        const output = for (&self.records) |*entry| {
            if (entry.id == null) break entry;
        } else {
            self.failed = true;
            return;
        };
        output.* = .{ .id = id };
        output.proxy = @ptrCast(wl.wl_registry_bind(registry, id, &wl.wl_output_interface, @min(version, 4)));
        if (output.proxy == null or wl.wl_output_add_listener(output.proxy.?, &output_listener, output) != 0) self.failed = true;
    } else if (std.mem.eql(u8, name, "wl_compositor") and self.compositor == null and version >= 4) {
        self.compositor = @ptrCast(wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 4));
    } else if (std.mem.eql(u8, name, "wl_shm") and self.shm == null and version >= 1) {
        self.shm = @ptrCast(wl.wl_registry_bind(registry, id, &wl.wl_shm_interface, 1));
    } else if (std.mem.eql(u8, name, "wp_viewporter") and self.viewporter == null and version >= 1) {
        self.viewporter = @ptrCast(wl.wl_registry_bind(registry, id, wl.wayspot_viewporter_interface(), 1));
    } else if (std.mem.eql(u8, name, "zwlr_layer_shell_v1") and self.shell == null and version >= 1) {
        self.shell = @ptrCast(wl.wl_registry_bind(registry, id, wl.wayspot_layer_shell_interface(), @min(version, 3)));
    }
}

fn registryRemove(data: ?*anyopaque, _: ?*wl.wl_registry, id: u32) callconv(.c) void {
    const self: *Display = @ptrCast(@alignCast(data));
    for (&self.records) |*output| if (output.id == id) {
        output.destroy();
        return;
    };
}

const output_listener = wl.wl_output_listener{ .geometry = outputGeometry, .mode = outputMode, .done = outputDone, .scale = outputScale, .name = outputName, .description = outputDescription };
fn outputGeometry(data: ?*anyopaque, _: ?*wl.wl_output, _: i32, _: i32, _: i32, _: i32, _: i32, _: [*c]const u8, _: [*c]const u8, transform: i32) callconv(.c) void {
    const output: *Output = @ptrCast(@alignCast(data));
    output.facts.transform = std.math.cast(u3, transform);
}
fn outputMode(data: ?*anyopaque, _: ?*wl.wl_output, flags: u32, width: i32, height: i32, _: i32) callconv(.c) void {
    if (flags & wl.WL_OUTPUT_MODE_CURRENT == 0) return;
    const output: *Output = @ptrCast(@alignCast(data));
    output.facts.mode = if (width > 0 and height > 0) .{ .width = @intCast(width), .height = @intCast(height) } else null;
}
fn outputDone(data: ?*anyopaque, _: ?*wl.wl_output) callconv(.c) void {
    const output: *Output = @ptrCast(@alignCast(data));
    if (output.facts.done() catch |err| {
        std.log.warn("wallpaper output geometry refused: {s}", .{@errorName(err)});
        return;
    }) {
        output.suspended = false;
        output.reopen_at = null;
    }
}
fn outputScale(_: ?*anyopaque, _: ?*wl.wl_output, _: i32) callconv(.c) void {}
fn outputName(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}
fn outputDescription(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}

const layer_listener = wl.wayspot_layer_listener{ .configure = layerConfigure, .closed = layerClosed };
fn layerConfigure(data: ?*anyopaque, layer: ?*wl.zwlr_layer_surface_v1, serial: u32, width: u32, height: u32) callconv(.c) void {
    const output: *Output = @ptrCast(@alignCast(data));
    if (layer) |proxy| wl.wayspot_layer_surface_ack_configure(proxy, serial);
    // A zero dimension means the client may choose. This fully anchored role
    // needs a real output size; keep existing content until it is available.
    _ = wallpaper.surfacePixelCount(width, height) catch {
        output.facts.logical = null;
        return;
    };
    output.facts.logical = .{ .width = width, .height = height };
}
fn layerClosed(data: ?*anyopaque, _: ?*wl.zwlr_layer_surface_v1) callconv(.c) void {
    const output: *Output = @ptrCast(@alignCast(data));
    output.destroyRole();
    output.suspended = true;
    output.reopen_at = null;
    std.log.warn("wallpaper role closed on output {d}", .{output.id orelse 0});
}
const buffer_listener = wl.wl_buffer_listener{ .release = bufferReleased };
fn bufferReleased(_: ?*anyopaque, _: ?*wl.wl_buffer) callconv(.c) void {}

const Ready = struct { stop: bool = false, rotate: bool = false, client: bool = false };
const poll_failure = std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL;

// One blocking wait over real readiness. No frame callback or periodic poll.
fn wait(source: *Source, connection: ?*wl.wl_display, stop_fd: std.posix.fd_t, timeout: ?u64) !Ready {
    var prepared = false;
    defer if (prepared) wl.wl_display_cancel_read(connection.?);
    var events: i16 = std.posix.POLL.IN;
    if (connection) |display| {
        if (wl.wl_display_prepare_read(display) != 0) return .{};
        prepared = true;
        const result = wl.wl_display_flush(display);
        if (result < 0) {
            if (std.posix.errno(result) != .AGAIN) return displayError(display);
            events |= std.posix.POLL.OUT;
        }
    }
    var fds = [_]std.posix.pollfd{
        .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = if (connection) |display| wl.wl_display_get_fd(display) else -1, .events = events, .revents = 0 },
        .{ .fd = source.rotate_listener, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = source.rotate_client, .events = std.posix.POLL.IN, .revents = 0 },
    };
    _ = try std.posix.poll(&fds, if (timeout) |ms| @intCast(@min(ms, std.math.maxInt(i32))) else -1);
    if (fds[0].revents != 0) {
        try Stop.consume(source.io, stop_fd);
        return .{ .stop = true };
    }
    if (connection) |display| {
        if (fds[1].revents & std.posix.POLL.IN != 0) {
            prepared = false;
            if (wl.wl_display_read_events(display) < 0) return displayError(display);
        } else if (fds[1].revents & poll_failure != 0) return displayError(display);
    }
    if (fds[2].revents & poll_failure != 0) return error.RotationListenerLost;
    return .{ .rotate = fds[2].revents != 0 or fds[3].revents != 0, .client = fds[3].revents != 0 };
}

// Receipt means the commit requests were written, not a frame was displayed.
fn flush(source: *Source, connection: *wl.wl_display, stop_fd: std.posix.fd_t) !void {
    const deadline = source.now() + 1000;
    while (true) {
        const result = wl.wl_display_flush(connection);
        if (result >= 0) return;
        if (std.posix.errno(result) != .AGAIN) return displayError(connection);
        const remaining = deadline -| source.now();
        if (remaining == 0) return error.WaylandDisplayLost;
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = wl.wl_display_get_fd(connection), .events = std.posix.POLL.OUT, .revents = 0 },
        };
        if (try std.posix.poll(&fds, @intCast(remaining)) == 0) return error.WaylandDisplayLost;
        if (fds[0].revents != 0) {
            try Stop.consume(source.io, stop_fd);
            return error.Stopped;
        }
        if (fds[1].revents & poll_failure != 0) return displayError(connection);
    }
}

pub fn run(init: std.process.Init, root_path: []const u8) !void {
    var catalog = try discoverCatalog(init.io, init.gpa, root_path);
    defer catalog.deinit();
    const signature = try sessionIdentifier(init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.RuntimeDirectoryMissing, init.environ_map.get("WAYLAND_DISPLAY") orelse return error.WaylandDisplayMissing);
    var source: Source = .{ .io = init.io };
    try source.openRotation(&signature);
    defer source.closeRotation();
    const stop = try Stop.open();
    defer stop.close();
    var first = try wallpaper.choose(&source, init.gpa, &catalog);
    first.image.deinit(init.gpa);
    var selected = first.encoded;
    defer selected.deinit(init.gpa);
    catalog.published = first.index;
    var schedule: wallpaper.Schedule = .{};
    // Recover the selected endpoint on transport loss. A protocol fault is
    // not a recoverable disconnect. Session teardown stops this process.
    while (true) {
        var display: Display = .{};
        const result = result: {
            display.connect() catch |err| break :result err;
            break :result serve(&display, &source, init.gpa, &catalog, &selected, &schedule, stop.fd);
        };
        display.deinit();
        result catch |err| switch (err) {
            error.Stopped => return,
            error.WaylandDisplayLost, error.WaylandConnectFailed => {
                source.replyRotation(false);
                std.log.warn("wallpaper connection unavailable: {s}", .{@errorName(err)});
                const ready = try wait(&source, null, stop.fd, 1000);
                if (ready.stop) return;
                if (ready.rotate) {
                    _ = source.receiveRotation() catch false;
                    source.replyRotation(false);
                }
                continue;
            },
            else => return err,
        };
        return;
    }
}

fn serve(display: *Display, source: *Source, allocator: std.mem.Allocator, catalog: *wallpaper.Catalog, selected: *wallpaper.EncodedImage, schedule: *wallpaper.Schedule, stop_fd: std.posix.fd_t) !void {
    var direct = false;
    var request_deadline: ?u64 = null;
    var retry_at: ?u64 = null;
    while (true) {
        try display.dispatch();
        const now = source.now();
        try display.ensureRoles(now);
        if (request_deadline) |end| {
            if (now >= end or (direct and display.ready and display.count() == 0)) {
                source.replyRotation(false);
                direct = false;
                request_deadline = null;
            }
        }
        // A direct request may expedite recovery of a closed background role.
        if (direct or schedule.due(now, display.allReady())) {
            if (display.allReady()) {
                const success = rotate(display, source, allocator, catalog, selected, stop_fd) catch |err| switch (err) {
                    error.Stopped, error.WaylandDisplayLost, error.WaylandProtocolError => return err,
                    else => blk: {
                        std.log.warn("wallpaper rotation refused: {s}", .{@errorName(err)});
                        break :blk false;
                    },
                };
                try schedule.attempted(source.now(), direct, success);
                if (direct) {
                    source.replyRotation(success);
                    direct = false;
                    request_deadline = null;
                }
            }
        }
        if (retry_at == null or now >= retry_at.?) {
            retry_at = null;
            const pending = display.plan(false) catch |err| {
                std.log.warn("wallpaper geometry refused: {s}", .{@errorName(err)});
                retry_at = now + 1000;
                continue;
            };
            if (pending.count != 0) {
                const result = result: {
                    var image = wallpaper.decodeImage(source, allocator, selected) catch |err| break :result err;
                    defer image.deinit(allocator);
                    break :result display.publish(source, allocator, &image, pending, stop_fd);
                };
                result catch |err| switch (err) {
                    error.Stopped, error.WaylandDisplayLost, error.WaylandProtocolError => return err,
                    else => {
                        std.log.warn("wallpaper publication refused: {s}", .{@errorName(err)});
                        retry_at = source.now() + 1000;
                    },
                };
                if (retry_at == null and schedule.deadline == null) try schedule.advance(source.now());
            }
        }
        const current = source.now();
        var timeout = schedule.wake(current, display.allReady());
        for ([_]?u64{ request_deadline, retry_at }) |deadline| if (deadline) |end| {
            timeout = if (timeout) |old| @min(old, end -| current) else end -| current;
        };
        if (display.roleWake(current)) |delay| timeout = if (timeout) |old| @min(old, delay) else delay;
        const ready = try wait(source, display.connection, stop_fd, timeout);
        if (ready.stop) return error.Stopped;
        if (ready.rotate) {
            if (direct) {
                source.rejectBusy();
                if (ready.client) {
                    source.replyRotation(false);
                    direct = false;
                    request_deadline = null;
                }
            } else {
                direct = source.receiveRotation() catch |err| blk: {
                    std.log.warn("wallpaper rotation request refused: {s}", .{@errorName(err)});
                    source.replyRotation(false);
                    break :blk false;
                };
                if (source.rotate_client < 0) {
                    request_deadline = null;
                } else if (request_deadline == null) request_deadline = source.now() + 2000;
                if (direct) for (&display.records) |*output| {
                    output.suspended = false;
                    output.reopen_at = null;
                };
            }
        }
    }
}

fn rotate(display: *Display, source: *Source, allocator: std.mem.Allocator, catalog: *wallpaper.Catalog, selected: *wallpaper.EncodedImage, stop_fd: std.posix.fd_t) !bool {
    std.debug.assert(display.allReady());
    const pending = try display.plan(true);
    var candidate = try wallpaper.choose(source, allocator, catalog);
    defer candidate.image.deinit(allocator);
    errdefer candidate.encoded.deinit(allocator);
    try display.publish(source, allocator, &candidate.image, pending, stop_fd);
    selected.deinit(allocator);
    selected.* = candidate.encoded;
    catalog.published = candidate.index;
    return true;
}

test "unrelated globals and repeated configure events do not invalidate a background" {
    var display: Display = .{ .ready = true };
    const output = &display.records[0];
    output.* = .{ .id = 1, .facts = .{ .pixels = .{ .width = 1920, .height = 1080 }, .logical = .{ .width = 1280, .height = 720 } } };
    output.facts.published = output.facts.geometry();
    for (1..1001) |id| {
        registryGlobal(&display, null, @intCast(id), "wl_seat", 9);
        layerConfigure(output, null, @intCast(id), 1280, 720);
        try std.testing.expectEqual(@as(usize, 0), (try display.plan(false)).count);
    }
    try std.testing.expect(!display.failed and display.allReady());
    layerConfigure(output, null, 1001, 1920, 1080);
    try std.testing.expectEqual(@as(usize, 1), (try display.plan(false)).count);
}

test "plan retains survivors and rotates all current outputs without recreating roles" {
    var display: Display = .{ .ready = true };
    const facts: outputs.Facts = .{ .pixels = .{ .width = 1920, .height = 1080 }, .logical = .{ .width = 1280, .height = 720 } };
    display.records[0] = .{ .id = 1, .facts = facts };
    display.records[0].facts.published = facts.geometry();
    display.records[1] = .{ .id = 2, .facts = facts };
    const add = try display.plan(false);
    try std.testing.expectEqual(@as(usize, 1), add.count);
    try std.testing.expect(add.targets[0] == null and add.targets[1] != null);
    try std.testing.expectEqual(@as(usize, 2), (try display.plan(true)).count);
    registryRemove(&display, null, 2);
    try std.testing.expectEqual(@as(usize, 0), (try display.plan(false)).count);
    registryRemove(&display, null, 1);
    try std.testing.expect(!display.allReady());
    try std.testing.expectEqual(@as(usize, 0), (try display.plan(true)).count);
}

test "closed role recovery has a deadline and disappears with its output" {
    var display: Display = .{ .ready = true };
    const output = &display.records[0];
    output.* = .{ .id = 1, .facts = .{ .pixels = .{ .width = 1280, .height = 720 } }, .suspended = true };
    try std.testing.expect(!output.mayCreate(10));
    try std.testing.expectEqual(@as(?u64, 5000), display.roleWake(10));
    try std.testing.expect(!output.mayCreate(5009));
    try std.testing.expect(output.mayCreate(5010));
    try std.testing.expect(display.roleWake(5010) == null);
    output.suspended = true;
    try std.testing.expect(!output.mayCreate(6000));
    registryRemove(&display, null, 1);
    try std.testing.expect(display.roleWake(6000) == null);
    try std.testing.expect(!output.mayCreate(12000));
}

test "total output bound refuses a rotation without changing existing geometry" {
    var display: Display = .{ .ready = true };
    const facts: outputs.Facts = .{
        .pixels = .{ .width = 7680, .height = 4320 },
        .logical = .{ .width = 3840, .height = 2160 },
    };
    for (display.records[0..3], 0..) |*output, index| {
        output.* = .{ .id = @intCast(index + 1), .facts = facts };
        output.facts.published = facts.geometry();
    }
    try std.testing.expectError(error.RoundPixelsTooMany, display.plan(true));
    for (display.records[0..3]) |output| try std.testing.expect(!output.facts.needsBuffer());
}

test "stop readiness takes priority over rotation" {
    var fds: [2]std.posix.fd_t = undefined;
    const result = std.posix.system.socketpair(std.posix.AF.UNIX, std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC, 0, &fds);
    try std.testing.expectEqual(std.posix.E.SUCCESS, std.posix.errno(result));
    defer _ = std.posix.system.close(fds[0]);
    defer _ = std.posix.system.close(fds[1]);
    const writer: std.Io.File = .{ .handle = fds[1], .flags = .{ .nonblocking = false } };
    try writer.writeStreamingAll(std.testing.io, &(@as([128]u8, @splat(0))));
    var source: Source = .{ .io = std.testing.io };
    try source.openRotation("wallpaper-stop-priority-test");
    defer source.closeRotation();
    const client = try connectRotationTest("wallpaper-stop-priority-test");
    defer _ = std.posix.system.close(client);
    const ready = try wait(&source, null, fds[0], 100);
    try std.testing.expect(ready.stop and !ready.rotate);
}

test "all buffer preparation precedes every commit and failures discard only candidates" {
    const Target = struct {
        created: usize = 0,
        committed: usize = 0,
        discarded: usize = 0,
        fail_at: ?usize = null,

        fn createBuffer(self: *@This(), _: std.Io, _: *const wallpaper.Image) !usize {
            if (self.fail_at == self.created) return error.SurfaceBufferFailed;
            self.created += 1;
            return self.created;
        }
        fn discardBuffer(self: *@This(), buffer: usize) void {
            std.debug.assert(buffer > 0 and buffer <= self.created);
            self.discarded += 1;
        }
        fn commitBuffer(self: *@This(), _: usize, _: outputs.Geometry, buffer: usize) void {
            std.debug.assert(self.created == 3 and self.discarded == 0);
            std.debug.assert(buffer == self.committed + 1);
            self.committed += 1;
        }
    };
    var source: Source = .{ .io = std.testing.io };
    var pixel = [_]u32{0xff203040};
    const image: wallpaper.Image = .{ .width = 1, .height = 1, .pitch = 4, .pixels = &pixel };
    const geometry: outputs.Geometry = .{ .pixels = .{ .width = 2, .height = 2 }, .logical = .{ .width = 2, .height = 2 } };
    var plan: Display.Plan = .{ .count = 3 };
    plan.targets[0] = geometry;
    plan.targets[2] = geometry;
    plan.targets[5] = geometry;
    for (0..3) |failure| {
        var target: Target = .{ .fail_at = failure };
        try std.testing.expectError(error.SurfaceBufferFailed, publishBuffers(usize, &target, &source, std.testing.allocator, &image, plan));
        try std.testing.expectEqual(failure, target.created);
        try std.testing.expectEqual(failure, target.discarded);
        try std.testing.expectEqual(@as(usize, 0), target.committed);
        target = .{};
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        try std.testing.expectError(error.OutOfMemory, publishBuffers(usize, &target, &source, failing.allocator(), &image, plan));
        try std.testing.expectEqual(failure, target.discarded);
        try std.testing.expectEqual(@as(usize, 0), target.committed);
    }
    var success: Target = .{};
    try publishBuffers(usize, &success, &source, std.testing.allocator, &image, plan);
    try std.testing.expectEqual(@as(usize, 3), success.committed);
    try std.testing.expectEqual(@as(usize, 0), success.discarded);
}
