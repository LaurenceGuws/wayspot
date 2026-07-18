//! Runs the exact desktop notification service over one concrete DBus owner.

const std = @import("std");
const notification = @import("notification.zig");

pub const CloseReason = enum(u32) {
    expired = 1,
    dismissed = 2,
    requested = 3,
    reserved = 4,
};

pub const ReplyError = enum {
    unknown_method,
    invalid_signature,
    invalid_utf8,
    field_too_long,
    too_many_actions,
    too_many_hints,
    message_too_long,
    records_full,
    id_exhausted,
    unknown_notification,
    out_of_memory,
};

pub const Method = union(enum) {
    get_capabilities,
    notify: notification.Request,
    close: u32,
    get_server_information,
};

pub const Event = union(enum) {
    method: Method,
    reject: ReplyError,
    idle,
    stop,
    bus_lost,
    name_lost,
};

pub const BannerEvent = union(enum) {
    none,
    closed: struct { id: u32, reason: CloseReason },
    failed,
};

/// Bounds close and failure values returned before one DBus receive.
pub const banner_event_capacity = 16;

/// Serves methods until explicit stop; bus or name loss is a process failure.
pub fn run(dbus: anytype, allocator: std.mem.Allocator) !void {
    var banner: NoBanner = .{};
    var history: NoHistory = .{};
    return runWithBannerAndHistory(dbus, &banner, &history, allocator);
}

/// Serves DBus and applies banner closes before receiving the next method.
pub fn runWithBanner(dbus: anytype, banner: anytype, allocator: std.mem.Allocator) !void {
    var history: NoHistory = .{};
    return runWithBannerAndHistory(dbus, banner, &history, allocator);
}

/// Retains accepted notifications after replying and before receiving another method.
pub fn runWithBannerAndHistory(
    dbus: anytype,
    banner: anytype,
    history: anytype,
    allocator: std.mem.Allocator,
) !void {
    try openAndOwn(dbus);
    defer dbus.close();
    return serveOwnedWithBannerAndHistory(dbus, banner, history, allocator);
}

/// Opens one private DBus connection and acquires the notification name before returning.
pub fn openAndOwn(dbus: anytype) !void {
    try dbus.open();
    errdefer dbus.close();
    return dbus.own();
}

/// Serves an already-owned DBus connection; its caller remains the connection owner.
pub fn serveOwnedWithBannerAndHistory(
    dbus: anytype,
    banner: anytype,
    history: anytype,
    allocator: std.mem.Allocator,
) !void {
    var store: notification.Store = .{};
    defer store.deinit(allocator);

    // DOMAIN.yml declares this a resident process; only stop or failure ends it.
    while (true) {
        try drainBanner(dbus, banner, history, allocator, &store);
        switch (try dbus.next()) {
            .method => |method| try dispatch(dbus, banner, history, allocator, &store, method),
            .reject => |err| try dbus.replyError(err),
            .idle => {},
            .stop => return,
            .bus_lost => return error.BusLost,
            .name_lost => return error.NameLost,
        }
    }
}

fn drainBanner(
    dbus: anytype,
    banner: anytype,
    history: anytype,
    allocator: std.mem.Allocator,
    store: *notification.Store,
) !void {
    for (0..banner_event_capacity) |_| {
        switch (try banner.next()) {
            .none => return,
            .closed => |closed| {
                store.close(allocator, closed.id) catch continue;
                history.closed(closed.id);
                try dbus.signalClosed(closed.id, closed.reason);
            },
            .failed => return error.BannerFailed,
        }
    }
}

fn dispatch(
    dbus: anytype,
    banner: anytype,
    history: anytype,
    allocator: std.mem.Allocator,
    store: *notification.Store,
    method: Method,
) !void {
    switch (method) {
        .get_capabilities => try dbus.replyCapabilities(),
        .notify => |request| {
            const replaces = request.replaces_id != 0 and store.get(request.replaces_id) != null;
            const id = store.notify(allocator, request) catch |err| {
                try dbus.replyError(switch (err) {
                    error.InvalidUtf8 => .invalid_utf8,
                    error.FieldTooLong => .field_too_long,
                    error.RecordsFull => .records_full,
                    error.IdExhausted => .id_exhausted,
                    error.OutOfMemory => .out_of_memory,
                });
                return;
            };
            try banner.show(allocator, store.get(id).?, replaces);
            try dbus.replyNotify(id);
            try history.accepted(store.get(id).?, replaces);
        },
        .close => |id| {
            store.close(allocator, id) catch {
                try dbus.replyError(.unknown_notification);
                return;
            };
            history.closed(id);
            try banner.close(id);
            try dbus.signalClosed(id, .requested);
            try dbus.replyClose();
        },
        .get_server_information => try dbus.replyServerInformation(),
    }
}

const NoBanner = struct {
    fn next(_: *NoBanner) !BannerEvent {
        return .none;
    }

    fn show(
        _: *NoBanner,
        _: std.mem.Allocator,
        _: *const notification.Notification,
        _: bool,
    ) !void {}

    fn close(_: *NoBanner, _: u32) !void {}
};

