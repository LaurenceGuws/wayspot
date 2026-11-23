//! On-demand window discovery and focus. No resident state or compositor fallback.
const std = @import("std");
const Allocator = std.mem.Allocator;
const max_windows = 128;
const max_reply = 256 * 1024;
const max_action_reply = 64 * 1024;

fn Text(comptime capacity: usize) type {
    return struct {
        bytes: [capacity]u8 = undefined,
        len: u16 = 0,

        pub fn exact(input: []const u8) !@This() {
            if (input.len == 0 or input.len > capacity or !std.unicode.utf8ValidateSlice(input) or
                std.mem.indexOfScalar(u8, input, 0) != null) return error.InvalidText;
            var text: @This() = .{ .len = @intCast(input.len) };
            @memcpy(text.bytes[0..input.len], input);
            return text;
        }

        pub fn display(input: []const u8) !@This() {
            if (!std.unicode.utf8ValidateSlice(input) or std.mem.indexOfScalar(u8, input, 0) != null) return error.InvalidText;
            if (input.len == 0) return .{};
            if (input.len <= capacity) return exact(input);
            var end = capacity - "…".len;
            while (!std.unicode.utf8ValidateSlice(input[0..end])) end -= 1;
            var text: @This() = .{ .len = @intCast(end + "…".len) };
            @memcpy(text.bytes[0..end], input[0..end]);
            @memcpy(text.bytes[end..][0.."…".len], "…");
            return text;
        }

        pub fn slice(self: *const @This()) []const u8 {
            return self.bytes[0..self.len];
        }
    };
}

pub const StableId = Text(128);
pub const WorkspaceId = Text(128);
pub const MonitorId = Text(128);
pub const AppId = Text(192);
pub const Title = Text(384);
pub const Geometry = struct { x: f64, y: f64, width: f64, height: f64 };
pub const ViewportState = enum { visible, partial, offscreen, unknown };
pub const Presentation = enum { presented, workspace_inactive, occluded, hidden, unmapped };
pub const Edges = struct { left: bool = false, right: bool = false, top: bool = false, bottom: bool = false };

pub const Window = struct {
    stable_id: StableId,
    app_id: AppId,
    title: Title,
    workspace_id: ?WorkspaceId,
    monitor_id: ?MonitorId,
    geometry: Geometry,
    viewport: ViewportState = .unknown,
    edges: Edges = .{},
    presentation: Presentation,
    focus_rank: ?u32,
    active: bool,
    floating: bool,
    fullscreen: bool,
};

pub const WorkspacePosition = struct { ordinal: u16, total: u16 };
pub const Snapshot = struct {
    windows: [max_windows]Window = undefined,
    count: usize = 0,

    pub fn slice(self: *const Snapshot) []const Window {
        return self.windows[0..self.count];
    }

    pub fn workspacePosition(self: *const Snapshot, index: usize) ?WorkspacePosition {
        if (index >= self.count) return null;
        const target = &self.windows[index];
        const workspace = target.workspace_id orelse return null;
        var total: u16 = 0;
        var before: u16 = 0;
        for (self.slice()) |*window| {
            const candidate = window.workspace_id orelse continue;
            if (!std.mem.eql(u8, workspace.slice(), candidate.slice())) continue;
            total += 1;
            if (spatialLess(window, target)) before += 1;
        }
        std.debug.assert(total > 0);
        return .{ .ordinal = before + 1, .total = total };
    }
};

pub const Matches = struct {
    indexes: [max_windows]u16 = undefined,
    count: usize = 0,

    pub fn init(snapshot: *const Snapshot, query: []const u8) !Matches {
        if (query.len > 256 or !std.unicode.utf8ValidateSlice(query)) return error.InvalidQuery;
        var matches: Matches = .{};
        for (snapshot.slice(), 0..) |*window, index| {
            const workspace = if (window.workspace_id) |id| id.slice() else "";
            const monitor = if (window.monitor_id) |id| id.slice() else "";
            const ws_query = workspace.len != 0 and query.len > 3 and
                std.ascii.eqlIgnoreCase(query[0..3], "ws ") and
                std.ascii.eqlIgnoreCase(std.mem.trimStart(u8, query[3..], " "), workspace);
            if (!contains(window.app_id.slice(), query) and !contains(window.title.slice(), query) and
                !contains(workspace, query) and !contains(monitor, query) and !ws_query) continue;
            matches.indexes[matches.count] = @intCast(index);
            matches.count += 1;
        }
        return matches;
    }

    pub fn slice(self: *const Matches) []const u16 {
        return self.indexes[0..self.count];
    }
};

