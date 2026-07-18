//! Owns the fixed beta picker's pixel rectangles and pointer hit testing.

const std = @import("std");

pub const window_width = 720;
pub const window_height = 480;
pub const visible_rows = 14;
pub const icon_size = 22;

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const query_height: f32 = 52;
const row_height: f32 = 30;

pub const query = Rect{ .x = 8, .y = 8, .w = 704, .h = 36 };
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
