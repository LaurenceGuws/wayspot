//! Parses bounded desktop application records without filesystem ownership.

const std = @import("std");
const builtin = @import("builtin");

pub const desktop_file_capacity = 64 * 1024;
pub const type_capacity = 32;
pub const name_capacity = 256;
pub const generic_name_capacity = 256;
pub const keywords_capacity = 1024;
pub const icon_capacity = 256;
pub const exec_capacity = 4096;
pub const try_exec_capacity = 1024;
pub const path_capacity = 4096;
pub const desktop_list_capacity = 1024;

const Effect = enum {
    type,
    name,
    generic_name,
    keywords,
    icon,
    exec,
    try_exec,
    hidden,
    no_display,
    only_show_in,
    not_show_in,
    dbus_activatable,
    terminal,
    path,
    recognized_deferred,
};

const Rule = struct {
    key: []const u8,
    effect: Effect,
};

const rules = [_]Rule{
    .{ .key = "Type", .effect = .type },
    .{ .key = "Name", .effect = .name },
    .{ .key = "GenericName", .effect = .generic_name },
    .{ .key = "Keywords", .effect = .keywords },
    .{ .key = "Icon", .effect = .icon },
    .{ .key = "Exec", .effect = .exec },
    .{ .key = "TryExec", .effect = .try_exec },
    .{ .key = "Hidden", .effect = .hidden },
    .{ .key = "NoDisplay", .effect = .no_display },
    .{ .key = "OnlyShowIn", .effect = .only_show_in },
    .{ .key = "NotShowIn", .effect = .not_show_in },
    .{ .key = "DBusActivatable", .effect = .dbus_activatable },
    .{ .key = "Terminal", .effect = .terminal },
    .{ .key = "Path", .effect = .path },
    .{ .key = "Comment", .effect = .recognized_deferred },
    .{ .key = "Categories", .effect = .recognized_deferred },
    .{ .key = "Actions", .effect = .recognized_deferred },
    .{ .key = "MimeType", .effect = .recognized_deferred },
    .{ .key = "StartupNotify", .effect = .recognized_deferred },
    .{ .key = "StartupWMClass", .effect = .recognized_deferred },
    .{ .key = "Version", .effect = .recognized_deferred },
    .{ .key = "SingleMainWindow", .effect = .recognized_deferred },
    .{ .key = "URL", .effect = .recognized_deferred },
    .{ .key = "PrefersNonDefaultGPU", .effect = .recognized_deferred },
    .{ .key = "Implements", .effect = .recognized_deferred },
    .{ .key = "Encoding", .effect = .recognized_deferred },
};

comptime {
    @setEvalBranchQuota(5000);
    for (rules, 0..) |rule, index| {
        std.debug.assert(rule.key.len > 0);
        for (rules[index + 1 ..]) |other| std.debug.assert(!std.mem.eql(u8, rule.key, other.key));
    }
}

pub const Issue = enum {
    localized_field_deferred,
    unknown_standard_field,
    generic_name_invalid,
    keywords_invalid,
    icon_invalid,
    try_exec_invalid,
    path_invalid,
    recognized_field_deferred,
};

pub const Decision = enum {
    publish,
    missing_type,
    not_application,
    hidden,
    no_display,
    missing_name,
    missing_exec,
    other_desktop,
    unavailable_try_exec,
    dbus_launch_unsupported,
    unavailable_terminal,
    invalid_exec,
};

pub const DesktopFile = struct {
    root: u8,
    id: []u8,
    bytes: []u8,
};

