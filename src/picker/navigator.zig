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

        /// Owns nonempty valid UTF-8 without truncating identity.
        pub fn exact(input: []const u8) !@This() {
            if (input.len == 0 or input.len > capacity or !std.unicode.utf8ValidateSlice(input) or
                std.mem.indexOfScalar(u8, input, 0) != null) return error.InvalidText;
            var text: @This() = .{ .len = @intCast(input.len) };
            @memcpy(text.bytes[0..input.len], input);
            return text;
        }

        /// Owns display text, truncating long values at a codepoint boundary.
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

        /// Borrows the admitted byte extent.
        pub fn slice(self: *const @This()) []const u8 {
            return self.bytes[0..self.len];
        }
    };
}

/// Exact compositor-native window identity, never a display label.
pub const StableId = Text(128);
/// Exact workspace identity reported by the selected compositor.
pub const WorkspaceId = Text(128);
/// Exact monitor identity when a window has an output.
pub const MonitorId = Text(128);
/// Bounded application identity text for matching and presentation.
pub const AppId = Text(192);
/// Bounded display title, truncated only at UTF-8 boundaries.
pub const Title = Text(384);
/// Compositor-reported logical window geometry.
pub const Geometry = struct { x: f64, y: f64, width: f64, height: f64 };
/// Observed viewport relationship, unknown without evidence.
pub const ViewportState = enum { visible, partial, offscreen, unknown };
/// Compositor scene participation, not proof of unobscured pixels.
pub const Presentation = enum { presented, workspace_inactive, occluded, hidden, unmapped, unknown };
/// Observed directions beyond the viewport.
pub const Edges = struct { left: bool = false, right: bool = false, top: bool = false, bottom: bool = false };

