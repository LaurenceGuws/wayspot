//! Owns the fixed picker's pixel rectangles and pointer hit testing.

const std = @import("std");
const CanvasRect = @import("../ui/canvas.zig").Rect;

pub const window_width = 720;
pub const window_height = 520;
pub const visible_rows = 14;
pub const icon_size = 22;

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const query_height: f32 = 90;
const row_height: f32 = 30;

/// The toolbar is part of the existing picker window, not a desktop layer.
pub const toolbar = CanvasRect{ .x = 8, .y = 8, .w = 704, .h = 30 };
pub const query = Rect{ .x = 8, .y = 46, .w = 704, .h = 36 };
/// Children are toolbar-local, never independent absolute hitboxes.
pub const clock_clip = CanvasRect{ .x = 507, .y = 1, .w = 189, .h = 28 };

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

pub fn trayAt(x: f32, y: f32, count: usize) ?usize {
    if (count > tray_capacity or !toolbar.contains(x, y)) return null;
    const local_x = x - @as(f32, @floatFromInt(toolbar.x));
    const local_y = y - @as(f32, @floatFromInt(toolbar.y));
    for (0..count) |index| {
        if (traySlot(index).contains(local_x, local_y)) return index;
    }
    return null;
}
pub const scrollbar_track = Rect{
    .x = 708,
    .y = query_height,
    .w = 4,
    .h = row_height * visible_rows,
};

pub fn row(index: usize) Rect {
    std.debug.assert(index < visible_rows);
    return .{
        .x = 8,
        .y = query_height + @as(f32, @floatFromInt(index)) * row_height,
        .w = 696,
        .h = row_height - 2,
    };
}

pub fn icon(index: usize) Rect {
    const item = row(index);
    return .{ .x = 14, .y = item.y + 3, .w = icon_size, .h = icon_size };
}

pub fn textY(index: usize) f32 {
    return row(index).y + 5;
}

pub fn rowAt(x: f32, y: f32) ?usize {
    if (x < 8 or x >= 704 or y < query_height) return null;
    const index: usize = @intFromFloat((y - query_height) / row_height);
    return if (index < visible_rows) index else null;
}

pub fn scrollbar(first: usize, shown: usize, total: usize) ?Rect {
    if (total <= shown) return null;
    std.debug.assert(shown > 0);
    std.debug.assert(first <= total - shown);
    const shown_float: f32 = @floatFromInt(shown);
    const total_float: f32 = @floatFromInt(total);
    const height = @max(16, scrollbar_track.h * shown_float / total_float);
    const offset = @as(f32, @floatFromInt(first)) / @as(f32, @floatFromInt(total - shown));
    return .{
        .x = scrollbar_track.x,
        .y = scrollbar_track.y + (scrollbar_track.h - height) * offset,
        .w = scrollbar_track.w,
        .h = height,
    };
}

test "rows share exact draw and pointer edges" {
    const first = row(0);
    const last = row(visible_rows - 1);
    try std.testing.expectEqual(@as(usize, 0), rowAt(first.x, first.y).?);
    try std.testing.expectEqual(@as(usize, visible_rows - 1), rowAt(last.x, last.y).?);
    try std.testing.expectEqual(null, rowAt(first.x - 1, first.y));
    try std.testing.expectEqual(null, rowAt(first.x + first.w, first.y));
    try std.testing.expectEqual(null, rowAt(last.x, last.y + row_height));
}

test "scrollbar maps first and last pages to track ends" {
    const first = scrollbar(0, visible_rows, 90).?;
    const last = scrollbar(90 - visible_rows, visible_rows, 90).?;
    try std.testing.expectEqual(scrollbar_track.y, first.y);
    try std.testing.expectEqual(scrollbar_track.y + scrollbar_track.h, last.y + last.h);
    try std.testing.expectEqual(null, scrollbar(0, visible_rows, visible_rows));
}

test "toolbar, search and all fourteen rows stay separate within the window" {
    try std.testing.expect(@as(f32, @floatFromInt(toolbar.y + toolbar.h)) < query.y);
    try std.testing.expect(query.y + query.h < row(0).y);
    try std.testing.expect(row(visible_rows - 1).y + row(visible_rows - 1).h <= window_height);
    try std.testing.expectEqual(@as(?usize, null), rowAt(20, @floatFromInt(toolbar.y + 5)));
    try std.testing.expectEqual(@as(?usize, null), rowAt(20, query.y + 5));
    try std.testing.expectEqual(@as(?usize, 0), rowAt(20, row(0).y + 5));
    try std.testing.expectEqual(@as(?usize, visible_rows - 1), rowAt(20, row(visible_rows - 1).y + 5));
}

test "tray hitboxes stay within toolbar and never overlap the clock" {
    try std.testing.expectEqual(@as(?usize, null), trayAt(500, 20, 0));
    try std.testing.expectEqual(@as(?usize, 0), trayAt(495, 20, 1));
    try std.testing.expectEqual(@as(?usize, 1), trayAt(468, 20, 2));
    try std.testing.expectEqual(@as(?usize, null), trayAt(495, query.y, 2));
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
