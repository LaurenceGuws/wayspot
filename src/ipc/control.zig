//! IPC control owns the local Unix socket protocol for one resident picker.

const std = @import("std");
const build_options = @import("build_options");

pub const Command = enum {
    ping,
    summon,
    hide,
    toggle,
    version,
};

pub const HandlerResult = struct {
    ok: bool,
    code: []const u8,
    message: []const u8,
};

/// ControlSlot carries accepted visibility commands from the socket thread to the UI loop.
pub const ControlSlot = struct {
    mu: std.Io.Mutex = .init,
    command: ?Command = null,
    wake_event_type: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    wake_pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn put(self: *ControlSlot, command: Command) void {
        self.mu.lockUncancelable(std.Options.debug_io);
        self.command = command;
        self.mu.unlock(std.Options.debug_io);
        self.wake();
    }

    pub fn take(self: *ControlSlot) ?Command {
        self.mu.lockUncancelable(std.Options.debug_io);
        const command = self.command;
        self.command = null;
        self.mu.unlock(std.Options.debug_io);
        self.wake_pending.store(false, .release);
        return command;
    }

    pub fn setWakeEvent(self: *ControlSlot, event_type: u32) void {
        std.debug.assert(event_type != 0);
        self.wake_event_type.store(event_type, .release);
    }

    fn wake(self: *ControlSlot) void {
        const event_type = self.wake_event_type.load(.acquire);
        if (event_type == 0) return;
        if (self.wake_pending.swap(true, .acq_rel)) return;
        var event = @import("sdl_c").SDL_Event{ .user = .{ .type = event_type } };
        _ = @import("sdl_c").SDL_PushEvent(&event);
    }
};

const Request = struct {
    v: u32 = 0,
    cmd: []const u8 = "",
};

const Response = struct {
    ok: bool = false,
    code: []const u8 = "",
    message: []const u8 = "",
};

const OwnedResponse = struct {
    ok: bool,
    code: []const u8,
    message: []const u8,
    elapsed_ns: u64,
};

const connect_timeout_ms: u64 = 250;
const response_timeout_ms: i32 = 500;
const max_response_bytes: u32 = 8 * 1024 * 1024;
const response_chunk_size: u32 = 4096;

pub const Server = struct {
    allocator: std.mem.Allocator,
    socket_path: []u8,
    listener_fd: std.posix.fd_t,
    control_slot: *ControlSlot,
    stop_flag: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    thread: ?std.Thread = null,

    pub fn init(
        allocator: std.mem.Allocator,
        control_slot: *ControlSlot,
    ) !Server {
        const socket_path = try defaultSocketPathAlloc(allocator);
        const listener_fd = try bindListener(socket_path);
        return .{
            .allocator = allocator,
            .socket_path = socket_path,
            .listener_fd = listener_fd,
            .control_slot = control_slot,
        };
    }

    pub fn start(self: *Server) !void {
        self.thread = try std.Thread.spawn(.{}, serverMain, .{self});
    }

    pub fn deinit(self: *Server) void {
        self.stop_flag.store(true, .seq_cst);
        osClose(self.listener_fd);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
        osUnlink(self.socket_path) catch |err| {
            std.log.debug("ipc socket unlink failed path={s} err={s}", .{ self.socket_path, @errorName(err) });
        };
        self.allocator.free(self.socket_path);
    }
};

pub fn executeCommand(allocator: std.mem.Allocator, cmd: Command) !OwnedResponse {
    return sendCommand(allocator, cmd);
}

