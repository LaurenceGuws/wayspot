//! Sunglasses mode owns semantic route behavior for SunglassesSubCmd.
//!
//! The child union is declared in picker/sub_cmd.zig. This file constructs
//! picker candidates and bounded lifecycle meaning; monitor overlay state and
//! runtime remain in src/sunglasses/. No resident implementation is imported here.

const std = @import("std");
const candidate = @import("picker_candidate");
const sub_cmd = @import("picker_sub_cmd");

/// restart_open is the stable display input for the sunglasses restart route.
pub const restart_open = "lifecycle:sunglasses:restart";

/// collectCandidates constructs direct lifecycle leaves and nested input routes.
pub fn collectCandidates(out: *candidate.Candidate.List) !void {
    try out.append(candidate.Candidate.lifecycleLeaf(candidate.sunglassesRestart()));
    try out.append(candidate.Candidate.lifecycleLeaf(candidate.sunglassesApply()));
    try out.append(candidate.Candidate.lifecycleLeaf(candidate.sunglassesReconcile()));
    try out.append(candidate.Candidate.subCmd(dimSubCmd()));
    try out.append(candidate.Candidate.subCmd(filterSubCmd()));
    try out.append(candidate.Candidate.subCmd(imageSubCmd()));
}

/// restartSubCmd selects the sunglasses resident restart route.
pub fn restartSubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .restart = {} } };
}

/// applySubCmd selects the persisted sunglasses apply route.
pub fn applySubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .apply = {} } };
}

/// reconcileSubCmd selects the saved-state reconciliation route.
pub fn reconcileSubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .reconcile = {} } };
}

/// dimSubCmd selects the bounded dim input route.
pub fn dimSubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .dim = .{ .set = {} } } };
}

/// filterSubCmd selects the bounded filter input route.
pub fn filterSubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .filter = .{ .set = {} } } };
}

/// imageSubCmd selects the bounded image input route.
pub fn imageSubCmd() sub_cmd.SubCmd {
    return .{ .sunglasses = .{ .image = .{ .set = {} } } };
}

/// resolve returns canonical sunglasses command meaning without changing state.
pub fn resolve(value: sub_cmd.SunglassesSubCmd) []const u8 {
    return switch (value) {
        .restart => restartIntent(),
        .apply => "wayspot sunglasses apply",
        .reconcile => "wayspot sunglasses reconcile",
        .dim => "wayspot sunglasses dim",
        .filter => "wayspot sunglasses filter",
        .image => "wayspot sunglasses image",
    };
}

/// select turns one typed sunglasses route and Input into a terminal leaf.
/// Operation arms own the accepted Input arm; candidate constructors own the
/// monitor and value bounds. Resident runtime state is not touched here.
pub fn select(
    route: sub_cmd.SunglassesSubCmd,
    monitor: []const u8,
    value: candidate.Input,
) candidate.InputError!candidate.Candidate {
    return switch (route) {
        .restart => candidate.Candidate.lifecycleLeaf(try selectAction(candidate.sunglassesRestart(), value)),
        .apply => candidate.Candidate.lifecycleLeaf(try selectAction(candidate.sunglassesApply(), value)),
        .reconcile => candidate.Candidate.lifecycleLeaf(try selectAction(candidate.sunglassesReconcile(), value)),
        .dim => |operation| candidate.Candidate.lifecycleLeaf(try selectDim(operation, monitor, value)),
        .filter => |operation| candidate.Candidate.lifecycleLeaf(try selectFilter(operation, monitor, value)),
        .image => |operation| candidate.Candidate.lifecycleLeaf(try selectImage(operation, monitor, value)),
    };
}

fn selectAction(leaf: candidate.Lifecycle, value: candidate.Input) candidate.InputError!candidate.Lifecycle {
    try requireNone(value);
    return leaf;
}

fn selectDim(operation: sub_cmd.DimSubCmd, monitor: []const u8, value: candidate.Input) candidate.InputError!candidate.Lifecycle {
    switch (operation) {
        .set => try requireScalar(value),
        .on, .off => try requireToggle(value),
    }
    return candidate.sunglassesDim(monitor, value);
}

fn selectFilter(operation: sub_cmd.FilterSubCmd, monitor: []const u8, value: candidate.Input) candidate.InputError!candidate.Lifecycle {
    switch (operation) {
        .set => try requireScalar(value),
        .on, .off => try requireToggle(value),
    }
    return candidate.sunglassesFilter(monitor, value);
}

