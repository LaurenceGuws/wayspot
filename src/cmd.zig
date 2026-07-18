//! Resolves bounded beta arguments into one performable product meaning.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("apps.zig");

pub const argument_capacity = 64;
pub const query_capacity = apps.query_capacity;

pub const Cmd = union(enum) {
    apps: union(enum) {
        list: []const u8,
        open: u16,
    },
    notifications: union(enum) {
        run,
        history,
    },
};

comptime {
    std.debug.assert(std.meta.fields(Cmd).len == 2);
    std.debug.assert(std.meta.fields(@FieldType(Cmd, "apps")).len == 2);
    std.debug.assert(std.meta.fields(@FieldType(Cmd, "notifications")).len == 2);
    std.debug.assert(apps.app_capacity <= std.math.maxInt(u16) + 1);
}

/// Resolves notification arguments without application discovery.
pub fn resolveNotifications(argv: []const []const u8) !?Cmd {
    if (argv.len > argument_capacity) return error.TooManyArguments;
    if (argv.len == 0 or !std.mem.eql(u8, argv[0], "notifications")) return null;
    if (argv.len == 1) return .{ .notifications = .run };
    if (argv.len == 2 and std.mem.eql(u8, argv[1], "history")) {
        return .{ .notifications = .history };
    }
    return error.NotificationArgumentsInvalid;
}

/// Resolves app arguments after discovery into caller-owned query bytes.
pub fn resolveApps(
    argv: []const []const u8,
    applications: []const apps.App,
    query_bytes: *[query_capacity]u8,
) !Cmd {
    if (argv.len == 0) return error.ArgumentsInvalid;
    if (argv.len > argument_capacity) return error.TooManyArguments;
    if (applications.len > apps.app_capacity) return error.TooManyApplications;

    const values = if (std.mem.eql(u8, argv[0], "apps")) argv[1..] else argv;
    const query = try join(values, query_bytes);
    if (std.mem.eql(u8, argv[0], "apps")) return .{ .apps = .{ .list = query } };

    const index = try apps.exact(applications, query);
    if (index > std.math.maxInt(u16)) return error.ApplicationIndexTooLarge;
    return .{ .apps = .{ .open = @intCast(index) } };
}

fn join(values: []const []const u8, query_bytes: *[query_capacity]u8) ![]const u8 {
    var length: usize = 0;
    for (values, 0..) |value, index| {
        if (!std.unicode.utf8ValidateSlice(value)) return error.QueryInvalid;
        if (index > 0) {
            if (length == query_capacity) return error.QueryTooLong;
            length += 1;
        }
        if (value.len > query_capacity - length) return error.QueryTooLong;
        length += value.len;
    }

    var used: usize = 0;
    for (values, 0..) |value, index| {
        if (index > 0) {
            query_bytes[used] = ' ';
            used += 1;
        }
        @memcpy(query_bytes[used..][0..value.len], value);
        used += value.len;
    }
    std.debug.assert(used == length);
    return query_bytes[0..used];
}

test "notification meanings resolve before applications exist" {
    try expectNotifications(&.{"notifications"}, .run);
    try expectNotifications(&.{ "notifications", "history" }, .history);
    try std.testing.expectEqual(@as(?Cmd, null), try resolveNotifications(&.{"apps"}));
    try std.testing.expectError(
        error.NotificationArgumentsInvalid,
        resolveNotifications(&.{ "notifications", "unknown" }),
    );
}

test "apps list borrows one exact bounded query" {
    var bytes: [query_capacity]u8 = @splat(0xaa);
    const command = try resolveApps(&.{ "apps", "terminal", "editor" }, &.{}, &bytes);
    try std.testing.expectEqualStrings("terminal editor", command.apps.list);

    const exact = "x" ** query_capacity;
    const boundary = try resolveApps(&.{ "apps", exact }, &.{}, &bytes);
    try std.testing.expectEqualStrings(exact, boundary.apps.list);

    const before = bytes;
    try std.testing.expectError(
        error.QueryTooLong,
        resolveApps(&.{ "apps", exact, "" }, &.{}, &bytes),
    );
    try std.testing.expectEqualSlices(u8, &before, &bytes);
}