fn sendCommand(allocator: std.mem.Allocator, cmd: Command) !OwnedResponse {
    const start_ns = nowNs();
    const socket_path = try defaultSocketPathAlloc(allocator);
    defer allocator.free(socket_path);

    const fd = osSocket(std.posix.AF.UNIX, std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK, 0) catch |err| {
        if (err == error.AddressFamilyNotSupported) return error.NoSocketSupport;
        return err;
    };
    defer osClose(fd);

    const addr = try unixAddress(socket_path);
    const connected = try connectWithRetryTimeout(fd, @ptrCast(&addr.addr), addr.len, connect_timeout_ms);
    if (!connected) return error.ConnectTimeout;

    const request = try std.fmt.allocPrint(allocator, "{{\"v\":1,\"cmd\":\"{s}\"}}", .{@tagName(cmd)});
    defer allocator.free(request);
    try writeAll(fd, request);
    osShutdownSend(fd) catch |err| {
        std.log.debug("ipc client shutdown(send) failed route={s} err={s}", .{ @tagName(cmd), @errorName(err) });
    };

    var poll_fds = [_]std.posix.pollfd{
        .{
            .fd = fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };
    const poll_count = osPoll(&poll_fds, response_timeout_ms) catch return error.PollFailed;
    if (poll_count <= 0) return error.PollTimeout;
    if ((poll_fds[0].revents & std.posix.POLL.IN) == 0) return error.NoPollInput;

    var response_buf: [response_chunk_size]u8 = undefined;
    var response_buf_list = std.ArrayList(u8).empty;
    defer response_buf_list.deinit(allocator);
    const timeout_deadline = nowNs() + (@as(i96, response_timeout_ms) * std.time.ns_per_ms);
    var total_reads: u32 = 0;
    var total_bytes: u32 = 0;
    while (true) {
        const n = osRead(fd, &response_buf) catch |err| switch (err) {
            error.WouldBlock => blk: {
                const remaining_ns = timeout_deadline - nowNs();
                if (remaining_ns <= 0) {
                    std.log.warn(
                        "ipc read timeout cmd={s} reads={d} bytes={d}",
                        .{ @tagName(cmd), total_reads, total_bytes },
                    );
                    return error.PollTimeout;
                }
                const raw_remaining_ms = @divTrunc(remaining_ns + std.time.ns_per_ms - 1, std.time.ns_per_ms);
                const remaining_ms = @as(i32, @intCast(@max(@as(i128, 1), raw_remaining_ms)));
                var followup_poll_fds = [_]std.posix.pollfd{
                    .{
                        .fd = fd,
                        .events = std.posix.POLL.IN,
                        .revents = 0,
                    },
                };
                const ready = osPoll(&followup_poll_fds, remaining_ms) catch return error.PollFailed;
                if (ready <= 0) {
                    std.log.warn(
                        "ipc read timeout cmd={s} reads={d} bytes={d}",
                        .{ @tagName(cmd), total_reads, total_bytes },
                    );
                    return error.PollTimeout;
                }
                if ((followup_poll_fds[0].revents & std.posix.POLL.IN) == 0) {
                    continue;
                }
                break :blk 0;
            },
            else => {
                std.log.warn(
                    "ipc read failed cmd={s} err={s} reads={d} bytes={d}",
                    .{ @tagName(cmd), @errorName(err), total_reads, total_bytes },
                );
                return error.ReadFailed;
            },
        };
        if (n == 0) break;
        total_reads += 1;
        total_bytes += @intCast(n);
        if (response_buf_list.items.len + n > max_response_bytes) {
            std.log.warn(
                "ipc response exceeds max bytes cmd={s} bytes={d} max={d} reads={d}",
                .{ @tagName(cmd), response_buf_list.items.len + n, max_response_bytes, total_reads },
            );
            return error.ReadFailed;
        }
        try response_buf_list.appendSlice(allocator, response_buf[0..n]);
    }
    if (response_buf_list.items.len == 0) return error.EmptyResponse;

    var scanner = std.json.Scanner.initCompleteInput(allocator, response_buf_list.items);
    defer scanner.deinit();
    var diagnostics = std.json.Scanner.Diagnostics{};
    scanner.enableDiagnostics(&diagnostics);
    const parsed = std.json.parseFromTokenSource(Response, allocator, &scanner, .{}) catch |err| {
        std.log.warn(
            "ipc decode failed cmd={s} err={s} bytes={d} reads={d} offset={d} line={d} col={d}",
            .{
                @tagName(cmd),
                @errorName(err),
                response_buf_list.items.len,
                total_reads,
                diagnostics.getByteOffset(),
                diagnostics.getLine(),
                diagnostics.getColumn(),
            },
        );
        return error.BadResponse;
    };
    defer parsed.deinit();
    const code = try allocator.dupe(u8, parsed.value.code);
    const message = try allocator.dupe(u8, parsed.value.message);
    return .{
        .ok = parsed.value.ok,
        .code = code,
        .message = message,
        .elapsed_ns = elapsedFrom(start_ns),
    };
}

fn elapsedFrom(start_ns: i96) u64 {
    const elapsed = nowNs() - start_ns;
    return if (elapsed > 0) @intCast(elapsed) else 0;
}

fn nowNs() i96 {
    return std.Io.Clock.awake.now(std.Options.debug_io).toNanoseconds();
}

pub fn defaultSocketPathAlloc(allocator: std.mem.Allocator) ![]u8 {
    const uid = std.os.linux.getuid();
    return std.fmt.allocPrint(allocator, "/tmp/wayspot-{d}.sock", .{uid});
}

fn bindListener(socket_path: []const u8) !std.posix.fd_t {
    const fd = try osSocket(std.posix.AF.UNIX, std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC, 0);
    errdefer osClose(fd);

    const addr = try unixAddress(socket_path);
    osBind(fd, @ptrCast(&addr.addr), addr.len) catch |err| {
        if (err == error.AddressInUse) {
            if (!isSocketLive(socket_path)) {
                osUnlink(socket_path) catch |unlink_err| {
                    std.log.warn("ipc stale socket unlink failed path={s} err={s}", .{ socket_path, @errorName(unlink_err) });
                };
                try osBind(fd, @ptrCast(&addr.addr), addr.len);
            } else {
                return error.AddressInUse;
            }
        } else {
            return err;
        }
    };
    try osListen(fd, 32);
    return fd;
}

fn isSocketLive(socket_path: []const u8) bool {
    const fd = osSocket(std.posix.AF.UNIX, std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC, 0) catch return false;
    defer osClose(fd);
    const addr = unixAddress(socket_path) catch return false;
    osConnect(fd, @ptrCast(&addr.addr), addr.len) catch return false;
    return true;
}

fn serverMain(server: *Server) void {
    while (!server.stop_flag.load(.seq_cst)) {
        const client_fd = osAccept(server.listener_fd, std.posix.SOCK.CLOEXEC) catch |err| {
            switch (err) {
                error.WouldBlock, error.ConnectionAborted => continue,
                error.FileDescriptorNotASocket, error.OperationNotSupported, error.SystemResources, error.ProcessFdQuotaExceeded => continue,
                else => {
                    if (server.stop_flag.load(.seq_cst)) break;
                    continue;
                },
            }
        };
        handleClient(server, client_fd);
        osClose(client_fd);
    }
}

fn handleClient(server: *Server, client_fd: std.posix.fd_t) void {
    const request_bytes = readRequestAlloc(server.allocator, client_fd) catch {
        writeResponse(server.allocator, client_fd, "invalid_request", false, "read_error", "Failed to read request");
        return;
    };
    defer server.allocator.free(request_bytes);

    if (request_bytes.len == 0) {
        writeResponse(server.allocator, client_fd, "invalid_request", false, "bad_request", "Empty request");
        return;
    }

    var parsed = std.json.parseFromSlice(Request, server.allocator, request_bytes, .{}) catch {
        writeResponse(server.allocator, client_fd, "invalid_request", false, "bad_request", "Invalid JSON");
        return;
    };
    defer parsed.deinit();

    if (parsed.value.v != 1) {
        writeResponse(server.allocator, client_fd, "invalid_request", false, "bad_request", "Unsupported protocol version");
        return;
    }

    const cmd = parseCommand(parsed.value.cmd) orelse {
        writeResponse(server.allocator, client_fd, "invalid_request", false, "bad_request", "Unknown command");
        return;
    };

    switch (cmd) {
        .ping => writeResponse(server.allocator, client_fd, @tagName(cmd), true, "ok", "pong"),
        .version => writeResponse(server.allocator, client_fd, @tagName(cmd), true, "ok", build_options.app_version),
        .summon, .hide, .toggle => {
            server.control_slot.put(cmd);
            writeResponse(server.allocator, client_fd, @tagName(cmd), true, "ok", "accepted");
        },
    }
}

fn parseCommand(value: []const u8) ?Command {
    inline for (std.meta.fields(Command)) |field| {
        if (std.mem.eql(u8, value, field.name)) {
            return @field(Command, field.name);
        }
    }
    return null;
}

fn writeResponse(
    allocator: std.mem.Allocator,
    fd: std.posix.fd_t,
    endpoint: []const u8,
    ok: bool,
    code: []const u8,
    message: []const u8,
) void {
    const Payload = struct {
        ok: bool,
        code: []const u8,
        message: []const u8,
    };

    var output = std.ArrayList(u8).empty;
    defer output.deinit(allocator);
    const payload = std.json.fmt(Payload{ .ok = ok, .code = code, .message = message }, .{});
    output.print(allocator, "{f}", .{payload}) catch return;
    if (output.items.len > max_response_bytes) {
        std.log.warn(
            "ipc response too large for client protocol cmd={s} bytes={d} max={d}",
            .{ endpoint, output.items.len, max_response_bytes },
        );
        const error_payload = "{\"ok\":false,\"code\":\"response_too_large\",\"message\":\"response exceeded ipc limit\"}";
        writeAll(fd, error_payload) catch |err| {
            std.log.warn("ipc response write failed cmd={s} err={s}", .{ endpoint, @errorName(err) });
            return;
        };
        return;
    }
    writeAll(fd, output.items) catch |err| {
        std.log.warn("ipc response write failed cmd={s} err={s}", .{ endpoint, @errorName(err) });
        return;
    };
}

fn readRequestAlloc(allocator: std.mem.Allocator, fd: std.posix.fd_t) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var buf: [4096]u8 = undefined;
    while (true) {
        const n = osRead(fd, &buf) catch |err| switch (err) {
            error.WouldBlock => continue,
            else => return err,
        };
        if (n == 0) break;
        if (out.items.len + n > max_response_bytes) return error.MessageTooLong;
        try out.appendSlice(allocator, buf[0..n]);
    }

    return out.toOwnedSlice(allocator);
}

