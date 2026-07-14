//! CLI owns terminal consumption of the shared Cmd tree.
//!
//! It accepts the current terminal routes, writes the existing terminal records,
//! and invokes one already-wired Picker. Candidate meaning and construction
//! remain in picker.cmd; Bash position mapping and serialization are delegated
//! to the command completion boundary and bash_completion.

const std = @import("std");
const picker_owner = @import("wayspot_picker");
const cmd_owner = picker_owner.cmd;
const process_owner = @import("wayspot_process");
const apps_mode = picker_owner.mode.apps;
const candidate = picker_owner.candidate;
const icon_cache = picker_owner.icon_cache;
const icon_diag = picker_owner.icon_diag;
const sunglasses_mode = picker_owner.mode.sunglasses;
pub const bash_completion = @import("bash_completion.zig");

/// accepts reports whether args select one CLI consumer path.
pub fn accepts(args: []const []const u8) bool {
    if (args.len < 2) return false;
    if (std.mem.eql(u8, args[1], "apps")) return true;
    if (std.mem.eql(u8, args[1], "commands")) return true;
    if (std.mem.eql(u8, args[1], "query")) return true;
    if (std.mem.eql(u8, args[1], "open")) return true;
    if (std.mem.eql(u8, args[1], "--icon-diag")) return true;
    if (std.mem.eql(u8, args[1], "--icon-cache-refresh")) return true;
    return args.len >= 3 and
        std.mem.eql(u8, args[1], "complete") and
        std.mem.eql(u8, args[2], "bash");
}

/// run consumes one already-wired Picker through the terminal interface.
pub fn run(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    picker: *cmd_owner.Picker,
    home: []const u8,
) !void {
    if (!accepts(args)) return error.UnknownCliCommand;

    if (std.mem.eql(u8, args[1], "--icon-diag")) {
        try runIconDiag(allocator, picker);
        return;
    }

    if (std.mem.eql(u8, args[1], "--icon-cache-refresh")) {
        try runIconCacheRefresh(allocator, picker, home);
        return;
    }

    if (std.mem.eql(u8, args[1], "apps")) {
        try runApps(allocator, picker, args[2..]);
        return;
    }

    if (std.mem.eql(u8, args[1], "commands")) {
        try runRows(allocator, picker);
        return;
    }

    if (std.mem.eql(u8, args[1], "query")) {
        try runQuery(allocator, picker, args[2..]);
        return;
    }

    if (std.mem.eql(u8, args[1], "open")) {
        if (args.len != 3) return error.OpenPayloadRequired;
        try runOpen(allocator, picker, args[2]);
        return;
    }

    std.debug.assert(args.len >= 3);
    try runBashCompletion(allocator, picker, args[3..]);
}

fn runRows(allocator: std.mem.Allocator, picker: *cmd_owner.Picker) !void {
    try picker.loadHistory(allocator);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try picker.commands(allocator, &stdout_writer.interface);
    try stdout_writer.interface.flush();
}

fn runIconDiag(allocator: std.mem.Allocator, picker: *cmd_owner.Picker) !void {
    var candidates = candidate.Candidate.List.empty;
    defer candidates.deinit();
    const apps = try appsOwner(picker);
    try apps.collectCandidates(allocator, &candidates);
    try icon_diag.writeReport(candidates.slice());
}

fn runIconCacheRefresh(
    allocator: std.mem.Allocator,
    picker: *cmd_owner.Picker,
    home: []const u8,
) !void {
    var candidates = candidate.Candidate.List.empty;
    defer candidates.deinit();
    const apps = try appsOwner(picker);
    try apps.collectCandidates(allocator, &candidates);
    const counts = try icon_cache.refresh(home, candidates.slice());
    try icon_cache.printRefreshSummary(counts);
}

fn appsOwner(picker: *cmd_owner.Picker) !*apps_mode.Apps {
    return switch (picker.cmds[0]) {
        .apps => |owner| owner orelse error.AppsOwnerMissing,
        .notifications, .wallpaper, .sunglasses => error.AppsOwnerMissing,
    };
}

fn runQuery(
    allocator: std.mem.Allocator,
    picker: *cmd_owner.Picker,
    query_parts: []const []const u8,
) !void {
    const raw_query = try joinCommandText(allocator, query_parts);
    defer allocator.free(raw_query);
    try picker.loadHistory(allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try picker.query(allocator, raw_query, &stdout_writer.interface);
    try stdout_writer.interface.flush();
}

fn runApps(
    allocator: std.mem.Allocator,
    picker: *cmd_owner.Picker,
    query_parts: []const []const u8,
) !void {
    const raw_query = try appsQuery(allocator, query_parts);
    defer allocator.free(raw_query);
    try picker.loadHistory(allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try picker.query(allocator, raw_query, &stdout_writer.interface);
    try stdout_writer.interface.flush();
}

fn appsQuery(allocator: std.mem.Allocator, query_parts: []const []const u8) ![]u8 {
    if (query_parts.len == 0) return allocator.dupe(u8, "/apps");

    const terms = try joinCommandText(allocator, query_parts);
    defer allocator.free(terms);
    const prefix = "/apps ";
    if (terms.len > cmd_owner.max_cmd_bytes -| prefix.len) return error.CommandTooLong;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, terms });
}

fn runOpen(allocator: std.mem.Allocator, picker: *cmd_owner.Picker, lookup: []const u8) !void {
    try picker.loadHistory(allocator);
    const intent = try picker.open(allocator, lookup);
    defer allocator.free(intent);
    try picker.recordSelection(allocator, lookup);
    try runIntentBytes(intent);
    try picker.saveHistory(allocator);
}

