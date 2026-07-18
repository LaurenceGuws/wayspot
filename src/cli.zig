//! Owns bounded beta CLI presentation.

const std = @import("std");
const apps = @import("apps.zig");

pub const output_capacity = apps.app_capacity * (apps.name_capacity + 1);

pub const help =
    \\usage:
    \\  wayspot-beta
    \\  wayspot-beta apps [terms...]
    \\  wayspot-beta <exact application name or desktop id>
    \\
;

pub fn writeHelp(output: anytype) !void {
    try output.writeAll(help);
}

pub fn writeApps(output: anytype, applications: []const apps.App, query: []const u8) !void {
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

test "apps output is bounded and byte exact" {
    const applications = [_]apps.App{
        testApp("alpha.desktop", "Alpha"),
        testApp("beta.desktop", "Beta"),
    };
    var output = Transcript{ .expected = "Alpha\nBeta\n" };
    try writeApps(&output, &applications, "");
    try std.testing.expect(output.done());

    var filtered = Transcript{ .expected = "Beta\n" };
    try writeApps(&filtered, &applications, "bet");
    try std.testing.expect(filtered.done());
}

test "typo output remains a suggestion" {
    const ghostty = testApp("ghostty.desktop", "Ghostty");
    var listed = Transcript{ .expected = "Ghostty\n" };
    try writeApps(&listed, &.{ghostty}, "ghsotty");
    try std.testing.expect(listed.done());
}

test "help and output failures are exact" {
    const app = testApp("alpha.desktop", "Alpha");
    var failed = Transcript{ .expected = "Alpha\n", .fail_at = 5 };
    try std.testing.expectError(error.WriteFailed, writeApps(&failed, &.{app}, ""));

    var usage = Transcript{ .expected = help };
    try writeHelp(&usage);
    try std.testing.expect(usage.done());
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
