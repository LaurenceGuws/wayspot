//! Owns deterministic picker state and control flow.

const std = @import("std");
const apps = @import("apps.zig");

pub const query_capacity = apps.query_capacity;
pub const visible_row_capacity = 14;
pub const event_capacity = 64;
const events_before_draw_capacity = 1024;

pub const Table = enum {
    apps,
};

pub const Row = union(enum) {
    app: u16,
};

pub const Rows = union(Table) {
    apps: struct {
        applications: []const apps.App,
        matches: apps.Matches,
    },

    pub fn initApps(applications: []const apps.App, query: []const u8) !Rows {
        if (applications.len > apps.app_capacity) return error.TooManyApplications;
        if (query.len > query_capacity) return error.QueryTooLong;
        if (!std.unicode.utf8ValidateSlice(query)) return error.InvalidText;
        const matches = apps.Matches.init(applications, query);
        for (matches.slice()) |index| {
            if (index >= applications.len or index > std.math.maxInt(u16)) {
                return error.ApplicationIndexInvalid;
            }
        }
        return .{ .apps = .{ .applications = applications, .matches = matches } };
    }

    pub fn count(rows: *const Rows) usize {
        return switch (rows.*) {
            .apps => |app_rows| app_rows.matches.count,
        };
    }

    pub fn row(rows: *const Rows, index: usize) ?Row {
        return switch (rows.*) {
            .apps => |app_rows| {
                if (index >= app_rows.matches.count) return null;
                const app_index = app_rows.matches.indexes[index];
                if (app_index >= app_rows.applications.len or app_index > std.math.maxInt(u16)) {
                    return null;
                }
                return .{ .app = @intCast(app_index) };
            },
        };
    }
};

comptime {
    std.debug.assert(std.meta.fields(Table).len == 1);
    std.debug.assert(std.meta.fields(Row).len == 1);
    std.debug.assert(std.meta.fields(Rows).len == 1);
    std.debug.assert(apps.app_capacity <= std.math.maxInt(u16) + 1);
}

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
    scroll: i8,
    redraw,
    idle,
    ignored,
};

