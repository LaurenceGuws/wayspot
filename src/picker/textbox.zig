//! Textbox owns bounded single-line UTF-8 editing without rendering or SDL events.

const std = @import("std");

/// Result of a bounded edit against textbox-owned storage.
pub const EditResult = enum {
    no_change,
    changed,
    overflow,
    invalid_utf8,
};

/// SelectionRange is a normalized byte range inside a textbox.
pub const SelectionRange = struct {
    start: u32,
    end: u32,
};

/// Movement names the cursor moves supported by a single-line textbox.
pub const Movement = enum {
    left,
    right,
    home,
    end,
};

/// Returns the byte offset of the UTF-8 scalar that ends at the slice end.
pub fn previousUtf8Start(text: []const u8) @TypeOf(text.len) {
    if (text.len == 0) return 0;
    var index = text.len - 1;
    while (index > 0 and isUtf8Continuation(text[index])) : (index -= 1) {}
    return index;
}

/// Returns the byte offset after the UTF-8 scalar that starts at `offset`.
pub fn nextUtf8End(text: []const u8, offset: u32) u32 {
    if (offset >= text.len) return @intCast(text.len);
    const width = utf8ScalarWidth(text[offset]) orelse return offset;
    const end = offset + width;
    if (end > text.len) return @intCast(text.len);
    return end;
}

/// Counts UTF-8 scalars in valid text.
pub fn scalarCount(text: []const u8) u32 {
    var count: u32 = 0;
    var offset: u32 = 0;
    while (offset < text.len) {
        offset = nextUtf8End(text, offset);
        count += 1;
    }
    return count;
}

/// Maps a scalar index to a UTF-8 byte offset, clamping to the text end.
pub fn byteOffsetForScalarIndex(text: []const u8, scalar_index: u32) u32 {
    var count: u32 = 0;
    var offset: u32 = 0;
    while (offset < text.len and count < scalar_index) : (count += 1) {
        offset = nextUtf8End(text, offset);
    }
    return offset;
}

/// Maps a valid UTF-8 byte offset to its scalar boundary index.
pub fn scalarIndexForByteOffset(text: []const u8, byte_offset: u32) u32 {
    const clamped = @min(byte_offset, @as(u32, @intCast(text.len)));
    var count: u32 = 0;
    var offset: u32 = 0;
    while (offset < clamped) : (count += 1) {
        offset = nextUtf8End(text, offset);
    }
    return count;
}

/// Maps a UTF-8 byte offset to the deterministic x boundary used by mouse editing.
pub fn xForByteOffset(text: []const u8, left: f32, right: f32, byte_offset: u32) f32 {
    if (right <= left) return left;
    const count = scalarCount(text);
    const index = scalarIndexForByteOffset(text, byte_offset);
    if (index >= count) return right;
    const width = right - left;
    return left + (width * (@as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(count + 1))));
}

/// Maps a mouse x coordinate inside caller-owned bounds to a scalar boundary.
pub fn byteOffsetForMouseX(text: []const u8, left: f32, right: f32, x: f32) u32 {
    const count = scalarCount(text);
    if (right <= left or x <= left) return 0;
    if (x >= right) return @intCast(text.len);
    const width = right - left;
    const raw_index = @floor(((x - left) / width) * @as(f32, @floatFromInt(count + 1)));
    const scalar_index: u32 = @intFromFloat(@min(@as(f32, @floatFromInt(count)), @max(0, raw_index)));
    return byteOffsetForScalarIndex(text, scalar_index);
}

