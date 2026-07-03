//! Wayspot owns the daemon, launcher, notification, and UI modules.
const std = @import("std");
pub const app = @import("app/mod.zig");
pub const config = @import("config/mod.zig");
pub const providers = @import("providers/mod.zig");
pub const search = @import("search/mod.zig");
pub const ui = @import("ui/mod.zig");
pub const ipc = @import("ipc/mod.zig");
pub const notifications = @import("notifications/mod.zig");

pub fn bufferedPrint() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Wayspot daemon expects --ui-resident or --ctl.\n", .{});

    try stdout.flush();
}