/// Entry borrows every retained value from the parsed desktop-file bytes.
pub const Entry = struct {
    type: ?[]const u8 = null,
    name: ?[]const u8 = null,
    generic_name: ?[]const u8 = null,
    keywords: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    exec: ?[]const u8 = null,
    try_exec: ?[]const u8 = null,
    only_show_in: ?[]const u8 = null,
    not_show_in: ?[]const u8 = null,
    path: ?[]const u8 = null,
    hidden: bool = false,
    no_display: bool = false,
    dbus_activatable: bool = false,
    terminal: bool = false,
    issues: std.EnumSet(Issue) = .initEmpty(),

    pub fn decide(entry: *const Entry, current_desktop: ?[]const u8) Decision {
        const entry_type = entry.type orelse return .missing_type;
        if (!std.mem.eql(u8, entry_type, "Application")) return .not_application;
        if (entry.hidden) return .hidden;
        if (entry.no_display) return .no_display;
        if (entry.name == null) return .missing_name;
        if (entry.exec == null) return .missing_exec;
        if (!entry.visibleOn(current_desktop)) return .other_desktop;
        if (entry.dbus_activatable) return .dbus_launch_unsupported;
        return .publish;
    }

    fn visibleOn(entry: *const Entry, current_desktop: ?[]const u8) bool {
        if (entry.only_show_in) |allowed| {
            if (!desktopListMatches(allowed, current_desktop)) return false;
        }
        if (entry.not_show_in) |denied| {
            if (desktopListMatches(denied, current_desktop)) return false;
        }
        return true;
    }
};

pub const App = struct {
    storage: []u8,
    id: []const u8,
    name: []const u8,
    generic_name: ?[]const u8,
    keywords: ?[]const u8,
    icon: ?[]const u8,
    exec: []const u8,
    try_exec: ?[]const u8,
    only_show_in: ?[]const u8,
    not_show_in: ?[]const u8,
    path: ?[]const u8,
    terminal: bool,
    issues: std.EnumSet(Issue),
};

pub const app_capacity = 512;

pub const LoadReport = struct {
    malformed: usize = 0,
    duplicates: usize = 0,
    decisions: [std.meta.fields(Decision).len]usize = @splat(0),
    issues: [std.meta.fields(Issue).len]usize = @splat(0),
};

/// List owns one allocation per published app and no rejected file bytes.
pub const List = struct {
    allocator: std.mem.Allocator,
    items: [app_capacity]App = undefined,
    count: usize = 0,
    report: LoadReport = .{},

    pub fn deinit(list: *List) void {
        for (list.items[0..list.count]) |app| list.allocator.free(app.storage);
        list.* = undefined;
    }

    pub fn slice(list: *const List) []const App {
        return list.items[0..list.count];
    }

    /// Removes one app whose TryExec was proven unavailable by the filesystem owner.
    pub fn rejectTryExec(list: *List, index: usize) void {
        std.debug.assert(index < list.count);
        std.debug.assert(list.items[index].try_exec != null);
        list.reject(index, .unavailable_try_exec);
    }

    /// Removes one terminal app when no supported terminal executable exists.
    pub fn rejectTerminal(list: *List, index: usize) void {
        std.debug.assert(index < list.count);
        std.debug.assert(list.items[index].terminal);
        list.reject(index, .unavailable_terminal);
    }

    /// Removes one app whose Exec cannot produce a complete bounded argv.
    pub fn rejectExec(list: *List, index: usize) void {
        std.debug.assert(index < list.count);
        list.reject(index, .invalid_exec);
    }

    fn reject(list: *List, index: usize, decision: Decision) void {
        std.debug.assert(decision != .publish);
        list.allocator.free(list.items[index].storage);
        list.count -= 1;
        std.mem.copyForwards(App, list.items[index..list.count], list.items[index + 1 ..][0 .. list.count - index]);
        list.report.decisions[@intFromEnum(Decision.publish)] -= 1;
        list.report.decisions[@intFromEnum(decision)] += 1;
    }
};

/// Loads a deterministic, duplicate-free app list or returns no partial list.
pub fn load(
    allocator: std.mem.Allocator,
    files: []const DesktopFile,
    current_desktop: ?[]const u8,
) !List {
    if (files.len > app_capacity) return error.TooManyDesktopFiles;
    var list = List{ .allocator = allocator };
    errdefer list.deinit();

    for (files, 0..) |file, index| {
        if (seenDesktopId(files[0..index], file.id)) {
            list.report.duplicates += 1;
            continue;
        }
        const entry = parse(file.bytes) catch {
            list.report.malformed += 1;
            continue;
        };
        const decision = entry.decide(current_desktop);
        list.report.decisions[@intFromEnum(decision)] += 1;
        for (std.enums.values(Issue)) |issue| {
            if (entry.issues.contains(issue)) list.report.issues[@intFromEnum(issue)] += 1;
        }
        if (decision != .publish) continue;
        std.debug.assert(list.count < app_capacity);
        list.items[list.count] = try copyApp(allocator, file.id, entry);
        list.count += 1;
    }
    std.mem.sortUnstable(App, list.items[0..list.count], {}, appLessThan);
    return list;
}