pub const Events = struct {
    items: [event_capacity]Event = undefined,
    count: usize = 0,
    more: bool = false,

    pub fn slice(events: *const Events) []const Event {
        return events.items[0..events.count];
    }
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
/// read, draw, stopText, destroy, and quit. A text-stop failure takes
/// precedence over the event-loop result because incomplete cleanup is the
/// final process state; window destruction and SDL quit still run.
pub fn run(operations: anytype, applications: []const apps.App) !?usize {
    try operations.init();
    defer operations.quit();

    try operations.create();
    defer operations.destroy();

    try operations.startText();

    var state: State = .{};
    const result = eventLoop(operations, applications, &state);
    try operations.stopText();
    return result;
}

const State = struct {
    query: Query = .{},
    rows: Rows = .{ .apps = .{ .applications = &.{}, .matches = .{} } },
    selected: usize = 0,
    first: usize = 0,

    fn setQuery(state: *State, applications: []const apps.App, query: Query) !void {
        const rows = try Rows.initApps(applications, query.text());
        state.query = query;
        state.rows = rows;
        state.selected = 0;
        state.first = 0;
    }

    fn selection(state: *const State) ?usize {
        const row = state.rows.row(state.selected) orelse return null;
        return switch (row) {
            .app => |index| @intCast(index),
        };
    }
};

fn eventLoop(operations: anytype, applications: []const apps.App, state: *State) !?usize {
    state.rows = try Rows.initApps(applications, state.query.text());
    var frame = makeFrame(state);
    try operations.draw(&frame);

    var events_since_draw: usize = 0;
    var changed_since_draw = false;
    while (true) {
        const events = try operations.read();
        std.debug.assert(events.count > 0);
        for (events.slice()) |event| {
            switch (event) {
                .quit, .escape => return null,
                .backspace => {
                    var query = state.query;
                    query.delete();
                    try state.setQuery(applications, query);
                },
                .up => {
                    state.selected -|= 1;
                    keepSelectedVisible(state);
                },
                .down => {
                    if (state.selected + 1 < state.rows.count()) state.selected += 1;
                    keepSelectedVisible(state);
                },
                .enter => return state.selection(),
                .text => |text| {
                    var query = state.query;
                    try query.append(text.slice());
                    try state.setQuery(applications, query);
                },
                .hover => |row| {
                    if (visibleSelection(state, row, state.rows.count())) |selected| {
                        state.selected = selected;
                    }
                },
                .click => |row| {
                    state.selected = visibleSelection(
                        state,
                        row,
                        state.rows.count(),
                    ) orelse continue;
                    return state.selection();
                },
                .scroll => |rows| scroll(state, state.rows.count(), rows),
                .redraw => {},
                .ignored => continue,
                .idle => {},
            }
            changed_since_draw = true;
        }
        events_since_draw += events.count;
        if (events.more and events_since_draw < events_before_draw_capacity) continue;
        if (!changed_since_draw) {
            events_since_draw = 0;
            continue;
        }
        events_since_draw = 0;
        changed_since_draw = false;
        frame = makeFrame(state);
        try operations.draw(&frame);
    }
}

fn makeFrame(state: *const State) Frame {
    var frame = Frame{
        .query = state.query.text(),
        .first = @min(state.first, state.rows.count()),
        .total_count = state.rows.count(),
    };
    while (frame.first + frame.row_count < frame.total_count) {
        if (frame.row_count == visible_row_capacity) break;
        frame.rows[frame.row_count] = state.rows.row(frame.first + frame.row_count) orelse unreachable;
        frame.row_count += 1;
    }
    if (frame.row_count > 0) {
        std.debug.assert(state.selected >= frame.first);
        std.debug.assert(state.selected < frame.total_count);
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

fn scroll(state: *State, total: usize, rows: i8) void {
    const max_first = total -| visible_row_capacity;
    state.first = if (rows < 0)
        state.first -| @as(usize, @intCast(-@as(i16, rows)))
    else
        @min(max_first, state.first +| @as(usize, @intCast(rows)));
    if (total == 0) {
        state.selected = 0;
    } else {
        state.selected = std.math.clamp(state.selected, state.first, @min(total - 1, state.first + visible_row_capacity - 1));
    }
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
    scroll(&state, 40, 3);
    try std.testing.expectEqual(@as(usize, 4), state.first);
    try std.testing.expectEqual(@as(usize, visible_row_capacity), state.selected);
    scroll(&state, 2, 3);
    try std.testing.expectEqual(@as(usize, 0), state.first);
    try std.testing.expectEqual(@as(usize, 1), state.selected);
}

test "apps rows borrow one app slice and return only checked indexes" {
    const applications = [_]apps.App{
        testApp("Zulu", null, null),
        testApp("Alpha", null, null),
    };
    const rows = try Rows.initApps(&applications, "");
    try std.testing.expect(rows == .apps);
    try std.testing.expect(rows.apps.applications.ptr == &applications);
    try std.testing.expectEqual(@as(usize, 2), rows.count());
    try std.testing.expectEqual(Row{ .app = 1 }, rows.row(0).?);
    try std.testing.expectEqual(Row{ .app = 0 }, rows.row(1).?);
    try std.testing.expectEqual(@as(?Row, null), rows.row(2));
    try std.testing.expect(@sizeOf(Row) <= @sizeOf(u16) * 2);
}

test "failed rows transition preserves query rows and selection" {
    const applications = [_]apps.App{testApp("Alpha", null, null)};
    var state: State = .{
        .rows = try Rows.initApps(&applications, ""),
        .selected = 0,
        .first = 0,
    };
    const before_rows = state.rows;
    var invalid: Query = .{};
    invalid.bytes[0] = 0xff;
    invalid.len = 1;
    try std.testing.expectError(error.InvalidText, state.setQuery(&applications, invalid));
    try std.testing.expectEqualStrings("", state.query.text());
    try std.testing.expectEqual(before_rows.apps.applications.ptr, state.rows.apps.applications.ptr);
    try std.testing.expectEqual(before_rows.apps.matches.count, state.rows.apps.matches.count);
    try std.testing.expectEqual(@as(usize, 0), state.selected);
    try std.testing.expectEqual(@as(usize, 0), state.first);
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