test "only exact identities become checked app indexes" {
    const applications = [_]apps.App{
        testApp("alpha.desktop", "Alpha"),
        testApp("ghostty.desktop", "Ghostty"),
        testApp("other-ghostty.desktop", "Ghostty"),
    };
    var bytes: [query_capacity]u8 = undefined;
    try expectOpen(try resolveApps(&.{"Alpha"}, &applications, &bytes), 0);
    try expectOpen(try resolveApps(&.{"ghostty.desktop"}, &applications, &bytes), 1);
    try std.testing.expectError(
        error.ApplicationAmbiguous,
        resolveApps(&.{"Ghostty"}, &applications, &bytes),
    );
    try std.testing.expectError(
        error.ApplicationNotFound,
        resolveApps(&.{"ghsotty"}, &applications, &bytes),
    );
}

test "invalid UTF-8 and argument overflow publish no command or query" {
    var bytes: [query_capacity]u8 = @splat(0x5a);
    const before = bytes;
    try std.testing.expectError(
        error.QueryInvalid,
        resolveApps(&.{ "apps", "\xff" }, &.{}, &bytes),
    );
    try std.testing.expectEqualSlices(u8, &before, &bytes);

    const too_many = [_][]const u8{"x"} ** (argument_capacity + 1);
    try std.testing.expectError(
        error.TooManyArguments,
        resolveApps(&too_many, &.{}, &bytes),
    );
    try std.testing.expectError(error.TooManyArguments, resolveNotifications(&too_many));
    try std.testing.expectEqualSlices(u8, &before, &bytes);
}

test "exact argument capacity is accepted and the next argument is rejected" {
    var exact = [_][]const u8{""} ** argument_capacity;
    exact[0] = "apps";
    var bytes: [query_capacity]u8 = undefined;
    const command = try resolveApps(&exact, &.{}, &bytes);
    try std.testing.expect(command == .apps);
    try std.testing.expectEqual(argument_capacity - 2, command.apps.list.len);

    const too_many = [_][]const u8{""} ** (argument_capacity + 1);
    try std.testing.expectError(
        error.TooManyArguments,
        resolveApps(&too_many, &.{}, &bytes),
    );
}

test "arbitrary app argument bytes remain bounded and exact" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzArguments, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzArguments({}, &empty);
}

fn fuzzArguments(_: void, smith: *std.testing.Smith) !void {
    var input: [query_capacity + 1]u8 = undefined;
    const value = input[0..smith.slice(&input)];
    var bytes: [query_capacity]u8 = @splat(0x7f);
    const before = bytes;
    const command = resolveApps(&.{ "apps", value }, &.{}, &bytes) catch {
        if (value.len <= query_capacity and std.unicode.utf8ValidateSlice(value)) {
            return error.UnexpectedResolutionFailure;
        }
        try std.testing.expectEqualSlices(u8, &before, &bytes);
        return;
    };
    try std.testing.expect(command == .apps);
    try std.testing.expect(command.apps == .list);
    try std.testing.expectEqualSlices(u8, value, command.apps.list);
}

fn expectNotifications(argv: []const []const u8, expected: @FieldType(Cmd, "notifications")) !void {
    const command = (try resolveNotifications(argv)).?;
    try std.testing.expect(command == .notifications);
    try std.testing.expectEqual(expected, command.notifications);
}

fn expectOpen(command: Cmd, expected: u16) !void {
    try std.testing.expect(command == .apps);
    try std.testing.expect(command.apps == .open);
    try std.testing.expectEqual(expected, command.apps.open);
}

fn testApp(id: []const u8, name: []const u8) apps.App {
    return .{
        .storage = @constCast(""),
        .id = id,
        .name = name,
        .generic_name = null,
        .keywords = null,
        .icon = null,
        .exec = "true",
        .try_exec = null,
        .only_show_in = null,
        .not_show_in = null,
        .path = null,
        .terminal = false,
        .issues = .initEmpty(),
    };
}
