//! Sunglasses surface owns one pass-through overlay layer and state tint buffer.

const std = @import("std");
const hyprland = @import("../wallpaper/hyprland.zig");
const sunglasses_state = @import("../sunglasses/state.zig");

const c = @import("sdl_c");

pub const class_name = "wayspot-sunglasses";
const max_title_bytes: u32 = 160;
const layer_namespace = "wayspot-sunglasses";
const anchor_all_edges: u32 = 1 | 2 | 4 | 8;
const layer_overlay: u32 = 3;
const tint_max_alpha: u32 = 120;
const dim_max_alpha: u32 = 220;
const max_image_path_z_bytes: u32 = sunglasses_state.max_image_path_bytes + 1;

pub const SunglassesSurface = struct {
    window: *c.SDL_Window,
    layer: LayerShellRole,
    monitor: hyprland.Monitor,

    /// The surface owns compositor resources but not monitor discovery or picker lifecycle.
    pub fn init(monitor: hyprland.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !SunglassesSurface {
        var title_buf: [max_title_bytes:0]u8 = undefined;
        const window_title = try writeTitle(&title_buf, monitor.name());

        const props = c.SDL_CreateProperties();
        if (props == 0) return error.SdlWindowFailed;
        defer c.SDL_DestroyProperties(props);

        if (!c.SDL_SetStringProperty(props, c.SDL_PROP_WINDOW_CREATE_TITLE_STRING, window_title.ptr)) return error.SdlWindowFailed;
        if (!c.SDL_SetNumberProperty(props, c.SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, monitor.width)) return error.SdlWindowFailed;
        if (!c.SDL_SetNumberProperty(props, c.SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, monitor.height)) return error.SdlWindowFailed;
        if (!c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, true)) return error.SdlWindowFailed;
        if (!c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN, true)) return error.SdlWindowFailed;
        if (!c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_WAYLAND_CREATE_EGL_WINDOW_BOOLEAN, true)) return error.SdlWindowFailed;

        const window = c.SDL_CreateWindowWithProperties(props) orelse return error.SdlWindowFailed;
        errdefer c.SDL_DestroyWindow(window);

        var layer = try LayerShellRole.init(window, monitor);
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
        c.SDL_DestroyWindow(self.window);
        self.layer.flushDisplay();
    }

    pub fn redraw(self: *SunglassesSurface, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        try self.layer.drawStateSurface(self.monitor, monitor_state);
    }
};

