//! Hyprland owns bounded IPC parsing and fact publication; Source owns syscalls.

const std = @import("std");
const io = @import("hyprland_io");
const monitor_facts = @import("monitor.zig");
const workspace_facts = @import("workspace.zig");
const window_facts = @import("window.zig");
const state_facts = @import("state.zig");

/// max_hypr_response_bytes bounds one owned JSON response before parsing.
pub const max_hypr_response_bytes: usize = 1024 * 1024;
/// max_event_line_bytes bounds recognized socket2 data before its newline.
pub const max_event_line_bytes: usize = 1044;
/// event_read_bytes matches one bounded socket2 read.
pub const event_read_bytes: usize = io.max_event_chunk_bytes;

/// Connection stores the bounded Hyprland instance address parts.
pub const Connection = struct {
    /// runtime_dir is the caller-owned XDG runtime directory.
    runtime_dir: []const u8,
    /// signature is the caller-owned Hyprland instance signature.
    signature: []const u8,
};

/// FactEvent names env fact changes observed from socket2.
pub const FactEvent = enum {
    monitor_changed,
    workspace_changed,
    window_changed,
    stopped,
};

/// RequestError is the exact synchronous request and response error set.
pub const RequestError = error{
    HyprlandSocketPathInvalid,
    HyprlandSocketPathTooLong,
    HyprlandSocketOpenFailed,
    HyprlandSocketConnectFailed,
    HyprlandSocketWriteFailed,
    HyprlandSocketReadFailed,
    HyprlandSocketCloseFailed,
    HyprlandSocketNotLive,
    HyprlandResponseTooLarge,
    SignalInterrupted,
    SystemCallFailed,
    OutOfMemory,
};

/// EventStreamInitError is the exact event stream setup error set.
pub const EventStreamInitError = error{
    HyprlandSocketPathInvalid,
    HyprlandSocketPathTooLong,
    HyprlandSocketOpenFailed,
    HyprlandSocketConnectFailed,
    HyprlandSocketCloseFailed,
    HyprlandSocketNotLive,
    SystemCallFailed,
};

/// EventWaitError is the exact event wait and read error set.
pub const EventWaitError = error{
    HyprlandSocketReadFailed,
    HyprlandSocketNotLive,
    SignalInterrupted,
    SystemCallFailed,
    HyprlandSocketCloseFailed,
    HyprlandEventSocketClosed,
    HyprlandEventLineTooLong,
    HyprlandStopClosed,
};

/// MonitorQueryError is the exact monitor query and parse error set.
pub const MonitorQueryError = RequestError || error{
    InvalidMonitorJson,
    InvalidJsonNumber,
    InvalidMonitorName,
    InvalidMonitorSize,
    InvalidMonitorScale,
    TooManyCurrentActiveWorkspaces,
    TooManyMonitors,
};

/// FillStateError is the exact complete environment refresh error set.
pub const FillStateError = RequestError || error{
    InvalidMonitorJson,
    InvalidWorkspaceJson,
    InvalidWindowJson,
    InvalidJsonNumber,
    InvalidMonitorName,
    InvalidMonitorSize,
    InvalidMonitorScale,
    InvalidWorkspaceName,
    InvalidWindowClass,
    InvalidWindowTitle,
    InvalidWindowSize,
    TooManyCurrentActiveWorkspaces,
    TooManyWorkspaceMonitorRefs,
    TooManyWorkspaceWindowRefs,
    TooManyMonitors,
    TooManyWorkspaces,
    TooManyWindows,
};

/// queryMonitorsWith performs one typed monitor request through Source.
pub fn queryMonitorsWith(
    comptime Source: type,
    allocator: std.mem.Allocator,
    source: *Source,
    hypr: Connection,
) MonitorQueryError!monitor_facts.MonitorList {
    const response = try requestWith(Source, allocator, source, hypr, .monitors);
    defer allocator.free(response);
    return parseMonitors(allocator, response);
}