fn appLessThan(_: void, left: App, right: App) bool {
    const order = std.ascii.orderIgnoreCase(left.name, right.name);
    if (order != .eq) return order == .lt;
    return std.mem.lessThan(u8, left.id, right.id);
}

fn seenDesktopId(files: []const DesktopFile, id: []const u8) bool {
    for (files) |file| {
        if (std.mem.eql(u8, file.id, id)) return true;
    }
    return false;
}

fn copyApp(allocator: std.mem.Allocator, id: []const u8, entry: Entry) !App {
    const required_values = .{ id, entry.name.?, entry.exec.? };
    const optional_values = .{
        entry.generic_name,
        entry.keywords,
        entry.icon,
        entry.try_exec,
        entry.only_show_in,
        entry.not_show_in,
        entry.path,
    };
    var size: usize = 0;
    inline for (required_values) |value| size = try std.math.add(usize, size, value.len);
    inline for (optional_values) |value| {
        if (value) |present| size = try std.math.add(usize, size, present.len);
    }

    const storage = try allocator.alloc(u8, size);
    errdefer allocator.free(storage);
    var cursor: usize = 0;
    const app: App = .{
        .storage = storage,
        .id = copy(storage, &cursor, id),
        .name = decode(storage, &cursor, entry.name.?, false),
        .generic_name = decodeOptional(storage, &cursor, entry.generic_name, false),
        .keywords = decodeOptional(storage, &cursor, entry.keywords, true),
        .icon = decodeOptional(storage, &cursor, entry.icon, false),
        .exec = decode(storage, &cursor, entry.exec.?, false),
        .try_exec = decodeOptional(storage, &cursor, entry.try_exec, false),
        .only_show_in = decodeOptional(storage, &cursor, entry.only_show_in, true),
        .not_show_in = decodeOptional(storage, &cursor, entry.not_show_in, true),
        .path = decodeOptional(storage, &cursor, entry.path, false),
        .terminal = entry.terminal,
        .issues = entry.issues,
    };
    std.debug.assert(cursor <= storage.len);
    return app;
}

fn copy(storage: []u8, cursor: *usize, value: []const u8) []const u8 {
    const destination = storage[cursor.*..][0..value.len];
    @memcpy(destination, value);
    cursor.* += value.len;
    return destination;
}

fn decode(storage: []u8, cursor: *usize, value: []const u8, list: bool) []const u8 {
    const start = cursor.*;
    var input: usize = 0;
    while (input < value.len) : (input += 1) {
        if (value[input] != '\\') {
            storage[cursor.*] = value[input];
        } else {
            input += 1;
            storage[cursor.*] = switch (value[input]) {
                's' => ' ',
                'n' => '\n',
                't' => '\t',
                'r' => '\r',
                '\\' => '\\',
                ';' => if (list) ';' else unreachable,
                else => unreachable,
            };
        }
        cursor.* += 1;
    }
    return storage[start..cursor.*];
}

fn decodeOptional(
    storage: []u8,
    cursor: *usize,
    value: ?[]const u8,
    list: bool,
) ?[]const u8 {
    return if (value) |present| decode(storage, cursor, present, list) else null;
}

fn desktopListMatches(list: []const u8, current_desktop: ?[]const u8) bool {
    const current = current_desktop orelse return false;
    var desktops = std.mem.splitScalar(u8, current, ':');
    while (desktops.next()) |desktop| {
        var start: usize = 0;
        var index: usize = 0;
        while (index <= list.len) : (index += 1) {
            if (index < list.len and list[index] == '\\') {
                index += 1;
                continue;
            }
            if (index < list.len and list[index] != ';') continue;
            if (decodedEquals(list[start..index], desktop)) return true;
            start = index + 1;
        }
    }
    return false;
}

fn decodedEquals(encoded: []const u8, expected: []const u8) bool {
    var decoded: [desktop_list_capacity]u8 = undefined;
    var cursor: usize = 0;
    const value = decode(&decoded, &cursor, encoded, true);
    return std.mem.eql(u8, value, expected);
}

