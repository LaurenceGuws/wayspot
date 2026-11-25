//! The process termination fd, shared by the standalone and resident loops.
const std = @import("std");
const Self = @This();

fd: std.posix.fd_t,
prior_mask: std.posix.sigset_t,

/// Blocks termination signals and returns their signalfd plus the exact prior mask.
pub fn open() !Self {
    var mask = std.posix.sigemptyset();
    std.posix.sigaddset(&mask, .INT);
    std.posix.sigaddset(&mask, .TERM);
    var prior: std.posix.sigset_t = undefined;
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, &prior);
    errdefer std.posix.sigprocmask(std.posix.SIG.SETMASK, &prior, null);
    return .{
        .fd = try std.posix.signalfd(-1, &mask, std.os.linux.SFD.CLOEXEC | std.os.linux.SFD.NONBLOCK),
        .prior_mask = prior,
    };
}

/// Closes the signalfd and restores the prior signal mask.
pub fn close(stop: Self) void {
    _ = std.posix.system.close(stop.fd);
    std.posix.sigprocmask(std.posix.SIG.SETMASK, &stop.prior_mask, null);
}

pub fn consume(io: std.Io, fd: std.posix.fd_t) !void {
    var record: [128]u8 = undefined;
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    if (try file.readStreaming(io, &.{&record}) != record.len) return error.StopRecordIncomplete;
}
