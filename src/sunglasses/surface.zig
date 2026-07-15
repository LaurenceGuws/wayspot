//! Sunglasses surface owns one pass-through overlay layer and state tint buffer.

const std = @import("std");
const monitor_facts = @import("wayspot_env").monitor;
const sunglasses_state = @import("../sunglasses/state.zig");
const sdl_io = @import("sdl_io");
const sdl_native = @import("sdl_native");
const sunglasses_setup = @import("sunglasses_setup");
const wayland_native = @import("wayland_native");

const c = @import("sdl_c");

pub const class_name = "wayspot-sunglasses";
const max_title_bytes: u32 = sdl_io.max_window_title_bytes;
const tint_max_alpha: u32 = 120;
const dim_max_alpha: u32 = 220;
const max_image_path_z_bytes: u32 = sunglasses_state.max_image_path_bytes + 1;
const sunglasses_pixel_format = c.SDL_PIXELFORMAT_ARGB8888;
const sunglasses_shm_format = c.WL_SHM_FORMAT_ARGB8888;

const ImageKind = enum {
    png,
    bmp,
};

pub const SunglassesSurface = struct {
    window: sdl_native.SdlWindowIo,
    layer: LayerShellRole,
    monitor: monitor_facts.Monitor,

    /// The surface owns compositor resources but not monitor discovery or picker lifecycle.
    pub fn init(monitor: monitor_facts.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !SunglassesSurface {
        var title_buf: [max_title_bytes:0]u8 = undefined;
        const window_title = try writeTitle(&title_buf, monitor.nameText());
        const title = try sdl_io.WindowTitle.init(window_title[0..window_title.len]);
        const monitor_name = try sdl_io.DisplayName.init(monitor.nameText());
        const size = try sdl_io.WindowSize.init(monitor.size.width, monitor.size.height);
        const plan = sunglasses_setup.SetupPlan.init(monitor_name, title, size);
        var window = try createNativeWindow(plan);
        errdefer window.deinit();

        var layer = try LayerShellRole.init(&window, plan);
        errdefer layer.deinit();

        try layer.drawStateSurface(monitor, monitor_state);

        return .{
            .window = window,
            .layer = layer,
            .monitor = monitor,
        };
    }

    pub fn deinit(self: *SunglassesSurface) void {
        self.layer.deinit();
        self.window.deinit();
    }

    pub fn redraw(self: *SunglassesSurface, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        try self.layer.drawStateSurface(self.monitor, monitor_state);
    }
};

fn createNativeWindow(plan: sunglasses_setup.SetupPlan) !sdl_native.SdlWindowIo {
    var properties: ?sdl_native.SdlWindowPropertyIo = null;
    errdefer if (properties) |*value| value.deinit();
    var window: ?sdl_native.SdlWindowIo = null;
    for (sunglasses_setup.window_commands) |command| switch (command) {
        .property_create => properties = try sdl_native.SdlWindowPropertyIo.create(),
        .set_title => try properties.?.setTitle(plan.title),
        .set_width => try properties.?.setWidth(plan.size.width),
        .set_height => try properties.?.setHeight(plan.size.height),
        .set_hidden => try properties.?.setHidden(true),
        .set_custom_surface_role => try properties.?.setCustomSurfaceRole(true),
        .set_create_egl_window => try properties.?.setCreateEglWindow(true),
        .window_create => window = try sdl_native.SdlWindowIo.create(&properties.?),
        .property_destroy => properties.?.deinit(),
    };
    return window orelse unreachable;
}

const LayerShellRole = struct {
    native: wayland_native.WaylandIo,
    attached_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 },
    attached_buffer_created: bool = false,

    fn init(window: *sdl_native.SdlWindowIo, plan: sunglasses_setup.SetupPlan) !LayerShellRole {
        return .{
            .native = try wayland_native.WaylandIo.init(window, plan),
        };
    }

    fn drawStateSurface(self: *LayerShellRole, monitor: monitor_facts.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        if (monitor_state) |state| {
            if (useImageBuffer(state)) {
                try self.drawStateImage(monitor, state);
                return;
            }
        }
        try self.drawStateTint(monitor, monitor_state);
    }

    fn drawStateImage(self: *LayerShellRole, monitor: monitor_facts.Monitor, monitor_state: *const sunglasses_state.MonitorState) !void {
        var path_buf: [max_image_path_z_bytes:0]u8 = undefined;
        const image_path = try writeImagePath(&path_buf, monitor_state.imagePath());
        var next_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        const globals = self.native.globalsPtr() orelse return error.LayerShellShmMissing;
        try mapSunglassesBufferResult(c.wayspot_shm_buffer_create(
            globals,
            &next_buffer,
            @intCast(monitor.size.width),
            @intCast(monitor.size.height),
            sunglasses_shm_format,
        ));
        errdefer c.wayspot_shm_buffer_destroy(&next_buffer);
        try drawImageIntoBuffer(&next_buffer, monitor, image_path, @intCast(sunglasses_state.clampImageOpacity(monitor_state.image_opacity)), stateArgb(monitor_state));
        try self.attachCreatedBuffer(monitor, &next_buffer);
    }

    fn drawStateTint(self: *LayerShellRole, monitor: monitor_facts.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        var next_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        const globals = self.native.globalsPtr() orelse return error.LayerShellShmMissing;
        try mapSunglassesBufferResult(c.wayspot_shm_buffer_create(
            globals,
            &next_buffer,
            @intCast(monitor.size.width),
            @intCast(monitor.size.height),
            sunglasses_shm_format,
        ));
        errdefer c.wayspot_shm_buffer_destroy(&next_buffer);
        fillBuffer(&next_buffer, monitor, stateArgb(monitor_state));
        try self.attachCreatedBuffer(monitor, &next_buffer);
    }

    fn attachCreatedBuffer(self: *LayerShellRole, monitor: monitor_facts.Monitor, next_buffer: *c.struct_wayspot_shm_buffer) !void {
        const wl_surface = self.native.surfacePtr() orelse {
            c.wayspot_shm_buffer_destroy(next_buffer);
            return error.WaylandSurfaceUnavailable;
        };
        c.wayspot_wl_surface_attach_buffer(
            wl_surface,
            next_buffer,
            @intCast(monitor.size.width),
            @intCast(monitor.size.height),
        );
        c.wayspot_wl_surface_commit(wl_surface);
        if (self.native.displayPtr()) |display| {
            c.wayspot_wl_display_roundtrip_cleanup(display);
        }
        var old_buffer = self.takeAttachedBuffer();
        self.attached_buffer = next_buffer.*;
        next_buffer.* = .{ .buffer = null, .data = null, .byte_len = 0 };
        self.attached_buffer_created = true;
        if (old_buffer) |*buffer| {
            c.wayspot_shm_buffer_destroy(buffer);
        }
    }

    fn deinit(self: *LayerShellRole) void {
        if (self.native.surfacePtr()) |wl_surface| {
            c.wayspot_wl_surface_detach_buffer(wl_surface);
            c.wayspot_wl_surface_commit(wl_surface);
            if (self.native.displayPtr()) |display| {
                c.wayspot_wl_display_roundtrip_cleanup(display);
            }
        }
        var attached_buffer = self.takeAttachedBuffer();
        if (attached_buffer) |*buffer| {
            c.wayspot_shm_buffer_destroy(buffer);
        }
        self.native.deinit();
    }

    fn takeAttachedBuffer(self: *LayerShellRole) ?c.struct_wayspot_shm_buffer {
        if (!self.attached_buffer_created) return null;
        const buffer = self.attached_buffer;
        self.attached_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        self.attached_buffer_created = false;
        return buffer;
    }
};

