//! Owns deterministic picker state and control flow.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("apps.zig");
const notification_history = @import("notification_history.zig");

pub const query_capacity = apps.query_capacity;
pub const visible_row_capacity = 14;
pub const event_capacity = 64;
const events_before_draw_capacity = 1024;

/// Table is the closed GUI navigation vocabulary; it is not a CLI meaning.
pub const Table = enum {
    root,
    apps,
    notifications,
};

/// Row borrows its value from the current Rows owner and cannot outlive it.
pub const Row = union(enum) {
    table: Table,
    app: u16,
    notification: *const notification_history.Record,
};

/// Rows owns one table: apps borrow, root is static, and notifications allocate.
pub const Rows = union(Table) {
    root,
    apps: struct {
        applications: []const apps.App,
        matches: apps.Matches,
    },
    notifications: notification_history.History,

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

    pub fn deinit(rows: *Rows, allocator: std.mem.Allocator) void {
        switch (rows.*) {
            .root, .apps => {},
            .notifications => |*history| history.deinit(allocator),
        }
        rows.* = .{ .apps = .{ .applications = &.{}, .matches = .{} } };
    }

    pub fn count(rows: *const Rows, query: []const u8) usize {
        return switch (rows.*) {
            .root => rootCount(query),
            .apps => |app_rows| app_rows.matches.count,
            .notifications => |history| history.count,
        };
    }

    pub fn row(rows: *const Rows, query: []const u8, index: usize) ?Row {
        return switch (rows.*) {
            .root => rootRow(query, index),
            .apps => |app_rows| {
                if (index >= app_rows.matches.count) return null;
                const app_index = app_rows.matches.indexes[index];
                if (app_index >= app_rows.applications.len or app_index > std.math.maxInt(u16)) {
                    return null;
                }
                return .{ .app = @intCast(app_index) };
            },
            .notifications => |*history| {
                if (index >= history.count) return null;
                return .{ .notification = &history.records[history.count - 1 - index].? };
            },
        };
    }
};

const root_rows = [2]Row{
    .{ .table = .apps },
    .{ .table = .notifications },
};

pub fn tableName(table: Table) [:0]const u8 {
    return switch (table) {
        .root => "/",
        .apps => "apps",
        .notifications => "notifications",
    };
}

fn rootCount(query: []const u8) usize {
    if (query.len == 0 or query[0] != '/') return 0;
    var count: usize = 0;
    for (root_rows) |row| count += @intFromBool(rootMatches(row.table, query[1..]));
    return count;
}

fn rootRow(query: []const u8, want: usize) ?Row {
    if (query.len == 0 or query[0] != '/') return null;
    var found: usize = 0;
    for (root_rows) |row| {
        if (!rootMatches(row.table, query[1..])) continue;
        if (found == want) return row;
        found += 1;
    }
    return null;
}

fn rootMatches(table: Table, prefix: []const u8) bool {
    const name = tableName(table);
    return prefix.len <= name.len and std.ascii.eqlIgnoreCase(name[0..prefix.len], prefix);
}

