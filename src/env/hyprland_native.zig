//! Hyprland owns the native Linux socket and poll implementation only.

const std = @import("std");
const io = @import("hyprland_io");

const NativeRecord = struct {
    id: io.SocketId = .{ .value = 0 },
    fd: std.posix.fd_t = -1,
    kind: io.SocketKind = .request,
    open: bool = false,
    write_offset: usize = 0,
};

/// SocketSource owns the fixed native descriptor mapping for one env owner.
pub const SocketSource = struct {
    /// records owns at most eight native descriptors and their local identities.
    records: [io.max_socket_records]NativeRecord = [_]NativeRecord{.{}} ** io.max_socket_records,
    /// next_id is the next nonzero local identity; exhaustion returns SystemCallFailed.
    next_id: u32 = 1,
    /// initialized rejects new operations after deinit.
    initialized: bool = true,

    /// init starts with no open socket and owns no allocator.
    pub fn init() SocketSource {
        return .{};
    }

    /// deinit attempts every live close once and returns the first close error.
    pub fn deinit(self: *SocketSource) io.SocketCloseError!void {
        if (!self.initialized) return;
        self.initialized = false;
        var first_error: ?io.SocketCloseError = null;
        for (&self.records) |*record| {
            if (!record.open) continue;
            const id = record.id;
            self.close(id) catch |err| {
                if (first_error == null) first_error = err;
            };
        }
        if (first_error) |err| return err;
    }

    /// socket opens one request or event descriptor and publishes a local id.
    pub fn socket(self: *SocketSource, kind: io.SocketKind) io.SocketOpenError!io.SocketId {
        if (!self.initialized) return error.SystemCallFailed;
        const slot = self.freeRecord() orelse return error.SystemCallFailed;
        if (self.next_id == std.math.maxInt(u32)) return error.SystemCallFailed;
        const raw_fd = std.os.linux.socket(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC,
            0,
        );
        switch (std.os.linux.errno(raw_fd)) {
            .SUCCESS => {},
            else => return error.HyprlandSocketOpenFailed,
        }
        const fd: std.posix.fd_t = @intCast(raw_fd);
        const id = io.SocketId.init(self.next_id) catch unreachable;
        self.next_id += 1;
        slot.* = .{ .id = id, .fd = fd, .kind = kind, .open = true };
        return id;
    }

    /// connect copies a validated SocketPath into native sockaddr storage.
    pub fn connect(self: *SocketSource, id: io.SocketId, path: io.SocketPath) io.SocketConnectError!void {
        const record = self.liveRecord(id) orelse return error.HyprlandSocketNotLive;
        var address = std.os.linux.sockaddr.un{ .family = std.os.linux.AF.UNIX, .path = [_]u8{0} ** 108 };
        @memcpy(address.path[0..path.len], path.bytes[0..path.len]);
        const address_len: std.os.linux.socklen_t = @intCast(
            @offsetOf(std.os.linux.sockaddr.un, "path") + path.len + 1,
        );
        const result = std.os.linux.connect(record.fd, &address, address_len);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => {},
            else => error.HyprlandSocketConnectFailed,
        };
    }

    /// write sends one bounded request fragment and returns its exact byte count.
    pub fn write(self: *SocketSource, id: io.SocketId, request: io.RequestWrite) io.SocketWriteError!io.WriteCount {
        const record = self.liveRecord(id) orelse return error.HyprlandSocketNotLive;
        const bytes = request.slice();
        if (record.write_offset >= bytes.len) return error.HyprlandSocketWriteFailed;
        const remaining = bytes[record.write_offset..];
        const result = std.os.linux.write(record.fd, remaining.ptr, remaining.len);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => if (result <= 0 or result > remaining.len) error.HyprlandSocketWriteFailed else blk: {
                record.write_offset += @intCast(result);
                break :blk @intCast(result);
            },
            .INTR => error.SignalInterrupted,
            else => error.HyprlandSocketWriteFailed,
        };
    }

    /// readRequest returns one bounded response chunk or EOF.
    pub fn readRequest(self: *SocketSource, id: io.SocketId) io.SocketReadError!io.RequestRead {
        const record = self.liveRecord(id) orelse return error.HyprlandSocketNotLive;
        var chunk = io.RequestChunk{};
        const result = std.os.linux.read(record.fd, chunk.bytes[0..].ptr, chunk.bytes.len);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => if (result == 0) .eof else .{ .chunk = .{ .bytes = chunk.bytes, .len = @intCast(result) } },
            .INTR => error.SignalInterrupted,
            else => error.HyprlandSocketReadFailed,
        };
    }

    /// readEvent returns one bounded socket2 chunk or EOF.
    pub fn readEvent(self: *SocketSource, id: io.SocketId) io.SocketReadError!io.EventRead {
        const record = self.liveRecord(id) orelse return error.HyprlandSocketNotLive;
        var chunk = io.EventChunk{};
        const result = std.os.linux.read(record.fd, chunk.bytes[0..].ptr, chunk.bytes.len);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => if (result == 0) .eof else .{ .chunk = .{ .bytes = chunk.bytes, .len = @intCast(result) } },
            .INTR => error.SignalInterrupted,
            else => error.HyprlandSocketReadFailed,
        };
    }

    /// poll maps native revents for an optional event socket and borrowed stop token.
    pub fn poll(self: *SocketSource, set: io.PollSet) io.PollError!io.PollResult {
        if (!self.initialized) return error.SystemCallFailed;
        var poll_fds: [2]std.posix.pollfd = undefined;
        var count: usize = 0;
        if (set.event) |event_id| {
            const event_record = self.liveRecord(event_id) orelse return error.HyprlandSocketNotLive;
            poll_fds[count] = .{ .fd = event_record.fd, .events = std.posix.POLL.IN, .revents = 0 };
            count += 1;
        }
        const stop_fd = std.math.cast(std.posix.fd_t, set.stop.value) orelse return error.SystemCallFailed;
        const stop_index = count;
        poll_fds[count] = .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 };
        count += 1;
        const result = std.os.linux.poll(poll_fds[0..count].ptr, @intCast(count), set.timeout.milliseconds);
        switch (std.os.linux.errno(result)) {
            .SUCCESS => {},
            .INTR => return error.SignalInterrupted,
            else => return error.SystemCallFailed,
        }
        const stop = try mapRevents(@intCast(poll_fds[stop_index].revents), true);
        const event = if (set.event == null) null else try mapRevents(@intCast(poll_fds[0].revents), false);
        return .{ .event = event, .stop = stop };
    }

    /// close attempts one native close and retires the local mapping either way.
    pub fn close(self: *SocketSource, id: io.SocketId) io.SocketCloseError!void {
        const record = self.liveRecord(id) orelse return error.HyprlandSocketNotLive;
        const fd = record.fd;
        record.open = false;
        record.fd = -1;
        const result = std.os.linux.close(fd);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => {},
            else => error.HyprlandSocketCloseFailed,
        };
    }

    fn freeRecord(self: *SocketSource) ?*NativeRecord {
        for (&self.records) |*record| if (!record.open) return record;
        return null;
    }

    fn liveRecord(self: *SocketSource, id: io.SocketId) ?*NativeRecord {
        if (id.value == 0) return null;
        for (&self.records) |*record| if (record.open and record.id.value == id.value) return record;
        return null;
    }
};

