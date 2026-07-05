//! Test root for the sunglasses runtime config form.

const std = @import("std");
const form = @import("sunglasses/form.zig");
const state = @import("sunglasses/state.zig");

test {
    std.testing.refAllDecls(form);
}

test "RCA missing persisted sunglasses image path must not remain an effective overlay" {
    var monitor = try state.MonitorState.init("DP-1");
    monitor.image_enabled = true;
    monitor.setImageOpacity(5);
    try monitor.setImagePath("/tmp/wayspot-missing-sunglasses-rca.png");

    try std.testing.expect(!monitor.hasEffectiveImageOverlay());
}