fn contains(text: []const u8, query: []const u8) bool {
    if (query.len > text.len) return false;
    for (0..text.len - query.len + 1) |i| {
        if (std.ascii.eqlIgnoreCase(text[i..][0..query.len], query)) return true;
    }
    return false;
}

fn spatialLess(a: *const Window, b: *const Window) bool {
    if (a.geometry.x != b.geometry.x) return a.geometry.x < b.geometry.x;
    if (a.geometry.y != b.geometry.y) return a.geometry.y < b.geometry.y;
    if (a.geometry.width != b.geometry.width) return a.geometry.width < b.geometry.width;
    if (a.geometry.height != b.geometry.height) return a.geometry.height < b.geometry.height;
    return std.mem.lessThan(u8, a.stable_id.slice(), b.stable_id.slice());
}

fn windowLess(_: void, a: Window, b: Window) bool {
    if (a.active != b.active) return a.active;
    if (a.focus_rank != b.focus_rank) {
        if (a.focus_rank == null) return false;
        if (b.focus_rank == null) return true;
        return a.focus_rank.? < b.focus_rank.?;
    }
    if (a.workspace_id) |workspace| {
        if (b.workspace_id) |other| {
            const order = std.mem.order(u8, workspace.slice(), other.slice());
            if (order != .eq) return order == .lt;
        } else return true;
    } else if (b.workspace_id != null) return false;
    return spatialLess(&a, &b);
}

/// The session's exact SDDM desktop identity, not a compatibility list.
pub const Backend = enum { hyprland, snowman };
pub fn backendForSession(desktop: ?[]const u8) ?Backend {
    const name = desktop orelse return null;
    if (std.mem.eql(u8, name, "Hyprland")) return .hyprland;
    if (std.mem.eql(u8, name, "Snowman")) return .snowman;
    return null;
}

/// Select a compositor's window listing operation.
pub const WindowDiscovery = union(Backend) {
    hyprland: void,
    snowman: void,

    pub fn argv(self: WindowDiscovery) ![]const []const u8 {
        return switch (self) {
            .hyprland => &.{ "hyprctl", "-j", "clients" },
            .snowman => error.SnowmanWindowDiscoveryUnavailable,
        };
    }
};

/// Focus one exact compositor-native window identity.
pub const WindowFocus = union(Backend) {
    hyprland: []const u8,
    snowman: []const u8,

    pub fn argv(self: WindowFocus, storage: *[3][]const u8, target: *[136]u8) ![]const []const u8 {
        return switch (self) {
            .snowman => error.SnowmanFocusUnavailable,
            .hyprland => |id| blk: {
                try validAddress(id);
                // Hyprland 0.56+ dispatches Lua expressions, not legacy names.
                storage[0] = "hyprctl";
                storage[1] = "dispatch";
                storage[2] = try std.fmt.bufPrint(target, "hl.dsp.focus({{ window = \"address:{s}\" }})", .{id});
                break :blk storage[0..3];
            },
        };
    }
};

/// Observe the compositor's actual focused window after dispatch.
pub const FocusObservation = union(Backend) {
    hyprland: void,
    snowman: void,

    pub fn argv(self: FocusObservation) ![]const []const u8 {
        return switch (self) {
            .hyprland => &.{ "hyprctl", "-j", "activewindow" },
            .snowman => error.SnowmanFocusUnavailable,
        };
    }
};

pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    succeeded: bool,

    pub fn deinit(self: *ProcessResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
        self.* = undefined;
    }
};

