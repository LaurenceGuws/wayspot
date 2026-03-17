const std = @import("std");
const ipc_control = @import("../ipc/control.zig");

pub const State = struct {
    allocator: std.mem.Allocator,
    exe_path: []u8,
    config_path: []u8,
    source_dir: []u8,
    child: ?std.process.Child = null,

    pub fn init(
        allocator: std.mem.Allocator,
        exe_path: []const u8,
        config_path: []const u8,
        source_dir: []const u8,
    ) !State {
        return .{
            .allocator = allocator,
            .exe_path = try allocator.dupe(u8, exe_path),
            .config_path = try allocator.dupe(u8, config_path),
            .source_dir = try allocator.dupe(u8, source_dir),
        };
    }

    pub fn deinit(self: *State) void {
        self.stop() catch {};
        self.allocator.free(self.exe_path);
        self.allocator.free(self.config_path);
        self.allocator.free(self.source_dir);
    }

    pub fn toggle(self: *State) !bool {
        self.reconcile();
        if (self.isRunning()) {
            try self.stop();
            return false;
        }
        try self.start();
        return true;
    }

    pub fn isRunning(self: *State) bool {
        self.reconcile();
        return self.child != null;
    }

    pub fn start(self: *State) !void {
        self.reconcile();
        if (self.child != null) return;

        var child = std.process.Child.init(
            &.{ self.exe_path, "--wallpaper-slideshow", "--config", self.config_path, "--source", self.source_dir },
            self.allocator,
        );
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        try child.spawn();
        self.child = child;
    }

    pub fn stop(self: *State) !void {
        self.reconcile();
        if (self.child == null) return;

        var child = self.child.?;
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        self.child = null;
    }

    fn reconcile(self: *State) void {
        if (self.child == null) return;

        const pid = self.child.?.id;
        const result = std.posix.waitpid(pid, std.posix.W.NOHANG);
        if (result.pid == 0) return;

        self.child = null;
    }
};

pub fn toggleViaDaemon(allocator: std.mem.Allocator) !?bool {
    const response = ipc_control.executeCommand(allocator, .slideshow_toggle) catch |err| switch (err) {
        error.FileNotFound,
        error.ConnectTimeout,
        error.ConnectionRefused,
        error.NoSocketSupport => return null,
        else => return err,
    };
    defer {
        allocator.free(response.code);
        allocator.free(response.message);
    }
    if (!response.ok or !std.mem.eql(u8, response.code, "ok")) return error.ToggleRejected;
    if (std.mem.eql(u8, response.message, "started")) {
        showStatusNotification(allocator, true);
        return true;
    }
    if (std.mem.eql(u8, response.message, "stopped")) {
        showStatusNotification(allocator, false);
        return false;
    }
    return error.BadResponse;
}

pub fn startViaDaemon(allocator: std.mem.Allocator) !?void {
    const response = ipc_control.executeCommand(allocator, .slideshow_start) catch |err| switch (err) {
        error.FileNotFound,
        error.ConnectTimeout,
        error.ConnectionRefused,
        error.NoSocketSupport => return null,
        else => return err,
    };
    defer {
        allocator.free(response.code);
        allocator.free(response.message);
    }
    if (!response.ok or !std.mem.eql(u8, response.code, "ok")) return error.StartRejected;
    showStatusNotification(allocator, true);
}

fn showStatusNotification(allocator: std.mem.Allocator, started: bool) void {
    const title = "Wallpaper slideshow";
    const body = if (started) "Started" else "Stopped";
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "notify-send", "-u", "low", "-t", "1200", title, body },
        .max_output_bytes = 0,
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}
