//! Main-thread SDL lifetime shared by independently owned Wayspot windows.
const std = @import("std");
const sdl = @import("sdl_c");
const wl = @import("wayland_c");
const Self = @This();

users: u8 = 0,
tray_event: ?u32 = null,

pub fn acquire(self: *Self) !void {
    if (self.users == 0) {
        // Every Wayspot window owns a custom layer-shell role. SDL's
        // Wayland startup can otherwise initialize libdecor (and its GTK
        // plugin) before a window even exists. Neither is a supported role
        // here. Apply the process-local policy on every first video lease.
        if (!sdl.SDL_SetHintWithPriority(sdl.SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR, "0", sdl.SDL_HINT_OVERRIDE)) return error.SdlLayerVideoHintFailed;
        if (!sdl.SDL_SetAppMetadata("wayspot", "0.1.0", "wayspot")) return error.SdlMetadataFailed;
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
    }
    std.debug.assert(self.users < 2);
    self.users += 1;
}

pub fn release(self: *Self) void {
    std.debug.assert(self.users > 0);
    self.users -= 1;
    if (self.users == 0) sdl.SDL_Quit();
}

/// SDL's user-event counter survives SDL_Quit. Allocate once per process,
/// not once per picker opening.
pub fn trayEvent(self: *Self) !u32 {
    std.debug.assert(self.users > 0);
    if (self.tray_event) |event| return event;
    const event = sdl.SDL_RegisterEvents(1);
    if (event == 0) return error.SdlTrayEventFailed;
    self.tray_event = event;
    return event;
}

/// Borrow only readiness. SDL retains ownership of reading and dispatching
/// its display and all event/renderer state.
pub fn fd(self: *const Self) !std.posix.fd_t {
    if (self.users == 0) return -1;
    const display: *wl.wl_display = @ptrCast(sdl.SDL_GetPointerProperty(sdl.SDL_GetGlobalProperties(), sdl.SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER, null) orelse return error.SdlWaylandDisplayMissing);
    return wl.wl_display_get_fd(display);
}