fn writeAll(fd: std.posix.fd_t, bytes: []const u8) !void {
    var offset: u32 = 0;
    while (offset < bytes.len) {
        const n = try osWrite(fd, bytes[@intCast(offset)..]);
        if (n == 0) return error.WriteFailed;
        offset += @intCast(n);
    }
}

fn connectWithRetryTimeout(fd: std.posix.fd_t, sockaddr: *const std.os.linux.sockaddr, socklen: std.posix.socklen_t, timeout_ms: u64) !bool {
    const start_ns = nowNs();
    const timeout_ns = timeout_ms * std.time.ns_per_ms;

    while (true) {
        osConnect(fd, sockaddr, socklen) catch |err| switch (err) {
            error.WouldBlock, error.FileNotFound, error.ConnectionRefused, error.ConnectionResetByPeer, error.NetworkUnreachable, error.AddressNotAvailable => {
                const now_ns = nowNs();
                if (now_ns - start_ns >= @as(i96, @intCast(timeout_ns))) return false;
                std.Io.sleep(
                    std.Options.debug_io,
                    .fromNanoseconds(5 * std.time.ns_per_ms),
                    .awake,
                ) catch {};
                continue;
            },
            else => return err,
        };
        return true;
    }
}

fn osSocket(domain: u32, socket_type: u32, protocol: u32) !std.posix.fd_t {
    const rc = std.os.linux.socket(domain, socket_type, protocol);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .AFNOSUPPORT => error.AddressFamilyNotSupported,
        else => error.SystemCallFailed,
    };
}

