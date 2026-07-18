const std = @import("std");
const wallpaper = @import("wallpaper.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});
const wl = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wlr-layer-shell-unstable-v1-client.h");
    @cInclude("viewporter-client.h");
});

pub const Native = struct {
    io: std.Io,
    file: ?std.Io.File = null,
    display: ?*wl.wl_display = null,
    registry_proxy: ?*wl.wl_registry = null,
    compositor: ?*wl.wl_compositor = null,
    shm: ?*wl.wl_shm = null,
    viewporter: ?*wl.wp_viewporter = null,
    layer_shell: ?*wl.zwlr_layer_shell_v1 = null,
    output_globals: [wallpaper.monitor_capacity]u32 = undefined,
    output_count: u8 = 0,
    output: ?*wl.wl_output = null,
    output_name: [wallpaper.monitor_name_capacity]u8 = undefined,
    output_name_length: u8 = 0,
    probe: OutputProbe = .{},
    global_count: u8 = 0,
    failed: bool = false,
    surface: Surface = .{},
    next_surface_generation: u32 = 1,

    pub fn open(native: *Native, path: []const u8) !void {
        std.debug.assert(native.file == null);
        native.file = if (std.fs.path.isAbsolute(path))
            try std.Io.Dir.openFileAbsolute(native.io, path, .{})
        else
            try std.Io.Dir.cwd().openFile(native.io, path, .{});
    }

    pub fn stat(native: *Native) !struct { kind: std.Io.File.Kind, size: u64 } {
        const value = try (native.file orelse unreachable).stat(native.io);
        return .{ .kind = value.kind, .size = value.size };
    }

    pub fn read(native: *Native, bytes: []u8) !usize {
        return (native.file orelse unreachable).readPositionalAll(native.io, bytes, 0);
    }

    pub fn close(native: *Native) void {
        const file = native.file orelse unreachable;
        file.close(native.io);
        native.file = null;
    }

    pub fn openOutput(native: *Native, name: []const u8) !void {
        std.debug.assert(native.display == null);
        native.display = wl.wl_display_connect(null) orelse return error.WaylandConnectFailed;
        errdefer native.disconnect();
        native.registry_proxy = wl.wl_display_get_registry(native.display.?) orelse
            return error.WaylandRegistryFailed;
        if (wl.wl_registry_add_listener(native.registry_proxy, &registry_listener, native) != 0) {
            return error.WaylandRegistryFailed;
        }
        try native.roundtrip();
        if (native.compositor == null or native.shm == null or native.viewporter == null or
            native.layer_shell == null or native.output_count == 0)
        {
            return error.WaylandGlobalMissing;
        }
        for (native.output_globals[0..native.output_count]) |global| {
            native.probe = .{};
            const proxy: *wl.wl_output = @ptrCast(wl.wl_registry_bind(
                native.registry_proxy,
                global,
                &wl.wl_output_interface,
                4,
            ) orelse return error.WaylandOutputMissing);
            var retained = false;
            defer if (!retained) wl.wl_output_release(proxy);
            if (wl.wl_output_add_listener(proxy, &output_listener, &native.probe) != 0) {
                return error.WaylandOutputInvalid;
            }
            try native.roundtrip();
            if (!native.probe.name_seen or !native.probe.done or native.probe.invalid) {
                return error.WaylandOutputIncomplete;
            }
            const probe_name = native.probe.name_bytes[0..native.probe.name_length];
            if (!std.mem.eql(u8, probe_name, name)) continue;
            if (native.output != null) return error.WaylandOutputDuplicate;
            native.output = proxy;
            retained = true;
            @memcpy(native.output_name[0..native.probe.name_length], probe_name);
            native.output_name_length = native.probe.name_length;
        }
        if (native.output == null) return error.WaylandOutputMissing;
    }

    pub fn disconnect(native: *Native) void {
        if (native.display == null) return;
        std.debug.assert(!native.surface.occupied);
        if (native.output) |proxy| wl.wl_output_release(proxy);
        if (native.layer_shell) |proxy| wl.zwlr_layer_shell_v1_destroy(proxy);
        if (native.viewporter) |proxy| wl.wp_viewporter_destroy(proxy);
        if (native.shm) |proxy| wl.wl_shm_destroy(proxy);
        if (native.compositor) |proxy| wl.wl_compositor_destroy(proxy);
        if (native.registry_proxy) |proxy| wl.wl_registry_destroy(proxy);
        wl.wl_display_disconnect(native.display.?);
        native.display = null;
        native.registry_proxy = null;
        native.compositor = null;
        native.shm = null;
        native.viewporter = null;
        native.layer_shell = null;
        native.output_count = 0;
        native.output = null;
        native.output_name_length = 0;
    }

    pub fn prepare(
        native: *Native,
        monitor: *const wallpaper.Monitor,
        pixels: *const wallpaper.Image,
    ) !wallpaper.SurfaceHandle {
        if (!std.mem.eql(u8, native.output_name[0..native.output_name_length], monitor.name())) {
            return error.WaylandOutputMissing;
        }
        if (native.surface.occupied) return error.SurfaceOccupied;
        if (native.next_surface_generation == std.math.maxInt(u32)) return error.SurfaceGenerationExhausted;
        const handle = wallpaper.SurfaceHandle{ .generation = native.next_surface_generation };
        native.next_surface_generation += 1;
        native.surface = .{ .occupied = true, .generation = handle.generation };
        errdefer native.discard(handle);
        const surface = &native.surface;
        surface.surface = wl.wl_compositor_create_surface(native.compositor.?) orelse
            return error.SurfaceCreateFailed;
        surface.region = wl.wl_compositor_create_region(native.compositor.?) orelse
            return error.SurfaceRegionFailed;
        wl.wl_surface_set_input_region(surface.surface orelse return error.SurfaceCreateFailed, surface.region);
        wl.wl_region_destroy(surface.region orelse return error.SurfaceRegionFailed);
        surface.region = null;
        surface.layer = wl.zwlr_layer_shell_v1_get_layer_surface(
            native.layer_shell.?,
            surface.surface.?,
            native.output.?,
            wl.ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND,
            "wayspot-beta-wallpaper",
        ) orelse return error.SurfaceLayerFailed;
        if (wl.zwlr_layer_surface_v1_add_listener(surface.layer, &layer_listener, surface) != 0) {
            return error.SurfaceLayerFailed;
        }
        const layer = surface.layer.?;
        wl.zwlr_layer_surface_v1_set_size(layer, 0, 0);
        wl.zwlr_layer_surface_v1_set_anchor(
            layer,
            wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
        );
        wl.zwlr_layer_surface_v1_set_exclusive_zone(layer, -1);
        wl.zwlr_layer_surface_v1_set_keyboard_interactivity(
            layer,
            wl.ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE,
        );
        surface.viewport = wl.wp_viewporter_get_viewport(native.viewporter.?, surface.surface.?) orelse
            return error.SurfaceViewportFailed;
        wl.wl_surface_commit(surface.surface.?);
        const configure_started = std.Io.Clock.awake.now(native.io);
        var count: u8 = 0;
        while (surface.configure == null and count < wallpaper.wayland_configure_capacity) : (count += 1) {
            if (!try native.dispatch(configure_started)) break;
        }
        if (surface.closed) return error.SurfaceClosed;
        const configured = surface.configure orelse return error.SurfaceConfigureMissing;
        _ = try wallpaper.surfacePixelCount(configured.width, configured.height);
        wl.zwlr_layer_surface_v1_ack_configure(layer, configured.serial);
        wl.wp_viewport_set_destination(
            surface.viewport.?,
            @intCast(configured.width),
            @intCast(configured.height),
        );
        const length = pixels.pixels.len * @sizeOf(u32);
        surface.shm_fd = try std.posix.memfd_create("wayspot-wallpaper", std.os.linux.MFD.CLOEXEC);
        try (std.Io.File{ .handle = surface.shm_fd.? }).setLength(native.io, length);
        surface.mapping = try std.posix.mmap(
            null,
            length,
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = .SHARED },
            surface.shm_fd.?,
            0,
        );
        @memcpy(surface.mapping.?[0..length], std.mem.sliceAsBytes(pixels.pixels));
        surface.pool = wl.wl_shm_create_pool(native.shm.?, surface.shm_fd.?, @intCast(length)) orelse
            return error.SurfacePoolFailed;
        surface.buffer = wl.wl_shm_pool_create_buffer(
            surface.pool.?,
            0,
            @intCast(pixels.width),
            @intCast(pixels.height),
            @intCast(pixels.pitch),
            wl.WL_SHM_FORMAT_XRGB8888,
        ) orelse return error.SurfaceBufferFailed;
        if (wl.wl_buffer_add_listener(surface.buffer, &buffer_listener, surface) != 0) {
            return error.SurfaceBufferFailed;
        }
        wl.wl_surface_attach(surface.surface.?, surface.buffer, 0, 0);
        wl.wl_surface_damage_buffer(surface.surface.?, 0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        wl.wl_surface_commit(surface.surface.?);
        surface.committed = true;
        if (wl.wl_display_flush(native.display.?) < 0) return error.WaylandFlushFailed;
        return handle;
    }

    pub fn release(native: *Native, handle: wallpaper.SurfaceHandle) !void {
        const surface = try native.checkedSurface(handle);
        errdefer native.discard(handle);
        wl.wl_surface_attach(surface.surface.?, null, 0, 0);
        wl.wl_surface_commit(surface.surface.?);
        if (wl.wl_display_flush(native.display.?) < 0) return error.WaylandFlushFailed;
        const release_started = std.Io.Clock.awake.now(native.io);
        var count: u8 = 0;
        while (!surface.released and count < wallpaper.wayland_release_capacity) : (count += 1) {
            if (!try native.dispatch(release_started)) break;
        }
        if (!surface.released) return error.SurfaceReleaseMissing;
        wl.wl_buffer_destroy(surface.buffer.?);
        surface.buffer = null;
        wl.wl_shm_pool_destroy(surface.pool.?);
        surface.pool = null;
        std.posix.munmap(surface.mapping.?);
        surface.mapping = null;
        std.posix.close(surface.shm_fd.?);
        surface.shm_fd = null;
        wl.wp_viewport_destroy(surface.viewport.?);
        surface.viewport = null;
        wl.zwlr_layer_surface_v1_destroy(surface.layer.?);
        surface.layer = null;
        wl.wl_surface_destroy(surface.surface.?);
        surface.surface = null;
        std.debug.assert(surface.localResourcesReleased());
        surface.* = .{};
    }

    fn discard(native: *Native, handle: wallpaper.SurfaceHandle) void {
        const surface = native.checkedSurface(handle) catch unreachable;
        if (surface.committed) native.disconnectDisplayLoss();
        if (native.display != null) surface.destroyProxies();
        surface.destroyLocal();
        surface.* = .{};
    }

    fn checkedSurface(native: *Native, handle: wallpaper.SurfaceHandle) !*Surface {
        if (!native.surface.occupied or native.surface.generation != handle.generation) {
            return error.SurfaceHandleInvalid;
        }
        return &native.surface;
    }

    fn roundtrip(native: *Native) !void {
        if (wl.wl_display_roundtrip(native.display.?) < 0 or native.failed) {
            return error.WaylandRoundtripFailed;
        }
    }

    fn dispatch(native: *Native, started: std.Io.Clock.Timestamp) !bool {
        if (wl.wl_display_dispatch_pending(native.display.?) < 0 or native.failed) {
            return error.WaylandDispatchFailed;
        }
        const elapsed = started.durationTo(std.Io.Clock.awake.now(native.io)).toMilliseconds();
        if (elapsed >= wallpaper.wayland_wait_milliseconds) return false;
        if (wl.wl_display_flush(native.display.?) < 0) return error.WaylandFlushFailed;
        while (wl.wl_display_prepare_read(native.display.?) != 0) {
            if (wl.wl_display_dispatch_pending(native.display.?) < 0) return error.WaylandDispatchFailed;
        }
        var descriptors = [1]std.posix.pollfd{.{
            .fd = wl.wl_display_get_fd(native.display.?),
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};
        const ready = std.posix.poll(
            &descriptors,
            @intCast(wallpaper.wayland_wait_milliseconds - elapsed),
        ) catch |err| {
            wl.wl_display_cancel_read(native.display.?);
            return err;
        };
        if (ready == 0) {
            wl.wl_display_cancel_read(native.display.?);
            return false;
        }
        if (descriptors[0].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL) != 0) {
            wl.wl_display_cancel_read(native.display.?);
            return error.WaylandDispatchFailed;
        }
        if (wl.wl_display_read_events(native.display.?) < 0) return error.WaylandDispatchFailed;
        if (wl.wl_display_dispatch_pending(native.display.?) < 0 or native.failed) {
            return error.WaylandDispatchFailed;
        }
        return true;
    }

    fn disconnectDisplayLoss(native: *Native) void {
        wl.wl_display_disconnect(native.display.?);
        native.display = null;
        native.registry_proxy = null;
        native.compositor = null;
        native.shm = null;
        native.viewporter = null;
        native.layer_shell = null;
        native.output = null;
    }

    pub fn decode(_: *Native, allocator: std.mem.Allocator, bytes: []const u8) !wallpaper.Image {
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
        _: *Native,
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

const OutputProbe = struct {
    name_bytes: [wallpaper.monitor_name_capacity]u8 = undefined,
    name_length: u8 = 0,
    name_seen: bool = false,
    done: bool = false,
    invalid: bool = false,
};

const Surface = struct {
    occupied: bool = false,
    generation: u32 = 0,
    surface: ?*wl.wl_surface = null,
    region: ?*wl.wl_region = null,
    layer: ?*wl.zwlr_layer_surface_v1 = null,
    viewport: ?*wl.wp_viewport = null,
    shm_fd: ?std.posix.fd_t = null,
    mapping: ?[]align(std.heap.page_size_min) u8 = null,
    pool: ?*wl.wl_shm_pool = null,
    buffer: ?*wl.wl_buffer = null,
    configure: ?wallpaper.Configure = null,
    configure_count: u8 = 0,
    closed: bool = false,
    committed: bool = false,
    released: bool = false,

    fn destroyProxies(surface: *Surface) void {
        if (surface.region) |proxy| wl.wl_region_destroy(proxy);
        if (surface.buffer) |proxy| wl.wl_buffer_destroy(proxy);
        if (surface.pool) |proxy| wl.wl_shm_pool_destroy(proxy);
        if (surface.viewport) |proxy| wl.wp_viewport_destroy(proxy);
        if (surface.layer) |proxy| wl.zwlr_layer_surface_v1_destroy(proxy);
        if (surface.surface) |proxy| wl.wl_surface_destroy(proxy);
    }

    fn destroyLocal(surface: *Surface) void {
        if (surface.mapping) |mapping| std.posix.munmap(mapping);
        if (surface.shm_fd) |fd| std.posix.close(fd);
    }

    fn localResourcesReleased(surface: *const Surface) bool {
        return surface.surface == null and surface.layer == null and surface.viewport == null and
            surface.buffer == null and surface.pool == null and surface.mapping == null and surface.shm_fd == null;
    }
};

const registry_listener = wl.wl_registry_listener{
    .global = registryGlobal,
    .global_remove = registryRemove,
};

fn registryGlobal(
    data: ?*anyopaque,
    registry: ?*wl.wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    const native: *Native = @ptrCast(@alignCast(data));
    if (native.global_count == wallpaper.wayland_global_capacity) {
        native.failed = true;
        return;
    }
    native.global_count += 1;
    const interface_name = std.mem.span(interface);
    if (std.mem.eql(u8, interface_name, "wl_compositor")) {
        if (!bindGlobal(&native.compositor, registry, name, version, 4, &wl.wl_compositor_interface)) {
            native.failed = true;
        }
    } else if (std.mem.eql(u8, interface_name, "wl_shm")) {
        if (!bindGlobal(&native.shm, registry, name, version, 1, &wl.wl_shm_interface)) native.failed = true;
    } else if (std.mem.eql(u8, interface_name, "wp_viewporter")) {
        if (!bindGlobal(&native.viewporter, registry, name, version, 1, &wl.wp_viewporter_interface)) {
            native.failed = true;
        }
    } else if (std.mem.eql(u8, interface_name, "zwlr_layer_shell_v1")) {
        if (!bindGlobal(
            &native.layer_shell,
            registry,
            name,
            version,
            3,
            &wl.zwlr_layer_shell_v1_interface,
        )) native.failed = true;
    } else if (std.mem.eql(u8, interface_name, "wl_output")) {
        if (version < 4 or native.output_count == wallpaper.monitor_capacity) {
            native.failed = true;
            return;
        }
        native.output_globals[native.output_count] = name;
        native.output_count += 1;
    }
}

fn bindGlobal(
    current: anytype,
    registry: ?*wl.wl_registry,
    name: u32,
    advertised: u32,
    required: u32,
    interface: *const wl.wl_interface,
) bool {
    if (current.* != null or advertised < required) return false;
    current.* = @ptrCast(wl.wl_registry_bind(registry, name, interface, required));
    return current.* != null;
}

fn registryRemove(data: ?*anyopaque, _: ?*wl.wl_registry, _: u32) callconv(.c) void {
    const native: *Native = @ptrCast(@alignCast(data));
    native.failed = true;
}

const output_listener = wl.wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = outputDescription,
};

fn outputGeometry(
    data: ?*anyopaque,
    _: ?*wl.wl_output,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: [*c]const u8,
    _: [*c]const u8,
    _: i32,
) callconv(.c) void {
    _ = data;
}

fn outputMode(
    data: ?*anyopaque,
    _: ?*wl.wl_output,
    _: u32,
    _: i32,
    _: i32,
    _: i32,
) callconv(.c) void {
    _ = data;
}

fn outputDone(data: ?*anyopaque, _: ?*wl.wl_output) callconv(.c) void {
    const probe: *OutputProbe = @ptrCast(@alignCast(data));
    if (!probe.name_seen) {
        probe.invalid = true;
        return;
    }
    probe.done = true;
}

fn outputScale(_: ?*anyopaque, _: ?*wl.wl_output, _: i32) callconv(.c) void {}

fn outputName(data: ?*anyopaque, _: ?*wl.wl_output, name: [*c]const u8) callconv(.c) void {
    const probe: *OutputProbe = @ptrCast(@alignCast(data));
    const bytes = std.mem.span(name);
    if (probe.name_seen or bytes.len == 0 or bytes.len > wallpaper.monitor_name_capacity or
        !std.unicode.utf8ValidateSlice(bytes))
    {
        probe.invalid = true;
        return;
    }
    @memcpy(probe.name_bytes[0..bytes.len], bytes);
    probe.name_length = @intCast(bytes.len);
    probe.name_seen = true;
}

fn outputDescription(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}

const layer_listener = wl.zwlr_layer_surface_v1_listener{
    .configure = layerConfigure,
    .closed = layerClosed,
};

fn layerConfigure(
    data: ?*anyopaque,
    _: ?*wl.zwlr_layer_surface_v1,
    serial: u32,
    width: u32,
    height: u32,
) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    if (surface.configure_count == wallpaper.wayland_configure_capacity) {
        surface.closed = true;
        return;
    }
    surface.configure_count += 1;
    surface.configure = .{ .serial = serial, .width = width, .height = height };
}