/// fillStateWith publishes no new environment snapshot until all three requests parse.
pub fn fillStateWith(
    comptime Source: type,
    allocator: std.mem.Allocator,
    source: *Source,
    hypr: Connection,
    env_state: *state_facts.EnvState,
) FillStateError!void {
    const monitors = try queryMonitorsWith(Source, allocator, source, hypr);
    const workspaces_response = try requestWith(Source, allocator, source, hypr, .workspaces);
    defer allocator.free(workspaces_response);
    const workspaces = try parseWorkspaces(allocator, workspaces_response);
    const windows_response = try requestWith(Source, allocator, source, hypr, .clients);
    defer allocator.free(windows_response);
    const windows = try parseWindows(allocator, windows_response);
    env_state.refreshFromHyprlandFacts(monitors, workspaces, windows);
}

/// requestWith opens, writes, reads, and closes one synchronous request.
pub fn requestWith(
    comptime Source: type,
    allocator: std.mem.Allocator,
    source: *Source,
    hypr: Connection,
    name: io.RequestName,
) RequestError![]u8 {
    const path = try socketPath(hypr, .request);
    const id = try source.socket(.request);
    var operation_error: ?RequestError = null;
    var response: ?[]u8 = null;

    source.connect(id, path) catch |err| {
        operation_error = err;
    };
    if (operation_error == null) {
        writeRequest(Source, source, id, io.RequestWrite.fromName(name)) catch |err| {
            operation_error = err;
        };
    }
    if (operation_error == null) {
        response = readResponse(Source, allocator, source, id) catch |err| response_failure: {
            operation_error = err;
            break :response_failure null;
        };
    }

    var close_error: ?io.SocketCloseError = null;
    source.close(id) catch |err| {
        close_error = err;
    };
    if (close_error) |err| {
        if (response) |bytes| allocator.free(bytes);
        return err;
    }
    if (operation_error) |err| return err;
    return response orelse error.HyprlandSocketReadFailed;
}

fn writeRequest(
    comptime Source: type,
    source: *Source,
    id: io.SocketId,
    request: io.RequestWrite,
) io.SocketWriteError!void {
    var offset: usize = 0;
    while (offset < request.len) {
        const count = source.write(id, request) catch |err| switch (err) {
            error.SignalInterrupted => continue,
            else => return err,
        };
        if (count == 0 or count > request.len - offset) return error.HyprlandSocketWriteFailed;
        offset += count;
    }
}

fn readResponse(
    comptime Source: type,
    allocator: std.mem.Allocator,
    source: *Source,
    id: io.SocketId,
) RequestError![]u8 {
    var response = std.ArrayList(u8).empty;
    errdefer response.deinit(allocator);
    while (true) {
        const read = source.readRequest(id) catch |err| switch (err) {
            error.SignalInterrupted => continue,
            else => return err,
        };
        switch (read) {
            .eof => return response.toOwnedSlice(allocator),
            .chunk => |chunk| {
                if (chunk.len == 0 or response.items.len > max_hypr_response_bytes - chunk.len) {
                    return error.HyprlandResponseTooLarge;
                }
                try response.appendSlice(allocator, chunk.bytes[0..chunk.len]);
            },
        }
    }
}

fn socketPath(hypr: Connection, kind: io.SocketKind) io.SocketPathError!io.SocketPath {
    var buffer: [256]u8 = undefined;
    const suffix = switch (kind) {
        .request => ".socket.sock",
        .event => ".socket2.sock",
    };
    const text = std.fmt.bufPrint(&buffer, "{s}/hypr/{s}/{s}", .{ hypr.runtime_dir, hypr.signature, suffix }) catch {
        return error.HyprlandSocketPathTooLong;
    };
    return io.SocketPath.init(text) catch |err| switch (err) {
        error.HyprlandSocketPathInvalid => error.HyprlandSocketPathInvalid,
        error.HyprlandSocketPathTooLong => error.HyprlandSocketPathTooLong,
    };
}

