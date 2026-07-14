//! Sunglasses owns bounded per-monitor overlay state and resident lifecycle calls.

const std = @import("std");
const candidate = @import("picker_candidate");

pub const Overlay = @import("overlay.zig").Overlay;
pub const state = @import("state.zig");

/// run owns one sunglasses resident overlay lifecycle.
pub const run = Overlay.runOverlay;
/// applyNow wakes the resident overlay after persisted state changes.
pub const applyNow = Overlay.applyNow;
/// reconcileSavedState starts, wakes, or stops the resident overlay for saved state.
pub const reconcileSavedState = Overlay.reconcileSavedState;
/// recordStartupFailure writes the bounded resident startup failure status.
pub const recordStartupFailure = Overlay.recordStartupFailure;

/// applyLeaf owns typed sunglasses state mutation and resident reconciliation.
/// The picker supplies a copied Lifecycle value; this owner persists only its
/// accepted monitor state and then wakes or starts the resident overlay.
pub fn applyLeaf(
    allocator: std.mem.Allocator,
    runtime_dir: []const u8,
    value: candidate.Lifecycle,
) !void {
    var saved = try state.State.load(allocator);
    switch (value) {
        .sunglasses_dim => |leaf| {
            const monitor = try saved.ensureMonitor(leaf.monitor.slice());
            switch (leaf.input) {
                .scalar => |input| monitor.setDimValue(input.value),
                .toggle => |input| monitor.dim_enabled = input.enabled,
                .none, .path => return error.InvalidSunglassesInput,
            }
        },
        .sunglasses_filter => |leaf| {
            const monitor = try saved.ensureMonitor(leaf.monitor.slice());
            switch (leaf.input) {
                .scalar => |input| monitor.setRedBlueValue(input.value),
                .toggle => |input| monitor.red_blue_enabled = input.enabled,
                .none, .path => return error.InvalidSunglassesInput,
            }
        },
        .sunglasses_image => |leaf| {
            const monitor = try saved.ensureMonitor(leaf.monitor.slice());
            switch (leaf.input) {
                .none => {
                    monitor.image_enabled = false;
                    monitor.clearImagePath();
                },
                .scalar => |input| monitor.setImageOpacity(input.value),
                .toggle => |input| monitor.image_enabled = input.enabled,
                .path => |input| try monitor.setImagePath(input.slice()),
            }
        },
        .notifications_restart,
        .wallpaper_restart,
        .wallpaper_rotate,
        .sunglasses_restart,
        .sunglasses_apply,
        .sunglasses_reconcile,
        => return error.SunglassesLeafNotOwned,
    }
    try saved.save(allocator);
    try Overlay.reconcileSavedState(allocator, runtime_dir);
}