/// Bounded single-line textbox storage for one product-owned text field.
pub fn Textbox(comptime max_bytes: u32) type {
    std.debug.assert(max_bytes > 0);
    return struct {
        const Self = @This();

        buf: [max_bytes]u8 = undefined,
        len: u32 = 0,
        cursor: u32 = 0,
        selection_anchor: ?u32 = null,

        /// Replaces the buffer when valid UTF-8 fits, otherwise leaves it unchanged.
        pub fn replace(self: *Self, text: []const u8) EditResult {
            if (!validUtf8(text)) return .invalid_utf8;
            if (text.len > max_bytes) return .overflow;
            if (std.mem.eql(u8, self.slice(), text) and self.selectionRange() == null and self.cursor == self.len) return .no_change;
            @memcpy(self.buf[0..text.len], text);
            self.len = @intCast(text.len);
            self.cursor = self.len;
            self.selection_anchor = null;
            return .changed;
        }

        /// Inserts valid UTF-8 at the cursor or replaces the current selection.
        pub fn insertText(self: *Self, text: []const u8) EditResult {
            self.normalizeCursor();
            if (text.len == 0) return .no_change;
            if (!validUtf8(text)) return .invalid_utf8;
            const range = self.selectionRange() orelse SelectionRange{ .start = self.cursor, .end = self.cursor };
            const removed = range.end - range.start;
            const new_len = self.len - removed + @as(u32, @intCast(text.len));
            if (new_len > max_bytes) return .overflow;

            const suffix_len = self.len - range.end;
            if (suffix_len > 0) {
                std.mem.copyBackwards(u8, self.buf[range.start + @as(u32, @intCast(text.len)) .. new_len], self.buf[range.end..self.len]);
            }
            @memcpy(self.buf[range.start .. range.start + @as(u32, @intCast(text.len))], text);
            self.len = new_len;
            self.cursor = range.start + @as(u32, @intCast(text.len));
            self.selection_anchor = null;
            return .changed;
        }

        /// Clears the current text and reports whether bytes or selection were removed.
        pub fn clear(self: *Self) EditResult {
            if (self.len == 0 and self.selection_anchor == null and self.cursor == 0) return .no_change;
            self.len = 0;
            self.cursor = 0;
            self.selection_anchor = null;
            return .changed;
        }

        /// Removes the selection or one UTF-8 scalar before the cursor.
        pub fn backspace(self: *Self) EditResult {
            self.normalizeCursor();
            if (self.deleteSelection()) |result| return result;
            if (self.cursor == 0) return .no_change;
            const start: u32 = @intCast(previousUtf8Start(self.buf[0..self.cursor]));
            return self.deleteRange(.{ .start = start, .end = self.cursor });
        }

        /// Removes the selection or one UTF-8 scalar after the cursor.
        pub fn deleteForward(self: *Self) EditResult {
            self.normalizeCursor();
            if (self.deleteSelection()) |result| return result;
            if (self.cursor >= self.len) return .no_change;
            return self.deleteRange(.{ .start = self.cursor, .end = nextUtf8End(self.slice(), self.cursor) });
        }

        /// Moves the cursor one scalar left, optionally extending selection.
        pub fn moveLeft(self: *Self, extend: bool) EditResult {
            if (!extend) {
                if (self.selectionRange()) |range| {
                    self.cursor = range.start;
                    self.selection_anchor = null;
                    return .changed;
                }
            }
            return self.moveCursor(@intCast(previousUtf8Start(self.buf[0..self.cursor])), extend);
        }

        /// Moves the cursor one scalar right, optionally extending selection.
        pub fn moveRight(self: *Self, extend: bool) EditResult {
            if (!extend) {
                if (self.selectionRange()) |range| {
                    self.cursor = range.end;
                    self.selection_anchor = null;
                    return .changed;
                }
            }
            return self.moveCursor(nextUtf8End(self.slice(), self.cursor), extend);
        }

        /// Moves the cursor to the start, optionally extending selection.
        pub fn moveHome(self: *Self, extend: bool) EditResult {
            return self.moveCursor(0, extend);
        }

        /// Moves the cursor to the end, optionally extending selection.
        pub fn moveEnd(self: *Self, extend: bool) EditResult {
            return self.moveCursor(self.len, extend);
        }

        /// Selects all text when non-empty.
        pub fn selectAll(self: *Self) EditResult {
            if (self.len == 0) {
                self.cursor = 0;
                self.selection_anchor = null;
                return .no_change;
            }
            if (self.cursor == self.len and self.selection_anchor != null and self.selection_anchor.? == 0) return .no_change;
            self.selection_anchor = 0;
            self.cursor = self.len;
            return .changed;
        }

        /// Clears selection without moving the cursor.
        pub fn clearSelection(self: *Self) EditResult {
            if (self.selection_anchor == null) return .no_change;
            self.selection_anchor = null;
            return .changed;
        }

        /// Reports whether a non-empty byte range is selected.
        pub fn hasSelection(self: *const Self) bool {
            return self.selectionRange() != null;
        }

        /// Returns the selected byte range when selection is non-empty.
        pub fn selectedText(self: *const Self) ?[]const u8 {
            const range = self.selectionRange() orelse return null;
            return self.buf[range.start..range.end];
        }

        /// Removes and returns whether a selected byte range was cut.
        pub fn cutSelection(self: *Self) EditResult {
            return self.deleteSelection() orelse .no_change;
        }

        /// Places the cursor at a valid UTF-8 byte offset and clears selection.
        pub fn setCursorFromByteOffset(self: *Self, offset: u32) EditResult {
            if (!self.validBoundary(offset)) return .no_change;
            return self.moveCursor(offset, false);
        }

        /// Selects from an anchor byte offset to another valid byte offset.
        pub fn selectToByteOffset(self: *Self, anchor: u32, offset: u32) EditResult {
            if (!self.validBoundary(anchor) or !self.validBoundary(offset)) return .no_change;
            const before_cursor = self.cursor;
            const before_anchor = self.selection_anchor;
            self.selection_anchor = anchor;
            self.cursor = offset;
            if (self.cursor == self.selection_anchor.?) self.selection_anchor = null;
            if (before_cursor == self.cursor and before_anchor == self.selection_anchor) return .no_change;
            return .changed;
        }

        /// Returns the current cursor byte offset.
        pub fn cursorOffset(self: *const Self) u32 {
            return self.cursor;
        }

        /// Returns the normalized selected byte range when non-empty.
        pub fn selectionRange(self: *const Self) ?SelectionRange {
            const anchor = self.selection_anchor orelse return null;
            if (anchor == self.cursor) return null;
            return if (anchor < self.cursor)
                .{ .start = anchor, .end = self.cursor }
            else
                .{ .start = self.cursor, .end = anchor };
        }

        /// Returns the immutable text currently stored by this textbox.
        pub fn slice(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }

        fn moveCursor(self: *Self, offset: u32, extend: bool) EditResult {
            if (!self.validBoundary(offset)) return .no_change;
            const before_cursor = self.cursor;
            const before_anchor = self.selection_anchor;
            if (extend) {
                if (self.selection_anchor == null) self.selection_anchor = self.cursor;
            } else {
                self.selection_anchor = null;
            }
            self.cursor = offset;
            if (self.selection_anchor) |anchor| {
                if (anchor == self.cursor) self.selection_anchor = null;
            }
            if (before_cursor == self.cursor and before_anchor == self.selection_anchor) return .no_change;
            return .changed;
        }

        fn deleteSelection(self: *Self) ?EditResult {
            const range = self.selectionRange() orelse return null;
            return self.deleteRange(range);
        }

        fn deleteRange(self: *Self, range: SelectionRange) EditResult {
            std.debug.assert(range.start <= range.end);
            std.debug.assert(range.end <= self.len);
            if (range.start == range.end) return .no_change;
            const suffix_len = self.len - range.end;
            if (suffix_len > 0) {
                std.mem.copyForwards(u8, self.buf[range.start .. range.start + suffix_len], self.buf[range.end..self.len]);
            }
            self.len -= range.end - range.start;
            self.cursor = range.start;
            self.selection_anchor = null;
            return .changed;
        }

        fn validBoundary(self: *const Self, offset: u32) bool {
            if (offset > self.len) return false;
            if (offset == self.len) return true;
            return !isUtf8Continuation(self.buf[offset]);
        }

        fn normalizeCursor(self: *Self) void {
            if (self.cursor > self.len) self.cursor = self.len;
            if (self.selection_anchor) |anchor| {
                if (anchor > self.len) self.selection_anchor = null;
            }
        }
    };
}

