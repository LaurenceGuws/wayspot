// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Pixel formats, named by their DRM fourcc code.
//!
//! `wl_shm.format` and `zwp_linux_dmabuf_v1` both speak DRM fourcc, with one
//! wrinkle: `wl_shm` gives the two formats every compositor must support the
//! codes 0 and 1 instead of `AR24` and `XR24`. Keeping the fourcc here and
//! translating at the `wl_shm` boundary means a buffer's format is the same
//! value whichever way the buffer was made -- which is what lets the dma-buf
//! backing come later without changing what a caller asks for.

const std = @import("std");

pub const Format = enum(u32) {
    /// `[31:0] A:R:G:B 8:8:8:8`, little endian. Always supported by `wl_shm`.
    argb8888 = fourcc("AR24"),
    /// `[31:0] x:R:G:B 8:8:8:8`, little endian. Always supported by `wl_shm`.
    xrgb8888 = fourcc("XR24"),
    abgr8888 = fourcc("AB24"),
    xbgr8888 = fourcc("XB24"),
    rgba8888 = fourcc("RA24"),
    rgbx8888 = fourcc("RX24"),
    bgra8888 = fourcc("BA24"),
    bgrx8888 = fourcc("BX24"),
    argb2101010 = fourcc("AR30"),
    xrgb2101010 = fourcc("XR30"),
    abgr2101010 = fourcc("AB30"),
    xbgr2101010 = fourcc("XB30"),
    rgb888 = fourcc("RG24"),
    bgr888 = fourcc("BG24"),
    rgb565 = fourcc("RG16"),
    bgr565 = fourcc("BG16"),
    _,

    /// The value `wl_shm` uses for this format.
    pub fn toShm(f: Format) u32 {
        return switch (f) {
            .argb8888 => 0,
            .xrgb8888 => 1,
            else => @backingInt(f),
        };
    }

    /// The format a `wl_shm` value names.
    pub fn fromShm(value: u32) Format {
        return switch (value) {
            0 => .argb8888,
            1 => .xrgb8888,
            else => @fromBackingInt(value),
        };
    }

    /// Bytes per pixel for the packed single-plane formats this module can
    /// allocate in shared memory, or null for anything else -- a planar YUV
    /// format, say, which has no single stride.
    pub fn bytesPerPixel(f: Format) ?u32 {
        return switch (f) {
            .argb8888, .xrgb8888, .abgr8888, .xbgr8888 => 4,
            .rgba8888, .rgbx8888, .bgra8888, .bgrx8888 => 4,
            .argb2101010, .xrgb2101010, .abgr2101010, .xbgr2101010 => 4,
            .rgb888, .bgr888 => 3,
            .rgb565, .bgr565 => 2,
            _ => null,
        };
    }

    pub fn format(f: Format, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const code: [4]u8 = @bitCast(std.mem.nativeToLittle(u32, @backingInt(f)));
        for (code) |c| try w.writeByte(if (std.ascii.isPrint(c)) c else '?');
    }
};

/// Format modifiers: how a buffer's pixels are laid out in memory beyond the
/// format itself -- tiling, compression. Everything else is vendor-specific
/// and opaque here.
pub const modifier = struct {
    /// Plain rows, one after another: what every device can read.
    pub const linear: u64 = 0;
    /// No explicit modifier: the layout is whatever the driver chose, and
    /// only the driver knows. This is what a compositor means when it offers
    /// a format without modifiers.
    pub const invalid: u64 = 0x00ff_ffff_ffff_ffff;
};

/// The DRM fourcc code for four characters, as `fourcc_code()` in
/// `drm_fourcc.h` builds it.
pub fn fourcc(comptime code: *const [4]u8) u32 {
    return @as(u32, code[0]) | @as(u32, code[1]) << 8 | @as(u32, code[2]) << 16 | @as(u32, code[3]) << 24;
}

const testing = std.testing;

test "wl_shm's two special codes, and the fourcc for the rest" {
    try testing.expectEqual(@as(u32, 0), Format.argb8888.toShm());
    try testing.expectEqual(@as(u32, 1), Format.xrgb8888.toShm());
    try testing.expectEqual(@as(u32, 0x3432_4241), Format.abgr8888.toShm());
    try testing.expectEqual(Format.xrgb8888, Format.fromShm(1));
    try testing.expectEqual(Format.rgb565, Format.fromShm(0x3631_4752));
    // An unknown format survives the round trip.
    try testing.expectEqual(@as(u32, 0x3231_564e), Format.fromShm(0x3231_564e).toShm());
    try testing.expectEqual(@as(?u32, null), Format.fromShm(0x3231_564e).bytesPerPixel());
}

test "a format prints as its fourcc" {
    var buf: [8]u8 = undefined;
    try testing.expectEqualStrings("XR24", try std.fmt.bufPrint(&buf, "{f}", .{Format.xrgb8888}));
}
