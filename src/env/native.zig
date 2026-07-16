//! Env production wrappers bind pure monitor control to SocketSource.

const std = @import("std");
const env = @import("wayspot_env");
const io = @import("hyprland_io");
const native = @import("hyprland_native");

pub const monitor = env.monitor;
pub const workspace = env.workspace;
pub const window = env.window;
pub const state = env.state;
pub const hyprland = env.hyprland;
pub const Connection = env.Connection;
pub const MonitorFactWake = env.MonitorFactWake;

/// MonitorSource owns one pointer-stable native SocketSource.
pub const MonitorSource = struct {
    /// source owns all native request/event socket mappings.
    source: native.SocketSource,
    /// connection stores borrowed runtime address facts.
    connection: Connection,

    /// init creates an unopened production source.
    pub fn init(connection: Connection) MonitorSource {
        return .{ .source = native.SocketSource.init(), .connection = connection };
    }

    /// fromProcessEnv reads the active Hyprland address without owning the environment.
    pub fn fromProcessEnv() ?MonitorSource {
        const runtime_dir = if (std.c.getenv("XDG_RUNTIME_DIR")) |value| std.mem.span(value) else return null;
        const signature = if (std.c.getenv("HYPRLAND_INSTANCE_SIGNATURE")) |value| std.mem.span(value) else return null;
        return init(.{ .runtime_dir = runtime_dir, .signature = signature });
    }

    /// deinit closes every remaining native source mapping once.
    pub fn deinit(self: *MonitorSource) io.SocketCloseError!void {
        return self.source.deinit();
    }

    /// runtimeDir returns the retained runtime directory.
    pub fn runtimeDir(self: *const MonitorSource) []const u8 {
        return self.connection.runtime_dir;
    }

    /// queryMonitors returns facts through the pure owner composition.
    pub fn queryMonitors(self: *MonitorSource, allocator: std.mem.Allocator) !monitor.MonitorList {
        var control = env.MonitorSourceWith(native.SocketSource).init(&self.source, self.connection);
        defer control.deinit();
        return control.queryMonitors(allocator);
    }

    /// monitorStream opens a stream that borrows this source owner.
    pub fn monitorStream(self: *MonitorSource, allocator: std.mem.Allocator) !MonitorFactStream {
        var control = env.MonitorSourceWith(native.SocketSource).init(&self.source, self.connection);
        const inner = try control.monitorStream(allocator);
        control.deinit();
        return .{ .inner = inner };
    }
};

/// MonitorFactStream owns event control while borrowing MonitorSource.source.
pub const MonitorFactStream = struct {
    /// inner is the pure event control composition.
    inner: env.MonitorFactStreamWith(native.SocketSource),

    /// deinit closes the event source once and leaves the parent source owner intact.
    pub fn deinit(self: *MonitorFactStream) io.SocketCloseError!void {
        try self.inner.deinit();
    }

    /// wait converts the caller's stop descriptor into the borrowed StopId contract.
    pub fn wait(self: *MonitorFactStream, stop_fd: std.posix.fd_t) !MonitorFactWake {
        const stop = io.StopId.fromFd(stop_fd) catch return error.SystemCallFailed;
        return self.inner.wait(stop);
    }
};

/// fillState refreshes an environment state through the production source.
pub fn fillState(allocator: std.mem.Allocator, connection: Connection, environment_state: *env.state.EnvState) !void {
    var source_owner = MonitorSource.init(connection);
    defer source_owner.deinit() catch |err| std.log.debug("hyprland source close failed err={s}", .{@errorName(err)});
    try hyprland.fillStateWith(native.SocketSource, allocator, &source_owner.source, connection, environment_state);
}

test "production env wrapper owns native source storage" {
    var source = MonitorSource.init(.{ .runtime_dir = "/run/user/1000", .signature = "instance" });
    try source.deinit();
}
