//! Owns one bounded, invocation-local WMIO desktop snapshot and exact focus action.
//!
//! Wayspot deliberately learns graphical truth only through WMIO's public
//! `wmio/v1` envelope. The picker decides when to load this model; this module
//! has no resident watcher, persistent cache, or Hyprland vocabulary.

const std = @import("std");

pub const window_capacity: usize = 128;
pub const response_capacity: usize = 256 * 1024;
pub const action_response_capacity: usize = 64 * 1024;
pub const error_response_capacity: usize = 16 * 1024;
pub const process_timeout: std.Io.Clock.Duration = .{
    .raw = .fromSeconds(2),
    .clock = .awake,
};

const stable_id_capacity: usize = 128;
const workspace_id_capacity: usize = 128;
const monitor_id_capacity: usize = 128;
const app_id_capacity: usize = 192;
const title_capacity: usize = 384;

fn FixedText(comptime capacity: usize) type {
    comptime std.debug.assert(capacity <= std.math.maxInt(u16));
    return struct {
        const Self = @This();

        bytes: [capacity]u8 = undefined,
        len: u16 = 0,

        pub fn exact(input: []const u8) !Self {
            if (input.len == 0) return error.TextEmpty;
            if (input.len > capacity) return error.TextTooLong;
            if (!std.unicode.utf8ValidateSlice(input)) return error.InvalidUtf8;
            if (std.mem.indexOfScalar(u8, input, 0) != null) return error.TextInvalid;
            var value: Self = .{ .len = @intCast(input.len) };
            @memcpy(value.bytes[0..input.len], input);
            return value;
        }

        pub fn display(input: []const u8) !Self {
            if (!std.unicode.utf8ValidateSlice(input)) return error.InvalidUtf8;
            if (std.mem.indexOfScalar(u8, input, 0) != null) return error.TextInvalid;
            if (input.len <= capacity) {
                var value: Self = .{ .len = @intCast(input.len) };
                @memcpy(value.bytes[0..input.len], input);
                return value;
            }
            const ellipsis = "…";
            comptime std.debug.assert(capacity > ellipsis.len);
            var prefix = capacity - ellipsis.len;
            while (prefix > 0 and textContinuation(input[prefix])) prefix -= 1;
            var value: Self = .{ .len = @intCast(prefix + ellipsis.len) };
            @memcpy(value.bytes[0..prefix], input[0..prefix]);
            @memcpy(value.bytes[prefix..][0..ellipsis.len], ellipsis);
            return value;
        }

        pub fn slice(value: *const Self) []const u8 {
            return value.bytes[0..value.len];
        }
    };
}

fn textContinuation(byte: u8) bool {
    return byte & 0b1100_0000 == 0b1000_0000;
}

pub const StableId = FixedText(stable_id_capacity);
pub const WorkspaceId = FixedText(workspace_id_capacity);
pub const MonitorId = FixedText(monitor_id_capacity);
pub const AppId = FixedText(app_id_capacity);
pub const Title = FixedText(title_capacity);

pub const ViewportState = enum {
    visible,
    partial,
    offscreen,
    unknown,
};

pub const Presentation = enum {
    presented,
    workspace_inactive,
    occluded,
    hidden,
    unmapped,
};

pub const Edges = struct {
    left: bool = false,
    right: bool = false,
    top: bool = false,
    bottom: bool = false,

    pub fn any(edges: Edges) bool {
        return edges.left or edges.right or edges.top or edges.bottom;
    }
};

pub const Geometry = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const Window = struct {
    stable_id: StableId,
    app_id: AppId,
    title: Title,
    workspace_id: ?WorkspaceId,
    monitor_id: ?MonitorId,
    geometry: Geometry,
    viewport: ViewportState,
    edges: Edges,
    presentation: Presentation,
    focus_rank: ?u32,
    active: bool,
    floating: bool,
    fullscreen: bool,

    pub fn label(window: *const Window) []const u8 {
        if (window.title.len > 0) return window.title.slice();
        if (window.app_id.len > 0) return window.app_id.slice();
        return window.stable_id.slice();
    }
};

pub const WorkspacePosition = struct {
    ordinal: u16,
    total: u16,
};