fn osClose(fd: std.posix.fd_t) void {
    const rc = std.os.linux.close(fd);
    if (std.os.linux.errno(rc) != .SUCCESS) {
        std.log.debug("unix socket close failed fd={d}", .{fd});
    }
}

const UnixSockAddr = struct {
    addr: std.os.linux.sockaddr.un,
    len: std.posix.socklen_t,
};

fn unixAddress(path: []const u8) !UnixSockAddr {
    if (path.len >= 108) return error.NameTooLong;
    var addr: std.os.linux.sockaddr.un = .{
        .family = std.os.linux.AF.UNIX,
        .path = [_]u8{0} ** 108,
    };
    @memcpy(addr.path[0..path.len], path);
    addr.path[path.len] = 0;
    return .{
        .addr = addr,
        .len = @intCast(@offsetOf(std.os.linux.sockaddr.un, "path") + path.len + 1),
    };
}

fn osBind(fd: std.posix.fd_t, sockaddr: *const std.os.linux.sockaddr, socklen: std.posix.socklen_t) !void {
    const rc = std.os.linux.bind(fd, sockaddr, socklen);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .ADDRINUSE => error.AddressInUse,
        else => error.SystemCallFailed,
    };
}

fn osListen(fd: std.posix.fd_t, backlog: u32) !void {
    const rc = std.os.linux.listen(fd, backlog);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        else => error.SystemCallFailed,
    };
}

fn osConnect(fd: std.posix.fd_t, sockaddr: *const std.os.linux.sockaddr, socklen: std.posix.socklen_t) !void {
    const rc = std.os.linux.connect(fd, sockaddr, socklen);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .AGAIN => error.WouldBlock,
        .NOENT => error.FileNotFound,
        .CONNREFUSED => error.ConnectionRefused,
        .CONNRESET => error.ConnectionResetByPeer,
        .NETUNREACH => error.NetworkUnreachable,
        .ADDRNOTAVAIL => error.AddressNotAvailable,
        else => error.SystemCallFailed,
    };
}

fn osAccept(fd: std.posix.fd_t, flags: u32) !std.posix.fd_t {
    const rc = std.os.linux.accept4(fd, null, null, flags);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .AGAIN => error.WouldBlock,
        .CONNABORTED => error.ConnectionAborted,
        .NOTSOCK => error.FileDescriptorNotASocket,
        .OPNOTSUPP => error.OperationNotSupported,
        .NOMEM => error.SystemResources,
        .MFILE, .NFILE => error.ProcessFdQuotaExceeded,
        else => error.SystemCallFailed,
    };
}

