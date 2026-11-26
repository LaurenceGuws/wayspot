//! Strict SDL operation transcript and deterministic picker simulations.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("../apps/catalog.zig");
const notification = @import("../notifications/root.zig");
const navigator = @import("navigator.zig");
const picker = @import("root.zig");

const step_capacity = 32;
const native_ui = @import("build_options").native_picker;

const Result = enum { ok, fail };

const Wait = union(enum) {
    event: picker.Event,
    events: struct {
        items: []const picker.Event,
        more: bool = false,
    },
    fail,
};

const ExpectedWindowRow = struct {
    stable_id: []const u8,
    app_index: ?u16 = null,
};

const Draw = struct {
    table: picker.Table = .apps,
    query: []const u8,
    rows: ExpectedRows = .none,
    selected_row: usize = 0,
    window_status: picker.WindowStatus = .dormant,
    window_error: ?[]const u8 = null,
    result: Result = .ok,
};

const ExpectedRows = union(enum) {
    none,
    root: []const picker.Table,
    apps: []const u16,
    windows: []const ExpectedWindowRow,
    notifications: []const NotificationRow,
};

const NotificationRow = struct {
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
};

const HistoryRead = enum {
    empty,
    stored,
    corrupt,
    permission,
    allocation,
};

const NavigatorDiscovery = struct {
    bytes: []const u8 = navigator_desktop_fixture,
    result: Result = .ok,
};

const NavigatorFocus = struct {
    stable_id: []const u8,
    bytes: []const u8 = "ok\n",
    result: Result = .ok,
};

const NavigatorFocusObservation = struct {
    bytes: []const u8 = "{\"address\":\"0x3\"}",
    result: Result = .ok,
};

const Step = union(enum) {
    init: Result,
    create: Result,
    start_text: Result,
    wait: Wait,
    draw: Draw,
    read_history: HistoryRead,
    navigator_discovery: NavigatorDiscovery,
    navigator_focus: NavigatorFocus,
    navigator_focus_observation: NavigatorFocusObservation,
    stop_text: Result,
    destroy,
    sync: Result,
    quit,
};

