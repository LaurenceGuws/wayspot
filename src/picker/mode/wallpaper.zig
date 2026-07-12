//! Wallpaper mode owns wallpaper lifecycle row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const restart_open = "lifecycle:wallpapers:restart";

/// collect appends wallpaper mode rows to the picker list.
pub fn collect(out: *candidate.Candidate.List) !void {
    try out.append(candidate.Candidate.makeMode("/wallpapers", "Mode", "/wallpapers"));
    try out.append(restartLifecycleRow());
}

/// restartLifecycleRow returns the explicit wallpaper restart row.
pub fn restartLifecycleRow() candidate.Candidate {
    return candidate.Candidate.makeLifecycle("Restart wallpaper", "Lifecycle", restart_open);
}

/// restartCommand returns the shell command used by the wallpaper restart row.
pub fn restartCommand() []const u8 {
    return "sh -lc 'bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --wallpaper$\" 2>/dev/null || true; sleep 0.2; setsid -f \"$bin\" --wallpaper'";
}

test "wallpaper mode owns restart lifecycle row" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();

    try collect(&list);

    try std.testing.expectEqual(@as(u32, 2), list.count);
    try std.testing.expectEqual(candidate.Candidate.Type.lifecycle, list.items[1].typeOf());
    try std.testing.expectEqualStrings(restart_open, list.items[1].openPayload());
}

test "wallpaper restart starts the owner directly" {
    const command = restartCommand();
    try std.testing.expect(std.mem.indexOf(u8, command, "flock") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "--wallpaper") != null);
}
