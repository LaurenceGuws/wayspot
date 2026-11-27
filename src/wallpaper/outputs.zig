//! Physical output size and layer-configured logical size. No desktop position or focus.
const std = @import("std");
const wallpaper = @import("root.zig");

// Pixel or logical extent; the enclosing field supplies its units.
const Size = struct {
    width: u32,
    height: u32,

    fn eql(a: Size, b: Size) bool {
        return a.width == b.width and a.height == b.height;
    }
};

/// One admitted wallpaper buffer extent and its layer-configured destination.
pub const Geometry = struct {
    pixels: Size,
    logical: Size,

    fn eql(a: Geometry, b: Geometry) bool {
        return a.pixels.eql(b.pixels) and a.logical.eql(b.logical);
    }
};

/// Pending output mode/transform, committed physical extent, independent
/// layer configuration, and the geometry of the last published buffer.
pub const Facts = struct {
    mode: ?Size = null,
    transform: ?u3 = null,
    pixels: ?Size = null,
    logical: ?Size = null,
    published: ?Geometry = null,

    /// Commits the pending physical extent at wl_output.done, if both facts
    /// are present and within the per-output pixel budget. Returns whether
    /// the committed extent changed. Incomplete or invalid facts leave the
    /// previous committed extent intact.
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

    /// Returns a target only when committed pixels and an admitted logical
    /// layer extent are available. The layer callback validates logical size.
    pub fn geometry(self: Facts) ?Geometry {
        return .{ .pixels = self.pixels orelse return null, .logical = self.logical orelse return null };
    }

    /// True only when a complete target differs from the published geometry
    /// or no buffer has been published. Rotation is a separate caller policy.
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

test "all eight output transforms commit the expected extent only at done" {
    const mode: Size = .{ .width = 3840, .height = 2160 };
    const rotated: Size = .{ .width = 2160, .height = 3840 };
    var facts: Facts = .{ .mode = mode, .transform = 0 };
    facts.logical = .{ .width = 1280, .height = 720 };
    try std.testing.expect(try facts.done());
    facts.published = facts.geometry();

    // The odd Wayland transform values exchange axes, including reflections.
    const expected = [8]Size{ mode, rotated, mode, rotated, mode, rotated, mode, rotated };
    for (expected, 0..) |size, index| {
        const previous = facts.pixels.?;
        facts.transform = @intCast(index);
        try std.testing.expectEqual(previous, facts.pixels.?);
        try std.testing.expect(!facts.needsBuffer());
        try std.testing.expectEqual(!previous.eql(size), try facts.done());
        try std.testing.expectEqual(size, facts.pixels.?);
        try std.testing.expectEqual(!previous.eql(size), facts.needsBuffer());
        facts.published = facts.geometry();
        try std.testing.expect(!try facts.done());
        try std.testing.expect(!facts.needsBuffer());
    }

    // A different transform with identical dimensions does not need new pixels.
    facts.transform = 3;
    try std.testing.expect(!try facts.done());
    try std.testing.expect(!facts.needsBuffer());
}

test "incomplete mode and transform preserve the last complete physical extent" {
    const size: Size = .{ .width = 1920, .height = 1080 };
    var facts: Facts = .{ .logical = .{ .width = 1280, .height = 720 } };
    try std.testing.expect(!try facts.done());
    try std.testing.expect(facts.geometry() == null);
    facts.transform = 1;
    try std.testing.expect(!try facts.done());
    facts.transform = null;
    facts.mode = size;
    try std.testing.expect(!try facts.done());
    try std.testing.expect(facts.geometry() == null);
    facts.transform = 0;
    try std.testing.expect(try facts.done());
    facts.published = facts.geometry();
    facts.mode = null;
    try std.testing.expect(!try facts.done());
    try std.testing.expectEqual(size, facts.pixels.?);
    facts.mode = size;
    facts.transform = null;
    try std.testing.expect(!try facts.done());
    try std.testing.expect(!facts.needsBuffer());
    facts.transform = 1;
    try std.testing.expect(try facts.done());
    try std.testing.expect(facts.needsBuffer());
}

test "exact monitor budget admits geometry and excess leaves publication unchanged" {
    const maximum: Size = .{ .width = 7680, .height = 4320 };
    var facts: Facts = .{
        .mode = maximum,
        .transform = 0,
        .logical = .{ .width = 3840, .height = 2160 },
    };
    try std.testing.expectEqual(
        wallpaper.monitor_pixel_capacity,
        try wallpaper.surfacePixelCount(maximum.width, maximum.height),
    );
    try std.testing.expect(try facts.done());
    facts.published = facts.geometry();
    facts.mode = .{ .width = maximum.width + 1, .height = maximum.height };
    try std.testing.expectError(error.MonitorPixelsTooMany, facts.done());
    try std.testing.expectEqual(maximum, facts.pixels.?);
    try std.testing.expect(!facts.needsBuffer());

    facts.mode = .{ .width = std.math.maxInt(u32), .height = 1 };
    try std.testing.expectError(error.ImageDimensionsTooLarge, facts.done());
    try std.testing.expectEqual(maximum, facts.pixels.?);
    try std.testing.expect(!facts.needsBuffer());

    facts.mode = maximum;
    facts.transform = 1;
    try std.testing.expect(try facts.done());
    try std.testing.expectEqual(Size{ .width = 4320, .height = 7680 }, facts.pixels.?);
    try std.testing.expect(facts.needsBuffer());
}