/// EventStream owns one socket2 local id and a bounded pending event line.
pub const EventStream = struct {
    /// socket is retired by Source.close during deinit.
    socket: io.SocketId = .{ .value = 0 },
    /// pending stores one partial event frame without its newline.
    pending: [max_event_line_bytes]u8 = undefined,
    /// pending_len is bounded by max_event_line_bytes.
    pending_len: usize = 0,
    /// pending_event collapses ready facts by monitor/workspace/window priority.
    pending_event: ?FactEvent = null,

    /// initWith opens and connects one typed event source.
    pub fn initWith(
        comptime Source: type,
        allocator: std.mem.Allocator,
        source: *Source,
        hypr: Connection,
    ) EventStreamInitError!EventStream {
        _ = allocator;
        const path = try socketPath(hypr, .event);
        const id = try source.socket(.event);
        source.connect(id, path) catch |err| {
            source.close(id) catch |close_err| return close_err;
            return err;
        };
        return .{ .socket = id };
    }

    /// deinit makes one close attempt and retires the local source id.
    pub fn deinit(self: *EventStream, comptime Source: type, source: *Source) io.SocketCloseError!void {
        if (self.socket.value == 0) return;
        const id = self.socket;
        self.socket = .{ .value = 0 };
        return source.close(id);
    }

    /// waitWith maps stop readiness before event readiness and reads one event.
    pub fn waitWith(
        self: *EventStream,
        comptime Source: type,
        source: *Source,
        stop: io.StopId,
    ) EventWaitError!FactEvent {
        while (true) {
            if (self.nextPendingEvent()) |event| return event;
            const result = source.poll(.{
                .event = self.socket,
                .stop = stop,
                .timeout = io.PollTimeout.infinite(),
            }) catch |err| switch (err) {
                error.SignalInterrupted => continue,
                else => return err,
            };
            switch (result.stop) {
                .readable => return .stopped,
                .readable_hangup, .closed => return error.HyprlandStopClosed,
                .failed => return error.SystemCallFailed,
                .idle => {},
            }
            switch (result.event orelse continue) {
                .readable, .readable_hangup => self.readAvailable(Source, source) catch |err| switch (err) {
                    error.SignalInterrupted => continue,
                    else => return err,
                },
                .closed => return error.HyprlandEventSocketClosed,
                .failed => return error.SystemCallFailed,
                .idle => {},
            }
        }
    }

    fn readAvailable(self: *EventStream, comptime Source: type, source: *Source) EventWaitError!void {
        const read = source.readEvent(self.socket) catch |err| switch (err) {
            error.SignalInterrupted => return error.SignalInterrupted,
            else => return err,
        };
        switch (read) {
            .eof => return error.HyprlandEventSocketClosed,
            .chunk => |chunk| try self.readAvailableFromBytes(chunk.bytes[0..chunk.len]),
        }
    }

    fn readAvailableFromBytes(self: *EventStream, bytes: []const u8) EventWaitError!void {
        for (bytes) |byte| {
            if (byte == '\n') {
                if (classifyEventLine(self.pending[0..self.pending_len])) |event| self.mergePendingEvent(event);
                self.pending_len = 0;
                continue;
            }
            if (self.pending_len >= max_event_line_bytes) {
                self.pending_len = 0;
                return error.HyprlandEventLineTooLong;
            }
            self.pending[self.pending_len] = byte;
            self.pending_len += 1;
        }
    }

    fn nextPendingEvent(self: *EventStream) ?FactEvent {
        const event = self.pending_event;
        self.pending_event = null;
        return event;
    }

    fn mergePendingEvent(self: *EventStream, event: FactEvent) void {
        const current = self.pending_event orelse {
            self.pending_event = event;
            return;
        };
        if (current == .monitor_changed or event == .monitor_changed) {
            self.pending_event = .monitor_changed;
        } else if (current == .workspace_changed or event == .workspace_changed) {
            self.pending_event = .workspace_changed;
        } else {
            self.pending_event = .window_changed;
        }
    }
};

