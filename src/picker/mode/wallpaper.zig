//! Wallpaper mode owns wallpaper lifecycle row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const restart_open = "lifecycle:wallpapers:restart";

/// collect appends wallpaper mode rows to the picker list.
pub fn collect(allocator: std.mem.Allocator, out: *candidate.Candidate.List) !void {
    try out.append(allocator, candidate.Candidate.init(.mode, "/wallpapers", "Mode", "/wallpapers"));
    try out.append(allocator, restartLifecycleRow());
}

/// restartLifecycleRow returns the explicit wallpaper restart row.
pub fn restartLifecycleRow() candidate.Candidate {
    return candidate.Candidate.init(.lifecycle, "Restart wallpaper", "Lifecycle", restart_open);
}

/// restartCommand returns the shell command used by the wallpaper restart row.
pub fn restartCommand() []const u8 {
    return "sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/wayspot\"; bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --wallpaper$\" 2>/dev/null || true; sleep 0.2; mkdir -p \"$state\"; setsid -f flock -n \"$state/wallpaper.lock\" \"$bin\" --wallpaper'";
}

test "wallpaper mode owns restart lifecycle row" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit(std.testing.allocator);

    try collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(candidate.Candidate.Kind.lifecycle, list.items[1].kind);
    try std.testing.expectEqualStrings(restart_open, list.items[1].open);
}
