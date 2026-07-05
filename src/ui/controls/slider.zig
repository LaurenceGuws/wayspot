//! Scalar slider math for callers that own layout, rendering, and state effects.

const std = @import("std");

/// Horizontal track facts used to map pointer x positions.
pub const Track = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    /// Builds a track with a positive effective width for pointer math.
    pub fn init(x: f32, y: f32, w: f32, h: f32) Track {
        return .{
            .x = x,
            .y = y,
            .w = @max(1, w),
            .h = h,
        };
    }
};

/// Inclusive integer range used by a scalar slider.
pub const ScalarRange = struct {
    min: i32,
    max: i32,

    /// Creates an inclusive range for clamping and pointer mapping.
    pub fn init(min: i32, max: i32) ScalarRange {
        std.debug.assert(min <= max);
        return .{ .min = min, .max = max };
    }

    /// Clamps a value into this range.
    pub fn clamp(self: ScalarRange, value: i32) i32 {
        return @min(self.max, @max(self.min, value));
    }

    /// Applies a keyboard or step delta and clamps the result.
    pub fn adjust(self: ScalarRange, value: i32, delta: i32) i32 {
        return self.clamp(value + delta);
    }

    /// Returns the clamped 0..1 position for a value in this range.
    pub fn normalized(self: ScalarRange, value: i32) f32 {
        const span = self.max - self.min;
        if (span == 0) return 0;
        return @as(f32, @floatFromInt(self.clamp(value) - self.min)) /
            @as(f32, @floatFromInt(span));
    }

    /// Maps a pointer x coordinate on `track` into this bounded range.
    pub fn valueFromX(self: ScalarRange, track: Track, x: f32) i32 {
        const normalized_x = @min(1, @max(0, (x - track.x) / track.w));
        const span = self.max - self.min;
        return self.clamp(self.min + @as(i32, @intFromFloat(@round(normalized_x * @as(f32, @floatFromInt(span))))));
    }
};

test "min and max clamp" {
    const range = ScalarRange.init(-10, 10);
    try std.testing.expectEqual(@as(i32, -10), range.clamp(-99));
    try std.testing.expectEqual(@as(i32, 0), range.clamp(0));
    try std.testing.expectEqual(@as(i32, 10), range.clamp(99));
}

test "delta adjust clamps" {
    const range = ScalarRange.init(0, 100);
    try std.testing.expectEqual(@as(i32, 0), range.adjust(2, -10));
    try std.testing.expectEqual(@as(i32, 55), range.adjust(50, 5));
    try std.testing.expectEqual(@as(i32, 100), range.adjust(98, 10));
}

test "normalized value" {
    const range = ScalarRange.init(-100, 100);
    try std.testing.expectEqual(@as(f32, 0), range.normalized(-200));
    try std.testing.expectEqual(@as(f32, 0.5), range.normalized(0));
    try std.testing.expectEqual(@as(f32, 1), range.normalized(200));
}

test "pointer x maps to bounded value" {
    const range = ScalarRange.init(-100, 100);
    const track = Track.init(20, 0, 200, 4);
    try std.testing.expectEqual(@as(i32, -100), range.valueFromX(track, 0));
    try std.testing.expectEqual(@as(i32, 0), range.valueFromX(track, 120));
    try std.testing.expectEqual(@as(i32, 100), range.valueFromX(track, 300));
}