/// Parses the Desktop Entry group and rejects malformed structural or control data.
pub fn parse(bytes: []const u8) !Entry {
    if (bytes.len > desktop_file_capacity) return error.DesktopFileTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;

    var entry: Entry = .{};
    var seen: [rules.len]bool = @splat(false);
    var found_group = false;
    var in_group = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, std.mem.trimEnd(u8, raw_line, "\r"), " \t");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[') {
            if (line[line.len - 1] != ']') return error.InvalidGroup;
            const desktop_group = std.mem.eql(u8, line, "[Desktop Entry]");
            if (desktop_group and found_group) return error.DuplicateDesktopGroup;
            if (desktop_group) found_group = true;
            in_group = desktop_group;
            continue;
        }
        if (!in_group) continue;

        const equals = std.mem.indexOfScalar(u8, line, '=') orelse return error.InvalidEntry;
        const key = std.mem.trim(u8, line[0..equals], " \t");
        const value = std.mem.trim(u8, line[equals + 1 ..], " \t");
        try validateKey(key);
        switch (classify(key)) {
            .localized_deferred => {
                entry.issues.insert(.localized_field_deferred);
                continue;
            },
            .extension => continue,
            .unknown => {
                entry.issues.insert(.unknown_standard_field);
                continue;
            },
            .known => |known| {
                if (seen[known.index]) return error.DuplicateField;
                seen[known.index] = true;
                try apply(&entry, known.effect, value);
            },
        }
    }
    if (!found_group) return error.MissingDesktopGroup;
    return entry;
}

const Classification = union(enum) {
    known: struct {
        effect: Effect,
        index: usize,
    },
    localized_deferred,
    extension,
    unknown,
};

fn classify(key: []const u8) Classification {
    for (rules, 0..) |rule, index| {
        if (std.mem.eql(u8, key, rule.key)) {
            return .{ .known = .{ .effect = rule.effect, .index = index } };
        }
    }
    inline for (.{ "Name[", "GenericName[", "Keywords[", "Comment[" }) |prefix| {
        if (std.mem.startsWith(u8, key, prefix) and std.mem.endsWith(u8, key, "]")) {
            return .localized_deferred;
        }
    }
    if (std.mem.startsWith(u8, key, "X-")) return .extension;
    return .unknown;
}

fn validateKey(key: []const u8) !void {
    if (key.len == 0) return error.InvalidKey;
    const base = if (std.mem.indexOfScalar(u8, key, '[')) |bracket| key[0..bracket] else key;
    if (base.len == 0) return error.InvalidKey;
    for (base) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '-') return error.InvalidKey;
    }
    if (base.len != key.len) {
        if (key[key.len - 1] != ']' or base.len + 2 >= key.len) return error.InvalidKey;
        for (key[base.len + 1 .. key.len - 1]) |byte| {
            if (byte == '[' or byte == ']') return error.InvalidKey;
        }
    }
}

fn apply(entry: *Entry, effect: Effect, value: []const u8) !void {
    switch (effect) {
        .type => entry.type = try requiredOrNull(value, type_capacity),
        .name => entry.name = try requiredOrNull(value, name_capacity),
        .generic_name => optional(
            entry,
            value,
            generic_name_capacity,
            false,
            .generic_name_invalid,
            &entry.generic_name,
        ),
        .keywords => optional(entry, value, keywords_capacity, true, .keywords_invalid, &entry.keywords),
        .icon => optional(entry, value, icon_capacity, false, .icon_invalid, &entry.icon),
        .exec => entry.exec = try requiredOrNull(value, exec_capacity),
        .try_exec => optional(entry, value, try_exec_capacity, false, .try_exec_invalid, &entry.try_exec),
        .hidden => entry.hidden = try boolean(value),
        .no_display => entry.no_display = try boolean(value),
        .only_show_in => entry.only_show_in = try required(value, desktop_list_capacity, true),
        .not_show_in => entry.not_show_in = try required(value, desktop_list_capacity, true),
        .dbus_activatable => entry.dbus_activatable = try boolean(value),
        .terminal => entry.terminal = try boolean(value),
        .path => optional(entry, value, path_capacity, false, .path_invalid, &entry.path),
        .recognized_deferred => entry.issues.insert(.recognized_field_deferred),
    }
}

