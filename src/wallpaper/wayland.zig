//! One Wayland connection and one persistent background surface per output.

const std = @import("std");
const wallpaper = @import("root.zig");
const sdl = @import("wattle").sdl;
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
extern fn wayspot_jpeg_free(pixels: [*]u8) callconv(.c) void;

/// Discovers one fresh bounded catalogue from the configured directory.
pub fn discoverCatalog(io: std.Io, allocator: std.mem.Allocator, root_path: []const u8) !wallpaper.Catalog {
    var source = Discovery{ .io = io };
    return wallpaper.collectCatalog(&source, allocator, root_path);
}

const Discovery = struct {
    io: std.Io,
    root: ?std.Io.Dir = null,
    iterator: std.Io.Dir.Iterator = undefined,

    /// Acquires a non-followed directory and its borrowed iterator.
    pub fn openRoot(source: *Discovery, path: []const u8) !void {
        std.debug.assert(source.root == null);
        const root = try std.Io.Dir.openDirAbsolute(source.io, path, .{
            .iterate = true,
            .follow_symlinks = false,
        });
        source.root = root;
        source.iterator = root.iterate();
    }

    /// Retires the iterator's directory handle.
    pub fn closeRoot(source: *Discovery) void {
        source.root.?.close(source.io);
        source.root = null;
    }

    /// Borrows the next directory entry until the next iterator operation.
    pub fn nextEntry(source: *Discovery) !?wallpaper.CatalogEntry {
        const entry = try source.iterator.next(source.io) orelse return null;
        return .{ .name = entry.name, .kind = entry.kind };
    }

    /// Resolves an unknown entry kind without following its final symlink.
    pub fn statEntry(source: *Discovery, name: []const u8) !std.Io.File.Kind {
        return (try source.root.?.statFile(source.io, name, .{ .follow_symlinks = false })).kind;
    }

    /// Obtains one independent catalogue shuffle seed.
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
    /// Acquires a regular image candidate without following its final symlink.
    pub fn open(source: *Source, path: []const u8) !void {
        std.debug.assert(source.file == null);
        // A catalogue path can change after discovery. Refuse known special
        // files and symlinks before opening, then use a nonblocking, nofollow
        // open so replacement with a FIFO cannot wait for a writer.
        const cwd = std.Io.Dir.cwd();
        const known = try cwd.statFile(source.io, path, .{ .follow_symlinks = false });
        if (known.kind != .file) return error.ImageNotRegularFile;
        const fd = try std.posix.openat(cwd.handle, path, .{
            .ACCMODE = .RDONLY,
            .CLOEXEC = true,
            .NONBLOCK = true,
            .NOFOLLOW = true,
            .NOCTTY = true,
        }, 0);
        // readEncodedImage stats this actual descriptor before reading.
        source.file = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    }

    /// Reports the actual acquired image descriptor kind and byte extent.
    pub fn stat(source: *Source) !struct { kind: std.Io.File.Kind, size: u64 } {
        const value = try (source.file orelse return error.ImageFileNotOpen).stat(source.io);
        return .{ .kind = value.kind, .size = value.size };
    }

    /// Reads at offset zero through the acquired image descriptor.
    pub fn read(source: *Source, bytes: []u8) !usize {
        return (source.file orelse return error.ImageFileNotOpen).readPositionalAll(source.io, bytes, 0);
    }

    /// Retires the descriptor acquired by the image reader.
    pub fn close(source: *Source) void {
        const file = source.file orelse {
            std.debug.assert(false);
            return;
        };
        source.file = null;
        file.close(source.io);
    }

    fn openRotation(source: *Source, signature: []const u8) !void {
        try source.bindRotation(signature, true);
    }

    fn bindRotation(source: *Source, signature: []const u8, listen: bool) !void {
        if (source.rotate_listener >= 0 or source.rotate_client >= 0)
            return error.RotationAlreadyOpen;
        const address = try abstractAddress(signature);
        const fd = try rotationSocket();
        errdefer closeFd(fd);
        // zig-audit: acknowledge ptr_cast
        // reason: Linux bind borrows an exact-length abstract AF_UNIX address.
        switch (std.os.linux.errno(std.os.linux.bind(fd, @ptrCast(&address.value), address.length))) {
            .SUCCESS => {},
            .ADDRINUSE => return error.RotationNameInUse,
            else => return error.RotationSocketBindFailed,
        }
        if (listen and std.os.linux.errno(std.os.linux.listen(fd, 4)) != .SUCCESS)
            return error.RotationSocketListenFailed;
        source.rotate_listener = fd;
    }

    fn closeClient(source: *Source) void {
        if (source.rotate_client >= 0) closeFd(source.rotate_client);
        source.rotate_client = -1;
        source.rotate_length = 0;
    }

    fn closeRotation(source: *Source) void {
        source.closeClient();
        if (source.rotate_listener >= 0) closeFd(source.rotate_listener);
        source.rotate_listener = -1;
    }

    fn acceptRotation(source: *Source) !?std.posix.fd_t {
        const linux = std.os.linux;
        const result = linux.accept4(
            source.rotate_listener,
            null,
            null,
            std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        );
        switch (linux.errno(result)) {
            .SUCCESS => {},
            .AGAIN, .INTR => return null,
            else => return error.RotationAcceptFailed,
        }
        const fd: std.posix.fd_t = @intCast(result);
        errdefer closeFd(fd);
        try authenticatePeer(fd, linux.geteuid());
        return fd;
    }

    fn receiveRotation(source: *Source) !bool {
        if (source.rotate_client >= 0) source.rejectBusy();
        if (source.rotate_client < 0) {
            source.rotate_client = (try source.acceptRotation()) orelse return false;
            std.debug.assert(source.rotate_length == 0);
        }
        const suffix = source.rotate_bytes[source.rotate_length..];
        const count = try receiveBytes(source.rotate_client, suffix) orelse return false;
        if (count == 0) return error.RotationRequestIncomplete;
        source.rotate_length += @intCast(count);
        return switch (wallpaper.classifyRotationRequest(
            source.rotate_bytes[0..source.rotate_length],
        )) {
            .incomplete => false,
            .rotate => true,
            .invalid => error.RotationRequestInvalid,
        };
    }

    fn rejectBusy(source: *Source) void {
        const fd = (source.acceptRotation() catch |err| {
            std.log.warn("wallpaper busy peer refused: {s}", .{@errorName(err)});
            return;
        }) orelse return;
        defer closeFd(fd);
        // Best effort: retire one bounded queued prefix before closing.
        // No request from this descriptor is admitted.
        var ignored: [16]u8 = undefined;
        if (receiveBytes(fd, &ignored)) |received| {
            if (received) |count| std.debug.assert(count <= ignored.len);
        } else |err| {
            std.log.warn("wallpaper busy request read failed: {s}", .{@errorName(err)});
        }
        sendReceipt(fd, false);
    }

    fn replyRotation(source: *Source, success: bool) void {
        if (source.rotate_client < 0) return;
        defer source.closeClient();
        sendReceipt(source.rotate_client, success);
    }

    /// Returns the borrowed I/O clock in monotonic milliseconds for bounded waits.
    pub fn now(source: *Source) u64 {
        return @intCast(std.Io.Clock.awake.now(source.io).toMilliseconds());
    }

    /// Decodes admitted image bytes into an owned XRGB8888 allocation.
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

    /// Scales a validated crop into caller-owned destination pixels.
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
            image.pixels.ptr,
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

const Credentials = extern struct {
    pid: std.os.linux.pid_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
};

fn closeFd(fd: std.posix.fd_t) void {
    // Linux retires the descriptor even when close reports EINTR.
    switch (std.os.linux.errno(std.os.linux.close(fd))) {
        .SUCCESS, .INTR => {},
        else => |err| std.log.err("wallpaper descriptor close failed: {s}", .{@tagName(err)}),
    }
}

fn rotationSocket() !std.posix.fd_t {
    const linux = std.os.linux;
    const result = linux.socket(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        0,
    );
    if (linux.errno(result) != .SUCCESS) return error.RotationSocketOpenFailed;
    return @intCast(result);
}

fn authenticatePeer(fd: std.posix.fd_t, expected_uid: c_uint) !void {
    const linux = std.os.linux;
    var credentials: Credentials = undefined;
    var length: std.posix.socklen_t = @sizeOf(Credentials);
    const result = linux.getsockopt(
        fd,
        std.posix.SOL.SOCKET,
        linux.SO.PEERCRED,
        std.mem.asBytes(&credentials),
        &length,
    );
    if (linux.errno(result) != .SUCCESS or length != @sizeOf(Credentials))
        return error.RotationPeerCredentialsFailed;
    try requireUid(credentials.uid, expected_uid);
}

fn requireUid(actual: c_uint, expected: c_uint) !void {
    if (actual != expected) return error.RotationPeerInvalid;
}

// A null result means no progress; zero bytes means the peer ended its stream.
fn receiveBytes(fd: std.posix.fd_t, bytes: []u8) !?usize {
    std.debug.assert(bytes.len > 0);
    const linux = std.os.linux;
    const result = linux.recvfrom(fd, bytes.ptr, bytes.len, linux.MSG.DONTWAIT, null, null);
    return switch (linux.errno(result)) {
        .SUCCESS => result,
        .AGAIN, .INTR => null,
        else => error.RotationSocketReadFailed,
    };
}

fn sendBytes(fd: std.posix.fd_t, bytes: []const u8) !?usize {
    std.debug.assert(bytes.len > 0);
    const linux = std.os.linux;
    const result = linux.sendto(
        fd,
        bytes.ptr,
        bytes.len,
        linux.MSG.DONTWAIT | linux.MSG.NOSIGNAL,
        null,
        0,
    );
    return switch (linux.errno(result)) {
        .SUCCESS => result,
        .AGAIN, .INTR => null,
        else => error.RotationSocketWriteFailed,
    };
}

fn sendReceipt(fd: std.posix.fd_t, success: bool) void {
    const bytes = if (success) "ok\n" else "error\n";
    const count = sendBytes(fd, bytes) catch |err| {
        std.log.warn("wallpaper receipt failed: {s}", .{@errorName(err)});
        return;
    };
    if (count == null or count.? != bytes.len)
        std.log.warn("wallpaper receipt incomplete", .{});
}

fn connectRotation(
    io: std.Io,
    fd: std.posix.fd_t,
    address: AbstractAddress,
    started: std.Io.Timestamp,
) !void {
    const linux = std.os.linux;
    switch (linux.errno(linux.connect(fd, &address.value, address.length))) {
        .SUCCESS => {},
        .INPROGRESS => {
            try pollDirect(io, fd, std.posix.POLL.OUT, started);
            var socket_error: c_int = 0;
            var length: std.posix.socklen_t = @sizeOf(c_int);
            const result = linux.getsockopt(
                fd,
                std.posix.SOL.SOCKET,
                linux.SO.ERROR,
                std.mem.asBytes(&socket_error),
                &length,
            );
            if (linux.errno(result) != .SUCCESS or length != @sizeOf(c_int))
                return error.RotationSocketConnectFailed;
            if (socket_error != 0) return switch (socket_error) {
                @backingInt(linux.E.CONNREFUSED) => error.WallpaperResidentUnavailable,
                @backingInt(linux.E.TIMEDOUT) => error.RotationTimedOut,
                else => error.RotationSocketConnectFailed,
            };
        },
        .CONNREFUSED => return error.WallpaperResidentUnavailable,
        else => return error.RotationSocketConnectFailed,
    }
    try authenticatePeer(fd, linux.geteuid());
}

/// Sends the legacy newline command and requires an exact close-delimited receipt.
pub fn requestRotation(io: std.Io, signature: []const u8) !void {
    const started = std.Io.Clock.awake.now(io);
    const address = try abstractAddress(signature);
    const fd = try rotationSocket();
    defer closeFd(fd);
    try connectRotation(io, fd, address, started);
    var written: usize = 0;
    const command = "rotate\n";
    for (0..16) |_| {
        try pollDirect(io, fd, std.posix.POLL.OUT, started);
        const count = try sendBytes(fd, command[written..]) orelse continue;
        written += count;
        if (written == command.len) break;
    }
    if (written != command.len) return error.RotationRequestIncomplete;
    try readReceipt(io, fd, started);
}

fn readReceipt(io: std.Io, fd: std.posix.fd_t, started: std.Io.Timestamp) !void {
    // The legacy server closes after replying. A matching prefix alone
    // does not prove the receipt ended; a later fragment could invalidate it.
    var reply: [16]u8 = undefined;
    var used: usize = 0;
    for (0..16) |_| {
        try pollDirect(io, fd, std.posix.POLL.IN, started);
        const count = try receiveBytes(fd, reply[used..]) orelse continue;
        if (count == 0) {
            if (std.mem.eql(u8, reply[0..used], "ok\n")) return;
            return error.RotationRejected;
        }
        used += count;
        if (used > "ok\n".len or !std.mem.eql(u8, reply[0..used], "ok\n"[0..used]))
            return error.RotationRejected;
    }
    return error.RotationRejected;
}

const rotation_request_timeout_milliseconds = 30_000;

fn requestMillisecondsRemaining(elapsed: i64) !i32 {
    if (elapsed >= rotation_request_timeout_milliseconds) return error.RotationTimedOut;
    if (elapsed < 0) return error.RotationClockInvalid;
    return @intCast(rotation_request_timeout_milliseconds - elapsed);
}

fn pollDirect(io: std.Io, fd: std.posix.fd_t, events: i16, started: std.Io.Timestamp) !void {
    const linux = std.os.linux;
    var descriptors = [1]std.posix.pollfd{.{ .fd = fd, .events = events, .revents = 0 }};
    while (true) {
        const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
        const remaining = try requestMillisecondsRemaining(elapsed);
        const result = linux.poll(&descriptors, descriptors.len, remaining);
        switch (linux.errno(result)) {
            .SUCCESS => break,
            .INTR => {
                try io.checkCancel();
                continue;
            },
            else => return error.RotationSocketFailed,
        }
    }
    if (descriptors[0].revents == 0) return error.RotationTimedOut;
    if (descriptors[0].revents & (std.posix.POLL.ERR | std.posix.POLL.NVAL) != 0)
        return error.RotationSocketFailed;
    if (events == std.posix.POLL.OUT and descriptors[0].revents & std.posix.POLL.HUP != 0)
        return error.RotationSocketFailed;
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
    const count = try wallpaper.surfacePixelCount(width, height);
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
    const encoded: wallpaper.EncodedImage = .{ .format = .png, .bytes = png };
    var image = try wallpaper.decodeImage(&source, std.testing.allocator, &encoded);
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
    std.mem.writeInt(u32, png[8..12], 13, .big);
    @memcpy(png[12..16], "IHDR");
    std.mem.writeInt(u32, png[16..20], 1, .big);
    std.mem.writeInt(u32, png[20..24], 1, .big);
    var source = Source{ .io = std.testing.io };
    try std.testing.expectError(
        error.ImageDecodeFailed,
        wallpaper.decodeImage(
            &source,
            std.testing.allocator,
            &.{ .format = .png, .bytes = &png },
        ),
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
    const image_bytes: wallpaper.EncodedImage = .{ .format = .jpeg, .bytes = &bytes };
    var image = try wallpaper.decodeImage(&source, std.testing.allocator, &image_bytes);
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
        const ready = try waitRotationTest(&resident, -1, 100);
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
    defer closeFd(client);
    const file: std.Io.File = .{ .handle = client, .flags = .{ .nonblocking = true } };
    try file.writeStreamingAll(std.testing.io, "rot");
    while (!(try waitRotationTest(&resident, -1, 100)).rotate) {}
    try std.testing.expect(!try resident.receiveRotation());
    try file.writeStreamingAll(std.testing.io, "ate\n");
    while (!(try waitRotationTest(&resident, -1, 100)).rotate) {}
    try std.testing.expect(try resident.receiveRotation());

    var busy = try std.testing.io.concurrent(requestRotation, .{ std.testing.io, signature });
    while (!(try waitRotationTest(&resident, -1, 100)).rotate) {}
    resident.rejectBusy();
    if (busy.await(std.testing.io)) |_| return error.BusyRequestAccepted else |err| {
        try std.testing.expect(err == error.RotationRejected or err == error.RotationSocketFailed);
    }
    resident.replyRotation(true);

    const disconnected = try connectRotationTest(signature);
    closeFd(disconnected);
    while (!(try waitRotationTest(&resident, -1, 100)).rotate) {}
    try std.testing.expectError(error.RotationRequestIncomplete, resident.receiveRotation());
    resident.replyRotation(false);
    const ready = try waitRotationTest(&resident, -1, 0);
    try std.testing.expect(!ready.rotate);
}

fn connectRotationTest(signature: []const u8) !std.posix.fd_t {
    const address = try abstractAddress(signature);
    const fd = try rotationSocket();
    errdefer closeFd(fd);
    try connectRotation(std.testing.io, fd, address, std.Io.Clock.awake.now(std.testing.io));
    return fd;
}

test "rotation request has one exact total wait bound" {
    try std.testing.expectError(error.RotationClockInvalid, requestMillisecondsRemaining(-1));
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
    const encoded: wallpaper.EncodedImage = .{ .format = format, .bytes = input };
    if (wallpaper.decodeImage(&source, std.testing.allocator, &encoded)) |value| {
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
            self.reopen_at = now +| 5000;
            break :blk self.reopen_at.?;
        };
        if (now < end) return false;
        self.suspended = false;
        self.reopen_at = null;
        return true;
    }

    fn configure(self: *Output, width: u32, height: u32) void {
        // A zero dimension means the client may choose. This fully anchored
        // role needs a real size; retain existing content until one arrives.
        if (wallpaper.surfacePixelCount(width, height)) |_| {
            self.facts.logical = .{ .width = width, .height = height };
        } else |_| {
            self.facts.logical = null;
        }
    }

    fn commitFacts(self: *Output) void {
        if (self.facts.done() catch |err| {
            std.log.warn("wallpaper output geometry refused: {s}", .{@errorName(err)});
            return;
        }) {
            self.suspended = false;
            self.reopen_at = null;
        }
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
    required_names: RequiredNames = .{},
    required_removed: bool = false,
    records: [wallpaper.monitor_capacity]Output = @splat(.{}),
    ready: bool = false,
    failed: bool = false,

    const RequiredNames = struct {
        compositor: ?u32 = null,
        shm: ?u32 = null,
        viewporter: ?u32 = null,
        shell: ?u32 = null,

        fn contains(self: RequiredNames, id: u32) bool {
            return self.compositor == id or self.shm == id or
                self.viewporter == id or self.shell == id;
        }
    };

    fn reserveOutput(self: *Display, id: u32, version: u32) !*Output {
        if (version < 3) return error.WaylandOutputVersionUnsupported;
        for (&self.records) |*output| {
            if (output.id == id) return error.WaylandOutputDuplicate;
        }
        for (&self.records) |*output| {
            if (output.id == null) {
                output.* = .{ .id = id };
                return output;
            }
        }
        return error.WaylandOutputCapacityExceeded;
    }

    fn removeGlobal(self: *Display, id: u32) void {
        // A removed global can still have a live proxy, but subsequent
        // requests to it may be ignored. Do not advertise publication on it.
        if (self.required_names.contains(id)) {
            self.required_removed = true;
            return;
        }
        for (&self.records) |*output| {
            if (output.id == id) {
                output.destroy();
                return;
            }
        }
    }

    fn connect(self: *Display) !void {
        std.debug.assert(self.connection == null);
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
            if (wl.wl_display_flush(connection) < 0)
                std.log.debug("wallpaper teardown flush incomplete", .{});
            wl.wl_display_disconnect(connection);
        }
        self.* = .{};
    }

    fn dispatch(self: *Display) !void {
        if (wl.wl_display_dispatch_pending(self.connection.?) < 0) return displayError(self.connection.?);
        if (self.required_removed) return error.WaylandGlobalMissing;
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
        try publishBuffers(*wl.wl_buffer, self, source, allocator, image, pending, stop_fd);
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
        const fd = try createBacking(io, std.mem.sliceAsBytes(pixels.pixels));
        defer closeFd(fd);
        const pool = wl.wl_shm_create_pool(self.shm.?, fd, @intCast(length)) orelse return error.SurfacePoolFailed;
        defer wl.wl_shm_pool_destroy(pool);
        const buffer = wl.wl_shm_pool_create_buffer(pool, 0, @intCast(pixels.width), @intCast(pixels.height), @intCast(pixels.pitch), wl.WL_SHM_FORMAT_XRGB8888) orelse return error.SurfaceBufferFailed;
        errdefer wl.wl_buffer_destroy(buffer);
        if (wl.wl_buffer_add_listener(buffer, &buffer_listener, null) != 0) return error.SurfaceBufferFailed;
        return buffer;
    }
};

// Write through the descriptor rather than faulting a sparse shared mapping.
// The kernel reports backing allocation failure as an ordinary write error;
// no writable mapping or partially populated buffer escapes this owner.
fn createBacking(io: std.Io, bytes: []const u8) !std.posix.fd_t {
    std.debug.assert(bytes.len > 0);
    const fd = try std.posix.memfd_create("wayspot-wallpaper", std.os.linux.MFD.CLOEXEC);
    errdefer closeFd(fd);
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = false } };
    try writeBacking(file, io, bytes);
    return fd;
}