const Transcript = struct {
    steps: []const Step,
    applications: []const apps.App,
    backend: ?navigator.Backend = .hyprland,
    retained: ?notification.History = null,
    history_reads: usize = 0,
    index: usize = 0,
    mismatch: bool = false,

    pub fn init(transcript: *Transcript) !void {
        const result = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .init => |result| result,
            else => return error.TranscriptMismatch,
        };
        if (result == .fail) return error.SdlInitFailed;
    }

    pub fn create(transcript: *Transcript) !void {
        const result = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .create => |result| result,
            else => return error.TranscriptMismatch,
        };
        if (result == .fail) return error.SdlCreateFailed;
    }

    pub fn startText(transcript: *Transcript) !void {
        const result = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .start_text => |result| result,
            else => return error.TranscriptMismatch,
        };
        if (result == .fail) return error.SdlStartTextFailed;
    }

    pub fn read(transcript: *Transcript) !picker.Events {
        const result = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .wait => |wait_result| switch (wait_result) {
                .event => |event| {
                    var events: picker.Events = .{};
                    events.items[0] = event;
                    events.count = 1;
                    return events;
                },
                .events => |events| events,
                .fail => return error.SdlWaitFailed,
            },
            else => return error.TranscriptMismatch,
        };
        if (result.items.len == 0 or result.items.len > picker.event_capacity) {
            return error.TranscriptMismatch;
        }
        var events: picker.Events = .{};
        @memcpy(events.items[0..result.items.len], result.items);
        events.count = result.items.len;
        events.more = result.more;
        return events;
    }

    pub fn draw(transcript: *Transcript, frame: *const picker.Frame) !void {
        const expected = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .draw => |expected_draw| expected_draw,
            else => return error.TranscriptMismatch,
        };
        if (expected.table != frame.table) return error.TranscriptMismatch;
        if (!std.mem.eql(u8, expected.query, frame.query)) return error.TranscriptMismatch;
        switch (expected.rows) {
            .none => if (frame.row_count != 0) return error.TranscriptMismatch,
            .root => |tables| try transcript.expectTables(frame, tables),
            .apps => |indexes| try transcript.expectApps(frame, indexes),
            .windows => |windows| try transcript.expectWindows(frame, windows),
            .notifications => |records| try expectNotifications(frame, records),
        }
        if (frame.row_count > 0 and expected.selected_row != frame.selected_row) {
            return error.TranscriptMismatch;
        }
        if (frame.window_status != expected.window_status or
            (frame.window_error == null) != (expected.window_error == null)) return error.TranscriptMismatch;
        if (frame.window_error) |reason| {
            if (!std.mem.eql(u8, reason, expected.window_error.?)) return error.TranscriptMismatch;
        }
        if (expected.result == .fail) return error.SdlDrawFailed;
    }

    fn expectTables(_: *Transcript, frame: *const picker.Frame, tables: []const picker.Table) !void {
        if (tables.len != frame.row_count) return error.TranscriptMismatch;
        for (frame.rowSlice(), tables) |row, table| switch (row) {
            .table => |actual| if (actual != table) return error.TranscriptMismatch,
            else => return error.TranscriptMismatch,
        };
    }

    fn expectApps(transcript: *Transcript, frame: *const picker.Frame, indexes: []const u16) !void {
        if (indexes.len != frame.row_count) return error.TranscriptMismatch;
        for (frame.rowSlice(), indexes) |row, expected| switch (row) {
            .app => |actual| {
                if (actual != expected) return error.TranscriptMismatch;
                if (actual >= transcript.applications.len) return error.TranscriptMismatch;
            },
            else => return error.TranscriptMismatch,
        };
    }

    fn expectWindows(
        transcript: *Transcript,
        frame: *const picker.Frame,
        windows: []const ExpectedWindowRow,
    ) !void {
        if (windows.len != frame.row_count) return error.TranscriptMismatch;
        for (frame.rowSlice(), windows) |row, expected| switch (row) {
            .window => |actual| {
                if (!std.mem.eql(u8, actual.window.stable_id.slice(), expected.stable_id)) {
                    return error.TranscriptMismatch;
                }
                if (actual.app_index != expected.app_index) return error.TranscriptMismatch;
                if (actual.app_index) |index| {
                    if (index >= transcript.applications.len) return error.TranscriptMismatch;
                }
            },
            else => return error.TranscriptMismatch,
        };
    }

    pub fn run(
        transcript: *Transcript,
        allocator: std.mem.Allocator,
        argv: []const []const u8,
        max_stdout: usize,
    ) !navigator.ProcessResult {
        if (argv.len < 3) return error.TranscriptMismatch;
        if (transcript.backend == .snowman) return transcript.snowmanRun(allocator, argv, max_stdout);
        if (!std.mem.eql(u8, argv[0], "hyprctl") or transcript.backend != .hyprland) return error.TranscriptMismatch;
        const step = transcript.next() orelse return error.TranscriptMismatch;
        const Selected = struct { bytes: []const u8, result: Result };
        const selected: Selected = if (argv.len == 3 and std.mem.eql(u8, argv[1], "-j") and
            std.mem.eql(u8, argv[2], "clients") and max_stdout == 256 * 1024)
            switch (step) {
                .navigator_discovery => |discovery| .{ .bytes = discovery.bytes, .result = discovery.result },
                else => return error.TranscriptMismatch,
            }
        else if (argv.len == 3 and std.mem.eql(u8, argv[1], "dispatch") and max_stdout == 64 * 1024)
            switch (step) {
                .navigator_focus => |focus| blk: {
                    var expected_buffer: [136]u8 = undefined;
                    const expected = try std.fmt.bufPrint(&expected_buffer, "hl.dsp.focus({{ window = \"address:{s}\" }})", .{focus.stable_id});
                    if (!std.mem.eql(u8, argv[2], expected)) return error.TranscriptMismatch;
                    break :blk .{ .bytes = focus.bytes, .result = focus.result };
                },
                else => return error.TranscriptMismatch,
            }
        else if (argv.len == 3 and std.mem.eql(u8, argv[1], "-j") and
            std.mem.eql(u8, argv[2], "activewindow") and max_stdout == 64 * 1024)
            switch (step) {
                .navigator_focus_observation => |observation| .{ .bytes = observation.bytes, .result = observation.result },
                else => return error.TranscriptMismatch,
            }
        else
            return error.TranscriptMismatch;
        const stdout = try allocator.dupe(u8, selected.bytes);
        errdefer allocator.free(stdout);
        return .{
            .stdout = stdout,
            .stderr = try allocator.dupe(u8, ""),
            .succeeded = selected.result == .ok,
        };
    }

    fn snowmanRun(transcript: *Transcript, allocator: std.mem.Allocator, argv: []const []const u8, max_stdout: usize) !navigator.ProcessResult {
        if (argv.len != 4 or !std.mem.eql(u8, argv[0], "snowman") or max_stdout != 64 * 1024) return error.TranscriptMismatch;
        const step = transcript.next() orelse return error.TranscriptMismatch;
        const reply = switch (step) {
            .navigator_discovery => |value| blk: {
                if (!std.mem.eql(u8, argv[1], "window") or !std.mem.eql(u8, argv[2], "list") or !std.mem.eql(u8, argv[3], "--mapped")) return error.TranscriptMismatch;
                break :blk value;
            },
            .navigator_focus_observation => |value| blk: {
                if (!std.mem.eql(u8, argv[1], "seat") or !std.mem.eql(u8, argv[2], "get") or !std.mem.eql(u8, argv[3], "1")) return error.TranscriptMismatch;
                break :blk NavigatorDiscovery{ .bytes = value.bytes, .result = value.result };
            },
            .navigator_focus => |value| blk: {
                if (!std.mem.eql(u8, argv[1], "window") or !std.mem.eql(u8, argv[2], "focus") or !std.mem.eql(u8, argv[3], value.stable_id)) return error.TranscriptMismatch;
                break :blk NavigatorDiscovery{ .bytes = value.bytes, .result = value.result };
            },
            else => return error.TranscriptMismatch,
        };
        const stdout = try allocator.dupe(u8, if (reply.result == .ok) reply.bytes else "");
        errdefer allocator.free(stdout);
        return .{ .stdout = stdout, .stderr = try allocator.dupe(u8, if (reply.result == .ok) "" else reply.bytes), .succeeded = reply.result == .ok };
    }

    pub fn readHistory(transcript: *Transcript) !notification.History {
        transcript.history_reads += 1;
        return switch (transcript.next() orelse return error.TranscriptMismatch) {
            .read_history => |result| switch (result) {
                .empty => .{},
                .stored => blk: {
                    const retained = transcript.retained orelse return error.TranscriptMismatch;
                    transcript.retained = null;
                    break :blk retained;
                },
                .corrupt => error.HistoryCorrupt,
                .permission => error.HistoryOpenFailed,
                .allocation => error.OutOfMemory,
            },
            else => error.TranscriptMismatch,
        };
    }

    pub fn stopText(transcript: *Transcript) !void {
        const result = switch (transcript.next() orelse return error.TranscriptMismatch) {
            .stop_text => |result| result,
            else => return error.TranscriptMismatch,
        };
        if (result == .fail) return error.SdlStopTextFailed;
    }

    pub fn destroy(transcript: *Transcript) void {
        transcript.consume(.destroy);
    }

    pub fn destroyForFocus(transcript: *Transcript) !void {
        transcript.destroy();
        const step = transcript.next() orelse return error.TranscriptMismatch;
        if (step != .sync) return error.TranscriptMismatch;
        if (step.sync == .fail) return error.PickerDismissalSyncFailed;
    }

    pub fn quit(transcript: *Transcript) void {
        transcript.consume(.quit);
    }

    fn next(transcript: *Transcript) ?Step {
        if (transcript.index == transcript.steps.len) {
            transcript.mismatch = true;
            return null;
        }
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }

    fn consume(transcript: *Transcript, expected: std.meta.Tag(Step)) void {
        const step = transcript.next() orelse return;
        if (std.meta.activeTag(step) != expected) transcript.mismatch = true;
    }

    fn done(transcript: *const Transcript) !void {
        var expected_history_reads: usize = 0;
        for (transcript.steps) |step| {
            expected_history_reads += @intFromBool(step == .read_history);
        }
        if (transcript.mismatch or transcript.index != transcript.steps.len) {
            return error.TranscriptMismatch;
        }
        if (transcript.history_reads != expected_history_reads) return error.TranscriptMismatch;
    }
};

