//! Deterministic time and output-readiness histories for wallpaper scheduling.
const std = @import("std");
const wallpaper = @import("root.zig");

test "hourly rotation uses a real deadline and never catches up after zero outputs" {
    const hour = wallpaper.rotation_interval_milliseconds;
    var schedule: wallpaper.Schedule = .{};
    try std.testing.expect(schedule.wake(0, false) == null);
    try schedule.advance(10);
    try std.testing.expectEqual(@as(?u64, hour), schedule.wake(10, true));
    try std.testing.expect(!schedule.due(hour + 9, true));
    try std.testing.expect(schedule.due(hour + 10, true));
    for (0..24) |n| {
        const now = @as(u64, @intCast(n + 1)) * hour + 10;
        try std.testing.expect(schedule.wake(now, false) == null);
        try std.testing.expect(!schedule.due(now, false));
    }
    const resumed = 25 * hour;
    try std.testing.expect(schedule.due(resumed, true));
    try schedule.advance(resumed);
    try std.testing.expect(!schedule.due(resumed, true));
    try std.testing.expectEqual(@as(?u64, hour), schedule.wake(resumed, true));
}

test "deadline arithmetic rejects overflow without mutating accepted deadline" {
    const hour = wallpaper.rotation_interval_milliseconds;
    var schedule: wallpaper.Schedule = .{};
    try schedule.advance(std.math.maxInt(u64) - hour);
    try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), schedule.deadline);
    try std.testing.expectError(error.Overflow, schedule.advance(std.math.maxInt(u64) - hour + 1));
    try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), schedule.deadline);
}

test "failed direct rotation preserves deadline while scheduled failure advances once" {
    const hour = wallpaper.rotation_interval_milliseconds;
    var schedule: wallpaper.Schedule = .{};
    try schedule.advance(100);
    try schedule.attempted(200, true, false);
    try std.testing.expectEqual(@as(?u64, hour + 100), schedule.deadline);
    try schedule.attempted(hour + 100, false, false);
    try std.testing.expectEqual(@as(?u64, 2 * hour + 100), schedule.deadline);
    try schedule.attempted(hour + 200, true, true);
    try std.testing.expectEqual(@as(?u64, 2 * hour + 200), schedule.deadline);
}