fn mapLayerGlobalsResult(result: c.enum_wayspot_layer_result) !void {
    return switch (result) {
        c.WAYSPOT_LAYER_OK => {},
        c.WAYSPOT_LAYER_REGISTRY_FAILED => error.LayerShellRegistryFailed,
        c.WAYSPOT_LAYER_REGISTRY_LISTENER_FAILED => error.LayerShellRegistryListenerFailed,
        c.WAYSPOT_LAYER_DISPLAY_ROUNDTRIP_FAILED => error.LayerShellRoundtripFailed,
        c.WAYSPOT_LAYER_SHELL_MISSING => error.LayerShellMissing,
        c.WAYSPOT_LAYER_COMPOSITOR_MISSING => error.LayerShellCompositorMissing,
        c.WAYSPOT_LAYER_SHM_MISSING => error.LayerShellShmMissing,
        else => error.LayerShellUnexpectedResult,
    };
}

fn mapLayerInputRegionResult(result: c.enum_wayspot_layer_result) !void {
    return switch (result) {
        c.WAYSPOT_LAYER_OK => {},
        c.WAYSPOT_LAYER_INPUT_REGION_FAILED => error.LayerShellInputRegionFailed,
        c.WAYSPOT_LAYER_COMPOSITOR_MISSING => error.LayerShellCompositorMissing,
        else => error.LayerShellUnexpectedResult,
    };
}

