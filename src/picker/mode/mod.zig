//! Picker mode owns the slash-list index and restart lifecycle row dispatch.

const std = @import("std");
const candidate = @import("picker_candidate");
pub const apps = @import("apps.zig");
pub const notifications = @import("notifications.zig");
pub const wallpaper = @import("wallpaper.zig");

/// Mode appends the accepted slash-list rows for the picker.
pub const Mode = struct {
    enabled: bool = true,

    /// collect appends static picker modes and restart lifecycle rows.
    pub fn collect(
        self: *Mode,
        allocator: std.mem.Allocator,
        out: *candidate.Candidate.List,
    ) !void {
        if (!self.enabled) return;
        try notifications.collect(allocator, out);
        try wallpaper.collect(allocator, out);
    }
};

/// resolveRestartLifecycleCommand returns the command associated with restart rows.
pub fn resolveRestartLifecycleCommand(open: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, open, notifications.restart_open)) return notifications.restartCommand();
    if (std.mem.eql(u8, open, wallpaper.restart_open)) return wallpaper.restartCommand();
    return null;
}

test "mode exposes rows from picker mode owners" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);

    var mode = Mode{};
    try mode.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 5), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(candidate.Candidate.Type.mode, list.items[0].typeOf());
    try std.testing.expectEqualStrings("/notifications", list.items[0].openPayload());
    try std.testing.expectEqual(candidate.Candidate.Type.lifecycle, list.items[1].typeOf());
    try std.testing.expectEqualStrings(notifications.restart_open, list.items[1].openPayload());
    try std.testing.expectEqualStrings(notifications.history_open, list.items[2].openPayload());
    try std.testing.expectEqualStrings(wallpaper.restart_open, list.items[4].openPayload());
    try std.testing.expect(resolveRestartLifecycleCommand(list.items[1].openPayload()) != null);
    try std.testing.expect(resolveRestartLifecycleCommand(list.items[4].openPayload()) != null);
}
