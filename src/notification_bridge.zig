//! Transfers owned notification values between the DBus worker and SDL main thread.

const std = @import("std");
const banner = @import("notification_banner.zig");
const notification = @import("notification.zig");
const service = @import("notification_dbus.zig");

pub const capacity = 16;

comptime {
    std.debug.assert(capacity == service.banner_event_capacity);
}

pub const ToMain = union(enum) {
    show: banner.Record,
    replace: banner.Record,
    close: u32,
    stop,
    failed,

    pub fn deinit(event: *ToMain, allocator: std.mem.Allocator) void {
        switch (event.*) {
            .show, .replace => |*record| record.deinit(allocator),
            else => {},
        }
        event.* = undefined;
    }
};

pub const ToDbus = union(enum) {
    closed: struct { id: u32, reason: service.CloseReason },
    failed,
};

pub const Bridge = struct {
    io: std.Io,
    to_main_buffer: [capacity]ToMain = undefined,
    to_dbus_buffer: [capacity]ToDbus = undefined,
    to_main: std.Io.Queue(ToMain),
    to_dbus: std.Io.Queue(ToDbus),
    wake_lock: std.Io.Mutex = .init,
    sdl_ready: bool = false,
    wake_failed: std.atomic.Value(bool) = .init(false),
    wake: ?*const fn () bool = null,

    /// Binds both queues to their final in-place buffers before either thread starts.
    pub fn init(bridge: *Bridge, io: std.Io) void {
        bridge.io = io;
        bridge.to_main_buffer = undefined;
        bridge.to_dbus_buffer = undefined;
        bridge.to_main = .init(&bridge.to_main_buffer);
        bridge.to_dbus = .init(&bridge.to_dbus_buffer);
        bridge.wake_lock = .init;
        bridge.sdl_ready = false;
        bridge.wake_failed = .init(false);
        bridge.wake = null;
    }

    /// Closes both directions and releases every presentation still in transit.
    pub fn deinit(bridge: *Bridge, allocator: std.mem.Allocator) void {
        bridge.to_main.close(bridge.io);
        bridge.to_dbus.close(bridge.io);
        var events: [capacity]ToMain = undefined;
        while (true) {
            const count = bridge.to_main.get(bridge.io, &events, 0) catch |err| switch (err) {
                error.Closed => break,
                error.Canceled => unreachable,
            };
            if (count == 0) break;
            for (events[0..count]) |*event| event.deinit(allocator);
        }
    }

    /// Publishes a complete owned banner copy before the DBus reply.
    pub fn show(
        bridge: *Bridge,
        allocator: std.mem.Allocator,
        source: *const notification.Notification,
        replaces: bool,
    ) !void {
        var record = try banner.Record.init(allocator, source);
        errdefer record.deinit(allocator);
        try bridge.publish(if (replaces) .{ .replace = record } else .{ .show = record });
    }

    /// Publishes one sender close after the active DBus record has been invalidated.
    pub fn close(bridge: *Bridge, id: u32) !void {
        try bridge.publish(.{ .close = id });
    }

    /// Receives at most one banner close without delaying DBus intake.
    pub fn next(bridge: *Bridge) !service.BannerEvent {
        var events: [1]ToDbus = undefined;
        const count = try bridge.to_dbus.get(bridge.io, &events, 0);
        if (count == 0) return .none;
        return switch (events[0]) {
            .closed => |value| .{ .closed = .{ .id = value.id, .reason = value.reason } },
            .failed => .failed,
        };
    }

    /// Sleeps until the main thread owns one DBus event.
    pub fn receive(bridge: *Bridge) !ToMain {
        return bridge.to_main.getOne(bridge.io);
    }

    /// Receives queued DBus events without sleeping.
    pub fn drain(bridge: *Bridge, events: []ToMain) !usize {
        return bridge.to_main.get(bridge.io, events, 0);
    }

    /// Returns an expired or dismissed id to the DBus record owner.
    pub fn closed(bridge: *Bridge, id: u32, reason: service.CloseReason) !void {
        try bridge.to_dbus.putOne(bridge.io, .{ .closed = .{ .id = id, .reason = reason } });
    }

    /// Stops the DBus worker when the main-thread banner owner fails.
    pub fn bannerFailed(bridge: *Bridge) void {
        bridge.to_dbus.putOneUncancelable(bridge.io, .failed) catch |err| switch (err) {
            error.Closed => {},
        };
    }

    /// Wakes the main thread after an orderly DBus worker stop.
    pub fn workerStopped(bridge: *Bridge) !void {
        try bridge.publish(.stop);
    }

    /// Wakes the main thread after a DBus worker failure when the queue remains open.
    pub fn workerFailed(bridge: *Bridge) void {
        bridge.publish(.failed) catch |err| switch (err) {
            error.Closed, error.Canceled => {},
        };
    }

    /// Publishes the registered SDL wake only after native initialization is complete.
    pub fn ready(bridge: *Bridge, wake: *const fn () bool) void {
        bridge.wake_lock.lockUncancelable(bridge.io);
        defer bridge.wake_lock.unlock(bridge.io);
        bridge.wake = wake;
        bridge.sdl_ready = true;
    }

    /// Prevents new SDL calls and waits for an in-flight wake to finish.
    pub fn pause(bridge: *Bridge) void {
        bridge.wake_lock.lockUncancelable(bridge.io);
        defer bridge.wake_lock.unlock(bridge.io);
        bridge.sdl_ready = false;
        bridge.wake = null;
    }

    /// Returns and clears one native wake failure without changing queue ownership.
    pub fn takeWakeFailure(bridge: *Bridge) bool {
        return bridge.wake_failed.swap(false, .acq_rel);
    }

    fn publish(bridge: *Bridge, event: ToMain) !void {
        try bridge.to_main.putOne(bridge.io, event);
        bridge.wake_lock.lockUncancelable(bridge.io);
        defer bridge.wake_lock.unlock(bridge.io);
        if (bridge.sdl_ready) {
            const wake = bridge.wake orelse {
                bridge.wake_failed.store(true, .release);
                return;
            };
            if (!wake()) bridge.wake_failed.store(true, .release);
        }
    }
};