fn mapSunglassesBufferResult(result: c.enum_wayspot_layer_result) !void {
    return switch (result) {
        c.WAYSPOT_LAYER_OK => {},
        c.WAYSPOT_LAYER_INVALID_SIZE => error.SunglassesInvalidBufferSize,
        c.WAYSPOT_LAYER_MEMFD_FAILED => error.SunglassesMemfdFailed,
        c.WAYSPOT_LAYER_TRUNCATE_FAILED => error.SunglassesTruncateFailed,
        c.WAYSPOT_LAYER_MMAP_FAILED => error.SunglassesMmapFailed,
        c.WAYSPOT_LAYER_SHM_POOL_FAILED => error.SunglassesShmPoolFailed,
        c.WAYSPOT_LAYER_WL_BUFFER_FAILED => error.SunglassesWlBufferFailed,
        c.WAYSPOT_LAYER_SHM_MISSING => error.LayerShellShmMissing,
        else => error.SunglassesBufferUnexpectedResult,
    };
}

fn drawImageIntoBuffer(buffer: *c.struct_wayspot_shm_buffer, monitor: monitor_facts.Monitor, path: [:0]const u8, image_opacity: u32, overlay_argb: u32) !void {
    if (image_opacity > 100) return error.SunglassesImageOpacityInvalid;
    const loaded = try loadAcceptedImage(path);
    defer c.SDL_DestroySurface(loaded);

    const source = c.SDL_ConvertSurface(loaded, sunglasses_pixel_format) orelse return error.SunglassesImageConvertFailed;
    defer c.SDL_DestroySurface(source);
    if (!c.SDL_SetSurfaceBlendMode(source, c.SDL_BLENDMODE_NONE)) return error.SunglassesImageConvertFailed;

    const target = c.SDL_CreateSurfaceFrom(
        @intCast(monitor.size.width),
        @intCast(monitor.size.height),
        sunglasses_pixel_format,
        buffer.data,
        @intCast(monitor.size.width * 4),
    ) orelse return error.SunglassesImageTargetFailed;
    defer c.SDL_DestroySurface(target);

    var source_rect = try coverSourceRect(source.*.w, source.*.h, @intCast(monitor.size.width), @intCast(monitor.size.height));
    if (!c.SDL_BlitSurfaceScaled(source, &source_rect, target, null, c.SDL_SCALEMODE_LINEAR)) return error.SunglassesImageScaleFailed;
    applyImageOverlay(buffer, monitor, image_opacity, overlay_argb);
}