pub const Snapshot = struct {
    windows: [window_capacity]Window = undefined,
    count: usize = 0,

    pub fn slice(snapshot: *const Snapshot) []const Window {
        return snapshot.windows[0..snapshot.count];
    }

    pub fn selected(snapshot: *const Snapshot) ?usize {
        return if (snapshot.count == 0) null else 0;
    }

    /// Returns a stable 1/N geometry ordinal without changing the finder's MRU order.
    pub fn workspacePosition(snapshot: *const Snapshot, index: usize) ?WorkspacePosition {
        if (index >= snapshot.count) return null;
        const target = &snapshot.windows[index];
        const workspace_id = target.workspace_id orelse return null;
        var total: u16 = 0;
        var before: u16 = 0;
        for (snapshot.slice()) |*candidate| {
            const candidate_workspace = candidate.workspace_id orelse continue;
            if (!std.mem.eql(u8, candidate_workspace.slice(), workspace_id.slice())) continue;
            total += 1;
            if (spatialLessThan(candidate, target)) before += 1;
        }
        std.debug.assert(total > 0);
        return .{ .ordinal = before + 1, .total = total };
    }
};

pub const Matches = struct {
    indexes: [window_capacity]u16 = undefined,
    count: usize = 0,

    pub fn init(snapshot: *const Snapshot, query: []const u8) !Matches {
        if (query.len > 256) return error.QueryTooLong;
        if (!std.unicode.utf8ValidateSlice(query)) return error.InvalidUtf8;
        var matches: Matches = .{};
        for (snapshot.slice(), 0..) |window, index| {
            if (!windowMatches(&window, query)) continue;
            matches.indexes[matches.count] = @intCast(index);
            matches.count += 1;
        }
        return matches;
    }

    pub fn slice(matches: *const Matches) []const u16 {
        return matches.indexes[0..matches.count];
    }
};

fn windowMatches(window: *const Window, query: []const u8) bool {
    if (query.len == 0) return true;
    if (containsIgnoreCase(window.app_id.slice(), query)) return true;
    if (containsIgnoreCase(window.title.slice(), query)) return true;
    if (window.workspace_id) |workspace_id| {
        if (containsIgnoreCase(workspace_id.slice(), query)) return true;
        if (workspaceQuery(query, workspace_id.slice())) return true;
    }
    if (window.monitor_id) |monitor_id| {
        if (containsIgnoreCase(monitor_id.slice(), query)) return true;
    }
    return false;
}

fn workspaceQuery(query: []const u8, workspace_id: []const u8) bool {
    if (query.len < 2) return false;
    if (std.ascii.toLower(query[0]) != 'w' or std.ascii.toLower(query[1]) != 's') return false;
    var start: usize = 2;
    while (start < query.len and query[start] == ' ') start += 1;
    return start < query.len and std.ascii.eqlIgnoreCase(query[start..], workspace_id);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;
    for (0..haystack.len - needle.len + 1) |index| {
        if (std.ascii.eqlIgnoreCase(haystack[index..][0..needle.len], needle)) return true;
    }
    return false;
}

pub const Request = union(enum) {
    desktop,
    focus: []const u8,

    pub fn arguments(request: Request, storage: *[4][]const u8) []const []const u8 {
        return switch (request) {
            .desktop => blk: {
                storage[0] = "wmio";
                storage[1] = "desktop";
                break :blk storage[0..2];
            },
            .focus => |stable_id| blk: {
                storage[0] = "wmio";
                storage[1] = "focus";
                storage[2] = "--stable-id";
                storage[3] = stable_id;
                break :blk storage[0..4];
            },
        };
    }

    pub fn stdoutLimit(request: Request) usize {
        return switch (request) {
            .desktop => response_capacity,
            .focus => action_response_capacity,
        };
    }
};

pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    succeeded: bool,

    pub fn deinit(result: *ProcessResult, allocator: std.mem.Allocator) void {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
        result.* = undefined;
    }
};

pub const Native = struct {
    io: std.Io,

    pub fn run(
        native: *Native,
        allocator: std.mem.Allocator,
        request: Request,
    ) !ProcessResult {
        var argument_storage: [4][]const u8 = undefined;
        const arguments = request.arguments(&argument_storage);
        const result = std.process.run(allocator, native.io, .{
            .argv = arguments,
            .stdout_limit = .limited(request.stdoutLimit()),
            .stderr_limit = .limited(error_response_capacity),
            .timeout = .{ .duration = process_timeout },
        }) catch |failure| return switch (failure) {
            error.FileNotFound => error.WmioUnavailable,
            error.StreamTooLong => error.WmioOutputTooLong,
            error.Timeout => error.WmioTimedOut,
            error.OutOfMemory => error.OutOfMemory,
            else => error.WmioSpawnFailed,
        };
        return .{
            .stdout = result.stdout,
            .stderr = result.stderr,
            .succeeded = termSucceeded(result.term),
        };
    }
};