fn isUtf8Continuation(byte: u8) bool {
    return (byte & 0b1100_0000) == 0b1000_0000;
}

fn utf8ScalarWidth(byte: u8) ?u32 {
    if (byte < 0x80) return 1;
    if ((byte & 0b1110_0000) == 0b1100_0000) return 2;
    if ((byte & 0b1111_0000) == 0b1110_0000) return 3;
    if ((byte & 0b1111_1000) == 0b1111_0000) return 4;
    return null;
}

fn validUtf8(text: []const u8) bool {
    var offset: u32 = 0;
    while (offset < text.len) {
        const first = text[offset];
        const width = utf8ScalarWidth(first) orelse return false;
        const end = offset + width;
        if (end > text.len) return false;
        if (width == 1) {
            offset = end;
            continue;
        }
        var index = offset + 1;
        while (index < end) : (index += 1) {
            if (!isUtf8Continuation(text[index])) return false;
        }
        if (width == 2 and first < 0xc2) return false;
        if (width == 3 and first == 0xe0 and text[offset + 1] < 0xa0) return false;
        if (width == 3 and first == 0xed and text[offset + 1] >= 0xa0) return false;
        if (width == 4 and first == 0xf0 and text[offset + 1] < 0x90) return false;
        if (width == 4 and first == 0xf4 and text[offset + 1] >= 0x90) return false;
        if (width == 4 and first > 0xf4) return false;
        offset = end;
    }
    return true;
}

