//! Owns bounded CLI presentation.

const std = @import("std");
const apps = @import("apps.zig");
const cmd = @import("cmd.zig");

pub const help =
    \\usage:
    \\  wayspot
    \\  wayspot wallpaper ROOT
    \\  wayspot wallpaper rotate
    \\  wayspot apps [terms...]
    \\  wayspot <exact application name or desktop id>
    \\  source <(wayspot completion bash)
    \\
;

pub fn writeApps(output: anytype, applications: []const apps.App, query: []const u8) !void {
    const found = apps.Matches.init(applications, query);
    for (found.slice()) |index| {
        const name = applications[index].name;
        std.debug.assert(name.len <= apps.name_capacity);
        try output.writeAll(name);
        try output.writeAll("\n");
    }
}

pub fn writeBash(output: anytype) !void {
    try output.writeAll(
        \\_wayspot_completion() {
        \\    COMPREPLY=()
        \\    [[ ${COMP_CWORD-} =~ ^[0-9]+$ ]] || return 0
        \\    (( COMP_CWORD < ${#COMP_WORDS[@]} )) || return 0
        \\    local current=${COMP_WORDS[COMP_CWORD]}
        \\    local -a directories
        \\    if (( COMP_CWORD == 1 )); then
        \\        mapfile -t COMPREPLY < <(compgen -W '
    );
    try writeWords(output, &cmd.modes);
    try output.writeAll(
        \\' -- "$current")
        \\        return
        \\    fi
        \\    case ${COMP_WORDS[1]-} in
        \\        apps)
        \\            mapfile -t COMPREPLY < <(
        \\                command wayspot apps "${COMP_WORDS[@]:2:COMP_CWORD-2}" "$current" 2>/dev/null
        \\            )
        \\            ;;
        \\        notifications)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W '
    );
    try writeWords(output, &cmd.notification_operations);
    try output.writeAll(
        \\' -- "$current")
        \\            ;;
        \\        wallpaper)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W '
    );
    try writeWords(output, &cmd.wallpaper_operations);
    try output.writeAll(
        \\' -- "$current")
        \\            mapfile -t directories < <(compgen -d -- "$current")
        \\            COMPREPLY+=("${directories[@]}")
        \\            compopt -o filenames 2>/dev/null || true
        \\            ;;
        \\    esac
        \\}
        \\complete -F _wayspot_completion wayspot
        \\
    );
}

fn writeWords(output: anytype, words: []const []const u8) !void {
    for (words, 0..) |word, index| {
        if (index > 0) try output.writeAll(" ");
        try output.writeAll(word);
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
    try usage.writeAll(help);
    try std.testing.expect(usage.done());
}

test "Bash definition uses current Cmd words without exposing an engine command" {
    const expected =
        \\_wayspot_completion() {
        \\    COMPREPLY=()
        \\    [[ ${COMP_CWORD-} =~ ^[0-9]+$ ]] || return 0
        \\    (( COMP_CWORD < ${#COMP_WORDS[@]} )) || return 0
        \\    local current=${COMP_WORDS[COMP_CWORD]}
        \\    local -a directories
        \\    if (( COMP_CWORD == 1 )); then
        \\        mapfile -t COMPREPLY < <(compgen -W 'apps notifications wallpaper' -- "$current")
        \\        return
        \\    fi
        \\    case ${COMP_WORDS[1]-} in
        \\        apps)
        \\            mapfile -t COMPREPLY < <(
        \\                command wayspot apps "${COMP_WORDS[@]:2:COMP_CWORD-2}" "$current" 2>/dev/null
        \\            )
        \\            ;;
        \\        notifications)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'history' -- "$current")
        \\            ;;
        \\        wallpaper)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'rotate' -- "$current")
        \\            mapfile -t directories < <(compgen -d -- "$current")
        \\            COMPREPLY+=("${directories[@]}")
        \\            compopt -o filenames 2>/dev/null || true
        \\            ;;
        \\    esac
        \\}
        \\complete -F _wayspot_completion wayspot
        \\
    ;
    var output = Transcript{ .expected = expected };
    try writeBash(&output);
    try std.testing.expect(output.done());
    try std.testing.expect(std.mem.indexOf(u8, expected, "complete bash") == null);
    try std.testing.expect(std.mem.indexOf(u8, expected, "eval") == null);
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
        .issues = .empty,
    };
}
