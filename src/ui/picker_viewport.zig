//! Picker viewport owns foot-derived row math: selected result, scroll offset, visible range, and hit testing.

const std = @import("std");

pub const max_visible_rows: u32 = 64;
pub const min_scrollbar_thumb_height: f32 = 12;
pub const default_result_list_top: f32 = 66;
pub const default_result_row_x: f32 = 20;
pub const default_result_row_width: f32 = 720;
pub const default_result_row_height: f32 = 44;
pub const default_result_row_gap: f32 = 6;
pub const default_result_title_x: f32 = 34;
pub const default_result_text_top_inset: f32 = 6;
pub const default_result_subtitle_offset: f32 = 20;
pub const default_result_icon_size: f32 = 28;
pub const default_result_icon_right_inset: f32 = 14;
pub const default_scrollbar_track = Rect{ .x = 746, .y = 66, .w = 4, .h = 394 };

/// VisibleRange names the absolute result rows that may be rendered for the current frame.
pub const VisibleRange = struct {
    start: u32,
    count: u32,
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

/// Scrollbar is passive render geometry; dragging is outside the picker viewport scope.
pub const Scrollbar = struct {
    needed: bool,
    track: Rect,
    thumb: Rect,

    pub fn forViewport(viewport: *const Viewport, track: Rect) Scrollbar {
        const visible_rows = clampVisibleRows(viewport.visible_rows);
        if (viewport.total_rows <= visible_rows or track.h <= 0 or track.w <= 0) {
            return .{
                .needed = false,
                .track = track,
                .thumb = .{ .x = track.x, .y = track.y, .w = track.w, .h = 0 },
            };
        }

        const visible_float: f32 = @floatFromInt(visible_rows);
        const total_float: f32 = @floatFromInt(viewport.total_rows);
        const base_thumb_height = track.h * (visible_float / total_float);
        const thumb_height = @min(track.h, @max(base_thumb_height, @min(track.h, min_scrollbar_thumb_height)));
        const travel = track.h - thumb_height;
        const max_scroll = maxScrollOffset(viewport.total_rows, visible_rows);
        const offset_float: f32 = @floatFromInt(@min(viewport.scroll_offset, max_scroll));
        const max_scroll_float: f32 = @floatFromInt(max_scroll);
        const thumb_y = if (max_scroll == 0) track.y else track.y + travel * (offset_float / max_scroll_float);

        return .{
            .needed = true,
            .track = track,
            .thumb = .{ .x = track.x, .y = thumb_y, .w = track.w, .h = thumb_height },
        };
    }
};

/// ResultLayout keeps foot-style base-coordinate row geometry shared by render and input hit testing.
pub const ResultLayout = struct {
    result_top: f32,
    row_x: f32,
    row_width: f32,
    row_height: f32,
    row_gap: f32,
    title_x: f32,
    text_top_inset: f32,
    subtitle_offset: f32,
    icon_size: f32,
    icon_right_inset: f32,
    scrollbar_track: Rect,
    visible_rows: u32,

    pub fn default(visible_rows: u32) ResultLayout {
        return .{
            .result_top = default_result_list_top,
            .row_x = default_result_row_x,
            .row_width = default_result_row_width,
            .row_height = default_result_row_height,
            .row_gap = default_result_row_gap,
            .title_x = default_result_title_x,
            .text_top_inset = default_result_text_top_inset,
            .subtitle_offset = default_result_subtitle_offset,
            .icon_size = default_result_icon_size,
            .icon_right_inset = default_result_icon_right_inset,
            .scrollbar_track = default_scrollbar_track,
            .visible_rows = @max(1, @min(visible_rows, max_visible_rows)),
        };
    }

    pub fn rowRect(self: ResultLayout, visible_row: u32) Rect {
        std.debug.assert(visible_row < self.visible_rows);
        const row_step = self.row_height + self.row_gap;
        const y = self.result_top + row_step * @as(f32, @floatFromInt(visible_row));
        return .{ .x = self.row_x, .y = y, .w = self.row_width, .h = self.row_height };
    }

    pub fn titleY(self: ResultLayout, visible_row: u32) f32 {
        return self.rowRect(visible_row).y + self.text_top_inset;
    }

    pub fn subtitleY(self: ResultLayout, visible_row: u32) f32 {
        return self.titleY(visible_row) + self.subtitle_offset;
    }

    pub fn iconRect(self: ResultLayout, visible_row: u32) Rect {
        const row = self.rowRect(visible_row);
        const icon_size = @min(self.icon_size, row.h);
        return .{
            .x = row.x + row.w - self.icon_right_inset - icon_size,
            .y = row.y + (row.h - icon_size) / 2,
            .w = icon_size,
            .h = icon_size,
        };
    }

    pub fn visibleRowAtPoint(self: ResultLayout, x: f32, y: f32) ?u32 {
        if (x < self.row_x or x >= self.row_x + self.row_width) return null;
        if (y < self.result_top) return null;

        const row_step = self.row_height + self.row_gap;
        if (row_step <= 0) return null;

        const row_float = @floor((y - self.result_top) / row_step);
        if (row_float >= @as(f32, @floatFromInt(self.visible_rows))) return null;

        const row: u32 = @intFromFloat(row_float);
        const top = self.result_top + row_step * @as(f32, @floatFromInt(row));
        return if (y < top + self.row_height) row else null;
    }

    pub fn scrollbar(self: ResultLayout, viewport: *const Viewport) Scrollbar {
        return Scrollbar.forViewport(viewport, self.scrollbar_track);
    }
};

/// Viewport keeps selected_row visible or absent; callers never index results without asking it.
pub const Viewport = struct {
    total_rows: u32,
    selected_row: ?u32,
    scroll_offset: u32,
    visible_rows: u32,

    pub fn init() Viewport {
        return .{
            .total_rows = 0,
            .selected_row = null,
            .scroll_offset = 0,
            .visible_rows = 1,
        };
    }

    pub fn resetResults(viewport: *Viewport, total_rows: u32) bool {
        const before = viewport.*;
        viewport.total_rows = total_rows;
        viewport.visible_rows = clampVisibleRows(viewport.visible_rows);
        if (total_rows == 0) {
            viewport.selected_row = null;
            viewport.scroll_offset = 0;
            return !sameState(before, viewport.*);
        }

        const selected_index = viewport.selected_row orelse 0;
        viewport.selected_row = @min(selected_index, total_rows - 1);
        viewport.scroll_offset = @min(viewport.scroll_offset, maxScrollOffset(viewport.total_rows, viewport.visible_rows));
        viewport.keepSelectionVisible();
        viewport.assertValid();
        return !sameState(before, viewport.*);
    }

    pub fn resize(viewport: *Viewport, visible_rows: u32) bool {
        const before = viewport.*;
        viewport.visible_rows = clampVisibleRows(visible_rows);
        viewport.scroll_offset = @min(viewport.scroll_offset, maxScrollOffset(viewport.total_rows, viewport.visible_rows));
        viewport.keepSelectionVisible();
        viewport.assertValid();
        return !sameState(before, viewport.*);
    }

    pub fn moveSelection(viewport: *Viewport, delta: i32) bool {
        const selected_index = viewport.selected_row orelse return false;
        const before = viewport.*;
        const last = viewport.total_rows - 1;
        viewport.selected_row = if (delta < 0)
            selected_index - @min(selected_index, negativeMagnitude(delta))
        else
            @min(last, selected_index + @min(last - selected_index, @as(u32, @intCast(delta))));
        viewport.keepSelectionVisible();
        viewport.assertValid();
        return !sameState(before, viewport.*);
    }

    pub fn scrollLines(viewport: *Viewport, delta: i32) bool {
        if (viewport.total_rows == 0) return false;
        const before = viewport.*;
        const max_scroll = maxScrollOffset(viewport.total_rows, viewport.visible_rows);
        if (delta < 0) {
            viewport.scroll_offset -= @min(viewport.scroll_offset, negativeMagnitude(delta));
        } else {
            const amount: u32 = @intCast(delta);
            viewport.scroll_offset = @min(max_scroll, viewport.scroll_offset + @min(max_scroll - viewport.scroll_offset, amount));
        }
        viewport.keepSelectionInsideVisibleRange();
        viewport.assertValid();
        return !sameState(before, viewport.*);
    }

    pub fn selectVisibleRow(viewport: *Viewport, visible_row: u32) bool {
        const result_index = viewport.resultAtVisibleRow(visible_row) orelse return false;
        if (viewport.selected_row == result_index) return false;
        viewport.selected_row = result_index;
        viewport.keepSelectionVisible();
        viewport.assertValid();
        return true;
    }

    pub fn resultAtVisibleRow(viewport: *const Viewport, visible_row: u32) ?u32 {
        const range = viewport.visibleRange();
        if (visible_row >= range.count) return null;
        const result_index = range.start + visible_row;
        std.debug.assert(result_index < viewport.total_rows);
        return result_index;
    }

    pub fn visibleRange(viewport: *const Viewport) VisibleRange {
        if (viewport.total_rows == 0) return .{ .start = 0, .count = 0 };
        const visible_rows = clampVisibleRows(viewport.visible_rows);
        const start = @min(viewport.scroll_offset, maxScrollOffset(viewport.total_rows, visible_rows));
        return .{
            .start = start,
            .count = @min(visible_rows, viewport.total_rows - start),
        };
    }

    pub fn selected(viewport: *const Viewport) ?u32 {
        return viewport.selected_row;
    }

    fn keepSelectionVisible(viewport: *Viewport) void {
        const selected_row = viewport.selected_row orelse return;
        const visible_rows = clampVisibleRows(viewport.visible_rows);
        viewport.scroll_offset = @min(viewport.scroll_offset, maxScrollOffset(viewport.total_rows, visible_rows));
        if (selected_row < viewport.scroll_offset) {
            viewport.scroll_offset = selected_row;
        } else if (selected_row >= viewport.scroll_offset + visible_rows) {
            viewport.scroll_offset = selected_row - visible_rows + 1;
        }
        viewport.scroll_offset = @min(viewport.scroll_offset, maxScrollOffset(viewport.total_rows, visible_rows));
    }

    fn keepSelectionInsideVisibleRange(viewport: *Viewport) void {
        if (viewport.selected_row == null) return;
        const range = viewport.visibleRange();
        if (range.count == 0) {
            viewport.selected_row = null;
            return;
        }
        const range_end = range.start + range.count - 1;
        const selected_row = viewport.selected_row.?;
        if (selected_row < range.start) {
            viewport.selected_row = range.start;
        } else if (selected_row > range_end) {
            viewport.selected_row = range_end;
        }
    }

    fn assertValid(viewport: *const Viewport) void {
        std.debug.assert(viewport.visible_rows >= 1);
        std.debug.assert(viewport.visible_rows <= max_visible_rows);
        std.debug.assert(viewport.scroll_offset <= maxScrollOffset(viewport.total_rows, viewport.visible_rows));
        if (viewport.total_rows == 0) {
            std.debug.assert(viewport.selected_row == null);
            std.debug.assert(viewport.scroll_offset == 0);
            return;
        }
        const selected_row = viewport.selected_row.?;
        std.debug.assert(selected_row < viewport.total_rows);
        const range = viewport.visibleRange();
        std.debug.assert(selected_row >= range.start);
        std.debug.assert(selected_row < range.start + range.count);
    }
};

pub fn visibleRowsForHeight(available_height: f32, row_height: f32, row_gap: f32) u32 {
    std.debug.assert(row_height > 0);
    std.debug.assert(row_gap >= 0);
    if (available_height <= row_height) return 1;

    var rows: u32 = 1;
    var used_height = row_height;
    while (rows < max_visible_rows and used_height + row_gap + row_height <= available_height) : (rows += 1) {
        used_height += row_gap + row_height;
    }
    return rows;
}

fn sameState(a: Viewport, b: Viewport) bool {
    return a.total_rows == b.total_rows and
        a.selected_row == b.selected_row and
        a.scroll_offset == b.scroll_offset and
        a.visible_rows == b.visible_rows;
}

fn clampVisibleRows(visible_rows: u32) u32 {
    return @max(1, @min(visible_rows, max_visible_rows));
}

fn maxScrollOffset(total_rows: u32, visible_rows_raw: u32) u32 {
    const visible_rows = clampVisibleRows(visible_rows_raw);
    return if (total_rows <= visible_rows) 0 else total_rows - visible_rows;
}

fn negativeMagnitude(delta: i32) u32 {
    std.debug.assert(delta < 0);
    return @as(u32, @intCast(-(delta + 1))) + 1;
}

test "empty viewport has no selected row and zero visible range" {
    const testing = std.testing;
    const viewport = Viewport.init();

    try testing.expectEqual(@as(?u32, null), viewport.selected());
    try testing.expectEqual(VisibleRange{ .start = 0, .count = 0 }, viewport.visibleRange());
    try testing.expectEqual(@as(?u32, null), viewport.resultAtVisibleRow(0));
}

test "reset results clamps selected and scroll offset" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(10));
    try testing.expect(viewport.resize(4));
    try testing.expect(viewport.moveSelection(9));
    try testing.expectEqual(@as(?u32, 9), viewport.selected());
    try testing.expectEqual(@as(u32, 6), viewport.scroll_offset);

    try testing.expect(viewport.resetResults(3));
    try testing.expectEqual(@as(?u32, 2), viewport.selected());
    try testing.expectEqual(@as(u32, 0), viewport.scroll_offset);

    try testing.expect(viewport.resetResults(0));
    try testing.expectEqual(@as(?u32, null), viewport.selected());
    try testing.expectEqual(@as(u32, 0), viewport.scroll_offset);

    try testing.expect(viewport.resetResults(5));
    try testing.expectEqual(@as(?u32, 0), viewport.selected());
    try testing.expectEqual(@as(u32, 0), viewport.scroll_offset);
}