fn selectImage(operation: sub_cmd.ImageSubCmd, monitor: []const u8, value: candidate.Input) candidate.InputError!candidate.Lifecycle {
    switch (operation) {
        .set => try requirePath(value),
        .opacity => try requireScalar(value),
        .on, .off => try requireToggle(value),
        .clear => try requireNone(value),
    }
    return candidate.sunglassesImage(monitor, value);
}

fn requireNone(value: candidate.Input) candidate.InputError!void {
    return switch (value) {
        .none => {},
        .scalar, .toggle, .path => error.InputNotAccepted,
    };
}

fn requireScalar(value: candidate.Input) candidate.InputError!void {
    return switch (value) {
        .scalar => {},
        .none, .toggle, .path => error.InputNotAccepted,
    };
}

fn requireToggle(value: candidate.Input) candidate.InputError!void {
    return switch (value) {
        .toggle => {},
        .none, .scalar, .path => error.InputNotAccepted,
    };
}

fn requirePath(value: candidate.Input) candidate.InputError!void {
    return switch (value) {
        .path => {},
        .none, .scalar, .toggle => error.InputNotAccepted,
    };
}

/// restartIntent names the canonical sunglasses resident entrypoint.
pub fn restartIntent() []const u8 {
    return "wayspot sunglasses";
}

test "sunglasses mode constructs every declared child route" {
    var list = candidate.Candidate.List.empty;
    defer list.deinit();

    try collectCandidates(&list);

    try std.testing.expectEqual(@as(usize, 6), list.count);
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).concrete, list.items[0].typeOf());
    try std.testing.expectEqualStrings(restart_open, list.items[0].openPayload());
    try std.testing.expectEqualStrings("wayspot sunglasses apply", list.items[1].openPayload());
    try std.testing.expectEqualStrings("wayspot sunglasses reconcile", list.items[2].openPayload());
    try std.testing.expectEqual(std.meta.Tag(candidate.Candidate).sub_cmd, list.items[3].typeOf());
    try std.testing.expectEqualStrings("wayspot sunglasses dim", list.items[3].openPayload());
    try std.testing.expectEqualStrings("wayspot sunglasses filter", list.items[4].openPayload());
    try std.testing.expectEqualStrings("wayspot sunglasses image", list.items[5].openPayload());
}

test "sunglasses routes resolve without importing overlay runtime" {
    try std.testing.expectEqualStrings("wayspot sunglasses", resolve(.restart));
    try std.testing.expectEqualStrings("wayspot sunglasses apply", resolve(.apply));
    try std.testing.expectEqualStrings("wayspot sunglasses reconcile", resolve(.reconcile));
    try std.testing.expectEqualStrings("wayspot sunglasses dim", resolve(.{ .dim = .{ .set = {} } }));
    try std.testing.expectEqualStrings("wayspot sunglasses filter", resolve(.{ .filter = .{ .set = {} } }));
    try std.testing.expectEqualStrings("wayspot sunglasses image", resolve(.{ .image = .{ .set = {} } }));
}

test "sunglasses route selection preserves the declared Input arm" {
    const scalar = try candidate.Input.scalarInput(35, 0, 100, 1);
    const toggle = candidate.Input.toggleInput(true);
    const path = try candidate.Input.pathInput("/tmp/sunglasses.png");

    const dim = try select(.{ .dim = .{ .set = {} } }, "DP-1", scalar);
    try std.testing.expectEqual(std.meta.Tag(candidate.Input).scalar, std.meta.activeTag(dim.input()));
    try std.testing.expectEqualStrings("DP-1", dim.concreteValue().?.lifecycle.sunglasses_dim.monitor.slice());

    const filter = try select(.{ .filter = .{ .on = {} } }, "DP-1", toggle);
    try std.testing.expectEqual(std.meta.Tag(candidate.Input).toggle, std.meta.activeTag(filter.input()));

    const image = try select(.{ .image = .{ .set = {} } }, "DP-1", path);
    try std.testing.expectEqual(std.meta.Tag(candidate.Input).path, std.meta.activeTag(image.input()));

    const clear = try select(.{ .image = .{ .clear = {} } }, "DP-1", .none);
    try std.testing.expectEqual(std.meta.Tag(candidate.Input).none, std.meta.activeTag(clear.input()));

    try std.testing.expectError(error.InputNotAccepted, select(.{ .dim = .{ .set = {} } }, "DP-1", toggle));
    try std.testing.expectError(error.InputNotAccepted, select(.{ .image = .{ .set = {} } }, "DP-1", scalar));
}