fn termSucceeded(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

/// Reads one fresh bounded desktop snapshot through the public WMIO CLI.
pub fn load(
    operations: anytype,
    allocator: std.mem.Allocator,
    self_pid: i64,
) !Snapshot {
    var result = try operations.run(allocator, Request{ .desktop = {} });
    defer result.deinit(allocator);
    if (!result.succeeded) return error.WmioRejected;
    return parseDesktop(allocator, result.stdout, self_pid);
}

/// Requests and verifies exact stable-id focus through the public WMIO CLI.
pub fn focus(
    operations: anytype,
    allocator: std.mem.Allocator,
    stable_id: []const u8,
) !void {
    _ = try StableId.exact(stable_id);
    var result = try operations.run(allocator, .{ .focus = stable_id });
    defer result.deinit(allocator);
    if (!result.succeeded) return error.WmioRejected;
    try parseFocus(allocator, result.stdout, stable_id);
}

pub fn parseDesktop(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    self_pid: i64,
) !Snapshot {
    if (bytes.len > response_capacity) return error.WmioOutputTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
        .parse_numbers = false,
        .duplicate_field_behavior = .@"error",
        .max_value_len = response_capacity,
    }) catch |failure| return switch (failure) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.WmioMalformed,
    };
    defer parsed.deinit();

    const envelope = try object(parsed.value);
    try validateEnvelope(envelope, "desktop");
    const data = try object(try field(envelope, "data"));
    var snapshot: Snapshot = .{};

    const windows = try array(try field(data, "windows"));
    if (windows.len > window_capacity) return error.TooManyWindows;
    for (windows) |value| {
        const window_object = try object(value);
        if (!try booleanField(window_object, "mapped")) continue;
        if (!try booleanField(window_object, "accepts_input")) continue;
        const pid = try nullableIntegerField(window_object, "pid");
        if (pid != null and pid.? == self_pid) continue;
        if (snapshot.count == snapshot.windows.len) return error.TooManyWindows;
        const retained = try parseWindow(window_object);
        for (snapshot.windows[0..snapshot.count]) |existing| {
            if (std.mem.eql(u8, existing.stable_id.slice(), retained.stable_id.slice())) {
                return error.DuplicateStableId;
            }
        }
        snapshot.windows[snapshot.count] = retained;
        snapshot.count += 1;
    }
    std.mem.sort(Window, snapshot.windows[0..snapshot.count], {}, windowLessThan);
    return snapshot;
}

fn parseWindow(object_value: std.json.ObjectMap) !Window {
    const viewport = try parseViewport(object_value.get("viewport"));
    const mode = try stringField(object_value, "mode");
    const workspace_ids = try array(try field(object_value, "workspace_ids"));
    const workspace_id: ?WorkspaceId = if (workspace_ids.len == 0)
        null
    else
        try WorkspaceId.exact(try string(workspace_ids[0]));
    const focus_rank_value = try optionalNullableIntegerField(object_value, "focus_rank");
    const focus_rank: ?u32 = if (focus_rank_value) |rank| blk: {
        if (rank < 0 or rank > std.math.maxInt(u32)) return error.FocusRankInvalid;
        break :blk @intCast(rank);
    } else null;
    return .{
        .stable_id = try StableId.exact(try stringField(object_value, "stable_id")),
        .app_id = try AppId.display(try stringField(object_value, "app_id")),
        .title = try Title.display(try stringField(object_value, "title")),
        .workspace_id = workspace_id,
        .monitor_id = if (try nullableStringField(object_value, "monitor_id")) |monitor_id|
            try MonitorId.exact(monitor_id)
        else
            null,
        .geometry = try parseGeometry(try object(try field(object_value, "geometry"))),
        .viewport = viewport.state,
        .edges = viewport.edges,
        .presentation = try parsePresentation(try stringField(object_value, "presentation")),
        .focus_rank = focus_rank,
        .active = try booleanField(object_value, "active"),
        .floating = std.mem.eql(u8, mode, "floating"),
        .fullscreen = std.mem.eql(u8, mode, "fullscreen"),
    };
}

