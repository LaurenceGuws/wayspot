//! Notification mode owns notification history and lifecycle row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const restart_open = "lifecycle:notifications:restart";
pub const history_open = "/notifications history";

/// collect appends notification mode rows to the picker list.
pub fn collect(allocator: std.mem.Allocator, out: *candidate.Candidate.List) !void {
    try out.append(allocator, candidate.Candidate.init(.mode, "/notifications", "Mode", "/notifications"));
    try out.append(allocator, candidate.Candidate.init(.lifecycle, "Restart notifications", "Lifecycle", restart_open));
    try out.append(allocator, candidate.Candidate.init(.mode, "Notification history", "Lifecycle", history_open));
}

/// restartCommand returns the shell command used by the notification restart row.
pub fn restartCommand() []const u8 {
    return "sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/wayspot\"; bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --notifications-daemon$\" 2>/dev/null || true; sleep 0.2; mkdir -p \"$state\"; setsid -f flock -n \"$state/notifications.lock\" \"$bin\" --notifications-daemon'";
}
