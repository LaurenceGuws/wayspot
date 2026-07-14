//! Notifications owns route behavior for NotificationsSubCmd.
//!
//! The child union is declared in picker/sub_cmd.zig. This file constructs
//! picker candidates and bounded lifecycle meaning; DBus runtime ownership
//! remains in src/notification/.

const std = @import("std");
const candidate = @import("picker_candidate");
const sub_cmd = @import("picker_sub_cmd");

/// restart_open is the stable display input for the notification restart route.
pub const restart_open = "lifecycle:notifications:restart";
/// history_open is the stable display input for the notification history route.
pub const history_open = "/notifications history";

/// collectCandidates constructs the notification restart leaf and history route.
pub fn collectCandidates(out: *candidate.Candidate.List) !void {
    try out.append(restartLifecycleCandidate());
    try out.append(candidate.Candidate.subCmd(historySubCmd()));
}

/// restartLifecycleCandidate constructs the typed notification lifecycle leaf.
pub fn restartLifecycleCandidate() candidate.Candidate {
    return candidate.Candidate.lifecycleLeaf(candidate.notificationsRestart());
}

/// restartSubCmd selects the notification resident restart route.
pub fn restartSubCmd() sub_cmd.SubCmd {
    return .{ .notifications = .{ .restart = {} } };
}

/// historySubCmd selects the notification history child route.
pub fn historySubCmd() sub_cmd.SubCmd {
    return .{ .notifications = .{ .history = {} } };
}

/// resolve returns the canonical command meaning for a notification route.
/// History is display-only and therefore has no executable intent here.
pub fn resolve(value: sub_cmd.NotificationsSubCmd) ?[]const u8 {
    return switch (value) {
        .history => null,
        .restart => restartIntent(),
    };
}

/// restartIntent names the canonical notification resident entrypoint.
pub fn restartIntent() []const u8 {
    return "wayspot notifications";
}

test "notification mode constructs both typed child routes" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();

    try collectCandidates(&list);

    try std.testing.expectEqual(@as(usize, 2), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings(restart_open, list.items[0].openPayload());
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).sub_cmd, list.items[1].typeOf());
    try std.testing.expectEqualStrings(history_open, list.items[1].openPayload());
    try std.testing.expectEqual(sub_cmd.NotificationsSubCmd.restart, std.meta.activeTag(restartSubCmd().notifications));
    try std.testing.expectEqual(sub_cmd.NotificationsSubCmd.history, std.meta.activeTag(historySubCmd().notifications));
}

test "notification route resolves without importing the resident runtime" {
    try std.testing.expectEqualStrings("wayspot notifications", resolve(.restart).?);
    try std.testing.expect(resolve(.history) == null);
}

test "notification restart intent is canonical" {
    try std.testing.expectEqualStrings("wayspot notifications", restartIntent());
}
