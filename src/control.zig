//! Bounded same-user session commands. One seqpacket per request and receipt.
const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const Self = @This();

/// Exact command packet names admitted on the same-UID session socket.
pub const Command = enum { summon, dismiss, rotate, status };
const capacity = 1024;
const request_timeout_ms = 2000;
const receipt_timeout_ms = 30_000;
const Address = struct { value: posix.sockaddr.un, length: posix.socklen_t };
// Linux SO_PEERCRED returns struct ucred, not an application-supplied identity.
const Credentials = extern struct { pid: linux.pid_t, uid: linux.uid_t, gid: linux.gid_t };
const failure_events = posix.POLL.ERR | posix.POLL.HUP | posix.POLL.NVAL;

listener: posix.fd_t = -1,
client: posix.fd_t = -1,
deadline: ?u64 = null,
pending: bool = false,

fn address(signature: []const u8) !Address {
    const prefix = "wayspot-resident:";
    if (signature.len != 32) return error.SessionIdentityInvalid;
    if (std.mem.indexOfAny(u8, signature, "\x00/") != null) return error.SessionIdentityInvalid;
    var value: posix.sockaddr.un = .{ .family = posix.AF.UNIX, .path = @splat(0) };
    @memcpy(value.path[1..][0..prefix.len], prefix);
    @memcpy(value.path[1 + prefix.len ..][0..signature.len], signature);
    return .{
        .value = value,
        .length = @intCast(@offsetOf(posix.sockaddr.un, "path") + 1 + prefix.len + signature.len),
    };
}

fn socket() !posix.fd_t {
    const result = linux.socket(
        posix.AF.UNIX,
        posix.SOCK.SEQPACKET | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK,
        0,
    );
    if (linux.errno(result) != .SUCCESS) return error.ControlSocketOpenFailed;
    return @intCast(result);
}

fn authenticate(fd: posix.fd_t) !void {
    var credentials: Credentials = undefined;
    var length: posix.socklen_t = @sizeOf(Credentials);
    const result = linux.getsockopt(
        fd,
        posix.SOL.SOCKET,
        linux.SO.PEERCRED,
        std.mem.asBytes(&credentials),
        &length,
    );
    if (linux.errno(result) != .SUCCESS) return error.ControlCredentialsUnavailable;
    if (length != @sizeOf(Credentials)) return error.ControlCredentialsUnavailable;
    if (credentials.uid != linux.geteuid()) return error.ControlPeerInvalid;
}

/// Reserves the exact session's abstract socket, refusing a second listener.
pub fn open(signature: []const u8) !Self {
    const addr = try address(signature);
    const fd = try socket();
    errdefer closeFd(fd);
    // zig-audit: acknowledge ptr_cast
    // reason: bind borrows an AF_UNIX sockaddr with its exact abstract-name byte length.
    switch (linux.errno(linux.bind(fd, @ptrCast(&addr.value), addr.length))) {
        .SUCCESS => {},
        .ADDRINUSE => return error.ResidentAlreadyRunning,
        else => return error.ControlBindFailed,
    }
    if (linux.errno(linux.listen(fd, 8)) != .SUCCESS) return error.ControlListenFailed;
    return .{ .listener = fd };
}

/// Retires the current client and listener; no descriptor ownership survives.
pub fn deinit(self: *Self) void {
    self.closeClient();
    if (self.listener >= 0) closeFd(self.listener);
    self.* = .{};
}

fn closeFd(fd: posix.fd_t) void {
    // Linux retires the descriptor on EINTR too; retry could close a reused fd.
    switch (linux.errno(linux.close(fd))) {
        .SUCCESS, .INTR => {},
        else => |err| std.log.err("control descriptor close failed: {s}", .{@tagName(err)}),
    }
}

fn closeClient(self: *Self) void {
    if (self.client >= 0) closeFd(self.client);
    self.client = -1;
    self.deadline = null;
    self.pending = false;
}

fn send(fd: posix.fd_t, bytes: []const u8) !void {
    const result = linux.sendto(
        fd,
        bytes.ptr,
        bytes.len,
        linux.MSG.DONTWAIT | linux.MSG.NOSIGNAL,
        null,
        0,
    );
    if (linux.errno(result) != .SUCCESS or result != bytes.len) return error.ControlSendFailed;
}