fn requiredOrNull(value: []const u8, capacity: usize) !?[]const u8 {
    if (value.len == 0) return null;
    if (value.len > capacity) return error.RequiredFieldTooLong;
    try validateEscapes(value, false);
    return value;
}

fn required(value: []const u8, capacity: usize, list: bool) ![]const u8 {
    if (value.len == 0) return error.RequiredFieldEmpty;
    if (value.len > capacity) return error.RequiredFieldTooLong;
    try validateEscapes(value, list);
    return value;
}

fn optional(
    entry: *Entry,
    value: []const u8,
    capacity: usize,
    list: bool,
    issue: Issue,
    target: *?[]const u8,
) void {
    if (value.len == 0 or value.len > capacity) {
        entry.issues.insert(issue);
        return;
    }
    validateEscapes(value, list) catch {
        entry.issues.insert(issue);
        return;
    };
    target.* = value;
}

fn validateEscapes(value: []const u8, list: bool) !void {
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        if (value[index] != '\\') continue;
        index += 1;
        if (index == value.len) return error.InvalidEscape;
        switch (value[index]) {
            's', 'n', 't', 'r', '\\' => {},
            ';' => if (!list) return error.InvalidEscape,
            else => return error.InvalidEscape,
        }
    }
}

fn boolean(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidBoolean;
}

test "complete application retains useful optional data" {
    const entry = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Kitty
        \\GenericName=Terminal
        \\Keywords=shell;console;
        \\Icon=kitty
        \\Exec=kitty
        \\TryExec=kitty
        \\Terminal=false
        \\Path=/tmp
    );
    try std.testing.expectEqual(Decision.publish, entry.decide("Hyprland"));
    try std.testing.expectEqualStrings("kitty", entry.icon.?);
    try std.testing.expectEqualStrings("Terminal", entry.generic_name.?);
    try std.testing.expectEqualStrings("shell;console;", entry.keywords.?);
}

test "missing icon retains a publishable application" {
    const entry = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Kitty
        \\Exec=kitty
    );
    try std.testing.expectEqual(Decision.publish, entry.decide("Hyprland"));
    try std.testing.expectEqual(null, entry.icon);
    try std.testing.expect(!entry.issues.contains(.icon_invalid));
}

test "invalid optional icon is explicit without discarding the app" {
    const entry = try parse(
        "[Desktop Entry]\nType=Application\nName=Kitty\nExec=kitty\nIcon=" ++
            ("x" ** (icon_capacity + 1)),
    );
    try std.testing.expectEqual(Decision.publish, entry.decide("Hyprland"));
    try std.testing.expectEqual(null, entry.icon);
    try std.testing.expect(entry.issues.contains(.icon_invalid));
}

test "hidden entry remains a desktop id tombstone without launch fields" {
    const entry = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Hidden=true
    );
    try std.testing.expect(entry.hidden);
    try std.testing.expectEqual(Decision.hidden, entry.decide("Hyprland"));
}

test "visibility and unsupported launch forms are explicit" {
    const no_display = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Hidden UI
        \\Exec=hidden-ui
        \\NoDisplay=true
    );
    try std.testing.expectEqual(Decision.no_display, no_display.decide("Hyprland"));

    const terminal = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Terminal App
        \\Exec=terminal-app
        \\Terminal=true
    );
    try std.testing.expectEqual(Decision.publish, terminal.decide("Hyprland"));
}

test "localized and recognized deferred fields cannot disappear silently" {
    const entry = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Files
        \\Name[fr]=Fichiers
        \\Comment=Browse files
        \\Categories=Utility;
        \\Exec=files
    );
    try std.testing.expect(entry.issues.contains(.localized_field_deferred));
    try std.testing.expect(entry.issues.contains(.recognized_field_deferred));
    try std.testing.expectError(error.InvalidKey, parse(
        "[Desktop Entry]\nType=Application\nName=Files\nName[]=Bad\nExec=files",
    ));
}

