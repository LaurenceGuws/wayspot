//! Env exports dumb desktop-environment entity fact owners.

const std = @import("std");

pub const monitor = @import("monitor.zig");
pub const workspace = @import("workspace.zig");
pub const window = @import("window.zig");
pub const state = @import("state.zig");
pub const hyprland = @import("hyprland.zig");

pub const Connection = hyprland.Connection;
pub const fillState = hyprland.fillState;

/// MonitorFactWake is the env-owned wake result visible to product loops.
pub const MonitorFactWake = enum {
    stopped,
    changed,
};

/// MonitorSource owns access to env monitor facts from the active implementation source.
pub const MonitorSource = struct {
    connection: hyprland.Connection,

    /// init retains the source connection details without exposing source mechanics.
    pub fn init(connection: hyprland.Connection) MonitorSource {
        return .{ .connection = connection };
    }

    /// fromProcessEnv returns the active monitor source when the process has one.
    pub fn fromProcessEnv() ?MonitorSource {
        const runtime_dir = if (std.c.getenv("XDG_RUNTIME_DIR")) |runtime_dir_z|
            std.mem.span(runtime_dir_z)
        else
            return null;
        const signature = if (std.c.getenv("HYPRLAND_INSTANCE_SIGNATURE")) |signature_z|
            std.mem.span(signature_z)
        else
            return null;
        return init(.{
            .runtime_dir = runtime_dir,
            .signature = signature,
        });
    }

    /// runtimeDir returns the retained runtime dir used by pid-file owners.
    pub fn runtimeDir(self: MonitorSource) []const u8 {
        return self.connection.runtime_dir;
    }

    /// queryMonitors loads bounded monitor facts without exposing source parsing.
    pub fn queryMonitors(self: MonitorSource, allocator: std.mem.Allocator) !monitor.MonitorList {
        return hyprland.queryMonitors(allocator, self.connection);
    }

    /// monitorStream opens an env monitor fact stream; caller must deinit it.
    pub fn monitorStream(self: MonitorSource, allocator: std.mem.Allocator) !MonitorFactStream {
        return MonitorFactStream.init(allocator, self.connection);
    }
};

/// MonitorFactStream maps implementation events to monitor-only wakes.
pub const MonitorFactStream = struct {
    allocator: std.mem.Allocator,
    connection: hyprland.Connection,
    stream: hyprland.EventStream,

    /// init opens the source event stream behind an env monitor-fact boundary.
    pub fn init(allocator: std.mem.Allocator, connection: hyprland.Connection) !MonitorFactStream {
        return .{
            .allocator = allocator,
            .connection = connection,
            .stream = try hyprland.EventStream.init(allocator, connection),
        };
    }

    /// deinit closes the retained stream once.
    pub fn deinit(self: *MonitorFactStream) void {
        self.stream.deinit();
    }

    /// wait returns only monitor fact changes or caller stop.
    pub fn wait(self: *MonitorFactStream, stop_fd: std.posix.fd_t) !MonitorFactWake {
        while (true) {
            const event = self.stream.wait(stop_fd) catch |err| {
                if (!eventStreamErrorRecoverable(err)) return err;
                self.stream.deinit();
                while (true) {
                    if (try waitForEventStreamReconnect(stop_fd)) return .stopped;
                    self.stream = hyprland.EventStream.init(self.allocator, self.connection) catch |reconnect_err| {
                        if (!eventStreamErrorRecoverable(reconnect_err)) return reconnect_err;
                        continue;
                    };
                    break;
                }
                continue;
            };
            switch (event) {
                .stopped => return .stopped,
                .monitor_changed => return .changed,
                .workspace_changed, .window_changed => {},
            }
        }
    }
};

const event_stream_reconnect_wait_ms: i32 = 1000;

fn eventStreamErrorRecoverable(err: anyerror) bool {
    return switch (err) {
        error.HyprlandEventSocketClosed,
        error.HyprlandSocketOpenFailed,
        error.HyprlandSocketConnectFailed,
        => true,
        else => false,
    };
}

fn waitForEventStreamReconnect(stop_fd: std.posix.fd_t) !bool {
    var poll_fds = [_]std.posix.pollfd{
        .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
    };
    while (true) {
        poll_fds[0].revents = 0;
        const ready = std.os.linux.poll(poll_fds[0..].ptr, 1, event_stream_reconnect_wait_ms);
        switch (std.os.linux.errno(ready)) {
            .SUCCESS => return ready > 0 and (poll_fds[0].revents & std.posix.POLL.IN) != 0,
            .INTR => continue,
            else => return error.EnvironmentReconnectWaitFailed,
        }
    }
}

test "env declarations are reachable" {
    std.testing.refAllDecls(monitor);
    std.testing.refAllDecls(workspace);
    std.testing.refAllDecls(window);
    std.testing.refAllDecls(state);
    std.testing.refAllDecls(hyprland);
}

test "environment reconnects only external event socket loss" {
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandEventSocketClosed));
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandSocketOpenFailed));
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandSocketConnectFailed));
    try std.testing.expect(!eventStreamErrorRecoverable(error.HyprlandEventLineTooLong));
}