/// classifyEventLine maps recognized socket2 lines to dumb fact-change events only.
pub fn classifyEventLine(line: []const u8) ?FactEvent {
    const marker = std.mem.indexOf(u8, line, ">>") orelse return null;
    const name = line[0..marker];
    if (eventNameIn(name, &.{
        "monitoradded",
        "monitoraddedv2",
        "monitorremoved",
        "monitorremovedv2",
    })) return .monitor_changed;
    if (eventNameIn(name, &.{
        "workspace",
        "workspacev2",
        "createworkspace",
        "createworkspacev2",
        "destroyworkspace",
        "destroyworkspacev2",
        "moveworkspace",
        "moveworkspacev2",
        "renameworkspace",
        "activespecial",
        "activespecialv2",
        "focusedmon",
        "focusedmonv2",
    })) return .workspace_changed;
    if (eventNameIn(name, &.{
        "activewindow",
        "activewindowv2",
        "openwindow",
        "closewindow",
        "movewindow",
        "movewindowv2",
        "windowtitle",
        "windowtitlev2",
    })) return .window_changed;
    return null;
}

fn eventNameIn(name: []const u8, comptime names: []const []const u8) bool {
    inline for (names) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

/// parseMonitors converts bounded Hyprland monitor JSON into plain facts.
pub fn parseMonitors(
    allocator: std.mem.Allocator,
    response: []const u8,
) MonitorQueryError!monitor_facts.MonitorList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidMonitorJson,
    };
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidMonitorJson;
    var list = monitor_facts.MonitorList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidMonitorJson;
        const id = try jsonI32(entry.object.get("id") orelse return error.InvalidMonitorJson);
        const name = jsonString(entry.object.get("name") orelse return error.InvalidMonitorJson) orelse
            return error.InvalidMonitorJson;
        const width = try jsonI32(entry.object.get("width") orelse return error.InvalidMonitorJson);
        const height = try jsonI32(entry.object.get("height") orelse return error.InvalidMonitorJson);
        var monitor = try monitor_facts.Monitor.init(
            .{ .value = id },
            name,
            try monitor_facts.MonitorSize.init(width, height),
        );
        if (entry.object.get("scale")) |scale_value| {
            monitor.scale = try monitor_facts.MonitorScale.init(try jsonF64(scale_value));
        }
        monitor.focused = jsonBool(entry.object.get("focused") orelse .{ .bool = false }) orelse
            return error.InvalidMonitorJson;
        if (entry.object.get("activeWorkspace")) |workspace_value| {
            if (workspace_value == .object) {
                if (workspace_value.object.get("id")) |workspace_id| {
                    try monitor.addCurrentActiveWorkspace(.{ .id = try jsonI32(workspace_id) });
                }
            }
        }
        try list.append(monitor);
    }
    return list;
}

/// parseWorkspaces converts bounded Hyprland workspace JSON into plain facts.
pub fn parseWorkspaces(
    allocator: std.mem.Allocator,
    response: []const u8,
) FillStateError!workspace_facts.WorkspaceList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidWorkspaceJson,
    };
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidWorkspaceJson;
    var list = workspace_facts.WorkspaceList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidWorkspaceJson;
        const id = try jsonI32(entry.object.get("id") orelse return error.InvalidWorkspaceJson);
        const name = jsonString(entry.object.get("name") orelse return error.InvalidWorkspaceJson) orelse
            return error.InvalidWorkspaceJson;
        var workspace = try workspace_facts.Workspace.init(.{ .value = id }, name);
        if (entry.object.get("monitorID")) |monitor_id| {
            try workspace.visible_on.append(.{ .id = try jsonI32(monitor_id) });
        }
        try list.append(workspace);
    }
    return list;
}

