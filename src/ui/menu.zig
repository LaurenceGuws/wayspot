//! Concrete vertical menu: one logical rectangle, row geometry and navigation.
//! Rows and action authority belong to the caller. Draw borrows one frame's
//! Canvas and label; the menu never retains text, protocol IDs or resources.
const std = @import("std");
const Canvas = @import("canvas.zig").Canvas;
const Rect = @import("canvas.zig").Rect;
const Painter = @import("text.zig").Painter;
const RowLayout = @import("row_layout.zig").RowLayout;

pub const Menu = struct {
    layout: RowLayout,
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
        std.debug.assert(bounds.w >= 28);
        return .{ .layout = RowLayout.init(bounds, row_height, 0) };
    }

    pub fn at(self: Menu, x: f32, y: f32) ?usize {
        return self.layout.at(x, y);
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
        const rows = self.layout.count();
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
        return if (index < self.layout.count()) index else null;
    }

    /// A single concrete row, not a retained widget object. The caller owns
    /// the row data and decides whether the resulting choice is actionable.
    pub fn drawRow(self: Menu, panel: Canvas, painter: *Painter, index: usize, item: Row) !void {
        const bounds = self.layout.row(index) orelse return error.MenuRowOutOfBounds;
        const row = try panel.child(bounds);
        try row.fill(if (self.hovered == index and item.enabled) .{ 56, 66, 83 } else .{ 30, 34, 44 });
        const label = try row.child(.{ .x = 8, .w = bounds.w - 28, .h = bounds.h });
        try label.text(painter, item.label, if (item.enabled) .{ 226, 231, 241 } else .{ 122, 129, 145 }, 2, 4);
        if (item.submenu) try row.text(painter, ">", .{ 185, 195, 215 }, @floatFromInt(bounds.w - 20), 4);
    }
};

test "menu row geometry and navigation share half-open bounds" {
    var menu = Menu.init(.{ .x = 398, .y = 42, .w = 306, .h = 27 * 12 }, 27);
    for (0..menu.layout.count()) |index| {
        const row = menu.layout.row(index).?;
        const top: f32 = @floatFromInt(menu.layout.bounds.y + row.y);
        try std.testing.expectEqual(@as(?usize, index), menu.at(398, top));
        try std.testing.expectEqual(@as(?usize, index), menu.at(703.75, top + 26.75));
        try std.testing.expect(menu.at(398, top - 0.25) != index);
        try std.testing.expect(menu.at(398, top + 27) != index);
        try std.testing.expect(menu.at(704, top) == null);
    }
    try std.testing.expectEqual(@as(?Rect, null), menu.layout.row(12));
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
