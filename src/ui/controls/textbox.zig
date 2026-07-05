//! Single-line append-at-end textbox mechanics without rendering or input events.

const std = @import("std");

/// Result of an edit against caller-owned text storage.
pub const EditResult = enum {
    no_change,
    changed,
    overflow,
};

/// Returns the byte offset of the UTF-8 scalar that ends at the slice end.
pub fn previousUtf8Start(text: []const u8) @TypeOf(text.len) {
    if (text.len == 0) return 0;
    var index = text.len - 1;
    while (index > 0 and (text[index] & 0b1100_0000) == 0b1000_0000) : (index -= 1) {}
    return index;
}

/// Appends text to an unbounded caller-owned byte list.
pub fn appendArrayList(list: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !EditResult {
    if (text.len == 0) return .no_change;
    try list.appendSlice(allocator, text);
    return .changed;
}

/// Removes one UTF-8 scalar from an unbounded caller-owned byte list.
pub fn backspaceArrayList(list: *std.ArrayList(u8)) EditResult {
    if (list.items.len == 0) return .no_change;
    list.shrinkRetainingCapacity(previousUtf8Start(list.items));
    return .changed;
}

/// Bounded append-only textbox storage for callers that already have a byte cap.
pub fn Textbox(comptime max_bytes: u32) type {
    std.debug.assert(max_bytes > 0);
    return struct {
        const Self = @This();

        buf: [max_bytes]u8 = undefined,
        len: u32 = 0,

        /// Replaces the buffer when `text` fits, otherwise leaves it unchanged.
        pub fn replace(self: *Self, text: []const u8) EditResult {
            if (text.len > max_bytes) return .overflow;
            if (std.mem.eql(u8, self.slice(), text)) return .no_change;
            @memcpy(self.buf[0..text.len], text);
            self.len = @intCast(text.len);
            return .changed;
        }

        /// Appends bytes at the end, copying the fitting prefix on overflow.
        pub fn append(self: *Self, text: []const u8) EditResult {
            if (text.len == 0) return .no_change;
            const remaining = max_bytes - self.len;
            const copy_len: u32 = if (text.len > @as(@TypeOf(text.len), remaining)) remaining else @intCast(text.len);
            if (copy_len > 0) {
                const start = self.len;
                const end = start + copy_len;
                @memcpy(self.buf[start..end], text[0..copy_len]);
                self.len = end;
            }
            if (text.len > @as(@TypeOf(text.len), copy_len)) return .overflow;
            return .changed;
        }

        /// Clears the current text and reports whether bytes were removed.
        pub fn clear(self: *Self) EditResult {
            if (self.len == 0) return .no_change;
            self.len = 0;
            return .changed;
        }

        /// Removes one UTF-8 scalar from the end when the textbox is non-empty.
        pub fn backspace(self: *Self) EditResult {
            if (self.len == 0) return .no_change;
            self.len = @intCast(previousUtf8Start(self.slice()));
            return .changed;
        }

        /// Returns the immutable text currently stored by this textbox.
        pub fn slice(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

test "empty state" {
    var box = Textbox(8){};
    try std.testing.expectEqualStrings("", box.slice());
}

test "seed and replace" {
    var box = Textbox(8){};
    try std.testing.expectEqual(EditResult.changed, box.replace("abc"));
    try std.testing.expectEqualStrings("abc", box.slice());
    try std.testing.expectEqual(EditResult.no_change, box.replace("abc"));
    try std.testing.expectEqual(EditResult.changed, box.replace("de"));
    try std.testing.expectEqualStrings("de", box.slice());
}

test "append" {
    var box = Textbox(12){};
    try std.testing.expectEqual(EditResult.changed, box.append("/tmp/"));
    try std.testing.expectEqual(EditResult.changed, box.append("a.png"));
    try std.testing.expectEqualStrings("/tmp/a.png", box.slice());
    try std.testing.expectEqual(EditResult.no_change, box.append(""));
}

test "overflow is reported without overrun" {
    var box = Textbox(5){};
    try std.testing.expectEqual(EditResult.changed, box.append("abcd"));
    try std.testing.expectEqual(EditResult.overflow, box.append("efgh"));
    try std.testing.expectEqualStrings("abcde", box.slice());
    try std.testing.expectEqual(EditResult.overflow, box.replace("123456"));
    try std.testing.expectEqualStrings("abcde", box.slice());
}

test "clear" {
    var box = Textbox(8){};
    try std.testing.expectEqual(EditResult.changed, box.append("abc"));
    try std.testing.expectEqual(EditResult.changed, box.clear());
    try std.testing.expectEqualStrings("", box.slice());
    try std.testing.expectEqual(EditResult.no_change, box.clear());
}

test "UTF-8 scalar backspace" {
    var box = Textbox(16){};
    try std.testing.expectEqual(EditResult.changed, box.append("ab"));
    try std.testing.expectEqual(EditResult.changed, box.append("é"));
    try std.testing.expectEqual(EditResult.changed, box.append("🙂"));
    try std.testing.expectEqual(EditResult.changed, box.backspace());
    try std.testing.expectEqualStrings("abé", box.slice());
    try std.testing.expectEqual(EditResult.changed, box.backspace());
    try std.testing.expectEqualStrings("ab", box.slice());
}

test "ArrayList append and UTF-8 scalar backspace" {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(std.testing.allocator);

    try std.testing.expectEqual(EditResult.changed, try appendArrayList(&list, std.testing.allocator, "abé"));
    try std.testing.expectEqual(EditResult.no_change, try appendArrayList(&list, std.testing.allocator, ""));
    try std.testing.expectEqual(EditResult.changed, backspaceArrayList(&list));
    try std.testing.expectEqualStrings("ab", list.items);
    try std.testing.expectEqual(EditResult.changed, backspaceArrayList(&list));
    try std.testing.expectEqualStrings("a", list.items);
}
