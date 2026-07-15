//! Native Wayland layer calls behind the plain wayland_io contract.

const std = @import("std");
const c = @import("sdl_c");
const sdl_io = @import("sdl_io");
const sdl_native = @import("sdl_native");
const sunglasses_setup = @import("sunglasses_setup");
const wayland_io = @import("wayland_io");

/// WaylandIo owns native layer setup and borrowed SDL-provided Wayland handles.
pub const WaylandIo = struct {
    /// handles are borrowed from SDL and are never disconnected here.
    handles: sdl_native.NativeWaylandHandles,
    /// globals owns the native layer globals until deinit.
    globals: c.struct_wayspot_layer_globals = undefined,
    /// layer_surface is the one owned native layer object.
    layer_surface: ?*c.struct_zwlr_layer_surface_v1 = null,
    /// configure remains alive for the native listener callback.
    configure: c.struct_wayspot_layer_configure_state = .{
        .configured = 0,
        .closed = 0,
        .serial = 0,
        .width = 0,
        .height = 0,
    },
    /// globals_ready gates native cleanup and deferred C access.
    globals_ready: bool = false,

    /// init creates one layer surface and waits for its first configure.
    pub fn init(
        window: *sdl_native.SdlWindowIo,
        plan: sunglasses_setup.SetupPlan,
    ) wayland_io.WaylandError!WaylandIo {
        const name = plan.monitor_name;
        var name_buf: [sdl_io.max_display_name_bytes:0]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name.slice()}) catch
            return error.LayerShellOutputMissing;
        var result = WaylandIo{ .handles = undefined };
        var output: ?*c.struct_wl_output = null;
        errdefer result.deinit();

        for (sunglasses_setup.layer_commands) |command| switch (command) {
            .resolve_wayland_handles => result.handles = window.nativeWaylandHandles() catch |err| switch (err) {
                error.SdlWindowPropertyMissing,
                error.WaylandSurfaceUnavailable,
                => return error.WaylandSurfaceUnavailable,
                else => return error.WaylandSurfaceUnavailable,
            },
            .globals_init => {
                const globals_result = c.wayspot_layer_globals_init(&result.globals, result.handles.display);
                if (globals_result != c.WAYSPOT_LAYER_OK) {
                    c.wayspot_layer_globals_deinit(&result.globals);
                    mapLayerResult(globals_result) catch |err| return err;
                    unreachable;
                }
                result.globals_ready = true;
            },
            .find_output => output = c.wayspot_layer_find_output(&result.globals, name_z.ptr) orelse
                return error.LayerShellOutputMissing,
            .create_layer_surface => result.layer_surface = c.wayspot_layer_get_surface_on_layer(
                &result.globals,
                result.handles.surface,
                output orelse return error.LayerShellOutputMissing,
                plan.layer.raw(),
                namespaceText(plan.namespace),
            ) orelse return error.LayerShellSurfaceCreateFailed,
            .add_listener => c.wayspot_layer_surface_add_listener(result.layer_surface.?, &result.configure),
            .set_size => c.wayspot_layer_surface_set_size(
                result.layer_surface.?,
                @intCast(plan.size.width),
                @intCast(plan.size.height),
            ),
            .set_anchor => c.wayspot_layer_surface_set_anchor(result.layer_surface.?, 1 | 2 | 4 | 8),
            .set_exclusive_zone => c.wayspot_layer_surface_set_exclusive_zone(result.layer_surface.?, -1),
            .set_keyboard_interactivity => c.wayspot_layer_surface_set_keyboard_interactivity(
                result.layer_surface.?,
                0,
            ),
            .set_empty_input_region => mapLayerResult(
                c.wayspot_wl_surface_set_empty_input_region(&result.globals, result.handles.surface),
            ) catch |err| return err,
            .first_commit => c.wayspot_wl_surface_commit(result.handles.surface),
            .first_roundtrip => {
                while (result.configure.configured == 0) {
                    if (result.configure.closed != 0) return error.LayerShellClosed;
                    if (c.wayspot_wl_display_roundtrip(result.handles.display) < 0) {
                        return error.LayerShellConfigureFailed;
                    }
                }
                try validateNativeConfigure(result.configure);
            },
            .ack_configure => c.wayspot_layer_surface_ack_configure(
                result.layer_surface.?,
                result.configure.serial,
            ),
            .resize_window => window.resize(plan.size) catch |err| switch (err) {
                error.SdlWindowSizeFailed => return error.SdlWindowSizeFailed,
                else => return error.SdlWindowSizeFailed,
            },
            .second_commit => {
                clearNativeConfigure(&result.configure);
                c.wayspot_wl_surface_commit(result.handles.surface);
            },
            .second_roundtrip => {
                if (c.wayspot_wl_display_roundtrip(result.handles.display) < 0) {
                    return error.LayerShellConfigureFailed;
                }
                try validateNativeConfigure(result.configure);
            },
        };
        return result;
    }

    /// emptyForTest creates an uninitialized native owner for deferred tests.
    pub fn emptyForTest() WaylandIo {
        return .{
            .handles = undefined,
            .globals = std.mem.zeroes(c.struct_wayspot_layer_globals),
        };
    }

    /// globalsPtr exposes borrowed globals only to the deferred buffer code.
    pub fn globalsPtr(self: *WaylandIo) ?*c.struct_wayspot_layer_globals {
        if (!self.globals_ready) return null;
        return &self.globals;
    }

    /// surfacePtr exposes the borrowed SDL surface only to deferred C code.
    pub fn surfacePtr(self: *const WaylandIo) ?*c.struct_wl_surface {
        if (!self.globals_ready) return null;
        return self.handles.surface;
    }

    /// displayPtr exposes the borrowed SDL display only to deferred C code.
    pub fn displayPtr(self: *const WaylandIo) ?*c.struct_wl_display {
        if (!self.globals_ready) return null;
        return self.handles.display;
    }

    /// deinit destroys the published layer, flushes only that layer, and deinitializes globals.
    /// A globals-only failure has no layer flush because no layer was published.
    pub fn deinit(self: *WaylandIo) void {
        if (!self.globals_ready) return;
        if (self.layer_surface) |layer_surface| {
            c.wayspot_layer_surface_destroy(layer_surface);
            self.layer_surface = null;
            c.wayspot_wl_display_roundtrip_cleanup(self.handles.display);
        }
        c.wayspot_layer_globals_deinit(&self.globals);
        self.globals_ready = false;
    }
};

