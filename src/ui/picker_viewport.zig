//! Picker viewport owns bounded result selection, scroll offset, visible range, and row hit testing.

const std = @import("std");

pub const max_visible_rows: u32 = 64;
pub const min_scrollbar_thumb_height: f32 = 12;

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

pub const ResultLayout = struct {
    result_top: f32,
    row_x: f32,
    row_width: f32,
    row_height: f32,
    row_gap: f32,
    status_x: f32,
    scrollbar_track: Rect,
    visible_rows: u32,

    pub fn rowRect(self: ResultLayout, visible_row: u32) Rect {
        std.debug.assert(visible_row < self.visible_rows);
        const row_step = self.row_height + self.row_gap;
        const y = self.result_top + row_step * @as(f32, @floatFromInt(visible_row));
        return .{ .x = self.row_x, .y = y, .w = self.row_width, .h = self.row_height };
    }

    pub fn visibleRowAtPoint(self: ResultLayout, x: f32, y: f32) ?u32 {
        if (x < self.row_x or x >= self.row_x + self.row_width) return null;
        if (y < self.result_top) return null;

        const row_step = self.row_height + self.row_gap;
        if (row_step <= 0) return null;

        var row: u32 = 0;
        var top = self.result_top;
        while (row < self.visible_rows) : (row += 1) {
            if (y >= top and y < top + self.row_height) return row;
            if (y < top + row_step) return null;
            top += row_step;
        }
        return null;
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

    pub fn resetResults(self: *Viewport, total_rows: u32) bool {
        const before = self.*;
        self.total_rows = total_rows;
        self.visible_rows = clampVisibleRows(self.visible_rows);
        if (total_rows == 0) {
            self.selected_row = null;
            self.scroll_offset = 0;
            return !sameState(before, self.*);
        }

        const selected_index = self.selected_row orelse 0;
        self.selected_row = @min(selected_index, total_rows - 1);
        self.scroll_offset = @min(self.scroll_offset, maxScrollOffset(self.total_rows, self.visible_rows));
        self.keepSelectionVisible();
        self.assertValid();
        return !sameState(before, self.*);
    }

    pub fn resize(self: *Viewport, visible_rows: u32) bool {
        const before = self.*;
        self.visible_rows = clampVisibleRows(visible_rows);
        self.scroll_offset = @min(self.scroll_offset, maxScrollOffset(self.total_rows, self.visible_rows));
        self.keepSelectionVisible();
        self.assertValid();
        return !sameState(before, self.*);
    }

    pub fn moveSelection(self: *Viewport, delta: i32) bool {
        const selected_index = self.selected_row orelse return false;
        const before = self.*;
        const last = self.total_rows - 1;
        self.selected_row = if (delta < 0)
            selected_index - @min(selected_index, negativeMagnitude(delta))
        else
            @min(last, selected_index + @min(last - selected_index, @as(u32, @intCast(delta))));
        self.keepSelectionVisible();
        self.assertValid();
        return !sameState(before, self.*);
    }

    pub fn scrollLines(self: *Viewport, delta: i32) bool {
        if (self.total_rows == 0) return false;
        const before = self.*;
        const max_scroll = maxScrollOffset(self.total_rows, self.visible_rows);
        if (delta < 0) {
            self.scroll_offset -= @min(self.scroll_offset, negativeMagnitude(delta));
        } else {
            const amount: u32 = @intCast(delta);
            self.scroll_offset = @min(max_scroll, self.scroll_offset + @min(max_scroll - self.scroll_offset, amount));
        }
        self.keepSelectionInsideVisibleRange();
        self.assertValid();
        return !sameState(before, self.*);
    }

    pub fn selectVisibleRow(self: *Viewport, visible_row: u32) bool {
        const result_index = self.resultAtVisibleRow(visible_row) orelse return false;
        if (self.selected_row == result_index) return false;
        self.selected_row = result_index;
        self.keepSelectionVisible();
        self.assertValid();
        return true;
    }

    pub fn resultAtVisibleRow(self: *const Viewport, visible_row: u32) ?u32 {
        const range = self.visibleRange();
        if (visible_row >= range.count) return null;
        const result_index = range.start + visible_row;
        std.debug.assert(result_index < self.total_rows);
        return result_index;
    }

    pub fn visibleRange(self: *const Viewport) VisibleRange {
        if (self.total_rows == 0) return .{ .start = 0, .count = 0 };
        const visible_rows = clampVisibleRows(self.visible_rows);
        const start = @min(self.scroll_offset, maxScrollOffset(self.total_rows, visible_rows));
        return .{
            .start = start,
            .count = @min(visible_rows, self.total_rows - start),
        };
    }

    pub fn selected(self: *const Viewport) ?u32 {
        return self.selected_row;
    }

    fn keepSelectionVisible(self: *Viewport) void {
        const selected_row = self.selected_row orelse return;
        const visible_rows = clampVisibleRows(self.visible_rows);
        self.scroll_offset = @min(self.scroll_offset, maxScrollOffset(self.total_rows, visible_rows));
        if (selected_row < self.scroll_offset) {
            self.scroll_offset = selected_row;
        } else if (selected_row >= self.scroll_offset + visible_rows) {
            self.scroll_offset = selected_row - visible_rows + 1;
        }
        self.scroll_offset = @min(self.scroll_offset, maxScrollOffset(self.total_rows, visible_rows));
    }

    fn keepSelectionInsideVisibleRange(self: *Viewport) void {
        if (self.selected_row == null) return;
        const range = self.visibleRange();
        if (range.count == 0) {
            self.selected_row = null;
            return;
        }
        const range_end = range.start + range.count - 1;
        const selected_row = self.selected_row.?;
        if (selected_row < range.start) {
            self.selected_row = range.start;
        } else if (selected_row > range_end) {
            self.selected_row = range_end;
        }
    }

    fn assertValid(self: *const Viewport) void {
        std.debug.assert(self.visible_rows >= 1);
        std.debug.assert(self.visible_rows <= max_visible_rows);
        std.debug.assert(self.scroll_offset <= maxScrollOffset(self.total_rows, self.visible_rows));
        if (self.total_rows == 0) {
            std.debug.assert(self.selected_row == null);
            std.debug.assert(self.scroll_offset == 0);
            return;
        }
        const selected_row = self.selected_row.?;
        std.debug.assert(selected_row < self.total_rows);
        const range = self.visibleRange();
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

    try testing.expectEqual(@as(u32, 1), visibleRowsForHeight(0, 44, 6));
    try testing.expectEqual(@as(u32, 3), visibleRowsForHeight(144, 44, 6));
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
        .status_x = 662,
        .scrollbar_track = .{ .x = 746, .y = 72, .w = 4, .h = 194 },
        .visible_rows = 4,
    };

    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(30, 70));
    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(30, 118));
    try testing.expectEqual(@as(?u32, null), layout.visibleRowAtPoint(746, 80));
    try testing.expectEqual(@as(?u32, 0), layout.visibleRowAtPoint(30, 80));
    try testing.expectEqual(@as(?u32, 2), layout.visibleRowAtPoint(30, 178));
}