test "every non-publish decision has one explicit reason" {
    const cases = .{
        .{ "[Desktop Entry]\nName=Missing Type\nExec=app", Decision.missing_type },
        .{ "[Desktop Entry]\nType=\nName=Empty Type\nExec=app", Decision.missing_type },
        .{ "[Desktop Entry]\nType=Link\nName=Link", Decision.not_application },
        .{ "[Desktop Entry]\nType=Application\nHidden=true", Decision.hidden },
        .{ "[Desktop Entry]\nType=Application\nNoDisplay=true", Decision.no_display },
        .{ "[Desktop Entry]\nType=Application\nExec=app", Decision.missing_name },
        .{ "[Desktop Entry]\nType=Application\nName=\nExec=app", Decision.missing_name },
        .{ "[Desktop Entry]\nType=Application\nName=No Exec", Decision.missing_exec },
        .{ "[Desktop Entry]\nType=Application\nName=Empty Exec\nExec=", Decision.missing_exec },
        .{
            "[Desktop Entry]\nType=Application\nName=DBus\nExec=app\nDBusActivatable=true",
            Decision.dbus_launch_unsupported,
        },
    };
    inline for (cases) |case| {
        const entry = try parse(case[0]);
        try std.testing.expectEqual(case[1], entry.decide("Hyprland"));
    }
}

test "desktop visibility uses semicolon rules against colon-separated current desktops" {
    const only = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Only
        \\Exec=only
        \\OnlyShowIn=Hyprland;GNOME;
    );
    try std.testing.expectEqual(Decision.publish, only.decide("Hyprland:wlroots"));
    try std.testing.expectEqual(Decision.other_desktop, only.decide("KDE"));
    try std.testing.expectEqual(Decision.other_desktop, only.decide(null));

    const denied = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Denied
        \\Exec=denied
        \\NotShowIn=GNOME;KDE;
    );
    try std.testing.expectEqual(Decision.publish, denied.decide("Hyprland"));
    try std.testing.expectEqual(Decision.other_desktop, denied.decide("Hyprland:KDE"));

    const escaped = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Escaped
        \\Exec=escaped
        \\OnlyShowIn=Desk\;top;Hyprland;
    );
    try std.testing.expectEqual(Decision.publish, escaped.decide("Hyprland"));
    try std.testing.expectEqual(Decision.publish, escaped.decide("Desk;top"));
}

test "unknown standard fields are marked while extension fields remain extensions" {
    const entry = try parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Name=App
        \\Exec=app
        \\FutureStandardKey=value
        \\X-Vendor-Key=value
    );
    try std.testing.expect(entry.issues.contains(.unknown_standard_field));
}

test "parser rejects duplicate control fields and malformed booleans" {
    try std.testing.expectError(error.DuplicateField, parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Type=Application
    ));
    try std.testing.expectError(error.InvalidBoolean, parse(
        \\[Desktop Entry]
        \\Type=Application
        \\Hidden=1
    ));
}

test "parser ignores other groups and requires exactly one Desktop Entry group" {
    const entry = try parse(
        \\[Other]
        \\Name=Wrong
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Right
        \\Exec=right
        \\[Action New]
        \\Name=Also Wrong
    );
    try std.testing.expectEqualStrings("Right", entry.name.?);
    try std.testing.expectError(error.MissingDesktopGroup, parse("[Other]\nName=None"));
    try std.testing.expectError(
        error.DuplicateDesktopGroup,
        parse("[Desktop Entry]\nType=Application\n[Desktop Entry]\nType=Application"),
    );
}

test "required and optional fields prove exact bounds" {
    const exact_name = "n" ** name_capacity;
    const exact_icon = "i" ** icon_capacity;
    const entry = try parse(
        "[Desktop Entry]\nType=Application\nName=" ++ exact_name ++
            "\nExec=app\nIcon=" ++ exact_icon,
    );
    try std.testing.expectEqual(name_capacity, entry.name.?.len);
    try std.testing.expectEqual(icon_capacity, entry.icon.?.len);

    try std.testing.expectError(
        error.RequiredFieldTooLong,
        parse("[Desktop Entry]\nType=Application\nName=" ++ exact_name ++ "n\nExec=app"),
    );
}

