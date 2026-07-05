//! Picker mode owns the slash-list index and lifecycle row dispatch.

const std = @import("std");
const candidate = @import("picker_candidate");
pub const apps = @import("apps.zig");
pub const notifications = @import("notifications.zig");
pub const sunglasses = @import("sunglasses.zig");
pub const wallpaper = @import("wallpaper.zig");

/// Mode appends the accepted slash-list rows for the picker.
pub const Mode = struct {
    enabled: bool = true,

    /// collect appends static picker modes and lifecycle command rows.
    pub fn collect(
        self: *Mode,
        allocator: std.mem.Allocator,
        out: *candidate.Candidate.List,
    ) !void {
        if (!self.enabled) return;
        try notifications.collect(allocator, out);
        try sunglasses.collect(allocator, out);
        try wallpaper.collect(allocator, out);
    }
};

/// resolveLifecycleCommand returns the command associated with lifecycle rows.
pub fn resolveLifecycleCommand(open: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, open, notifications.restart_open)) return notifications.restartCommand();
    if (std.mem.eql(u8, open, wallpaper.restart_open)) return wallpaper.restartCommand();
    return null;
}

test "mode exposes slash rows and lifecycle restart commands" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);

    var mode = Mode{};
    try mode.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 6), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(candidate.Candidate.Kind.mode, list.items[0].kind);
    try std.testing.expectEqualStrings("/notifications", list.items[0].open);
    try std.testing.expectEqual(candidate.Candidate.Kind.lifecycle, list.items[1].kind);
    try std.testing.expectEqualStrings(notifications.history_open, list.items[2].open);
    try std.testing.expectEqualStrings("/sunglasses", list.items[3].open);
    try std.testing.expect(resolveLifecycleCommand(list.items[1].open) != null);
}