fn expectNotifications(frame: *const picker.Frame, records: []const NotificationRow) !void {
    if (records.len != frame.row_count) return error.TranscriptMismatch;
    for (frame.rowSlice(), records) |row, expected| switch (row) {
        .notification => |actual| {
            if (!std.mem.eql(u8, expected.app_name, actual.app_name)) return error.TranscriptMismatch;
            if (!std.mem.eql(u8, expected.summary, actual.summary)) return error.TranscriptMismatch;
            if (!std.mem.eql(u8, expected.body, actual.body)) return error.TranscriptMismatch;
        },
        else => return error.TranscriptMismatch,
    };
}

fn simulate(steps: []const Step) !void {
    const selected = try simulateApps(steps, &.{});
    if (selected != null) return error.UnexpectedSelection;
}

fn simulateApps(steps: []const Step, applications: []const apps.App) !?usize {
    return simulateHistory(steps, applications, null);
}

fn simulateHistory(
    steps: []const Step,
    applications: []const apps.App,
    retained: ?notification.History,
) !?usize {
    return simulateHistoryBackend(steps, applications, retained, .hyprland);
}

fn simulateHistoryBackend(
    steps: []const Step,
    applications: []const apps.App,
    retained: ?notification.History,
    backend: navigator.Backend,
) !?usize {
    if (steps.len > step_capacity) return error.TranscriptTooLong;
    var transcript = Transcript{
        .steps = steps,
        .applications = applications,
        .backend = backend,
        .retained = retained,
    };
    defer if (transcript.retained) |*history| history.deinit(std.testing.allocator);
    const result = picker.run(
        &transcript,
        &transcript,
        &transcript,
        transcript.backend,
        std.testing.allocator,
        999,
        applications,
    );
    try transcript.done();
    return result;
}

