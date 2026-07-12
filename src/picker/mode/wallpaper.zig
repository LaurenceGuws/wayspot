//! Wallpaper owns route behavior for WallpaperSubCmd.
//!
//! The child union is declared in picker/sub_cmd.zig. This file constructs
//! picker candidates and bounded lifecycle meaning; image and Wayland runtime
//! remain in src/wallpaper/.

const std = @import("std");
const candidate = @import("picker_candidate");
const sub_cmd = @import("picker_sub_cmd");

/// restart_open is the stable display input for the wallpaper restart route.
pub const restart_open = "lifecycle:wallpapers:restart";

/// collectCandidates constructs the wallpaper lifecycle leaves.
pub fn collectCandidates(out: *candidate.Candidate.List) !void {
    try out.append(restartLifecycleCandidate());
    try out.append(candidate.Candidate.lifecycleLeaf(candidate.wallpaperRotate()));
}

/// restartLifecycleCandidate constructs the typed wallpaper restart leaf.
pub fn restartLifecycleCandidate() candidate.Candidate {
    return candidate.Candidate.lifecycleLeaf(candidate.wallpaperRestart());
}

/// restartSubCmd selects the wallpaper resident restart route.
pub fn restartSubCmd() sub_cmd.SubCmd {
    return .{ .wallpaper = .{ .restart = {} } };
}

/// rotateSubCmd selects the direct one-rotation route.
pub fn rotateSubCmd() sub_cmd.SubCmd {
    return .{ .wallpaper = .{ .rotate = {} } };
}

/// resolve returns canonical wallpaper command meaning without running it.
pub fn resolve(value: sub_cmd.WallpaperSubCmd) []const u8 {
    return switch (value) {
        .restart => restartIntent(),
        .rotate => "wayspot wallpaper rotate",
    };
}

/// restartIntent names the canonical wallpaper resident entrypoint.
pub fn restartIntent() []const u8 {
    return "wayspot wallpaper";
}

/// restartCommand is the existing detached launch bridge retained until the
/// process leaf boundary owns canonical execution.
pub fn restartCommand() []const u8 {
    return "sh -lc 'bin=\"$HOME/.local/bin/wayspot\"; pkill -TERM -f \"^${bin} --wallpaper$\" 2>/dev/null || true; sleep 0.2; setsid -f \"$bin\" --wallpaper'";
}

test "wallpaper mode constructs both typed child routes" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();

    try collectCandidates(&list);

    try std.testing.expectEqual(@as(usize, 2), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings(restart_open, list.items[0].openPayload());
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).concrete, list.items[1].typeOf());
    try std.testing.expectEqualStrings("wayspot wallpaper rotate", list.items[1].openPayload());
}

test "wallpaper routes resolve without importing the resident runtime" {
    try std.testing.expectEqualStrings("wayspot wallpaper", resolve(.restart));
    try std.testing.expectEqualStrings("wayspot wallpaper rotate", resolve(.rotate));
}

test "wallpaper terminal bridge remains until process resolution" {
    const command = restartCommand();
    try std.testing.expect(std.mem.indexOf(u8, command, "flock") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "--wallpaper") != null);
}
