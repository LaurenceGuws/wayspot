//! Concrete vertical menu: one logical rectangle, row geometry and navigation.
//! Rows and action authority belong to the caller. Draw borrows one frame's
//! Canvas and label; the menu never retains text, protocol IDs or resources.
const std = @import("std");
const Canvas = @import("canvas.zig").Canvas;
const Rect = @import("canvas.zig").Rect;
const Painter = @import("text.zig").Painter;

pub const Menu = struct {
    bounds: Rect,
    row_height: u16,
    hovered: ?usize = null,

    pub const Direction = enum { up, down };
    pub const Row = struct {
        label: []const u8,
        enabled: bool = true,
        submenu: bool = false,
    };

    /// Fixed logical menu geometry, including the existing label/arrow space.
    /// Zero rows are valid; the caller bounds row count before construction.
    pub fn init(bounds: Rect, row_height: u16) Menu {
        std.debug.assert(row_height > 0 and bounds.w >= 28 and bounds.h >= 0);
        std.debug.assert(@rem(bounds.h, @as(i32, row_height)) == 0);
        std.debug.assert(@as(i64, bounds.x) + bounds.w <= std.math.maxInt(i32));
        std.debug.assert(@as(i64, bounds.y) + bounds.h <= std.math.maxInt(i32));
        return .{ .bounds = bounds, .row_height = row_height };
    }

    pub fn count(self: Menu) usize {
        return @intCast(@divExact(self.bounds.h, @as(i32, self.row_height)));
    }

    /// Row-local drawing and hit geometry both derive from the same height.
    pub fn rowBounds(self: Menu, index: usize) ?Rect {
        if (index >= self.count()) return null;
        return .{ .y = @as(i32, @intCast(index)) * self.row_height, .w = self.bounds.w, .h = self.row_height };
    }

    pub fn at(self: Menu, x: f32, y: f32) ?usize {
        if (!self.bounds.contains(x, y)) return null;
        const index: usize = @intFromFloat((y - @as(f32, @floatFromInt(self.bounds.y))) / @as(f32, @floatFromInt(self.row_height)));
        return if (index < self.count()) index else null;
    }

    /// Only a changed pointer target needs a redraw.
    pub fn hover(self: *Menu, x: f32, y: f32) bool {
        const next = self.at(x, y);
        if (next == self.hovered) return false;
        self.hovered = next;
        return true;
    }

    /// Preserve non-wrapping navigation, including disabled rows. Activation
    /// is a candidate row index; the application checks its authoritative row.
    pub fn move(self: *Menu, direction: Direction) bool {
        const rows = self.count();
        if (rows == 0) return false;
        self.hovered = if (self.hovered) |current|
            switch (direction) {
                .up => current -| 1,
                .down => @min(rows - 1, current +| 1),
            }
        else if (direction == .up) rows - 1 else 0;
        return true;
    }

    pub fn selected(self: Menu) ?usize {
        const index = self.hovered orelse 0;
        return if (index < self.count()) index else null;
    }

    /// A single concrete row, not a retained widget object. The caller owns
    /// the row data and decides whether the resulting choice is actionable.
    pub fn drawRow(self: Menu, panel: Canvas, painter: *Painter, index: usize, item: Row) !void {
        const bounds = self.rowBounds(index) orelse return error.MenuRowOutOfBounds;
        const row = try panel.child(bounds);
        try row.fill(if (self.hovered == index and item.enabled) .{ 56, 66, 83 } else .{ 30, 34, 44 });
        const label = try row.child(.{ .x = 8, .w = bounds.w - 28, .h = bounds.h });
        try label.text(painter, item.label, if (item.enabled) .{ 226, 231, 241 } else .{ 122, 129, 145 }, 2, 4);
        if (item.submenu) try row.text(painter, ">", .{ 185, 195, 215 }, bounds.w - 20, 4);
    }
};

test "menu row geometry and navigation share half-open bounds" {
    var menu = Menu.init(.{ .x = 398, .y = 42, .w = 306, .h = 27 * 12 }, 27);
    for (0..menu.count()) |index| {
        const row = menu.rowBounds(index).?;
        const top: f32 = @floatFromInt(menu.bounds.y + row.y);
        try std.testing.expectEqual(@as(?usize, index), menu.at(398, top));
        try std.testing.expectEqual(@as(?usize, index), menu.at(703.75, top + 26.75));
        try std.testing.expect(menu.at(398, top - 0.25) != index);
        try std.testing.expect(menu.at(398, top + 27) != index);
        try std.testing.expect(menu.at(704, top) == null);
    }
    try std.testing.expectEqual(@as(?Rect, null), menu.rowBounds(12));
    try std.testing.expectEqual(@as(?usize, null), menu.at(398, std.math.nan(f32)));
    try std.testing.expectEqual(@as(?usize, null), menu.at(398, std.math.inf(f32)));
    try std.testing.expectEqual(@as(?usize, 0), menu.selected());
    try std.testing.expect(menu.move(.up));
    try std.testing.expectEqual(@as(?usize, 11), menu.selected());
    try std.testing.expect(menu.move(.down));
    try std.testing.expectEqual(@as(?usize, 11), menu.selected());
    try std.testing.expect(menu.hover(420, 42));
    try std.testing.expect(!menu.hover(420, 42));
    try std.testing.expect(menu.move(.up));
    try std.testing.expectEqual(@as(?usize, 0), menu.selected());
    try std.testing.expect(menu.hover(300, 42));
    try std.testing.expectEqual(@as(?usize, null), menu.hovered);
    try std.testing.expectEqual(@as(?usize, 0), menu.selected());
    menu = Menu.init(.{ .w = 306, .h = 0 }, 27);
    try std.testing.expect(!menu.move(.down));
    try std.testing.expectEqual(@as(?usize, null), menu.selected());
    try std.testing.expectEqual(@as(?usize, null), menu.at(0, 0));
}
