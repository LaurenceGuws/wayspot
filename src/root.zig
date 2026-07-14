//! Wayspot root exports accepted interfaces, environment facts, picker values,
//! and resident runtime owners.
const std = @import("std");
pub const cli = @import("wayspot_cli");
pub const config = @import("wayspot_config");
pub const env = @import("wayspot_env");
pub const gui = @import("wayspot_gui");
pub const notification = @import("wayspot_notification");
pub const process = @import("wayspot_process");
pub const picker = @import("wayspot_picker");
pub const wallpaper = @import("wayspot_wallpaper");
pub const sunglasses = @import("wayspot_sunglasses");
pub const identity = @import("wayspot_identity");

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
    std.testing.refAllDecls(notification);
    std.testing.refAllDecls(wallpaper);
    std.testing.refAllDecls(sunglasses);
    std.testing.refAllDecls(cli);
    std.testing.refAllDecls(cli.bash_completion);
    std.testing.refAllDecls(gui);
    std.testing.refAllDecls(picker.candidate);
    std.testing.refAllDecls(picker.cmd);
    std.testing.refAllDecls(picker.appearance);
}
