//! Owns deterministic picker state and control flow.

const std = @import("std");
const apps = @import("apps.zig");

pub const query_capacity = apps.query_capacity;
pub const visible_row_capacity = 18;
pub const query_height: f32 = 48;
pub const row_height: f32 = 24;

/// Text owns one bounded SDL text event after the native event returns.
pub const Text = struct {
    bytes: [query_capacity]u8 = undefined,
    len: usize,

    pub fn init(input: []const u8) !Text {
        if (input.len > query_capacity) return error.TextTooLong;
        var text: Text = .{ .len = input.len };
        @memcpy(text.bytes[0..input.len], input);
        return text;
    }

    pub fn slice(text: *const Text) []const u8 {
        return text.bytes[0..text.len];
    }
};

/// Event is the complete SDL input vocabulary understood by the current picker.
pub const Event = union(enum) {
    quit,
    escape,
    backspace,
    up,
    down,
    enter,
    text: Text,
    hover: usize,
    click: usize,
    scroll_up,
    scroll_down,
    idle,
    ignored,
};

pub const Row = struct {
    app_index: usize,
    name: []const u8,
};

pub const Frame = struct {
    query: [:0]const u8,
    rows: [visible_row_capacity]Row = undefined,
    row_count: usize = 0,
    selected_row: usize = 0,
    first: usize = 0,
    total_count: usize = 0,

    pub fn rowSlice(frame: *const Frame) []const Row {
        return frame.rows[0..frame.row_count];
    }
};

const Query = struct {
    bytes: [query_capacity:0]u8 = @splat(0),
    len: usize = 0,

    fn append(query: *Query, input: []const u8) !void {
        if (!std.unicode.utf8ValidateSlice(input)) return error.InvalidText;
        if (input.len > query_capacity - query.len) return error.QueryTooLong;
        @memcpy(query.bytes[query.len..][0..input.len], input);
        query.len += input.len;
        query.bytes[query.len] = 0;
    }

    fn delete(query: *Query) void {
        if (query.len == 0) return;
        query.len -= 1;
        while (query.len > 0 and textContinuation(query.bytes[query.len])) query.len -= 1;
        query.bytes[query.len] = 0;
    }

    fn text(query: *const Query) [:0]const u8 {
        return query.bytes[0..query.len :0];
    }
};

fn textContinuation(byte: u8) bool {
    return byte & 0b1100_0000 == 0b1000_0000;
}

/// Runs one picker against a concrete operation owner.
///
/// The operation type is compile-time concrete so plain tests need neither an
/// erased interface nor an SDL link. It must provide init, create, startText,
/// wait, draw, stopText, destroy, and quit. A text-stop failure takes
/// precedence over the event-loop result because incomplete cleanup is the
/// final process state; window destruction and SDL quit still run.
pub fn run(operations: anytype, applications: []const apps.App) !?usize {
    try operations.init();
    defer operations.quit();

    try operations.create();
    defer operations.destroy();

    try operations.startText();

    var state: State = .{};
    const result = events(operations, applications, &state);
    try operations.stopText();
    return result;
}

const State = struct {
    query: Query = .{},
    selected: usize = 0,
    first: usize = 0,
};

fn events(operations: anytype, applications: []const apps.App, state: *State) !?usize {
    var frame = makeFrame(state, applications);
    try operations.draw(&frame);

    while (true) {
        switch (try operations.wait()) {
            .quit, .escape => return null,
            .backspace => {
                state.query.delete();
                state.selected = 0;
                state.first = 0;
            },
            .up => {
                state.selected -|= 1;
                keepSelectedVisible(state);
            },
            .down => {
                const matched_count = matchCount(applications, state.query.text());
                if (state.selected + 1 < matched_count) state.selected += 1;
                keepSelectedVisible(state);
            },
            .enter => return selectedApp(applications, state.query.text(), state.selected),
            .text => |text| {
                try state.query.append(text.slice());
                state.selected = 0;
                state.first = 0;
            },
            .hover => |row| {
                if (visibleSelection(state, row, matchCount(applications, state.query.text()))) |selected| {
                    state.selected = selected;
                }
            },
            .click => |row| {
                state.selected = visibleSelection(
                    state,
                    row,
                    matchCount(applications, state.query.text()),
                ) orelse continue;
                return selectedApp(applications, state.query.text(), state.selected);
            },
            .scroll_up => scroll(state, matchCount(applications, state.query.text()), false),
            .scroll_down => scroll(state, matchCount(applications, state.query.text()), true),
            .ignored => continue,
            .idle => {},
        }
        frame = makeFrame(state, applications);
        try operations.draw(&frame);
    }
}

