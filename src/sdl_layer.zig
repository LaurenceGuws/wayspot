//! One native layer-shell role for an SDL-owned Wayland surface.
//! SDL retains wl_display/wl_surface, all input, scaling and buffer rendering.
//! Wayspot owns only registry/role proxies and their exact callback lifetime.
const std = @import("std");
const sdl = @import("sdl_c");
const wl = @import("wayland_c");
const Self = @This();

pub const Role = enum { picker, notification };

const Placement = struct {
    layer: u32,
    anchors: u32,
    keyboard: u32,
    margin: i32,
    exclusive_zone: i32,
    namespace: [*:0]const u8,
};

fn placement(role: Role) Placement {
    return switch (role) {
        .picker => .{
            .layer = wl.WAYSPOT_LAYER_OVERLAY,
            .anchors = 0, // no anchors: center within compositor-selected output
            .keyboard = wl.WAYSPOT_KEYBOARD_EXCLUSIVE,
            .margin = 0,
            .exclusive_zone = -1,
            .namespace = "wayspot-picker",
        },
        .notification => .{
            .layer = wl.WAYSPOT_LAYER_TOP,
            .anchors = wl.WAYSPOT_ANCHOR_TOP | wl.WAYSPOT_ANCHOR_RIGHT,
            .keyboard = wl.WAYSPOT_KEYBOARD_NONE,
            .margin = 16,
            .exclusive_zone = -1,
            .namespace = "wayspot-notification",
        },
    };
}

/// Create an SDL window with no XDG/libdecor role. The caller still owns it.
/// This uses SDL's documented custom-role path, not backend-private structs.
pub fn createWindow(title: [*:0]const u8, width: c_int, height: c_int) !*sdl.SDL_Window {
    if (!std.mem.eql(u8, std.mem.span(sdl.SDL_GetCurrentVideoDriver()), "wayland"))
        return error.WaylandRequired;
    const props = sdl.SDL_CreateProperties();
    if (props == 0) return error.SdlPropertiesUnavailable;
    defer sdl.SDL_DestroyProperties(props);
    if (!sdl.SDL_SetBooleanProperty(props, sdl.SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN, true) or
        !sdl.SDL_SetBooleanProperty(props, sdl.SDL_PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN, true) or
        !sdl.SDL_SetNumberProperty(props, sdl.SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, width) or
        !sdl.SDL_SetNumberProperty(props, sdl.SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, height) or
        !sdl.SDL_SetStringProperty(props, sdl.SDL_PROP_WINDOW_CREATE_TITLE_STRING, title))
        return error.SdlWindowProperties;
    return sdl.SDL_CreateWindowWithProperties(props) orelse error.SdlCreateFailed;
}

display: ?*wl.wl_display = null, // borrowed from SDL
surface: ?*wl.wl_surface = null, // borrowed from SDL
registry: ?*wl.wl_registry = null,
manager: ?*wl.zwlr_layer_shell_v1 = null,
layer: ?*wl.zwlr_layer_surface_v1 = null,
configured: bool = false,
closed: bool = false,
width: u32 = 0,
height: u32 = 0,

/// Complete role creation and the initial *empty* commit before any SDL frame.
/// No fallback to a toplevel: missing layer-shell is an explicit failure.
pub fn init(self: *Self, window: *sdl.SDL_Window, role: Role, logical_width: u32, logical_height: u32) !void {
    std.debug.assert(self.display == null and self.layer == null);
    if (!std.mem.eql(u8, std.mem.span(sdl.SDL_GetCurrentVideoDriver()), "wayland"))
        return error.WaylandRequired;
    const props = sdl.SDL_GetWindowProperties(window);
    self.display = @ptrCast(sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null) orelse return error.SdlWaylandDisplayMissing);
    self.surface = @ptrCast(sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null) orelse return error.SdlWaylandSurfaceMissing);
    errdefer self.deinit();
    self.registry = wl.wl_display_get_registry(self.display.?) orelse return error.LayerRegistry;
    if (wl.wl_registry_add_listener(self.registry.?, &registry_listener, self) != 0)
        return error.LayerRegistryListener;
    if (wl.wl_display_roundtrip(self.display.?) < 0) return error.LayerRegistryRoundtrip;
    const manager = self.manager orelse return error.LayerShellUnavailable;
    // Registry is no longer needed. SDL's wl_display and wl_surface survive.
    wl.wl_registry_destroy(self.registry.?);
    self.registry = null;
    const layout = placement(role);
    self.layer = wl.wayspot_layer_shell_get_surface(manager, self.surface.?, null, layout.layer, layout.namespace) orelse
        return error.LayerSurfaceUnavailable;
    if (wl.wayspot_layer_surface_add_listener(self.layer.?, &layer_listener, self) != 0)
        return error.LayerListenerUnavailable;
    wl.wayspot_layer_surface_set_size(self.layer.?, logical_width, logical_height);
    wl.wayspot_layer_surface_set_anchor(self.layer.?, layout.anchors);
    wl.wayspot_layer_surface_set_exclusive_zone(self.layer.?, layout.exclusive_zone);
    wl.wayspot_layer_surface_set_keyboard(self.layer.?, layout.keyboard);
    if (layout.margin != 0) wl.wayspot_layer_surface_set_margin(self.layer.?, layout.margin, layout.margin, 0, 0);
    wl.wl_surface_commit(self.surface.?);
    // Sync follows the initial empty commit: the compositor must configure
    // the layer before SDL may attach its first buffer.
    if (wl.wl_display_roundtrip(self.display.?) < 0) return error.LayerConfigureRoundtrip;
    if (!self.configured or self.closed) return error.LayerNotConfigured;
    try self.update(window);
}

