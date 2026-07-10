//! Hyprland owns bounded IPC parsing only to fill dumb env facts.

const std = @import("std");
const monitor_facts = @import("monitor.zig");
const workspace_facts = @import("workspace.zig");
const window_facts = @import("window.zig");
const state_facts = @import("state.zig");

pub const max_hypr_response_bytes: u32 = 1024 * 1024;
const socket_path_bytes: u32 = 160;
const max_event_line_bytes: u32 = 512;
const event_read_bytes: u32 = 1024;

/// Connection stores the bounded Hyprland instance address parts.
pub const Connection = struct {
    runtime_dir: []const u8,
    signature: []const u8,
};

/// FactEvent names env fact changes observed from socket2.
pub const FactEvent = enum {
    monitor_changed,
    workspace_changed,
    window_changed,
    stopped,
};

/// queryMonitors loads monitor facts with one bounded Hyprland request.
pub fn queryMonitors(allocator: std.mem.Allocator, hypr: Connection) !monitor_facts.MonitorList {
    const response = try request(allocator, hypr, "j/monitors");
    defer allocator.free(response);
    return parseMonitors(allocator, response);
}

/// fillState replaces env state from bounded Hyprland fact requests.
pub fn fillState(allocator: std.mem.Allocator, hypr: Connection, env_state: *state_facts.EnvState) !void {
    const monitors = try queryMonitors(allocator, hypr);
    const workspaces_response = try request(allocator, hypr, "j/workspaces");
    defer allocator.free(workspaces_response);
    const workspaces = try parseWorkspaces(allocator, workspaces_response);
    const windows_response = try request(allocator, hypr, "j/clients");
    defer allocator.free(windows_response);
    const windows = try parseWindows(allocator, windows_response);
    env_state.refreshFromHyprlandFacts(monitors, workspaces, windows);
}

