//! Hyprland access owns bounded monitor facts and the socket2 monitor event stream.

const std = @import("std");

pub const max_monitors: u32 = 8;
pub const max_hypr_response_bytes: u32 = 1024 * 1024;
pub const max_monitor_name_bytes: u32 = 96;
const socket_path_bytes: u32 = 160;
const max_event_line_bytes: u32 = 512;
const event_read_bytes: u32 = 1024;

pub const Connection = struct {
    runtime_dir: []const u8,
    signature: []const u8,
};

pub const Monitor = struct {
    name_buf: [max_monitor_name_bytes]u8 = undefined,
    name_len: u32 = 0,
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    scale: f64 = 1,
    focused: bool = false,

    pub fn name(self: *const Monitor) []const u8 {
        return self.name_buf[0..self.name_len];
    }
};

pub const MonitorList = struct {
    items: [max_monitors]Monitor = undefined,
    count: u32 = 0,

    fn append(self: *MonitorList, monitor: Monitor) !void {
        if (self.count >= max_monitors) return error.TooManyMonitors;
        self.items[self.count] = monitor;
        self.count += 1;
    }
};

pub fn queryMonitors(allocator: std.mem.Allocator, hypr: Connection) !MonitorList {
    const response = try request(allocator, hypr, "j/monitors");
    defer allocator.free(response);
    return parseMonitors(allocator, response);
}

pub const MonitorEvent = enum {
    monitor_changed,
    stopped,
};