const navigator_desktop_fixture =
    \\[
    \\ {"address":"0x2","class":"zen","title":"Browser","pid":20,"mapped":true,"hidden":false,"at":[6,4],"size":[1910,1072],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":1},
    \\ {"address":"0x3","class":"kitty","title":"Terminal","pid":10,"mapped":true,"hidden":false,"at":[-1910,4],"size":[1910,1072],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":2},
    \\ {"address":"0x4","class":"org.kde.dolphin","title":"Downloads","pid":30,"mapped":true,"hidden":true,"at":[1920,0],"size":[960,1080],"workspace":{"id":2},"monitor":1,"floating":false,"fullscreen":0,"focusHistoryID":3},
    \\ {"address":"0x5","class":"wayspot","title":"wayspot","pid":999,"mapped":true,"hidden":false,"at":[600,300],"size":[720,480],"workspace":{"id":1},"monitor":0,"floating":true,"fullscreen":0,"focusHistoryID":0}
    \\]
;

test "text input starts before wait and cleanup is exact" {
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("abc") } } },
        .{ .draw = .{ .query = "abc" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });
}

test "Tab lazily opens a global MRU window finder and exact Enter focuses selection" {
    const prefix = [_]Step{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{} },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .down } },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .selected_row = 1,
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .enter } },
    };
    const focus = [_]Step{ .{ .navigator_focus = .{ .stable_id = "0x3" } }, .{ .navigator_focus_observation = .{} } };
    const cleanup = [_]Step{ .{ .stop_text = .ok }, .destroy };
    const steps = if (native_ui) prefix ++ cleanup ++ [_]Step{ .{ .sync = .ok }, .quit } ++ focus else prefix ++ focus ++ cleanup ++ [_]Step{.quit};
    try simulate(&steps);
}

test "typing in window finder filters windows instead of returning to applications" {
    const prefix = [_]Step{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{} },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("term") } } },
        .{ .draw = .{
            .table = .windows,
            .query = "term",
            .rows = .{ .windows = &.{.{ .stable_id = "0x3" }} },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .enter } },
    };
    const focus = [_]Step{ .{ .navigator_focus = .{ .stable_id = "0x3" } }, .{ .navigator_focus_observation = .{} } };
    const cleanup = [_]Step{ .{ .stop_text = .ok }, .destroy };
    const steps = if (native_ui) prefix ++ cleanup ++ [_]Step{ .{ .sync = .ok }, .quit } ++ focus else prefix ++ focus ++ cleanup ++ [_]Step{.quit};
    try simulate(&steps);
}

