//! Turns one desktop application into bounded argv and replaces the picker process.

const std = @import("std");
const builtin = @import("builtin");
const apps = @import("apps.zig");

pub const argument_capacity = 64;
pub const storage_capacity = 8192;

/// Plan owns every argv byte; moving it after init invalidates its argv slices.
pub const Plan = struct {
    storage: [storage_capacity]u8 = undefined,
    used: usize = 0,
    argv: [argument_capacity][]const u8 = undefined,
    count: usize = 0,
    cwd: ?[]const u8 = null,

    pub fn init(
        plan: *Plan,
        app: *const apps.App,
        terminal: ?[]const u8,
        home: []const u8,
    ) !void {
        plan.* = .{};
        errdefer plan.* = .{};
        if (!std.fs.path.isAbsolute(home)) return error.HomeInvalid;
        if (home.len > apps.path_capacity) return error.HomeTooLong;
        if (app.terminal) {
            const name = terminal orelse return error.TerminalUnavailable;
            if (!std.mem.eql(u8, name, "kitty")) return error.TerminalUnsupported;
            try plan.add(name);
            try plan.add("--");
        }
        const app_start = plan.count;
        try plan.parseExec(app);
        if (plan.count == app_start) return error.ExecutableMissing;
        if (plan.argv[app_start].len == 0) return error.ExecutableMissing;
        if (std.mem.indexOfScalar(u8, plan.argv[app_start], '=') != null) {
            return error.ExecutableInvalid;
        }
        plan.cwd = app.path orelse home;
    }

    pub fn arguments(plan: *const Plan) []const []const u8 {
        return plan.argv[0..plan.count];
    }

    fn parseExec(plan: *Plan, app: *const apps.App) !void {
        var index: usize = 0;
        var file_code_seen = false;
        while (index < app.exec.len) {
            while (index < app.exec.len and app.exec[index] == ' ') index += 1;
            if (index == app.exec.len) break;
            if (app.exec[index] == '\t') return error.UnquotedReservedCharacter;

            const start = plan.used;
            const quoted = app.exec[index] == '"';
            if (quoted) index += 1;
            var closed = !quoted;
            while (index < app.exec.len) {
                const current = app.exec[index];
                if (quoted and current == '"') {
                    index += 1;
                    closed = true;
                    break;
                }
                if (!quoted and current == ' ') break;
                if (quoted) {
                    if (std.ascii.isControl(current)) return error.ControlCharacter;
                    if (current == '%') return error.QuotedFieldCode;
                    if (current == '\\') {
                        index += 1;
                        if (index == app.exec.len) return error.InvalidQuoteEscape;
                        const escaped = app.exec[index];
                        if (escaped != '"' and escaped != '`' and escaped != '$' and escaped != '\\') {
                            return error.InvalidQuoteEscape;
                        }
                        try plan.byte(escaped);
                    } else {
                        try plan.byte(current);
                    }
                    index += 1;
                    continue;
                }
                if (reserved(current)) return error.UnquotedReservedCharacter;
                if (current != '%') {
                    try plan.byte(current);
                    index += 1;
                    continue;
                }
                index += 1;
                if (index == app.exec.len) return error.InvalidFieldCode;
                const code = app.exec[index];
                index += 1;
                switch (code) {
                    '%' => try plan.byte('%'),
                    'c' => try plan.bytes(app.name),
                    'f', 'u' => {
                        if (file_code_seen) return error.RepeatedFileCode;
                        file_code_seen = true;
                    },
                    'F', 'U' => {
                        if (file_code_seen) return error.RepeatedFileCode;
                        if (plan.used != start or (index < app.exec.len and app.exec[index] != ' ')) {
                            return error.FieldCodeNotWholeArgument;
                        }
                        file_code_seen = true;
                    },
                    'd', 'D', 'n', 'N', 'v', 'm' => {},
                    'i', 'k' => return error.UnsupportedFieldCode,
                    else => return error.InvalidFieldCode,
                }
            }
            if (!closed) return error.UnclosedQuote;
            if (quoted and index < app.exec.len and app.exec[index] != ' ') {
                return error.QuotedArgumentNotWhole;
            }
            if (plan.used > start or quoted) try plan.finish(start);
        }
    }

    fn add(plan: *Plan, value: []const u8) !void {
        const start = plan.used;
        try plan.bytes(value);
        try plan.finish(start);
    }

    fn byte(plan: *Plan, value: u8) !void {
        if (plan.used == storage_capacity) return error.ArgumentBytesTooLong;
        plan.storage[plan.used] = value;
        plan.used += 1;
    }

    fn bytes(plan: *Plan, value: []const u8) !void {
        if (value.len > storage_capacity - plan.used) return error.ArgumentBytesTooLong;
        @memcpy(plan.storage[plan.used..][0..value.len], value);
        plan.used += value.len;
    }

    fn finish(plan: *Plan, start: usize) !void {
        if (plan.count == argument_capacity) return error.TooManyArguments;
        plan.argv[plan.count] = plan.storage[start..plan.used];
        plan.count += 1;
    }
};