/// EventStream owns one socket2 connection and a bounded pending line buffer.
pub const EventStream = struct {
    fd: std.posix.fd_t = -1,
    pending: [max_event_line_bytes]u8 = undefined,
    pending_len: u32 = 0,
    pending_event: ?FactEvent = null,

    /// init opens the Hyprland event socket; caller must deinit.
    pub fn init(allocator: std.mem.Allocator, hypr: Connection) !EventStream {
        const socket_path = try std.fmt.allocPrint(allocator, "{s}/hypr/{s}/.socket2.sock", .{ hypr.runtime_dir, hypr.signature });
        defer allocator.free(socket_path);
        return .{ .fd = try connectRequestSocket(socket_path) };
    }

    /// deinit closes the retained socket once.
    pub fn deinit(self: *EventStream) void {
        if (self.fd != -1) {
            closeFd(self.fd);
            self.fd = -1;
        }
    }

    /// wait returns the next fact-change event or the caller stop signal.
    pub fn wait(self: *EventStream, stop_fd: std.posix.fd_t) !FactEvent {
        while (true) {
            if (self.nextPendingEvent()) |event| return event;
            var poll_fds = [_]std.posix.pollfd{
                .{ .fd = self.fd, .events = std.posix.POLL.IN, .revents = 0 },
                .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
            };
            const ready = pollFdSet(&poll_fds, -1) catch |err| switch (err) {
                error.SignalInterrupted => continue,
                else => return err,
            };
            if (ready == 0) continue;
            if ((poll_fds[1].revents & std.posix.POLL.IN) != 0) return .stopped;
            if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) continue;
            try self.readAvailable();
        }
    }

    fn readAvailable(self: *EventStream) !void {
        var buf: [event_read_bytes]u8 = undefined;
        const read_count = readFd(self.fd, &buf) catch |err| switch (err) {
            error.SignalInterrupted => return,
            else => return err,
        };
        if (read_count == 0) return error.HyprlandEventSocketClosed;
        try self.readAvailableFromBytes(buf[0..read_count]);
    }

    fn readAvailableFromBytes(self: *EventStream, bytes: []const u8) !void {
        var index: u32 = 0;
        while (index < bytes.len) : (index += 1) {
            if (bytes[index] == '\n') {
                if (classifyEventLine(self.pending[0..self.pending_len])) |event| {
                    self.mergePendingEvent(event);
                }
                self.pending_len = 0;
                continue;
            }
            if (self.pending_len >= max_event_line_bytes) {
                self.pending_len = 0;
                return error.HyprlandEventLineTooLong;
            }
            self.pending[self.pending_len] = bytes[index];
            self.pending_len += 1;
        }
    }

    fn nextPendingEvent(self: *EventStream) ?FactEvent {
        if (self.pending_event) |event| {
            self.pending_event = null;
            return event;
        }
        while (true) {
            var newline_index: u32 = 0;
            while (newline_index < self.pending_len) : (newline_index += 1) {
                if (self.pending[newline_index] != '\n') continue;
                const line = self.pending[0..newline_index];
                const remaining_start = newline_index + 1;
                const remaining_len = self.pending_len - remaining_start;
                if (remaining_len > 0) {
                    std.mem.copyForwards(u8, self.pending[0..remaining_len], self.pending[remaining_start..self.pending_len]);
                }
                self.pending_len = remaining_len;
                if (classifyEventLine(line)) |event| return event;
                break;
            }
            if (newline_index >= self.pending_len) return null;
        }
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

/// request opens, writes, reads, and closes one synchronous Hyprland request.
pub fn request(allocator: std.mem.Allocator, hypr: Connection, command: []const u8) ![]u8 {
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/hypr/{s}/.socket.sock", .{ hypr.runtime_dir, hypr.signature });
    defer allocator.free(socket_path);
    const fd = try connectRequestSocket(socket_path);
    defer closeFd(fd);
    try writeAll(fd, command);
    return readBounded(allocator, fd);
}

/// classifyEventLine maps socket2 lines to dumb fact-change events only.
pub fn classifyEventLine(line: []const u8) ?FactEvent {
    const marker = std.mem.indexOf(u8, line, ">>") orelse return null;
    const name = line[0..marker];
    if (eventNameIn(name, &.{ "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "focusedmon", "focusedmonv2" })) return .monitor_changed;
    if (eventNameIn(name, &.{ "workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "renameworkspace", "activespecial", "activespecialv2" })) return .workspace_changed;
    if (eventNameIn(name, &.{ "activewindow", "activewindowv2", "openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2" })) return .window_changed;
    return null;
}

fn eventNameIn(name: []const u8, comptime names: []const []const u8) bool {
    inline for (names) |candidate| {
        if (std.mem.eql(u8, name, candidate)) return true;
    }
    return false;
}

/// parseMonitors converts Hyprland monitor JSON into bounded monitor facts.
pub fn parseMonitors(allocator: std.mem.Allocator, response: []const u8) !monitor_facts.MonitorList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidMonitorJson;
    var list = monitor_facts.MonitorList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidMonitorJson;
        const id = try jsonI32(entry.object.get("id") orelse return error.InvalidMonitorJson);
        const name = jsonString(entry.object.get("name") orelse return error.InvalidMonitorJson) orelse return error.InvalidMonitorJson;
        const width = try jsonI32(entry.object.get("width") orelse return error.InvalidMonitorJson);
        const height = try jsonI32(entry.object.get("height") orelse return error.InvalidMonitorJson);
        var monitor = try monitor_facts.Monitor.init(.{ .value = id }, name, try monitor_facts.MonitorSize.init(width, height));
        if (entry.object.get("scale")) |scale_value| monitor.scale = try monitor_facts.MonitorScale.init(try jsonF64(scale_value));
        monitor.focused = jsonBool(entry.object.get("focused") orelse std.json.Value{ .bool = false }) orelse return error.InvalidMonitorJson;
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

fn focusedMonitorName(monitors: monitor_facts.MonitorList) ?[]const u8 {
    var index: u32 = 0;
    while (index < monitors.count) : (index += 1) {
        if (monitors.items[index].focused) return monitors.items[index].nameText();
    }
    return null;
}

/// parseWorkspaces converts Hyprland workspace JSON into bounded workspace facts.
/// Hyprland's workspace response exposes a window count, not window identities,
/// so workspace window refs stay empty until a source provides concrete refs.
pub fn parseWorkspaces(allocator: std.mem.Allocator, response: []const u8) !workspace_facts.WorkspaceList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidWorkspaceJson;
    var list = workspace_facts.WorkspaceList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidWorkspaceJson;
        const id = try jsonI32(entry.object.get("id") orelse return error.InvalidWorkspaceJson);
        const name = jsonString(entry.object.get("name") orelse return error.InvalidWorkspaceJson) orelse return error.InvalidWorkspaceJson;
        var workspace = try workspace_facts.Workspace.init(.{ .value = id }, name);
        if (entry.object.get("monitorID")) |monitor_id| try workspace.visible_on.append(.{ .id = try jsonI32(monitor_id) });
        try list.append(workspace);
    }
    return list;
}

/// parseWindows converts Hyprland client JSON into bounded window facts.
pub fn parseWindows(allocator: std.mem.Allocator, response: []const u8) !window_facts.WindowList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidWindowJson;
    var list = window_facts.WindowList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidWindowJson;
        const address_text = jsonString(entry.object.get("address") orelse return error.InvalidWindowJson) orelse return error.InvalidWindowJson;
        const class = jsonString(entry.object.get("class") orelse return error.InvalidWindowJson) orelse return error.InvalidWindowJson;
        const title = jsonString(entry.object.get("title") orelse std.json.Value{ .string = "" }) orelse return error.InvalidWindowJson;
        const size_value = entry.object.get("size") orelse return error.InvalidWindowJson;
        if (size_value != .array or size_value.array.items.len < 2) return error.InvalidWindowJson;
        const address = parseAddress(address_text) catch return error.InvalidWindowJson;
        var item = try window_facts.Window.init(
            .{ .value = address },
            class,
            title,
            try window_facts.WindowSize.init(try jsonI32(size_value.array.items[0]), try jsonI32(size_value.array.items[1])),
        );
        if (entry.object.get("workspace")) |workspace_value| {
            if (workspace_value == .object) {
                if (workspace_value.object.get("id")) |workspace_id| item.workspace = .{ .id = try jsonI32(workspace_id) };
            }
        }
        item.visible = jsonBool(entry.object.get("mapped") orelse std.json.Value{ .bool = true }) orelse return error.InvalidWindowJson;
        if (entry.object.get("focusHistoryID")) |focus_value| {
            item.focused = try jsonI32(focus_value) == 0;
        }
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
        .integer => |int_value| @intCast(int_value),
        .float => |float_value| @intFromFloat(float_value),
        else => error.InvalidJsonNumber,
    };
}

fn jsonF64(value: std.json.Value) !f64 {
    return switch (value) {
        .integer => |int_value| @floatFromInt(int_value),
        .float => |float_value| float_value,
        else => error.InvalidJsonNumber,
    };
}

fn connectRequestSocket(socket_path: []const u8) !i32 {
    if (socket_path.len >= socket_path_bytes) return error.HyprlandSocketPathTooLong;
    const raw_fd = std.os.linux.socket(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC, 0);
    switch (std.os.linux.errno(raw_fd)) {
        .SUCCESS => {},
        else => return error.HyprlandSocketOpenFailed,
    }
    const fd: i32 = @intCast(raw_fd);
    errdefer closeFd(fd);
    var addr = std.os.linux.sockaddr.un{ .family = std.os.linux.AF.UNIX, .path = [_]u8{0} ** 108 };
    @memcpy(addr.path[0..socket_path.len], socket_path);
    const addr_len: std.os.linux.socklen_t = @intCast(@offsetOf(std.os.linux.sockaddr.un, "path") + socket_path.len + 1);
    const rc = std.os.linux.connect(fd, &addr, addr_len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => fd,
        else => error.HyprlandSocketConnectFailed,
    };
}

fn writeAll(fd: i32, bytes: []const u8) !void {
    var offset: u32 = 0;
    while (offset < bytes.len) {
        const chunk = bytes[offset..];
        const written = std.os.linux.write(fd, chunk.ptr, chunk.len);
        switch (std.os.linux.errno(written)) {
            .SUCCESS => {
                if (written == 0) return error.HyprlandSocketWriteFailed;
                offset += @intCast(written);
            },
            .INTR => {},
            else => return error.HyprlandSocketWriteFailed,
        }
    }
}

fn readBounded(allocator: std.mem.Allocator, fd: i32) ![]u8 {
    var response = std.ArrayList(u8).empty;
    errdefer response.deinit(allocator);
    var buf: [4096]u8 = undefined;
    while (true) {
        const read_count = std.os.linux.read(fd, &buf, buf.len);
        switch (std.os.linux.errno(read_count)) {
            .SUCCESS => {
                if (read_count == 0) return response.toOwnedSlice(allocator);
                if (response.items.len + read_count > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
                try response.appendSlice(allocator, buf[0..read_count]);
            },
            .INTR => {},
            else => return error.HyprlandSocketReadFailed,
        }
    }
}

fn closeFd(fd: i32) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) {
        std.log.debug("hyprland request socket close failed fd={d}", .{fd});
    }
}

fn pollFdSet(fds: []std.posix.pollfd, timeout_ms: i32) !u32 {
    const rc = std.os.linux.poll(fds.ptr, @intCast(fds.len), timeout_ms);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .INTR => error.SignalInterrupted,
        else => error.SystemCallFailed,
    };
}

fn readFd(fd: std.posix.fd_t, buf: []u8) !u32 {
    const rc = std.os.linux.read(fd, buf.ptr, buf.len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .INTR => error.SignalInterrupted,
        else => error.SystemCallFailed,
    };
}

test "monitor JSON parser accepts current active refs" {
    const json =
        \\[
        \\  {"id":1,"name":"DP-1","width":1920,"height":1080,"scale":1.0,"focused":true,"activeWorkspace":{"id":7,"name":"main"}}
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

test "focused monitor lookup uses monitor facts only" {
    const json =
        \\[
        \\  {"id":1,"name":"DP-1","width":1920,"height":1080,"focused":false},
        \\  {"id":2,"name":"HDMI-A-1","width":1280,"height":720,"focused":true}
        \\]
    ;
    const monitors = try parseMonitors(std.testing.allocator, json);
    try std.testing.expectEqualStrings("HDMI-A-1", focusedMonitorName(monitors).?);
}

test "monitor JSON parser rejects missing source identity" {
    const json =
        \\[
        \\  {"name":"DP-1","width":1920,"height":1080}
        \\]
    ;
    try std.testing.expectError(error.InvalidMonitorJson, parseMonitors(std.testing.allocator, json));
}

test "workspace JSON parser leaves count-only window refs empty" {
    const json =
        \\[
        \\  {"id":7,"name":"main","monitorID":1,"windows":2}
        \\]
    ;
    const workspaces = try parseWorkspaces(std.testing.allocator, json);
    try std.testing.expectEqual(@as(u32, 1), workspaces.count);
    try std.testing.expectEqual(@as(u32, 1), workspaces.items[0].visible_on.count);
    try std.testing.expectEqual(@as(u32, 0), workspaces.items[0].windows.count);
}

test "window JSON parser keeps address as source identity" {
    const json =
        \\[
        \\  {"address":"0xabc","class":"foot","title":"shell","size":[800,600],"workspace":{"id":7},"mapped":true,"focusHistoryID":0}
        \\]
    ;
    const windows = try parseWindows(std.testing.allocator, json);
    try std.testing.expectEqual(@as(u32, 1), windows.count);
    try std.testing.expectEqual(@as(u64, 0xabc), windows.items[0].id.value);
    try std.testing.expect(windows.items[0].visible);
    try std.testing.expect(windows.items[0].focused);
    try std.testing.expectEqual(@as(i32, 7), windows.items[0].workspace.?.id);
}

test "JSON parsers reject malformed and oversized responses" {
    const oversized = try std.testing.allocator.alloc(u8, max_hypr_response_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, ' ');
    try std.testing.expectError(error.HyprlandResponseTooLarge, parseMonitors(std.testing.allocator, oversized));
    try std.testing.expectError(error.HyprlandResponseTooLarge, parseWorkspaces(std.testing.allocator, oversized));
    try std.testing.expectError(error.HyprlandResponseTooLarge, parseWindows(std.testing.allocator, oversized));
    try std.testing.expectError(error.InvalidMonitorJson, parseMonitors(std.testing.allocator, "{}"));
    try std.testing.expectError(error.InvalidWorkspaceJson, parseWorkspaces(std.testing.allocator, "{}"));
    try std.testing.expectError(error.InvalidWindowJson, parseWindows(std.testing.allocator, "{}"));
}

test "socket2 classifier accepts fact-change events only" {
    try std.testing.expectEqual(@as(?FactEvent, .monitor_changed), classifyEventLine("monitoradded>>DP-1"));
    try std.testing.expectEqual(@as(?FactEvent, .workspace_changed), classifyEventLine("workspacev2>>7,main"));
    try std.testing.expectEqual(@as(?FactEvent, .window_changed), classifyEventLine("activewindowv2>>abc"));
    try std.testing.expectEqual(@as(?FactEvent, null), classifyEventLine("fullscreen>>1"));
    try std.testing.expectEqual(@as(?FactEvent, null), classifyEventLine("focusedmon"));
}

test "socket2 pending parser rejects overlong lines and skips ignored lines" {
    var stream = EventStream{};
    stream.pending_len = max_event_line_bytes;
    try std.testing.expectError(error.HyprlandEventLineTooLong, stream.readAvailableFromBytes("x"));

    const bytes = "fullscreen>>1\nmonitoradded>>DP-1\n";
    @memcpy(stream.pending[0..bytes.len], bytes);
    stream.pending_len = @intCast(bytes.len);
    try std.testing.expectEqual(@as(?FactEvent, .monitor_changed), stream.nextPendingEvent());
}

test "socket2 parser bounds line storage without rejecting a valid event burst" {
    var stream = EventStream{};
    var bytes: [event_read_bytes]u8 = undefined;
    const line = "workspacev2>>7,main\n";
    var offset: u32 = 0;
    while (offset + line.len <= max_event_line_bytes + line.len) : (offset += @intCast(line.len)) {
        std.mem.copyForwards(u8, bytes[offset .. offset + line.len], line);
    }

    try std.testing.expect(offset > max_event_line_bytes);
    try stream.readAvailableFromBytes(bytes[0..offset]);
    try std.testing.expectEqual(@as(?FactEvent, .workspace_changed), stream.nextPendingEvent());
    try std.testing.expectEqual(@as(u32, 0), stream.pending_len);
}