test "Tab toggles window finder back to a fresh application finder" {
    const applications = [_]apps.App{testApp("Alpha")};
    _ = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "", .rows = .{ .apps = &.{0} } } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{} },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .tab } },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &.{0} },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .escape } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
}

test "Hyprland discovery failure leaves a bounded window mode and Tab recovers apps" {
    const applications = [_]apps.App{testApp("Alpha")};
    _ = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "", .rows = .{ .apps = &.{0} } } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{ .result = .fail } },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .window_status = .unavailable,
            .window_error = "CompositorCliRejected",
        } },
        .{ .wait = .{ .event = .tab } },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &.{0} },
            .window_status = .unavailable,
        } },
        .{ .wait = .{ .event = .escape } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
}

test "malformed Hyprland client response is visible and recoverable" {
    const applications = [_]apps.App{testApp("Alpha")};
    _ = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "", .rows = .{ .apps = &.{0} } } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{ .bytes = "{}" } },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .window_status = .unavailable,
            .window_error = "CompositorReplyMalformed",
        } },
        .{ .wait = .{ .event = .tab } },
        .{ .draw = .{ .query = "", .rows = .{ .apps = &.{0} }, .window_status = .unavailable } },
        .{ .wait = .{ .event = .escape } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
}

test "stale exact window focus never activates another target" {
    const prefix = [_]Step{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .tab } },
        .{ .navigator_discovery = .{} },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .down } },
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .selected_row = 1,
            .window_status = .ready,
        } },
        .{ .wait = .{ .event = .enter } },
    };
    const focus = [_]Step{ .{ .navigator_focus = .{ .stable_id = "0x3" } }, .{ .navigator_focus_observation = .{ .bytes = "{\"address\":\"0x2\"}" } } };
    const cleanup = [_]Step{ .{ .stop_text = .ok }, .destroy };
    if (native_ui) {
        const steps = prefix ++ cleanup ++ [_]Step{ .{ .sync = .ok }, .quit } ++ focus;
        try std.testing.expectError(error.CompositorFocusMismatch, simulate(&steps));
        const failed_sync = prefix ++ cleanup ++ [_]Step{ .{ .sync = .fail }, .quit };
        try std.testing.expectError(error.PickerDismissalSyncFailed, simulate(&failed_sync));
        return;
    }
    const steps = prefix ++ focus ++ [_]Step{
        .{ .draw = .{
            .table = .windows,
            .query = "",
            .rows = .{ .windows = &.{
                .{ .stable_id = "0x2" },
                .{ .stable_id = "0x3" },
                .{ .stable_id = "0x4" },
            } },
            .selected_row = 1,
            .window_status = .focus_failed,
            .window_error = "CompositorFocusMismatch",
        } },
        .{ .wait = .{ .event = .escape } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    };
    try simulate(&steps);
}

const snowman_windows = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_list\",\"serial\":5,\"data\":[{\"id\":42,\"workspace_id\":2,\"output_id\":null,\"mapped\":true,\"app_id\":\"kitty\",\"title\":\"Terminal\",\"geometry\":{\"x\":0,\"y\":0,\"width\":800,\"height\":600},\"mode\":\"tiled\",\"fullscreen\":false,\"scene\":{\"status\":\"workspace_unpresented\"}}]}";
const snowman_seat = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"seat_get\",\"serial\":5,\"data\":{\"id\":1,\"kind\":\"shared\",\"focused_window\":null,\"recent_window_count\":1,\"recent_window_ids\":[42]}}";
const snowman_applied = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":6,\"data\":{\"window_id\":42,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true,\"status\":\"applied\"}}";
const snowman_selection_prefix = [_]Step{
    .{ .init = .ok },                  .{ .create = .ok },                                        .{ .start_text = .ok },                                         .{ .draw = .{ .query = "" } },
    .{ .wait = .{ .event = .tab } },   .{ .navigator_discovery = .{ .bytes = snowman_windows } }, .{ .navigator_focus_observation = .{ .bytes = snowman_seat } }, .{ .draw = .{ .table = .windows, .query = "", .rows = .{ .windows = &.{.{ .stable_id = "42" }} }, .window_status = .ready } },
    .{ .wait = .{ .event = .enter } }, .{ .stop_text = .ok },                                     .destroy,
};