fn rejectBusy(fd: posix.fd_t) void {
    defer closeFd(fd);
    // Retire at most one queued request without admitting it. Closing a Linux
    // seqpacket socket with unread data can reset the peer's receipt.
    var packet: [1]u8 = undefined;
    const received = linux.recvfrom(
        fd,
        &packet,
        packet.len,
        linux.MSG.DONTWAIT | linux.MSG.TRUNC,
        null,
        null,
    );
    switch (linux.errno(received)) {
        .SUCCESS, .AGAIN, .INTR => {},
        else => |err| std.log.warn("resident busy request read failed: {s}", .{@tagName(err)}),
    }
    send(fd, "error:ControlBusy\n") catch |err| {
        std.log.warn("resident busy receipt failed: {s}", .{@errorName(err)});
    };
}

fn respond(self: *Self, bytes: []const u8) void {
    std.debug.assert(self.client >= 0);
    send(self.client, bytes) catch |err| {
        std.log.warn("resident receipt failed: {s}", .{@errorName(err)});
    };
    self.closeClient();
}

/// Completes an admitted request once; no receipt is sent to an unadmitted client.
pub fn reply(self: *Self, bytes: []const u8) void {
    if (!self.pending) return;
    self.respond(bytes);
}

/// Completes an admitted request with its originating capability error.
// zig-audit: acknowledge anyerror
// reason: Capability failures cross this receipt boundary without narrowing or losing their names.
pub fn reject(self: *Self, err: anyerror) void {
    if (!self.pending) return;
    self.respondError(@errorName(err));
}

fn respondError(self: *Self, name: []const u8) void {
    var buffer: [128]u8 = undefined;
    const receipt = std.fmt.bufPrint(&buffer, "error:{s}\n", .{name}) catch
        "error:ControlRejected\n";
    self.respond(receipt);
}

/// Advances one accept and one request packet using the monotonic millisecond tick.
/// A returned command owns the reply until completion, expiry or disconnection.
pub fn advance(self: *Self, now: u64) !?Command {
    std.debug.assert(self.listener >= 0);
    std.debug.assert((self.client >= 0) == (self.deadline != null));
    if (self.pending) std.debug.assert(self.client >= 0);

    if (self.deadline) |end| {
        if (now >= end) self.respondError("ControlTimedOut");
    }
    const result = linux.accept4(
        self.listener,
        null,
        null,
        posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK,
    );
    switch (linux.errno(result)) {
        .SUCCESS => {
            const accepted: posix.fd_t = @intCast(result);
            authenticate(accepted) catch |err| {
                std.log.warn("resident control peer refused: {s}", .{@errorName(err)});
                closeFd(accepted);
                return null;
            };
            if (self.client >= 0) {
                rejectBusy(accepted);
            } else {
                self.client = accepted;
                self.deadline = now + request_timeout_ms;
            }
        },
        .AGAIN, .INTR => {},
        else => return error.ControlAcceptFailed,
    }
    if (self.client < 0) return null;
    var bytes: [32]u8 = undefined;
    const n = linux.recvfrom(
        self.client,
        &bytes,
        bytes.len,
        linux.MSG.DONTWAIT | linux.MSG.TRUNC,
        null,
        null,
    );
    switch (linux.errno(n)) {
        .AGAIN, .INTR => return null,
        .SUCCESS => {},
        else => {
            self.closeClient();
            return null;
        },
    }
    if (n == 0) {
        self.closeClient();
        return null;
    }
    if (n > bytes.len or self.pending) {
        self.respondError("ControlRequestInvalid");
        return null;
    }
    const command = std.meta.stringToEnum(Command, bytes[0..n]) orelse {
        self.respondError("ControlRequestInvalid");
        return null;
    };
    self.pending = true;
    self.deadline = now + receipt_timeout_ms;
    return command;
}

