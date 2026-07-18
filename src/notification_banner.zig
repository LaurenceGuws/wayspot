//! Owns the one visible notification banner and its bounded deadline.

const std = @import("std");
const builtin = @import("builtin");
const notification = @import("notification.zig");

pub const default_timeout_ms: u32 = 5000;
pub const maximum_timeout_ms: u32 = 60_000;

pub const Record = struct {
    id: u32,
    storage: []u8,
    summary: []u8,
    body: []u8,
    timeout_ms: ?u32,

    /// Copies the text required after the DBus owner resumes receiving messages.
    pub fn init(
        allocator: std.mem.Allocator,
        source: *const notification.Notification,
    ) error{OutOfMemory}!Record {
        std.debug.assert(source.id != 0);
        const storage = try allocator.alloc(u8, source.summary.len + source.body.len);
        @memcpy(storage[0..source.summary.len], source.summary);
        @memcpy(storage[source.summary.len..], source.body);
        return .{
            .id = source.id,
            .storage = storage,
            .summary = storage[0..source.summary.len],
            .body = storage[source.summary.len..],
            .timeout_ms = timeout(source.expire_timeout),
        };
    }

    pub fn deinit(record: *Record, allocator: std.mem.Allocator) void {
        allocator.free(record.storage);
        record.* = undefined;
    }
};

pub const Visible = struct {
    record: Record,
    deadline_ms: ?u64,
};

pub const State = struct {
    visible: ?Visible = null,

    pub fn deinit(state: *State, allocator: std.mem.Allocator) void {
        if (state.visible) |*visible| visible.record.deinit(allocator);
        state.visible = null;
        state.assertValid();
    }

    /// Replaces the visible value and returns a displaced different id.
    pub fn show(
        state: *State,
        allocator: std.mem.Allocator,
        record: Record,
        now_ms: u64,
    ) ?u32 {
        state.assertValid();
        const shown = makeVisible(record, now_ms);
        if (state.visible) |*visible| {
            const displaced = visible.record.id;
            if (visible.record.id == record.id) {
                visible.record.deinit(allocator);
                visible.* = shown;
                state.assertValid();
                return null;
            }
            visible.record.deinit(allocator);
            visible.* = shown;
            state.assertValid();
            return displaced;
        }
        state.visible = shown;
        state.assertValid();
        return null;
    }

    /// Removes the sender-owned id only when it is currently visible.
    pub fn close(state: *State, allocator: std.mem.Allocator, id: u32) bool {
        state.assertValid();
        if (state.visible) |*visible| {
            if (visible.record.id == id) {
                visible.record.deinit(allocator);
                state.visible = null;
                state.assertValid();
                return true;
            }
        }
        return false;
    }

    /// Invalidates and returns the visible id exactly when its deadline is reached.
    pub fn expire(state: *State, allocator: std.mem.Allocator, now_ms: u64) ?u32 {
        state.assertValid();
        const visible = state.visible orelse return null;
        const deadline = visible.deadline_ms orelse return null;
        if (now_ms < deadline) return null;
        return state.removeVisible(allocator);
    }

    /// Invalidates and returns the visible id after direct pointer dismissal.
    pub fn dismiss(state: *State, allocator: std.mem.Allocator) ?u32 {
        state.assertValid();
        if (state.visible == null) return null;
        return state.removeVisible(allocator);
    }

    fn removeVisible(state: *State, allocator: std.mem.Allocator) u32 {
        const id = state.visible.?.record.id;
        state.visible.?.record.deinit(allocator);
        state.visible = null;
        state.assertValid();
        return id;
    }

    fn assertValid(state: *const State) void {
        if (state.visible) |visible| std.debug.assert(visible.record.id != 0);
    }
};

fn timeout(value: i32) ?u32 {
    if (value < 0) return default_timeout_ms;
    if (value == 0) return maximum_timeout_ms;
    return @min(@as(u32, @intCast(value)), maximum_timeout_ms);
}