fn parseFocus(allocator: std.mem.Allocator, bytes: []const u8, expected_id: []const u8) !void {
    if (bytes.len > action_response_capacity) return error.WmioOutputTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
        .parse_numbers = false,
        .duplicate_field_behavior = .@"error",
        .max_value_len = action_response_capacity,
    }) catch |failure| return switch (failure) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.WmioMalformed,
    };
    defer parsed.deinit();
    const envelope = try object(parsed.value);
    try validateEnvelope(envelope, "focus");
    const data = try object(try field(envelope, "data"));
    if (!std.mem.eql(u8, try stringField(data, "stable_id"), expected_id)) {
        return error.WmioFocusMismatch;
    }
}

fn validateEnvelope(envelope: std.json.ObjectMap, operation: []const u8) !void {
    if (!std.mem.eql(u8, try stringField(envelope, "schema"), "wmio/v1")) {
        return error.WmioSchemaInvalid;
    }
    if (!try booleanField(envelope, "ok")) return error.WmioRejected;
    if (!std.mem.eql(u8, try stringField(envelope, "operation"), operation)) {
        return error.WmioOperationInvalid;
    }
}

fn parseGeometry(value: std.json.ObjectMap) !Geometry {
    const width = try floatField(value, "width");
    const height = try floatField(value, "height");
    if (width <= 0 or height <= 0) return error.GeometryInvalid;
    return .{
        .x = try floatField(value, "x"),
        .y = try floatField(value, "y"),
        .width = width,
        .height = height,
    };
}

const Viewport = struct {
    state: ViewportState,
    edges: Edges,
};

fn parseViewport(value: ?std.json.Value) !Viewport {
    if (value == null) return .{ .state = .unknown, .edges = .{} };
    const object_value = try object(value.?);
    const state_bytes = try stringField(object_value, "state");
    const state: ViewportState = if (std.mem.eql(u8, state_bytes, "visible"))
        .visible
    else if (std.mem.eql(u8, state_bytes, "partial"))
        .partial
    else if (std.mem.eql(u8, state_bytes, "offscreen"))
        .offscreen
    else if (std.mem.eql(u8, state_bytes, "unknown"))
        .unknown
    else
        return error.ViewportInvalid;
    const edge_values = try array(try field(object_value, "edges"));
    if (edge_values.len > 4) return error.ViewportInvalid;
    var edges: Edges = .{};
    for (edge_values) |edge_value| {
        const edge = try string(edge_value);
        if (std.mem.eql(u8, edge, "left")) {
            if (edges.left) return error.ViewportInvalid;
            edges.left = true;
        } else if (std.mem.eql(u8, edge, "right")) {
            if (edges.right) return error.ViewportInvalid;
            edges.right = true;
        } else if (std.mem.eql(u8, edge, "top")) {
            if (edges.top) return error.ViewportInvalid;
            edges.top = true;
        } else if (std.mem.eql(u8, edge, "bottom")) {
            if (edges.bottom) return error.ViewportInvalid;
            edges.bottom = true;
        } else {
            return error.ViewportInvalid;
        }
    }
    switch (state) {
        .visible, .unknown => if (edges.any()) return error.ViewportInvalid,
        .partial, .offscreen => if (!edges.any()) return error.ViewportInvalid,
    }
    return .{ .state = state, .edges = edges };
}

fn parsePresentation(value: []const u8) !Presentation {
    if (std.mem.eql(u8, value, "presented")) return .presented;
    if (std.mem.eql(u8, value, "workspace-inactive")) return .workspace_inactive;
    if (std.mem.eql(u8, value, "occluded")) return .occluded;
    if (std.mem.eql(u8, value, "hidden")) return .hidden;
    if (std.mem.eql(u8, value, "unmapped")) return .unmapped;
    return error.PresentationInvalid;
}

