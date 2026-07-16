//! Sunglasses is the resident per-monitor overlay owner.
//!
//! `run` owns identity setup, SDL lifecycle, overlay cleanup, and startup
//! recovery. `applyNow`, `reconcileSavedState`, and `applyLeaf` own the direct
//! lifecycle transitions; picker mode code carries only typed leaf meaning.

const std = @import("std");
const candidate = @import("picker_candidate");
const env = @import("wayspot_env_native");
const identity = @import("wayspot_identity");

pub const Overlay = @import("overlay.zig").Overlay;
pub const state = @import("state.zig");

/// run owns one sunglasses resident overlay lifecycle.
pub fn run(allocator: std.mem.Allocator, monitor_source: *env.MonitorSource) !void {
    try identity.set(identity.sunglasses);
    Overlay.runOverlay(allocator, monitor_source) catch |err| {
        recordStartupFailure(allocator, monitor_source.runtimeDir(), err);
        std.log.err("sunglasses overlay failed: {s}", .{@errorName(err)});
        std.process.exit(2);
    };
}
/// applyNow wakes the resident overlay after persisted state changes.
pub fn applyNow(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
    try identity.set(identity.sunglasses);
    try Overlay.applyNow(allocator, runtime_dir);
}
/// reconcileSavedState starts, wakes, or stops the resident overlay for saved state.
pub fn reconcileSavedState(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
    try identity.set(identity.sunglasses);
    try Overlay.reconcileSavedState(allocator, runtime_dir);
}
/// recordStartupFailure writes the bounded resident startup failure status.
pub fn recordStartupFailure(allocator: std.mem.Allocator, runtime_dir: []const u8, err: anyerror) void {
    Overlay.recordStartupFailure(allocator, runtime_dir, err);
}

/// applyLeaf owns typed sunglasses state mutation and resident reconciliation.
/// The picker supplies a copied Lifecycle value; this owner persists only its
/// accepted monitor state and then wakes or starts the resident overlay.
pub fn applyLeaf(
    allocator: std.mem.Allocator,
    runtime_dir: []const u8,
    value: candidate.Lifecycle,
) !void {
    try identity.set(identity.sunglasses);
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

test "sunglasses module reaches resident overlay and state owners" {
    std.testing.refAllDecls(Overlay);
    std.testing.refAllDecls(state);
}
