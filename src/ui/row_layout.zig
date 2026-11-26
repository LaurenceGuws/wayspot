//! Shared geometry for vertical rows. A slot includes its trailing gap for
//! hit testing, while the painted child excludes it. No selection or data
//! ownership: a menu and a scrolling result list have different policies.
const std = @import("std");
const Rect = @import("canvas.zig").Rect;

pub const RowLayout = struct {
    bounds: Rect,
    pitch: u16,
    gap: u16,

    pub fn init(bounds: Rect, pitch: u16, gap: u16) RowLayout {
        std.debug.assert(pitch > gap and bounds.w > 0 and bounds.h >= 0);
        std.debug.assert(@rem(bounds.h, @as(i32, pitch)) == 0);
        std.debug.assert(@as(i64, bounds.x) + bounds.w <= std.math.maxInt(i32));
        std.debug.assert(@as(i64, bounds.y) + bounds.h <= std.math.maxInt(i32));
        return .{ .bounds = bounds, .pitch = pitch, .gap = gap };
    }

    pub fn count(self: RowLayout) usize {
        return @intCast(@divExact(self.bounds.h, @as(i32, self.pitch)));
    }

    /// Child bounds are relative to the row container, excluding the gap.
    pub fn row(self: RowLayout, index: usize) ?Rect {
        if (index >= self.count()) return null;
        return .{ .y = @as(i32, @intCast(index)) * self.pitch, .w = self.bounds.w, .h = self.pitch - self.gap };
    }

    /// Root-logical, half-open pointer admission. The gap remains part of
    /// its preceding slot, preserving the picker's forgiving hit targets.
    pub fn at(self: RowLayout, x: f32, y: f32) ?usize {
        if (!self.bounds.contains(x, y)) return null;
        const offset = @as(f64, y) - @as(f64, @floatFromInt(self.bounds.y));
        const index: usize = @intFromFloat(offset / @as(f64, @floatFromInt(self.pitch)));
        return if (index < self.count()) index else null;
    }
};

test "row pitch and paint gap are distinct without independent hit geometry" {
    const list = RowLayout.init(.{ .x = 8, .y = 90, .w = 696, .h = 420 }, 30, 2);
    try std.testing.expectEqual(@as(usize, 14), list.count());
    for (0..list.count()) |index| {
        const rect = list.row(index).?;
        try std.testing.expectEqual(@as(i32, 28), rect.h);
        const y: f32 = @floatFromInt(list.bounds.y + rect.y);
        try std.testing.expectEqual(@as(?usize, index), list.at(8, y));
        try std.testing.expectEqual(@as(?usize, index), list.at(703.75, y + 29.75));
        try std.testing.expect(list.at(8, y + 30) != index);
        try std.testing.expect(list.at(704, y) == null);
    }
    try std.testing.expect(list.row(14) == null);
    try std.testing.expect(list.at(8, 510) == null);
    try std.testing.expect(list.at(8, std.math.nan(f32)) == null);
    try std.testing.expect(list.at(8, std.math.inf(f32)) == null);
    const empty = RowLayout.init(.{ .w = 306, .h = 0 }, 27, 0);
    try std.testing.expectEqual(@as(usize, 0), empty.count());
    try std.testing.expect(empty.row(0) == null and empty.at(0, 0) == null);
}