fn reserved(byte: u8) bool {
    if (std.ascii.isControl(byte)) return true;
    return switch (byte) {
        '"',
        '\'',
        '\\',
        '>',
        '<',
        '~',
        '|',
        '&',
        ';',
        '$',
        '*',
        '?',
        '#',
        '(',
        ')',
        '`',
        => true,
        else => false,
    };
}

pub const Native = struct {
    io: std.Io,

    pub fn replace(native: *Native, argv: []const []const u8, cwd: ?[]const u8) !void {
        if (cwd) |path| try std.process.setCurrentPath(native.io, path);
        return std.process.replace(native.io, .{ .argv = argv });
    }
};

/// Resolves one complete plan before presenting it to the process boundary.
pub fn run(
    operations: anytype,
    app: *const apps.App,
    terminal: ?[]const u8,
    home: []const u8,
) !void {
    var plan: Plan = .{};
    try plan.init(app, terminal, home);
    try operations.replace(plan.arguments(), plan.cwd);
}

/// Removes every app whose complete launch plan is invalid.
pub fn apply(list: *apps.List, terminal: ?[]const u8, home: []const u8) !void {
    if (!std.fs.path.isAbsolute(home)) return error.HomeInvalid;
    if (home.len > apps.path_capacity) return error.HomeTooLong;
    var invalid: [apps.app_capacity]bool = @splat(false);
    for (list.slice(), 0..) |*app, index| {
        var plan: Plan = .{};
        plan.init(app, terminal, home) catch {
            invalid[index] = true;
        };
    }
    var index = list.count;
    while (index > 0) {
        index -= 1;
        if (invalid[index]) list.rejectExec(index);
    }
}

const Transcript = struct {
    argv: []const []const u8,
    cwd: ?[]const u8,
    called: bool = false,

    fn replace(transcript: *Transcript, argv: []const []const u8, cwd: ?[]const u8) !void {
        if (transcript.called or argv.len != transcript.argv.len) return error.TranscriptMismatch;
        for (argv, transcript.argv) |actual, expected| {
            if (!std.mem.eql(u8, actual, expected)) return error.TranscriptMismatch;
        }
        if (!optionalEqual(cwd, transcript.cwd)) return error.TranscriptMismatch;
        transcript.called = true;
        return error.ReplaceStopped;
    }
};

fn optionalEqual(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null or right == null) return left == null and right == null;
    return std.mem.eql(u8, left.?, right.?);
}

test "plain and terminal plans preserve exact argv and working directory" {
    const plain = testApp("Editor", "\"editor path\" --name=%c %U %%", "/work", false);
    var plain_transcript = Transcript{
        .argv = &.{ "editor path", "--name=Editor", "%" },
        .cwd = "/work",
    };
    try std.testing.expectError(error.ReplaceStopped, run(&plain_transcript, &plain, null, "/home/user"));
    try std.testing.expect(plain_transcript.called);

    const terminal = testApp("Monitor", "btop", null, true);
    var terminal_transcript = Transcript{
        .argv = &.{ "kitty", "--", "btop" },
        .cwd = "/home/user",
    };
    try std.testing.expectError(error.ReplaceStopped, run(&terminal_transcript, &terminal, "kitty", "/home/user"));
    try std.testing.expect(terminal_transcript.called);
}