/// Authenticates the server, sends one command and borrows one bounded receipt from buffer.
/// The client waits at most receipt_timeout_ms after sending.
pub fn call(
    io: std.Io,
    signature: []const u8,
    command: Command,
    buffer: *[capacity]u8,
) ![]const u8 {
    const addr = try address(signature);
    const fd = try socket();
    defer closeFd(fd);
    switch (linux.errno(linux.connect(fd, &addr.value, addr.length))) {
        .SUCCESS => {},
        .CONNREFUSED, .NOENT => return error.ResidentUnavailable,
        .AGAIN => return error.ControlBusy,
        else => return error.ControlConnectFailed,
    }
    try authenticate(fd);
    try send(fd, @tagName(command));
    const started = std.Io.Clock.awake.now(io);
    while (true) {
        const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
        if (elapsed >= receipt_timeout_ms) return error.ControlTimedOut;
        var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
        if (try posix.poll(&fds, @intCast(receipt_timeout_ms - elapsed)) == 0) {
            return error.ControlTimedOut;
        }
        if (fds[0].revents & posix.POLL.IN == 0 and fds[0].revents & failure_events != 0) {
            return error.ControlDisconnected;
        }
        const n = linux.recvfrom(
            fd,
            buffer,
            buffer.len,
            linux.MSG.DONTWAIT | linux.MSG.TRUNC,
            null,
            null,
        );
        switch (linux.errno(n)) {
            .AGAIN, .INTR => continue,
            .SUCCESS => {},
            else => return error.ControlReceiveFailed,
        }
        if (n == 0 or n > buffer.len) return error.ControlReceiptInvalid;
        return buffer[0..n];
    }
}

test "one session control owner; unknown and oversized identities refused" {
    const signature = "12345678901234567890123456789012";
    var owner = try open(signature);
    defer owner.deinit();
    try std.testing.expectError(error.ResidentAlreadyRunning, open(signature));
    try std.testing.expectError(error.SessionIdentityInvalid, open("invalid"));
    try std.testing.expectError(error.SessionIdentityInvalid, open(signature ++ "x"));
    try std.testing.expectError(error.SessionIdentityInvalid, open("/" ++ signature[1..]));
    try std.testing.expectError(error.SessionIdentityInvalid, open("\x00" ++ signature[1..]));
}

test "control rejects invalid and oversized packets without losing its listener" {
    const identity = "32109876543210987654321098765432";
    var owner = try open(identity);
    defer owner.deinit();
    const addr = try address(identity);
    for ([_][]const u8{ "not-a-command", &(@as([64]u8, @splat('x'))), "status" }) |packet| {
        const fd = try socket();
        defer closeFd(fd);
        try std.testing.expectEqual(
            linux.E.SUCCESS,
            linux.errno(linux.connect(fd, &addr.value, addr.length)),
        );
        try send(fd, packet);
        const command = try owner.advance(100);
        if (std.mem.eql(u8, packet, "status")) {
            try std.testing.expectEqual(Command.status, command.?);
            owner.reply("ok\n");
        } else try std.testing.expect(command == null);
        var response: [128]u8 = undefined;
        const count = linux.recvfrom(fd, &response, response.len, 0, null, null);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(count));
        const expected = if (std.mem.eql(u8, packet, "status"))
            "ok\n"
        else
            "error:ControlRequestInvalid\n";
        try std.testing.expect(count <= response.len);
        try std.testing.expectEqualStrings(expected, response[0..count]);
        try std.testing.expect(owner.client == -1 and !owner.pending);
    }
}

fn connectTest(signature: []const u8) !posix.fd_t {
    const addr = try address(signature);
    const fd = try socket();
    errdefer closeFd(fd);
    try std.testing.expectEqual(
        linux.E.SUCCESS,
        linux.errno(linux.connect(fd, &addr.value, addr.length)),
    );
    try authenticate(fd);
    return fd;
}

fn expectReceiptTest(fd: posix.fd_t, expected: []const u8) !void {
    var buffer: [capacity]u8 = undefined;
    const count = linux.recvfrom(
        fd,
        &buffer,
        buffer.len,
        linux.MSG.DONTWAIT | linux.MSG.TRUNC,
        null,
        null,
    );
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(count));
    try std.testing.expect(count <= buffer.len);
    try std.testing.expectEqualStrings(expected, buffer[0..count]);
}

test "peer credentials require a connected same-user socket" {
    const fd = try socket();
    defer closeFd(fd);
    try std.testing.expectError(error.ControlPeerInvalid, authenticate(fd));
    var pipe: [2]posix.fd_t = undefined;
    try std.testing.expectEqual(
        linux.E.SUCCESS,
        linux.errno(linux.pipe2(&pipe, .{ .CLOEXEC = true })),
    );
    defer closeFd(pipe[0]);
    defer closeFd(pipe[1]);
    try std.testing.expectError(error.ControlCredentialsUnavailable, authenticate(pipe[0]));
}

