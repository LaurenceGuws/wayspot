//! Compile-only check for every native SDL and Wayland adapter entry point.

const sdl_native = @import("sdl_native");
const wayland_native = @import("wayland_native");

/// referenceNativeEntries names every native entry point without invoking C or a DE.
fn referenceNativeEntries() void {
    const display = sdl_native.displaySource();
    const display_entries = .{
        .query_displays = display.query_displays,
        .query_name = display.query_name,
        .query_bounds = display.query_bounds,
        .query_scale = display.query_scale,
    };
    const sdl_entries = .{
        .property_create = sdl_native.SdlWindowPropertyIo.create,
        .property_set_title = sdl_native.SdlWindowPropertyIo.setTitle,
        .property_set_width = sdl_native.SdlWindowPropertyIo.setWidth,
        .property_set_height = sdl_native.SdlWindowPropertyIo.setHeight,
        .property_set_hidden = sdl_native.SdlWindowPropertyIo.setHidden,
        .property_set_role = sdl_native.SdlWindowPropertyIo.setCustomSurfaceRole,
        .property_set_egl = sdl_native.SdlWindowPropertyIo.setCreateEglWindow,
        .property_deinit = sdl_native.SdlWindowPropertyIo.deinit,
        .window_create = sdl_native.SdlWindowIo.create,
        .window_handles = sdl_native.SdlWindowIo.nativeWaylandHandles,
        .window_resize = sdl_native.SdlWindowIo.resize,
        .window_deinit = sdl_native.SdlWindowIo.deinit,
    };
    const wayland_entries = .{
        .init = wayland_native.WaylandIo.init,
        .globals = wayland_native.WaylandIo.globalsPtr,
        .surface = wayland_native.WaylandIo.surfacePtr,
        .display = wayland_native.WaylandIo.displayPtr,
        .deinit = wayland_native.WaylandIo.deinit,
    };

    _ = display_entries.query_displays;
    _ = display_entries.query_name;
    _ = display_entries.query_bounds;
    _ = display_entries.query_scale;
    _ = sdl_entries.property_create;
    _ = sdl_entries.property_set_title;
    _ = sdl_entries.property_set_width;
    _ = sdl_entries.property_set_height;
    _ = sdl_entries.property_set_hidden;
    _ = sdl_entries.property_set_role;
    _ = sdl_entries.property_set_egl;
    _ = sdl_entries.property_deinit;
    _ = sdl_entries.window_create;
    _ = sdl_entries.window_handles;
    _ = sdl_entries.window_resize;
    _ = sdl_entries.window_deinit;
    _ = wayland_entries.init;
    _ = wayland_entries.globals;
    _ = wayland_entries.surface;
    _ = wayland_entries.display;
    _ = wayland_entries.deinit;
}

/// main runs only the compile/link reference table; it starts no native resource.
pub fn main() void {
    referenceNativeEntries();
}