fn osPoll(fds: []std.posix.pollfd, timeout_ms: i32) !u32 {
    const rc = std.os.linux.poll(fds.ptr, @intCast(fds.len), timeout_ms);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        else => error.SystemCallFailed,
    };
}

fn osRead(fd: std.posix.fd_t, buf: []u8) !u32 {
    const rc = std.os.linux.read(fd, buf.ptr, buf.len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        .AGAIN => error.WouldBlock,
        else => error.SystemCallFailed,
    };
}

fn osWrite(fd: std.posix.fd_t, bytes: []const u8) !u32 {
    const rc = std.os.linux.write(fd, bytes.ptr, bytes.len);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => @intCast(rc),
        else => error.SystemCallFailed,
    };
}

fn osShutdownSend(fd: std.posix.fd_t) !void {
    const rc = std.os.linux.shutdown(fd, std.os.linux.SHUT.WR);
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        else => error.SystemCallFailed,
    };
}

fn osUnlink(path: []const u8) !void {
    if (path.len >= std.fs.max_path_bytes) return error.NameTooLong;
    var path_z: [std.fs.max_path_bytes:0]u8 = undefined;
    @memcpy(path_z[0..path.len], path);
    path_z[path.len] = 0;
    const rc = std.os.linux.unlink(@ptrCast(&path_z));
    return switch (std.os.linux.errno(rc)) {
        .SUCCESS => {},
        .NOENT => error.FileNotFound,
        else => error.SystemCallFailed,
    };
}

test "bindListener replaces stale occupied path and binds socket" {
    const allocator = std.testing.allocator;
    const pid = std.c.getpid();
    const path = try std.fmt.allocPrint(allocator, "/tmp/wayspot-stale-{d}.sock", .{pid});
    defer allocator.free(path);
    std.posix.unlink(path) catch |err| {
        std.log.debug("test socket unlink pre failed path={s} err={s}", .{ path, @errorName(err) });
    };
    defer std.posix.unlink(path) catch |err| {
        std.log.debug("test socket unlink post failed path={s} err={s}", .{ path, @errorName(err) });
    };

    const file = try std.fs.createFileAbsolute(path, .{});
    file.close();

    const fd = try bindListener(path);
    defer std.posix.close(fd);

    const stat = try std.posix.fstatat(std.posix.AT.FDCWD, path, 0);
    try std.testing.expect(std.posix.S.ISSOCK(stat.mode));
}

test "bindListener sets user-only socket permissions" {
    const allocator = std.testing.allocator;
    const pid = std.c.getpid();
    const path = try std.fmt.allocPrint(allocator, "/tmp/wayspot-mode-{d}.sock", .{pid});
    defer allocator.free(path);
    std.posix.unlink(path) catch |err| {
        std.log.debug("test socket unlink pre failed path={s} err={s}", .{ path, @errorName(err) });
    };
    defer std.posix.unlink(path) catch |err| {
        std.log.debug("test socket unlink post failed path={s} err={s}", .{ path, @errorName(err) });
    };

    const fd = try bindListener(path);
    defer std.posix.close(fd);

    const stat = try std.posix.fstatat(std.posix.AT.FDCWD, path, 0);
    try std.testing.expectEqual(@as(u32, 0o600), stat.mode & 0o777);
}

test "writeAll writes full payload across stream socket" {
    const fds = try std.posix.socketpair(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(fds[0]);
    defer std.posix.close(fds[1]);

    const payload = "abcdefghijklmnopqrstuvwxyz0123456789";
    try writeAll(fds[0], payload);
    std.posix.shutdown(fds[0], .send) catch {};

    const received = try readRequestAlloc(std.testing.allocator, fds[1]);
    defer std.testing.allocator.free(received);

    try std.testing.expectEqualStrings(payload, received);
}

test "readRequestAlloc reads fragmented request until eof" {
    const fds = try std.posix.socketpair(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(fds[0]);
    defer std.posix.close(fds[1]);

    try writeAll(fds[0], "{\"v\":1,");
    try writeAll(fds[0], "\"cmd\":\"ping\"}");
    std.posix.shutdown(fds[0], .send) catch {};

    const request = try readRequestAlloc(std.testing.allocator, fds[1]);
    defer std.testing.allocator.free(request);

    try std.testing.expectEqualStrings("{\"v\":1,\"cmd\":\"ping\"}", request);
}