fn writeBacking(file: std.Io.File, io: std.Io, bytes: []const u8) !void {
    var written: usize = 0;
    // Positive progress bounds the number of writes by the byte extent.
    while (written < bytes.len) {
        const count = try file.writePositional(io, &.{bytes[written..]}, written);
        if (count == 0) return error.SurfaceBackingWriteIncomplete;
        std.debug.assert(count <= bytes.len - written);
        written += count;
    }
}

// Prepare every required immutable buffer before touching any displayed
// content. Failed allocation/scale/buffer creation retires only candidates.
// The same bounded transaction is exercised by the failure-injection test.
fn publishBuffers(
    comptime Buffer: type,
    // zig-audit: acknowledge anytype
    // reason: Native proxy owner and deterministic buffer target share preparation and commit.
    destination: anytype,
    source: *Source,
    allocator: std.mem.Allocator,
    image: *const wallpaper.Image,
    plan: Display.Plan,
    stop_fd: std.posix.fd_t,
) !void {
    var buffers: [wallpaper.monitor_capacity]?Buffer = @splat(null);
    errdefer for (&buffers) |*buffer| {
        if (buffer.*) |value| destination.discardBuffer(value);
    };
    for (plan.targets, 0..) |target, index| {
        const geometry = target orelse continue;
        try checkStop(source.io, stop_fd);
        var pixels = try wallpaper.coverImage(
            source,
            allocator,
            image,
            geometry.pixels.width,
            geometry.pixels.height,
        );
        defer pixels.deinit(allocator);
        buffers[index] = try destination.createBuffer(source.io, &pixels);
    }
    // Do not split an admitted commit batch on a later stop. Until this point
    // every prepared buffer still belongs exclusively to the transaction.
    try checkStop(source.io, stop_fd);
    for (plan.targets, 0..) |target, index| {
        const geometry = target orelse continue;
        destination.commitBuffer(index, geometry, buffers[index].?);
        buffers[index] = null;
    }
}

