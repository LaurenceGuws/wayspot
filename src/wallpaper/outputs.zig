//! Physical output size and layer-configured logical size. No desktop position or focus.
const std = @import("std");
const wallpaper = @import("root.zig");

pub const Size = struct {
    width: u32,
    height: u32,

    pub fn eql(a: Size, b: Size) bool {
        return a.width == b.width and a.height == b.height;
    }
};

pub const Geometry = struct {
    pixels: Size,
    logical: Size,

    pub fn eql(a: Geometry, b: Geometry) bool {
        return a.pixels.eql(b.pixels) and a.logical.eql(b.logical);
    }
};

pub const Facts = struct {
    mode: ?Size = null,
    transform: ?u3 = null,
    pixels: ?Size = null,
    logical: ?Size = null,
    published: ?Geometry = null,

    // wl_output.done is the atomic boundary for mode and transform facts.
    pub fn done(self: *Facts) !bool {
        var size = self.mode orelse return false;
        const transform = self.transform orelse return false;
        if (transform & 1 != 0) std.mem.swap(u32, &size.width, &size.height);
        const count = try wallpaper.surfacePixelCount(size.width, size.height);
        if (count > wallpaper.monitor_pixel_capacity) return error.MonitorPixelsTooMany;
        const changed = if (self.pixels) |old| !old.eql(size) else true;
        self.pixels = size;
        return changed;
    }

    pub fn geometry(self: Facts) ?Geometry {
        return .{ .pixels = self.pixels orelse return null, .logical = self.logical orelse return null };
    }

    pub fn needsBuffer(self: Facts) bool {
        const target = self.geometry() orelse return false;
        return if (self.published) |old| !old.eql(target) else true;
    }
};

test "physical mode changes are committed only at done; repeat facts do not publish" {
    var facts: Facts = .{ .mode = .{ .width = 3840, .height = 2160 }, .transform = 0 };
    try std.testing.expect(facts.geometry() == null);
    try std.testing.expect(try facts.done());
    facts.logical = .{ .width = 2560, .height = 1440 };
    const initial = facts.geometry().?;
    try std.testing.expect(facts.needsBuffer());
    facts.published = initial;
    for (0..1000) |_| {
        try std.testing.expect(!try facts.done());
        facts.logical = initial.logical;
        try std.testing.expect(!facts.needsBuffer());
    }
    facts.transform = 1;
    try std.testing.expect(!facts.needsBuffer());
    try std.testing.expect(try facts.done());
    try std.testing.expectEqual(Size{ .width = 2160, .height = 3840 }, facts.pixels.?);
    try std.testing.expect(facts.needsBuffer());
}

test "logical reconfigure changes only the affected output; no surface geometry means no buffer" {
    var a: Facts = .{ .pixels = .{ .width = 1920, .height = 1080 }, .logical = .{ .width = 1280, .height = 720 } };
    a.published = a.geometry();
    var b = a;
    b.logical = .{ .width = 1920, .height = 1080 };
    try std.testing.expect(!a.needsBuffer());
    try std.testing.expect(b.needsBuffer());
    b.logical = null;
    try std.testing.expect(!b.needsBuffer());
}

test "invalid and oversized output sizes do not replace committed facts" {
    var facts: Facts = .{ .mode = .{ .width = 0, .height = 1080 }, .transform = 0, .pixels = .{ .width = 1920, .height = 1080 } };
    try std.testing.expectError(error.ImageDimensionsZero, facts.done());
    facts.mode = .{ .width = 8192, .height = 8192 };
    try std.testing.expectError(error.MonitorPixelsTooMany, facts.done());
    try std.testing.expectEqual(Size{ .width = 1920, .height = 1080 }, facts.pixels.?);
}
