//! ModesProvider owns slash-mode candidates and their daemon commands.

const std = @import("std");
const search = @import("../search/mod.zig");

const notifications_restart = "daemon:notifications:restart";
const wallpapers_restart = "daemon:wallpapers:restart";

pub const ModesProvider = struct {
    enabled: bool = true,

    /// collect appends static picker modes and their first daemon command rows.
    pub fn collect(
        self: *ModesProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !void {
        if (!self.enabled) return;
        try out.append(allocator, search.Candidate.init(.mode, "/notifications", "Daemon mode", "/notifications"));
        try out.append(allocator, search.Candidate.init(.mode, "/wallpapers", "Daemon mode", "/wallpapers"));
        try out.append(allocator, search.Candidate.init(.daemon, "Restart notifications daemon", "Runtime", notifications_restart));
        try out.append(allocator, search.Candidate.init(.daemon, "Restart wallpaper daemon", "Runtime", wallpapers_restart));
    }
};

pub fn resolveDaemonCommand(action: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, action, notifications_restart)) {
        return "sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/wayspot\"; bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --notifications-daemon$\" 2>/dev/null || true; sleep 0.2; mkdir -p \"$state\"; setsid -f flock -n \"$state/notifications.lock\" \"$bin\" --notifications-daemon'";
    }
    if (std.mem.eql(u8, action, wallpapers_restart)) {
        return "sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/wayspot\"; bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --wallpaper$\" 2>/dev/null || true; sleep 0.2; mkdir -p \"$state\"; setsid -f flock -n \"$state/wallpaper.lock\" \"$bin\" --wallpaper'";
    }
    return null;
}

test "modes provider exposes slash modes and daemon restart commands" {
    var list = search.CandidateList.empty;
    defer list.deinit(std.testing.allocator);

    var provider = ModesProvider{};
    try provider.collect(std.testing.allocator, &list);

    try std.testing.expectEqual(@as(u32, 4), @as(u32, @intCast(list.items.len)));
    try std.testing.expectEqual(search.CandidateKind.mode, list.items[0].kind);
    try std.testing.expectEqualStrings("/notifications", list.items[0].action);
    try std.testing.expectEqual(search.CandidateKind.daemon, list.items[2].kind);
    try std.testing.expect(resolveDaemonCommand(list.items[2].action) != null);
}