fn displayError(connection: *wl.wl_display) error{ WaylandDisplayLost, WaylandProtocolError } {
    return if (wl.wl_display_get_error(connection) == @backingInt(std.posix.E.PROTO)) error.WaylandProtocolError else error.WaylandDisplayLost;
}

const registry_listener = wl.wl_registry_listener{
    .global = registryGlobal,
    .global_remove = registryRemove,
};
const sync_listener = wl.wl_callback_listener{ .done = registryReady };

// The listener installation borrows stable, correctly aligned owner storage
// for the entire lifetime of the corresponding libwayland proxy.
// zig-audit: acknowledge anyopaque
// reason: libwayland listener userdata carries the stable Display owner.
fn displayContext(data: ?*anyopaque) *Display {
    std.debug.assert(data != null);
    // zig-audit: acknowledge ptr_cast
    // reason: Restore the Display pointer originally supplied to the listener.
    // zig-audit: acknowledge align_cast
    // reason: Listener installation passes an aligned Display allocation.
    return @ptrCast(@alignCast(data.?));
}

// zig-audit: acknowledge anyopaque
// reason: libwayland listener userdata carries one stable output array entry.
fn outputContext(data: ?*anyopaque) *Output {
    std.debug.assert(data != null);
    // zig-audit: acknowledge ptr_cast
    // reason: Restore the Output pointer supplied when installing its listener.
    // zig-audit: acknowledge align_cast
    // reason: Output records remain aligned and unmoved while proxies exist.
    return @ptrCast(@alignCast(data.?));
}