pub fn update(self: *Self, window: *sdl.SDL_Window) !void {
    if (self.closed) return error.LayerClosed;
    if (self.width == 0 or self.height == 0) return error.LayerInvalidGeometry;
    var width: c_int = 0;
    var height: c_int = 0;
    if (!sdl.SDL_GetWindowSize(window, &width, &height)) return error.SdlWindowSize;
    if (width != self.width or height != self.height) {
        if (!sdl.SDL_SetWindowSize(window, @intCast(self.width), @intCast(self.height)))
            return error.SdlWindowResize;
    }
}

/// Retire Wayland role objects before SDL destroys the borrowed surface.
pub fn deinit(self: *Self) void {
    if (self.layer) |proxy| wl.wayspot_layer_surface_destroy(proxy);
    if (self.registry) |proxy| wl.wl_registry_destroy(proxy);
    if (self.manager) |proxy| wl.wayspot_layer_shell_destroy(proxy);
    self.* = .{};
}

const registry_listener = wl.wl_registry_listener{
    .global = onGlobal,
    .global_remove = onGlobalRemove,
};
fn onGlobal(data: ?*anyopaque, registry: ?*wl.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(data));
    if (self.manager != null or version < 1 or !std.mem.eql(u8, std.mem.span(interface), "zwlr_layer_shell_v1")) return;
    // Version 3 permits explicit manager destruction; older versions use
    // the wrapper's local-only proxy cleanup.
    self.manager = @ptrCast(wl.wl_registry_bind(registry, name, wl.wayspot_layer_shell_interface(), @min(version, 3)) orelse return);
}
fn onGlobalRemove(_: ?*anyopaque, _: ?*wl.wl_registry, _: u32) callconv(.c) void {}

const layer_listener = wl.wayspot_layer_listener{ .configure = onConfigure, .closed = onClosed };
fn onConfigure(data: ?*anyopaque, layer: ?*wl.zwlr_layer_surface_v1, serial: u32, width: u32, height: u32) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(data));
    if (width == 0 or height == 0 or width > std.math.maxInt(c_int) or height > std.math.maxInt(c_int)) {
        self.closed = true;
        return;
    }
    wl.wayspot_layer_surface_ack_configure(layer.?, serial);
    self.width = width;
    self.height = height;
    self.configured = true;
}
fn onClosed(data: ?*anyopaque, _: ?*wl.zwlr_layer_surface_v1) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(data));
    self.closed = true;
}

test "picker and notification layer placement never reserve tile space" {
    const picker = placement(.picker);
    const notification = placement(.notification);
    try std.testing.expectEqual(@as(u32, wl.WAYSPOT_LAYER_OVERLAY), picker.layer);
    try std.testing.expectEqual(@as(u32, 0), picker.anchors);
    try std.testing.expectEqual(@as(u32, wl.WAYSPOT_KEYBOARD_EXCLUSIVE), picker.keyboard);
    try std.testing.expectEqual(@as(i32, -1), picker.exclusive_zone);
    try std.testing.expectEqual(@as(u32, wl.WAYSPOT_LAYER_TOP), notification.layer);
    try std.testing.expectEqual(@as(u32, wl.WAYSPOT_ANCHOR_TOP | wl.WAYSPOT_ANCHOR_RIGHT), notification.anchors);
    try std.testing.expectEqual(@as(u32, wl.WAYSPOT_KEYBOARD_NONE), notification.keyboard);
    try std.testing.expectEqual(@as(i32, -1), notification.exclusive_zone);
    try std.testing.expect(notification.margin > 0);
}
