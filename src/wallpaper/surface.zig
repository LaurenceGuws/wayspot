//! Wallpaper surface owns one layer-shell surface and one attached shm buffer.

const std = @import("std");
const monitor_facts = @import("wayspot_env_native").monitor;

const c = @import("sdl_c");
const wayland = @import("wayland_c");

pub const class_name = "wayspot-wallpaper";
const layer_namespace = "wayspot-wallpaper";
const anchor_all_edges: u32 = 1 | 2 | 4 | 8;
const wallpaper_pixel_format = c.SDL_PIXELFORMAT_XRGB8888;
const wallpaper_shm_format = c.WL_SHM_FORMAT_XRGB8888;

const ImageKind = enum {
    png,
    bmp,
};

pub const WallpaperSurface = struct {
    layer: LayerShellRole,
    monitor: monitor_facts.Monitor,

    /// init owns one direct Wayland connection and one layer-shell surface.
    pub fn init(monitor: monitor_facts.Monitor) !WallpaperSurface {
        var layer = try LayerShellRole.init(monitor);
        errdefer layer.deinit();
        return .{ .layer = layer, .monitor = monitor };
    }

    pub fn drawImage(self: *WallpaperSurface, path: [:0]const u8) !void {
        try self.layer.drawImage(self.monitor, path);
    }

    pub fn deinit(self: *WallpaperSurface) void {
        self.layer.deinit();
    }
};

const LayerShellRole = struct {
    globals: wayland.struct_wayspot_layer_globals = undefined,
    layer_surface: ?*wayland.struct_zwlr_layer_surface_v1 = null,
    wl_surface: ?*wayland.struct_wl_surface = null,
    display: ?*wayland.struct_wl_display = null,
    attached_buffer: wayland.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 },
    attached_buffer_created: bool = false,

    /// init creates the role handshake on the private display owned by this surface.
    fn init(monitor: monitor_facts.Monitor) !LayerShellRole {
        var role = LayerShellRole{};
        role.display = wayland.wayspot_wayland_connect() orelse return error.WaylandDisplayUnavailable;
        errdefer wayland.wayspot_wayland_disconnect(role.display.?);
        try mapLayerGlobalsResult(wayland.wayspot_layer_globals_init(&role.globals, role.display.?));
        errdefer wayland.wayspot_layer_globals_deinit(&role.globals);
        role.wl_surface = wayland.wayspot_layer_create_surface(&role.globals) orelse return error.WaylandSurfaceUnavailable;
        errdefer wayland.wayspot_wl_surface_destroy(role.wl_surface.?);

        var monitor_name_buf: [monitor_facts.max_monitor_name_bytes:0]u8 = undefined;
        const monitor_name = try std.fmt.bufPrintZ(&monitor_name_buf, "{s}", .{monitor.nameText()});
        const output = wayland.wayspot_layer_find_output(&role.globals, monitor_name.ptr) orelse return error.LayerShellOutputMissing;
        const layer_surface = wayland.wayspot_layer_get_surface(&role.globals, role.wl_surface.?, output, layer_namespace) orelse return error.LayerShellSurfaceCreateFailed;
        role.layer_surface = layer_surface;
        errdefer role.destroyLayerSurface();

        var configure_state = wayland.struct_wayspot_layer_configure_state{
            .configured = 0,
            .closed = 0,
            .serial = 0,
            .width = 0,
            .height = 0,
        };
        wayland.wayspot_layer_surface_add_listener(layer_surface, &configure_state);
        wayland.wayspot_layer_surface_set_size(layer_surface, @intCast(monitor.size.width), @intCast(monitor.size.height));
        wayland.wayspot_layer_surface_set_anchor(layer_surface, anchor_all_edges);
        wayland.wayspot_layer_surface_set_exclusive_zone(layer_surface, -1);
        wayland.wayspot_layer_surface_set_keyboard_interactivity(layer_surface, 0);
        wayland.wayspot_wl_surface_commit(role.wl_surface.?);

        while (configure_state.configured == 0) {
            if (configure_state.closed != 0) {
                return error.LayerShellClosed;
            }
            if (wayland.wayspot_wl_display_roundtrip(role.display.?) < 0) return error.LayerShellConfigureFailed;
        }

        wayland.wayspot_layer_surface_ack_configure(layer_surface, configure_state.serial);
        wayland.wayspot_wl_surface_commit(role.wl_surface.?);
        if (wayland.wayspot_wl_display_roundtrip(role.display.?) < 0) return error.LayerShellConfigureFailed;
        return role;
    }

    fn drawImage(self: *LayerShellRole, monitor: monitor_facts.Monitor, path: [:0]const u8) !void {
        var next_buffer: wayland.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        try mapWallpaperImageResult(wayland.wayspot_shm_buffer_create(
            &self.globals,
            &next_buffer,
            @intCast(monitor.size.width),
            @intCast(monitor.size.height),
            wallpaper_shm_format,
        ));
        errdefer wayland.wayspot_shm_buffer_destroy(&next_buffer);
        try drawImageIntoBuffer(&next_buffer, monitor, path);
        try self.attachCreatedBuffer(monitor, &next_buffer);
    }

    fn attachCreatedBuffer(self: *LayerShellRole, monitor: monitor_facts.Monitor, next_buffer: *wayland.struct_wayspot_shm_buffer) !void {
        const wl_surface = self.wl_surface orelse {
            destroyBuffer(next_buffer);
            return error.WaylandSurfaceUnavailable;
        };
        var old_buffer = self.takeAttachedBuffer();
        self.attached_buffer = next_buffer.*;
        next_buffer.* = .{ .buffer = null, .data = null, .byte_len = 0 };
        self.attached_buffer_created = true;
        wayland.wayspot_wl_surface_attach_buffer(wl_surface, &self.attached_buffer, @intCast(monitor.size.width), @intCast(monitor.size.height));
        wayland.wayspot_wl_surface_commit(wl_surface);
        if (self.display) |display| {
            wayland.wayspot_wl_display_roundtrip_cleanup(display);
        }
        if (old_buffer) |*buffer| {
            destroyBuffer(buffer);
        }
    }

    fn deinit(self: *LayerShellRole) void {
        if (self.wl_surface) |wl_surface| {
            wayland.wayspot_wl_surface_detach_buffer(wl_surface);
            wayland.wayspot_wl_surface_commit(wl_surface);
            if (self.display) |display| {
                wayland.wayspot_wl_display_roundtrip_cleanup(display);
            }
        }
        var attached_buffer = self.takeAttachedBuffer();
        if (attached_buffer) |*buffer| {
            destroyBuffer(buffer);
        }
        self.destroyLayerSurface();
        if (self.display) |display| {
            wayland.wayspot_wl_display_roundtrip_cleanup(display);
        }
        if (self.wl_surface) |wl_surface| wayland.wayspot_wl_surface_destroy(wl_surface);
        wayland.wayspot_layer_globals_deinit(&self.globals);
        if (self.display) |display| wayland.wayspot_wayland_disconnect(display);
    }

    fn destroyLayerSurface(self: *LayerShellRole) void {
        if (self.layer_surface) |layer_surface| {
            wayland.wayspot_layer_surface_destroy(layer_surface);
            self.layer_surface = null;
        }
    }

    fn takeAttachedBuffer(self: *LayerShellRole) ?wayland.struct_wayspot_shm_buffer {
        if (!self.attached_buffer_created) return null;
        const buffer = self.attached_buffer;
        self.attached_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        self.attached_buffer_created = false;
        return buffer;
    }
};