// A single compile-time pairing of interface metadata and resulting proxy
// type prevents binding one interface and treating it as another.
fn bindGlobal(
    comptime Proxy: type,
    registry: ?*wl.wl_registry,
    id: u32,
    version: u32,
) ?*Proxy {
    const owner = registry orelse return null;
    const interface = if (Proxy == wl.wl_output)
        &wl.wl_output_interface
    else if (Proxy == wl.wl_compositor)
        &wl.wl_compositor_interface
    else if (Proxy == wl.wl_shm)
        &wl.wl_shm_interface
    else if (Proxy == wl.wp_viewporter)
        wl.wayspot_viewporter_interface()
    else if (Proxy == wl.zwlr_layer_shell_v1)
        wl.wayspot_layer_shell_interface()
    else
        @compileError("unsupported wallpaper registry interface");
    // zig-audit: acknowledge ptr_cast
    // reason: wl_registry_bind returns the proxy for the exact interface selected above.
    return @ptrCast(wl.wl_registry_bind(owner, id, interface, version));
}

// zig-audit: acknowledge anyopaque
// reason: Matches wl_callback_listener.done userdata ABI.
fn registryReady(data: ?*anyopaque, callback: ?*wl.wl_callback, _: u32) callconv(.c) void {
    const self = displayContext(data);
    std.debug.assert(callback != null and callback == self.initial_sync);
    wl.wl_callback_destroy(callback);
    self.initial_sync = null;
    self.ready = true;
}

// zig-audit: acknowledge anyopaque
// reason: Matches wl_registry_listener.global userdata ABI.
fn registryGlobal(data: ?*anyopaque, registry: ?*wl.wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const self = displayContext(data);
    const name = std.mem.span(interface);
    if (std.mem.eql(u8, name, "wl_output")) {
        const output = self.reserveOutput(id, version) catch |err| {
            std.log.warn("wallpaper output registration refused: {s}", .{@errorName(err)});
            self.failed = true;
            return;
        };
        output.proxy = bindGlobal(wl.wl_output, registry, id, @min(version, 4));
        if (output.proxy == null or wl.wl_output_add_listener(
            output.proxy.?,
            &output_listener,
            output,
        ) != 0) self.failed = true;
    } else if (std.mem.eql(u8, name, "wl_compositor") and self.compositor == null and version >= 4) {
        self.compositor = bindGlobal(wl.wl_compositor, registry, id, 4);
        if (self.compositor != null) self.required_names.compositor = id;
    } else if (std.mem.eql(u8, name, "wl_shm") and self.shm == null and version >= 1) {
        self.shm = bindGlobal(wl.wl_shm, registry, id, 1);
        if (self.shm != null) self.required_names.shm = id;
    } else if (std.mem.eql(u8, name, "wp_viewporter") and self.viewporter == null and version >= 1) {
        self.viewporter = bindGlobal(wl.wp_viewporter, registry, id, 1);
        if (self.viewporter != null) self.required_names.viewporter = id;
    } else if (std.mem.eql(u8, name, "zwlr_layer_shell_v1") and self.shell == null and version >= 1) {
        self.shell = bindGlobal(wl.zwlr_layer_shell_v1, registry, id, @min(version, 3));
        if (self.shell != null) self.required_names.shell = id;
    }
}

// zig-audit: acknowledge anyopaque
// reason: Matches wl_registry_listener.global_remove userdata ABI.
fn registryRemove(data: ?*anyopaque, _: ?*wl.wl_registry, id: u32) callconv(.c) void {
    displayContext(data).removeGlobal(id);
}

