//! Cursor blink timing for callers that own rendering and input events.

const std = @import("std");

/// The default blink period, in monotonic milliseconds.
pub const cursor_blink_interval_ms: u64 = 530;

comptime {
    std.debug.assert(cursor_blink_interval_ms > 0);
}

/// CursorBlink tracks visibility and the next toggle deadline.
pub const CursorBlink = struct {
    visible: bool,
    next_toggle_ms: u64,
    interval_ms: u64,

    /// Starts visible and schedules the first toggle after `interval_ms`.
    pub fn init(now_ms: u64, interval_ms: u64) CursorBlink {
        std.debug.assert(interval_ms > 0);
        return .{
            .visible = true,
            .next_toggle_ms = now_ms + interval_ms,
            .interval_ms = interval_ms,
        };
    }

    /// Shows the cursor and restarts the deadline from caller time.
    pub fn reset(self: *CursorBlink, now_ms: u64) void {
        self.visible = true;
        self.next_toggle_ms = now_ms + self.interval_ms;
    }

    /// Advances through elapsed toggle deadlines and reports visibility changes.
    pub fn advance(self: *CursorBlink, now_ms: u64) bool {
        if (now_ms < self.next_toggle_ms) return false;
        const was_visible = self.visible;
        const toggles: u64 = ((now_ms - self.next_toggle_ms) / self.interval_ms) + 1;
        if ((toggles & 1) == 1) self.visible = !self.visible;
        self.next_toggle_ms += toggles * self.interval_ms;
        return self.visible != was_visible;
    }

    /// Returns the bounded millisecond wait until the next toggle deadline.
    pub fn waitTimeoutMs(self: *const CursorBlink, now_ms: u64) i32 {
        if (now_ms >= self.next_toggle_ms) return 0;
        const remaining = self.next_toggle_ms - now_ms;
        return @intCast(@min(remaining, @as(u64, @intCast(std.math.maxInt(i32)))));
    }
};

test "cursor advances only at its deadline" {
    var cursor = CursorBlink.init(100, cursor_blink_interval_ms);

    try std.testing.expect(cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(100));
    try std.testing.expect(!cursor.advance(629));
    try std.testing.expect(cursor.visible);
    try std.testing.expect(cursor.advance(630));
    try std.testing.expect(!cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(630));
}

test "cursor reset shows cursor and restarts deadline" {
    var cursor = CursorBlink.init(0, cursor_blink_interval_ms);

    try std.testing.expect(cursor.advance(530));
    try std.testing.expect(!cursor.visible);
    cursor.reset(900);
    try std.testing.expect(cursor.visible);
    try std.testing.expectEqual(@as(i32, 530), cursor.waitTimeoutMs(900));
    try std.testing.expect(!cursor.advance(1429));
    try std.testing.expect(cursor.advance(1430));
    try std.testing.expect(!cursor.visible);
}