fn windowLessThan(_: void, left: Window, right: Window) bool {
    if (left.active != right.active) return left.active;
    if (left.focus_rank != right.focus_rank) {
        if (left.focus_rank == null) return false;
        if (right.focus_rank == null) return true;
        return left.focus_rank.? < right.focus_rank.?;
    }
    if (left.workspace_id != null and right.workspace_id != null) {
        const order = std.mem.order(u8, left.workspace_id.?.slice(), right.workspace_id.?.slice());
        if (order != .eq) return order == .lt;
    } else if (left.workspace_id == null and right.workspace_id != null) {
        return false;
    } else if (left.workspace_id != null and right.workspace_id == null) {
        return true;
    }
    return spatialLessThan(&left, &right);
}

fn spatialLessThan(left: *const Window, right: *const Window) bool {
    if (left.geometry.x != right.geometry.x) return left.geometry.x < right.geometry.x;
    if (left.geometry.y != right.geometry.y) return left.geometry.y < right.geometry.y;
    if (left.geometry.width != right.geometry.width) return left.geometry.width < right.geometry.width;
    if (left.geometry.height != right.geometry.height) return left.geometry.height < right.geometry.height;
    return std.mem.lessThan(u8, left.stable_id.slice(), right.stable_id.slice());
}

fn field(object_value: std.json.ObjectMap, name: []const u8) !std.json.Value {
    return object_value.get(name) orelse error.WmioFieldMissing;
}

fn object(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |object_value| object_value,
        else => error.WmioFieldTypeInvalid,
    };
}

fn array(value: std.json.Value) ![]const std.json.Value {
    return switch (value) {
        .array => |array_value| array_value.items,
        else => error.WmioFieldTypeInvalid,
    };
}

fn string(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |string_value| string_value,
        else => error.WmioFieldTypeInvalid,
    };
}

fn stringField(object_value: std.json.ObjectMap, name: []const u8) ![]const u8 {
    return string(try field(object_value, name));
}

fn nullableStringField(object_value: std.json.ObjectMap, name: []const u8) !?[]const u8 {
    const value = object_value.get(name) orelse return error.WmioFieldMissing;
    return switch (value) {
        .null => null,
        .string => |string_value| string_value,
        else => error.WmioFieldTypeInvalid,
    };
}

fn booleanField(object_value: std.json.ObjectMap, name: []const u8) !bool {
    return switch (try field(object_value, name)) {
        .bool => |value| value,
        else => error.WmioFieldTypeInvalid,
    };
}

fn integerField(object_value: std.json.ObjectMap, name: []const u8) !i32 {
    return std.fmt.parseInt(i32, try numberField(object_value, name), 10) catch
        error.WmioIntegerInvalid;
}

fn floatField(object_value: std.json.ObjectMap, name: []const u8) !f64 {
    const value = std.fmt.parseFloat(f64, try numberField(object_value, name)) catch
        return error.WmioNumberInvalid;
    if (!std.math.isFinite(value)) return error.WmioNumberInvalid;
    return value;
}

fn nullableIntegerField(object_value: std.json.ObjectMap, name: []const u8) !?i64 {
    const value = object_value.get(name) orelse return error.WmioFieldMissing;
    return switch (value) {
        .null => null,
        .number_string => |bytes| std.fmt.parseInt(i64, bytes, 10) catch
            error.WmioIntegerInvalid,
        else => error.WmioFieldTypeInvalid,
    };
}

fn optionalNullableIntegerField(object_value: std.json.ObjectMap, name: []const u8) !?i64 {
    const value = object_value.get(name) orelse return null;
    return switch (value) {
        .null => null,
        .number_string => |bytes| std.fmt.parseInt(i64, bytes, 10) catch
            error.WmioIntegerInvalid,
        else => error.WmioFieldTypeInvalid,
    };
}

fn numberField(object_value: std.json.ObjectMap, name: []const u8) ![]const u8 {
    return switch (try field(object_value, name)) {
        .number_string => |value| value,
        else => error.WmioFieldTypeInvalid,
    };
}

fn containsString(values: []const std.json.Value, wanted: []const u8) !bool {
    var found = false;
    for (values) |value| {
        if (std.mem.eql(u8, try string(value), wanted)) found = true;
    }
    return found;
}

