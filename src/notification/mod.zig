//! Notification owns daemon state, history cache, history rows, and banners.

const std = @import("std");

pub const banner = @import("banner.zig");
pub const state = @import("state.zig");
pub const daemon = @import("daemon.zig");
pub const Daemon = daemon.Daemon;
pub const run = daemon.run;
pub const runtime = @import("runtime.zig");
pub const preview = @import("preview.zig");
pub const history_cache = @import("history_cache.zig");
pub const history_list = @import("history_list.zig");

test "notification helper modules are covered" {
    std.testing.refAllDecls(preview);
    std.testing.refAllDecls(history_cache);
    std.testing.refAllDecls(history_list);
}
