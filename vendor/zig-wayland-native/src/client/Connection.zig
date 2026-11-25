// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A connection to a Wayland compositor: a Unix socket, and a
//! `protocol.Session` to make sense of what goes over it.
//!
//! Requests go through the generated bindings straight into `session`, and sit
//! there until `flush` -- or anything that waits for the compositor, which
//! flushes first. Events come back through listeners, one per object, set with
//! `setListener` and called from `dispatch`.
//!
//! One thing about this connection is not what the standard library would
//! have done. `std.Io.net` can send and receive ancillary data, but its
//! `sendmsg` always names a destination address, and Linux refuses one on a
//! connected stream socket with `EISCONN`. So the socket is connected through
//! `std.Io.net` and then read and written with `sendmsg(2)` and `recvmsg(2)`
//! directly, which is also what makes this module Linux-only.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const linux = std.os.linux;
const protocol = @import("protocol");
const Fd = protocol.Fd;

const Connection = @This();

comptime {
    if (builtin.os.tag != .linux) @compileError("the Wayland client module is Linux-only");
}

gpa: Allocator,
io: Io,
/// The socket. Useful for waiting on with `poll(2)` alongside something else;
/// see `read`.
fd: Fd,
session: protocol.Session,

/// What a listener looks like once its types have been erased. `setListener`
/// makes one of these from a typed handler.
pub const Listener = fn (data: ?*anyopaque, connection: *Connection, msg: protocol.Message) anyerror!void;

pub const ConnectError = Allocator.Error || Io.net.UnixAddress.ConnectError || error{
    /// `WAYLAND_DISPLAY` is a relative name and `XDG_RUNTIME_DIR` is not set,
    /// so there is nowhere to look for it.
    NoRuntimeDir,
    /// `WAYLAND_SOCKET` is set but is not a file descriptor number.
    InvalidWaylandSocket,
    /// The socket path is longer than a Unix socket address can hold.
    NameTooLong,
};

pub const IoError = Allocator.Error || error{
    /// The compositor closed the connection.
    ConnectionClosed,
    /// The compositor sent more file descriptors than there was room to
    /// receive, and the rest were lost.
    FileDescriptorsTruncated,
    Unexpected,
};