const desktop_fixture =
    \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{
    \\  "focus":{"monitor_id":"0","workspace_id":"1","window_id":"zen"},
    \\  "windows":[
    \\    {"stable_id":"zen","app_id":"zen","title":"Browser","pid":20,"mapped":true,"accepts_input":true,"active":false,"focus_rank":1,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":6,"y":4,"width":1910,"height":1072},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"tiled"},
    \\    {"stable_id":"kitty","app_id":"kitty","title":"Terminal","pid":10,"mapped":true,"accepts_input":true,"active":false,"focus_rank":2,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":-1910,"y":4,"width":1910,"height":1072},"viewport":{"state":"offscreen","edges":["left"]},"presentation":"occluded","mode":"tiled"},
    \\    {"stable_id":"other","app_id":"files","title":"Files","pid":30,"mapped":true,"accepts_input":true,"active":false,"focus_rank":3,"workspace_ids":["2"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":100,"height":100},"viewport":{"state":"unknown","edges":[]},"presentation":"workspace-inactive","mode":"floating"},
    \\    {"stable_id":"self","app_id":"wayspot","title":"wayspot","pid":99,"mapped":true,"accepts_input":true,"active":true,"focus_rank":0,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":720,"height":480},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"floating"},
    \\    {"stable_id":"overlay","app_id":"overlay","title":"Overlay","pid":40,"mapped":true,"accepts_input":false,"active":false,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":100,"height":100},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"floating"}
    \\  ]
    \\}}
;

const focus_fixture =
    \\{"schema":"wmio/v1","ok":true,"operation":"focus","data":{"stable_id":"kitty"}}
;

const Transcript = struct {
    desktop_bytes: []const u8 = desktop_fixture,
    focus_bytes: []const u8 = focus_fixture,
    succeed: bool = true,
    calls: usize = 0,
    expected_focus: ?[]const u8 = null,

    pub fn run(
        transcript: *Transcript,
        allocator: std.mem.Allocator,
        request: Request,
    ) !ProcessResult {
        transcript.calls += 1;
        const bytes = switch (request) {
            .desktop => transcript.desktop_bytes,
            .focus => |stable_id| blk: {
                const expected = transcript.expected_focus orelse return error.UnexpectedFocus;
                if (!std.mem.eql(u8, expected, stable_id)) return error.FocusTargetMismatch;
                break :blk transcript.focus_bytes;
            },
        };
        const stdout = try allocator.dupe(u8, bytes);
        errdefer allocator.free(stdout);
        return .{
            .stdout = stdout,
            .stderr = try allocator.dupe(u8, ""),
            .succeeded = transcript.succeed,
        };
    }
};

test "desktop model keeps global windows and orders them by recent focus" {
    const snapshot = try parseDesktop(std.testing.allocator, desktop_fixture, 99);
    try std.testing.expectEqual(@as(usize, 3), snapshot.count);
    try std.testing.expectEqualStrings("zen", snapshot.windows[0].stable_id.slice());
    try std.testing.expectEqual(@as(?u32, 1), snapshot.windows[0].focus_rank);
    try std.testing.expectEqual(.visible, snapshot.windows[0].viewport);
    try std.testing.expectEqualStrings("kitty", snapshot.windows[1].stable_id.slice());
    try std.testing.expectEqual(@as(?u32, 2), snapshot.windows[1].focus_rank);
    try std.testing.expectEqual(.offscreen, snapshot.windows[1].viewport);
    try std.testing.expect(snapshot.windows[1].edges.left);
    try std.testing.expectEqual(.occluded, snapshot.windows[1].presentation);
    try std.testing.expectEqualStrings("other", snapshot.windows[2].stable_id.slice());
    try std.testing.expectEqualStrings("2", snapshot.windows[2].workspace_id.?.slice());
    try std.testing.expectEqual(.workspace_inactive, snapshot.windows[2].presentation);
    try std.testing.expectEqual(@as(?usize, 0), snapshot.selected());
}

test "workspace position is spatial metadata and does not change MRU order" {
    const snapshot = try parseDesktop(std.testing.allocator, desktop_fixture, 99);
    try std.testing.expectEqualStrings("zen", snapshot.windows[0].stable_id.slice());
    try std.testing.expectEqualStrings("kitty", snapshot.windows[1].stable_id.slice());
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 2, .total = 2 }, snapshot.workspacePosition(0).?);
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 1, .total = 2 }, snapshot.workspacePosition(1).?);
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 1, .total = 1 }, snapshot.workspacePosition(2).?);
    try std.testing.expectEqual(@as(?WorkspacePosition, null), snapshot.workspacePosition(snapshot.count));
}