comptime {
    std.debug.assert(std.meta.fields(Table).len == 3 and
        std.meta.fields(Row).len == 3 and
        std.meta.fields(Rows).len == 3 and
        apps.app_capacity <= std.math.maxInt(u16) + 1);
    std.debug.assert(root_rows.len == 2 and
        root_rows[0].table == .apps and
        root_rows[1].table == .notifications);
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
    table: Table = .apps,
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

    fn set(query: *Query, input: []const u8) !void {
        var next: Query = .{};
        try next.append(input);
        query.* = next;
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
/// final process state; window destruction and SDL quit still run. The separate
/// concrete history reader is called only by the exact notifications route.
pub fn run(
    operations: anytype,
    history_reader: anytype,
    allocator: std.mem.Allocator,
    applications: []const apps.App,
) !?usize {
    var owned_rows: ?*Rows = null;
    defer if (owned_rows) |rows| rows.deinit(allocator);

    try operations.init();
    defer operations.quit();

    try operations.create();
    defer operations.destroy();

    try operations.startText();

    var state: State = .{};
    owned_rows = &state.rows;
    const result = eventLoop(operations, history_reader, allocator, applications, &state);
    try operations.stopText();
    return result;
}

const State = struct {
    query: Query = .{},
    rows: Rows = .{ .apps = .{ .applications = &.{}, .matches = .{} } },
    selected: usize = 0,
    first: usize = 0,

    fn setQuery(
        state: *State,
        history_reader: anytype,
        allocator: std.mem.Allocator,
        applications: []const apps.App,
        query: Query,
    ) !void {
        const rows = try openRows(history_reader, applications, query.text());
        state.rows.deinit(allocator);
        state.query = query;
        state.rows = rows;
        state.selected = 0;
        state.first = 0;
    }

    fn row(state: *const State, index: usize) ?Row {
        return state.rows.row(state.query.text(), index);
    }

    fn selectRow(
        state: *State,
        history_reader: anytype,
        allocator: std.mem.Allocator,
        applications: []const apps.App,
        selected: Row,
    ) !?usize {
        return switch (selected) {
            .table => |table| {
                var query: Query = .{};
                try query.set(switch (table) {
                    .root => "/",
                    .apps => "/apps",
                    .notifications => "/notifications",
                });
                try state.setQuery(history_reader, allocator, applications, query);
                return null;
            },
            .app => |index| @intCast(index),
            .notification => null,
        };
    }
};

fn openRows(history_reader: anytype, applications: []const apps.App, query: []const u8) !Rows {
    if (query.len == 0 or query[0] != '/') return Rows.initApps(applications, query);
    if (std.mem.eql(u8, query, "/apps")) return Rows.initApps(applications, "");
    if (std.mem.startsWith(u8, query, "/apps ")) {
        return Rows.initApps(applications, query["/apps ".len..]);
    }
    if (std.mem.eql(u8, query, "/notifications")) {
        return .{ .notifications = try history_reader.readHistory() };
    }
    return .root;
}

fn eventLoop(
    operations: anytype,
    history_reader: anytype,
    allocator: std.mem.Allocator,
    applications: []const apps.App,
    state: *State,
) !?usize {
    state.rows = try openRows(history_reader, applications, state.query.text());
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
                    try state.setQuery(history_reader, allocator, applications, query);
                },
                .up => {
                    state.selected -|= 1;
                    keepSelectedVisible(state);
                },
                .down => {
                    if (state.selected + 1 < state.rows.count(state.query.text())) state.selected += 1;
                    keepSelectedVisible(state);
                },
                .enter => {
                    const row = state.row(state.selected) orelse return null;
                    if (try state.selectRow(history_reader, allocator, applications, row)) |index| {
                        return index;
                    }
                },
                .text => |text| {
                    var query = state.query;
                    try query.append(text.slice());
                    try state.setQuery(history_reader, allocator, applications, query);
                },
                .hover => |row| {
                    if (visibleSelection(state, row, state.rows.count(state.query.text()))) |selected| {
                        state.selected = selected;
                    }
                },
                .click => |row| {
                    state.selected = visibleSelection(
                        state,
                        row,
                        state.rows.count(state.query.text()),
                    ) orelse continue;
                    const selected = state.row(state.selected) orelse continue;
                    if (try state.selectRow(history_reader, allocator, applications, selected)) |index| {
                        return index;
                    }
                },
                .scroll => |rows| scroll(state, state.rows.count(state.query.text()), rows),
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
        .table = std.meta.activeTag(state.rows),
        .query = state.query.text(),
        .first = @min(state.first, state.rows.count(state.query.text())),
        .total_count = state.rows.count(state.query.text()),
    };
    while (frame.first + frame.row_count < frame.total_count) {
        if (frame.row_count == visible_row_capacity) break;
        frame.rows[frame.row_count] = state.row(frame.first + frame.row_count) orelse unreachable;
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
    try std.testing.expectEqual(@as(usize, 2), rows.count(""));
    try std.testing.expectEqual(Row{ .app = 1 }, rows.row("", 0).?);
    try std.testing.expectEqual(Row{ .app = 0 }, rows.row("", 1).?);
    try std.testing.expectEqual(@as(?Row, null), rows.row("", 2));
    try std.testing.expectEqual(@sizeOf(u16), @sizeOf(@FieldType(Row, "app")));
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
    var history_reader: TestHistoryReader = .{};
    try std.testing.expectError(
        error.InvalidText,
        state.setQuery(&history_reader, std.testing.allocator, &applications, invalid),
    );
    try std.testing.expectEqualStrings("", state.query.text());
    try std.testing.expectEqual(before_rows.apps.applications.ptr, state.rows.apps.applications.ptr);
    try std.testing.expectEqual(before_rows.apps.matches.count, state.rows.apps.matches.count);
    try std.testing.expectEqual(@as(usize, 0), state.selected);
    try std.testing.expectEqual(@as(usize, 0), state.first);
}

test "root rows are static ordered and prefix filtered" {
    const root: Rows = .root;
    try std.testing.expectEqual(@as(usize, 2), root.count("/"));
    try std.testing.expectEqual(Row{ .table = .apps }, root.row("/", 0).?);
    try std.testing.expectEqual(Row{ .table = .notifications }, root.row("/", 1).?);
    try std.testing.expectEqual(@as(usize, 1), root.count("/ap"));
    try std.testing.expectEqual(Row{ .table = .apps }, root.row("/AP", 0).?);
    try std.testing.expectEqual(@as(usize, 0), root.count("/unknown"));
    try std.testing.expectEqualStrings("apps", tableName(.apps));
    try std.testing.expectEqualStrings("notifications", tableName(.notifications));
    try std.testing.expectEqual(@as(usize, 0), root.count("/apps/extra"));
}

test "notification rows borrow retained records newest first" {
    var history = try notification_history.parse(
        std.testing.allocator,
        "{\"received_unix_seconds\":1,\"history_id\":1,\"app_name\":\"old\",\"summary\":\"one\",\"body\":\"a\"}\n" ++
            "{\"received_unix_seconds\":2,\"history_id\":2,\"app_name\":\"new\",\"summary\":\"two\",\"body\":\"b\"}\n",
        2,
    );
    var rows = Rows{ .notifications = history };
    defer rows.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), rows.count("/notifications"));
    const newest = rows.row("/notifications", 0).?.notification;
    const oldest = rows.row("/notifications", 1).?.notification;
    try std.testing.expectEqualStrings("new", newest.app_name);
    try std.testing.expectEqualStrings("old", oldest.app_name);
    try std.testing.expect(newest == &rows.notifications.records[1].?);
    history = undefined;
}

