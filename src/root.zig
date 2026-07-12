//! Wayspot root exports accepted env, identity, picker, notification, wallpaper, and overlay owners.
const std = @import("std");
pub const config = @import("config/mod.zig");
pub const env = @import("env/mod.zig");
pub const notification = @import("notification/mod.zig");
pub const picker = @import("picker/mod.zig");
pub const wallpaper = @import("wallpaper/mod.zig");
pub const sunglasses = @import("sunglasses/mod.zig");
pub const identity = @import("identity.zig");

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Usage: wayspot commands | query <text> | open <payload> | complete bash <text> | --ui | --notifications-daemon | --icon-diag | --icon-cache-refresh | --wallpaper | --next-wallpaper | --wallpaper-rotate-now | --sunglasses-daemon | --sunglasses-apply\n", .{});

    try stdout.flush();
}

test "root references config and appearance declarations" {
    std.testing.refAllDecls(config.defaults);
    std.testing.refAllDecls(env);
    std.testing.refAllDecls(picker.appearance);
    std.testing.refAllDecls(@import("wallpaper/surface.zig"));
    std.testing.refAllDecls(@import("sunglasses/overlay.zig"));
    std.testing.refAllDecls(@import("sunglasses/surface.zig"));
}