test "busy peer cannot replace an admitted request" {
    const signature = "busy-peer-keeps-original-request";
    var owner = try open(signature);
    defer owner.deinit();
    const first = try connectTest(signature);
    defer closeFd(first);
    try send(first, "rotate");
    try std.testing.expectEqual(@as(?Command, .rotate), try owner.advance(100));
    const current = owner.client;
    const deadline = owner.deadline;

    const second = try connectTest(signature);
    defer closeFd(second);
    try send(second, "status");
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(101));
    try expectReceiptTest(second, "error:ControlBusy\n");
    try std.testing.expectEqual(current, owner.client);
    try std.testing.expectEqual(deadline, owner.deadline);
    try std.testing.expect(owner.pending);

    const silent = try connectTest(signature);
    defer closeFd(silent);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(102));
    try expectReceiptTest(silent, "error:ControlBusy\n");
    try std.testing.expectEqual(current, owner.client);
    try std.testing.expectEqual(deadline, owner.deadline);

    owner.reply("ok\n");
    try expectReceiptTest(first, "ok\n");
    try std.testing.expectEqual(linux.E.BADF, linux.errno(linux.fcntl(current, linux.F.GETFD, 0)));
    try std.testing.expect(!owner.pending and owner.deadline == null and owner.client == -1);
}

test "incomplete and admitted requests expire at their own deadline" {
    const signature = "control-request-deadline-test-00";
    var owner = try open(signature);
    defer owner.deinit();
    const first = try connectTest(signature);
    defer closeFd(first);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(100));
    try std.testing.expectEqual(@as(?u64, 2100), owner.deadline);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(2099));
    try std.testing.expect(owner.client >= 0 and !owner.pending);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(2100));
    try expectReceiptTest(first, "error:ControlTimedOut\n");
    try std.testing.expect(owner.client == -1 and owner.deadline == null);

    const second = try connectTest(signature);
    defer closeFd(second);
    try send(second, "rotate");
    try std.testing.expectEqual(@as(?Command, .rotate), try owner.advance(2200));
    try std.testing.expectEqual(@as(?u64, 32200), owner.deadline);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(32199));
    try std.testing.expect(owner.pending);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(32200));
    try expectReceiptTest(second, "error:ControlTimedOut\n");
    try std.testing.expect(owner.client == -1 and owner.deadline == null and !owner.pending);
}

test "duplicate packet cannot obtain a second command while a reply is pending" {
    const signature = "control-duplicate-packet-test-00";
    var owner = try open(signature);
    defer owner.deinit();
    const fd = try connectTest(signature);
    defer closeFd(fd);
    try send(fd, "rotate");
    try std.testing.expectEqual(@as(?Command, .rotate), try owner.advance(10));
    try send(fd, "status");
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(11));
    try expectReceiptTest(fd, "error:ControlRequestInvalid\n");
    try std.testing.expect(owner.client == -1 and !owner.pending and owner.deadline == null);
}

test "late completion cannot reply to a newly connected unadmitted peer" {
    const signature = "control-late-completion-test-000";
    var owner = try open(signature);
    defer owner.deinit();
    {
        const first = try connectTest(signature);
        defer closeFd(first);
        try send(first, "rotate");
        try std.testing.expectEqual(@as(?Command, .rotate), try owner.advance(100));
    }
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(101));
    try std.testing.expect(!owner.pending and owner.client == -1);

    const next = try connectTest(signature);
    defer closeFd(next);
    try std.testing.expectEqual(@as(?Command, null), try owner.advance(102));
    const accepted = owner.client;
    try std.testing.expect(accepted >= 0 and !owner.pending);
    owner.reply("ok\n");
    owner.reject(error.RotationRejected);
    try std.testing.expectEqual(accepted, owner.client);
    var fds = [_]posix.pollfd{.{ .fd = next, .events = posix.POLL.IN, .revents = 0 }};
    try std.testing.expectEqual(@as(usize, 0), try posix.poll(&fds, 0));

    try send(next, "status");
    try std.testing.expectEqual(@as(?Command, .status), try owner.advance(103));
    owner.reply("fresh\n");
    try expectReceiptTest(next, "fresh\n");
}