fn loadAcceptedImage(path: [:0]const u8) !*c.SDL_Surface {
    return switch (try imageKind(path)) {
        .png => c.SDL_LoadPNG(path.ptr) orelse error.SunglassesImageLoadFailed,
        .bmp => c.SDL_LoadBMP(path.ptr) orelse error.SunglassesImageLoadFailed,
    };
}

fn imageKind(path: []const u8) !ImageKind {
    if (hasExtension(path, ".png")) return .png;
    if (hasExtension(path, ".bmp")) return .bmp;
    return error.SunglassesUnsupportedImageExtension;
}

fn hasExtension(path: []const u8, extension: []const u8) bool {
    if (path.len < extension.len) return false;
    return std.ascii.eqlIgnoreCase(path[path.len - extension.len ..], extension);
}

fn coverSourceRect(source_width: i32, source_height: i32, target_width: i32, target_height: i32) !c.SDL_Rect {
    if (source_width <= 0 or source_height <= 0 or target_width <= 0 or target_height <= 0) return error.SunglassesImageScaleFailed;
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
    if (rect.w <= 0 or rect.h <= 0) return error.SunglassesImageScaleFailed;
    return rect;
}

fn fillBuffer(buffer: *c.struct_wayspot_shm_buffer, monitor: monitor_facts.Monitor, value: u32) void {
    const pixels: [*]u32 = @ptrCast(@alignCast(buffer.data));
    const pixel_count = monitor.size.width * monitor.size.height;
    var index: u32 = 0;
    while (index < pixel_count) : (index += 1) {
        pixels[index] = value;
    }
}

fn applyImageOverlay(buffer: *c.struct_wayspot_shm_buffer, monitor: monitor_facts.Monitor, image_opacity: u32, overlay_argb: u32) void {
    const pixels: [*]u32 = @ptrCast(@alignCast(buffer.data));
    const pixel_count = monitor.size.width * monitor.size.height;
    var index: u32 = 0;
    while (index < pixel_count) : (index += 1) {
        const image = premultiplyArgb(pixels[index], image_opacity);
        pixels[index] = if (overlay_argb == 0) image else argbOver(overlay_argb, image);
    }
}

fn writeTitle(buf: *[max_title_bytes:0]u8, monitor_name: []const u8) ![:0]const u8 {
    return try std.fmt.bufPrintZ(buf, "wayspot-sunglasses:{s}", .{monitor_name});
}

test "sunglasses surface title uses env monitor name fact" {
    var title_buf: [max_title_bytes:0]u8 = undefined;
    const title = try writeTitle(&title_buf, "DP-1");
    try std.testing.expectEqualStrings("wayspot-sunglasses:DP-1", title);
}

test "sunglasses surface title rejects overlong monitor name" {
    var title_buf: [max_title_bytes:0]u8 = undefined;
    var monitor_name: [max_title_bytes]u8 = undefined;
    @memset(&monitor_name, 'm');
    try std.testing.expectError(error.NoSpaceLeft, writeTitle(&title_buf, &monitor_name));
}

test "sunglasses maps typed C layer results" {
    try mapLayerGlobalsResult(c.WAYSPOT_LAYER_OK);
    try std.testing.expectError(error.LayerShellRegistryFailed, mapLayerGlobalsResult(c.WAYSPOT_LAYER_REGISTRY_FAILED));
    try std.testing.expectError(error.LayerShellRegistryListenerFailed, mapLayerGlobalsResult(c.WAYSPOT_LAYER_REGISTRY_LISTENER_FAILED));
    try std.testing.expectError(error.LayerShellRoundtripFailed, mapLayerGlobalsResult(c.WAYSPOT_LAYER_DISPLAY_ROUNDTRIP_FAILED));
    try std.testing.expectError(error.LayerShellMissing, mapLayerGlobalsResult(c.WAYSPOT_LAYER_SHELL_MISSING));
    try std.testing.expectError(error.LayerShellCompositorMissing, mapLayerGlobalsResult(c.WAYSPOT_LAYER_COMPOSITOR_MISSING));
    try std.testing.expectError(error.LayerShellShmMissing, mapLayerGlobalsResult(c.WAYSPOT_LAYER_SHM_MISSING));
    try std.testing.expectError(error.LayerShellUnexpectedResult, mapLayerGlobalsResult(c.WAYSPOT_LAYER_MEMFD_FAILED));

    try mapLayerInputRegionResult(c.WAYSPOT_LAYER_OK);
    try std.testing.expectError(error.LayerShellInputRegionFailed, mapLayerInputRegionResult(c.WAYSPOT_LAYER_INPUT_REGION_FAILED));
    try std.testing.expectError(error.LayerShellCompositorMissing, mapLayerInputRegionResult(c.WAYSPOT_LAYER_COMPOSITOR_MISSING));
    try std.testing.expectError(error.LayerShellUnexpectedResult, mapLayerInputRegionResult(c.WAYSPOT_LAYER_MEMFD_FAILED));
}

