//! Main-thread SDL lifetime shared by independently owned Wayspot windows.
const std = @import("std");
const sdl = @import("sdl_c");
const wl = @import("wayland_c");
const Self = @This();
const egl_vendor_manifest = @import("build_options").egl_vendor_manifest;

pub const native_ui = @import("build_options").native_picker;
const shm = if (native_ui) @import("native_surface.zig") else struct {};

users: u8 = 0,
tray_event: ?u32 = null,

// One visible-session owner. Standalone and resident roles borrow the same
// API; the resident retains no native connection while both roles are cold.
env: ?*const std.process.Environ.Map = null,
native: if (native_ui) ?*shm.Display else void = if (native_ui) null else {},
native_users: u8 = 0,

pub fn acquireNative(self: *Self, allocator: std.mem.Allocator, io: std.Io) !*shm.Display {
    if (self.native) |display| {
        if (display.failed) return error.NativeConnectionFailed;
        std.debug.assert(self.native_users < 2);
        self.native_users += 1;
        return display;
    }
    std.debug.assert(self.native_users == 0 and self.users == 0);
    const env = self.env orelse return error.NativeDisplayEnvironment;
    const display = try shm.Display.open(allocator, io, env);
    errdefer display.destroy();
    const start = std.Io.Clock.awake.now(io);
    while (display.status() == .discovering) try readBefore(display, io, start);
    if (display.status() != .ready) return error.NativeDisplayNotReady;
    self.native = display;
    self.native_users = 1;
    std.log.info("native UI connection opened", .{});
    return display;
}

pub fn releaseNative(self: *Self) void {
    std.debug.assert(self.native_users > 0 and self.users == 0);
    self.native_users -= 1;
    if (self.native_users != 0) return;
    self.native.?.destroy();
    self.native = null;
    // All software renderers are now gone. Never run global SDL cleanup
    // while a sibling role still owns CPU drawing resources.
    sdl.SDL_Quit();
    std.log.info("native UI connection retired", .{});
}

pub fn readBefore(display: *shm.Display, io: std.Io, start: std.Io.Timestamp) !void {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
    if (elapsed >= 2000) return error.NativeUiDeadline;
    var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, @intCast(2000 - elapsed)) == 0) return error.NativeUiDeadline;
    try display.readReady();
}

pub fn nativeFd(self: *const Self) std.posix.fd_t {
    if (native_ui) return if (self.native) |display| display.fd() else -1;
    return -1;
}

pub fn pumpNative(self: *Self) !void {
    if (!native_ui) return;
    const display = self.native orelse return;
    if (display.failed) return error.NativeConnectionFailed;
    var fds = [_]std.posix.pollfd{.{ .fd = display.fd(), .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, 0) != 0) try display.readReady();
}

/// Called once at the graphical process entrypoint, before SDL or service
/// workers start. GLVND reads libc's environment, not SDL's private hint map.
/// The original std.process.Init.environ_map remains the sole environment
/// passed to external commands and application launches.
pub fn prepareProcess(io: std.Io) !void {
    if (native_ui) return;
    if (egl_vendor_manifest) |manifest| {
        const stat = std.Io.Dir.cwd().statFile(io, manifest, .{}) catch return error.EglVendorManifestUnavailable;
        if (stat.kind != .file) return error.EglVendorManifestUnavailable;
        std.Io.Dir.accessAbsolute(io, manifest, .{ .read = true }) catch return error.EglVendorManifestUnavailable;
        if (sdl.SDL_setenv_unsafe("__EGL_VENDOR_LIBRARY_FILENAMES", manifest, 1) != 0) return error.EglVendorSelectionFailed;
        std.log.info("EGL vendor manifest: {s}", .{manifest});
    }
}

pub fn acquire(self: *Self) !void {
    if (native_ui) return error.NativeUiHasNoVideoLease;
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
