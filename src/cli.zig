//! Owns beta argv dispatch and bounded application-list output.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("apps.zig");

pub const argument_capacity = 64;
pub const query_capacity = apps.query_capacity;
pub const output_capacity = apps.app_capacity * (apps.name_capacity + 1);

const help =
    \\usage:
    \\  wayspot-beta
    \\  wayspot-beta apps [terms...]
    \\  wayspot-beta <exact application name or desktop id>
    \\
;

/// Lists the apps capability or resolves one exact application fallback.
pub fn run(output: anytype, argv: []const []const u8, applications: []const apps.App) !?usize {
    return dispatch(output, argv, applications) catch |err| switch (err) {
        error.ArgumentsInvalid,
        error.QueryInvalid,
        error.QueryTooLong,
        error.ApplicationAmbiguous,
        error.ApplicationNotFound,
        => {
            try output.writeAll(help);
            return err;
        },
        else => |other| return other,
    };
}

fn dispatch(output: anytype, argv: []const []const u8, applications: []const apps.App) !?usize {
    if (argv.len == 0 or argv.len > argument_capacity) return error.ArgumentsInvalid;
    if (std.mem.eql(u8, argv[0], "apps")) {
        var query: Query = .{};
        try query.join(argv[1..]);
        try list(output, applications, query.slice());
        return null;
    }

    var identity: Query = .{};
    try identity.join(argv);
    return try apps.exact(applications, identity.slice());
}

const Query = struct {
    bytes: [query_capacity]u8 = undefined,
    len: usize = 0,

    fn join(query: *Query, values: []const []const u8) !void {
        query.* = .{};
        for (values, 0..) |value, index| {
            if (!std.unicode.utf8ValidateSlice(value)) return error.QueryInvalid;
            const separator: usize = @intFromBool(index > 0);
            if (separator + value.len > query_capacity - query.len) return error.QueryTooLong;
            if (separator == 1) {
                query.bytes[query.len] = ' ';
                query.len += 1;
            }
            @memcpy(query.bytes[query.len..][0..value.len], value);
            query.len += value.len;
        }
    }

    fn slice(query: *const Query) []const u8 {
        return query.bytes[0..query.len];
    }
};

fn list(output: anytype, applications: []const apps.App, query: []const u8) !void {
    const found = apps.Matches.init(applications, query);
    var bytes: usize = 0;
    for (found.slice()) |index| {
        const app = applications[index];
        if (app.name.len + 1 > output_capacity - bytes) return error.OutputTooLong;
        bytes += app.name.len + 1;
    }
    for (found.slice()) |index| {
        const app = applications[index];
        try output.writeAll(app.name);
        try output.writeAll("\n");
    }
}

const Transcript = struct {
    expected: []const u8,
    used: usize = 0,
    fail_at: ?usize = null,

    fn writeAll(transcript: *Transcript, bytes: []const u8) !void {
        if (transcript.fail_at) |limit| {
            if (transcript.used + bytes.len > limit) return error.WriteFailed;
        }
        if (bytes.len > transcript.expected.len - transcript.used) return error.TranscriptMismatch;
        if (!std.mem.eql(u8, transcript.expected[transcript.used..][0..bytes.len], bytes)) {
            return error.TranscriptMismatch;
        }
        transcript.used += bytes.len;
    }

    fn done(transcript: *const Transcript) bool {
        return transcript.used == transcript.expected.len;
    }
};

test "apps lists the same bounded matches and exact fallback selects one app" {
    const applications = [_]apps.App{
        testApp("alpha.desktop", "Alpha"),
        testApp("beta.desktop", "Beta"),
    };
    var output = Transcript{ .expected = "Alpha\nBeta\n" };
    try std.testing.expectEqual(@as(?usize, null), try run(&output, &.{"apps"}, &applications));
    try std.testing.expect(output.done());

    var filtered = Transcript{ .expected = "Beta\n" };
    try std.testing.expectEqual(@as(?usize, null), try run(&filtered, &.{ "apps", "bet" }, &applications));
    try std.testing.expect(filtered.done());

    var silent = Transcript{ .expected = "" };
    try std.testing.expectEqual(@as(?usize, 0), try run(&silent, &.{"Alpha"}, &applications));
    try std.testing.expect(silent.done());
}

test "typo lists a suggestion but cannot become executable identity" {
    const ghostty = testApp("ghostty.desktop", "Ghostty");
    var listed = Transcript{ .expected = "Ghostty\n" };
    try std.testing.expectEqual(
        @as(?usize, null),
        try run(&listed, &.{ "apps", "ghsotty" }, &.{ghostty}),
    );
    try std.testing.expect(listed.done());

    var rejected = Transcript{ .expected = help };
    try std.testing.expectError(error.ApplicationNotFound, run(&rejected, &.{"ghsotty"}, &.{ghostty}));
    try std.testing.expect(rejected.done());
}

test "argv query and output failures are bounded and exact" {
    const app = testApp("alpha.desktop", "Alpha");
    var invalid = Transcript{ .expected = help };
    try std.testing.expectError(error.ArgumentsInvalid, run(&invalid, &.{}, &.{app}));
    try std.testing.expect(invalid.done());
    var too_long = Transcript{ .expected = help };
    try std.testing.expectError(
        error.QueryTooLong,
        run(&too_long, &.{ "apps", &([_]u8{'a'} ** (query_capacity + 1)) }, &.{app}),
    );
    try std.testing.expect(too_long.done());

    var missing = Transcript{ .expected = help };
    try std.testing.expectError(error.ApplicationNotFound, run(&missing, &.{"Missing"}, &.{app}));
    try std.testing.expect(missing.done());

    var failed = Transcript{ .expected = "Alpha\n", .fail_at = 5 };
    try std.testing.expectError(error.WriteFailed, run(&failed, &.{"apps"}, &.{app}));
}

test "arbitrary CLI query bytes remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzQuery, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzQuery({}, &empty);
}

fn fuzzQuery(_: void, smith: *std.testing.Smith) !void {
    var input: [query_capacity + 1]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    var query: Query = .{};
    query.join(&.{bytes}) catch return;
    try std.testing.expect(query.len <= query_capacity);
    try std.testing.expectEqualSlices(u8, bytes, query.slice());
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
