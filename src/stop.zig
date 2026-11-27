//! The process termination fd, shared by the standalone and resident loops.
const std = @import("std");
const Self = @This();

fd: std.posix.fd_t,
prior_mask: std.posix.sigset_t,

/// Blocks SIGINT and SIGTERM on the calling thread and opens their signalfd.
/// The owner must close it on that same thread, restoring its prior mask.
pub fn open() !Self {
    var mask = std.posix.sigemptyset();
    std.posix.sigaddset(&mask, .INT);
    std.posix.sigaddset(&mask, .TERM);
    var prior: std.posix.sigset_t = undefined;
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, &prior);
    errdefer std.posix.sigprocmask(std.posix.SIG.SETMASK, &prior, null);
    return .{
        .fd = try std.posix.signalfd(
            -1,
            &mask,
            std.os.linux.SFD.CLOEXEC | std.os.linux.SFD.NONBLOCK,
        ),
        .prior_mask = prior,
    };
}

/// Retires the uniquely owned signalfd and restores the opening thread's signal mask.
pub fn close(stop: Self) void {
    defer std.posix.sigprocmask(std.posix.SIG.SETMASK, &stop.prior_mask, null);
    // Linux releases the descriptor even on EINTR. Never retry a close:
    // another thread could already have reused the descriptor number.
    switch (std.posix.errno(std.posix.system.close(stop.fd))) {
        .SUCCESS, .INTR => {},
        else => |err| std.log.err("termination descriptor close failed: {s}", .{@tagName(err)}),
    }
}

/// Consumes one complete termination record after readiness on the borrowed fd.
/// Short records and read errors fail rather than report a termination event.
pub fn consume(io: std.Io, fd: std.posix.fd_t) !void {
    var record: [128]u8 = undefined;
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    if (try file.readStreaming(io, &.{&record}) != record.len) return error.StopRecordIncomplete;
}

test "termination descriptor owns real signals and restores its opening mask" {
    const posix = std.posix;
    const linux = std.os.linux;
    var original: posix.sigset_t = undefined;
    posix.sigprocmask(posix.SIG.SETMASK, null, &original);
    defer posix.sigprocmask(posix.SIG.SETMASK, &original, null);

    var prior = original;
    posix.sigdelset(&prior, .INT);
    posix.sigaddset(&prior, .TERM);
    posix.sigaddset(&prior, .USR1);
    posix.sigprocmask(posix.SIG.SETMASK, &prior, null);

    const fd = block: {
        const stop = try open();
        defer stop.close();

        var blocked: posix.sigset_t = undefined;
        posix.sigprocmask(posix.SIG.SETMASK, null, &blocked);
        try std.testing.expect(posix.sigismember(&blocked, .INT));
        try std.testing.expect(posix.sigismember(&blocked, .TERM));
        try std.testing.expect(posix.sigismember(&blocked, .USR1));

        const descriptor_flags = linux.fcntl(stop.fd, linux.F.GETFD, 0);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(descriptor_flags));
        try std.testing.expect(descriptor_flags & linux.FD_CLOEXEC != 0);
        const status_flags = linux.fcntl(stop.fd, linux.F.GETFL, 0);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(status_flags));
        const flags: linux.O = @bitCast(@as(u32, @intCast(status_flags)));
        try std.testing.expect(flags.NONBLOCK);

        var fds = [_]posix.pollfd{.{ .fd = stop.fd, .events = posix.POLL.IN, .revents = 0 }};
        try std.testing.expectEqual(@as(usize, 0), try posix.poll(&fds, 0));
        for ([_]posix.SIG{ .INT, .TERM }) |signal| {
            // raise targets the calling test thread, not the desktop or other tests.
            try posix.raise(signal);
            try std.testing.expectEqual(@as(usize, 1), try posix.poll(&fds, 0));
            try std.testing.expect(fds[0].revents & posix.POLL.IN != 0);
            try consume(std.testing.io, stop.fd);
            try std.testing.expectEqual(@as(usize, 0), try posix.poll(&fds, 0));
        }
        break :block stop.fd;
    };

    var restored: posix.sigset_t = undefined;
    posix.sigprocmask(posix.SIG.SETMASK, null, &restored);
    try std.testing.expect(!posix.sigismember(&restored, .INT));
    try std.testing.expect(posix.sigismember(&restored, .TERM));
    try std.testing.expect(posix.sigismember(&restored, .USR1));
    try std.testing.expectEqual(linux.E.BADF, linux.errno(linux.fcntl(fd, linux.F.GETFD, 0)));
}

test "termination consume rejects a short record" {
    const linux = std.os.linux;
    var fds: [2]std.posix.fd_t = undefined;
    try std.testing.expectEqual(linux.E.SUCCESS, linux.errno(linux.pipe2(
        &fds,
        .{ .CLOEXEC = true, .NONBLOCK = true },
    )));
    const reader: std.Io.File = .{ .handle = fds[0], .flags = .{ .nonblocking = true } };
    defer reader.close(std.testing.io);
    const writer: std.Io.File = .{ .handle = fds[1], .flags = .{ .nonblocking = true } };
    defer writer.close(std.testing.io);
    try writer.writeStreamingAll(std.testing.io, "short");
    try std.testing.expectError(error.StopRecordIncomplete, consume(std.testing.io, reader.handle));
}
