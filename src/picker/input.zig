//! Normalizes bounded SDL input facts without importing the native library.

const std = @import("std");

pub const wheel_row_capacity: i32 = 18;
const rows_per_tick: i32 = 3;

/// Returns a signed row delta where positive values move toward later rows.
pub fn wheelRows(integer_y: i32, flipped: bool) i8 {
    const y: i64 = integer_y;
    const directed = if (flipped) y else -y;
    return @intCast(std.math.clamp(directed, -wheel_row_capacity / rows_per_tick, wheel_row_capacity / rows_per_tick) *
        rows_per_tick);
}

test "normal and flipped wheels preserve intended direction" {
    try std.testing.expectEqual(@as(i8, -3), wheelRows(1, false));
    try std.testing.expectEqual(@as(i8, -3), wheelRows(-1, true));
    try std.testing.expectEqual(@as(i8, 3), wheelRows(-1, false));
    try std.testing.expectEqual(@as(i8, 3), wheelRows(1, true));
}

test "wheel rows are zero preserving and bounded" {
    try std.testing.expectEqual(@as(i8, 0), wheelRows(0, false));
    try std.testing.expectEqual(@as(i8, -18), wheelRows(std.math.maxInt(i32), false));
    try std.testing.expectEqual(@as(i8, 18), wheelRows(std.math.minInt(i32), false));
}