test "published strings decode only their specified escapes" {
    const files = [_]DesktopFile{.{
        .root = 0,
        .id = @constCast("escaped.desktop"),
        .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Two\\sWords\n" ++
                "Keywords=first\\;part;second;\nIcon=some\\\\icon\nExec=app\\s--flag",
        ),
    }};
    var list = try load(std.testing.allocator, &files, "Hyprland");
    defer list.deinit();
    try std.testing.expectEqualStrings("Two Words", list.slice()[0].name);
    try std.testing.expectEqualStrings("first;part;second;", list.slice()[0].keywords.?);
    try std.testing.expectEqualStrings("some\\icon", list.slice()[0].icon.?);
    try std.testing.expectEqualStrings("app --flag", list.slice()[0].exec);

    try std.testing.expectError(error.InvalidEscape, parse(
        "[Desktop Entry]\nType=Application\nName=Bad\\qName\nExec=bad",
    ));
    const optional_invalid = try parse(
        "[Desktop Entry]\nType=Application\nName=Good\nIcon=bad\\;icon\nExec=good",
    );
    try std.testing.expectEqual(null, optional_invalid.icon);
    try std.testing.expect(optional_invalid.issues.contains(.icon_invalid));
}

test "arbitrary desktop bytes remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzDesktopEntry, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzDesktopEntry({}, &empty);
}

test "load preserves precedence and counts every non-published reason" {
    const files = [_]DesktopFile{
        .{ .root = 0, .id = @constCast("same.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nHidden=true",
        ) },
        .{ .root = 1, .id = @constCast("same.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Wrong\nExec=wrong",
        ) },
        .{ .root = 1, .id = @constCast("good.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Good\nExec=good\nIcon=good",
        ) },
        .{ .root = 1, .id = @constCast("broken.desktop"), .bytes = @constCast("broken") },
    };
    var list = try load(std.testing.allocator, &files, "Hyprland");
    defer list.deinit();
    try std.testing.expectEqual(@as(usize, 1), list.count);
    try std.testing.expectEqualStrings("Good", list.slice()[0].name);
    try std.testing.expectEqualStrings("good", list.slice()[0].icon.?);
    try std.testing.expectEqual(@as(usize, 1), list.report.duplicates);
    try std.testing.expectEqual(@as(usize, 1), list.report.malformed);
    try std.testing.expectEqual(@as(usize, 1), list.report.decisions[@intFromEnum(Decision.hidden)]);
}

test "load orders published apps by name then desktop id" {
    const files = [_]DesktopFile{
        .{ .root = 0, .id = @constCast("z.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=beta\nExec=beta",
        ) },
        .{ .root = 0, .id = @constCast("b.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Alpha\nExec=alpha-b",
        ) },
        .{ .root = 0, .id = @constCast("a.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=alpha\nExec=alpha-a",
        ) },
    };
    var list = try load(std.testing.allocator, &files, "Hyprland");
    defer list.deinit();
    try std.testing.expectEqualStrings("a.desktop", list.slice()[0].id);
    try std.testing.expectEqualStrings("b.desktop", list.slice()[1].id);
    try std.testing.expectEqualStrings("beta", list.slice()[2].name);
}

test "load handles every allocation failure without leaks" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, loadAllocationTest, .{});
}

fn loadAllocationTest(allocator: std.mem.Allocator) !void {
    const files = [_]DesktopFile{
        .{ .root = 0, .id = @constCast("one.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=One\nExec=one",
        ) },
        .{ .root = 0, .id = @constCast("two.desktop"), .bytes = @constCast(
            "[Desktop Entry]\nType=Application\nName=Two\nExec=two",
        ) },
    };
    var list = try load(allocator, &files, "Hyprland");
    defer list.deinit();
}

fn fuzzDesktopEntry(_: void, smith: *std.testing.Smith) !void {
    var input: [desktop_file_capacity + 1]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    const entry = parse(bytes) catch return;
    inline for (.{ entry.type, entry.name, entry.icon, entry.exec, entry.path }) |value| {
        if (value) |slice| {
            try std.testing.expect(@intFromPtr(slice.ptr) >= @intFromPtr(bytes.ptr));
            try std.testing.expect(@intFromPtr(slice.ptr) + slice.len <= @intFromPtr(bytes.ptr) + bytes.len);
        }
    }
}