fn destroyBuffer(buffer: *wayland.struct_wayspot_shm_buffer) void {
    wayland.wayspot_shm_buffer_destroy(buffer);
}

fn mapLayerGlobalsResult(result: wayland.enum_wayspot_layer_result) !void {
    return switch (result) {
        wayland.WAYSPOT_LAYER_OK => {},
        wayland.WAYSPOT_LAYER_REGISTRY_FAILED => error.LayerShellRegistryFailed,
        wayland.WAYSPOT_LAYER_REGISTRY_LISTENER_FAILED => error.LayerShellRegistryListenerFailed,
        wayland.WAYSPOT_LAYER_DISPLAY_ROUNDTRIP_FAILED => error.LayerShellRoundtripFailed,
        wayland.WAYSPOT_LAYER_SHELL_MISSING => error.LayerShellMissing,
        wayland.WAYSPOT_LAYER_COMPOSITOR_MISSING => error.LayerShellCompositorMissing,
        wayland.WAYSPOT_LAYER_SHM_MISSING => error.LayerShellShmMissing,
        else => error.LayerShellUnexpectedResult,
    };
}

fn mapWallpaperImageResult(result: wayland.enum_wayspot_layer_result) !void {
    return switch (result) {
        wayland.WAYSPOT_LAYER_OK => {},
        wayland.WAYSPOT_LAYER_INVALID_SIZE => error.WallpaperInvalidBufferSize,
        wayland.WAYSPOT_LAYER_MEMFD_FAILED => error.WallpaperMemfdFailed,
        wayland.WAYSPOT_LAYER_TRUNCATE_FAILED => error.WallpaperTruncateFailed,
        wayland.WAYSPOT_LAYER_MMAP_FAILED => error.WallpaperMmapFailed,
        wayland.WAYSPOT_LAYER_SHM_POOL_FAILED => error.WallpaperShmPoolFailed,
        wayland.WAYSPOT_LAYER_WL_BUFFER_FAILED => error.WallpaperWlBufferFailed,
        wayland.WAYSPOT_LAYER_SHM_MISSING => error.LayerShellShmMissing,
        else => error.WallpaperImageUnexpectedResult,
    };
}