fn mapRevents(revents: u16, is_stop: bool) io.PollError!io.PollState {
    const input: u16 = @intCast(std.posix.POLL.IN);
    const hangup: u16 = @intCast(std.posix.POLL.HUP);
    const failed: u16 = @intCast(std.posix.POLL.ERR);
    const invalid: u16 = @intCast(std.posix.POLL.NVAL);
    const known = input | hangup | failed | invalid;
    if ((revents & ~known) != 0 or (revents & (failed | invalid)) != 0) return error.SystemCallFailed;
    if ((revents & input) != 0 and (revents & hangup) != 0) return if (is_stop) .closed else .readable_hangup;
    if ((revents & input) != 0) return .readable;
    if ((revents & hangup) != 0) return .closed;
    return .idle;
}

test "native source starts empty and rejects a retired identity" {
    var source = SocketSource.init();
    try std.testing.expectError(error.HyprlandSocketNotLive, source.close(.{ .value = 1 }));
    try source.deinit();
    try source.deinit();
}

test "native poll mapping handles every supported revents shape" {
    const input: u16 = @intCast(std.posix.POLL.IN);
    const hangup: u16 = @intCast(std.posix.POLL.HUP);
    const failed: u16 = @intCast(std.posix.POLL.ERR);
    const invalid: u16 = @intCast(std.posix.POLL.NVAL);

    try std.testing.expectEqual(io.PollState.idle, try mapRevents(0, false));
    try std.testing.expectEqual(io.PollState.readable, try mapRevents(input, false));
    try std.testing.expectEqual(io.PollState.readable_hangup, try mapRevents(input | hangup, false));
    try std.testing.expectEqual(io.PollState.closed, try mapRevents(hangup, false));
    try std.testing.expectEqual(io.PollState.closed, try mapRevents(input | hangup, true));
    try std.testing.expectError(error.SystemCallFailed, mapRevents(failed, false));
    try std.testing.expectError(error.SystemCallFailed, mapRevents(invalid, false));
    try std.testing.expectError(error.SystemCallFailed, mapRevents(0x8000, false));
}