/// Native operations use std.Io; tests may supply a deterministic subprocess transcript.
fn run(operations: anytype, allocator: Allocator, argv: []const []const u8, max_stdout: usize) !ProcessResult {
    if (@TypeOf(operations) == std.Io) {
        const child = std.process.run(allocator, operations, .{
            .argv = argv,
            .stdout_limit = .limited(max_stdout),
            .stderr_limit = .limited(16 * 1024),
            .timeout = .{ .duration = .{ .raw = .fromSeconds(2), .clock = .awake } },
        }) catch |failure| return switch (failure) {
            error.FileNotFound => error.CompositorCliUnavailable,
            error.StreamTooLong => error.CompositorReplyTooLong,
            error.Timeout => error.CompositorCliTimedOut,
            error.OutOfMemory => error.OutOfMemory,
            else => error.CompositorCliFailed,
        };
        return .{
            .stdout = child.stdout,
            .stderr = child.stderr,
            .succeeded = switch (child.term) {
                .exited => |code| code == 0,
                else => false,
            },
        };
    } else return operations.run(allocator, argv, max_stdout);
}

/// Read current mapped windows only when the picker enters window mode.
pub fn load(operations: anytype, allocator: Allocator, backend: ?Backend, self_pid: i64) !Snapshot {
    switch (backend orelse return error.UnsupportedCompositor) {
        .snowman => return error.SnowmanWindowDiscoveryUnavailable,
        .hyprland => {},
    }
    var result = try run(operations, allocator, try (WindowDiscovery{ .hyprland = {} }).argv(), 256 * 1024);
    defer result.deinit(allocator);
    if (!result.succeeded) return error.CompositorCliRejected;
    return parseDesktop(allocator, result.stdout, self_pid, .hyprland);
}