test "sunglasses maps typed C buffer results" {
    try mapSunglassesBufferResult(c.WAYSPOT_LAYER_OK);
    try std.testing.expectError(error.SunglassesInvalidBufferSize, mapSunglassesBufferResult(c.WAYSPOT_LAYER_INVALID_SIZE));
    try std.testing.expectError(error.SunglassesMemfdFailed, mapSunglassesBufferResult(c.WAYSPOT_LAYER_MEMFD_FAILED));
    try std.testing.expectError(error.SunglassesTruncateFailed, mapSunglassesBufferResult(c.WAYSPOT_LAYER_TRUNCATE_FAILED));
    try std.testing.expectError(error.SunglassesMmapFailed, mapSunglassesBufferResult(c.WAYSPOT_LAYER_MMAP_FAILED));
    try std.testing.expectError(error.SunglassesShmPoolFailed, mapSunglassesBufferResult(c.WAYSPOT_LAYER_SHM_POOL_FAILED));
    try std.testing.expectError(error.SunglassesWlBufferFailed, mapSunglassesBufferResult(c.WAYSPOT_LAYER_WL_BUFFER_FAILED));
    try std.testing.expectError(error.LayerShellShmMissing, mapSunglassesBufferResult(c.WAYSPOT_LAYER_SHM_MISSING));
    try std.testing.expectError(error.SunglassesBufferUnexpectedResult, mapSunglassesBufferResult(c.WAYSPOT_LAYER_SHELL_MISSING));
}

test "sunglasses accepts only png and bmp image extensions" {
    try std.testing.expectEqual(ImageKind.png, try imageKind("/tmp/overlay.png"));
    try std.testing.expectEqual(ImageKind.png, try imageKind("/tmp/overlay.PNG"));
    try std.testing.expectEqual(ImageKind.bmp, try imageKind("/tmp/overlay.bmp"));
    try std.testing.expectEqual(ImageKind.bmp, try imageKind("/tmp/overlay.BMP"));
    try std.testing.expectError(error.SunglassesUnsupportedImageExtension, imageKind("/tmp/overlay.jpg"));
    try std.testing.expectError(error.SunglassesUnsupportedImageExtension, imageKind("/tmp/png"));
}

test "sunglasses missing accepted image file maps to image load error" {
    try std.testing.expectError(error.SunglassesImageLoadFailed, loadAcceptedImage("/tmp/wayspot-missing-sunglasses-slice06.png"));
}

test "sunglasses cover source rect matches previous C behavior" {
    try std.testing.expectEqual(c.SDL_Rect{ .x = 500, .y = 0, .w = 3000, .h = 3000 }, try coverSourceRect(4000, 3000, 1000, 1000));
    try std.testing.expectEqual(c.SDL_Rect{ .x = 0, .y = 375, .w = 4000, .h = 2250 }, try coverSourceRect(4000, 3000, 1600, 900));
    try std.testing.expectEqual(c.SDL_Rect{ .x = 437, .y = 0, .w = 1125, .h = 1500 }, try coverSourceRect(2000, 1500, 900, 1200));
    try std.testing.expectError(error.SunglassesImageScaleFailed, coverSourceRect(2000, 0, 900, 1200));
}

