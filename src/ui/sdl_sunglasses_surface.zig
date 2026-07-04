//! SDL sunglasses surface owns one pass-through overlay layer and tint buffer.

const std = @import("std");
const hyprland = @import("../wallpaper/hyprland.zig");

const c = @import("sdl_c");

pub const class_name = "wayspot-sunglasses";
const max_title_bytes: u32 = 160;
const layer_namespace = "wayspot-sunglasses";
const anchor_all_edges: u32 = 1 | 2 | 4 | 8;
const layer_overlay: u32 = 3;
const proof_argb_tint: u32 = 0x66660000;

pub const SunglassesSurface = struct {
    window: *c.SDL_Window,
    layer: LayerShellRole,
    monitor: hyprland.Monitor,

    /// The surface owns compositor resources but not monitor discovery or process lifetime.
    pub fn init(monitor: hyprland.Monitor) !SunglassesSurface {
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

        try layer.drawProofTint(monitor);

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

    fn drawProofTint(self: *LayerShellRole, monitor: hyprland.Monitor) !void {
        var next_buffer: c.struct_wayspot_shm_buffer = .{ .buffer = null, .data = null, .byte_len = 0 };
        const created = c.wayspot_shm_buffer_create_tint(
            &self.globals,
            &next_buffer,
            @intCast(monitor.width),
            @intCast(monitor.height),
            proof_argb_tint,
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
