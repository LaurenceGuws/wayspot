//! Owns bounded CLI presentation.

const std = @import("std");
const apps = @import("apps/catalog.zig");
const cmd = @import("cmd.zig");

/// Public usage text printed when exact application resolution fails.
pub const help =
    \\usage:
    \\  wayspot
    \\  wayspot resident CONFIG
    \\  wayspot resident status
    \\  wayspot picker [dismiss]
    \\  wayspot tray
    \\  wayspot notifications [history]
    \\  wayspot wallpaper ROOT
    \\  wayspot wallpaper rotate
    \\  wayspot apps [terms...]
    \\  wayspot <exact application name or desktop id>
    \\  source <(wayspot completion bash)
    \\
;

/// Writes matched application names in rank order, one per line, to the borrowed writer.
/// Applications and query must satisfy the catalog bounds; the caller owns flushing.
pub fn writeApps(
    output: *std.Io.Writer,
    applications: []const apps.App,
    query: []const u8,
) std.Io.Writer.Error!void {
    const found = apps.Matches.init(applications, query);
    for (found.slice()) |index| {
        const name = applications[index].name;
        std.debug.assert(name.len <= apps.name_capacity);
        try output.writeAll(name);
        try output.writeAll("\n");
    }
}

/// Writes the Bash completion definition without shell evaluation or flushing.
pub fn writeBash(output: *std.Io.Writer) std.Io.Writer.Error!void {
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
        \\        resident)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'status' -- "$current")
        \\            ;;
        \\        picker)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'dismiss' -- "$current")
        \\            ;;
        \\    esac
        \\}
        \\complete -F _wayspot_completion wayspot
        \\
    );
}

fn writeWords(output: *std.Io.Writer, words: []const []const u8) std.Io.Writer.Error!void {
    for (words, 0..) |word, index| {
        if (index > 0) try output.writeAll(" ");
        try output.writeAll(word);
    }
}

test "apps output is bounded and byte exact" {
    const applications = [_]apps.App{
        testApp("alpha.desktop", "Alpha"),
        testApp("beta.desktop", "Beta"),
    };
    var buffer: [32]u8 = undefined;
    var output = std.Io.Writer.fixed(&buffer);
    try writeApps(&output, &applications, "");
    try std.testing.expectEqualStrings("Alpha\nBeta\n", output.buffered());

    output = .fixed(&buffer);
    try writeApps(&output, &applications, "bet");
    try std.testing.expectEqualStrings("Beta\n", output.buffered());

    output = .fixed(&buffer);
    try writeApps(&output, &applications, "unmatched");
    try std.testing.expectEqualStrings("", output.buffered());
}

test "typo output remains a suggestion" {
    const ghostty = testApp("ghostty.desktop", "Ghostty");
    var buffer: [16]u8 = undefined;
    var listed = std.Io.Writer.fixed(&buffer);
    try writeApps(&listed, &.{ghostty}, "ghsotty");
    try std.testing.expectEqualStrings("Ghostty\n", listed.buffered());
}

test "help and output failures are exact" {
    const app = testApp("alpha.desktop", "Alpha");
    var buffer: [5]u8 = undefined;
    var failed = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(error.WriteFailed, writeApps(&failed, &.{app}, ""));
    try std.testing.expectEqualStrings("Alpha", failed.buffered());

    var unavailable: std.Io.Writer = .failing;
    try std.testing.expectError(error.WriteFailed, writeBash(&unavailable));
    try std.testing.expect(std.mem.indexOf(u8, help, "wayspot notifications [history]") != null);
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
        \\        mapfile -t COMPREPLY < <(compgen -W 'apps notifications wallpaper tray resident picker' -- "$current")
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
        \\        resident)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'status' -- "$current")
        \\            ;;
        \\        picker)
        \\            (( COMP_CWORD == 2 )) || return 0
        \\            mapfile -t COMPREPLY < <(compgen -W 'dismiss' -- "$current")
        \\            ;;
        \\    esac
        \\}
        \\complete -F _wayspot_completion wayspot
        \\
    ;
    var buffer: [expected.len]u8 = undefined;
    var output = std.Io.Writer.fixed(&buffer);
    try writeBash(&output);
    try std.testing.expectEqualStrings(expected, output.buffered());
    try std.testing.expect(std.mem.indexOf(u8, expected, "complete bash") == null);
    try std.testing.expect(std.mem.indexOf(u8, expected, "eval") == null);
}

fn testApp(id: []const u8, name: []const u8) apps.App {
    return .{
        .storage = &.{},
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