fn layerClosed(data: ?*anyopaque, _: ?*wl.zwlr_layer_surface_v1) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    surface.closed = true;
}

const buffer_listener = wl.wl_buffer_listener{ .release = bufferRelease };

fn bufferRelease(data: ?*anyopaque, _: ?*wl.wl_buffer) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    surface.released = true;
}

fn surfaceSide(value: c_int) !u32 {
    if (value <= 0) return error.ImageDimensionsZero;
    if (value > wallpaper.image_side_capacity) return error.ImageDimensionsTooLarge;
    return @intCast(value);
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

fn surfaceParity(native: *Native, monitor: *const wallpaper.Monitor, pixels: *const wallpaper.Image) !void {
    try wallpaper.openOutput(native, monitor.name());
    defer native.disconnect();
    const handle = try wallpaper.prepareSurface(native, monitor, pixels);
    try wallpaper.releaseSurface(native, handle);
}

test "native adapter reaches every one-surface operation without a display" {
    _ = surfaceParity;
}

test "output probe owns only one exact name and done identity" {
    var probe: OutputProbe = .{};
    outputName(&probe, null, "DP-1");
    outputDone(&probe, null);
    try std.testing.expect(probe.name_seen);
    try std.testing.expect(probe.done);
    try std.testing.expectEqualStrings("DP-1", probe.name_bytes[0..probe.name_length]);
    outputName(&probe, null, "DP-1");
    try std.testing.expect(probe.invalid);
    probe = .{};
    outputDone(&probe, null);
    try std.testing.expect(probe.invalid);
}

test "surface handles reject absent stale and wrong generations" {
    var native = Native{ .io = std.testing.io };
    native.surface = .{ .occupied = true, .generation = 7 };
    _ = try native.checkedSurface(.{ .generation = 7 });
    try std.testing.expectError(error.SurfaceHandleInvalid, native.checkedSurface(.{ .generation = 8 }));
    native.surface = .{};
    try std.testing.expectError(error.SurfaceHandleInvalid, native.checkedSurface(.{ .generation = 7 }));
}

test "configure histories are bounded" {
    var surface: Surface = .{};
    for (0..wallpaper.wayland_configure_capacity) |serial| {
        layerConfigure(&surface, null, @intCast(serial), 1, 1);
    }
    layerConfigure(&surface, null, 99, 1, 1);
    try std.testing.expect(surface.closed);
}

test "native PNG file decode and linear cover scaling" {
    const png =
        "\x89PNG\r\n\x1a\n" ++
        "\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89" ++
        "\x00\x00\x00\x0dIDAT\x78\x9c\x63\xf8\xcf\xc0\xd0\x00\x00\x04\x81\x01\x80\x2c\x55\xce\xb0" ++
        "\x00\x00\x00\x00IEND\xae\x42\x60\x82";
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "one.png", .data = png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "one.png", std.testing.allocator);
    defer std.testing.allocator.free(path);

    var native = Native{ .io = std.testing.io };
    var image = try wallpaper.loadImage(&native, std.testing.allocator, path);
    defer image.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 1), image.width);
    try std.testing.expectEqual(@as(u32, 1), image.height);
    try std.testing.expectEqual(@as(u32, 0xff800000), image.pixels[0]);
    var pixels = try wallpaper.coverImage(&native, std.testing.allocator, &image, 3, 2);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 12), pixels.pitch);
    for (pixels.pixels) |pixel| try std.testing.expectEqual(@as(u32, 0xff800000), pixel);
    try std.testing.expect(native.file == null);
}

