//! Env owns pure monitor control composition and dumb desktop fact values.

const std = @import("std");
const io = @import("hyprland_io");

pub const monitor = @import("monitor.zig");
pub const workspace = @import("workspace.zig");
pub const window = @import("window.zig");
pub const state = @import("state.zig");
pub const hyprland = @import("hyprland.zig");

pub const Connection = hyprland.Connection;

/// MonitorFactWake is the env-owned wake result visible to product loops.
pub const MonitorFactWake = enum { stopped, changed };

/// MonitorSourceWith composes one borrowed Source with pure monitor controls.
pub fn MonitorSourceWith(comptime Source: type) type {
    return struct {
        source: *Source,
        connection: Connection,

        const Self = @This();

        /// init retains only a pointer-stable Source address and connection facts.
        pub fn init(source: *Source, connection: Connection) Self {
            return .{ .source = source, .connection = connection };
        }

        /// deinit clears control state; the caller still owns Source cleanup.
        pub fn deinit(self: *Self) void {
            self.source = undefined;
        }

        /// runtimeDir returns the caller-owned runtime directory.
        pub fn runtimeDir(self: *const Self) []const u8 {
            return self.connection.runtime_dir;
        }

        /// queryMonitors publishes facts only after the parser completes.
        pub fn queryMonitors(self: *Self, allocator: std.mem.Allocator) hyprland.MonitorQueryError!monitor.MonitorList {
            return hyprland.queryMonitorsWith(Source, allocator, self.source, self.connection);
        }

        /// monitorStream opens a borrowed-source event stream.
        pub fn monitorStream(
            self: *Self,
            allocator: std.mem.Allocator,
        ) hyprland.EventStreamInitError!MonitorFactStreamWith(Source) {
            return MonitorFactStreamWith(Source).init(allocator, self.source, self.connection);
        }
    };
}

/// MonitorFactStreamWith owns event control state and borrows Source storage.
pub fn MonitorFactStreamWith(comptime Source: type) type {
    return struct {
        allocator: std.mem.Allocator,
        source: *Source,
        connection: Connection,
        stream: hyprland.EventStream,

        const Self = @This();

        /// init publishes no stream until event socket setup succeeds.
        pub fn init(
            allocator: std.mem.Allocator,
            source: *Source,
            connection: Connection,
        ) hyprland.EventStreamInitError!Self {
            return .{
                .allocator = allocator,
                .source = source,
                .connection = connection,
                .stream = try hyprland.EventStream.initWith(Source, allocator, source, connection),
            };
        }

        /// deinit closes the event socket once; Source remains caller-owned.
        pub fn deinit(self: *Self) io.SocketCloseError!void {
            try self.stream.deinit(Source, self.source);
        }

        /// wait returns only monitor changes or the caller stop token.
        pub fn wait(self: *Self, stop: io.StopId) (hyprland.EventWaitError || error{
            HyprlandSocketPathInvalid,
            HyprlandSocketPathTooLong,
            HyprlandSocketOpenFailed,
            HyprlandSocketConnectFailed,
        })!MonitorFactWake {
            while (true) {
                const event = self.stream.waitWith(Source, self.source, stop) catch |err| {
                    if (!eventStreamErrorRecoverable(err)) return err;
                    self.stream.deinit(Source, self.source) catch |close_err| return close_err;
                    while (true) {
                        if (try waitForEventStreamReconnect(Source, self.source, stop)) return .stopped;
                        self.stream = hyprland.EventStream.initWith(
                            Source,
                            self.allocator,
                            self.source,
                            self.connection,
                        ) catch |reconnect_err| {
                            if (!eventStreamErrorRecoverable(reconnect_err)) return reconnect_err;
                            continue;
                        };
                        break;
                    }
                    continue;
                };
                return switch (event) {
                    .stopped => .stopped,
                    .monitor_changed => .changed,
                    .workspace_changed, .window_changed => continue,
                };
            }
        }
    };
}

fn eventStreamErrorRecoverable(err: anyerror) bool {
    return switch (err) {
        error.HyprlandEventSocketClosed,
        error.HyprlandSocketOpenFailed,
        error.HyprlandSocketConnectFailed,
        => true,
        else => false,
    };
}

fn waitForEventStreamReconnect(comptime Source: type, source: *Source, stop: io.StopId) hyprland.EventWaitError!bool {
    const result = source.poll(.{
        .event = null,
        .stop = stop,
        .timeout = io.PollTimeout.fromMilliseconds(1000) catch unreachable,
    }) catch |err| switch (err) {
        error.SignalInterrupted => return false,
        else => return err,
    };
    return switch (result.stop) {
        .readable => true,
        .readable_hangup, .closed => error.HyprlandStopClosed,
        .failed => error.SystemCallFailed,
        .idle => false,
    };
}

test "pure env composition exposes only fact values" {
    std.testing.refAllDecls(monitor);
    std.testing.refAllDecls(workspace);
    std.testing.refAllDecls(window);
    std.testing.refAllDecls(state);
    std.testing.refAllDecls(hyprland);
    _ = MonitorSourceWith(io.SocketTranscript);
    _ = MonitorFactStreamWith(io.SocketTranscript);
}

test "env reconnect classifies only recoverable event loss" {
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandEventSocketClosed));
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandSocketOpenFailed));
    try std.testing.expect(eventStreamErrorRecoverable(error.HyprlandSocketConnectFailed));
    try std.testing.expect(!eventStreamErrorRecoverable(error.HyprlandEventLineTooLong));
}