/// Focus one window through Hyprland; Snowman refuses without invoking a CLI.
pub fn focus(operations: anytype, allocator: Allocator, backend: ?Backend, id: []const u8) !void {
    switch (backend orelse return error.UnsupportedCompositor) {
        .snowman => return error.SnowmanFocusUnavailable,
        .hyprland => {},
    }
    var storage: [3][]const u8 = undefined;
    var target: [136]u8 = undefined;
    var result = try run(operations, allocator, try (WindowFocus{ .hyprland = id }).argv(&storage, &target), max_action_reply);
    defer result.deinit(allocator);
    if (!result.succeeded or !std.mem.eql(u8, std.mem.trim(u8, result.stdout, " \t\r\n"), "ok")) {
        if (!@import("builtin").is_test) {
            // Quote bounded CLI output so diagnostics cannot inject terminal controls.
            const details = std.json.Stringify.valueAlloc(allocator, .{
                .exit_ok = result.succeeded,
                .stdout = result.stdout[0..@min(result.stdout.len, 256)],
                .stderr = result.stderr[0..@min(result.stderr.len, 256)],
            }, .{}) catch null;
            if (details) |reply| {
                defer allocator.free(reply);
                std.log.warn("hyprctl focus dispatch rejected: {s}", .{reply});
            }
        }
        return error.CompositorFocusRejected;
    }
    var observed = try run(operations, allocator, try (FocusObservation{ .hyprland = {} }).argv(), max_action_reply);
    defer observed.deinit(allocator);
    if (!observed.succeeded) return error.CompositorFocusUnverified;
    if (observed.stdout.len > max_action_reply) return error.CompositorReplyTooLong;
    var active = std.json.parseFromSlice(struct { address: []const u8 }, allocator, observed.stdout, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" }) catch return error.CompositorReplyMalformed;
    defer active.deinit();
    try validAddress(active.value.address);
    if (!std.ascii.eqlIgnoreCase(active.value.address, id)) return error.CompositorFocusMismatch;
}

const Client = struct {
    address: []const u8,
    class: []const u8,
    title: []const u8,
    pid: ?i64 = null,
    mapped: bool,
    xwayland_hidden: bool = false,
    hidden: bool = false,
    at: [2]f64,
    size: [2]f64,
    workspace: struct {
        id: ?i64 = null,
        address: ?[]const u8 = null,
    },
    monitor: i64,
    floating: bool,
    fullscreen: std.json.Value,
    focusHistoryID: ?i64 = null,
};

/// Decode one bounded, owned Hyprland client list into the picker's window model.
pub fn parseDesktop(allocator: Allocator, bytes: []const u8, self_pid: i64, backend: Backend) !Snapshot {
    if (backend == .snowman) return error.SnowmanWindowDiscoveryUnavailable;
    if (bytes.len > max_reply) return error.CompositorReplyTooLong;
    var decoded = std.json.parseFromSlice([]Client, allocator, bytes, .{
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .@"error",
        .max_value_len = max_reply,
    }) catch |failure| {
        if (failure == error.OutOfMemory) return error.OutOfMemory;
        // Only on schema failure: locate the bad client without exposing titles
        // or paying for a second decode on successful discovery.
        var raw = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
            .duplicate_field_behavior = .@"error",
            .max_value_len = max_reply,
        }) catch {
            if (!@import("builtin").is_test) std.log.warn("hyprctl clients JSON syntax error: {s}", .{@errorName(failure)});
            return error.CompositorReplyMalformed;
        };
        defer raw.deinit();
        if (raw.value == .array) {
            for (raw.value.array.items, 0..) |entry, index| {
                var checked = std.json.parseFromValue(Client, allocator, entry, .{
                    .ignore_unknown_fields = true,
                }) catch |cause| {
                    if (cause == error.OutOfMemory) return error.OutOfMemory;
                    if (!@import("builtin").is_test) std.log.warn("hyprctl clients[{d}] schema mismatch: {s}", .{ index, @errorName(cause) });
                    return error.CompositorReplyMalformed;
                };
                checked.deinit();
            }
        }
        if (!@import("builtin").is_test) std.log.warn("hyprctl clients JSON decode failed: {s}", .{@errorName(failure)});
        return error.CompositorReplyMalformed;
    };
    defer decoded.deinit();
    if (decoded.value.len > max_windows) return error.TooManyWindows;
    var snapshot: Snapshot = .{};
    for (decoded.value, 0..) |client, index| {
        if (!client.mapped or client.xwayland_hidden or (client.pid != null and client.pid.? == self_pid)) continue;
        try validAddress(client.address);
        // A mapped scratchpad may be hidden before it receives positive geometry.
        // Preserve it in the finder without inventing dimensions or rejecting the list.
        if (!std.math.isFinite(client.at[0]) or !std.math.isFinite(client.at[1]) or
            !std.math.isFinite(client.size[0]) or !std.math.isFinite(client.size[1]) or
            client.size[0] < 0 or client.size[1] < 0)
        {
            if (!@import("builtin").is_test) std.log.warn("hyprctl clients[{d}] ({s}): nonfinite or negative geometry", .{ index, client.address });
            return error.GeometryInvalid;
        }
        const fullscreen = switch (client.fullscreen) {
            .bool => |v| v,
            .integer => |v| v != 0,
            else => {
                if (!@import("builtin").is_test) std.log.warn("hyprctl clients[{d}] fullscreen is not boolean or integer", .{index});
                return error.CompositorReplyMalformed;
            },
        };
        var ws: [32]u8 = undefined;
        var monitor: [32]u8 = undefined;
        const rank = client.focusHistoryID;
        // Hyprland's special workspaces have an address but no numeric id.
        const workspace = if (client.workspace.id) |id|
            try std.fmt.bufPrint(&ws, "{d}", .{id})
        else
            client.workspace.address orelse return error.CompositorFieldMissing;
        const window: Window = .{
            .stable_id = try StableId.exact(client.address),
            .app_id = try AppId.display(client.class),
            .title = try Title.display(client.title),
            .workspace_id = try WorkspaceId.exact(workspace),
            .monitor_id = if (client.monitor < 0) null else try MonitorId.exact(try std.fmt.bufPrint(&monitor, "{d}", .{client.monitor})),
            .geometry = .{ .x = client.at[0], .y = client.at[1], .width = client.size[0], .height = client.size[1] },
            .presentation = if (client.hidden) .hidden else .presented,
            .focus_rank = if (rank != null and rank.? >= 0 and rank.? <= std.math.maxInt(u32)) @intCast(rank.?) else null,
            .active = rank != null and rank.? == 0,
            .floating = client.floating,
            .fullscreen = fullscreen,
        };
        for (snapshot.slice()) |existing| {
            if (std.mem.eql(u8, existing.stable_id.slice(), window.stable_id.slice())) return error.DuplicateStableId;
        }
        snapshot.windows[snapshot.count] = window;
        snapshot.count += 1;
    }
    std.mem.sort(Window, snapshot.windows[0..snapshot.count], {}, windowLess);
    return snapshot;
}