/// parseWindows converts bounded Hyprland client JSON into plain facts.
pub fn parseWindows(
    allocator: std.mem.Allocator,
    response: []const u8,
) FillStateError!window_facts.WindowList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidWindowJson,
    };
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidWindowJson;
    var list = window_facts.WindowList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidWindowJson;
        const address_text = jsonString(entry.object.get("address") orelse return error.InvalidWindowJson) orelse
            return error.InvalidWindowJson;
        const class = jsonString(entry.object.get("class") orelse return error.InvalidWindowJson) orelse
            return error.InvalidWindowJson;
        const title = jsonString(entry.object.get("title") orelse .{ .string = "" }) orelse
            return error.InvalidWindowJson;
        const size_value = entry.object.get("size") orelse return error.InvalidWindowJson;
        if (size_value != .array or size_value.array.items.len != 2) return error.InvalidWindowJson;
        const address = parseAddress(address_text) catch return error.InvalidWindowJson;
        var item = try window_facts.Window.init(
            .{ .value = address },
            class,
            title,
            try window_facts.WindowSize.init(
                try jsonI32(size_value.array.items[0]),
                try jsonI32(size_value.array.items[1]),
            ),
        );
        if (entry.object.get("workspace")) |workspace_value| {
            if (workspace_value == .object) {
                if (workspace_value.object.get("id")) |workspace_id| {
                    item.workspace = .{ .id = try jsonI32(workspace_id) };
                }
            }
        }
        item.visible = jsonBool(entry.object.get("mapped") orelse .{ .bool = true }) orelse
            return error.InvalidWindowJson;
        if (entry.object.get("focusHistoryID")) |focus_value| item.focused = try jsonI32(focus_value) == 0;
        try list.append(item);
    }
    return list;
}

fn parseAddress(text: []const u8) !u64 {
    const trimmed = if (std.mem.startsWith(u8, text, "0x")) text[2..] else text;
    return std.fmt.parseInt(u64, trimmed, 16);
}

fn jsonString(value: std.json.Value) ?[]const u8 {
    return switch (value) {
        .string => |text| text,
        else => null,
    };
}

fn jsonBool(value: std.json.Value) ?bool {
    return switch (value) {
        .bool => |flag| flag,
        else => null,
    };
}

fn jsonI32(value: std.json.Value) !i32 {
    return switch (value) {
        .integer => |number| std.math.cast(i32, number) orelse error.InvalidJsonNumber,
        .float => |number| if (std.math.isFinite(number) and
            number >= std.math.minInt(i32) and
            number <= std.math.maxInt(i32) and
            @trunc(number) == number)
            @intFromFloat(number)
        else
            error.InvalidJsonNumber,
        else => error.InvalidJsonNumber,
    };
}

fn jsonF64(value: std.json.Value) !f64 {
    return switch (value) {
        .integer => |number| @floatFromInt(number),
        .float => |number| number,
        else => error.InvalidJsonNumber,
    };
}

test "monitor JSON parser accepts current active refs" {
    const json =
        \\[
        \\  {"id":1,"name":"DP-1","width":1920,"height":1080,
        \\    "scale":1.0,"focused":true,"activeWorkspace":{"id":7,"name":"main"}}
        \\]
    ;
    const monitors = try parseMonitors(std.testing.allocator, json);
    try std.testing.expectEqual(@as(u32, 1), monitors.count);
    try std.testing.expectEqual(@as(i32, 1), monitors.items[0].id.value);
    try std.testing.expectEqualStrings("DP-1", monitors.items[0].nameText());
    try std.testing.expectEqual(@as(i32, 1920), monitors.items[0].size.width);
    try std.testing.expect(monitors.items[0].focused);
    try std.testing.expectEqual(@as(i32, 7), monitors.items[0].current_active.items[0].id);
}