const output_listener = wl.wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = outputDescription,
};
// zig-audit: acknowledge anyopaque
// reason: Matches wl_output_listener.geometry userdata ABI.
fn outputGeometry(data: ?*anyopaque, _: ?*wl.wl_output, _: i32, _: i32, _: i32, _: i32, _: i32, _: [*c]const u8, _: [*c]const u8, transform: i32) callconv(.c) void {
    outputContext(data).facts.transform = std.math.cast(u3, transform);
}
// zig-audit: acknowledge anyopaque
// reason: Matches wl_output_listener.mode userdata ABI.
fn outputMode(data: ?*anyopaque, _: ?*wl.wl_output, flags: u32, width: i32, height: i32, _: i32) callconv(.c) void {
    if (flags & wl.WL_OUTPUT_MODE_CURRENT == 0) return;
    const output = outputContext(data);
    output.facts.mode = if (width > 0 and height > 0)
        .{ .width = @intCast(width), .height = @intCast(height) }
    else
        null;
}
// zig-audit: acknowledge anyopaque
// reason: Matches wl_output_listener.done userdata ABI.
fn outputDone(data: ?*anyopaque, _: ?*wl.wl_output) callconv(.c) void {
    outputContext(data).commitFacts();
}
// zig-audit: acknowledge anyopaque
// reason: Required listener ABI; integer scale does not own wallpaper geometry.
fn outputScale(_: ?*anyopaque, _: ?*wl.wl_output, _: i32) callconv(.c) void {}
// zig-audit: acknowledge anyopaque
// reason: Required listener ABI; output names do not own wallpaper geometry.
fn outputName(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}
// zig-audit: acknowledge anyopaque
// reason: Required listener ABI; output descriptions do not own wallpaper geometry.
fn outputDescription(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}

const layer_listener = wl.wayspot_layer_listener{
    .configure = layerConfigure,
    .closed = layerClosed,
};
// zig-audit: acknowledge anyopaque
// reason: Matches layer-surface configure userdata ABI.
fn layerConfigure(data: ?*anyopaque, layer: ?*wl.zwlr_layer_surface_v1, serial: u32, width: u32, height: u32) callconv(.c) void {
    const output = outputContext(data);
    std.debug.assert(layer != null and layer == output.layer);
    if (layer) |proxy| wl.wayspot_layer_surface_ack_configure(proxy, serial);
    output.configure(width, height);
}
// zig-audit: acknowledge anyopaque
// reason: Matches layer-surface closed userdata ABI.
fn layerClosed(data: ?*anyopaque, layer: ?*wl.zwlr_layer_surface_v1) callconv(.c) void {
    const output = outputContext(data);
    std.debug.assert(layer != null and layer == output.layer);
    output.destroyRole();
    output.suspended = true;
    output.reopen_at = null;
    std.log.warn("wallpaper role closed on output {d}", .{output.id orelse 0});
}
const buffer_listener = wl.wl_buffer_listener{ .release = bufferReleased };
// zig-audit: acknowledge anyopaque
// reason: Required release listener ABI; immutable backing is never recycled.
fn bufferReleased(_: ?*anyopaque, _: ?*wl.wl_buffer) callconv(.c) void {}

const Ready = struct { stop: bool = false, rotate: bool = false };
const poll_failure = std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL;

// An interruption ends this poll turn so the owner recomputes its deadline.
fn pollOnce(io: std.Io, fds: []std.posix.pollfd, timeout: i32) !usize {
    const linux = std.os.linux;
    const result = linux.poll(fds.ptr, @intCast(fds.len), timeout);
    switch (linux.errno(result)) {
        .SUCCESS => return result,
        .INTR => {
            try io.checkCancel();
            return 0;
        },
        else => |err| {
            std.log.err("wallpaper poll failed: {s}", .{@tagName(err)});
            return error.WallpaperPollFailed;
        },
    }
}

fn checkStop(io: std.Io, stop_fd: std.posix.fd_t) !void {
    if (stop_fd < 0) return;
    var fds = [_]std.posix.pollfd{.{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 }};
    if (try pollOnce(io, &fds, 0) == 0) return;
    if (fds[0].revents != 0) {
        try Stop.consume(io, stop_fd);
        return error.Stopped;
    }
}

// Real socket readiness witness used by the focused transport tests.
fn waitRotationTest(source: *Source, stop_fd: std.posix.fd_t, timeout: i32) !Ready {
    var fds = [_]std.posix.pollfd{
        .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = source.rotate_listener, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = source.rotate_client, .events = std.posix.POLL.IN, .revents = 0 },
    };
    if (try pollOnce(source.io, &fds, timeout) == 0) return .{};
    if (fds[0].revents != 0) {
        try Stop.consume(source.io, stop_fd);
        return .{ .stop = true };
    }
    if (fds[1].revents & poll_failure != 0) return error.RotationListenerLost;
    return .{ .rotate = fds[1].revents != 0 or fds[2].revents != 0 };
}

// Receipt means the commit requests were written, not a frame was displayed.
fn flush(source: *Source, connection: *wl.wl_display, stop_fd: std.posix.fd_t) !void {
    const deadline = source.now() +| 1000;
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
        if (try pollOnce(source.io, &fds, @intCast(remaining)) == 0) continue;
        if (fds[0].revents != 0) {
            try Stop.consume(source.io, stop_fd);
            return error.Stopped;
        }
        if (fds[1].revents & poll_failure != 0) return displayError(connection);
    }
}

