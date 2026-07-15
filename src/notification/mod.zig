//! Notification is the resident DBus owner.
//!
//! `run` establishes the notification process identity, acquires the DBus
//! name, and owns the resident cleanup path. Picker mode code carries only
//! typed route meaning and does not import this runtime.

const std = @import("std");
const identity = @import("wayspot_identity");

pub const banner = @import("banner.zig");
pub const state = @import("state.zig");
pub const dbus = @import("dbus.zig");
pub const DBus = dbus.DBus;
pub const preview = @import("wayspot_notification_preview");
pub const history = @import("wayspot_history");
pub const history_list = @import("wayspot_history_list");

/// run owns one notification resident process lifecycle from identity setup
/// through DBus acquisition, event processing, and cleanup.
pub fn run(allocator: std.mem.Allocator) !void {
    try identity.set(identity.notifications);
    try dbus.run(allocator);
}

test "notification helper modules are covered" {
    std.testing.refAllDecls(dbus);
    std.testing.refAllDecls(preview);
    std.testing.refAllDecls(history);
    std.testing.refAllDecls(history_list);
}
