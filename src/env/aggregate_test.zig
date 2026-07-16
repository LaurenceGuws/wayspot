//! Aggregate pure env test root; it does not import production native wrappers.

const std = @import("std");
const env = @import("mod.zig");
const hyprland = @import("hyprland.zig");
const monitor = @import("monitor.zig");
const workspace = @import("workspace.zig");
const window = @import("window.zig");
const state = @import("state.zig");

test "pure env source tree is reachable" {
    std.testing.refAllDecls(env);
    std.testing.refAllDecls(hyprland);
    std.testing.refAllDecls(monitor);
    std.testing.refAllDecls(workspace);
    std.testing.refAllDecls(window);
    std.testing.refAllDecls(state);
}