test "workspace position uses top-to-bottom and stable identity for equal x" {
    var snapshot: Snapshot = .{};
    const workspace = try WorkspaceId.exact("7");
    const base = Window{
        .stable_id = try StableId.exact("middle"),
        .app_id = try AppId.display("kitty"),
        .title = try Title.display("~"),
        .workspace_id = workspace,
        .monitor_id = null,
        .geometry = .{ .x = 100, .y = 20, .width = 50, .height = 50 },
        .viewport = .visible,
        .edges = .{},
        .presentation = .presented,
        .focus_rank = 0,
        .active = true,
        .floating = false,
        .fullscreen = false,
    };
    snapshot.windows[0] = base;
    snapshot.windows[1] = base;
    snapshot.windows[1].stable_id = try StableId.exact("top");
    snapshot.windows[1].geometry.y = 10;
    snapshot.windows[2] = base;
    snapshot.windows[2].stable_id = try StableId.exact("z-bottom");
    snapshot.windows[2].geometry.y = 20;
    snapshot.count = 3;
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 2, .total = 3 }, snapshot.workspacePosition(0).?);
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 1, .total = 3 }, snapshot.workspacePosition(1).?);
    try std.testing.expectEqual(WorkspacePosition{ .ordinal = 3, .total = 3 }, snapshot.workspacePosition(2).?);
}

test "window matches preserve MRU order and search app title or workspace" {
    const snapshot = try parseDesktop(std.testing.allocator, desktop_fixture, 99);
    const all = try Matches.init(&snapshot, "");
    try std.testing.expectEqualSlices(u16, &.{ 0, 1, 2 }, all.slice());
    const terminal = try Matches.init(&snapshot, "term");
    try std.testing.expectEqualSlices(u16, &.{1}, terminal.slice());
    const workspace = try Matches.init(&snapshot, "ws 2");
    try std.testing.expectEqualSlices(u16, &.{2}, workspace.slice());
    const title = try Matches.init(&snapshot, "browser");
    try std.testing.expectEqualSlices(u16, &.{0}, title.slice());
}

test "desktop model accepts an older WMIO snapshot without viewport metadata" {
    const bytes =
        \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{"focus":{"workspace_id":"1"},"windows":[
        \\{"stable_id":"a","app_id":"app","title":"App","pid":1,"mapped":true,"accepts_input":true,"active":true,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":1,"height":1},"presentation":"presented","mode":"tiled"}
        \\]}}
    ;
    const snapshot = try parseDesktop(std.testing.allocator, bytes, 2);
    try std.testing.expectEqual(@as(usize, 1), snapshot.count);
    try std.testing.expectEqual(.unknown, snapshot.windows[0].viewport);
}

test "desktop model accepts backend-neutral fractional geometry" {
    const bytes =
        \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{"focus":{"workspace_id":"1"},"windows":[
        \\{"stable_id":"a","app_id":"app","title":"App","pid":1,"mapped":true,"accepts_input":true,"active":true,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":1920.0,"y":0,"width":2258.823529411765,"height":1227.0588235294117},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"floating"}
        \\]}}
    ;
    const snapshot = try parseDesktop(std.testing.allocator, bytes, 2);
    try std.testing.expectEqual(@as(usize, 1), snapshot.count);
    try std.testing.expectEqual(@as(f64, 1920.0), snapshot.windows[0].geometry.x);
    try std.testing.expectApproxEqAbs(@as(f64, 2258.823529411765), snapshot.windows[0].geometry.width, 0.0000001);
}

test "desktop model rejects malformed viewport semantics without partial publication" {
    const malformed =
        \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{"focus":{"workspace_id":"1"},"windows":[
        \\{"stable_id":"a","app_id":"app","title":"App","pid":1,"mapped":true,"accepts_input":true,"active":true,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":1,"height":1},"viewport":{"state":"offscreen","edges":[]},"presentation":"occluded","mode":"tiled"}
        \\]}}
    ;
    try std.testing.expectError(
        error.ViewportInvalid,
        parseDesktop(std.testing.allocator, malformed, 2),
    );
}