fn runBashCompletion(
    allocator: std.mem.Allocator,
    picker: *cmd_owner.Picker,
    query_parts: []const []const u8,
) !void {
    if (query_parts.len != 2) return error.CompletionArgumentsInvalid;
    const position = try parseCompletionPosition(query_parts[0]);
    const raw_query = query_parts[1];
    if (raw_query.len > cmd_owner.max_cmd_bytes) return error.CommandTooLong;
    try picker.loadHistory(allocator);

    const completed = try picker.complete(allocator, position, raw_query);
    defer allocator.free(completed);

    var stdout_buffer: [bash_completion.max_completion_output_bytes]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try bash_completion.write(&stdout_writer.interface, completed);
    try stdout_writer.interface.flush();
}

/// parseCompletionPosition decodes the bounded CLI completion position vocabulary.
fn parseCompletionPosition(value: []const u8) !cmd_owner.CompletionPosition {
    if (std.mem.eql(u8, value, "mode")) return .mode;
    if (std.mem.eql(u8, value, "sub_cmd")) return .sub_cmd;
    if (std.mem.eql(u8, value, "operation")) return .operation;
    if (std.mem.eql(u8, value, "app")) return .app;
    return error.CompletionPositionInvalid;
}

fn runIntentBytes(intent: []const u8) !void {
    try process_owner.runDetached(intent);
}

fn joinCommandText(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    if (parts.len == 0) return allocator.dupe(u8, "");
    var total_len: u32 = 0;
    for (parts) |part| {
        total_len += @intCast(part.len);
        if (total_len > cmd_owner.max_cmd_bytes) return error.CommandTooLong;
    }
    total_len += @intCast(parts.len - 1);
    if (total_len > cmd_owner.max_cmd_bytes) return error.CommandTooLong;

    var out = try std.ArrayList(u8).initCapacity(allocator, total_len);
    errdefer out.deinit(allocator);
    for (parts, 0..) |part, index| {
        if (index > 0) try out.append(allocator, ' ');
        try out.appendSlice(allocator, part);
    }
    return try out.toOwnedSlice(allocator);
}

test "CLI accepts only terminal consumer paths" {
    try std.testing.expect(accepts(&.{ "wayspot", "apps" }));
    try std.testing.expect(accepts(&.{ "wayspot", "query", "/apps" }));
    try std.testing.expect(accepts(&.{ "wayspot", "complete", "bash" }));
    try std.testing.expect(!accepts(&.{ "wayspot", "--ui" }));
    try std.testing.expect(!accepts(&.{"wayspot"}));
}

test "CLI apps input uses the shared apps route" {
    const empty = try appsQuery(std.testing.allocator, &.{});
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualStrings("/apps", empty);

    const parts = [_][]const u8{ "Firefox", "Browser" };
    const filtered = try appsQuery(std.testing.allocator, &parts);
    defer std.testing.allocator.free(filtered);
    try std.testing.expectEqualStrings("/apps Firefox Browser", filtered);
}

test "CLI completion position vocabulary is closed" {
    try std.testing.expectEqual(cmd_owner.CompletionPosition.mode, try parseCompletionPosition("mode"));
    try std.testing.expectEqual(cmd_owner.CompletionPosition.sub_cmd, try parseCompletionPosition("sub_cmd"));
    try std.testing.expectEqual(cmd_owner.CompletionPosition.operation, try parseCompletionPosition("operation"));
    try std.testing.expectEqual(cmd_owner.CompletionPosition.app, try parseCompletionPosition("app"));
    try std.testing.expectError(error.CompletionPositionInvalid, parseCompletionPosition("payload"));
}

test "CLI and GUI typed commits use equal Concrete values and rejection" {
    const scalar_from_cli = try candidate.Input.scalarInput(35, 0, 100, 1);
    const scalar_from_gui = try candidate.Input.scalarInput(35, 0, 100, 1);
    const cli_leaf = try sunglasses_mode.select(.{ .dim = .{ .set = {} } }, "DP-1", scalar_from_cli);
    const gui_leaf = try sunglasses_mode.select(.{ .dim = .{ .set = {} } }, "DP-1", scalar_from_gui);
    try std.testing.expectEqual(cli_leaf, gui_leaf);

    const toggle_from_cli = candidate.Input.toggleInput(true);
    const toggle_from_gui = candidate.Input.toggleInput(true);
    const cli_toggle = try sunglasses_mode.select(.{ .filter = .{ .on = {} } }, "DP-1", toggle_from_cli);
    const gui_toggle = try sunglasses_mode.select(.{ .filter = .{ .on = {} } }, "DP-1", toggle_from_gui);
    try std.testing.expectEqual(cli_toggle, gui_toggle);

    const path_from_cli = try candidate.Input.pathInput("/tmp/sunglasses.png");
    const path_from_gui = try candidate.Input.pathInput("/tmp/sunglasses.png");
    const cli_path = try sunglasses_mode.select(.{ .image = .{ .set = {} } }, "DP-1", path_from_cli);
    const gui_path = try sunglasses_mode.select(.{ .image = .{ .set = {} } }, "DP-1", path_from_gui);
    try std.testing.expectEqual(cli_path, gui_path);

    try std.testing.expectError(
        error.InputNotAccepted,
        sunglasses_mode.select(.{ .dim = .{ .set = {} } }, "DP-1", toggle_from_cli),
    );
    try std.testing.expectError(
        error.InputNotAccepted,
        sunglasses_mode.select(.{ .image = .{ .set = {} } }, "DP-1", toggle_from_gui),
    );
}