test "keyboard movement keeps selected row visible" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(8));
    try testing.expect(viewport.resize(3));
    try testing.expect(viewport.moveSelection(3));
    try testing.expectEqual(@as(?u32, 3), viewport.selected());
    try testing.expectEqual(@as(u32, 1), viewport.scroll_offset);

    try testing.expect(viewport.moveSelection(-2));
    try testing.expectEqual(@as(?u32, 1), viewport.selected());
    try testing.expectEqual(@as(u32, 1), viewport.scroll_offset);

    try testing.expect(viewport.moveSelection(-1));
    try testing.expectEqual(@as(?u32, 0), viewport.selected());
    try testing.expectEqual(@as(u32, 0), viewport.scroll_offset);

    try testing.expect(!viewport.moveSelection(-1));
    try testing.expect(viewport.moveSelection(99));
    try testing.expectEqual(@as(?u32, 7), viewport.selected());
    try testing.expectEqual(@as(u32, 5), viewport.scroll_offset);
    try testing.expect(!viewport.moveSelection(1));
}

test "scroll lines clamps offset and preserves valid selection" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(12));
    try testing.expect(viewport.resize(4));
    try testing.expect(viewport.scrollLines(3));
    try testing.expectEqual(@as(u32, 3), viewport.scroll_offset);
    try testing.expectEqual(@as(?u32, 3), viewport.selected());

    try testing.expect(viewport.scrollLines(99));
    try testing.expectEqual(@as(u32, 8), viewport.scroll_offset);
    try testing.expectEqual(@as(?u32, 8), viewport.selected());

    try testing.expect(viewport.scrollLines(-99));
    try testing.expectEqual(@as(u32, 0), viewport.scroll_offset);
    try testing.expectEqual(@as(?u32, 3), viewport.selected());
}