fn drawImageIntoBuffer(buffer: *wayland.struct_wayspot_shm_buffer, monitor: monitor_facts.Monitor, path: [:0]const u8) !void {
    const loaded = try loadAcceptedImage(path);
    defer c.SDL_DestroySurface(loaded);

    const source = c.SDL_ConvertSurface(loaded, wallpaper_pixel_format) orelse return error.WallpaperImageConvertFailed;
    defer c.SDL_DestroySurface(source);

    const target = c.SDL_CreateSurfaceFrom(
        @intCast(monitor.size.width),
        @intCast(monitor.size.height),
        wallpaper_pixel_format,
        buffer.data,
        @intCast(monitor.size.width * 4),
    ) orelse return error.WallpaperImageTargetFailed;
    defer c.SDL_DestroySurface(target);

    var source_rect = try coverSourceRect(source.*.w, source.*.h, @intCast(monitor.size.width), @intCast(monitor.size.height));
    if (!c.SDL_BlitSurfaceScaled(source, &source_rect, target, null, c.SDL_SCALEMODE_LINEAR)) return error.WallpaperImageScaleFailed;
}

fn loadAcceptedImage(path: [:0]const u8) !*c.SDL_Surface {
    return switch (try imageKind(path)) {
        .png => c.SDL_LoadPNG(path.ptr) orelse error.WallpaperImageLoadFailed,
        .bmp => c.SDL_LoadBMP(path.ptr) orelse error.WallpaperImageLoadFailed,
    };
}

fn imageKind(path: []const u8) !ImageKind {
    if (hasExtension(path, ".png")) return .png;
    if (hasExtension(path, ".bmp")) return .bmp;
    return error.WallpaperUnsupportedImageExtension;
}

fn hasExtension(path: []const u8, extension: []const u8) bool {
    if (path.len < extension.len) return false;
    return std.ascii.eqlIgnoreCase(path[path.len - extension.len ..], extension);
}

fn coverSourceRect(source_width: i32, source_height: i32, target_width: i32, target_height: i32) !c.SDL_Rect {
    if (source_width <= 0 or source_height <= 0 or target_width <= 0 or target_height <= 0) return error.WallpaperImageScaleFailed;
    const source_as_target_wide = @as(i64, source_width) * target_height;
    const target_as_source_wide = @as(i64, target_width) * source_height;
    if (source_as_target_wide > target_as_source_wide) {
        const crop_width: i32 = @intCast(@divTrunc(@as(i64, source_height) * target_width, target_height));
        return positiveRect(.{ .x = @divTrunc(source_width - crop_width, 2), .y = 0, .w = crop_width, .h = source_height });
    }
    const crop_height: i32 = @intCast(@divTrunc(@as(i64, source_width) * target_height, target_width));
    return positiveRect(.{ .x = 0, .y = @divTrunc(source_height - crop_height, 2), .w = source_width, .h = crop_height });
}

fn positiveRect(rect: c.SDL_Rect) !c.SDL_Rect {
    if (rect.w <= 0 or rect.h <= 0) return error.WallpaperImageScaleFailed;
    return rect;
}

test "wallpaper maps typed C layer results" {
    try mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_OK);
    try std.testing.expectError(error.LayerShellRegistryFailed, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_REGISTRY_FAILED));
    try std.testing.expectError(error.LayerShellRegistryListenerFailed, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_REGISTRY_LISTENER_FAILED));
    try std.testing.expectError(error.LayerShellRoundtripFailed, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_DISPLAY_ROUNDTRIP_FAILED));
    try std.testing.expectError(error.LayerShellMissing, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_SHELL_MISSING));
    try std.testing.expectError(error.LayerShellCompositorMissing, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_COMPOSITOR_MISSING));
    try std.testing.expectError(error.LayerShellShmMissing, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_SHM_MISSING));
    try std.testing.expectError(error.LayerShellUnexpectedResult, mapLayerGlobalsResult(wayland.WAYSPOT_LAYER_MEMFD_FAILED));
}