test "Snowman selects the exact window only after destruction, sync and SDL release" {
    const steps = snowman_selection_prefix ++ [_]Step{ .{ .sync = .ok }, .quit, .{ .navigator_focus = .{ .stable_id = "42", .bytes = snowman_applied } } };
    try std.testing.expectEqual(@as(?usize, null), try simulateHistoryBackend(&steps, &.{}, null, .snowman));
}

test "Snowman never attempts focus if dismissal synchronization fails" {
    const steps = snowman_selection_prefix ++ [_]Step{ .{ .sync = .fail }, .quit };
    try std.testing.expectError(error.PickerDismissalSyncFailed, simulateHistoryBackend(&steps, &.{}, null, .snowman));
}

test "Snowman stale selection refuses once after cleanup without retry" {
    const steps = snowman_selection_prefix ++ [_]Step{ .{ .sync = .ok }, .quit, .{ .navigator_focus = .{ .stable_id = "42", .bytes = "{\"schema\":\"snowman-command/v1\",\"ok\":false,\"error\":{\"code\":\"not_found\"}}", .result = .fail } } };
    try std.testing.expectError(error.SnowmanWindowGone, simulateHistoryBackend(&steps, &.{}, null, .snowman));
}

test "one pending event burst produces one final draw" {
    const first = picker.Event{ .text = try picker.Text.init("a") };
    const second = picker.Event{ .text = try picker.Text.init("b") };
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .events = .{ .items = &.{ first, second } } } },
        .{ .draw = .{ .query = "ab" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });
}

test "each startup failure cleans only completed acquisitions" {
    try std.testing.expectError(error.SdlInitFailed, simulate(&.{
        .{ .init = .fail },
    }));
    try std.testing.expectError(error.SdlCreateFailed, simulate(&.{
        .{ .init = .ok },
        .{ .create = .fail },
        .quit,
    }));
    try std.testing.expectError(error.SdlStartTextFailed, simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .fail },
        .destroy,
        .quit,
    }));
}

test "wait and draw failures clean text window and SDL" {
    try std.testing.expectError(error.SdlWaitFailed, simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .fail },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }));
    try std.testing.expectError(error.SdlDrawFailed, simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "", .result = .fail } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }));
}

test "query failure publishes no draw and still cleans every acquisition" {
    try std.testing.expectError(error.InvalidText, simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("\xff") } } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }));
}

test "quit does not draw or wait again" {
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });
}

test "ignored input does not draw and backspace removes one codepoint" {
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .ignored } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("aλ") } } },
        .{ .draw = .{ .query = "aλ" } },
        .{ .wait = .{ .event = .backspace } },
        .{ .draw = .{ .query = "a" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });
}

test "filtering resets selection and enter returns the displayed app" {
    const applications = [_]apps.App{
        testApp("Firefox"),
        testApp("Kitty"),
    };
    const selected = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &.{ 0, 1 } },
        } },
        .{ .wait = .{ .event = .down } },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &.{ 0, 1 } },
            .selected_row = 1,
        } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("fire") } } },
        .{ .draw = .{
            .query = "fire",
            .rows = .{ .apps = &.{0} },
        } },
        .{ .wait = .{ .event = .enter } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
    try std.testing.expectEqual(@as(?usize, 0), selected);
}

test "scroll hover and click preserve exact row and application identity" {
    const applications = [_]apps.App{
        testApp("App 00"),
        testApp("App 01"),
        testApp("App 02"),
        testApp("App 03"),
        testApp("App 04"),
        testApp("App 05"),
        testApp("App 06"),
        testApp("App 07"),
        testApp("App 08"),
        testApp("App 09"),
        testApp("App 10"),
        testApp("App 11"),
        testApp("App 12"),
        testApp("App 13"),
        testApp("App 14"),
        testApp("App 15"),
    };
    const initial_indexes = [_]u16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    const scrolled_indexes = [_]u16{ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const selected = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &initial_indexes },
        } },
        .{ .wait = .{ .event = .{ .scroll = 2 } } },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &scrolled_indexes },
        } },
        .{ .wait = .{ .event = .{ .hover = 5 } } },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &scrolled_indexes },
            .selected_row = 5,
        } },
        .{ .wait = .{ .event = .{ .click = 5 } } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
    try std.testing.expectEqual(@as(?usize, 7), selected);
}

