//! Wayspot root exports accepted interfaces, env, identity, picker, and resident owners.
const std = @import("std");
pub const cli = @import("cli/entry.zig");
pub const config = @import("config/mod.zig");
pub const env = @import("env/mod.zig");
pub const gui = @import("gui/surface.zig");
pub const notification = @import("notification/mod.zig");
pub const process = @import("process/launch.zig");
pub const picker = @import("picker/mod.zig");
pub const wallpaper = @import("wallpaper/mod.zig");
pub const sunglasses = @import("sunglasses/mod.zig");
pub const identity = @import("identity.zig");

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Usage: wayspot commands \n query <text> \n open <payload> \n complete bash <text> \n --ui \n --notifications-daemon \n --icon-diag \n --icon-cache-refresh \n --wallpaper \n --next-wallpaper \n --wallpaper-rotate-now \n --sunglasses-daemon \n --sunglasses-apply\n", .{});

    try stdout.flush();
}

test "root references config and appearance declarations" {
    std.testing.refAllDecls(config.defaults);
    std.testing.refAllDecls(env);
    std.testing.refAllDecls(process);
    std.testing.refAllDecls(cli);
    std.testing.refAllDecls(cli.bash_completion);
    std.testing.refAllDecls(gui);
    std.testing.refAllDecls(picker.candidate);
    std.testing.refAllDecls(picker.cmd);
    std.testing.refAllDecls(picker.appearance);
    std.testing.refAllDecls(@import("wallpaper/surface.zig"));
    std.testing.refAllDecls(@import("sunglasses/overlay.zig"));
    std.testing.refAllDecls(@import("sunglasses/surface.zig"));
}