/// One owned window observation with exact native selection identity.
pub const Window = struct {
    stable_id: StableId,
    app_id: AppId,
    app_id_truncated: bool = false,
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

/// One-based spatial ordinal among windows of the same workspace.
pub const WorkspacePosition = struct { ordinal: u16, total: u16 };
/// One bounded, independently owned window-list observation.
pub const Snapshot = struct {
    windows: [max_windows]Window = undefined,
    count: usize = 0,

    /// Borrows only the admitted windows.
    pub fn slice(self: *const Snapshot) []const Window {
        return self.windows[0..self.count];
    }

    /// Computes spatial position without reordering the focus-sorted snapshot.
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

/// Indexes into the exact snapshot used for one query.
pub const Matches = struct {
    indexes: [max_windows]u16 = undefined,
    count: usize = 0,

    /// Filters current observations while retaining their original focus order.
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

    /// Borrows the exact indexes into the original snapshot.
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
/// Selects only an explicitly supported session identity.
pub fn backendForSession(desktop: ?[]const u8) ?Backend {
    const name = desktop orelse return null;
    if (std.mem.eql(u8, name, "Hyprland")) return .hyprland;
    if (std.mem.eql(u8, name, "Snowman")) return .snowman;
    return null;
}

fn discoveryArgv(backend: Backend) []const []const u8 {
    return switch (backend) {
        .hyprland => &.{ "hyprctl", "-j", "clients" },
        .snowman => &.{ "snowman", "window", "list", "--mapped" },
    };
}

fn observationArgv(backend: Backend) []const []const u8 {
    return switch (backend) {
        .hyprland => &.{ "hyprctl", "-j", "activewindow" },
        .snowman => &.{ "snowman", "seat", "get", "1" },
    };
}

fn hyprlandFocusArgv(id: []const u8, storage: *[3][]const u8, target: *[136]u8) ![]const []const u8 {
    try validAddress(id);
    // Hyprland 0.56+ dispatches Lua expressions, not legacy names.
    storage.* = .{
        "hyprctl",
        "dispatch",
        try std.fmt.bufPrint(target, "hl.dsp.focus({{ window = \"address:{s}\" }})", .{id}),
    };
    return storage;
}

/// Owns both bounded subprocess output allocations and its exit result.
pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    succeeded: bool,

    /// Retires both owned streams with the original allocator.
    pub fn deinit(self: *ProcessResult, allocator: Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
        self.* = undefined;
    }
};

/// Native subprocesses borrow the unmodified session environment captured
/// at process entry, never the GUI's process-local EGL specialization.
pub const Native = struct {
    io: std.Io,
    environ_map: ?*const std.process.Environ.Map,

    /// Runs one bounded native CLI request with the captured session environment.
    pub fn run(self: Native, allocator: Allocator, argv: []const []const u8, max_stdout: usize) !ProcessResult {
        const child = std.process.run(allocator, self.io, .{
            .argv = argv,
            .environ_map = self.environ_map,
            .stdout_limit = .limited(max_stdout),
            .stderr_limit = .limited(16 * 1024),
            .timeout = .{ .duration = .{ .raw = .fromSeconds(2), .clock = .awake } },
        }) catch |failure| return switch (failure) {
            error.FileNotFound => error.CompositorCliUnavailable,
            error.StreamTooLong => error.CompositorReplyTooLong,
            error.Timeout => error.CompositorCliTimedOut,
            error.OutOfMemory => error.OutOfMemory,
            error.Canceled => error.Canceled,
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
    }
};

/// Read current mapped windows only when the picker enters window mode.
// zig-audit: acknowledge anytype
// reason: Native subprocesses and strict command transcripts share the discovery contract.
pub fn load(operations: anytype, allocator: Allocator, backend: ?Backend, self_pid: i64) !Snapshot {
    switch (backend orelse return error.UnsupportedCompositor) {
        .snowman => {
            var windows = try operations.run(allocator, discoveryArgv(.snowman), max_action_reply);
            defer windows.deinit(allocator);
            if (!windows.succeeded) return error.CompositorCliRejected;
            var seat = try operations.run(allocator, observationArgv(.snowman), max_action_reply);
            defer seat.deinit(allocator);
            if (!seat.succeeded) return error.CompositorCliRejected;
            return parseSnowman(allocator, windows.stdout, seat.stdout);
        },
        .hyprland => {
            var result = try operations.run(allocator, discoveryArgv(.hyprland), max_reply);
            defer result.deinit(allocator);
            if (!result.succeeded) return error.CompositorCliRejected;
            return parseDesktop(allocator, result.stdout, self_pid);
        },
    }
}

/// Focus one exact native ID. Snowman must be called only after the picker
/// has retired its exclusive layer; its receipt includes both native foci.
// zig-audit: acknowledge anytype
// reason: Native subprocesses and strict command transcripts share the exact focus receipt contract.
pub fn focus(operations: anytype, allocator: Allocator, backend: ?Backend, id: []const u8) !void {
    if ((backend orelse return error.UnsupportedCompositor) == .snowman) {
        const selected = try numericId(id);
        var result = try operations.run(allocator, &.{ "snowman", "window", "focus", id }, max_action_reply);
        defer result.deinit(allocator);
        return verifySnowmanFocus(allocator, &result, selected);
    }
    var storage: [3][]const u8 = undefined;
    var target: [136]u8 = undefined;
    var result = try operations.run(allocator, try hyprlandFocusArgv(id, &storage, &target), max_action_reply);
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
    var observed = try operations.run(allocator, observationArgv(.hyprland), max_action_reply);
    defer observed.deinit(allocator);
    if (!observed.succeeded) return error.CompositorFocusUnverified;
    if (observed.stdout.len > max_action_reply) return error.CompositorReplyTooLong;
    var active = std.json.parseFromSlice(struct { address: []const u8 }, allocator, observed.stdout, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" }) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.CompositorReplyMalformed;
    defer active.deinit();
    try validAddress(active.value.address);
    if (!sameAddress(active.value.address, id)) {
        // Both values have passed validAddress. Keep the exact observation
        // for diagnosing physical focus races, without redispatching or
        // treating a different window as success.
        if (!@import("builtin").is_test) std.log.warn("Hyprland focus mismatch: requested={s} observed={s}", .{ id, active.value.address });
        return error.CompositorFocusMismatch;
    }
}

const snowman_schema = "snowman-command/v1";

fn numericId(value: []const u8) !u64 {
    if (value.len == 0 or value.len > 20 or value[0] == '0') return error.InvalidWindowId;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidWindowId;
    return std.fmt.parseInt(u64, value, 10) catch return error.InvalidWindowId;
}

const SnowId = enum(u64) {
    _,

    /// Parses a canonical nonzero JSON integer from the bounded reply.
    pub fn jsonParse(_: Allocator, source: *std.json.Scanner, _: std.json.ParseOptions) !SnowId {
        const bytes = switch (try source.next()) {
            .number => |value| value,
            else => return error.UnexpectedToken,
        };
        return @fromBackingInt(@intCast(numericId(bytes) catch return error.InvalidNumber));
    }
};

fn numericText(comptime Id: type, value: u64) !Id {
    if (value == 0) return error.InvalidWindowId;
    var buffer: [20]u8 = undefined;
    return Id.exact(try std.fmt.bufPrint(&buffer, "{d}", .{value}));
}

fn decodeSnowman(comptime Data: type, allocator: Allocator, bytes: []const u8, operation: []const u8) !std.json.Parsed(Data) {
    // The two reads are on-demand observations, not an atomic joint snapshot.
    // Each response still has to carry its own exact schema and operation.
    if (bytes.len > max_action_reply) return error.CompositorReplyTooLong;
    const parsed = std.json.parseFromSlice(Data, allocator, bytes, .{
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .@"error",
        .max_value_len = max_action_reply,
    }) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.CompositorReplyMalformed;
    errdefer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.schema, snowman_schema) or !parsed.value.ok or
        !std.mem.eql(u8, parsed.value.operation, operation)) return error.CompositorReplyMalformed;
    return parsed;
}

const SnowWindow = struct {
    id: SnowId,
    workspace_id: SnowId,
    output_id: ?SnowId,
    mapped: bool,
    app_id: []const u8,
    title: []const u8,
    geometry: Geometry,
    mode: enum { tiled, floating },
    fullscreen: bool,
    scene: struct { status: enum { unmapped, workspace_unpresented, layout_hidden, scene_disabled, scene_enabled, scene_unobserved } },
};
const SnowSeat = struct {
    id: SnowId,
    kind: enum { shared, private },
    focused_window: ?SnowId,
    recent_window_count: usize,
    recent_window_ids: []SnowId,
};

fn SnowReply(comptime Data: type) type {
    return struct { schema: []const u8, ok: bool, operation: []const u8, serial: u64, data: Data };
}

/// Snowman supplies canonical numeric IDs and logical focus history. Its
/// scene status is participation evidence, never proof of unobscured pixels.
pub fn parseSnowman(allocator: Allocator, windows: []const u8, seat: []const u8) !Snapshot {
    const views = try decodeSnowman(SnowReply([]SnowWindow), allocator, windows, "window_list");
    defer views.deinit();
    const observed = try decodeSnowman(SnowReply(SnowSeat), allocator, seat, "seat_get");
    defer observed.deinit();
    const history = observed.value.data;
    if (@backingInt(history.id) != 1 or history.kind != .shared or history.recent_window_count != history.recent_window_ids.len or
        history.recent_window_ids.len > 512) return error.CompositorReplyMalformed;
    for (history.recent_window_ids, 0..) |id, index| {
        if (std.mem.indexOfScalar(SnowId, history.recent_window_ids[0..index], id) != null) return error.CompositorReplyMalformed;
    }
    if (views.value.data.len > max_windows) return error.TooManyWindows;
    var snapshot: Snapshot = .{};
    for (views.value.data) |view| {
        if (!view.mapped or view.scene.status == .unmapped) return error.CompositorReplyMalformed;
        if (!std.math.isFinite(view.geometry.x) or !std.math.isFinite(view.geometry.y) or
            !std.math.isFinite(view.geometry.width) or !std.math.isFinite(view.geometry.height) or
            view.geometry.width < 0 or view.geometry.height < 0) return error.GeometryInvalid;
        const id = try numericText(StableId, @backingInt(view.id));
        for (snapshot.slice()) |existing| if (std.mem.eql(u8, existing.stable_id.slice(), id.slice())) return error.DuplicateStableId;
        const app_id = try AppId.display(view.app_id);
        snapshot.windows[snapshot.count] = .{
            .stable_id = id,
            .app_id = app_id,
            .app_id_truncated = app_id.len != view.app_id.len,
            .title = try Title.display(view.title),
            .workspace_id = try numericText(WorkspaceId, @backingInt(view.workspace_id)),
            .monitor_id = if (view.output_id) |output| try numericText(MonitorId, @backingInt(output)) else null,
            .geometry = view.geometry,
            .presentation = switch (view.scene.status) {
                .workspace_unpresented => .workspace_inactive,
                .layout_hidden, .scene_disabled => .hidden,
                .scene_enabled => .presented,
                .scene_unobserved => .unknown,
                .unmapped => return error.CompositorReplyMalformed,
            },
            .focus_rank = if (std.mem.indexOfScalar(SnowId, history.recent_window_ids, view.id)) |index| @intCast(index) else null,
            .active = history.focused_window == view.id,
            .floating = view.mode == .floating,
            .fullscreen = view.fullscreen,
        };
        snapshot.count += 1;
    }
    std.mem.sort(Window, snapshot.windows[0..snapshot.count], {}, windowLess);
    return snapshot;
}

const SnowFocusReceipt = struct {
    status: []const u8,
    window_id: ?SnowId,
    policy: []const u8,
    keyboard_focused: bool,
    pointer_focused: bool,
};

fn verifySnowmanFocus(allocator: Allocator, result: *const ProcessResult, id: u64) !void {
    if (!result.succeeded) {
        const Failure = struct { schema: []const u8, ok: bool, @"error": struct { code: []const u8 } };
        const parsed = std.json.parseFromSlice(Failure, allocator, result.stderr, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" }) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.CompositorFocusRejected;
        defer parsed.deinit();
        if (parsed.value.ok or !std.mem.eql(u8, parsed.value.schema, snowman_schema)) return error.CompositorFocusRejected;
        const code = parsed.value.@"error".code;
        if (std.mem.eql(u8, code, "locked")) return error.SnowmanFocusLocked;
        if (std.mem.eql(u8, code, "not_found") or std.mem.eql(u8, code, "not_mapped")) return error.SnowmanWindowGone;
        if (std.mem.eql(u8, code, "exclusive_layer")) return error.SnowmanExclusiveLayer;
        if (std.mem.eql(u8, code, "busy")) return error.SnowmanInputBusy;
        if (std.mem.eql(u8, code, "focus_incomplete")) return error.SnowmanFocusIncomplete;
        if (std.mem.eql(u8, code, "no_output")) return error.SnowmanNoOutput;
        if (std.mem.eql(u8, code, "input_unavailable")) return error.SnowmanInputUnavailable;
        return error.CompositorFocusRejected;
    }
    const parsed = try decodeSnowman(SnowReply(SnowFocusReceipt), allocator, result.stdout, "window_focus");
    defer parsed.deinit();
    const receipt = parsed.value.data;
    if (receipt.window_id != @as(SnowId, @fromBackingInt(@intCast(id))) or !receipt.keyboard_focused or !receipt.pointer_focused or
        !std.mem.eql(u8, receipt.status, "applied") or !std.mem.eql(u8, receipt.policy, "greedy")) return error.CompositorFocusMismatch;
    if (!@import("builtin").is_test) std.log.info("window focus applied id={d}", .{id});
}

/// Do not wait for notify-send's D-Bus reply on the resident's UI thread:
/// the same resident may own the notification service. The existing detached
/// launcher waits only for the short launch helper, not the notification.
// zig-audit: acknowledge anyerror
// reason: The outer picker action boundary reports exact native errors without narrowing them.
pub fn reportFailure(init: std.process.Init, failure: anyerror) void {
    const message: []const u8 = switch (failure) {
        error.SnowmanFocusLocked => "The selected window or workspace is locked.",
        error.SnowmanWindowGone => "The selected window no longer exists or is unmapped.",
        error.SnowmanExclusiveLayer => "An exclusive keyboard layer still owns focus.",
        error.SnowmanInputBusy => "An input grab is active.",
        error.SnowmanFocusIncomplete => "Snowman could not realize focus. The desktop state may have changed.",
        error.SnowmanNoOutput => "No output is available for focus.",
        error.SnowmanInputUnavailable => "The interaction pair is unavailable.",
        else => @errorName(failure),
    };
    std.log.warn("window selection failed: {s}", .{@errorName(failure)});
    var launch = @import("../apps/launch.zig").Detached{ .io = init.io, .environ_map = init.environ_map };
    launch.spawn(&.{ "notify-send", "--app-name=Wayspot", "--", "Window selection failed", message }, null) catch |err| std.log.warn("cannot launch focus failure notification: {s}", .{@errorName(err)});
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
pub fn parseDesktop(allocator: Allocator, bytes: []const u8, self_pid: i64) !Snapshot {
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
        }) catch |err| {
            if (err == error.OutOfMemory) return error.OutOfMemory;
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
        const app_id = try AppId.display(client.class);
        const window: Window = .{
            .stable_id = try StableId.exact(client.address),
            .app_id = app_id,
            .app_id_truncated = app_id.len != client.class.len,
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
            if (sameAddress(existing.stable_id.slice(), window.stable_id.slice())) return error.DuplicateStableId;
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
    if (std.mem.trimStart(u8, value[2..], "0").len == 0) return error.InvalidWindowAddress;
}

// Both inputs have already passed validAddress. Preserve native spelling
// for dispatch while comparing the hexadecimal identity, not its formatting.
fn sameAddress(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(
        std.mem.trimStart(u8, a[2..], "0"),
        std.mem.trimStart(u8, b[2..], "0"),
    );
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
    const snapshot = try parseDesktop(std.testing.allocator, fixture, 99);
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
    const snapshot = try parseDesktop(std.testing.allocator, payload, 42);
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
    try std.testing.expectError(error.CompositorReplyMalformed, parseDesktop(std.testing.allocator, payload, 42));
}

test "Hyprland mixed normal and special workspace clients include an absent numeric id" {
    const payload =
        \\[
        \\ {"address":"0x1","class":"howl","title":"Terminal","mapped":true,"hidden":false,"at":[1924,4],"size":[2392,1342],"workspace":{"address":"2","id":2,"type":"normal","name":"2"},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":0},
        \\ {"address":"0x2","class":"howl","title":"Scratch","mapped":true,"hidden":false,"at":[1924,4],"size":[2392,1342],"workspace":{"address":"special:magic","type":"special","name":"special:magic"},"monitor":0,"floating":false,"fullscreen":0,"focusHistoryID":1}
        \\]
    ;
    const snapshot = try parseDesktop(std.testing.allocator, payload, 99);
    try std.testing.expectEqual(@as(usize, 2), snapshot.count);
    try std.testing.expectEqualStrings("2", snapshot.windows[0].workspace_id.?.slice());
    try std.testing.expectEqualStrings("special:magic", snapshot.windows[1].workspace_id.?.slice());
    try std.testing.expectEqual(@as(usize, 1), (try Matches.init(&snapshot, "special:magic")).count);
    try std.testing.expectEqualSlices(u16, &.{1}, (try Matches.init(&snapshot, "ws special:magic")).slice());
}

// Verify the actual focus entrypoint's full argv and exact response, not a
// second command encoder that could diverge from production.
const FocusProbe = struct {
    const Step = struct {
        argv: []const []const u8,
        bytes: []const u8,
    };
    steps: []const Step,
    cursor: usize = 0,

    fn run(self: *FocusProbe, allocator: Allocator, argv: []const []const u8, max_stdout: usize) !ProcessResult {
        if (self.cursor >= self.steps.len) return error.FocusProbeUnexpected;
        const step = self.steps[self.cursor];
        self.cursor += 1;
        try std.testing.expectEqual(max_action_reply, max_stdout);
        try std.testing.expectEqual(step.argv.len, argv.len);
        for (step.argv, argv) |expected, actual| try std.testing.expectEqualStrings(expected, actual);
        const stdout = try allocator.dupe(u8, step.bytes);
        errdefer allocator.free(stdout);
        return .{ .stdout = stdout, .stderr = try allocator.dupe(u8, ""), .succeeded = true };
    }
};

test "Snowman native commands preserve canonical numeric identity" {
    const list = discoveryArgv(.snowman);
    try std.testing.expectEqualStrings("--mapped", list[3]);
    try std.testing.expectEqual(std.math.maxInt(u64), try numericId("18446744073709551615"));
    var probe: FocusProbe = .{ .steps = &.{.{
        .argv = &.{ "snowman", "window", "focus", "18446744073709551615" },
        .bytes = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{\"status\":\"applied\",\"window_id\":18446744073709551615,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true}}",
    }} };
    try focus(&probe, std.testing.allocator, .snowman, "18446744073709551615");
    try std.testing.expectEqual(probe.steps.len, probe.cursor);
    try std.testing.expectError(error.InvalidWindowId, focus(&probe, std.testing.allocator, .snowman, "01"));
    try std.testing.expectEqual(probe.steps.len, probe.cursor);
    try std.testing.expectError(error.InvalidWindowId, numericId("0"));
    try std.testing.expectError(error.InvalidWindowId, numericId("01"));
    try std.testing.expectError(error.InvalidWindowId, numericId("--sticky"));
    try std.testing.expectError(error.InvalidWindowId, numericId("18446744073709551616"));
}

test "bad native data and duplicate exact targets are rejected" {
    try std.testing.expectError(error.CompositorReplyMalformed, parseDesktop(std.testing.allocator, "{}", 1));
    const duplicated =
        \\[
        \\ {"address":"0x1","class":"one","title":"One","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0},
        \\ {"address":"0x1","class":"two","title":"Two","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0}
        \\]
    ;
    try std.testing.expectError(error.DuplicateStableId, parseDesktop(std.testing.allocator, duplicated, 1));
    var storage: [3][]const u8 = undefined;
    var target: [136]u8 = undefined;
    const focus_args = try hyprlandFocusArgv("0xAbC123", &storage, &target);
    try std.testing.expectEqual(@as(usize, 3), focus_args.len);
    try std.testing.expectEqualStrings("hyprctl", focus_args[0]);
    try std.testing.expectEqualStrings("dispatch", focus_args[1]);
    try std.testing.expectEqualStrings("hl.dsp.focus({ window = \"address:0xAbC123\" })", focus_args[2]);
    try std.testing.expectError(error.InvalidWindowAddress, hyprlandFocusArgv("class:any", &storage, &target));
}

const snowman_fixture =
    \\{"schema":"snowman-command/v1","ok":true,"operation":"window_list","serial":10,"data":[
    \\{"id":41,"workspace_id":1,"output_id":1,"mapped":true,"app_id":"app","title":"Visible","geometry":{"x":0,"y":0,"width":400,"height":300},"mode":"tiled","fullscreen":false,"scene":{"status":"scene_enabled"}},
    \\{"id":42,"workspace_id":1,"output_id":1,"mapped":true,"app_id":"app","title":"Hidden tile","geometry":{"x":0,"y":0,"width":400,"height":300},"mode":"tiled","fullscreen":false,"scene":{"status":"layout_hidden"}},
    \\{"id":43,"workspace_id":3,"output_id":null,"mapped":true,"app_id":"app","title":"Other workspace","geometry":{"x":0,"y":0,"width":400,"height":300},"mode":"floating","fullscreen":true,"scene":{"status":"workspace_unpresented"}}]}
;
const snowman_history =
    \\{"schema":"snowman-command/v1","ok":true,"operation":"seat_get","serial":11,"data":{"id":1,"kind":"shared","focused_window":41,"recent_window_count":3,"recent_window_ids":[41,43,42]}}
;

test "Snowman discovery uses seat MRU and keeps hidden and unpresented windows" {
    const snapshot = try parseSnowman(std.testing.allocator, snowman_fixture, snowman_history);
    try std.testing.expectEqual(@as(usize, 3), snapshot.count);
    try std.testing.expectEqualStrings("41", snapshot.windows[0].stable_id.slice());
    try std.testing.expect(snapshot.windows[0].active);
    try std.testing.expectEqualStrings("43", snapshot.windows[1].stable_id.slice());
    try std.testing.expectEqual(Presentation.workspace_inactive, snapshot.windows[1].presentation);
    try std.testing.expect(snapshot.windows[1].monitor_id == null and snapshot.windows[1].fullscreen and snapshot.windows[1].floating);
    try std.testing.expectEqual(Presentation.hidden, snapshot.windows[2].presentation);
    try std.testing.expectEqual(ViewportState.unknown, snapshot.windows[0].viewport);
    try std.testing.expectError(error.CompositorReplyMalformed, parseSnowman(std.testing.allocator, "[]", snowman_history));
    try std.testing.expectError(error.CompositorReplyMalformed, parseSnowman(std.testing.allocator, snowman_fixture, "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"seat_get\",\"serial\":1,\"data\":{\"id\":1,\"kind\":\"private\",\"focused_window\":null,\"recent_window_count\":0,\"recent_window_ids\":[]}}"));
}

test "Snowman focus receipt must name the exact window and both native foci" {
    const cases = [_]struct { bytes: []const u8, failure: ?error{CompositorFocusMismatch} }{
        .{ .bytes = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{\"status\":\"applied\",\"window_id\":42,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true}}", .failure = null },
        .{ .bytes = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{\"status\":\"applied\",\"window_id\":43,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true}}", .failure = error.CompositorFocusMismatch },
        .{ .bytes = "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{\"status\":\"applied\",\"window_id\":42,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":false}}", .failure = error.CompositorFocusMismatch },
    };
    for (cases) |case| {
        const bytes = try std.testing.allocator.dupe(u8, case.bytes);
        defer std.testing.allocator.free(bytes);
        const result: ProcessResult = .{ .stdout = bytes, .stderr = &.{}, .succeeded = true };
        const verified = verifySnowmanFocus(std.testing.allocator, &result, 42);
        if (case.failure) |failure| try std.testing.expectError(failure, verified) else try verified;
    }
}

test "Hyprland duplicate hexadecimal identities are rejected regardless of spelling" {
    const payload =
        \\[
        \\ {"address":"0xAbC","class":"one","title":"One","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0},
        \\ {"address":"0x000abc","class":"two","title":"Two","mapped":true,"at":[0,0],"size":[100,100],"workspace":{"id":1},"monitor":0,"floating":false,"fullscreen":0}
        \\]
    ;
    try std.testing.expectError(error.DuplicateStableId, parseDesktop(std.testing.allocator, payload, 99));
}

test "Snowman focus receipt does not coerce a quoted or floating window identity" {
    for ([_][]const u8{ "\"42\"", "42.0", "4.2e1", "42.000000000000000000000000000000000001" }) |identity| {
        const bytes = try std.fmt.allocPrint(std.testing.allocator, "{{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{{\"status\":\"applied\",\"window_id\":{s},\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true}}}}", .{identity});
        defer std.testing.allocator.free(bytes);
        var result: ProcessResult = .{ .stdout = bytes, .stderr = &.{}, .succeeded = true };
        try std.testing.expectError(error.CompositorReplyMalformed, verifySnowmanFocus(std.testing.allocator, &result, 42));
    }
}

test "Hyprland focus observation compares the hexadecimal identity without redispatch" {
    const dispatch: FocusProbe.Step = .{
        .argv = &.{ "hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0xAbC\" })" },
        .bytes = "ok\n",
    };
    for ([_]struct { address: []const u8, matches: bool }{
        .{ .address = "0x000abc", .matches = true },
        .{ .address = "0x000abd", .matches = false },
    }) |case| {
        const observed = try std.fmt.allocPrint(std.testing.allocator, "{{\"address\":\"{s}\"}}", .{case.address});
        defer std.testing.allocator.free(observed);
        var probe: FocusProbe = .{ .steps = &.{ dispatch, .{
            .argv = &.{ "hyprctl", "-j", "activewindow" },
            .bytes = observed,
        } } };
        if (case.matches) {
            try focus(&probe, std.testing.allocator, .hyprland, "0xAbC");
        } else {
            try std.testing.expectError(error.CompositorFocusMismatch, focus(&probe, std.testing.allocator, .hyprland, "0xAbC"));
        }
        try std.testing.expectEqual(probe.steps.len, probe.cursor);
    }
    var no_dispatch: FocusProbe = .{ .steps = &.{} };
    try std.testing.expectError(error.InvalidWindowAddress, focus(&no_dispatch, std.testing.allocator, .hyprland, "0x0000"));
    try std.testing.expectEqual(@as(usize, 0), no_dispatch.cursor);
}

test "Snowman discovery refuses coercible native identities in either reply" {
    const a = std.testing.allocator;
    const mutations = [_]struct { from: []const u8, to: []const u8, seat: bool = false }{
        .{ .from = "\"id\":41", .to = "\"id\":\"41\"" },
        .{ .from = "\"workspace_id\":1", .to = "\"workspace_id\":1.0" },
        .{ .from = "\"output_id\":1", .to = "\"output_id\":1e0" },
        .{ .from = "\"id\":1,", .to = "\"id\":\"1\",", .seat = true },
        .{ .from = "\"focused_window\":41", .to = "\"focused_window\":41.0", .seat = true },
        .{ .from = "[41,43,42]", .to = "[41,43,\"42\"]", .seat = true },
    };
    for (mutations) |mutation| {
        const original = if (mutation.seat) snowman_history else snowman_fixture;
        const changed = try std.mem.replaceOwned(u8, a, original, mutation.from, mutation.to);
        defer a.free(changed);
        try std.testing.expect(!std.mem.eql(u8, original, changed));
        try std.testing.expectError(error.CompositorReplyMalformed, parseSnowman(
            a,
            if (mutation.seat) snowman_fixture else changed,
            if (mutation.seat) changed else snowman_history,
        ));
    }
}

fn allocationWitness(allocator: Allocator) !void {
    const snapshot = try parseSnowman(allocator, snowman_fixture, snowman_history);
    try std.testing.expectEqual(@as(usize, 3), snapshot.count);
    const receipt = try allocator.dupe(u8, "{\"schema\":\"snowman-command/v1\",\"ok\":true,\"operation\":\"window_focus\",\"serial\":2,\"data\":{\"status\":\"applied\",\"window_id\":42,\"policy\":\"greedy\",\"keyboard_focused\":true,\"pointer_focused\":true}}");
    defer allocator.free(receipt);
    const result: ProcessResult = .{ .stdout = receipt, .stderr = &.{}, .succeeded = true };
    try verifySnowmanFocus(allocator, &result, 42);
}

test "navigator allocation failure publishes no partial snapshot or successful receipt" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationWitness, .{});
}
