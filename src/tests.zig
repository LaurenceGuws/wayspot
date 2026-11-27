//! One module root for all owned colocated source tests and simulators.

test {
    // zig-audit: acknowledge discard
    // reason: Referencing this compile-time namespace tuple admits every owned source module's colocated tests into this test root.
    _ = .{
        @import("apps/catalog.zig"),
        @import("apps/desktop_files.zig"),
        @import("apps/launch.zig"),
        @import("cli.zig"),
        @import("cmd.zig"),
        @import("control.zig"),
        @import("main.zig"),
        @import("notifications/root.zig"),
        @import("picker/clock.zig"),
        @import("picker/geometry.zig"),
        @import("picker/icon.zig"),
        @import("picker/image.zig"),
        @import("picker/navigator.zig"),
        @import("picker/root.zig"),
        @import("picker/session.zig"),
        @import("picker/simulator.zig"),
        @import("picker/view.zig"),
        @import("resident.zig"),
        @import("stop.zig"),
        @import("tray/host.zig"),
        @import("tray/menu.zig"),
        @import("tray/watcher.zig"),
        @import("ui/native_cursor.zig"),
        @import("ui/native_input.zig"),
        @import("ui/native_surface.zig"),
        @import("ui/native_surface_test.zig"),
        @import("ui/owner.zig"),
        @import("wallpaper/outputs.zig"),
        @import("wallpaper/root.zig"),
        @import("wallpaper/simulator.zig"),
        @import("wallpaper/wayland.zig"),
    };
}