fn namespaceText(namespace: wayland_io.LayerNamespace) [*:0]const u8 {
    return switch (namespace) {
        .sunglasses => "wayspot-sunglasses",
    };
}

fn mapLayerResult(result: c.enum_wayspot_layer_result) wayland_io.WaylandError!void {
    return switch (result) {
        c.WAYSPOT_LAYER_OK => {},
        c.WAYSPOT_LAYER_REGISTRY_FAILED => error.LayerShellRegistryFailed,
        c.WAYSPOT_LAYER_REGISTRY_LISTENER_FAILED => error.LayerShellRegistryListenerFailed,
        c.WAYSPOT_LAYER_DISPLAY_ROUNDTRIP_FAILED => error.LayerShellRoundtripFailed,
        c.WAYSPOT_LAYER_SHELL_MISSING => error.LayerShellMissing,
        c.WAYSPOT_LAYER_COMPOSITOR_MISSING => error.LayerShellCompositorMissing,
        c.WAYSPOT_LAYER_SHM_MISSING => error.LayerShellShmMissing,
        c.WAYSPOT_LAYER_INPUT_REGION_FAILED => error.LayerShellInputRegionFailed,
        else => error.LayerShellUnexpectedResult,
    };
}

fn clearNativeConfigure(configure: *c.struct_wayspot_layer_configure_state) void {
    configure.* = .{
        .configured = 0,
        .closed = 0,
        .serial = 0,
        .width = 0,
        .height = 0,
    };
}

fn validateNativeConfigure(
    configure: c.struct_wayspot_layer_configure_state,
) wayland_io.WaylandError!void {
    const facts = wayland_io.ConfigureFacts{
        .configured = configure.configured != 0,
        .closed = configure.closed != 0,
        .serial = configure.serial,
        .width = configure.width,
        .height = configure.height,
    };
    try wayland_io.validateConfigureFacts(facts);
    if (facts.closed) return error.LayerShellClosed;
}

test "native configure validation uses the plain bounds" {
    var configure = c.struct_wayspot_layer_configure_state{
        .configured = 1,
        .closed = 0,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    };
    try validateNativeConfigure(configure);
    configure.serial = 0;
    try std.testing.expectError(error.InvalidConfigureFacts, validateNativeConfigure(configure));
    configure = .{
        .configured = 0,
        .closed = 1,
        .serial = 0,
        .width = 0,
        .height = 0,
    };
    try std.testing.expectError(error.LayerShellClosed, validateNativeConfigure(configure));
}