test "slash root transitions to apps without reading history" {
    const applications = [_]apps.App{testApp("Alpha")};
    const selected = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{
            .query = "",
            .rows = .{ .apps = &.{0} },
        } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("/") } } },
        .{ .draw = .{
            .table = .root,
            .query = "/",
            .rows = .{ .root = &.{ .apps, .notifications } },
        } },
        .{ .wait = .{ .event = .{ .click = 0 } } },
        .{ .draw = .{
            .query = "/apps",
            .rows = .{ .apps = &.{0} },
        } },
        .{ .wait = .{ .event = .enter } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
    try std.testing.expectEqual(@as(?usize, 0), selected);
}

test "empty slash prefix remains open on Enter" {
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("/unknown") } } },
        .{ .draw = .{ .table = .root, .query = "/unknown" } },
        .{ .wait = .{ .event = .enter } },
        .{ .draw = .{ .table = .root, .query = "/unknown" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });
}

test "notification rows are newest first and never close or launch" {
    const retained = try retainedHistory();
    const expected = [_]NotificationRow{
        .{ .app_name = "new", .summary = "second", .body = "new body" },
        .{ .app_name = "old", .summary = "first", .body = "old body" },
    };
    const selected = try simulateHistory(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("/notifications") } } },
        .{ .read_history = .stored },
        .{ .draw = .{
            .table = .notifications,
            .query = "/notifications",
            .rows = .{ .notifications = &expected },
        } },
        .{ .wait = .{ .event = .down } },
        .{ .draw = .{
            .table = .notifications,
            .query = "/notifications",
            .rows = .{ .notifications = &expected },
            .selected_row = 1,
        } },
        .{ .wait = .{ .event = .enter } },
        .{ .draw = .{
            .table = .notifications,
            .query = "/notifications",
            .rows = .{ .notifications = &expected },
            .selected_row = 1,
        } },
        .{ .wait = .{ .event = .{ .click = 0 } } },
        .{ .draw = .{
            .table = .notifications,
            .query = "/notifications",
            .rows = .{ .notifications = &expected },
        } },
        .{ .wait = .{ .event = .backspace } },
        .{ .draw = .{
            .table = .root,
            .query = "/notification",
            .rows = .{ .root = &.{.notifications} },
        } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &.{}, retained);
    try std.testing.expectEqual(@as(?usize, null), selected);
}

test "missing history is empty and read failures clean SDL exactly" {
    try simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("/notifications") } } },
        .{ .read_history = .empty },
        .{ .draw = .{ .table = .notifications, .query = "/notifications" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    });

    const failures = [_]struct { HistoryRead, anyerror }{
        .{ .corrupt, error.HistoryCorrupt },
        .{ .permission, error.HistoryOpenFailed },
        .{ .allocation, error.OutOfMemory },
    };
    for (failures) |failure| {
        try std.testing.expectError(failure[1], simulate(&.{
            .{ .init = .ok },
            .{ .create = .ok },
            .{ .start_text = .ok },
            .{ .draw = .{ .query = "" } },
            .{ .wait = .{ .event = .{ .text = try picker.Text.init("/notifications") } } },
            .{ .read_history = failure[0] },
            .{ .stop_text = .ok },
            .destroy,
            .quit,
        }));
    }
}

fn retainedHistory() !notification.History {
    return notification.parse(
        std.testing.allocator,
        "{\"received_unix_seconds\":1,\"history_id\":1,\"app_name\":\"old\"," ++
            "\"summary\":\"first\",\"body\":\"old body\"}\n" ++
            "{\"received_unix_seconds\":2,\"history_id\":2,\"app_name\":\"new\"," ++
            "\"summary\":\"second\",\"body\":\"new body\"}\n",
        2,
    );
}