test "focused monitor event classifier preserves priority vocabulary" {
    try std.testing.expectEqual(@as(?FactEvent, .monitor_changed), classifyEventLine("monitoradded>>DP-1"));
    try std.testing.expectEqual(@as(?FactEvent, .workspace_changed), classifyEventLine("focusedmonv2>>DP-1,1"));
    try std.testing.expectEqual(@as(?FactEvent, .window_changed), classifyEventLine("activewindowv2>>abc"));
    try std.testing.expectEqual(@as(?FactEvent, null), classifyEventLine("fullscreen>>1"));
}

test "pending event priority is monitor then workspace then window" {
    var stream = EventStream{};
    stream.mergePendingEvent(.window_changed);
    stream.mergePendingEvent(.workspace_changed);
    try std.testing.expectEqual(FactEvent.workspace_changed, stream.nextPendingEvent().?);
    stream.mergePendingEvent(.window_changed);
    stream.mergePendingEvent(.monitor_changed);
    try std.testing.expectEqual(FactEvent.monitor_changed, stream.nextPendingEvent().?);
}

test "socket2 pending parser keeps the 1044-byte recognized bound" {
    var stream = EventStream{};
    stream.pending_len = max_event_line_bytes;
    try std.testing.expectError(error.HyprlandEventLineTooLong, stream.readAvailableFromBytes("x"));
    stream.pending_len = 0;
    const line = "workspacev2>>7,main\n";
    try stream.readAvailableFromBytes(line);
    try std.testing.expectEqual(@as(?FactEvent, .workspace_changed), stream.nextPendingEvent());
}

test "socket2 parser accepts 1044 data bytes and rejects the next byte" {
    var stream = EventStream{};
    var exact: [max_event_line_bytes + 1]u8 = undefined;
    const prefix = "monitoradded>>";
    @memcpy(exact[0..prefix.len], prefix);
    @memset(exact[prefix.len..max_event_line_bytes], 'x');
    exact[max_event_line_bytes] = '\n';
    try stream.readAvailableFromBytes(&exact);
    try std.testing.expectEqual(@as(?FactEvent, .monitor_changed), stream.nextPendingEvent());

    var overlong: [max_event_line_bytes + 2]u8 = undefined;
    @memcpy(overlong[0..prefix.len], prefix);
    @memset(overlong[prefix.len..], 'x');
    try std.testing.expectError(error.HyprlandEventLineTooLong, stream.readAvailableFromBytes(&overlong));
}

test "JSON parser rejects extra window dimensions and unsafe numbers" {
    const extra = "[{\"address\":\"0x1\",\"class\":\"foot\",\"title\":\"\",\"size\":[1,2,3]}]";
    try std.testing.expectError(error.InvalidWindowJson, parseWindows(std.testing.allocator, extra));
    const unsafe = "[{\"id\":999999999999999999999999,\"name\":\"DP-1\",\"width\":1,\"height\":1}]";
    try std.testing.expectError(error.InvalidJsonNumber, parseMonitors(std.testing.allocator, unsafe));
}

test "JSON response bound accepts exact bytes before parsing and rejects one more" {
    const exact = try std.testing.allocator.alloc(u8, max_hypr_response_bytes);
    defer std.testing.allocator.free(exact);
    @memset(exact, ' ');
    exact[0] = '[';
    exact[1] = ']';
    const monitors = try parseMonitors(std.testing.allocator, exact);
    try std.testing.expectEqual(@as(u32, 0), monitors.count);

    const overlong = try std.testing.allocator.alloc(u8, max_hypr_response_bytes + 1);
    defer std.testing.allocator.free(overlong);
    try std.testing.expectError(error.HyprlandResponseTooLarge, parseMonitors(std.testing.allocator, overlong));
}

test "parser-byte fuzz remains bounded and publishes no external objects" {
    try std.testing.fuzz({}, fuzzParserBytes, .{});
}

fn fuzzParserBytes(_: void, smith: *std.testing.Smith) !void {
    var input: [max_event_line_bytes + 1]u8 = undefined;
    smith.bytes(&input);
    const length = smith.valueRangeAtMost(u16, 0, @intCast(input.len));
    _ = classifyEventLine(input[0..length]);
}
