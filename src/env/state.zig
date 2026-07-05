//! State owns bounded env snapshots without relationship rules.

const std = @import("std");
const monitor_facts = @import("monitor.zig");
const workspace_facts = @import("workspace.zig");
const window_facts = @import("window.zig");

/// EnvSnapshot owns one retained set of dumb env entity facts.
pub const EnvSnapshot = struct {
    monitors: monitor_facts.MonitorList = .{},
    workspaces: workspace_facts.WorkspaceList = .{},
    windows: window_facts.WindowList = .{},

    /// monitorAt returns a retained monitor fact by index.
    pub fn monitorAt(self: *const EnvSnapshot, index: u32) ?*const monitor_facts.Monitor {
        return self.monitors.at(index);
    }

    /// workspaceAt returns a retained workspace fact by index.
    pub fn workspaceAt(self: *const EnvSnapshot, index: u32) ?*const workspace_facts.Workspace {
        return self.workspaces.at(index);
    }

    /// windowAt returns a retained window fact by index.
    pub fn windowAt(self: *const EnvSnapshot, index: u32) ?*const window_facts.Window {
        return self.windows.at(index);
    }
};

/// EnvState owns the current mutable env facts for processes that need them.
pub const EnvState = struct {
    snapshot: EnvSnapshot = .{},

    /// refreshMonitors replaces only monitor facts; caller owns source loading.
    pub fn refreshMonitors(self: *EnvState, monitors: monitor_facts.MonitorList) void {
        self.snapshot.monitors = monitors;
    }

    /// refreshFromHyprlandFacts replaces the whole snapshot with parsed Hyprland facts.
    pub fn refreshFromHyprlandFacts(
        self: *EnvState,
        monitors: monitor_facts.MonitorList,
        workspaces: workspace_facts.WorkspaceList,
        windows: window_facts.WindowList,
    ) void {
        self.refreshFromFacts(monitors, workspaces, windows);
    }

    /// refreshFromFacts replaces the whole snapshot with caller-provided facts.
    pub fn refreshFromFacts(
        self: *EnvState,
        monitors: monitor_facts.MonitorList,
        workspaces: workspace_facts.WorkspaceList,
        windows: window_facts.WindowList,
    ) void {
        self.snapshot = .{
            .monitors = monitors,
            .workspaces = workspaces,
            .windows = windows,
        };
    }
};

test "state snapshot stores monitor source facts through accessors" {
    var monitors = monitor_facts.MonitorList{};
    const size = try monitor_facts.MonitorSize.init(1280, 720);
    var monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", size);
    monitor.scale = try monitor_facts.MonitorScale.init(1.25);
    try monitor.addCurrentActiveWorkspace(.{ .id = 7 });
    try monitors.append(monitor);

    var state = EnvState{};
    state.refreshMonitors(monitors);

    const retained = state.snapshot.monitorAt(0) orelse return error.MissingMonitorFact;
    try std.testing.expectEqual(@as(i32, 1280), retained.size.width);
    try std.testing.expectEqual(@as(i32, 720), retained.size.height);
    try std.testing.expectEqual(@as(f64, 1.25), retained.scale.?.value);
    try std.testing.expectEqual(@as(u32, 1), retained.current_active.count);
    try std.testing.expectEqual(@as(i32, 7), retained.current_active.items[0].id);
    try std.testing.expectEqual(@as(?*const monitor_facts.Monitor, null), state.snapshot.monitorAt(1));
}

test "state snapshot stores Hyprland workspace and window facts without adding refs" {
    var monitors = monitor_facts.MonitorList{};
    var monitor = try monitor_facts.Monitor.init(.{ .value = 1 }, "DP-1", try monitor_facts.MonitorSize.init(1920, 1080));
    try monitor.addCurrentActiveWorkspace(.{ .id = 7 });
    try monitors.append(monitor);

    var workspaces = workspace_facts.WorkspaceList{};
    var workspace = try workspace_facts.Workspace.init(.{ .value = 7 }, "main");
    try workspace.visible_on.append(.{ .id = 1 });
    try workspace.windows.append(.{ .id = 0xabc });
    try workspaces.append(workspace);
    try workspaces.append(try workspace_facts.Workspace.init(.{ .value = 8 }, "empty"));

    var windows = window_facts.WindowList{};
    var window = try window_facts.Window.init(.{ .value = 0xabc }, "foot", "shell", try window_facts.WindowSize.init(640, 480));
    window.visible = true;
    window.focused = true;
    window.workspace = .{ .id = 7 };
    try windows.append(window);
    try windows.append(try window_facts.Window.init(.{ .value = 0xdef }, "hidden", "", try window_facts.WindowSize.init(0, 0)));

    var state = EnvState{};
    state.refreshFromHyprlandFacts(monitors, workspaces, windows);

    const retained_monitor = state.snapshot.monitorAt(0) orelse return error.MissingMonitorFact;
    try std.testing.expectEqual(@as(u32, 1), retained_monitor.current_active.count);
    try std.testing.expectEqual(@as(i32, 7), retained_monitor.current_active.items[0].id);

    const retained_workspace = state.snapshot.workspaceAt(0) orelse return error.MissingWorkspaceFact;
    try std.testing.expectEqual(@as(u32, 1), retained_workspace.visible_on.count);
    try std.testing.expectEqual(@as(i32, 1), retained_workspace.visible_on.items[0].id);
    try std.testing.expectEqual(@as(u32, 1), retained_workspace.windows.count);
    try std.testing.expectEqual(@as(u64, 0xabc), retained_workspace.windows.items[0].id);

    const empty_workspace = state.snapshot.workspaceAt(1) orelse return error.MissingWorkspaceFact;
    try std.testing.expectEqual(@as(u32, 0), empty_workspace.visible_on.count);
    try std.testing.expectEqual(@as(u32, 0), empty_workspace.windows.count);
    try std.testing.expectEqual(@as(?*const workspace_facts.Workspace, null), state.snapshot.workspaceAt(2));

    const retained_window = state.snapshot.windowAt(0) orelse return error.MissingWindowFact;
    try std.testing.expectEqual(@as(i32, 640), retained_window.size.width);
    try std.testing.expectEqual(@as(i32, 480), retained_window.size.height);
    try std.testing.expect(retained_window.visible);
    try std.testing.expect(retained_window.focused);
    try std.testing.expectEqual(@as(i32, 7), retained_window.workspace.?.id);

    const missing_ref_window = state.snapshot.windowAt(1) orelse return error.MissingWindowFact;
    try std.testing.expectEqual(@as(i32, 0), missing_ref_window.size.width);
    try std.testing.expectEqual(@as(i32, 0), missing_ref_window.size.height);
    try std.testing.expect(!missing_ref_window.visible);
    try std.testing.expect(!missing_ref_window.focused);
    try std.testing.expectEqual(@as(?window_facts.WorkspaceRef, null), missing_ref_window.workspace);
    try std.testing.expectEqual(@as(?*const window_facts.Window, null), state.snapshot.windowAt(2));
}