const LayerShellRole = struct {
    globals: c.struct_wayspot_layer_globals = undefined,
    layer_surface: ?*c.struct_zwlr_layer_surface_v1 = null,
    wl_surface: ?*c.struct_wl_surface = null,
    display: ?*c.struct_wl_display = null,
    attached_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 },
    attached_buffer_created: bool = false,

    fn init(window: *c.SDL_Window, monitor: hyprland.Monitor) !LayerShellRole {
        const props = c.SDL_GetWindowProperties(window);
        if (props == 0) return error.SdlWindowFailed;

        const display_ptr = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null) orelse return error.WaylandSurfaceUnavailable;
        const surface_ptr = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null) orelse return error.WaylandSurfaceUnavailable;
        const display: *c.struct_wl_display = @ptrCast(@alignCast(display_ptr));
        const wl_surface: *c.struct_wl_surface = @ptrCast(@alignCast(surface_ptr));

        var role = LayerShellRole{};
        role.display = display;
        role.wl_surface = wl_surface;
        if (c.wayspot_layer_globals_init(&role.globals, display) != 0) return error.LayerShellUnavailable;
        errdefer c.wayspot_layer_globals_deinit(&role.globals);

        var monitor_name_buf: [hyprland.max_monitor_name_bytes:0]u8 = undefined;
        const monitor_name = try std.fmt.bufPrintZ(&monitor_name_buf, "{s}", .{monitor.name()});
        const output = c.wayspot_layer_find_output(&role.globals, monitor_name.ptr) orelse return error.LayerShellOutputUnavailable;
        const layer_surface = c.wayspot_layer_get_surface_on_layer(&role.globals, wl_surface, output, layer_overlay, layer_namespace) orelse return error.LayerShellSurfaceFailed;
        role.layer_surface = layer_surface;
        errdefer role.destroyLayerSurface();

        var configure_state = c.struct_wayspot_layer_configure_state{
            .configured = 0,
            .closed = 0,
            .serial = 0,
            .width = 0,
            .height = 0,
        };
        c.wayspot_layer_surface_add_listener(layer_surface, &configure_state);
        c.wayspot_layer_surface_set_size(layer_surface, @intCast(monitor.width), @intCast(monitor.height));
        c.wayspot_layer_surface_set_anchor(layer_surface, anchor_all_edges);
        c.wayspot_layer_surface_set_exclusive_zone(layer_surface, -1);
        c.wayspot_layer_surface_set_keyboard_interactivity(layer_surface, 0);
        if (c.wayspot_wl_surface_set_empty_input_region(&role.globals, wl_surface) != 0) return error.LayerShellInputRegionFailed;
        c.wayspot_wl_surface_commit(wl_surface);

        while (configure_state.configured == 0) {
            if (configure_state.closed != 0) return error.LayerShellClosed;
            if (c.wayspot_wl_display_roundtrip(display) < 0) return error.LayerShellConfigureFailed;
        }

        c.wayspot_layer_surface_ack_configure(layer_surface, configure_state.serial);
        if (!c.SDL_SetWindowSize(window, monitor.width, monitor.height)) return error.SdlWindowSizeFailed;
        c.wayspot_wl_surface_commit(wl_surface);
        if (c.wayspot_wl_display_roundtrip(display) < 0) return error.LayerShellConfigureFailed;
        return role;
    }

    fn drawStateSurface(self: *LayerShellRole, monitor: hyprland.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        if (monitor_state) |state| {
            if (useImageBuffer(state)) {
                try self.drawStateImage(monitor, state);
                return;
            }
        }
        try self.drawStateTint(monitor, monitor_state);
    }

    fn drawStateImage(self: *LayerShellRole, monitor: hyprland.Monitor, monitor_state: *const sunglasses_state.MonitorState) !void {
        var path_buf: [max_image_path_z_bytes:0]u8 = undefined;
        const image_path = try writeImagePath(&path_buf, monitor_state.imagePath());
        var next_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        const created = c.wayspot_shm_buffer_create_sunglasses_image(
            &self.globals,
            &next_buffer,
            @intCast(monitor.width),
            @intCast(monitor.height),
            image_path.ptr,
            @intCast(sunglasses_state.clampImageOpacity(monitor_state.image_opacity)),
            stateArgb(monitor_state),
        );
        if (created != 0) return error.SunglassesImageBufferFailed;
        try self.attachCreatedBuffer(monitor, &next_buffer);
    }

    fn drawStateTint(self: *LayerShellRole, monitor: hyprland.Monitor, monitor_state: ?*const sunglasses_state.MonitorState) !void {
        var next_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        const created = c.wayspot_shm_buffer_create_tint(
            &self.globals,
            &next_buffer,
            @intCast(monitor.width),
            @intCast(monitor.height),
            stateArgb(monitor_state),
        );
        if (created != 0) return error.SunglassesTintBufferFailed;
        try self.attachCreatedBuffer(monitor, &next_buffer);
    }

    fn attachCreatedBuffer(self: *LayerShellRole, monitor: hyprland.Monitor, next_buffer: *c.struct_wayspot_shm_buffer) !void {
        const wl_surface = self.wl_surface orelse {
            c.wayspot_shm_buffer_destroy(next_buffer);
            return error.WaylandSurfaceUnavailable;
        };
        var old_buffer = self.attached_buffer;
        const had_old_buffer = self.attached_buffer_created;
        self.attached_buffer = next_buffer.*;
        next_buffer.* = .{ .buffer = null, .data = null, .byte_len = 0 };
        self.attached_buffer_created = true;
        c.wayspot_wl_surface_attach_buffer(wl_surface, &self.attached_buffer, @intCast(monitor.width), @intCast(monitor.height));
        c.wayspot_wl_surface_commit(wl_surface);
        if (self.display) |display| {
            c.wayspot_wl_display_roundtrip_cleanup(display);
        }
        if (had_old_buffer) {
            c.wayspot_shm_buffer_destroy(&old_buffer);
        }
    }

    fn deinit(self: *LayerShellRole) void {
        if (self.wl_surface) |wl_surface| {
            c.wayspot_wl_surface_detach_buffer(wl_surface);
            c.wayspot_wl_surface_commit(wl_surface);
            if (self.display) |display| {
                c.wayspot_wl_display_roundtrip_cleanup(display);
            }
        }
        if (self.attached_buffer_created) {
            c.wayspot_shm_buffer_destroy(&self.attached_buffer);
            self.attached_buffer_created = false;
        }
        self.destroyLayerSurface();
        if (self.display) |display| {
            c.wayspot_wl_display_roundtrip_cleanup(display);
        }
        c.wayspot_layer_globals_deinit(&self.globals);
    }

    fn destroyLayerSurface(self: *LayerShellRole) void {
        if (self.layer_surface) |layer_surface| {
            c.wayspot_layer_surface_destroy(layer_surface);
            self.layer_surface = null;
        }
    }

    fn flushDisplay(self: *LayerShellRole) void {
        if (self.display) |display| {
            c.wayspot_wl_display_roundtrip_cleanup(display);
        }
    }
};

fn writeTitle(buf: *[max_title_bytes:0]u8, monitor_name: []const u8) ![:0]const u8 {
    return try std.fmt.bufPrintZ(buf, "wayspot-sunglasses:{s}", .{monitor_name});
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

test "surface buffer decision uses image only for effective image overlay" {
    var monitor = try sunglasses_state.MonitorState.init("DP-1");
    monitor.image_enabled = true;
    monitor.setImageOpacity(40);
    try std.testing.expect(!useImageBuffer(&monitor));

    try monitor.setImagePath("/tmp/wayspot-overlay.png");
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