/// Stable wallpaper owner. No nested blocking event loop in the resident.
pub const Service = struct {
    allocator: std.mem.Allocator,
    source: Source,
    catalog: wallpaper.Catalog,
    selected: wallpaper.EncodedImage,
    schedule: wallpaper.Schedule = .{},
    display: Display = .{},
    direct: bool = false,
    request_deadline: ?u64 = null,
    retry_at: ?u64 = null,
    reconnect_at: u64 = 0,
    write_pending: bool = false,
    rotation_result: ?bool = null,

    /// Owns the startup catalogue and one admitted encoded image, without a display connection.
    pub fn init(init_process: std.process.Init, root_path: []const u8) !Service {
        var catalog = try discoverCatalog(init_process.io, init_process.gpa, root_path);
        errdefer catalog.deinit();
        var source: Source = .{ .io = init_process.io };
        var first = try wallpaper.choose(&source, init_process.gpa, &catalog);
        first.image.deinit(init_process.gpa);
        catalog.published = first.index;
        return .{ .allocator = init_process.gpa, .source = source, .catalog = catalog, .selected = first.encoded };
    }

    /// Retires display resources, retained image, catalogue and legacy endpoint.
    pub fn deinit(self: *Service) void {
        self.display.deinit();
        self.selected.deinit(self.allocator);
        self.catalog.deinit();
        self.source.closeRotation();
    }

    /// Reserve the old standalone identity without opening another listener.
    /// A legacy wallpaper process must not compete with a resident surface owner.
    pub fn reserveStandalone(self: *Service, identity: []const u8) !void {
        try self.source.bindRotation(identity, false);
    }

    /// Admits one direct rotation and its bounded readiness deadline.
    pub fn request(self: *Service) !void {
        if (self.direct or self.rotation_result != null) return error.RotationBusy;
        if (self.display.connection == null) return error.WallpaperResidentUnavailable;
        self.direct = true;
        self.request_deadline = self.source.now() +| 2000;
        for (&self.display.records) |*output| {
            output.suspended = false;
            output.reopen_at = null;
        }
    }

    /// Consumes the exact pending direct rotation result once.
    pub fn takeResult(self: *Service) ?bool {
        const value = self.rotation_result;
        self.rotation_result = null;
        return value;
    }

    /// Returns the number of locally committed output geometries.
    pub fn count(self: *const Service) usize {
        return self.display.publishedCount();
    }

    /// Borrows the current Wayland descriptor and required readiness mask.
    pub fn pollFd(self: *const Service) std.posix.pollfd {
        return .{
            .fd = if (self.display.connection) |connection| wl.wl_display_get_fd(connection) else -1,
            .events = std.posix.POLL.IN | (if (self.write_pending) @as(i16, std.posix.POLL.OUT) else 0),
            .revents = 0,
        };
    }

    /// Returns milliseconds to the earliest owned deadline, or null when idle.
    pub fn wake(self: *const Service, now: u64) ?u64 {
        if (self.display.connection == null) return self.reconnect_at -| now;
        var timeout = self.schedule.wake(now, self.display.allReady());
        for ([_]?u64{ self.request_deadline, self.retry_at }) |deadline| if (deadline) |end| {
            timeout = if (timeout) |old| @min(old, end -| now) else end -| now;
        };
        if (self.display.roleWake(now)) |delay| timeout = if (timeout) |old| @min(old, delay) else delay;
        return timeout;
    }

    /// Advances one display turn or schedules ordinary transport recovery.
    pub fn advance(self: *Service, stop_fd: std.posix.fd_t) !void {
        try checkStop(self.source.io, stop_fd);
        if (self.display.connection == null) {
            if (self.source.now() < self.reconnect_at) return;
            self.display.connect() catch |err| return self.recover(err);
        }
        self.turn(stop_fd) catch |err| return self.recover(err);
    }

    // zig-audit: acknowledge anyerror
    // reason: Preserve exact native and allocation errors; only transport loss reconnects.
    fn recover(self: *Service, err: anyerror) !void {
        switch (err) {
            error.WaylandDisplayLost, error.WaylandConnectFailed => {
                self.display.deinit();
                self.finishRequest(false);
                self.retry_at = null;
                self.write_pending = false;
                self.reconnect_at = self.source.now() +| 1000;
                std.log.warn("wallpaper connection unavailable: {s}", .{@errorName(err)});
            },
            else => return err,
        }
    }

    fn finishRequest(self: *Service, success: bool) void {
        if (self.direct) self.rotation_result = success;
        self.direct = false;
        self.request_deadline = null;
    }

    fn turn(self: *Service, stop_fd: std.posix.fd_t) !void {
        const display = &self.display;
        const source = &self.source;
        const allocator = self.allocator;
        const catalog = &self.catalog;
        const selected = &self.selected;
        const schedule = &self.schedule;
        try display.dispatch();
        // Only the display fd is read here. The common loop owns the command
        // socket and never competes with libwayland for event dispatch.
        const connection = display.connection.?;
        if (wl.wl_display_prepare_read(connection) == 0) {
            var descriptor = [_]std.posix.pollfd{.{ .fd = wl.wl_display_get_fd(connection), .events = std.posix.POLL.IN, .revents = 0 }};
            var prepared = true;
            defer if (prepared) wl.wl_display_cancel_read(connection);
            if (try pollOnce(source.io, &descriptor, 0) != 0) {
                if (descriptor[0].revents & std.posix.POLL.IN != 0) {
                    prepared = false;
                    if (wl.wl_display_read_events(connection) < 0) return displayError(connection);
                } else if (descriptor[0].revents & poll_failure != 0) {
                    return displayError(connection);
                }
            }
        }
        try display.dispatch();
        const now = source.now();
        try display.ensureRoles(now);
        if (self.request_deadline) |end| {
            if (now >= end or (self.direct and display.ready and display.count() == 0)) {
                self.finishRequest(false);
            }
        }
        // A direct request may expedite recovery of a closed background role.
        if (self.direct or schedule.due(now, display.allReady())) {
            if (display.allReady()) {
                const success = rotate(display, source, allocator, catalog, selected, stop_fd) catch |err| switch (err) {
                    error.Stopped, error.Canceled, error.WaylandDisplayLost, error.WaylandProtocolError => return err,
                    else => blk: {
                        std.log.warn("wallpaper rotation refused: {s}", .{@errorName(err)});
                        break :blk false;
                    },
                };
                try schedule.attempted(source.now(), self.direct, success);
                self.finishRequest(success);
            }
        }
        if (self.retry_at == null or now >= self.retry_at.?) {
            self.retry_at = null;
            if (display.plan(false)) |pending| {
                if (pending.count != 0) {
                    const result = result: {
                        var image = wallpaper.decodeImage(source, allocator, selected) catch |err|
                            break :result err;
                        defer image.deinit(allocator);
                        break :result display.publish(source, allocator, &image, pending, stop_fd);
                    };
                    result catch |err| switch (err) {
                        error.Stopped, error.Canceled, error.WaylandDisplayLost, error.WaylandProtocolError => return err,
                        else => {
                            std.log.warn("wallpaper publication refused: {s}", .{@errorName(err)});
                            self.retry_at = source.now() +| 1000;
                        },
                    };
                    if (self.retry_at == null and schedule.deadline == null)
                        try schedule.advance(source.now());
                }
            } else |err| {
                std.log.warn("wallpaper geometry refused: {s}", .{@errorName(err)});
                self.retry_at = now +| 1000;
            }
        }

        const sent = wl.wl_display_flush(connection);
        self.write_pending = sent < 0;
        if (sent < 0 and std.posix.errno(sent) != .AGAIN) return displayError(connection);
    }
};

/// Runs the standalone wallpaper owner until stop or a terminal failure.
pub fn run(init_process: std.process.Init, root_path: []const u8) !void {
    const stop = try Stop.open();
    defer stop.close();
    var service = try Service.init(init_process, root_path);
    defer service.deinit();
    const signature = try sessionIdentifier(init_process.environ_map.get("XDG_RUNTIME_DIR") orelse return error.RuntimeDirectoryMissing, init_process.environ_map.get("WAYLAND_DISPLAY") orelse return error.WaylandDisplayMissing);
    try service.source.openRotation(&signature);
    var partial_deadline: ?u64 = null;
    while (true) {
        service.advance(stop.fd) catch |err| switch (err) {
            error.Stopped => return,
            else => return err,
        };
        if (service.takeResult()) |success| {
            service.source.replyRotation(success);
            partial_deadline = null;
        }
        const now = service.source.now();
        if (partial_deadline) |end| if (!service.direct and now >= end) {
            service.source.replyRotation(false);
            partial_deadline = null;
        };
        var timeout = service.wake(now);
        if (partial_deadline) |end| if (!service.direct) {
            timeout = if (timeout) |old| @min(old, end -| now) else end -| now;
        };
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop.fd, .events = std.posix.POLL.IN, .revents = 0 },
            service.pollFd(),
            .{ .fd = service.source.rotate_listener, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = service.source.rotate_client, .events = std.posix.POLL.IN, .revents = 0 },
        };
        const delay: i32 = if (timeout) |ms| @intCast(@min(ms, std.math.maxInt(i32))) else -1;
        if (try pollOnce(init_process.io, &fds, delay) == 0) continue;
        if (fds[0].revents != 0) {
            try Stop.consume(init_process.io, stop.fd);
            return;
        }
        if (fds[2].revents & poll_failure != 0) return error.RotationListenerLost;
        if (fds[2].revents != 0 or fds[3].revents != 0) {
            if (service.direct) {
                if (fds[2].revents != 0) service.source.rejectBusy();
                if (fds[3].revents != 0) {
                    service.source.replyRotation(false);
                    service.direct = false;
                    service.request_deadline = null;
                    partial_deadline = null;
                }
            } else {
                const complete = service.source.receiveRotation() catch |err| blk: {
                    std.log.warn("wallpaper rotation request refused: {s}", .{@errorName(err)});
                    service.source.replyRotation(false);
                    break :blk false;
                };
                if (service.source.rotate_client >= 0 and partial_deadline == null) partial_deadline = service.source.now() +| 2000;
                if (complete) service.request() catch {
                    service.source.replyRotation(false);
                    partial_deadline = null;
                };
                if (service.source.rotate_client < 0) partial_deadline = null;
            }
        }
    }
}

