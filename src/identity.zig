//! Identity owns bounded Linux comm names for Wayspot entrypoints.

const std = @import("std");

const max_linux_comm_visible_bytes: u32 = 15;

pub const notifications = "wayspot-notify";
pub const picker = "wayspot-picker";
pub const wallpaper = "wayspot-wall";
pub const sunglasses = "wayspot-sunglas";

comptime {
    std.debug.assert(notifications.len <= max_linux_comm_visible_bytes);
    std.debug.assert(picker.len <= max_linux_comm_visible_bytes);
    std.debug.assert(wallpaper.len <= max_linux_comm_visible_bytes);
    std.debug.assert(sunglasses.len <= max_linux_comm_visible_bytes);
}

pub fn set(name: []const u8) !void {
    if (name.len == 0 or name.len > max_linux_comm_visible_bytes) return error.InvalidIdentityName;
    var buf: [max_linux_comm_visible_bytes + 1:0]u8 = undefined;
    @memset(&buf, 0);
    @memcpy(buf[0..name.len], name);
    const ptr_value: u64 = @intFromPtr(&buf);
    if (@import("builtin").os.tag == .linux) {
        const result = try std.posix.prctl(.SET_NAME, .{ptr_value});
        if (result != 0) return error.IdentityNameFailed;
    }
}

test "visible comm names fit Linux visible entrypoint name bound" {
    try std.testing.expect(notifications.len <= max_linux_comm_visible_bytes);
    try std.testing.expect(picker.len <= max_linux_comm_visible_bytes);
    try std.testing.expect(wallpaper.len <= max_linux_comm_visible_bytes);
    try std.testing.expect(sunglasses.len <= max_linux_comm_visible_bytes);
}