test "malformed input publishes no process operation" {
    const cases = .{
        .{ "\"open", error.UnclosedQuote },
        .{ "open\"bad", error.UnquotedReservedCharacter },
        .{ "\"open\"tail", error.QuotedArgumentNotWhole },
        .{ "\"open%f\"", error.QuotedFieldCode },
        .{ "\"open\\q\"", error.InvalidQuoteEscape },
        .{ "open %f %U", error.RepeatedFileCode },
        .{ "open before%F", error.FieldCodeNotWholeArgument },
        .{ "open %Uafter", error.FieldCodeNotWholeArgument },
        .{ "open %i", error.UnsupportedFieldCode },
        .{ "open %z", error.InvalidFieldCode },
        .{ "open \"bad\tvalue\"", error.ControlCharacter },
        .{ "NAME=value", error.ExecutableInvalid },
        .{ "\"\"", error.ExecutableMissing },
    };
    inline for (cases) |case| {
        const app = testApp("App", case[0], null, false);
        var transcript = Transcript{ .argv = &.{"never"}, .cwd = null };
        try std.testing.expectError(case[1], run(&transcript, &app, null, "/home/user"));
        try std.testing.expect(!transcript.called);
    }
}

test "invalid launch rows are removed before picker publication" {
    const source = [_]apps.DesktopFile{
        .{ .root = 0, .id = @constCast("good.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Good\nExec=good",
        ) },
        .{ .root = 0, .id = @constCast("bad.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Bad\nExec=bad %z",
        ) },
    };
    var list = try apps.load(std.testing.allocator, &source, "Hyprland");
    defer list.deinit();
    try apply(&list, null, "/home/user");
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqualStrings("Good", list.slice()[0].name);
    try std.testing.expectEqual(@as(usize, 1), list.report.decisions[@intFromEnum(apps.Decision.invalid_exec)]);
}

test "argument and byte bounds are exact and failure atomic" {
    const many = ("a " ** argument_capacity) ++ "a";
    var plan: Plan = .{};
    const app_many = testApp("App", many, null, false);
    try std.testing.expectError(error.TooManyArguments, plan.init(&app_many, null, "/home/user"));
    try std.testing.expectEqual(@as(usize, 0), plan.count);
    try std.testing.expectEqual(@as(usize, 0), plan.used);

    const exact = "x" ** storage_capacity;
    const app_exact = testApp("App", exact, null, false);
    try plan.init(&app_exact, null, "/home/user");
    try std.testing.expectEqual(storage_capacity, plan.used);
    const app_over = testApp("App", exact ++ "x", null, false);
    try std.testing.expectError(error.ArgumentBytesTooLong, plan.init(&app_over, null, "/home/user"));
    try std.testing.expectEqual(@as(usize, 0), plan.used);
}

test "terminal policy is explicit and native replacement failure is visible" {
    const terminal = testApp("Monitor", "btop", null, true);
    var transcript = Transcript{ .argv = &.{"never"}, .cwd = null };
    try std.testing.expectError(error.TerminalUnavailable, run(&transcript, &terminal, null, "/home/user"));
    try std.testing.expectError(error.TerminalUnsupported, run(&transcript, &terminal, "foot", "/home/user"));
    try std.testing.expectError(error.HomeInvalid, run(&transcript, &terminal, "kitty", "relative"));

    const plain = testApp("App", "app", null, false);
    var native = Native{ .io = std.Io.failing };
    try std.testing.expectError(error.FileNotFound, run(&native, &plain, null, "/home/user"));
}

test "arbitrary Exec bytes remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzExec, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzExec({}, &empty);
}

fn fuzzExec(_: void, smith: *std.testing.Smith) !void {
    var input: [apps.exec_capacity]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    const app = testApp("App", bytes, null, false);
    var plan: Plan = .{};
    plan.init(&app, null, "/home/user") catch return;
    try std.testing.expect(plan.count > 0);
    try std.testing.expect(plan.count <= argument_capacity);
    try std.testing.expect(plan.used <= storage_capacity);
}

fn testApp(name: []const u8, exec: []const u8, path: ?[]const u8, terminal: bool) apps.App {
    return .{
        .storage = @constCast(""),
        .id = "test.desktop",
        .name = name,
        .generic_name = null,
        .keywords = null,
        .icon = null,
        .exec = exec,
        .try_exec = null,
        .only_show_in = null,
        .not_show_in = null,
        .path = path,
        .terminal = terminal,
        .issues = .initEmpty(),
    };
}
