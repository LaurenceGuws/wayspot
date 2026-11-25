//! Bounded same-user session commands. One seqpacket per request and receipt.
const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const Self = @This();

pub const Command = enum { summon, dismiss, rotate, status };
const capacity = 1024;
const Address = struct { value: posix.sockaddr.un, length: posix.socklen_t };
const Credentials = extern struct { pid: c_int, uid: c_uint, gid: c_uint };
const failure_events = posix.POLL.ERR | posix.POLL.HUP | posix.POLL.NVAL;

listener: posix.fd_t = -1,
client: posix.fd_t = -1,
deadline: ?u64 = null,
pending: bool = false,

fn address(signature: []const u8) !Address {
    const prefix = "wayspot-resident:";
    if (signature.len != 32 or std.mem.indexOfAny(u8, signature, "\x00/") != null) return error.SessionIdentityInvalid;
    var value: posix.sockaddr.un = .{ .family = posix.AF.UNIX, .path = @splat(0) };
    @memcpy(value.path[1..][0..prefix.len], prefix);
    @memcpy(value.path[1 + prefix.len ..][0..signature.len], signature);
    return .{ .value = value, .length = @intCast(@offsetOf(posix.sockaddr.un, "path") + 1 + prefix.len + signature.len) };
}

fn socket() !posix.fd_t {
    const result = linux.socket(posix.AF.UNIX, posix.SOCK.SEQPACKET | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK, 0);
    if (linux.errno(result) != .SUCCESS) return error.ControlSocketOpenFailed;
    return @intCast(result);
}

fn authenticate(fd: posix.fd_t) !void {
    var credentials: Credentials = undefined;
    var length: posix.socklen_t = @sizeOf(Credentials);
    if (posix.errno(posix.system.getsockopt(fd, posix.SOL.SOCKET, linux.SO.PEERCRED, @ptrCast(&credentials), &length)) != .SUCCESS or length != @sizeOf(Credentials)) return error.ControlCredentialsUnavailable;
    if (credentials.uid != linux.geteuid()) return error.ControlPeerInvalid;
}

pub fn open(signature: []const u8) !Self {
    const addr = try address(signature);
    const fd = try socket();
    errdefer _ = linux.close(fd);
    switch (linux.errno(linux.bind(fd, @ptrCast(&addr.value), addr.length))) {
        .SUCCESS => {},
        .ADDRINUSE => return error.ResidentAlreadyRunning,
        else => return error.ControlBindFailed,
    }
    if (linux.errno(linux.listen(fd, 8)) != .SUCCESS) return error.ControlListenFailed;
    return .{ .listener = fd };
}

pub fn deinit(self: *Self) void {
    self.closeClient();
    if (self.listener >= 0) _ = linux.close(self.listener);
    self.* = .{};
}

fn closeClient(self: *Self) void {
    if (self.client >= 0) _ = linux.close(self.client);
    self.client = -1;
    self.deadline = null;
    self.pending = false;
}

fn send(fd: posix.fd_t, bytes: []const u8) !void {
    const result = linux.sendto(fd, bytes.ptr, bytes.len, linux.MSG.DONTWAIT | linux.MSG.NOSIGNAL, null, 0);
    if (linux.errno(result) != .SUCCESS or result != bytes.len) return error.ControlSendFailed;
}

pub fn reply(self: *Self, bytes: []const u8) void {
    if (self.client < 0) return;
    send(self.client, bytes) catch |err| std.log.warn("resident receipt failed: {s}", .{@errorName(err)});
    self.closeClient();
}

pub fn reject(self: *Self, err: anyerror) void {
    var buffer: [128]u8 = undefined;
    self.reply(std.fmt.bufPrint(&buffer, "error:{s}\n", .{@errorName(err)}) catch "error:ControlRejected\n");
}

pub fn advance(self: *Self, now: u64) !?Command {
    if (self.deadline) |end| if (now >= end) self.reject(error.ControlTimedOut);
    const result = linux.accept4(self.listener, null, null, posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK);
    switch (linux.errno(result)) {
        .SUCCESS => {
            const accepted: posix.fd_t = @intCast(result);
            authenticate(accepted) catch {
                _ = linux.close(accepted);
                return null;
            };
            if (self.client >= 0) {
                send(accepted, "error:ControlBusy\n") catch {};
                _ = linux.close(accepted);
            } else {
                self.client = accepted;
                self.deadline = now + 2000;
            }
        },
        .AGAIN, .INTR => {},
        else => return error.ControlAcceptFailed,
    }
    if (self.client < 0) return null;
    var bytes: [32]u8 = undefined;
    const n = linux.recvfrom(self.client, &bytes, bytes.len, linux.MSG.DONTWAIT | linux.MSG.TRUNC, null, null);
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
        self.reject(error.ControlRequestInvalid);
        return null;
    }
    const command = std.meta.stringToEnum(Command, bytes[0..n]) orelse {
        self.reject(error.ControlRequestInvalid);
        return null;
    };
    self.pending = true;
    self.deadline = now + 30_000;
    return command;
}

pub fn call(io: std.Io, signature: []const u8, command: Command, buffer: *[capacity]u8) ![]const u8 {
    const addr = try address(signature);
    const fd = try socket();
    defer _ = linux.close(fd);
    switch (linux.errno(linux.connect(fd, @ptrCast(&addr.value), addr.length))) {
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
        if (elapsed >= 30_000) return error.ControlTimedOut;
        var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
        if (try posix.poll(&fds, @intCast(30_000 - elapsed)) == 0) return error.ControlTimedOut;
        if (fds[0].revents & posix.POLL.IN == 0 and fds[0].revents & failure_events != 0) return error.ControlDisconnected;
        const n = linux.recvfrom(fd, buffer, buffer.len, linux.MSG.DONTWAIT | linux.MSG.TRUNC, null, null);
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
}

test "control rejects invalid and oversized packets without losing its listener" {
    const identity = "32109876543210987654321098765432";
    var owner = try open(identity);
    defer owner.deinit();
    const addr = try address(identity);
    for ([_][]const u8{ "not-a-command", &(@as([64]u8, @splat('x'))), "status" }) |packet| {
        const fd = try socket();
        defer _ = linux.close(fd);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.connect(fd, @ptrCast(&addr.value), addr.length)));
        try send(fd, packet);
        const command = try owner.advance(100);
        if (std.mem.eql(u8, packet, "status")) {
            try std.testing.expectEqual(Command.status, command.?);
            owner.reply("ok\n");
        } else try std.testing.expect(command == null);
        var response: [128]u8 = undefined;
        const count = linux.recvfrom(fd, &response, response.len, 0, null, null);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(count));
        try std.testing.expectEqualStrings(if (std.mem.eql(u8, packet, "status")) "ok\n" else "error:ControlRequestInvalid\n", response[0..count]);
        try std.testing.expect(owner.client == -1 and !owner.pending);
    }
}