test "wallpaper maps typed C image results" {
    try mapWallpaperImageResult(wayland.WAYSPOT_LAYER_OK);
    try std.testing.expectError(error.WallpaperInvalidBufferSize, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_INVALID_SIZE));
    try std.testing.expectError(error.WallpaperMemfdFailed, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_MEMFD_FAILED));
    try std.testing.expectError(error.WallpaperTruncateFailed, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_TRUNCATE_FAILED));
    try std.testing.expectError(error.WallpaperMmapFailed, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_MMAP_FAILED));
    try std.testing.expectError(error.WallpaperShmPoolFailed, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_SHM_POOL_FAILED));
    try std.testing.expectError(error.WallpaperWlBufferFailed, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_WL_BUFFER_FAILED));
    try std.testing.expectError(error.LayerShellShmMissing, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_SHM_MISSING));
    try std.testing.expectError(error.WallpaperImageUnexpectedResult, mapWallpaperImageResult(wayland.WAYSPOT_LAYER_SHELL_MISSING));
}

test "wallpaper accepts only png and bmp image extensions" {
    try std.testing.expectEqual(ImageKind.png, try imageKind("/tmp/wallpaper.png"));
    try std.testing.expectEqual(ImageKind.png, try imageKind("/tmp/wallpaper.PNG"));
    try std.testing.expectEqual(ImageKind.bmp, try imageKind("/tmp/wallpaper.bmp"));
    try std.testing.expectEqual(ImageKind.bmp, try imageKind("/tmp/wallpaper.BMP"));
    try std.testing.expectError(error.WallpaperUnsupportedImageExtension, imageKind("/tmp/wallpaper.jpg"));
    try std.testing.expectError(error.WallpaperUnsupportedImageExtension, imageKind("/tmp/png"));
}

test "wallpaper missing accepted image file maps to image load error" {
    try std.testing.expectError(error.WallpaperImageLoadFailed, loadAcceptedImage("/tmp/wayspot-missing-wallpaper-slice06.png"));
}

test "wallpaper cover source rect matches previous C behavior" {
    try std.testing.expectEqual(c.SDL_Rect{ .x = 500, .y = 0, .w = 3000, .h = 3000 }, try coverSourceRect(4000, 3000, 1000, 1000));
    try std.testing.expectEqual(c.SDL_Rect{ .x = 0, .y = 375, .w = 4000, .h = 2250 }, try coverSourceRect(4000, 3000, 1600, 900));
    try std.testing.expectEqual(c.SDL_Rect{ .x = 437, .y = 0, .w = 1125, .h = 1500 }, try coverSourceRect(2000, 1500, 900, 1200));
    try std.testing.expectError(error.WallpaperImageScaleFailed, coverSourceRect(0, 1500, 900, 1200));
}

test "wallpaper attach failure destroys next empty buffer and keeps previous attachment" {
    var role = LayerShellRole{
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 64 },
        .attached_buffer_created = true,
    };
    var next_buffer = wayland.struct_wayspot_shm_buffer{ .buffer = null, .data = null, .byte_len = 12 };
    const monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", try monitor_facts.MonitorSize.init(10, 10));

    try std.testing.expectError(error.WaylandSurfaceUnavailable, role.attachCreatedBuffer(monitor, &next_buffer));
    try std.testing.expectEqual(@as(u32, 0), next_buffer.byte_len);
    try std.testing.expect(role.attached_buffer_created);
    try std.testing.expectEqual(@as(u32, 64), role.attached_buffer.byte_len);
}

test "wallpaper draw failure keeps attached buffer state" {
    var role = LayerShellRole{
        .globals = emptyLayerGlobals(),
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 88 },
        .attached_buffer_created = true,
    };
    const monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", try monitor_facts.MonitorSize.init(10, 10));

    try std.testing.expectError(error.LayerShellShmMissing, role.drawImage(monitor, "/tmp/missing.png"));
    try std.testing.expect(role.attached_buffer_created);
    try std.testing.expectEqual(@as(u32, 88), role.attached_buffer.byte_len);
}

fn emptyLayerGlobals() wayland.struct_wayspot_layer_globals {
    return .{
        .display = null,
        .registry = null,
        .compositor = null,
        .shm = null,
        .layer_shell = null,
        .outputs = std.mem.zeroes([wayland.WAYSPOT_LAYER_MAX_OUTPUTS]wayland.struct_wayspot_layer_output),
        .output_count = 0,
    };
}

test "wallpaper attached buffer cleanup is single owner transition" {
    var role = LayerShellRole{
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 31 },
        .attached_buffer_created = true,
    };

    const first = role.takeAttachedBuffer() orelse return error.TestExpectedAttachedBuffer;
    try std.testing.expectEqual(@as(u32, 31), first.byte_len);
    try std.testing.expect(!role.attached_buffer_created);
    try std.testing.expectEqual(@as(?wayland.struct_wayspot_shm_buffer, null), role.takeAttachedBuffer());
}