test "desktop model rejects duplicate exact targets" {
    const duplicated =
        \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{"focus":{"workspace_id":"1"},"windows":[
        \\{"stable_id":"same","app_id":"one","title":"One","pid":1,"mapped":true,"accepts_input":true,"active":false,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":0,"y":0,"width":1,"height":1},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"tiled"},
        \\{"stable_id":"same","app_id":"two","title":"Two","pid":2,"mapped":true,"accepts_input":true,"active":false,"workspace_ids":["1"],"monitor_id":"0","geometry":{"x":1,"y":0,"width":1,"height":1},"viewport":{"state":"visible","edges":[]},"presentation":"presented","mode":"tiled"}
        \\]}}
    ;
    try std.testing.expectError(
        error.DuplicateStableId,
        parseDesktop(std.testing.allocator, duplicated, 99),
    );
}

test "desktop response bytes and window count are bounded" {
    const too_long = try std.testing.allocator.alloc(u8, response_capacity + 1);
    defer std.testing.allocator.free(too_long);
    @memset(too_long, ' ');
    try std.testing.expectError(
        error.WmioOutputTooLong,
        parseDesktop(std.testing.allocator, too_long, 1),
    );

    var many_json: [8192]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&many_json);
    try writer.writeAll(
        "{\"schema\":\"wmio/v1\",\"ok\":true,\"operation\":\"desktop\"," ++
            "\"data\":{\"focus\":{\"workspace_id\":\"1\"},\"windows\":[",
    );
    for (0..window_capacity + 1) |index| {
        if (index != 0) try writer.writeAll(",");
        try writer.writeAll("{}");
    }
    try writer.writeAll("]}}");
    try std.testing.expectError(
        error.TooManyWindows,
        parseDesktop(std.testing.allocator, writer.buffered(), 1),
    );
}

test "display text truncates on a UTF-8 boundary" {
    const input = "123456789" ++ "λ";
    const Tiny = FixedText(10);
    const value = try Tiny.display(input);
    try std.testing.expect(std.unicode.utf8ValidateSlice(value.slice()));
    try std.testing.expectEqualStrings("1234567…", value.slice());
}

test "requests are bounded public WMIO commands" {
    var storage: [4][]const u8 = undefined;
    const desktop = Request{ .desktop = {} };
    try std.testing.expectEqualSlices(
        []const u8,
        &.{ "wmio", "desktop" },
        desktop.arguments(&storage),
    );
    try std.testing.expectEqual(response_capacity, desktop.stdoutLimit());
    try std.testing.expectEqualSlices(
        []const u8,
        &.{ "wmio", "focus", "--stable-id", "abc" },
        (Request{ .focus = "abc" }).arguments(&storage),
    );
    try std.testing.expectEqual(action_response_capacity, (Request{ .focus = "abc" }).stdoutLimit());
    try std.testing.expect(process_timeout.raw.nanoseconds > 0);
    try std.testing.expect(error_response_capacity < response_capacity);
}

test "load and focus use one exact bounded operation each" {
    var transcript: Transcript = .{ .expected_focus = "kitty" };
    const snapshot = try load(&transcript, std.testing.allocator, 99);
    try std.testing.expectEqual(@as(usize, 3), snapshot.count);
    try focus(&transcript, std.testing.allocator, "kitty");
    try std.testing.expectEqual(@as(usize, 2), transcript.calls);
}

test "failed command and mismatched focus remain failures" {
    var rejected: Transcript = .{ .succeed = false };
    try std.testing.expectError(
        error.WmioRejected,
        load(&rejected, std.testing.allocator, 99),
    );
    var mismatch: Transcript = .{
        .expected_focus = "kitty",
        .focus_bytes =
        \\{"schema":"wmio/v1","ok":true,"operation":"focus","data":{"stable_id":"zen"}}
        ,
    };
    try std.testing.expectError(
        error.WmioFocusMismatch,
        focus(&mismatch, std.testing.allocator, "kitty"),
    );
}

test "empty desktop has an honest empty finder" {
    const bytes =
        \\{"schema":"wmio/v1","ok":true,"operation":"desktop","data":{"focus":{"workspace_id":null},"windows":[]}}
    ;
    const snapshot = try parseDesktop(std.testing.allocator, bytes, 1);
    try std.testing.expectEqual(@as(usize, 0), snapshot.count);
    try std.testing.expectEqual(@as(?usize, null), snapshot.selected());
    try std.testing.expectEqual(@as(usize, 0), (try Matches.init(&snapshot, "")).count);
}
