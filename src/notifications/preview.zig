//! Notification preview text owns shared bounded labels for banners and history.

const std = @import("std");

pub const banner_app_max: u32 = 80;
pub const banner_summary_max: u32 = 132;
pub const banner_body_max: u32 = 132;
pub const history_title_max: u32 = 120;
pub const history_subtitle_max: u32 = 180;
pub const max_preview_bytes: u32 = history_subtitle_max;

comptime {
    std.debug.assert(banner_app_max > 0);
    std.debug.assert(banner_summary_max > 0);
    std.debug.assert(banner_body_max > 0);
    std.debug.assert(history_title_max > 0);
    std.debug.assert(history_subtitle_max > 0);
    std.debug.assert(max_preview_bytes >= banner_app_max);
    std.debug.assert(max_preview_bytes >= banner_summary_max);
    std.debug.assert(max_preview_bytes >= banner_body_max);
    std.debug.assert(max_preview_bytes >= history_title_max);
}

pub const Text = struct {
    buf: [max_preview_bytes]u8 = undefined,
    len: u32 = 0,

    pub fn slice(self: *const Text) []const u8 {
        return self.buf[0..self.len];
    }

    pub fn isEmpty(self: *const Text) bool {
        return self.len == 0;
    }
};

pub fn bannerApp(text: []const u8) Text {
    return collapse(text, banner_app_max);
}

pub fn bannerSummary(text: []const u8) Text {
    return collapse(text, banner_summary_max);
}

pub fn bannerBody(text: []const u8) Text {
    return collapse(text, banner_body_max);
}

pub fn historyTitle(app_name: []const u8, summary: []const u8) Text {
    const title = collapse(summary, history_title_max);
    if (!title.isEmpty()) return title;
    return collapse(app_name, history_title_max);
}

pub fn historySubtitle(app_name: []const u8, body: []const u8) Text {
    const app = collapse(app_name, history_subtitle_max);
    const body_text = collapse(body, history_subtitle_max);
    if (app.isEmpty()) return body_text;
    if (body_text.isEmpty()) return app;

    var out = Text{};
    appendSlice(&out, app.slice(), history_subtitle_max);
    appendSlice(&out, ": ", history_subtitle_max);
    appendSlice(&out, body_text.slice(), history_subtitle_max);
    return out;
}

pub fn collapse(text: []const u8, max_bytes: u32) Text {
    std.debug.assert(max_bytes > 0);
    std.debug.assert(max_bytes <= max_preview_bytes);

    var out = Text{};
    var pending_space = false;
    var truncated = false;

    for (text) |byte| {
        if (isCollapsedWhitespace(byte)) {
            if (out.len > 0) pending_space = true;
            continue;
        }

        if (pending_space) {
            if (!appendByte(&out, ' ', max_bytes)) {
                truncated = true;
                break;
            }
            pending_space = false;
        }

        if (!appendByte(&out, byte, max_bytes)) {
            truncated = true;
            break;
        }
    }

    if (truncated and out.len > 0) out.buf[out.len - 1] = '~';
    return out;
}

fn appendSlice(out: *Text, text: []const u8, max_bytes: u32) void {
    for (text) |byte| {
        if (!appendByte(out, byte, max_bytes)) {
            if (out.len > 0) out.buf[out.len - 1] = '~';
            return;
        }
    }
}

fn appendByte(out: *Text, byte: u8, max_bytes: u32) bool {
    if (out.len >= max_bytes) return false;
    out.buf[out.len] = byte;
    out.len += 1;
    return true;
}

fn isCollapsedWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
}

test "preview collapses whitespace runs" {
    const out = bannerBody("  alpha\t\tbeta\r\ngamma   delta  ");
    try std.testing.expectEqualStrings("alpha beta gamma delta", out.slice());
}

test "history title falls back to app name when summary is empty" {
    const out = historyTitle("Mail App", " \n\t ");
    try std.testing.expectEqualStrings("Mail App", out.slice());
}

test "preview truncates to explicit cap" {
    const long = [_]u8{'a'} ** (banner_app_max + 4);
    const out = bannerApp(&long);
    try std.testing.expectEqual(banner_app_max, out.len);
    try std.testing.expectEqual(@as(u8, '~'), out.slice()[out.slice().len - 1]);
}

test "history subtitle combines app and body within cap" {
    const out = historySubtitle("Calendar", "meeting\tsoon");
    try std.testing.expectEqualStrings("Calendar: meeting soon", out.slice());
}