test "native malformed PNG closes its file and publishes no image" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var png: [24]u8 = @splat(0);
    @memcpy(png[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(png[12..16], "IHDR");
    std.mem.writeInt(u32, png[16..20], 1, .big);
    std.mem.writeInt(u32, png[20..24], 1, .big);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "broken.png", .data = &png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "broken.png", std.testing.allocator);
    defer std.testing.allocator.free(path);
    var native = Native{ .io = std.testing.io };
    try std.testing.expectError(
        error.ImageDecodeFailed,
        wallpaper.loadImage(&native, std.testing.allocator, path),
    );
    try std.testing.expect(native.file == null);
}

test "native unsupported IO acquires no file" {
    var native = Native{ .io = std.Io.failing };
    if (native.open("wallpaper.png")) |_| {
        return error.ExpectedOpenFailure;
    } else |_| {}
    try std.testing.expect(native.file == null);
}

test "bounded malformed PNG data publishes no partial image" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzPng, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzPng({}, &empty);
}

fn fuzzPng(_: void, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var native = Native{ .io = std.Io.failing };
    if (native.decode(std.testing.allocator, input)) |value| {
        var image = value;
        defer image.deinit(std.testing.allocator);
        try std.testing.expect(image.width > 0 and image.width <= wallpaper.image_side_capacity);
        try std.testing.expect(image.height > 0 and image.height <= wallpaper.image_side_capacity);
        try std.testing.expectEqual(@as(usize, image.width) * image.height, image.pixels.len);
    } else |_| {}
}