fn makeVisible(record: Record, now_ms: u64) Visible {
    return .{
        .record = record,
        .deadline_ms = if (record.timeout_ms) |ms| now_ms +| ms else null,
    };
}

fn sampleRecord(allocator: std.mem.Allocator, id: u32, text: []const u8, timeout_ms: i32) !Record {
    var store: notification.Store = .{};
    defer store.deinit(allocator);
    _ = try store.notify(allocator, .{
        .replaces_id = 0,
        .app_name = "app",
        .app_icon = "",
        .summary = text,
        .body = "body",
        .expire_timeout = timeout_ms,
    });
    const source = store.get(1).?;
    var result = try Record.init(allocator, source);
    result.id = id;
    return result;
}

test "a different id displaces the visible record without a backlog" {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        @as(?u32, null),
        state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 1, "one", 0), 10),
    );
    try std.testing.expectEqual(
        @as(?u32, 1),
        state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 2, "two", 0), 20),
    );
    try std.testing.expectEqual(
        @as(?u32, 2),
        state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 3, "three", 0), 30),
    );
    try std.testing.expectEqual(@as(u32, 3), state.visible.?.record.id);
    try std.testing.expect(state.close(std.testing.allocator, 3));
    try std.testing.expect(state.visible == null);
    try std.testing.expect(!state.close(std.testing.allocator, 1));
}

test "replacement redraws the same id and resets its deadline" {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    _ = state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 1, "one", 100), 10);
    try std.testing.expectEqual(
        @as(?u32, null),
        state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 1, "replaced", 300), 40),
    );
    try std.testing.expectEqualStrings("replaced", state.visible.?.record.summary);
    try std.testing.expectEqual(@as(?u64, 340), state.visible.?.deadline_ms);
}

test "timeout boundaries caps and dismissal leave no presentation" {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    _ = state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 1, "persistent", 0), 0);
    try std.testing.expectEqual(@as(?u64, 60_000), state.visible.?.deadline_ms);
    try std.testing.expectEqual(
        @as(?u32, 1),
        state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 2, "default", -1), 100),
    );
    try std.testing.expectEqual(@as(?u64, 5100), state.visible.?.deadline_ms);
    try std.testing.expectEqual(@as(?u32, null), state.expire(std.testing.allocator, 5099));
    try std.testing.expectEqual(@as(?u32, 2), state.expire(std.testing.allocator, 5100));
    try std.testing.expect(state.visible == null);

    _ = state.show(std.testing.allocator, try sampleRecord(std.testing.allocator, 3, "capped", 70_000), 10);
    try std.testing.expectEqual(@as(?u64, 60_010), state.visible.?.deadline_ms);
    try std.testing.expectEqual(@as(?u32, 3), state.dismiss(std.testing.allocator));
    try std.testing.expect(state.visible == null);
}

test "generated banner histories preserve ownership and bounds" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzHistory, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzHistory({}, &empty);
}

fn fuzzHistory(_: void, smith: *std.testing.Smith) !void {
    var state: State = .{};
    defer state.deinit(std.testing.allocator);
    var now_ms: u64 = 0;
    const count = smith.value(u8) % 129;
    for (0..count) |_| {
        now_ms +|= smith.value(u16);
        switch (smith.value(u8) % 4) {
            0 => {
                const id = @as(u32, smith.value(u8)) + 1;
                const timeout_ms = @as(i32, smith.value(u16)) + 1;
                _ = state.show(
                    std.testing.allocator,
                    try sampleRecord(std.testing.allocator, id, "generated", timeout_ms),
                    now_ms,
                );
            },
            1 => _ = state.close(std.testing.allocator, @as(u32, smith.value(u8)) + 1),
            2 => _ = state.expire(std.testing.allocator, now_ms),
            3 => _ = state.dismiss(std.testing.allocator),
            else => unreachable,
        }
    }
}