test "bridge preserves owned records and close reasons" {
    var bridge: Bridge = undefined;
    bridge.init(std.testing.io);
    defer bridge.deinit(std.testing.allocator);
    var store: notification.Store = .{};
    defer store.deinit(std.testing.allocator);
    const id = try store.notify(std.testing.allocator, .{
        .replaces_id = 0,
        .app_name = "app",
        .app_icon = "",
        .summary = "summary",
        .body = "body",
        .expire_timeout = 25,
    });
    try bridge.show(std.testing.allocator, store.get(id).?, false);
    var event = try bridge.receive();
    defer event.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("summary", event.show.summary);

    try bridge.closed(id, .dismissed);
    try std.testing.expectEqual(
        service.BannerEvent{ .closed = .{ .id = id, .reason = .dismissed } },
        try bridge.next(),
    );
    try std.testing.expectEqual(service.BannerEvent.none, try bridge.next());
}

test "SDL readiness wakes only after queue ownership transfers" {
    const Wake = struct {
        var count: usize = 0;
        fn call() bool {
            count += 1;
            return true;
        }
    };
    Wake.count = 0;
    var bridge: Bridge = undefined;
    bridge.init(std.testing.io);
    defer bridge.deinit(std.testing.allocator);
    try bridge.close(1);
    try std.testing.expectEqual(@as(usize, 0), Wake.count);
    bridge.ready(Wake.call);
    try bridge.close(2);
    try std.testing.expectEqual(@as(usize, 1), Wake.count);
}

test "failed wake preserves queue ownership and reports separately" {
    const Wake = struct {
        fn call() bool {
            return false;
        }
    };
    var bridge: Bridge = undefined;
    bridge.init(std.testing.io);
    defer bridge.deinit(std.testing.allocator);
    bridge.ready(Wake.call);
    try bridge.close(7);
    try std.testing.expect(bridge.takeWakeFailure());
    try std.testing.expect(!bridge.takeWakeFailure());
    var event = try bridge.receive();
    defer event.deinit(std.testing.allocator);
    try std.testing.expectEqual(std.meta.Tag(ToMain).close, std.meta.activeTag(event));
}