fn writeImagePath(buf: *[max_image_path_z_bytes:0]u8, image_path: []const u8) ![:0]const u8 {
    return try std.fmt.bufPrintZ(buf, "{s}", .{image_path});
}

fn useImageBuffer(monitor_state: *const sunglasses_state.MonitorState) bool {
    return monitor_state.hasEffectiveImageOverlay();
}

fn stateArgb(monitor_state: ?*const sunglasses_state.MonitorState) u32 {
    const monitor = monitor_state orelse return 0;
    const dim_alpha = if (monitor.dim_enabled)
        scaledAlpha(sunglasses_state.clampDim(monitor.dim_value), sunglasses_state.dim_max, dim_max_alpha)
    else
        0;
    if (!monitor.red_blue_enabled or monitor.red_blue_value == sunglasses_state.red_blue_zero) {
        return argb(dim_alpha, 0, 0, 0);
    }

    const tint_value = sunglasses_state.clampRedBlue(monitor.red_blue_value);
    const tint_magnitude: u32 = @intCast(if (tint_value < 0) -tint_value else tint_value);
    const tint_alpha = scaledTintAlpha(@intCast(tint_magnitude), sunglasses_state.red_blue_max, tint_max_alpha);
    if (tint_value < 0) return compositeTintAndDim(0, 36, 255, tint_alpha, dim_alpha);
    return compositeTintAndDim(255, 34, 0, tint_alpha, dim_alpha);
}

fn scaledAlpha(value: i32, max_value: i32, max_alpha: u32) u32 {
    if (value <= 0) return 0;
    const bounded: u32 = @intCast(@min(value, max_value));
    const max_bound: u32 = @intCast(max_value);
    return @min(max_alpha, (bounded * max_alpha) / max_bound);
}

fn scaledTintAlpha(value: i32, max_value: i32, max_alpha: u32) u32 {
    if (value <= 0) return 0;
    const bounded: u32 = @intCast(@min(value, max_value));
    const max_bound: u32 = @intCast(max_value);
    const curve_max = max_bound * max_bound * 4;
    const curved = (bounded * max_bound) + (bounded * bounded * 3);
    return @min(max_alpha, ((curved * max_alpha) + (curve_max / 2)) / curve_max);
}

fn argb(alpha: u32, red: u32, green: u32, blue: u32) u32 {
    return ((alpha & 0xff) << 24) |
        ((red & 0xff) << 16) |
        ((green & 0xff) << 8) |
        (blue & 0xff);
}

fn compositeTintAndDim(red: u32, green: u32, blue: u32, tint_alpha: u32, dim_alpha: u32) u32 {
    const tint_visible = tint_alpha * (255 - dim_alpha);
    const alpha = dim_alpha + (tint_visible / 255);
    if (alpha == 0) return 0;
    return argb(
        alpha,
        (red * tint_visible) / (255 * 255),
        (green * tint_visible) / (255 * 255),
        (blue * tint_visible) / (255 * 255),
    );
}

fn scaleByte(value: u32, numerator: u32, denominator: u32) u32 {
    return if (denominator == 0) 0 else (value * numerator + (denominator / 2)) / denominator;
}

fn premultiplyArgb(source: u32, image_opacity: u32) u32 {
    const source_alpha = (source >> 24) & 0xff;
    const alpha = scaleByte(source_alpha, image_opacity, 100);
    const red = scaleByte((source >> 16) & 0xff, alpha, 255);
    const green = scaleByte((source >> 8) & 0xff, alpha, 255);
    const blue = scaleByte(source & 0xff, alpha, 255);
    return argb(alpha, red, green, blue);
}