test "visible row lookup rejects rows outside rendered range" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(6));
    try testing.expect(viewport.resize(3));
    try testing.expect(viewport.scrollLines(2));
    try testing.expectEqual(@as(?u32, 2), viewport.resultAtVisibleRow(0));
    try testing.expectEqual(@as(?u32, 4), viewport.resultAtVisibleRow(2));
    try testing.expectEqual(@as(?u32, null), viewport.resultAtVisibleRow(3));

    try testing.expect(viewport.resetResults(0));
    try testing.expectEqual(@as(?u32, null), viewport.resultAtVisibleRow(0));
}

test "select visible row maps through scroll offset and rejects invalid rows" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(10));
    try testing.expect(viewport.resize(3));
    try testing.expect(viewport.scrollLines(4));
    try testing.expectEqual(VisibleRange{ .start = 4, .count = 3 }, viewport.visibleRange());

    try testing.expect(viewport.selectVisibleRow(2));
    try testing.expectEqual(@as(?u32, 6), viewport.selected());
    try testing.expectEqual(@as(u32, 4), viewport.scroll_offset);

    try testing.expect(viewport.selectVisibleRow(0));
    try testing.expectEqual(@as(?u32, 4), viewport.selected());
    try testing.expectEqual(@as(u32, 4), viewport.scroll_offset);

    const before_rejected = viewport;
    try testing.expect(!viewport.selectVisibleRow(3));
    try testing.expect(sameState(before_rejected, viewport));
}

