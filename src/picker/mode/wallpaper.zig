//! Wallpaper mode owns wallpaper lifecycle row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const restart_open = "lifecycle:wallpapers:restart";

/// collect appends wallpaper mode rows to the picker list.
pub fn collect(allocator: std.mem.Allocator, out: *candidate.Candidate.List) !void {
    try out.append(allocator, candidate.Candidate.init(.mode, "/wallpapers", "Mode", "/wallpapers"));
    try out.append(allocator, candidate.Candidate.init(.lifecycle, "Restart wallpaper", "Lifecycle", restart_open));
}

/// restartCommand returns the shell command used by the wallpaper restart row.
pub fn restartCommand() []const u8 {
    return "sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/wayspot\"; bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --wallpaper$\" 2>/dev/null || true; sleep 0.2; mkdir -p \"$state\"; setsid -f flock -n \"$state/wallpaper.lock\" \"$bin\" --wallpaper'";
}