fn argbOver(source: u32, destination: u32) u32 {
    const source_alpha = (source >> 24) & 0xff;
    const inverse_alpha = 255 - source_alpha;
    const alpha = source_alpha + scaleByte((destination >> 24) & 0xff, inverse_alpha, 255);
    const red = ((source >> 16) & 0xff) + scaleByte((destination >> 16) & 0xff, inverse_alpha, 255);
    const green = ((source >> 8) & 0xff) + scaleByte((destination >> 8) & 0xff, inverse_alpha, 255);
    const blue = (source & 0xff) + scaleByte(destination & 0xff, inverse_alpha, 255);
    return argb(@min(alpha, 255), @min(red, 255), @min(green, 255), @min(blue, 255));
}

test "state argb keeps dim dominant when tint is also enabled" {
    var monitor = try sunglasses_state.MonitorState.init("DP-1");
    try std.testing.expectEqual(@as(u32, 0), stateArgb(null));

    monitor.dim_enabled = true;
    monitor.setDimValue(100);
    try std.testing.expectEqual(argb(dim_max_alpha, 0, 0, 0), stateArgb(&monitor));

    monitor.red_blue_enabled = true;
    monitor.setRedBlueValue(100);
    const combined = stateArgb(&monitor);
    try std.testing.expect(((combined >> 24) & 0xff) >= dim_max_alpha);
    try std.testing.expect(((combined >> 16) & 0xff) < 90);
}

test "red blue tint alpha starts gently and preserves maximum" {
    const old_linear_one_tick = scaledAlpha(1, sunglasses_state.red_blue_max, tint_max_alpha);
    try std.testing.expect(scaledTintAlpha(1, sunglasses_state.red_blue_max, tint_max_alpha) < old_linear_one_tick);
    try std.testing.expect(scaledTintAlpha(5, sunglasses_state.red_blue_max, tint_max_alpha) > 0);
    try std.testing.expect(scaledTintAlpha(5, sunglasses_state.red_blue_max, tint_max_alpha) < scaledAlpha(5, sunglasses_state.red_blue_max, tint_max_alpha));
    try std.testing.expect(scaledTintAlpha(10, sunglasses_state.red_blue_max, tint_max_alpha) < scaledAlpha(10, sunglasses_state.red_blue_max, tint_max_alpha));
    try std.testing.expect(scaledTintAlpha(10, sunglasses_state.red_blue_max, tint_max_alpha) > scaledTintAlpha(5, sunglasses_state.red_blue_max, tint_max_alpha));
    try std.testing.expectEqual(tint_max_alpha, scaledTintAlpha(sunglasses_state.red_blue_max, sunglasses_state.red_blue_max, tint_max_alpha));
}

test "state argb uses softened red blue tint at low values" {
    var monitor = try sunglasses_state.MonitorState.init("DP-1");
    monitor.red_blue_enabled = true;
    monitor.setRedBlueValue(1);
    try std.testing.expectEqual(@as(u32, 0), stateArgb(&monitor));

    monitor.setRedBlueValue(5);
    const low_tick = stateArgb(&monitor);
    try std.testing.expect(((low_tick >> 24) & 0xff) > 0);
    try std.testing.expect(((low_tick >> 16) & 0xff) <= ((low_tick >> 24) & 0xff));

    monitor.setRedBlueValue(100);
    try std.testing.expectEqual(compositeTintAndDim(255, 34, 0, tint_max_alpha, 0), stateArgb(&monitor));
}

test "sunglasses image opacity and overlay composition match previous C behavior" {
    try std.testing.expectEqual(argb(128, 64, 32, 16), premultiplyArgb(argb(255, 128, 64, 32), 50));
    try std.testing.expectEqual(argb(0, 0, 0, 0), premultiplyArgb(argb(255, 128, 64, 32), 0));
    try std.testing.expectEqual(argb(255, 128, 64, 32), premultiplyArgb(argb(255, 128, 64, 32), 100));
    try std.testing.expectEqual(argb(255, 130, 90, 70), argbOver(argb(128, 80, 60, 50), argb(255, 100, 60, 40)));
}