/// Connects the way libwayland does, reading the environment:
///
/// 1. `WAYLAND_SOCKET`, a file descriptor already connected, which is how a
///    compositor launches a client it wants to talk to privately. It is used
///    as it is and made close-on-exec.
/// 2. Otherwise `WAYLAND_DISPLAY`, default `wayland-0`: a socket path, taken
///    as it is if absolute and relative to `XDG_RUNTIME_DIR` if not.
pub fn connect(gpa: Allocator, io: Io, environ: *const std.process.Environ.Map) ConnectError!Connection {
    if (environ.get("WAYLAND_SOCKET")) |text| {
        const fd = std.fmt.parseInt(Fd, text, 10) catch return error.InvalidWaylandSocket;
        if (fd < 0) return error.InvalidWaylandSocket;
        _ = linux.fcntl(fd, linux.F.SETFD, linux.FD_CLOEXEC);
        return fromFd(gpa, io, fd);
    }
    const display = environ.get("WAYLAND_DISPLAY") orelse "wayland-0";
    if (std.fs.path.isAbsolute(display)) return connectToPath(gpa, io, display);
    const runtime_dir = environ.get("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const path = try std.fs.path.join(gpa, &.{ runtime_dir, display });
    defer gpa.free(path);
    return connectToPath(gpa, io, path);
}

/// Connects to the compositor listening at `path`.
pub fn connectToPath(gpa: Allocator, io: Io, path: []const u8) ConnectError!Connection {
    const address = try Io.net.UnixAddress.init(path);
    const stream = try address.connect(io);
    errdefer _ = linux.close(stream.socket.handle);
    return fromFd(gpa, io, stream.socket.handle);
}

/// Speaks Wayland over a socket that is already connected, and takes
/// ownership of it.
pub fn fromFd(gpa: Allocator, io: Io, fd: Fd) Allocator.Error!Connection {
    return .{ .gpa = gpa, .io = io, .fd = fd, .session = try .init(gpa) };
}

/// Closes the socket and every file descriptor received and not handed out.
/// Nothing is flushed: call `flush` first if it matters.
pub fn deinit(c: *Connection) void {
    c.session.discardUnreadFds() catch {};
    c.closeDiscarded();
    c.session.deinit();
    _ = linux.close(c.fd);
    c.* = undefined;
}

// -- listeners ---------------------------------------------------------------

/// Calls `handler` for every event `object` receives, until the object is
/// destroyed or another listener replaces this one.
///
/// `handler` is `fn (@TypeOf(context), *Connection, @TypeOf(object),
/// @TypeOf(object).Event) void`, or the same returning an error union, whose
/// errors come out of `dispatch`. `context` is a pointer, or `{}` for none.
///
/// Strings and arrays in the event borrow from the connection's input
/// buffer and are valid only until the handler returns. File descriptors in
/// it belong to the handler, which must close them.
///
/// A handler may send requests, but must not dispatch.
pub fn setListener(c: *Connection, object: anytype, context: anytype, comptime handler: anytype) error{InvalidObject}!void {
    const T = @TypeOf(object);
    const Ctx = @TypeOf(context);
    const Trampoline = struct {
        fn call(data: ?*anyopaque, connection: *Connection, msg: protocol.Message) anyerror!void {
            const ctx: Ctx = fromOpaque(Ctx, data);
            const event = try T.Event.decode(msg);
            const result = handler(ctx, connection, T{ .id = msg.object }, event);
            if (@typeInfo(@TypeOf(result)) == .error_union) try result;
        }
    };
    const f: *const Listener = &Trampoline.call;
    try c.session.setUserData(object.id, toOpaque(context), @ptrCast(f));
}

/// Stops calling whatever listener `object` has. Its events are still
/// decoded, and any file descriptors in them closed.
pub fn clearListener(c: *Connection, object: anytype) error{InvalidObject}!void {
    try c.session.setUserData(object.id, null, null);
}

fn toOpaque(context: anytype) ?*anyopaque {
    const Ctx = @TypeOf(context);
    return switch (@typeInfo(Ctx)) {
        .void => null,
        .pointer => @ptrCast(@constCast(context)),
        .optional => if (context) |p| @ptrCast(@constCast(p)) else null,
        else => @compileError("a listener's context is a pointer or {}, not " ++ @typeName(Ctx)),
    };
}

fn fromOpaque(comptime Ctx: type, data: ?*anyopaque) Ctx {
    return switch (@typeInfo(Ctx)) {
        .void => {},
        .pointer => @ptrCast(@alignCast(data.?)),
        .optional => if (data) |p| @ptrCast(@alignCast(p)) else null,
        else => unreachable,
    };
}

// -- sending -----------------------------------------------------------------

/// Sends everything queued, blocking until the socket has taken it.
pub fn flush(c: *Connection) IoError!void {
    while (true) {
        const batch = c.session.pending();
        if (batch.bytes.len == 0) return;
        const sent = try c.send(batch.bytes, batch.fds);
        c.session.consumed(sent, batch.fds.len);
    }
}

fn send(c: *Connection, bytes: []const u8, fds: []const Fd) IoError!usize {
    var control: [cmsgSpace(protocol.wire.max_fds_out)]u8 align(@alignOf(linux.cmsghdr)) = undefined;
    var controllen: usize = 0;
    if (fds.len > 0) {
        std.debug.assert(fds.len <= protocol.wire.max_fds_out);
        const header: *linux.cmsghdr = @ptrCast(&control);
        header.* = .{
            .len = @sizeOf(linux.cmsghdr) + fds.len * @sizeOf(Fd),
            .level = linux.SOL.SOCKET,
            .type = linux.SCM.RIGHTS,
        };
        @memcpy(control[@sizeOf(linux.cmsghdr)..][0 .. fds.len * @sizeOf(Fd)], std.mem.sliceAsBytes(fds));
        controllen = cmsgSpace(fds.len);
    }
    const iov: [1]std.posix.iovec_const = .{.{ .base = bytes.ptr, .len = bytes.len }};
    const msg: linux.msghdr_const = .{
        .name = null,
        .namelen = 0,
        .iov = &iov,
        .iovlen = 1,
        .control = if (controllen == 0) null else &control,
        .controllen = controllen,
        .flags = 0,
    };
    while (true) {
        const rc = linux.sendmsg(c.fd, &msg, linux.MSG.NOSIGNAL);
        switch (linux.errno(rc)) {
            .SUCCESS => return rc,
            .INTR => continue,
            .PIPE, .CONNRESET => return error.ConnectionClosed,
            .NOMEM, .NOBUFS => return error.OutOfMemory,
            else => return error.Unexpected,
        }
    }
}

// -- receiving ---------------------------------------------------------------

/// Reads whatever the compositor has sent, blocking until it has sent
/// something, and hands it to the session without dispatching any of it.
/// For an event loop that polls `fd` itself: when it is readable, `read` and
/// then `dispatchPending`.
pub fn read(c: *Connection) IoError!void {
    const buf = try c.session.readable(4096);
    var iov: [1]std.posix.iovec = .{.{ .base = buf.ptr, .len = buf.len }};
    var control: [cmsgSpace(protocol.wire.max_fds_out)]u8 align(@alignOf(linux.cmsghdr)) = undefined;
    var msg: linux.msghdr = .{
        .name = null,
        .namelen = 0,
        .iov = &iov,
        .iovlen = 1,
        .control = &control,
        .controllen = control.len,
        .flags = 0,
    };
    const received = while (true) {
        const rc = linux.recvmsg(c.fd, &msg, linux.MSG.CMSG_CLOEXEC | linux.MSG.NOSIGNAL);
        switch (linux.errno(rc)) {
            .SUCCESS => break rc,
            .INTR => continue,
            .CONNRESET => return error.ConnectionClosed,
            .NOMEM, .NOBUFS => return error.OutOfMemory,
            else => return error.Unexpected,
        }
    };

    // The descriptors are in this process now, whatever else happens, so
    // they are taken before anything can fail.
    var offset: usize = 0;
    var failed: ?Allocator.Error = null;
    while (offset + @sizeOf(linux.cmsghdr) <= msg.controllen) {
        const header: *align(1) const linux.cmsghdr = @ptrCast(control[offset..].ptr);
        if (header.len < @sizeOf(linux.cmsghdr) or offset + header.len > msg.controllen) break;
        if (header.level == linux.SOL.SOCKET and header.type == linux.SCM.RIGHTS) {
            const data = control[offset + @sizeOf(linux.cmsghdr) .. offset + header.len];
            var n: usize = 0;
            while (n + @sizeOf(Fd) <= data.len) : (n += @sizeOf(Fd)) {
                const fd = std.mem.readInt(Fd, data[n..][0..@sizeOf(Fd)], builtin.cpu.arch.endian());
                if (failed == null) {
                    c.session.receivedFd(fd) catch |e| {
                        failed = e;
                        _ = linux.close(fd);
                    };
                } else _ = linux.close(fd);
            }
        }
        offset += std.mem.alignForward(usize, header.len, @alignOf(linux.cmsghdr));
    }
    if (failed) |e| return e;
    if (msg.flags & linux.MSG.CTRUNC != 0) return error.FileDescriptorsTruncated;
    if (received == 0) return error.ConnectionClosed;
    c.session.received(received);
}

/// Dispatches every event already read, without reading more. Returns how
/// many there were.
pub fn dispatchPending(c: *Connection) anyerror!usize {
    var count: usize = 0;
    while (true) {
        const next = c.session.nextEvent();
        c.closeDiscarded();
        const msg = try next orelse return count;
        count += 1;
        if (msg.user_fn) |f| {
            const listener: *const Listener = @ptrCast(@alignCast(f));
            try listener(msg.user_data, c, msg);
        } else {
            for (msg.args) |arg| switch (arg) {
                .fd => |fd| _ = linux.close(fd),
                else => {},
            };
        }
    }
}

/// Flushes, then dispatches what has already been read, or if there is
/// nothing, blocks until the compositor sends something and dispatches that.
/// Returns how many events were dispatched, which may be none if what
/// arrived was only part of one.
///
/// Its errors are those of `flush`, `read` and `protocol.Session.nextEvent`,
/// and whatever a listener returned. After a `ProtocolError`,
/// `session.protocol_error` says what the compositor objected to.
pub fn dispatch(c: *Connection) anyerror!usize {
    try c.flush();
    const already = try c.dispatchPending();
    if (already > 0) return already;
    try c.read();
    return c.dispatchPending();
}

/// Blocks until the compositor has handled every request sent so far, and
/// every event it sent in reply has been dispatched.
pub fn roundtrip(c: *Connection) anyerror!void {
    var done = false;
    const callback = try c.session.newChild(.display, &protocol.core.callback);
    c.session.request(.display, protocol.core.display_request.sync, &.{.{ .new_id = callback }}) catch |e| {
        c.session.forget(callback);
        return e;
    };
    const f: *const Listener = &roundtripDone;
    c.session.setUserData(callback, &done, @ptrCast(f)) catch unreachable;
    // Should dispatching fail first, the callback outlives this frame, and
    // must not be left pointing into it.
    errdefer c.session.setUserData(callback, null, null) catch {};
    while (!done) _ = try c.dispatch();
}

fn roundtripDone(data: ?*anyopaque, _: *Connection, _: protocol.Message) anyerror!void {
    const done: *bool = @ptrCast(data.?);
    done.* = true;
}

fn closeDiscarded(c: *Connection) void {
    for (c.session.discardedFds()) |fd| _ = linux.close(fd);
    c.session.clearDiscardedFds();
}

fn cmsgSpace(fds: usize) usize {
    return @sizeOf(linux.cmsghdr) + std.mem.alignForward(usize, fds * @sizeOf(Fd), @alignOf(linux.cmsghdr));
}
