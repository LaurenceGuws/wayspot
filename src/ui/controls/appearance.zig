//! Inert appearance value types and bounds shared by UI surfaces.
//!
//! This file owns only reusable bounded values. Product surface names and
//! renderer effects live outside `src/ui/controls`.

const std = @import("std");

pub const max_font_candidates: u32 = 8;
pub const max_string_bytes: u32 = 240;
pub const min_font_px: u16 = 8;
pub const max_font_px: u16 = 48;
pub const min_chrome_px: f32 = 0;
pub const max_chrome_px: f32 = 96;
pub const max_layout_px: f32 = 240;
pub const min_opacity: f32 = 0;
pub const max_opacity: f32 = 1;

/// Rgba8 stores one bounded sRGB color with an explicit alpha byte.
pub const Rgba8 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    /// Builds a color only when every component is within the byte range.
    pub fn fromComponents(r: i64, g: i64, b: i64, a: i64) !Rgba8 {
        return .{
            .r = try byteComponent(r),
            .g = try byteComponent(g),
            .b = try byteComponent(b),
            .a = try byteComponent(a),
        };
    }
};

/// FontCandidate owns one zero-terminated path or family candidate.
pub const FontCandidate = struct {
    bytes: [max_string_bytes + 1]u8 = [_]u8{0} ** (max_string_bytes + 1),
    len: u16 = 0,

    /// Replaces the candidate text, rejecting overlong strings.
    pub fn set(self: *FontCandidate, value: []const u8) !void {
        if (value.len == 0) return error.EmptyString;
        if (value.len > max_string_bytes) return error.StringTooLong;
        @memset(&self.bytes, 0);
        @memcpy(self.bytes[0..value.len], value);
        self.len = @intCast(value.len);
    }

    /// Returns the candidate as a sentinel-terminated byte slice for C APIs.
    pub fn sliceZ(self: *const FontCandidate) [:0]const u8 {
        return self.bytes[0..self.len :0];
    }
};

/// FontCandidates keeps a fixed-size ordered fallback list.
pub const FontCandidates = struct {
    items: [max_font_candidates]FontCandidate = [_]FontCandidate{.{}} ** max_font_candidates,
    count: u32 = 0,

    /// Appends one candidate while enforcing the list and string bounds.
    pub fn append(self: *FontCandidates, value: []const u8) !void {
        if (self.count >= max_font_candidates) return error.TooManyFontCandidates;
        try self.items[self.count].set(value);
        self.count += 1;
    }

    /// Returns the candidate at `index`, or null when the index is outside the retained list.
    pub fn at(self: *const FontCandidates, index: u32) ?*const FontCandidate {
        if (index >= self.count) return null;
        return &self.items[index];
    }
};

/// Validates a text size in pixels.
pub fn fontPx(value: i64) !u16 {
    if (value < min_font_px or value > max_font_px) return error.FontSizeOutOfRange;
    return @intCast(value);
}

/// Validates a chrome scalar in base pixels.
pub fn chromePx(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.ChromeOutOfRange;
    if (value < min_chrome_px or value > max_chrome_px) return error.ChromeOutOfRange;
    return @floatCast(value);
}

/// Validates a base-coordinate layout scalar.
pub fn layoutPx(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.LayoutOutOfRange;
    if (value < min_chrome_px or value > max_layout_px) return error.LayoutOutOfRange;
    return @floatCast(value);
}

/// Validates a scalar intended to stay within the opacity range.
pub fn opacity(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.OpacityOutOfRange;
    if (value < min_opacity or value > max_opacity) return error.OpacityOutOfRange;
    return @floatCast(value);
}

fn byteComponent(value: i64) !u8 {
    if (value < 0 or value > 255) return error.ColorComponentOutOfRange;
    return @intCast(value);
}

test "inert appearance validators reject values outside accepted bounds" {
    try std.testing.expectError(error.FontSizeOutOfRange, fontPx(7));
    try std.testing.expectError(error.FontSizeOutOfRange, fontPx(49));
    try std.testing.expectEqual(@as(u16, 17), try fontPx(17));

    try std.testing.expectError(error.ChromeOutOfRange, chromePx(-1));
    try std.testing.expectError(error.ChromeOutOfRange, chromePx(97));
    try std.testing.expectEqual(@as(f32, 42), try chromePx(42));
    try std.testing.expectEqual(@as(f32, 122), try layoutPx(122));
    try std.testing.expectError(error.LayoutOutOfRange, layoutPx(241));

    try std.testing.expectError(error.OpacityOutOfRange, opacity(-0.1));
    try std.testing.expectError(error.OpacityOutOfRange, opacity(1.1));
    try std.testing.expectEqual(@as(f32, 0.28), try opacity(0.28));

    try std.testing.expectError(error.ColorComponentOutOfRange, Rgba8.fromComponents(256, 0, 0, 255));
}