test "surface buffer decision uses image only for effective image overlay" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "overlay.png",
        .data = "",
    });
    const relative_image_path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/overlay.png", .{&tmp.sub_path});
    defer std.testing.allocator.free(relative_image_path);
    const image_path = try std.Io.Dir.cwd().realPathFileAlloc(std.Options.debug_io, relative_image_path, std.testing.allocator);
    defer std.testing.allocator.free(image_path);

    var monitor = try sunglasses_state.MonitorState.init("DP-1");
    monitor.image_enabled = true;
    monitor.setImageOpacity(40);
    try std.testing.expect(!useImageBuffer(&monitor));

    try monitor.setImagePath(image_path);
    try std.testing.expect(useImageBuffer(&monitor));

    monitor.image_enabled = false;
    try std.testing.expect(!useImageBuffer(&monitor));
}

test "image path formatting accepts maximum state path plus nul terminator" {
    var monitor = try sunglasses_state.MonitorState.init("DP-1");
    var path: [sunglasses_state.max_image_path_bytes]u8 = undefined;
    @memset(&path, 'a');
    path[0] = '/';
    try monitor.setImagePath(&path);

    var z_path: [max_image_path_z_bytes:0]u8 = undefined;
    const formatted = try writeImagePath(&z_path, monitor.imagePath());
    try std.testing.expectEqual(sunglasses_state.max_image_path_bytes, @as(u32, @intCast(formatted.len)));
    try std.testing.expectEqual(@as(u8, 0), formatted.ptr[sunglasses_state.max_image_path_bytes]);
}

test "image path formatting rejects overlong path" {
    var path: [max_image_path_z_bytes]u8 = undefined;
    @memset(&path, 'p');
    var z_path: [max_image_path_z_bytes:0]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, writeImagePath(&z_path, &path));
}

test "sunglasses attach failure destroys next empty buffer and keeps previous attachment" {
    var role = LayerShellRole{
        .native = wayland_native.WaylandIo.emptyForTest(),
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 64 },
        .attached_buffer_created = true,
    };
    var next_buffer = c.struct_wayspot_shm_buffer{ .buffer = null, .data = null, .byte_len = 12 };
    const monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", try monitor_facts.MonitorSize.init(10, 10));

    try std.testing.expectError(error.WaylandSurfaceUnavailable, role.attachCreatedBuffer(monitor, &next_buffer));
    try std.testing.expectEqual(@as(u32, 0), next_buffer.byte_len);
    try std.testing.expect(role.attached_buffer_created);
    try std.testing.expectEqual(@as(u32, 64), role.attached_buffer.byte_len);
}

test "sunglasses redraw failure keeps attached buffer state" {
    var role = LayerShellRole{
        .native = wayland_native.WaylandIo.emptyForTest(),
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 88 },
        .attached_buffer_created = true,
    };
    const monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", try monitor_facts.MonitorSize.init(10, 10));

    try std.testing.expectError(error.LayerShellShmMissing, role.drawStateSurface(monitor, null));
    try std.testing.expect(role.attached_buffer_created);
    try std.testing.expectEqual(@as(u32, 88), role.attached_buffer.byte_len);
}

test "sunglasses attached buffer cleanup is single owner transition" {
    var role = LayerShellRole{
        .native = wayland_native.WaylandIo.emptyForTest(),
        .attached_buffer = .{ .buffer = null, .data = null, .byte_len = 31 },
        .attached_buffer_created = true,
    };

    const first = role.takeAttachedBuffer() orelse return error.TestExpectedAttachedBuffer;
    try std.testing.expectEqual(@as(u32, 31), first.byte_len);
    try std.testing.expect(!role.attached_buffer_created);
    try std.testing.expectEqual(@as(?c.struct_wayspot_shm_buffer, null), role.takeAttachedBuffer());
}