fn rotate(display: *Display, source: *Source, allocator: std.mem.Allocator, catalog: *wallpaper.Catalog, selected: *wallpaper.EncodedImage, stop_fd: std.posix.fd_t) !bool {
    std.debug.assert(display.allReady());
    try checkStop(source.io, stop_fd);
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
        output.configure(1280, 720);
        try std.testing.expectEqual(@as(usize, 0), (try display.plan(false)).count);
    }
    try std.testing.expect(!display.failed and display.allReady());
    output.configure(1920, 1080);
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
    defer closeFd(fds[0]);
    defer closeFd(fds[1]);
    const writer: std.Io.File = .{ .handle = fds[1], .flags = .{ .nonblocking = false } };
    try writer.writeStreamingAll(std.testing.io, &(@as([128]u8, @splat(0))));
    var source: Source = .{ .io = std.testing.io };
    try source.openRotation("wallpaper-stop-priority-test");
    defer source.closeRotation();
    const client = try connectRotationTest("wallpaper-stop-priority-test");
    defer closeFd(client);
    const ready = try waitRotationTest(&source, fds[0], 100);
    try std.testing.expect(ready.stop and !ready.rotate);
}

test "all buffer preparation precedes every commit and failures discard only candidates" {
    const Target = struct {
        created: usize = 0,
        committed: usize = 0,
        discarded: usize = 0,
        fail_at: ?usize = null,
        stop_after: ?usize = null,
        stop: ?std.Io.File = null,
        invalid: bool = false,
        retired: [3]bool = @splat(false),

        fn createBuffer(self: *@This(), _: std.Io, _: *const wallpaper.Image) !usize {
            if (self.fail_at == self.created) return error.SurfaceBufferFailed;
            self.created += 1;
            if (self.stop_after == self.created)
                try self.stop.?.writeStreamingAll(std.testing.io, &(@as([128]u8, @splat(0))));
            return self.created;
        }
        fn discardBuffer(self: *@This(), buffer: usize) void {
            if (buffer == 0 or buffer > self.created or self.retired[buffer - 1])
                self.invalid = true
            else
                self.retired[buffer - 1] = true;
            self.discarded += 1;
        }
        fn commitBuffer(self: *@This(), _: usize, _: outputs.Geometry, buffer: usize) void {
            if (self.created != 3 or self.discarded != 0 or buffer != self.committed + 1)
                self.invalid = true;
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
        try std.testing.expectError(error.SurfaceBufferFailed, publishBuffers(usize, &target, &source, std.testing.allocator, &image, plan, -1));
        try std.testing.expectEqual(failure, target.created);
        try std.testing.expectEqual(failure, target.discarded);
        try std.testing.expectEqual(@as(usize, 0), target.committed);
        try std.testing.expect(!target.invalid);
        target = .{};
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        try std.testing.expectError(error.OutOfMemory, publishBuffers(usize, &target, &source, failing.allocator(), &image, plan, -1));
        try std.testing.expectEqual(failure, target.discarded);
        try std.testing.expectEqual(@as(usize, 0), target.committed);
        try std.testing.expect(!target.invalid);
    }
    const linux = std.os.linux;
    for (1..4) |prepared| {
        var fds: [2]std.posix.fd_t = undefined;
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.pipe2(
            &fds,
            .{ .CLOEXEC = true, .NONBLOCK = true },
        )));
        defer closeFd(fds[0]);
        defer closeFd(fds[1]);
        var target: Target = .{
            .stop_after = prepared,
            .stop = .{ .handle = fds[1], .flags = .{ .nonblocking = true } },
        };
        try std.testing.expectError(
            error.Stopped,
            publishBuffers(usize, &target, &source, std.testing.allocator, &image, plan, fds[0]),
        );
        try std.testing.expectEqual(prepared, target.created);
        try std.testing.expectEqual(prepared, target.discarded);
        try std.testing.expectEqual(@as(usize, 0), target.committed);
        try std.testing.expect(!target.invalid);
        for (target.retired[0..prepared]) |retired| try std.testing.expect(retired);
    }
    var success: Target = .{};
    try publishBuffers(usize, &success, &source, std.testing.allocator, &image, plan, -1);
    try std.testing.expectEqual(@as(usize, 3), success.committed);
    try std.testing.expectEqual(@as(usize, 0), success.discarded);
    try std.testing.expect(!success.invalid);
}

test "native image open rejects paths replaced after catalogue discovery" {
    const io = std.testing.io;
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    const linux = std.os.linux;
    var root_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buf[0..try fixture.dir.realPath(io, &root_buf)];
    try fixture.dir.writeFile(io, .{ .sub_path = "first.png", .data = "fixture" });
    try fixture.dir.writeFile(io, .{ .sub_path = "second.png", .data = "second" });
    var catalog = try discoverCatalog(io, std.testing.allocator, root);
    defer catalog.deinit();
    try std.testing.expectEqual(@as(usize, 2), catalog.paths.items.len);
    const path = catalog.paths.items[1];
    var source: Source = .{ .io = io };

    try fixture.dir.deleteFile(io, "second.png");
    try std.testing.expectEqual(
        linux.E.SUCCESS,
        linux.errno(linux.mknodat(fixture.dir.handle, "second.png", linux.S.IFIFO | 0o600, 0)),
    );
    try std.testing.expectError(error.ImageNotRegularFile, source.open(path));
    try std.testing.expect(source.file == null);
    try fixture.dir.deleteFile(io, "second.png");
    try fixture.dir.symLink(io, "first.png", "second.png", .{});
    try std.testing.expectError(error.ImageNotRegularFile, source.open(path));
    try std.testing.expect(source.file == null);
    try fixture.dir.deleteFile(io, "second.png");
    try fixture.dir.writeFile(io, .{ .sub_path = "second.png", .data = "replacement" });
    try source.open(path);
    defer source.close();
    const stat = try source.stat();
    try std.testing.expectEqual(std.Io.File.Kind.file, stat.kind);
    var data: [11]u8 = undefined;
    try std.testing.expectEqual(data.len, try source.read(&data));
    try std.testing.expectEqualStrings("replacement", &data);

    var failing: Source = .{ .io = std.Io.failing };
    if (failing.open(path)) |_| {
        failing.close();
        return error.ExpectedOpenFailure;
    } else |_| {}
    try std.testing.expect(failing.file == null);
}

