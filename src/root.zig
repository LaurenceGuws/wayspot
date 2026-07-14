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

const help_text =
    "Usage: wayspot <mode> [operation] [input...]\n" ++
    "\n" ++
    "Modes:\n" ++
    "  apps [terms...]                         default picker source\n" ++
    "  notifications                           resident notification process\n" ++
    "  wallpaper                               resident wallpaper process\n" ++
    "  wallpaper rotate                        request one wallpaper rotation\n" ++
    "  sunglasses                              resident overlay process\n" ++
    "  sunglasses apply|reconcile              apply saved overlay state\n" ++
    "  sunglasses dim|filter|image ...         edit one monitor value\n" ++
    "\n" ++
    "Interfaces:\n" ++
    "  wayspot --ui                            GUI picker\n" ++
    "  wayspot query <text>                    CLI query\n" ++
    "  wayspot open <candidate>                CLI launch\n" ++
    "  wayspot complete bash <position> <text> Bash completion\n";

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll(help_text);

    try stdout.flush();
}

test "root help exposes canonical modes and no resident flags" {
    try std.testing.expect(std.mem.indexOf(u8, help_text, "  apps [terms...]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "  notifications") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "  wallpaper") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "  sunglasses") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "wayspot --ui") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "--notifications-daemon") == null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "--wallpaper") == null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "--sunglasses") == null);
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
