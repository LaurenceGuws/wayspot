//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
pub const app = @import("app/mod.zig");
pub const config = @import("config/mod.zig");
pub const providers = @import("providers/mod.zig");
pub const search = @import("search/mod.zig");
pub const ui = @import("ui/mod.zig");
pub const wm = @import("wm/mod.zig");
pub const ipc = @import("ipc/mod.zig");
pub const notifications = @import("notifications/mod.zig");
pub const shell = @import("shell/mod.zig");
pub const tools = struct {
    pub const theme_apply = @import("tools/theme_apply.zig");
    pub const theme_registry = @import("tools/theme_registry.zig");
    pub const theme_state = @import("tools/theme_state.zig");
    pub const slideshow_control = @import("tools/slideshow_control.zig");
    pub const wallpaper_sorter = @import("tools/wallpaper_sorter.zig");
    pub const wallpaper_runtime = @import("tools/wallpaper_runtime.zig");
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Wayspot scaffold ready. Run `zig build test`.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