test "resize recalculates visible range without invalid state" {
    const testing = std.testing;
    var viewport = Viewport.init();

    try testing.expect(viewport.resetResults(10));
    try testing.expect(viewport.resize(0));
    try testing.expectEqual(@as(u32, 1), viewport.visible_rows);
    try testing.expectEqual(VisibleRange{ .start = 0, .count = 1 }, viewport.visibleRange());

    try testing.expect(viewport.moveSelection(9));
    try testing.expectEqual(@as(u32, 9), viewport.scroll_offset);
    try testing.expect(viewport.resize(5));
    try testing.expectEqual(@as(u32, 5), viewport.scroll_offset);
    try testing.expectEqual(VisibleRange{ .start = 5, .count = 5 }, viewport.visibleRange());

    try testing.expect(viewport.resize(2));
    try testing.expectEqual(@as(?u32, 9), viewport.selected());
    try testing.expectEqual(@as(u32, 8), viewport.scroll_offset);

    try testing.expectEqual(@as(u32, 1), visibleRowsForHeight(0, default_result_row_height, default_result_row_gap));
    try testing.expectEqual(@as(u32, 3), visibleRowsForHeight(144, default_result_row_height, default_result_row_gap));
}

test "passive scrollbar thumb is bounded" {
    const testing = std.testing;
    var viewport = Viewport.init();
    const track = Rect{ .x = 100, .y = 10, .w = 4, .h = 90 };

    try testing.expect(viewport.resetResults(3));
    try testing.expect(viewport.resize(4));
    try testing.expect(!Scrollbar.forViewport(&viewport, track).needed);

    try testing.expect(viewport.resetResults(12));
    const top_bar = Scrollbar.forViewport(&viewport, track);
    try testing.expect(top_bar.needed);
    try testing.expect(top_bar.thumb.y >= track.y);
    try testing.expect(top_bar.thumb.h <= track.h);
    try testing.expect(top_bar.thumb.y + top_bar.thumb.h <= track.y + track.h);

    try testing.expect(viewport.scrollLines(99));
    const bottom_bar = Scrollbar.forViewport(&viewport, track);
    try testing.expectApproxEqAbs(track.y + track.h, bottom_bar.thumb.y + bottom_bar.thumb.h, 0.001);
}

