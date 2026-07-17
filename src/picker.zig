//! Owns deterministic picker state and control flow.

const std = @import("std");
const apps = @import("apps.zig");

pub const query_capacity = 256;
pub const visible_row_capacity = 32;

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
            },
            .up => state.selected -|= 1,
            .down => {
                const matched_count = matchCount(applications, state.query.text());
                if (state.selected + 1 < matched_count) state.selected += 1;
            },
            .enter => return selectedApp(applications, state.query.text(), state.selected),
            .text => |text| {
                try state.query.append(text.slice());
                state.selected = 0;
            },
            .ignored => continue,
        }
        frame = makeFrame(state, applications);
        try operations.draw(&frame);
    }
}

fn makeFrame(state: *const State, applications: []const apps.App) Frame {
    var frame = Frame{ .query = state.query.text() };
    const first = if (state.selected < visible_row_capacity)
        0
    else
        state.selected - visible_row_capacity + 1;
    var matched: usize = 0;
    for (applications, 0..) |app, app_index| {
        if (!matches(app, state.query.text())) continue;
        if (matched >= first and frame.row_count < visible_row_capacity) {
            frame.rows[frame.row_count] = .{ .app_index = app_index, .name = app.name };
            frame.row_count += 1;
        }
        matched += 1;
    }
    if (frame.row_count > 0) {
        std.debug.assert(state.selected >= first);
        std.debug.assert(state.selected < matched);
        frame.selected_row = state.selected - first;
    }
    return frame;
}

fn selectedApp(applications: []const apps.App, query: []const u8, selected: usize) ?usize {
    var matched: usize = 0;
    for (applications, 0..) |app, index| {
        if (!matches(app, query)) continue;
        if (matched == selected) return index;
        matched += 1;
    }
    return null;
}

fn matchCount(applications: []const apps.App, query: []const u8) usize {
    var count: usize = 0;
    for (applications) |app| {
        if (matches(app, query)) count += 1;
    }
    return count;
}

fn matches(app: apps.App, query: []const u8) bool {
    if (query.len == 0) return true;
    if (containsIgnoreCase(app.id, query)) return true;
    if (containsIgnoreCase(app.name, query)) return true;
    if (app.generic_name) |value| if (containsIgnoreCase(value, query)) return true;
    if (app.keywords) |value| if (containsIgnoreCase(value, query)) return true;
    return false;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..haystack.len - needle.len + 1) |index| {
        if (std.ascii.eqlIgnoreCase(haystack[index..][0..needle.len], needle)) return true;
    }
    return false;
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

test "application matching uses desktop id name generic name and keywords" {
    const app = testApp("Kitty", "Terminal", "shell;console;");
    try std.testing.expect(matches(app, "test"));
    try std.testing.expect(matches(app, "kit"));
    try std.testing.expect(matches(app, "TERM"));
    try std.testing.expect(matches(app, "console"));
    try std.testing.expect(!matches(app, "browser"));
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
