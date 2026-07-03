//! Tool check owns small PATH executable probes for built-in launcher actions.

const std = @import("std");

const max_command_name_bytes = 128;
const max_path_entry_bytes = 512;
const max_candidate_path_bytes = 1024;
const max_path_entries = 64;

var command_exists_runner: *const fn (name: []const u8) bool = commandExistsViaPath;

pub fn commandExists(name: []const u8) bool {
    return command_exists_runner(name);
}

fn commandExistsViaPath(name: []const u8) bool {
    if (!validCommandName(name)) return false;
    const path_value = if (std.c.getenv("PATH")) |value| std.mem.span(value) else return false;

    var entries = std.mem.splitScalar(u8, path_value, ':');
    var entry_count: u32 = 0;
    while (entries.next()) |entry| {
        if (entry.len == 0) continue;
        if (entry.len > max_path_entry_bytes) return false;
        if (entry_count >= max_path_entries) return false;
        entry_count += 1;
        if (pathEntryContainsCommand(entry, name)) return true;
    }
    return false;
}

fn validCommandName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (name.len > max_command_name_bytes) return false;
    return std.mem.indexOfScalar(u8, name, '/') == null;
}

fn pathEntryContainsCommand(entry: []const u8, name: []const u8) bool {
    if (entry.len + 1 + name.len > max_candidate_path_bytes) return false;
    var candidate: [max_candidate_path_bytes:0]u8 = undefined;
    @memcpy(candidate[0..entry.len], entry);
    candidate[entry.len] = '/';
    @memcpy(candidate[entry.len + 1 .. entry.len + 1 + name.len], name);
    const candidate_len = entry.len + 1 + name.len;
    candidate[candidate_len] = 0;
    const rc = std.c.access(candidate[0..candidate_len :0].ptr, std.c.X_OK);
    return rc == 0;
}

test "commandExists delegates to direct runner" {
    const Fake = struct {
        var calls: u32 = 0;

        fn run(name: []const u8) bool {
            calls += 1;
            return std.mem.eql(u8, name, "present");
        }
    };

    command_exists_runner = Fake.run;
    defer {
        command_exists_runner = commandExistsViaPath;
    }

    try std.testing.expect(commandExists("present"));
    try std.testing.expect(!commandExists("missing"));
    try std.testing.expectEqual(@as(u32, 2), Fake.calls);
}

test "commandExists rejects empty direct and oversized names" {
    const long_name = [_]u8{'a'} ** (max_command_name_bytes + 1);

    try std.testing.expect(!commandExists(""));
    try std.testing.expect(!commandExists("bin/sh"));
    try std.testing.expect(!commandExists(&long_name));
}

test "commandExistsViaPath finds executable in bounded PATH entry" {
    try std.testing.expect(commandExistsViaPath("sh"));
}