const NoHistory = struct {
    fn accepted(
        _: *NoHistory,
        _: *const notification.Notification,
        _: bool,
    ) !void {}

    fn closed(_: *NoHistory, _: u32) void {}
};

const step_capacity = 32;

const Step = union(enum) {
    open: bool,
    own: bool,
    history_load,
    history_persist,
    next: Event,
    reply_capabilities,
    reply_notify: u32,
    signal_closed: struct { id: u32, reason: CloseReason },
    reply_close,
    reply_server_information,
    reply_error: ReplyError,
    close,
};

const Transcript = struct {
    steps: []const Step,
    index: usize = 0,
    mismatch: bool = false,
    notify_replied: bool = false,
    history_operations: usize = 0,

    pub fn open(transcript: *Transcript) !void {
        if (!try transcript.result(.open)) return error.OpenFailed;
    }

    pub fn own(transcript: *Transcript) !void {
        if (!try transcript.result(.own)) return error.NameOwned;
    }

    fn historyLoad(transcript: *Transcript) !void {
        try transcript.expectTag(.history_load);
        transcript.history_operations += 1;
    }

    fn historyPersist(transcript: *Transcript) !void {
        try transcript.expectTag(.history_persist);
        transcript.history_operations += 1;
    }

    pub fn next(transcript: *Transcript) !Event {
        return switch (transcript.take() orelse return error.TranscriptMismatch) {
            .next => |event| event,
            else => error.TranscriptMismatch,
        };
    }

    pub fn replyCapabilities(transcript: *Transcript) !void {
        try transcript.expectTag(.reply_capabilities);
    }

    pub fn replyNotify(transcript: *Transcript, id: u32) !void {
        const expected = switch (transcript.take() orelse return error.TranscriptMismatch) {
            .reply_notify => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (expected != id) return error.TranscriptMismatch;
        transcript.notify_replied = true;
    }

    pub fn signalClosed(transcript: *Transcript, id: u32, reason: CloseReason) !void {
        const expected = switch (transcript.take() orelse return error.TranscriptMismatch) {
            .signal_closed => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (expected.id != id or expected.reason != reason) return error.TranscriptMismatch;
    }

    pub fn replyClose(transcript: *Transcript) !void {
        try transcript.expectTag(.reply_close);
    }

    pub fn replyServerInformation(transcript: *Transcript) !void {
        try transcript.expectTag(.reply_server_information);
    }

    pub fn replyError(transcript: *Transcript, err: ReplyError) !void {
        const expected = switch (transcript.take() orelse return error.TranscriptMismatch) {
            .reply_error => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (expected != err) return error.TranscriptMismatch;
    }

    pub fn close(transcript: *Transcript) void {
        transcript.consume(.close);
    }

    fn result(transcript: *Transcript, tag: std.meta.Tag(Step)) !bool {
        const step = transcript.take() orelse return error.TranscriptMismatch;
        if (std.meta.activeTag(step) != tag) return error.TranscriptMismatch;
        return switch (step) {
            .open, .own => |value| value,
            else => unreachable,
        };
    }

    fn expectTag(transcript: *Transcript, tag: std.meta.Tag(Step)) !void {
        const step = transcript.take() orelse return error.TranscriptMismatch;
        if (std.meta.activeTag(step) != tag) return error.TranscriptMismatch;
    }

    fn take(transcript: *Transcript) ?Step {
        if (transcript.index == transcript.steps.len) {
            transcript.mismatch = true;
            return null;
        }
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }

    fn consume(transcript: *Transcript, tag: std.meta.Tag(Step)) void {
        const step = transcript.take() orelse return;
        if (std.meta.activeTag(step) != tag) transcript.mismatch = true;
    }

    fn done(transcript: *const Transcript) !void {
        if (transcript.mismatch or transcript.index != transcript.steps.len) {
            return error.TranscriptMismatch;
        }
    }
};

const HistoryTranscript = struct {
    notify_replied: *const bool,
    accepted_count: usize = 0,
    closed_count: usize = 0,
    fail: bool = false,

    fn accepted(
        transcript: *HistoryTranscript,
        _: *const notification.Notification,
        _: bool,
    ) !void {
        if (!transcript.notify_replied.*) return error.HistoryBeforeReply;
        transcript.accepted_count += 1;
        if (transcript.fail) return error.HistoryFailed;
    }

    fn closed(transcript: *HistoryTranscript, _: u32) void {
        transcript.closed_count += 1;
    }
};

const BannerTranscript = struct {
    events: []const BannerEvent,
    index: usize = 0,
    show_count: usize = 0,

    fn next(transcript: *BannerTranscript) !BannerEvent {
        if (transcript.index == transcript.events.len) return error.TranscriptMismatch;
        defer transcript.index += 1;
        return transcript.events[transcript.index];
    }

    fn show(
        transcript: *BannerTranscript,
        _: std.mem.Allocator,
        _: *const notification.Notification,
        _: bool,
    ) !void {
        transcript.show_count += 1;
    }

    fn close(_: *BannerTranscript, _: u32) !void {}
};

fn simulate(steps: []const Step) !void {
    if (steps.len > step_capacity) return error.TranscriptTooLong;
    var transcript = Transcript{ .steps = steps };
    const result = run(&transcript, std.testing.allocator);
    try transcript.done();
    return result;
}

fn sampleRequest(replaces_id: u32, summary: []const u8) notification.Request {
    return .{
        .replaces_id = replaces_id,
        .app_name = "app",
        .app_icon = "",
        .summary = summary,
        .body = "body",
        .expire_timeout = -1,
    };
}

test "all methods share one store and close invalidates before its signal" {
    try simulate(&.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .{ .method = .get_capabilities } },
        .reply_capabilities,
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "first") } } },
        .{ .reply_notify = 1 },
        .{ .next = .{ .method = .{ .notify = sampleRequest(1, "replacement") } } },
        .{ .reply_notify = 1 },
        .{ .next = .{ .method = .{ .close = 1 } } },
        .{ .signal_closed = .{ .id = 1, .reason = .requested } },
        .reply_close,
        .{ .next = .{ .method = .{ .close = 1 } } },
        .{ .reply_error = .unknown_notification },
        .{ .next = .{ .method = .get_server_information } },
        .reply_server_information,
        .{ .next = .stop },
        .close,
    });
}

