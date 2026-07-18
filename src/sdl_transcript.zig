//! Strict SDL operation transcript and deterministic picker simulations.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("apps.zig");
const picker = @import("picker.zig");

const step_capacity = 16;

const Result = enum { ok, fail };

const Wait = union(enum) {
    event: picker.Event,
    events: struct {
        items: []const picker.Event,
        more: bool = false,
    },
    fail,
};

const Draw = struct {
    query: []const u8,
    rows: []const []const u8 = &.{},
    app_indexes: []const u16 = &.{},
    selected_row: usize = 0,
    result: Result = .ok,
};

const Step = union(enum) {
    init: Result,
    create: Result,
    start_text: Result,
    wait: Wait,
    draw: Draw,
    stop_text: Result,
    destroy,
    quit,
};

const Transcript = struct {
    steps: []const Step,
    applications: []const apps.App,
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
        if (!std.mem.eql(u8, expected.query, frame.query)) return error.TranscriptMismatch;
        if (expected.rows.len != frame.row_count) return error.TranscriptMismatch;
        if (expected.app_indexes.len != frame.row_count) return error.TranscriptMismatch;
        for (expected.rows, expected.app_indexes, frame.rowSlice()) |expected_name, expected_index, row| {
            const app_index = switch (row) {
                .app => |index| index,
            };
            if (app_index != expected_index or app_index >= transcript.applications.len) {
                return error.TranscriptMismatch;
            }
            if (!std.mem.eql(u8, expected_name, transcript.applications[app_index].name)) {
                return error.TranscriptMismatch;
            }
        }
        if (frame.row_count > 0 and expected.selected_row != frame.selected_row) {
            return error.TranscriptMismatch;
        }
        if (expected.result == .fail) return error.SdlDrawFailed;
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
        if (transcript.mismatch or transcript.index != transcript.steps.len) {
            return error.TranscriptMismatch;
        }
    }
};

fn simulate(steps: []const Step) !void {
    const selected = try simulateApps(steps, &.{});
    if (selected != null) return error.UnexpectedSelection;
}

fn simulateApps(steps: []const Step, applications: []const apps.App) !?usize {
    if (steps.len > step_capacity) return error.TranscriptTooLong;
    var transcript = Transcript{ .steps = steps, .applications = applications };
    const result = picker.run(&transcript, applications);
    try transcript.done();
    return result;
}

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
            .rows = &.{ "Firefox", "Kitty" },
            .app_indexes = &.{ 0, 1 },
        } },
        .{ .wait = .{ .event = .down } },
        .{ .draw = .{
            .query = "",
            .rows = &.{ "Firefox", "Kitty" },
            .app_indexes = &.{ 0, 1 },
            .selected_row = 1,
        } },
        .{ .wait = .{ .event = .{ .text = try picker.Text.init("fire") } } },
        .{ .draw = .{
            .query = "fire",
            .rows = &.{"Firefox"},
            .app_indexes = &.{0},
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
    const initial_names = [_][]const u8{
        "App 00", "App 01", "App 02", "App 03", "App 04", "App 05", "App 06",
        "App 07", "App 08", "App 09", "App 10", "App 11", "App 12", "App 13",
    };
    const initial_indexes = [_]u16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    const scrolled_names = [_][]const u8{
        "App 02", "App 03", "App 04", "App 05", "App 06", "App 07", "App 08",
        "App 09", "App 10", "App 11", "App 12", "App 13", "App 14", "App 15",
    };
    const scrolled_indexes = [_]u16{ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const selected = try simulateApps(&.{
        .{ .init = .ok },
        .{ .create = .ok },
        .{ .start_text = .ok },
        .{ .draw = .{
            .query = "",
            .rows = &initial_names,
            .app_indexes = &initial_indexes,
        } },
        .{ .wait = .{ .event = .{ .scroll = 2 } } },
        .{ .draw = .{
            .query = "",
            .rows = &scrolled_names,
            .app_indexes = &scrolled_indexes,
        } },
        .{ .wait = .{ .event = .{ .hover = 5 } } },
        .{ .draw = .{
            .query = "",
            .rows = &scrolled_names,
            .app_indexes = &scrolled_indexes,
            .selected_row = 5,
        } },
        .{ .wait = .{ .event = .{ .click = 5 } } },
        .{ .stop_text = .ok },
        .destroy,
        .quit,
    }, &applications);
    try std.testing.expectEqual(@as(?usize, 7), selected);
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
        .issues = .initEmpty(),
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
    const steps = [_]Step{.{ .init = .fail }} ** (step_capacity + 1);
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