test "visible row point mapping rejects chrome gaps and scrollbar" {
    const testing = std.testing;
    const layout = ResultLayout{
        .result_top = 72,
        .row_x = 20,
        .row_width = 720,
        .row_height = 44,
        .row_gap = 6,
        .title_x = 34,
        .text_top_inset = 6,
        .subtitle_offset = 20,
        .icon_size = 28,
        .icon_right_inset = 14,
        .scrollbar_track = .{ .x = 746, .y = 72, .w = 4, .h = 194 },
        .visible_rows = 4,
    };

    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(30, 70));
    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(30, 118));
    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(746, 80));
    try testing.expectEqual(@as(?u32, 0), layout.visibleRowAtPoint(30, 80));
    try testing.expectEqual(@as(?u32, 2), layout.visibleRowAtPoint(30, 178));
}

test "default result layout preserves shell row geometry" {
    const testing = std.testing;
    const layout = ResultLayout.default(8);
    const first_row = layout.rowRect(0);
    const second_row = layout.rowRect(1);

    try testing.expectEqual(Rect{ .x = 20, .y = 66, .w = 720, .h = 44 }, first_row);
    try testing.expectEqual(@as(f32, 72), layout.titleY(0));
    try testing.expectEqual(@as(f32, 92), layout.subtitleY(0));
    try testing.expectEqual(@as(f32, 116), second_row.y);
    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(30, 112));
    try testing.expectEqual(@as(?u32, 1), layout.visibleRowAtPoint(30, 122));
}

test "default result layout places icon inside row hit area" {
    const testing = std.testing;
    const layout = ResultLayout.default(3);
    const icon = layout.iconRect(1);
    const row = layout.rowRect(1);

    try testing.expectEqual(@as(f32, 28), icon.w);
    try testing.expectEqual(@as(f32, 28), icon.h);
    try testing.expect(icon.x >= row.x);
    try testing.expect(icon.y >= row.y);
    try testing.expect(icon.x + icon.w <= row.x + row.w);
    try testing.expect(icon.y + icon.h <= row.y + row.h);
    try testing.expectEqual(@as(?u32, 1), layout.visibleRowAtPoint(icon.x + 1, icon.y + 1));
}
