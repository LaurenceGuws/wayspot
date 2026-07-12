//! Notification mode owns notification history and lifecycle row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const restart_open = "lifecycle:notifications:restart";
pub const history_open = "/notifications history";

/// collect appends notification mode rows to the picker list.
pub fn collect(allocator: std.mem.Allocator, out: *candidate.Candidate.List) !void {
    try out.append(allocator, candidate.Candidate.init(.mode, "/notifications", "Mode", "/notifications"));
    try out.append(allocator, restartLifecycleRow());
    try out.append(allocator, candidate.Candidate.init(.mode, "Notification history", "Lifecycle", history_open));
}

/// restartLifecycleRow returns the explicit notification restart row.
pub fn restartLifecycleRow() candidate.Candidate {
    return candidate.Candidate.init(.lifecycle, "Restart notifications", "Lifecycle", restart_open);
}

/// restartCommand returns the shell command used by the notification restart row.
pub fn restartCommand() []const u8 {
    return "sh -lc 'bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --notifications-daemon$\" 2>/dev/null || true; sleep 0.2; setsid -f \"$bin\" --notifications-daemon'";
}

test "notification mode owns history and restart lifecycle rows" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);

    try collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(candidate.Candidate.Kind.lifecycle, list.items[1].kind);
    try std.testing.expectEqualStrings(restart_open, list.items[1].open);
    try std.testing.expectEqualStrings(history_open, list.items[2].open);
}

test "notification restart starts the owner directly" {
    const command = restartCommand();
    try std.testing.expect(std.mem.indexOf(u8, command, "flock") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "--notifications-daemon") != null);
}
