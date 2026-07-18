//! Runs deterministic banner sessions against one concrete window and event owner.

const std = @import("std");
const banner = @import("notification_banner.zig");
const bridge_mod = @import("notification_bridge.zig");

/// Event is the complete banner input vocabulary returned by a window owner.
pub const Event = enum {
    wake,
    dismiss,
    redraw,
    timeout,
    device_lost,
};

/// Sleeps between notifications and starts exactly one bounded window session when needed.
pub fn run(
    window: anytype,
    bridge: anytype,
    allocator: std.mem.Allocator,
) !void {
    var state: banner.State = .{};
    defer state.deinit(allocator);

    while (true) {
        var first = try bridge.receive();
        switch (first) {
            .stop => {
                first.deinit(allocator);
                return;
            },
            .failed => {
                first.deinit(allocator);
                return error.DbusWorkerFailed;
            },
            else => {},
        }

        window.start(bridge) catch |err| {
            first.deinit(allocator);
            return err;
        };
        var owns_first = true;
        const result = session(window, bridge, allocator, &state, &first, &owns_first);
        if (owns_first) first.deinit(allocator);
        window.stop(bridge);
        switch (try result) {
            .idle => {},
            .stop => return,
        }
    }
}

const SessionResult = enum { idle, stop };

fn session(
    window: anytype,
    bridge: anytype,
    allocator: std.mem.Allocator,
    state: *banner.State,
    first: *bridge_mod.ToMain,
    owns_first: *bool,
) !SessionResult {
    try apply(state, bridge, allocator, first, window.now(), owns_first);
    try window.draw(state.visible);

    while (true) {
        if (bridge.takeWakeFailure()) return error.WakeFailed;
        const now = window.now();
        if (state.expire(allocator, now)) |id| {
            try bridge.closed(id, .expired);
            try window.draw(state.visible);
        }
        if (state.visible == null) return .idle;

        switch (try window.wait(state.visible.?.deadline_ms.?)) {
            .wake => {
                var events: [bridge_mod.capacity]bridge_mod.ToMain = undefined;
                const count = try bridge.drain(&events);
                for (events[0..count], 0..) |*event, index| {
                    var owned = true;
                    defer if (owned) event.deinit(allocator);
                    switch (event.*) {
                        .stop => {
                            deinitEvents(events[index + 1 .. count], allocator);
                            return .stop;
                        },
                        .failed => {
                            deinitEvents(events[index + 1 .. count], allocator);
                            return error.DbusWorkerFailed;
                        },
                        else => try apply(state, bridge, allocator, event, window.now(), &owned),
                    }
                }
                try window.draw(state.visible);
            },
            .dismiss => {
                if (state.dismiss(allocator)) |id| {
                    try bridge.closed(id, .dismissed);
                    try window.draw(state.visible);
                }
            },
            .redraw => try window.draw(state.visible),
            .timeout => {},
            .device_lost => return error.DeviceLost,
        }
    }
}

fn deinitEvents(events: []bridge_mod.ToMain, allocator: std.mem.Allocator) void {
    for (events) |*event| event.deinit(allocator);
}

const Notice = struct {
    id: u32,
    text: []const u8,
    timeout_ms: u32,
};

const Input = union(enum) {
    show: Notice,
    replace: Notice,
    close: u32,
    stop,
    failed,
};

const Step = union(enum) {
    receive: Input,
    start: bool,
    now: u64,
    draw: ?u32,
    wake_failed: bool,
    wait: Event,
    drain: []const Input,
    closed: struct { id: u32, reason: @import("notification_dbus.zig").CloseReason },
    stop,
};