fn testApp(name: []const u8) apps.App {
    return .{
        .storage = @constCast(""),
        .id = "test.desktop",
        .name = name,
        .generic_name = null,
        .keywords = null,
        .icon = null,
        .exec = "test",
        .try_exec = null,
        .only_show_in = null,
        .not_show_in = null,
        .path = null,
        .terminal = false,
        .issues = .empty,
    };
}

test "text stop failure still destroys the window and quits SDL" {
    try std.testing.expectError(error.SdlStopTextFailed, simulate(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{ .query = "" } },
        .{ .wait = .{ .event = .quit } },
        .{ .stop_text = .fail },
        .destroy,
        .quit,
    }));
}

test "transcript rejects unconsumed and unexpected operations" {
    try std.testing.expectError(error.TranscriptMismatch, simulate(&.{
        .{ .init = .ok },
        .quit,
        .destroy,
    }));
    try std.testing.expectError(error.TranscriptMismatch, simulate(&.{
        .{ .create = .ok },
    }));
}

test "transcript rejects its first over-bound history" {
    const steps: [step_capacity + 1]Step = @splat(.{ .init = .fail });
    try std.testing.expectError(error.TranscriptTooLong, simulate(&steps));
}

test "structured SDL histories preserve cleanup" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzHistory, .{});
        return;
    }
    var baseline = std.testing.Smith{ .in = "" };
    try fuzzHistory({}, &baseline);
}

fn fuzzHistory(_: void, smith: *std.testing.Smith) !void {
    const fail_at = smith.valueRangeAtMost(u8, 0, 5);
    const inputs = [_][]const u8{ "", "a", "λ", "abc", "\xff" };
    const input = inputs[smith.valueRangeLessThan(u8, 0, inputs.len)];
    const text = try picker.Text.init(input);

    var steps: [16]Step = undefined;
    var count: usize = 0;
    append(&steps, &count, .{ .init = if (fail_at == 0) .fail else .ok });
    if (fail_at == 0) return expectFailure(error.SdlInitFailed, steps[0..count]);
    append(&steps, &count, .{ .create = if (fail_at == 1) .fail else .ok });
    if (fail_at == 1) {
        append(&steps, &count, .quit);
        return expectFailure(error.SdlCreateFailed, steps[0..count]);
    }
    append(&steps, &count, .{ .start_text = if (fail_at == 2) .fail else .ok });
    if (fail_at == 2) {
        append(&steps, &count, .destroy);
        append(&steps, &count, .quit);
        return expectFailure(error.SdlStartTextFailed, steps[0..count]);
    }
    append(&steps, &count, .{ .draw = .{
        .query = "",
        .result = if (fail_at == 3) .fail else .ok,
    } });
    if (fail_at == 3) {
        appendCleanup(&steps, &count);
        return expectFailure(error.SdlDrawFailed, steps[0..count]);
    }
    append(&steps, &count, .{ .wait = if (fail_at == 4) .fail else .{ .event = .{ .text = text } } });
    if (fail_at == 4) {
        appendCleanup(&steps, &count);
        return expectFailure(error.SdlWaitFailed, steps[0..count]);
    }
    if (!std.unicode.utf8ValidateSlice(input)) {
        appendCleanup(&steps, &count);
        return expectFailure(error.InvalidText, steps[0..count]);
    }
    append(&steps, &count, .{ .draw = .{ .query = input } });
    append(&steps, &count, .{ .wait = .{ .event = .quit } });
    if (fail_at == 5) {
        append(&steps, &count, .{ .stop_text = .fail });
        append(&steps, &count, .destroy);
        append(&steps, &count, .quit);
        return expectFailure(error.SdlStopTextFailed, steps[0..count]);
    }
    appendCleanup(&steps, &count);
    try simulate(steps[0..count]);
}

fn append(steps: []Step, count: *usize, step: Step) void {
    std.debug.assert(count.* < steps.len);
    steps[count.*] = step;
    count.* += 1;
}

fn appendCleanup(steps: []Step, count: *usize) void {
    append(steps, count, .{ .stop_text = .ok });
    append(steps, count, .destroy);
    append(steps, count, .quit);
}

fn expectFailure(expected: anyerror, steps: []const Step) !void {
    try std.testing.expectError(expected, simulate(steps));
}
