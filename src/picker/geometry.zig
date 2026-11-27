//! Owns the fixed picker's pixel rectangles and pointer hit testing.

const std = @import("std");
const wattle = @import("wattle");
const CanvasRect = wattle.Rect;
const TextField = wattle.TextField;
const RowLayout = wattle.RowLayout;

/// Picker logical width, independent of output density.
pub const window_width = 720;
/// Picker logical height, independent of output density.
pub const window_height = 520;
/// Maximum simultaneously displayed result rows.
pub const visible_rows = 14;
/// Logical side length of a result icon.
pub const icon_size = 22;

/// Slots preserve the original 30-pixel hit target and 28-pixel painted row.
pub const results = RowLayout.init(.{ .x = 8, .y = 90, .w = 696, .h = 30 * visible_rows }, 30, 2);

/// The toolbar is part of the existing picker window, not a desktop layer.
pub const toolbar = CanvasRect{ .x = 8, .y = 8, .w = 704, .h = 30 };
/// Search field and its shared IME/pointer geometry.
pub const query = TextField{ .bounds = .{ .x = 8, .y = 46, .w = 704, .h = 36 } };
/// Children are toolbar-local, never independent absolute hitboxes.
pub const clock_clip = CanvasRect{ .x = 507, .y = 1, .w = 189, .h = 28 };

/// Maximum toolbar tray slots before the clock.
pub const tray_capacity = 12;
const tray_size: i32 = 26;
const tray_right: i32 = 501;

/// Tray slots populate from right to left, immediately before the clock.
/// Zero items consume zero pixels; there are no placeholder application icons.
pub fn traySlot(index: usize) CanvasRect {
    std.debug.assert(index < tray_capacity);
    return .{
        .x = tray_right - tray_size * @as(i32, @intCast(index + 1)),
        .y = 2,
        .w = tray_size,
        .h = tray_size,
    };
}

/// Resolves a half-open toolbar slot to an admitted tray item.
pub fn trayAt(x: f32, y: f32, count: usize) ?usize {
    if (count > tray_capacity or !toolbar.contains(x, y)) return null;
    const local_x = x - @as(f32, @floatFromInt(toolbar.x));
    const local_y = y - @as(f32, @floatFromInt(toolbar.y));
    for (0..count) |index| {
        if (traySlot(index).contains(local_x, local_y)) return index;
    }
    return null;
}
/// Result-list scrollbar clip in window coordinates.
pub const scrollbar_track = CanvasRect{
    .x = results.bounds.x + results.bounds.w + 4,
    .y = results.bounds.y,
    .w = 4,
    .h = results.bounds.h,
};

/// Fractional thumb relative to its track; the track owns clipping.
pub fn scrollbar(first: usize, shown: usize, total: usize) ?wattle.FloatRect {
    if (total <= shown) return null;
    std.debug.assert(shown > 0);
    std.debug.assert(first <= total - shown);
    const shown_float: f32 = @floatFromInt(shown);
    const total_float: f32 = @floatFromInt(total);
    const track_height: f32 = @floatFromInt(scrollbar_track.h);
    const height = @max(16, track_height * shown_float / total_float);
    const offset = @as(f32, @floatFromInt(first)) / @as(f32, @floatFromInt(total - shown));
    return .{
        .x = 0,
        .y = (track_height - height) * offset,
        .w = @floatFromInt(scrollbar_track.w),
        .h = height,
    };
}

test "scrollbar maps first and last pages to track ends" {
    const first = scrollbar(0, visible_rows, 90).?;
    const last = scrollbar(90 - visible_rows, visible_rows, 90).?;
    try std.testing.expectEqual(@as(f32, 0), first.y);
    try std.testing.expectEqual(@as(f32, @floatFromInt(scrollbar_track.h)), last.y + last.h);
    try std.testing.expectEqual(null, scrollbar(0, visible_rows, visible_rows));
}

test "toolbar, search and all fourteen rows stay separate within the window" {
    try std.testing.expect(toolbar.y + toolbar.h < query.bounds.y);
    try std.testing.expect(query.bounds.y + query.bounds.h < results.bounds.y);
    try std.testing.expect(results.bounds.y + results.bounds.h <= window_height);
    try std.testing.expectEqual(@as(usize, visible_rows), results.count());
    try std.testing.expectEqual(@as(?usize, null), results.at(20, @floatFromInt(toolbar.y + 5)));
    try std.testing.expectEqual(@as(?usize, null), results.at(20, @floatFromInt(query.bounds.y + 5)));
    try std.testing.expectEqual(@as(?usize, 0), results.at(20, 95));
    try std.testing.expectEqual(@as(?usize, visible_rows - 1), results.at(20, 485));
}

test "tray hitboxes stay within toolbar and never overlap the clock" {
    try std.testing.expectEqual(@as(?usize, null), trayAt(500, 20, 0));
    try std.testing.expectEqual(@as(?usize, 0), trayAt(495, 20, 1));
    try std.testing.expectEqual(@as(?usize, 1), trayAt(468, 20, 2));
    try std.testing.expectEqual(@as(?usize, null), trayAt(495, @floatFromInt(query.bounds.y), 2));
    try std.testing.expectEqual(@as(?usize, null), trayAt(std.math.nan(f32), 20, 1));
    try std.testing.expectEqual(@as(?usize, null), trayAt(495, 20, tray_capacity + 1));
    for (0..tray_capacity) |index| {
        const slot = traySlot(index);
        try std.testing.expect(slot.y >= 0);
        try std.testing.expect(slot.y + slot.h <= toolbar.h);
        try std.testing.expect(slot.x + slot.w <= clock_clip.x);
        try std.testing.expect(slot.x >= 0);
        const left: f32 = @floatFromInt(toolbar.x + slot.x);
        const top: f32 = @floatFromInt(toolbar.y + slot.y);
        const right = left + @as(f32, @floatFromInt(slot.w));
        const bottom = top + @as(f32, @floatFromInt(slot.h));
        try std.testing.expectEqual(@as(?usize, index), trayAt(left, top, tray_capacity));
        try std.testing.expectEqual(@as(?usize, index), trayAt(right - 0.25, bottom - 0.25, tray_capacity));
        try std.testing.expectEqual(@as(?usize, null), trayAt(left, bottom, tray_capacity));
        try std.testing.expect(trayAt(right, top, tray_capacity) != index);
        try std.testing.expect(trayAt(left - 0.25, top, tray_capacity) != index);
    }
}