test "rotation accepts no pending connection without losing listener ownership" {
    var source: Source = .{ .io = std.testing.io };
    try source.openRotation("rotation-empty-accept-test");
    defer source.closeRotation();
    const listener = source.rotate_listener;
    try std.testing.expect(!try source.receiveRotation());
    try std.testing.expectEqual(listener, source.rotate_listener);
    try std.testing.expectEqual(@as(std.posix.fd_t, -1), source.rotate_client);
    try std.testing.expectError(error.RotationAlreadyOpen, source.openRotation("other"));
    try std.testing.expectEqual(listener, source.rotate_listener);
}

test "rotation receipt requires end of stream after an exact success" {
    const linux = std.os.linux;
    const cases = [_]struct { bytes: []const u8, success: bool }{
        .{ .bytes = "ok\n", .success = true },
        .{ .bytes = "ok\nextra", .success = false },
        .{ .bytes = "ok", .success = false },
        .{ .bytes = "error\n", .success = false },
        .{ .bytes = "", .success = false },
    };
    for (cases) |case| {
        var fds: [2]std.posix.fd_t = undefined;
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.socketpair(
            std.posix.AF.UNIX,
            std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
            0,
            &fds,
        )));
        defer closeFd(fds[0]);
        defer closeFd(fds[1]);
        if (case.bytes.len != 0)
            try std.testing.expectEqual(case.bytes.len, (try sendBytes(fds[1], case.bytes)).?);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.shutdown(fds[1], 1)));
        const now = std.Io.Clock.awake.now(std.testing.io);
        if (case.success) {
            try readReceipt(std.testing.io, fds[0], now);
        } else {
            try std.testing.expectError(error.RotationRejected, readReceipt(std.testing.io, fds[0], now));
        }
    }
}

test "rotation send to retired peer reports failure without signal delivery" {
    const linux = std.os.linux;
    var fds: [2]std.posix.fd_t = undefined;
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.socketpair(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
        0,
        &fds,
    )));
    defer closeFd(fds[0]);
    closeFd(fds[1]);
    try std.testing.expectError(error.RotationSocketWriteFailed, sendBytes(fds[0], "ok\n"));
}

test "output registry admits exact capacity, rejects duplicates and reuses retired slots" {
    var display: Display = .{};
    try std.testing.expectError(error.WaylandOutputVersionUnsupported, display.reserveOutput(1, 2));
    const first = try display.reserveOutput(1, 4);
    try std.testing.expectError(error.WaylandOutputDuplicate, display.reserveOutput(1, 4));
    try std.testing.expectEqual(@as(usize, 1), display.count());
    for (2..wallpaper.monitor_capacity + 1) |id| {
        const output = try display.reserveOutput(@intCast(id), 3);
        try std.testing.expectEqual(@as(?u32, @intCast(id)), output.id);
    }
    try std.testing.expectError(
        error.WaylandOutputCapacityExceeded,
        display.reserveOutput(wallpaper.monitor_capacity + 1, 4),
    );
    try std.testing.expectEqual(wallpaper.monitor_capacity, display.count());
    display.removeGlobal(1);
    const replacement = try display.reserveOutput(1, 4);
    try std.testing.expectEqual(first, replacement);
    try std.testing.expectEqual(wallpaper.monitor_capacity, display.count());
    try std.testing.expect(replacement.facts.geometry() == null);
}

test "required global removal is terminal without treating unrelated removal as lost authority" {
    for ([_]u32{ 21, 22, 23, 24 }) |id| {
        var display: Display = .{ .required_names = .{
            .compositor = 21,
            .shm = 22,
            .viewporter = 23,
            .shell = 24,
        } };
        const output = try display.reserveOutput(25, 4);
        output.facts.pixels = .{ .width = 1280, .height = 720 };
        output.configure(1280, 720);
        display.removeGlobal(26);
        try std.testing.expect(!display.required_removed);
        try std.testing.expectEqual(@as(usize, 1), display.count());
        display.removeGlobal(id);
        try std.testing.expect(display.required_removed);
        try std.testing.expectEqual(@as(usize, 1), display.count());
        display.removeGlobal(25);
        try std.testing.expectEqual(@as(usize, 0), display.count());
        try std.testing.expect(display.required_removed);
    }
}

test "invalid layer extent retains published pixels until valid configure returns" {
    var output: Output = .{ .id = 1, .facts = .{
        .pixels = .{ .width = 1920, .height = 1080 },
    } };
    output.configure(1280, 720);
    output.facts.published = output.facts.geometry();
    const published = output.facts.published.?;
    output.configure(0, 720);
    try std.testing.expect(output.facts.geometry() == null);
    try std.testing.expect(!output.facts.needsBuffer());
    try std.testing.expectEqual(published, output.facts.published.?);
    output.configure(8192, 8193);
    try std.testing.expect(output.facts.geometry() == null);
    try std.testing.expectEqual(published, output.facts.published.?);
    output.configure(1280, 720);
    try std.testing.expect(!output.facts.needsBuffer());
    output.configure(1920, 1080);
    try std.testing.expect(output.facts.needsBuffer());
}

test "immutable backing is populated exactly and write failure is an ordinary error" {
    const io = std.testing.io;
    const bytes = "wallpaper backing";
    const fd = try createBacking(io, bytes);
    defer closeFd(fd);
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = false } };
    const stat = try file.stat(io);
    try std.testing.expectEqual(@as(u64, bytes.len), stat.size);
    var actual: [bytes.len]u8 = undefined;
    try std.testing.expectEqual(bytes.len, try file.readPositionalAll(io, &actual, 0));
    try std.testing.expectEqualStrings(bytes, &actual);

    const full = try std.Io.Dir.openFileAbsolute(io, "/dev/full", .{ .mode = .write_only });
    defer full.close(io);
    try std.testing.expectError(error.NoSpaceLeft, writeBacking(full, io, bytes));
}

test "ready termination wins before a disconnected service can open a display" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const linux = std.os.linux;
    var fds: [2]std.posix.fd_t = undefined;
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.pipe2(
        &fds,
        .{ .CLOEXEC = true, .NONBLOCK = true },
    )));
    defer closeFd(fds[0]);
    defer closeFd(fds[1]);
    const writer: std.Io.File = .{ .handle = fds[1], .flags = .{ .nonblocking = true } };
    try writer.writeStreamingAll(io, &(@as([128]u8, @splat(0))));
    var service: Service = .{
        .allocator = allocator,
        .source = .{ .io = io },
        .catalog = .{ .allocator = allocator, .prng = .init(0) },
        .selected = .{ .format = .png, .bytes = &.{} },
        .reconnect_at = std.math.maxInt(u64),
    };
    try std.testing.expectError(error.Stopped, service.advance(fds[0]));
    try std.testing.expect(service.display.connection == null);
    try std.testing.expect(service.rotation_result == null);
}