test "banner close burst drains in order before the next DBus receive" {
    var dbus = Transcript{ .steps = &.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "one") } } },
        .{ .reply_notify = 1 },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "two") } } },
        .{ .reply_notify = 2 },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "three") } } },
        .{ .reply_notify = 3 },
        .{ .signal_closed = .{ .id = 1, .reason = .expired } },
        .{ .signal_closed = .{ .id = 2, .reason = .expired } },
        .{ .next = .stop },
        .close,
    } };
    var banner = BannerTranscript{ .events = &.{
        .none,
        .none,
        .none,
        .{ .closed = .{ .id = 1, .reason = .expired } },
        .{ .closed = .{ .id = 999, .reason = .expired } },
        .{ .closed = .{ .id = 2, .reason = .expired } },
        .none,
    } };

    try runWithBanner(&dbus, &banner, std.testing.allocator);
    try dbus.done();
    try std.testing.expectEqual(banner.events.len, banner.index);
    try std.testing.expectEqual(@as(usize, 3), banner.show_count);
}

test "accepted reply precedes visible history failure" {
    var dbus = Transcript{ .steps = &.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "accepted") } } },
        .{ .reply_notify = 1 },
        .close,
    } };
    var banner: NoBanner = .{};
    var history = HistoryTranscript{ .notify_replied = &dbus.notify_replied, .fail = true };
    try std.testing.expectError(
        error.HistoryFailed,
        runWithBannerAndHistory(&dbus, &banner, &history, std.testing.allocator),
    );
    try dbus.done();
    try std.testing.expectEqual(@as(usize, 1), history.accepted_count);
}

test "native rejections receive one error and do not stop the service" {
    try simulate(&.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .{ .reject = .invalid_signature } },
        .{ .reply_error = .invalid_signature },
        .{ .next = .idle },
        .{ .next = .stop },
        .close,
    });
}

test "record rejection is mapped and leaves the next id untouched" {
    var long_summary: [notification.summary_capacity + 1]u8 = @splat('x');
    try simulate(&.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, &long_summary) } } },
        .{ .reply_error = .field_too_long },
        .{ .next = .{ .method = .{ .notify = sampleRequest(0, "valid") } } },
        .{ .reply_notify = 1 },
        .{ .next = .stop },
        .close,
    });
}

test "startup and resident failures clean exactly acquired ownership" {
    try std.testing.expectError(error.OpenFailed, simulate(&.{
        .{ .open = false },
    }));
    try std.testing.expectError(error.NameOwned, simulate(&.{
        .{ .open = true },
        .{ .own = false },
        .close,
    }));
    try std.testing.expectError(error.BusLost, simulate(&.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .bus_lost },
        .close,
    }));
    try std.testing.expectError(error.NameLost, simulate(&.{
        .{ .open = true },
        .{ .own = true },
        .{ .next = .name_lost },
        .close,
    }));
}

test "history starts only after successful name ownership" {
    var rejected = Transcript{ .steps = &.{
        .{ .open = true },
        .{ .own = false },
        .close,
    } };
    try std.testing.expectError(error.NameOwned, openAndOwn(&rejected));
    try rejected.done();
    try std.testing.expectEqual(@as(usize, 0), rejected.history_operations);

    var accepted = Transcript{ .steps = &.{
        .{ .open = true },
        .{ .own = true },
        .history_load,
        .history_persist,
        .{ .next = .stop },
        .close,
    } };
    try openAndOwn(&accepted);
    try accepted.historyLoad();
    try accepted.historyPersist();
    var banner: NoBanner = .{};
    var history: NoHistory = .{};
    try serveOwnedWithBannerAndHistory(
        &accepted,
        &banner,
        &history,
        std.testing.allocator,
    );
    accepted.close();
    try accepted.done();
    try std.testing.expectEqual(@as(usize, 2), accepted.history_operations);
}