test "empty state" {
    var box = Textbox(8){};
    try std.testing.expectEqualStrings("", box.slice());
    try std.testing.expectEqual(@as(u32, 0), box.cursorOffset());
}

test "seed and replace" {
    var box = Textbox(8){};
    try std.testing.expectEqual(EditResult.changed, box.replace("abc"));
    try std.testing.expectEqualStrings("abc", box.slice());
    try std.testing.expectEqual(@as(u32, 3), box.cursorOffset());
    try std.testing.expectEqual(EditResult.no_change, box.replace("abc"));
    try std.testing.expectEqual(EditResult.changed, box.replace("de"));
    try std.testing.expectEqualStrings("de", box.slice());
}

test "insert at cursor and replace selection" {
    var box = Textbox(16){};
    try std.testing.expectEqual(EditResult.changed, box.insertText("abc"));
    try std.testing.expectEqual(EditResult.changed, box.moveLeft(false));
    try std.testing.expectEqual(EditResult.changed, box.moveLeft(false));
    try std.testing.expectEqual(EditResult.changed, box.insertText("X"));
    try std.testing.expectEqualStrings("aXbc", box.slice());
    try std.testing.expectEqual(@as(u32, 2), box.cursorOffset());

    try std.testing.expectEqual(EditResult.changed, box.selectToByteOffset(1, 3));
    try std.testing.expectEqual(EditResult.changed, box.insertText("YY"));
    try std.testing.expectEqualStrings("aYYc", box.slice());
}

