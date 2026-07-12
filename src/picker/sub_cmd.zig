//! SubCmd owns the one closed resident child vocabulary consumed by Cmd.
//!
//! The picker mode files construct these values but do not declare their
//! types. Apps has no child union because its candidates are terminal app
//! leaves. Resident runtime code is not imported here.

const std = @import("std");

/// NotificationsSubCmd is the closed child vocabulary for notification routes.
/// `history` enters display-only notification history; `restart` selects the
/// notification resident lifecycle intent. The union carries no borrowed
/// input, so this layer has no allocation or cleanup responsibility.
pub const NotificationsSubCmd = union(enum) {
    /// history enters the bounded notification history route.
    history,
    /// restart selects the notification resident lifecycle intent.
    restart,
};

/// WallpaperSubCmd is the closed child vocabulary for wallpaper routes.
/// `restart` selects the resident owner and `rotate` selects one direct
/// rotation intent. The union carries no borrowed input or owned storage.
pub const WallpaperSubCmd = union(enum) {
    /// restart selects the wallpaper resident lifecycle intent.
    restart,
    /// rotate selects one direct wallpaper rotation intent.
    rotate,
};

/// DimSubCmd is the closed operation vocabulary for dimming one monitor.
/// It selects an operation; the typed Concrete leaf builder validates the
/// scalar or toggle Input at the selected boundary.
pub const DimSubCmd = union(enum) {
    /// set selects a scalar dim value.
    set,
    /// on selects the enabled dim state.
    on,
    /// off selects the disabled dim state.
    off,
};

/// FilterSubCmd is the closed operation vocabulary for red/blue filtering.
/// It selects an operation; the typed Concrete leaf builder validates the
/// scalar or toggle Input at the selected boundary.
pub const FilterSubCmd = union(enum) {
    /// set selects a scalar filter value.
    set,
    /// on selects the enabled filter state.
    on,
    /// off selects the disabled filter state.
    off,
};

/// ImageSubCmd is the closed operation vocabulary for the image overlay.
/// It selects an operation; the typed Concrete leaf builder validates the
/// path, scalar, toggle, or none Input at the selected boundary.
pub const ImageSubCmd = union(enum) {
    /// set selects a bounded image path.
    set,
    /// opacity selects a bounded image opacity scalar.
    opacity,
    /// on selects the enabled image state.
    on,
    /// off selects the disabled image state.
    off,
    /// clear selects removal of the retained image path.
    clear,
};

/// SunglassesSubCmd is the closed child vocabulary for overlay routes.
/// Nested route arms select operations; monitor and Input values are carried
/// by the later typed Concrete leaf and own no allocation here.
pub const SunglassesSubCmd = union(enum) {
    /// restart selects the sunglasses resident lifecycle intent.
    restart,
    /// apply wakes or starts the persisted sunglasses overlay state.
    apply,
    /// reconcile makes the resident overlay match saved state.
    reconcile,
    /// dim enters the bounded dim operation union.
    dim: DimSubCmd,
    /// filter enters the bounded filter operation union.
    filter: FilterSubCmd,
    /// image enters the bounded image operation union.
    image: ImageSubCmd,
};

/// SubCmd carries exactly one resident mode child union without erasure.
/// Apps is intentionally absent because the apps mode exposes terminal
/// application candidates directly. An unknown arm is impossible by type.
pub const SubCmd = union(enum) {
    /// notifications carries one NotificationsSubCmd route.
    notifications: NotificationsSubCmd,
    /// wallpaper carries one WallpaperSubCmd route.
    wallpaper: WallpaperSubCmd,
    /// sunglasses carries one SunglassesSubCmd route.
    sunglasses: SunglassesSubCmd,
};

comptime {
    assertUnionFields(NotificationsSubCmd, &.{ "history", "restart" });
    assertUnionFields(WallpaperSubCmd, &.{ "restart", "rotate" });
    assertUnionFields(SunglassesSubCmd, &.{ "restart", "apply", "reconcile", "dim", "filter", "image" });
    assertUnionFields(DimSubCmd, &.{ "set", "on", "off" });
    assertUnionFields(FilterSubCmd, &.{ "set", "on", "off" });
    assertUnionFields(ImageSubCmd, &.{ "set", "opacity", "on", "off", "clear" });
    assertUnionFields(SubCmd, &.{ "notifications", "wallpaper", "sunglasses" });
}

fn assertUnionFields(comptime Union: type, comptime names: []const []const u8) void {
    const fields = std.meta.fields(Union);
    std.debug.assert(fields.len == names.len);
    inline for (names, 0..) |name, index| {
        std.debug.assert(std.mem.eql(u8, fields[index].name, name));
    }
}

test "resident child unions are closed and explicit" {
    const notifications = NotificationsSubCmd{ .restart = {} };
    const wallpaper = WallpaperSubCmd{ .rotate = {} };
    const sunglasses = SunglassesSubCmd{ .image = .{ .set = {} } };

    try std.testing.expectEqual(std.meta.Tag(NotificationsSubCmd).restart, std.meta.activeTag(notifications));
    try std.testing.expectEqual(std.meta.Tag(WallpaperSubCmd).rotate, std.meta.activeTag(wallpaper));
    try std.testing.expectEqual(std.meta.Tag(SunglassesSubCmd).image, std.meta.activeTag(sunglasses));
}

test "SubCmd has one shared wrapper and no apps arm" {
    const history = SubCmd{ .notifications = .{ .history = {} } };
    const rotate = SubCmd{ .wallpaper = .{ .rotate = {} } };
    const apply = SubCmd{ .sunglasses = .{ .apply = {} } };

    try std.testing.expectEqual(std.meta.Tag(SubCmd).notifications, std.meta.activeTag(history));
    try std.testing.expectEqual(std.meta.Tag(SubCmd).wallpaper, std.meta.activeTag(rotate));
    try std.testing.expectEqual(std.meta.Tag(SubCmd).sunglasses, std.meta.activeTag(apply));
    try std.testing.expect(@hasField(SubCmd, "notifications"));
    try std.testing.expect(@hasField(SubCmd, "wallpaper"));
    try std.testing.expect(@hasField(SubCmd, "sunglasses"));
    try std.testing.expect(!@hasField(SubCmd, "apps"));
}

test "sunglasses nested routes are closed operation unions" {
    const dim = SunglassesSubCmd{ .dim = .{ .set = {} } };
    const filter = SunglassesSubCmd{ .filter = .{ .off = {} } };
    const image = SunglassesSubCmd{ .image = .{ .opacity = {} } };

    try std.testing.expectEqual(std.meta.Tag(SunglassesSubCmd).dim, std.meta.activeTag(dim));
    try std.testing.expectEqual(std.meta.Tag(SunglassesSubCmd).filter, std.meta.activeTag(filter));
    try std.testing.expectEqual(std.meta.Tag(SunglassesSubCmd).image, std.meta.activeTag(image));
    try std.testing.expectEqual(std.meta.Tag(DimSubCmd).set, std.meta.activeTag(dim.dim));
    try std.testing.expectEqual(std.meta.Tag(FilterSubCmd).off, std.meta.activeTag(filter.filter));
    try std.testing.expectEqual(std.meta.Tag(ImageSubCmd).opacity, std.meta.activeTag(image.image));
}
