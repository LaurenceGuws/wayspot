//! A picker invocation owns its fresh application facts and native layer.
//! Allocate at a stable address; close the surface before executing selection.
const std = @import("std");
const apps = @import("../apps/catalog.zig");
const desktop_files = @import("../apps/desktop_files.zig");
const launch = @import("../apps/launch.zig");
const notification = @import("../notifications/root.zig");
const picker = @import("root.zig");
const navigator = @import("navigator.zig");
const View = @import("view.zig").Native;
const UiOwner = @import("../ui/owner.zig");
const Self = @This();

process: std.process.Init,
applications: apps.List,
terminal: ?[]const u8,
home: []const u8,
state: picker.State,
view: View,
deadline: u64 = 0,

pub fn open(init: std.process.Init, ui_owner: *UiOwner, tray_enabled: bool) !*Self {
    const self = try init.gpa.create(Self);
    errdefer init.gpa.destroy(self);
    const home = init.environ_map.get("HOME") orelse return error.HomeMissing;
    var files = try desktop_files.collect(init.gpa, init.io, .{
        .home = home,
        .data_home = init.environ_map.get("XDG_DATA_HOME"),
        .data_dirs = init.environ_map.get("XDG_DATA_DIRS"),
    });
    defer files.deinit();
    self.applications = try apps.load(init.gpa, files.items.items, init.environ_map.get("XDG_CURRENT_DESKTOP"));
    errdefer self.applications.deinit();
    try desktop_files.applyTryExec(init.io, init.environ_map.get("PATH"), &self.applications);
    const terminal = try desktop_files.applyTerminal(init.io, init.environ_map.get("PATH"), init.environ_map.get("TERMINAL"), &self.applications);
    try launch.apply(&self.applications, terminal, home);
    self.process = init;
    self.terminal = terminal;
    self.home = home;
    self.state = .{
        .allocator = init.gpa,
        .self_pid = @intCast(std.os.linux.getpid()),
        .window_backend = navigator.backendForSession(init.environ_map.get("XDG_SESSION_DESKTOP")),
        .applications = self.applications.slice(),
    };
    errdefer self.state.deinit();
    self.view = .{
        .ui_owner = ui_owner,
        .applications = self.applications.slice(),
        .allocator = init.gpa,
        .io = init.io,
        .home = home,
        .tray_enabled = tray_enabled,
    };
    if (tray_enabled) {
        const fd = std.os.linux.eventfd(0, std.os.linux.EFD.CLOEXEC | std.os.linux.EFD.NONBLOCK);
        if (std.os.linux.errno(fd) != .SUCCESS) return error.TrayWakeOpenFailed;
        self.view.tray_wake_fd = @intCast(fd);
    }
    errdefer if (self.view.tray_wake_fd >= 0) {
        _ = std.os.linux.close(self.view.tray_wake_fd);
    };
    try self.view.init();
    errdefer self.view.quit();
    try self.view.create();
    errdefer self.view.destroy();
    try self.view.startText();
    errdefer self.view.stopText() catch {};
    try self.state.begin();
    try self.draw();
    return self;
}

pub fn finish(self: *Self, selected: picker.Action) !void {
    const allocator = self.process.gpa;
    defer allocator.destroy(self);
    defer self.applications.deinit();
    defer self.state.deinit();
    const stop_result = self.view.stopText();
    const destroy_result = if (selected == .focus and (if (stop_result) |_| true else |_| false)) self.view.destroyForFocus() else blk: {
        self.view.destroy();
        break :blk {};
    };
    self.view.quit();
    if (self.view.tray_wake_fd >= 0) _ = std.os.linux.close(self.view.tray_wake_fd);
    try stop_result;
    try destroy_result;
    switch (selected) {
        .dismiss => {},
        .launch => |index| {
            var process: launch.Detached = .{ .io = self.process.io, .environ_map = self.process.environ_map };
            try launch.spawn(&process, &self.applications.slice()[index], self.terminal, self.home);
        },
        .focus => |id| try navigator.focus(navigator.Native{ .io = self.process.io, .environ_map = self.process.environ_map }, allocator, self.state.window_backend, id.slice()),
        else => unreachable,
    }
}

pub fn readHistory(self: *Self) !notification.History {
    return notification.inspect(self.process.gpa, self.process.io, self.process.environ_map.get("XDG_STATE_HOME"), self.home);
}

pub fn draw(self: *Self) !void {
    try self.view.draw(&self.state.frame());
    self.deadline = now(self.process.io) + @as(u64, @intCast(self.view.waitTimeout()));
}

pub fn advance(self: *Self, events: *const picker.Events) !picker.Action {
    const action = try self.state.advance(self, navigator.Native{ .io = self.process.io, .environ_map = self.process.environ_map }, events);
    if (action == .draw) try self.draw();
    return action;
}

pub fn trayReady(self: *Self) !bool {
    if (self.view.tray_wake_fd < 0) return false;
    var value: u64 = undefined;
    const bytes = std.mem.asBytes(&value);
    const result = std.os.linux.read(self.view.tray_wake_fd, bytes.ptr, bytes.len);
    switch (std.os.linux.errno(result)) {
        .SUCCESS => if (result != bytes.len) return error.TrayWakeReadFailed,
        .AGAIN, .INTR => {},
        else => return error.TrayWakeReadFailed,
    }
    return self.view.trayReady();
}

/// A held native key supplies its exact repeat deadline; none while idle.
pub fn repeatWake(self: *const Self) ?u64 {
    return self.view.repeatWake();
}

fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.awake.now(io).toMilliseconds());
}
