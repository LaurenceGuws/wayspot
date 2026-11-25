// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A compositor for tests to play: a `Connection` at one end of a
//! socketpair, and the other end for the test to write events into and read
//! requests out of.
//!
//! Nothing here needs a second thread: a socket buffers in both directions,
//! and object ids are allocated deterministically, so a test can write the
//! compositor's replies before the client asks for them, and read the
//! client's requests after it has sent them.

const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const protocol = @import("protocol");
const Connection = @import("client").Connection;

const Fd = protocol.Fd;

/// One request the client sent, as the compositor sees it.
pub const Request = struct {
    object: protocol.ObjectId,
    opcode: u16,
    /// The arguments, a word at a time.
    words: []const u32,
};

pub const Pair = struct {
    conn: Connection,
    server: Fd,

    pub fn init() !Pair {
        var fds: [2]i32 = undefined;
        try testing.expectEqual(@as(usize, 0), linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0, &fds));
        return .{ .conn = try .fromFd(testing.allocator, testing.io, fds[0]), .server = fds[1] };
    }

    pub fn deinit(p: *Pair) void {
        p.conn.deinit();
        if (p.server >= 0) _ = linux.close(p.server);
    }

    /// Sends an event from the compositor's end, with `fds` beside it.
    pub fn send(p: *Pair, object: protocol.ObjectId, interface: *const protocol.Interface, opcode: u16, args: []const protocol.Arg, fds: []const Fd) !void {
        var buf: [protocol.wire.max_message_size]u8 = undefined;
        const size = try protocol.wire.encodedSize(interface.events[opcode].args, args);
        protocol.wire.encode(buf[0..size], object, opcode, args);

        var control: [64]u8 align(@alignOf(linux.cmsghdr)) = undefined;
        const header: *linux.cmsghdr = @ptrCast(&control);
        header.* = .{ .len = @sizeOf(linux.cmsghdr) + fds.len * @sizeOf(Fd), .level = linux.SOL.SOCKET, .type = linux.SCM.RIGHTS };
        @memcpy(control[@sizeOf(linux.cmsghdr)..][0 .. fds.len * @sizeOf(Fd)], std.mem.sliceAsBytes(fds));
        const iov: [1]std.posix.iovec_const = .{.{ .base = &buf, .len = size }};
        const msg: linux.msghdr_const = .{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = 1,
            .control = if (fds.len == 0) null else &control,
            .controllen = if (fds.len == 0) 0 else std.mem.alignForward(usize, header.len, 8),
            .flags = 0,
        };
        try testing.expectEqual(size, linux.sendmsg(p.server, &msg, 0));
    }

    /// Reads exactly `bytes.len` bytes the client sent, and whatever file
    /// descriptors came with them.
    pub fn receive(p: *Pair, bytes: []u8, fds: *std.ArrayList(Fd)) !void {
        var got: usize = 0;
        while (got < bytes.len) {
            var iov: [1]std.posix.iovec = .{.{ .base = bytes[got..].ptr, .len = bytes.len - got }};
            var control: [256]u8 align(@alignOf(linux.cmsghdr)) = undefined;
            var msg: linux.msghdr = .{
                .name = null,
                .namelen = 0,
                .iov = &iov,
                .iovlen = 1,
                .control = &control,
                .controllen = control.len,
                .flags = 0,
            };
            const rc = linux.recvmsg(p.server, &msg, linux.MSG.CMSG_CLOEXEC);
            try testing.expectEqual(std.posix.E.SUCCESS, std.posix.errno(rc));
            if (rc == 0) return error.EndOfStream;
            got += rc;
            if (msg.controllen >= @sizeOf(linux.cmsghdr)) {
                const header: *const linux.cmsghdr = @ptrCast(&control);
                const n = (header.len - @sizeOf(linux.cmsghdr)) / @sizeOf(Fd);
                const data: [*]const Fd = @ptrCast(@alignCast(control[@sizeOf(linux.cmsghdr)..].ptr));
                try fds.appendSlice(testing.allocator, data[0..n]);
            }
        }
    }

    /// Reads and discards everything the client has sent so far.
    pub fn drain(p: *Pair) !void {
        var buf: [4096]u8 = undefined;
        var iov: [1]std.posix.iovec = .{.{ .base = &buf, .len = buf.len }};
        var msg: linux.msghdr = .{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = 1,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };
        while (std.posix.errno(linux.recvmsg(p.server, &msg, linux.MSG.DONTWAIT)) == .SUCCESS) {}
    }

    /// Every request the client has sent and not yet been read, parsed.
    /// File descriptors that came with them go in `fds`, or are closed if it
    /// is null. Free with `freeRequests`.
    pub fn requests(p: *Pair, fds: ?*std.ArrayList(Fd)) ![]Request {
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(testing.allocator);
        var buf: [4096]u8 align(4) = undefined;
        while (true) {
            var iov: [1]std.posix.iovec = .{.{ .base = &buf, .len = buf.len }};
            var control: [256]u8 align(@alignOf(linux.cmsghdr)) = undefined;
            var msg: linux.msghdr = .{
                .name = null,
                .namelen = 0,
                .iov = &iov,
                .iovlen = 1,
                .control = &control,
                .controllen = control.len,
                .flags = 0,
            };
            const rc = linux.recvmsg(p.server, &msg, linux.MSG.DONTWAIT | linux.MSG.CMSG_CLOEXEC);
            if (std.posix.errno(rc) != .SUCCESS or rc == 0) break;
            try bytes.appendSlice(testing.allocator, buf[0..rc]);
            if (msg.controllen >= @sizeOf(linux.cmsghdr)) {
                const header: *const linux.cmsghdr = @ptrCast(&control);
                const n = (header.len - @sizeOf(linux.cmsghdr)) / @sizeOf(Fd);
                const data: [*]const Fd = @ptrCast(@alignCast(control[@sizeOf(linux.cmsghdr)..].ptr));
                for (data[0..n]) |fd| {
                    if (fds) |list| try list.append(testing.allocator, fd) else _ = linux.close(fd);
                }
            }
        }

        var list: std.ArrayList(Request) = .empty;
        errdefer freeRequests(list.items);
        var offset: usize = 0;
        while (offset < bytes.items.len) {
            const header = protocol.wire.Header.decode(bytes.items[offset..][0..8]);
            const payload = bytes.items[offset + 8 .. offset + header.size];
            const words = try testing.allocator.alloc(u32, payload.len / 4);
            for (words, 0..) |*w, i| w.* = std.mem.readInt(u32, payload[i * 4 ..][0..4], @import("builtin").cpu.arch.endian());
            try list.append(testing.allocator, .{ .object = header.object, .opcode = header.opcode, .words = words });
            offset += header.size;
        }
        return list.toOwnedSlice(testing.allocator);
    }
};

pub fn freeRequests(list: []const Request) void {
    for (list) |r| testing.allocator.free(r.words);
    testing.allocator.free(list);
}