const Transcript = struct {
    steps: []const Step,
    index: usize = 0,
    mismatch: bool = false,

    fn receive(transcript: *Transcript) !bridge_mod.ToMain {
        return transcript.makeInput(switch (try transcript.next()) {
            .receive => |input| input,
            else => return error.TranscriptMismatch,
        });
    }

    fn start(transcript: *Transcript, _: anytype) !void {
        const ok = switch (try transcript.next()) {
            .start => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (!ok) return error.StartFailed;
    }

    fn stop(transcript: *Transcript, _: anytype) void {
        transcript.consume(.stop);
    }

    fn now(transcript: *Transcript) u64 {
        return switch (transcript.next() catch return 0) {
            .now => |value| value,
            else => {
                transcript.mismatch = true;
                return 0;
            },
        };
    }

    fn draw(transcript: *Transcript, visible: ?banner.Visible) !void {
        const expected = switch (try transcript.next()) {
            .draw => |id| id,
            else => return error.TranscriptMismatch,
        };
        const actual = if (visible) |value| value.record.id else null;
        if (expected != actual) return error.TranscriptMismatch;
    }

    fn takeWakeFailure(transcript: *Transcript) bool {
        return switch (transcript.next() catch return true) {
            .wake_failed => |failed| failed,
            else => {
                transcript.mismatch = true;
                return true;
            },
        };
    }

    fn wait(transcript: *Transcript, _: u64) !Event {
        return switch (try transcript.next()) {
            .wait => |event| event,
            else => error.TranscriptMismatch,
        };
    }

    fn drain(transcript: *Transcript, events: []bridge_mod.ToMain) !usize {
        const inputs = switch (try transcript.next()) {
            .drain => |values| values,
            else => return error.TranscriptMismatch,
        };
        if (inputs.len > events.len) return error.TranscriptMismatch;
        var count: usize = 0;
        errdefer deinitEvents(events[0..count], std.testing.allocator);
        for (inputs) |input| {
            events[count] = try transcript.makeInput(input);
            count += 1;
        }
        return count;
    }

    fn closed(
        transcript: *Transcript,
        id: u32,
        reason: @import("notification_dbus.zig").CloseReason,
    ) !void {
        const expected = switch (try transcript.next()) {
            .closed => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (expected.id != id or expected.reason != reason) return error.TranscriptMismatch;
    }

    fn makeInput(_: *Transcript, value: Input) !bridge_mod.ToMain {
        return switch (value) {
            .show => |notice| .{ .show = try makeRecord(notice) },
            .replace => |notice| .{ .replace = try makeRecord(notice) },
            .close => |id| .{ .close = id },
            .stop => .stop,
            .failed => .failed,
        };
    }

    fn next(transcript: *Transcript) !Step {
        if (transcript.index == transcript.steps.len) {
            transcript.mismatch = true;
            return error.TranscriptMismatch;
        }
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }

    fn consume(transcript: *Transcript, tag: std.meta.Tag(Step)) void {
        const step = transcript.next() catch return;
        if (std.meta.activeTag(step) != tag) transcript.mismatch = true;
    }

    fn done(transcript: *const Transcript) !void {
        if (transcript.mismatch or transcript.index != transcript.steps.len) {
            return error.TranscriptMismatch;
        }
    }
};

fn makeRecord(notice: Notice) !banner.Record {
    const storage = try std.testing.allocator.dupe(u8, notice.text);
    return .{
        .id = notice.id,
        .storage = storage,
        .summary = storage,
        .body = storage[storage.len..],
        .timeout_ms = notice.timeout_ms,
    };
}

fn simulate(steps: []const Step) !void {
    var transcript = Transcript{ .steps = steps };
    const result = run(&transcript, &transcript, std.testing.allocator);
    try transcript.done();
    return result;
}

test "timeout closes before teardown and returns to queue sleep" {
    try simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 100 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 1 },
        .{ .wake_failed = false },
        .{ .now = 0 },
        .{ .wait = .timeout },
        .{ .wake_failed = false },
        .{ .now = 100 },
        .{ .closed = .{ .id = 1, .reason = .expired } },
        .{ .draw = null },
        .stop,
        .{ .receive = .stop },
    });
}

test "dismissal closes before draw and session teardown" {
    try simulate(&.{
        .{ .receive = .{ .show = .{ .id = 7, .text = "seven", .timeout_ms = 1000 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 7 },
        .{ .wake_failed = false },
        .{ .now = 1 },
        .{ .wait = .dismiss },
        .{ .closed = .{ .id = 7, .reason = .dismissed } },
        .{ .draw = null },
        .{ .wake_failed = false },
        .{ .now = 2 },
        .stop,
        .{ .receive = .stop },
    });
}

test "burst closes each displaced id and draws only the newest deadline" {
    try simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 1000 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 1 },
        .{ .wake_failed = false },
        .{ .now = 1 },
        .{ .wait = .wake },
        .{ .drain = &.{
            .{ .show = .{ .id = 2, .text = "two", .timeout_ms = 1000 } },
            .{ .show = .{ .id = 3, .text = "three", .timeout_ms = 1000 } },
            .{ .replace = .{ .id = 3, .text = "three replaced", .timeout_ms = 50 } },
        } },
        .{ .now = 10 },
        .{ .closed = .{ .id = 1, .reason = .expired } },
        .{ .now = 20 },
        .{ .closed = .{ .id = 2, .reason = .expired } },
        .{ .now = 30 },
        .{ .draw = 3 },
        .{ .wake_failed = false },
        .{ .now = 79 },
        .{ .wait = .timeout },
        .{ .wake_failed = false },
        .{ .now = 80 },
        .{ .closed = .{ .id = 3, .reason = .expired } },
        .{ .draw = null },
        .stop,
        .{ .receive = .stop },
    });
}

test "stop in a wake batch releases later owned records" {
    try simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 1000 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 1 },
        .{ .wake_failed = false },
        .{ .now = 1 },
        .{ .wait = .wake },
        .{ .drain = &.{
            .stop,
            .{ .show = .{ .id = 2, .text = "two", .timeout_ms = 1000 } },
        } },
        .stop,
    });
}

test "start failure releases the received record without stop" {
    try std.testing.expectError(error.StartFailed, simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 100 } } },
        .{ .start = false },
    }));
}

test "wake and device failures stop the complete native session" {
    try std.testing.expectError(error.WakeFailed, simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 100 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 1 },
        .{ .wake_failed = true },
        .stop,
    }));
    try std.testing.expectError(error.DeviceLost, simulate(&.{
        .{ .receive = .{ .show = .{ .id = 1, .text = "one", .timeout_ms = 100 } } },
        .{ .start = true },
        .{ .now = 0 },
        .{ .draw = 1 },
        .{ .wake_failed = false },
        .{ .now = 0 },
        .{ .wait = .device_lost },
        .stop,
    }));
}

fn apply(
    state: *banner.State,
    bridge: anytype,
    allocator: std.mem.Allocator,
    event: *bridge_mod.ToMain,
    now_ms: u64,
    owned: *bool,
) !void {
    switch (event.*) {
        .show, .replace => |record| {
            const displaced = state.show(allocator, record, now_ms);
            owned.* = false;
            if (displaced) |id| try bridge.closed(id, .expired);
        },
        .close => |id| _ = state.close(allocator, id),
        .stop, .failed => unreachable,
    }
}
