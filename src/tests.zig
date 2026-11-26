//! One module root for all colocated source tests and simulators.

test {
    _ = @import("apps/catalog.zig");
    _ = @import("cli.zig");
    _ = @import("picker/clock.zig");
    _ = @import("cmd.zig");
    _ = @import("control.zig");
    _ = @import("resident.zig");
    _ = @import("apps/desktop_files.zig");
    _ = @import("picker/icon.zig");
    _ = @import("picker/image.zig");
    _ = @import("apps/launch.zig");
    _ = @import("picker/navigator.zig");
    _ = @import("notifications/root.zig");
    _ = @import("picker/root.zig");
    _ = @import("picker/view.zig");
    _ = @import("picker/geometry.zig");
    _ = @import("picker/simulator.zig");
    _ = @import("ui/text.zig");
    _ = @import("ui/canvas.zig");
    _ = @import("ui/menu.zig");
    _ = @import("ui/row_layout.zig");
    _ = @import("ui/owner.zig");
    _ = @import("ui/native_surface.zig");
    _ = @import("ui/native_surface_test.zig");
    _ = @import("tray/host.zig");
    _ = @import("tray/menu.zig");
    _ = @import("tray/watcher.zig");
    _ = @import("wallpaper/root.zig");
    _ = @import("wallpaper/wayland.zig");
    _ = @import("wallpaper/outputs.zig");
    _ = @import("wallpaper/simulator.zig");
}