test "overflow and invalid UTF-8 leave text cursor and selection unchanged" {
    var box = Textbox(5){};
    try std.testing.expectEqual(EditResult.changed, box.replace("abcd"));
    try std.testing.expectEqual(EditResult.changed, box.moveLeft(true));
    const cursor = box.cursorOffset();
    const selected = box.selectionRange().?;
    try std.testing.expectEqual(EditResult.overflow, box.insertText("efgh"));
    try std.testing.expectEqualStrings("abcd", box.slice());
    try std.testing.expectEqual(cursor, box.cursorOffset());
    try std.testing.expectEqual(selected, box.selectionRange().?);
    try std.testing.expectEqual(EditResult.invalid_utf8, box.insertText(&.{0x80}));
    try std.testing.expectEqualStrings("abcd", box.slice());
}

test "clear" {
    var box = Textbox(8){};
    try std.testing.expectEqual(EditResult.changed, box.insertText("abc"));
    try std.testing.expectEqual(EditResult.changed, box.clear());
    try std.testing.expectEqualStrings("", box.slice());
    try std.testing.expectEqual(EditResult.no_change, box.clear());
}

test "UTF-8 scalar movement backspace and delete" {
    var box = Textbox(32){};
    try std.testing.expectEqual(EditResult.changed, box.insertText("ab"));
    try std.testing.expectEqual(EditResult.changed, box.insertText("é"));
    try std.testing.expectEqual(EditResult.changed, box.insertText("🙂"));
    try std.testing.expectEqual(EditResult.changed, box.moveLeft(false));
    try std.testing.expectEqual(@as(u32, 4), box.cursorOffset());
    try std.testing.expectEqual(EditResult.changed, box.backspace());
    try std.testing.expectEqualStrings("ab🙂", box.slice());
    try std.testing.expectEqual(EditResult.changed, box.deleteForward());
    try std.testing.expectEqualStrings("ab", box.slice());
}

test "home end and shift selection ranges" {
    var box = Textbox(16){};
    try std.testing.expectEqual(EditResult.changed, box.replace("abcd"));
    try std.testing.expectEqual(EditResult.changed, box.moveHome(true));
    try std.testing.expectEqual(SelectionRange{ .start = 0, .end = 4 }, box.selectionRange().?);
    try std.testing.expectEqual(EditResult.changed, box.moveRight(false));
    try std.testing.expect(box.selectionRange() == null);
    try std.testing.expectEqual(@as(u32, 4), box.cursorOffset());
    try std.testing.expectEqual(EditResult.changed, box.moveHome(true));
    try std.testing.expectEqual(SelectionRange{ .start = 0, .end = 4 }, box.selectionRange().?);
}

test "selected text and cut selection return exact bytes" {
    var box = Textbox(16){};
    try std.testing.expectEqual(EditResult.changed, box.replace("abécd"));
    try std.testing.expectEqual(EditResult.changed, box.selectToByteOffset(1, 4));
    try std.testing.expectEqualStrings("bé", box.selectedText().?);
    try std.testing.expectEqual(EditResult.changed, box.cutSelection());
    try std.testing.expectEqualStrings("acd", box.slice());
    try std.testing.expect(box.selectedText() == null);
}

test "mouse scalar mapping clamps and keeps UTF-8 boundaries" {
    const text = "aé🙂z";
    try std.testing.expectEqual(@as(u32, 0), byteOffsetForMouseX(text, 10, 50, 0));
    try std.testing.expectEqual(@as(u32, 0), byteOffsetForMouseX(text, 10, 50, 10));
    try std.testing.expectEqual(@as(u32, 3), byteOffsetForMouseX(text, 10, 50, 26));
    try std.testing.expectEqual(@as(u32, @intCast(text.len)), byteOffsetForMouseX(text, 10, 50, 50));
    try std.testing.expectEqual(@as(u32, @intCast(text.len)), byteOffsetForMouseX(text, 10, 50, 90));
    try std.testing.expectEqual(@as(u32, 2), scalarIndexForByteOffset(text, 3));
    try std.testing.expectEqual(@as(f32, 10), xForByteOffset(text, 10, 50, 0));
    try std.testing.expectEqual(@as(f32, 50), xForByteOffset(text, 10, 50, @intCast(text.len)));
}
