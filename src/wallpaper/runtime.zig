//! Wallpaper runtime owns monitor surface slots, the proof deadline, and shutdown order.

const std = @import("std");
const hyprland = @import("hyprland.zig");
const sdl_wallpaper_surface = @import("../ui/sdl_wallpaper_surface.zig");

const c = @import("sdl_c");

const proof_runtime_ms: u64 = 10_000;

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    slots: [hyprland.max_monitors]SurfaceSlot = undefined,
    slot_count: u32 = 0,
    sdl_started: bool = false,

    /// Each surface slot is created once for one monitor generation and destroyed by Runtime.deinit.
    pub fn runLifecycleProof(allocator: std.mem.Allocator, hypr: hyprland.Connection) !void {
        var runtime = Runtime{ .allocator = allocator };
        defer runtime.deinit();
        try runtime.startProof(hypr);
    }

    fn startProof(self: *Runtime, hypr: hyprland.Connection) !void {
        const monitors = try hyprland.queryMonitors(self.allocator, hypr);
        if (monitors.count == 0) return error.NoHyprlandMonitors;

        const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, sdl_wallpaper_surface.class_name);
        if (!hint_set) return error.SdlHintFailed;
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        self.sdl_started = true;

        var index: u32 = 0;
        while (index < monitors.count) : (index += 1) {
            const monitor = monitors.items[index];
            const surface = try sdl_wallpaper_surface.WallpaperSurface.init(monitor, 1);
            self.slots[self.slot_count] = SurfaceSlot{
                .surface = surface,
                .state = .created,
            };
            self.slot_count += 1;
        }

        try waitUntilDeadline(proof_runtime_ms);
    }

    pub fn deinit(self: *Runtime) void {
        var index = self.slot_count;
        while (index > 0) {
            index -= 1;
            self.slots[index].deinit();
        }
        self.slot_count = 0;
        if (self.sdl_started) {
            c.SDL_Quit();
            self.sdl_started = false;
        }
    }
};

pub const SurfaceSlot = struct {
    surface: sdl_wallpaper_surface.WallpaperSurface,
    state: enum { empty, created } = .empty,

    fn deinit(self: *SurfaceSlot) void {
        if (self.state == .created) {
            self.surface.deinit();
            self.state = .empty;
        }
    }
};

fn waitUntilDeadline(duration_ms: u64) !void {
    const deadline = c.SDL_GetTicks() + duration_ms;
    while (true) {
        const now = c.SDL_GetTicks();
        if (now >= deadline) return;
        const remaining = deadline - now;
        const timeout: i32 = @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
        var event: c.SDL_Event = undefined;
        if (c.SDL_WaitEventTimeout(&event, timeout)) {
            if (event.type == c.SDL_EVENT_QUIT or
                event.type == c.SDL_EVENT_TERMINATING or
                event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED)
            {
                return;
            }
            while (c.SDL_PollEvent(&event)) {
                if (event.type == c.SDL_EVENT_QUIT or
                    event.type == c.SDL_EVENT_TERMINATING or
                    event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED)
                {
                    return;
                }
            }
        }
    }
}