test "route construction is lazy and history failure is atomic" {
    const applications = [_]apps.App{testApp("Alpha", null, null)};
    var state: State = .{ .rows = try Rows.initApps(&applications, "") };
    defer state.rows.deinit(std.testing.allocator);
    var history_reader: TestHistoryReader = .{};

    var query: Query = .{};
    try query.set("/");
    try state.setQuery(&history_reader, std.testing.allocator, &applications, query);
    try std.testing.expect(state.rows == .root);
    try std.testing.expectEqual(@as(usize, 0), history_reader.reads);

    try query.set("/apps alp");
    try state.setQuery(&history_reader, std.testing.allocator, &applications, query);
    try std.testing.expect(state.rows == .apps);
    try std.testing.expectEqual(@as(usize, 1), state.rows.count(state.query.text()));
    try std.testing.expectEqual(Row{ .app = 0 }, state.row(0).?);
    try std.testing.expectEqual(@as(usize, 0), history_reader.reads);

    history_reader.failure = error.HistoryOpenFailed;
    try query.set("/notifications");
    try std.testing.expectError(
        error.HistoryOpenFailed,
        state.setQuery(&history_reader, std.testing.allocator, &applications, query),
    );
    try std.testing.expect(state.rows == .apps);
    try std.testing.expectEqualStrings("/apps alp", state.query.text());
    try std.testing.expectEqual(@as(usize, 1), history_reader.reads);
}

test "generated route edits remain bounded and own one rows value" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzRoutes, .{});
        return;
    }
    var baseline = std.testing.Smith{ .in = "" };
    try fuzzRoutes({}, &baseline);
}

fn fuzzRoutes(_: void, smith: *std.testing.Smith) !void {
    const applications = [_]apps.App{testApp("Alpha", null, null)};
    var state: State = .{ .rows = try Rows.initApps(&applications, "") };
    defer state.rows.deinit(std.testing.allocator);
    var history_reader: TestHistoryReader = .{};
    const edits = [_][]const u8{
        "", "/", "/a", "/apps", "/apps alpha", "/n", "/notifications", "/unknown", "alpha",
    };
    const count = smith.valueRangeAtMost(u8, 1, 32);
    for (0..count) |_| {
        const text = edits[smith.valueRangeLessThan(u8, 0, edits.len)];
        var query: Query = .{};
        try query.set(text);
        try state.setQuery(&history_reader, std.testing.allocator, &applications, query);
        const total = state.rows.count(state.query.text());
        try std.testing.expect(total <= notification_history.record_capacity);
        if (total > 0) try std.testing.expect(state.row(0) != null);
    }
}

const TestHistoryReader = struct {
    reads: usize = 0,
    failure: ?notification_history.Error = null,

    fn readHistory(reader: *TestHistoryReader) !notification_history.History {
        reader.reads += 1;
        if (reader.failure) |failure| return failure;
        return .{};
    }
};

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