fn validAddress(value: []const u8) !void {
    if (value.len < 3 or value.len > 18 or !std.mem.startsWith(u8, value, "0x")) return error.InvalidWindowAddress;
    for (value[2..]) |byte| if (!std.ascii.isHex(byte)) return error.InvalidWindowAddress;
}

const fixture =
    \\[
    \\ {"address":"0x2","class":"zen","title":"Browser","pid":20,"mapped":true,"at":[6.5,4],"size":[1910.25,1072],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":1},
    \\ {"address":"0x3","class":"kitty","title":"Terminal","pid":10,"mapped":true,"at":[-1910,4],"size":[1910,1072],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":2},
    \\ {"address":"0x4","class":"org.kde.dolphin","title":"Files","pid":30,"mapped":true,"hidden":true,"at":[1920,0],"size":[960,1080],"workspace":{"id":2},"monitor":1,"floating":true,"fullscreen":0,"focusHistoryID":3},
    \\ {"address":"0x5","class":"wayspot","title":"Picker","pid":99,"mapped":true,"at":[0,0],"size":[720,520],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":0}
    \\]
;

test "session selection is exact" {
    try std.testing.expectEqual(@as(?Backend, .snowman), backendForSession("Snowman"));
    try std.testing.expectEqual(@as(?Backend, .hyprland), backendForSession("Hyprland"));
    try std.testing.expectEqual(@as(?Backend, null), backendForSession("Hyprland:Snowman"));
    try std.testing.expectEqual(@as(?Backend, null), backendForSession(null));
}

test "Hyprland snapshot retains focus order and workspace metadata" {
    const snapshot = try parseDesktop(std.testing.allocator, fixture, 99, .hyprland);
    try std.testing.expectEqual(@as(usize, 3), snapshot.count);
    try std.testing.expectEqualStrings("0x2", snapshot.windows[0].stable_id.slice());
    try std.testing.expectEqualStrings("0x3", snapshot.windows[1].stable_id.slice());
    try std.testing.expectEqual(.hidden, snapshot.windows[2].presentation);
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 2, .total = 2 }, snapshot.workspacePosition(0).?);
    try std.testing.expectEqualSlices(u16, &.{1}, (try Matches.init(&snapshot, "term")).slice());
    try std.testing.expectEqualSlices(u16, &.{2}, (try Matches.init(&snapshot, "ws 2")).slice());
}

test "hidden Hyprland special workspace can have zero-sized geometry" {
    const payload =
        \\[
        \\ {"address":"0x9","class":"kitty","title":"Scratchpad","mapped":true,"hidden":true,"at":[430,-2880],"size":[0,0],"workspace":{"id":-98,"name":"special:scratchpad"},"monitor":-1,"floating":true,"fullscreen":false,"focusHistoryID":-1}
        \\]
    ;
    const snapshot = try parseDesktop(std.testing.allocator, payload, 42, .hyprland);
    try std.testing.expectEqual(@as(usize, 1), snapshot.count);
    const window = &snapshot.windows[0];
    try std.testing.expectEqualStrings("-98", window.workspace_id.?.slice());
    try std.testing.expect(window.monitor_id == null);
    try std.testing.expectEqual(@as(f64, 0), window.geometry.width);
    try std.testing.expectEqual(@as(f64, 0), window.geometry.height);
    try std.testing.expectEqual(Presentation.hidden, window.presentation);
    try std.testing.expect(window.focus_rank == null);
}

test "one malformed Hyprland client reports a schema failure without partial publication" {
    const payload =
        \\[
        \\ {"address":"0x2","class":"kitty","title":"Terminal","mapped":true,"at":[0,0],"size":[120,80],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0},
        \\ {"address":"0x3","class":"broken","title":"Scratchpad","mapped":true,"at":[0,0],"size":[0,0],"workspace":{"id":"special:broken"},"monitor":-1,"floating":true,"fullscreen":false}
        \\]
    ;
    try std.testing.expectError(error.CompositorReplyMalformed, parseDesktop(std.testing.allocator, payload, 42, .hyprland));
}

test "Hyprland mixed normal and special workspace clients include an absent numeric id" {
    const payload =
        \\[
        \\ {"address":"0x1","class":"howl","title":"Terminal","mapped":true,"hidden":false,"at":[1924,4],"size":[2392,1342],"workspace":{"address":"2","id":2,"type":"normal","name":"2"},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":0},
        \\ {"address":"0x2","class":"howl","title":"Scratch","mapped":true,"hidden":false,"at":[1924,4],"size":[2392,1342],"workspace":{"address":"special:magic","type":"special","name":"special:magic"},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":1}
        \\]
    ;
    const snapshot = try parseDesktop(std.testing.allocator, payload, 99, .hyprland);
    try std.testing.expectEqual(@as(usize, 2), snapshot.count);
    try std.testing.expectEqualStrings("2", snapshot.windows[0].workspace_id.?.slice());
    try std.testing.expectEqualStrings("special:magic", snapshot.windows[1].workspace_id.?.slice());
    try std.testing.expectEqual(@as(usize, 1), (try Matches.init(&snapshot, "special:magic")).count);
    try std.testing.expectEqualSlices(u16, &.{1}, (try Matches.init(&snapshot, "ws special:magic")).slice());
}

test "Snowman never produces a subprocess command" {
    try std.testing.expectError(error.SnowmanWindowDiscoveryUnavailable, (WindowDiscovery{ .snowman = {} }).argv());
    var storage: [3][]const u8 = undefined;
    var target: [136]u8 = undefined;
    try std.testing.expectError(error.SnowmanFocusUnavailable, (WindowFocus{ .snowman = "1" }).argv(&storage, &target));
    try std.testing.expectError(error.SnowmanFocusUnavailable, (FocusObservation{ .snowman = {} }).argv());
    try std.testing.expectError(error.SnowmanWindowDiscoveryUnavailable, parseDesktop(std.testing.allocator, "[]", 1, .snowman));
}

test "bad native data and duplicate exact targets are rejected" {
    try std.testing.expectError(error.CompositorReplyMalformed, parseDesktop(std.testing.allocator, "{}", 1, .hyprland));
    const duplicated =
        \\[
        \\ {"address":"0x1","class":"one","title":"One","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0},
        \\ {"address":"0x1","class":"two","title":"Two","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0}
        \\]
    ;
    try std.testing.expectError(error.DuplicateStableId, parseDesktop(std.testing.allocator, duplicated, 1, .hyprland));
    var storage: [3][]const u8 = undefined;
    var target: [136]u8 = undefined;
    const focus_args = try (WindowFocus{ .hyprland = "0xAbC123" }).argv(&storage, &target);
    try std.testing.expectEqual(@as(usize, 3), focus_args.len);
    try std.testing.expectEqualStrings("hyprctl", focus_args[0]);
    try std.testing.expectEqualStrings("dispatch", focus_args[1]);
    try std.testing.expectEqualStrings("hl.dsp.focus({ window = \"address:0xAbC123\" })", focus_args[2]);
    try std.testing.expectError(error.InvalidWindowAddress, (WindowFocus{ .hyprland = "class:any" }).argv(&storage, &target));
}