pub const EventStream = struct {
    fd: std.posix.fd_t = -1,
    pending: [max_event_line_bytes]u8 = undefined,
    pending_len: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, hypr: Connection) !EventStream {
        const socket_path = try std.fmt.allocPrint(allocator, "{s}/hypr/{s}/.socket2.sock", .{ hypr.runtime_dir, hypr.signature });
        defer allocator.free(socket_path);
        return .{
            .fd = try connectRequestSocket(socket_path),
        };
    }

    pub fn deinit(self: *EventStream) void {
        if (self.fd != -1) {
            closeFd(self.fd);
            self.fd = -1;
        }
    }

    /// Poll socket2 with a stop fd so monitor events wake the vendor event loop without polling the CPU.
    pub fn wait(self: *EventStream, stop_fd: std.posix.fd_t) !MonitorEvent {
        while (true) {
            if (self.nextPendingEvent()) |event| return event;

            var poll_fds = [_]std.posix.pollfd{
                .{
                    .fd = self.fd,
                    .events = std.posix.POLL.IN,
                    .revents = 0,
                },
                .{
                    .fd = stop_fd,
                    .events = std.posix.POLL.IN,
                    .revents = 0,
                },
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

        var index: u32 = 0;
        while (index < read_count) : (index += 1) {
            if (self.pending_len >= max_event_line_bytes) {
                self.pending_len = 0;
                return error.HyprlandEventLineTooLong;
            }
            self.pending[self.pending_len] = buf[index];
            self.pending_len += 1;
        }
    }

    fn nextPendingEvent(self: *EventStream) ?MonitorEvent {
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
};

/// Open, write, read, and close each Hyprland request without retaining the synchronous socket.
fn request(allocator: std.mem.Allocator, hypr: Connection, command: []const u8) ![]u8 {
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/hypr/{s}/.socket.sock", .{ hypr.runtime_dir, hypr.signature });
    defer allocator.free(socket_path);

    const fd = try connectRequestSocket(socket_path);
    defer closeFd(fd);

    try writeAll(fd, command);
    return readBounded(allocator, fd);
}

fn connectRequestSocket(socket_path: []const u8) !i32 {
    if (socket_path.len >= socket_path_bytes) return error.HyprlandSocketPathTooLong;
    const raw_fd = std.os.linux.socket(
        std.os.linux.AF.UNIX,
        std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC,
        0,
    );
    switch (std.os.linux.errno(raw_fd)) {
        .SUCCESS => {},
        else => return error.HyprlandSocketOpenFailed,
    }
    const fd: i32 = @intCast(raw_fd);
    errdefer closeFd(fd);

    var addr = std.os.linux.sockaddr.un{
        .family = std.os.linux.AF.UNIX,
        .path = [_]u8{0} ** 108,
    };
    @memcpy(addr.path[0..socket_path.len], socket_path);
    const addr_len: std.os.linux.socklen_t = @intCast(@offsetOf(std.os.linux.sockaddr.un, "path") + socket_path.len + 1);
    const rc = std.os.linux.connect(fd, &addr, addr_len);
    switch (std.os.linux.errno(rc)) {
        .SUCCESS => return fd,
        else => return error.HyprlandSocketConnectFailed,
    }
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

fn classifyEventLine(line: []const u8) ?MonitorEvent {
    const marker = std.mem.indexOf(u8, line, ">>") orelse return null;
    const name = line[0..marker];
    if (std.mem.eql(u8, name, "monitoradded") or
        std.mem.eql(u8, name, "monitoraddedv2") or
        std.mem.eql(u8, name, "monitorremoved") or
        std.mem.eql(u8, name, "monitorremovedv2"))
    {
        return .monitor_changed;
    }
    return null;
}

fn parseMonitors(allocator: std.mem.Allocator, response: []const u8) !MonitorList {
    if (response.len > max_hypr_response_bytes) return error.HyprlandResponseTooLarge;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();
    if (parsed.value != .array) return error.InvalidMonitorJson;

    var list = MonitorList{};
    for (parsed.value.array.items) |entry| {
        if (entry != .object) return error.InvalidMonitorJson;
        var monitor = Monitor{};
        const name_value = entry.object.get("name") orelse return error.InvalidMonitorJson;
        const width_value = entry.object.get("width") orelse return error.InvalidMonitorJson;
        const height_value = entry.object.get("height") orelse return error.InvalidMonitorJson;
        const x_value = entry.object.get("x") orelse return error.InvalidMonitorJson;
        const y_value = entry.object.get("y") orelse return error.InvalidMonitorJson;
        const scale_value = entry.object.get("scale") orelse return error.InvalidMonitorJson;
        const focused_value = entry.object.get("focused") orelse return error.InvalidMonitorJson;

        const name = jsonString(name_value) orelse return error.InvalidMonitorJson;
        if (name.len == 0 or name.len > max_monitor_name_bytes) return error.InvalidMonitorJson;
        @memcpy(monitor.name_buf[0..name.len], name);
        monitor.name_len = @intCast(name.len);
        monitor.width = try jsonI32(width_value);
        monitor.height = try jsonI32(height_value);
        monitor.x = try jsonI32(x_value);
        monitor.y = try jsonI32(y_value);
        monitor.scale = try jsonF64(scale_value);
        monitor.focused = jsonBool(focused_value) orelse return error.InvalidMonitorJson;
        try list.append(monitor);
    }
    return list;
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

test "monitor JSON parser accepts required fields" {
    const json =
        \\[
        \\  {"name":"DP-1","x":0,"y":0,"width":1920,"height":1080,"scale":1.0,"focused":true}
        \\]
    ;
    const monitors = try parseMonitors(std.testing.allocator, json);
    try std.testing.expectEqual(@as(u32, 1), monitors.count);
    try std.testing.expectEqualStrings("DP-1", monitors.items[0].name());
    try std.testing.expectEqual(@as(i32, 1920), monitors.items[0].width);
    try std.testing.expect(monitors.items[0].focused);
}

test "monitor JSON parser rejects oversized and malformed responses" {
    const oversized = try std.testing.allocator.alloc(u8, max_hypr_response_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, ' ');
    try std.testing.expectError(error.HyprlandResponseTooLarge, parseMonitors(std.testing.allocator, oversized));
    try std.testing.expectError(error.InvalidMonitorJson, parseMonitors(std.testing.allocator, "{}"));
}

test "socket2 event classifier accepts only monitor events" {
    try std.testing.expectEqual(@as(?MonitorEvent, .monitor_changed), classifyEventLine("monitoradded>>DP-1"));
    try std.testing.expectEqual(@as(?MonitorEvent, .monitor_changed), classifyEventLine("monitorremovedv2>>1,DP-1,desc"));
    try std.testing.expectEqual(@as(?MonitorEvent, null), classifyEventLine("focusedmon>>DP-1,1"));
    try std.testing.expectEqual(@as(?MonitorEvent, null), classifyEventLine("openwindow>>addr,ws,class,title"));
    try std.testing.expectEqual(@as(?MonitorEvent, null), classifyEventLine("focusedmon"));
}

test "socket2 pending parser skips ignored lines before monitor event" {
    var stream = EventStream{};
    const bytes = "openwindow>>addr,ws,class,title\nmonitoradded>>DP-1\n";
    @memcpy(stream.pending[0..bytes.len], bytes);
    stream.pending_len = @intCast(bytes.len);
    try std.testing.expectEqual(@as(?MonitorEvent, .monitor_changed), stream.nextPendingEvent());
    try std.testing.expectEqual(@as(u32, 0), stream.pending_len);
}