fn makeFrame(state: *const State, applications: []const apps.App) Frame {
    const found = apps.Matches.init(applications, state.query.text());
    var frame = Frame{
        .query = state.query.text(),
        .first = @min(state.first, found.count),
        .total_count = found.count,
    };
    for (found.slice()[frame.first..]) |app_index| {
        if (frame.row_count == visible_row_capacity) break;
        frame.rows[frame.row_count] = .{ .app_index = app_index, .name = applications[app_index].name };
        frame.row_count += 1;
    }
    if (frame.row_count > 0) {
        std.debug.assert(state.selected >= frame.first);
        std.debug.assert(state.selected < found.count);
        frame.selected_row = state.selected - frame.first;
    }
    return frame;
}

fn keepSelectedVisible(state: *State) void {
    if (state.selected < state.first) state.first = state.selected;
    if (state.selected >= state.first + visible_row_capacity) {
        state.first = state.selected - visible_row_capacity + 1;
    }
}

fn visibleSelection(state: *const State, row: usize, total: usize) ?usize {
    if (row >= visible_row_capacity or state.first + row >= total) return null;
    return state.first + row;
}

fn scroll(state: *State, total: usize, down: bool) void {
    const max_first = total -| visible_row_capacity;
    state.first = if (down) @min(max_first, state.first +| 3) else state.first -| 3;
    if (total == 0) {
        state.selected = 0;
    } else {
        state.selected = std.math.clamp(state.selected, state.first, @min(total - 1, state.first + visible_row_capacity - 1));
    }
}

fn selectedApp(applications: []const apps.App, query: []const u8, selected: usize) ?usize {
    const found = apps.Matches.init(applications, query);
    return if (selected < found.count) found.indexes[selected] else null;
}

fn matchCount(applications: []const apps.App, query: []const u8) usize {
    return apps.Matches.init(applications, query).count;
}

test "query accepts its exact bound and rejects the next byte without mutation" {
    var query: Query = .{};
    try query.append(&([_]u8{'a'} ** query_capacity));
    try std.testing.expectError(error.QueryTooLong, query.append("b"));
    try std.testing.expectEqual(query_capacity, query.len);
    try std.testing.expectEqual(@as(u8, 0), query.bytes[query_capacity]);
}

test "query rejects invalid UTF-8 without mutation" {
    var query: Query = .{};
    try query.append("valid");
    try std.testing.expectError(error.InvalidText, query.append("\xff"));
    try std.testing.expectEqualStrings("valid", query.text());
}

test "text event owns its exact bound" {
    const input = [_]u8{'a'} ** query_capacity;
    const text = try Text.init(&input);
    try std.testing.expectEqualSlices(u8, &input, text.slice());
    try std.testing.expectError(error.TextTooLong, Text.init(&(input ++ [_]u8{'b'})));
}

test "backspace removes one UTF-8 codepoint and maintains termination" {
    var query: Query = .{};
    try query.append("aλ");
    query.delete();
    try std.testing.expectEqualStrings("a", query.text());
    query.delete();
    query.delete();
    try std.testing.expectEqualStrings("", query.text());
}

test "viewport follows keys and wheel without exceeding results" {
    var state: State = .{};
    state.selected = visible_row_capacity;
    keepSelectedVisible(&state);
    try std.testing.expectEqual(@as(usize, 1), state.first);
    scroll(&state, 40, true);
    try std.testing.expectEqual(@as(usize, 4), state.first);
    try std.testing.expectEqual(@as(usize, visible_row_capacity), state.selected);
    scroll(&state, 2, true);
    try std.testing.expectEqual(@as(usize, 0), state.first);
    try std.testing.expectEqual(@as(usize, 1), state.selected);
}

fn testApp(name: []const u8, generic_name: ?[]const u8, keywords: ?[]const u8) apps.App {
    return .{
        .storage = @constCast(""),
        .id = "test.desktop",
        .name = name,
        .generic_name = generic_name,
        .keywords = keywords,
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
