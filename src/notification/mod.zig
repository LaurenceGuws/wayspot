//! Notification owns DBus state, history cache, history rows, and banners.

const std = @import("std");

pub const banner = @import("banner.zig");
pub const state = @import("state.zig");
pub const dbus = @import("dbus.zig");
pub const DBus = dbus.DBus;
pub const run = dbus.run;
pub const rows = @import("rows.zig");
pub const preview = @import("preview.zig");
pub const history_cache = @import("history_cache.zig");
pub const history_list = @import("history_list.zig");

test "notification helper modules are covered" {
    std.testing.refAllDecls(preview);
    std.testing.refAllDecls(history_cache);
    std.testing.refAllDecls(history_list);
}
