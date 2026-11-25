// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The client's half of a Wayland conversation, with the conversation itself
//! left to somebody else.
//!
//! A `Session` turns requests into bytes and file descriptors waiting to be
//! sent, and bytes and file descriptors that have arrived into events. It
//! knows which object each id names, when an id may be reused, and what the
//! compositor meant by a protocol error. It never touches a socket, a clock or
//! the environment -- it cannot even close a file descriptor -- so the whole of
//! the protocol can be driven from a test with nothing but byte slices, and
//! the `client` module is left with only the I/O.
//!
//! Sending:
//!
//! 1. Requests queue up through `request` (the generated bindings call it).
//! 2. `pending` says what to send: bytes, and the file descriptors that must
//!    travel with the first of those bytes.
//! 3. `consumed` retires however much of that actually went.
//!
//! Receiving:
//!
//! 1. `readable` hands out space to receive bytes into, and `received` says
//!    how much arrived; `feed` does both from a slice. File descriptors that
//!    arrived alongside go in through `receivedFd`.
//! 2. `nextEvent` returns the next event addressed to a live object, or null
//!    when it needs more input.
//! 3. File descriptors that belonged to events nobody will see -- sent to an
//!    object already destroyed -- accumulate in `discardedFds`, for the caller
//!    to close.
//!
//! File descriptors passed to `request` are *borrowed*: they must stay open
//! until `consumed` has retired them. File descriptors in a returned event
//! belong to whoever receives the event.

const std = @import("std");
const Allocator = std.mem.Allocator;
const wire = @import("wire.zig");
const core = @import("core.zig");
const Interface = @import("Interface.zig");
const ObjectMap = @import("ObjectMap.zig");
const Arg = wire.Arg;
const Fd = wire.Fd;
const ObjectId = wire.ObjectId;

const Session = @This();

gpa: Allocator,
objects: ObjectMap = .{},

/// Received bytes. Everything before `in_head` has been decoded.
in: std.ArrayList(u8) = .empty,
in_head: usize = 0,
/// Received file descriptors, in the order they arrived. Everything before
/// `in_fds_head` has been handed out.
in_fds: std.ArrayList(Fd) = .empty,
in_fds_head: usize = 0,

/// Encoded requests waiting to be sent.
out: std.ArrayList(u8) = .empty,
/// File descriptors waiting to be sent, borrowed from the caller.
out_fds: std.ArrayList(Fd) = .empty,
/// One per queued message that carries file descriptors: the offset in `out`
/// just past it, and how many of `out_fds` have been queued up to and
/// including it. `pending` needs these to split a batch at a message boundary
/// when more descriptors are queued than one `sendmsg` may carry.
out_marks: std.ArrayList(Mark) = .empty,

discarded_fds: std.ArrayList(Fd) = .empty,

/// Where the arguments of the event most recently returned by `nextEvent`
/// live.
args: [wire.max_args]Arg = undefined,

/// Set once the session has failed. Every later `nextEvent` returns it.
failure: ?EventError = null,
/// What the compositor said, if the failure was a `wl_display.error`.
protocol_error: ?ProtocolError = null,
error_message: std.ArrayList(u8) = .empty,

const Mark = struct { end: usize, fds: usize };

/// An event, decoded as far as the wire format goes. The generated
/// `Event.decode` of the object's interface turns it into a typed value.
///
/// `args` lives in the session and strings and arrays in it borrow from the
/// input buffer. All of it is valid until the next call to `nextEvent`,
/// `readable` or `feed`.
pub const Message = struct {
    object: ObjectId,
    interface: *const Interface,
    opcode: u16,
    args: []const Arg,
    /// Whatever was set with `setUserData` on the object, as it was when the
    /// event was decoded.
    user_data: ?*anyopaque,
    user_fn: ?*const anyopaque,

    pub fn signature(msg: Message) Interface.Signature {
        return msg.interface.events[msg.opcode];
    }
};

/// What the compositor said when it sent `wl_display.error`.
pub const ProtocolError = struct {
    object: ObjectId,
    /// The interface of `object`, if this side still knew it.
    interface: ?*const Interface,
    /// An error code from the enum of `interface`, or one of `wl_display`'s
    /// own.
    code: u32,
    /// Human-readable, and meant for a log rather than for a program.
    message: []const u8,

    pub fn format(e: ProtocolError, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const name = if (e.interface) |i| i.name else "unknown";
        try w.print("{s}#{f}: error {d}: {s}", .{ name, e.object, e.code, e.message });
    }
};

pub const RequestError = Allocator.Error || ObjectMap.AllocError || wire.EncodeError || error{
    /// The object does not exist or has already been destroyed.
    InvalidObject,
    /// The interface has no request with that opcode.
    InvalidOpcode,
    /// The object was bound at a version older than the one that introduced
    /// the request, or a bind asked for a version newer than this side
    /// understands.
    UnsupportedVersion,
    /// The session has already failed.
    SessionFailed,
};

pub const EventError = Allocator.Error || wire.DecodeError || error{
    /// The compositor sent `wl_display.error`; `protocol_error` says what it
    /// was. The compositor disconnects after sending it.
    ProtocolError,
    /// An event with an opcode the object's interface does not have.
    InvalidOpcode,
    /// An event created an object with an id that is not the server's to use,
    /// or is already in use.
    InvalidNewId,
};

pub fn init(gpa: Allocator) Allocator.Error!Session {
    var s: Session = .{ .gpa = gpa };
    try s.objects.insertClient(gpa, .display, .{ .interface = &core.display, .version = 1 });
    return s;
}

/// Frees everything the session holds. It cannot close the file descriptors
/// that arrived and were never handed out, so a caller that owns a socket
/// should call `discardUnreadFds` and close `discardedFds` first.
pub fn deinit(s: *Session) void {
    const gpa = s.gpa;
    s.objects.deinit(gpa);
    s.in.deinit(gpa);
    s.in_fds.deinit(gpa);
    s.out.deinit(gpa);
    s.out_fds.deinit(gpa);
    s.out_marks.deinit(gpa);
    s.discarded_fds.deinit(gpa);
    s.error_message.deinit(gpa);
    s.* = undefined;
}

// -- objects -----------------------------------------------------------------

/// Allocates an id for a new object of `interface` at `version`, for a request
/// that is about to create it. If that request then fails, give the id back
/// with `forget`.
pub fn newId(s: *Session, interface: *const Interface, version: u32) RequestError!ObjectId {
    if (version == 0 or version > interface.version) return error.UnsupportedVersion;
    return s.objects.allocate(s.gpa, .{ .interface = interface, .version = version });
}

/// Like `newId`, for an object created by a request on `parent`, which gives
/// it its own version as the protocol says it must.
pub fn newChild(s: *Session, parent: ObjectId, interface: *const Interface) RequestError!ObjectId {
    const p = s.objects.getLive(parent) orelse return error.InvalidObject;
    return s.newId(interface, @min(p.version, interface.version));
}

/// Gives back an id from `newId` that the compositor was never told about.
pub fn forget(s: *Session, id: ObjectId) void {
    std.debug.assert(!id.isServer());
    s.objects.release(s.gpa, id) catch {
        // Could not remember it as free, so it is simply never reused.
    };
}

/// The version `id` was created at, if it is live.
pub fn versionOf(s: *const Session, id: ObjectId) ?u32 {
    const entry = s.objects.getLive(id) orelse return null;
    return entry.version;
}

/// The interface of `id`, if it is live.
pub fn interfaceOf(s: *const Session, id: ObjectId) ?*const Interface {
    const entry = s.objects.getLive(id) orelse return null;
    return entry.interface;
}

/// Attaches two words to a live object, to come back in every `Message`
/// addressed to it. They go when the object does.
pub fn setUserData(s: *Session, id: ObjectId, data: ?*anyopaque, func: ?*const anyopaque) error{InvalidObject}!void {
    const entry = s.objects.getLive(id) orelse return error.InvalidObject;
    entry.user_data = data;
    entry.user_fn = func;
}

// -- sending -----------------------------------------------------------------

/// Queues request `opcode` on `object`. `args` must match the request's
/// signature, with a bare `new_id` given as the three values it expands to.
/// If the request is a destructor, the object is dead once this returns.
pub fn request(s: *Session, object: ObjectId, opcode: u16, args: []const Arg) RequestError!void {
    if (s.failure != null) return error.SessionFailed;
    const entry = s.objects.getLive(object) orelse return error.InvalidObject;
    if (opcode >= entry.interface.requests.len) return error.InvalidOpcode;
    const sig = entry.interface.requests[opcode];
    if (entry.version < sig.since) return error.UnsupportedVersion;

    const size = try wire.encodedSize(sig.args, args);
    const fd_count = sig.fdCount();
    if (fd_count > wire.max_fds_out) return error.MessageTooLarge;

    try s.out.ensureUnusedCapacity(s.gpa, size);
    try s.out_fds.ensureUnusedCapacity(s.gpa, fd_count);
    if (fd_count > 0) try s.out_marks.ensureUnusedCapacity(s.gpa, 1);

    wire.encode(s.out.addManyAsSliceAssumeCapacity(size), object, opcode, args);
    for (args) |arg| switch (arg) {
        .fd => |fd| s.out_fds.appendAssumeCapacity(fd),
        else => {},
    };
    if (fd_count > 0) s.out_marks.appendAssumeCapacity(.{ .end = s.out.items.len, .fds = s.out_fds.items.len });

    if (sig.destructor) s.objects.destroy(object);
}

pub const Pending = struct {
    bytes: []const u8,
    /// To be sent with the first of `bytes`, as `SCM_RIGHTS` ancillary data.
    fds: []const Fd,
};

/// What to send next. Empty when there is nothing queued.
///
/// When more file descriptors are queued than one `sendmsg` may carry, this
/// is only as many whole messages as fit, and the rest comes on the next call
/// after `consumed`.
pub fn pending(s: *const Session) Pending {
    if (s.out_fds.items.len <= wire.max_fds_out)
        return .{ .bytes = s.out.items, .fds = s.out_fds.items };
    var end: usize = 0;
    var fds: usize = 0;
    for (s.out_marks.items) |mark| {
        if (mark.fds > wire.max_fds_out) break;
        end = mark.end;
        fds = mark.fds;
    }
    // `request` refuses any single message with more than `max_fds_out`, so
    // the first mark always fits.
    std.debug.assert(end > 0);
    return .{ .bytes = s.out.items[0..end], .fds = s.out_fds.items[0..fds] };
}

/// Retires the first `bytes` bytes and `fds` file descriptors of what
/// `pending` returned. Descriptors travel with the first byte of a send, so
/// after a send of any length, `fds` is all of them.
pub fn consumed(s: *Session, bytes: usize, fds: usize) void {
    std.debug.assert(bytes <= s.out.items.len and fds <= s.out_fds.items.len);
    s.out.replaceRangeAssumeCapacity(0, bytes, &.{});
    s.out_fds.replaceRangeAssumeCapacity(0, fds, &.{});
    var keep: usize = 0;
    for (s.out_marks.items) |mark| {
        if (mark.end <= bytes) continue;
        s.out_marks.items[keep] = .{ .end = mark.end - bytes, .fds = mark.fds - fds };
        keep += 1;
    }
    s.out_marks.shrinkRetainingCapacity(keep);
}

// -- receiving ---------------------------------------------------------------

/// Space for at least `min` more bytes of input, to be followed by
/// `received`. Invalidates every `Message` already returned.
pub fn readable(s: *Session, min: usize) Allocator.Error![]u8 {
    if (s.in_head > 0) {
        const rest = s.in.items.len - s.in_head;
        std.mem.copyForwards(u8, s.in.items[0..rest], s.in.items[s.in_head..]);
        s.in.shrinkRetainingCapacity(rest);
        s.in_head = 0;
    }
    try s.in.ensureUnusedCapacity(s.gpa, min);
    return s.in.unusedCapacitySlice();
}

/// `n` bytes were written into what `readable` returned.
pub fn received(s: *Session, n: usize) void {
    std.debug.assert(n <= s.in.capacity - s.in.items.len);
    s.in.items.len += n;
}

/// Copies `bytes` in as received input.
pub fn feed(s: *Session, bytes: []const u8) Allocator.Error!void {
    const buf = try s.readable(bytes.len);
    @memcpy(buf[0..bytes.len], bytes);
    s.received(bytes.len);
}

/// A file descriptor arrived. The session owns it until it is handed out in
/// an event or put in `discardedFds`.
pub fn receivedFd(s: *Session, fd: Fd) Allocator.Error!void {
    if (s.in_fds_head > 0 and s.in_fds_head == s.in_fds.items.len) {
        s.in_fds.clearRetainingCapacity();
        s.in_fds_head = 0;
    }
    try s.in_fds.append(s.gpa, fd);
}

/// File descriptors that arrived for events nobody will see. The caller
/// closes them and then calls `clearDiscardedFds`.
pub fn discardedFds(s: *const Session) []const Fd {
    return s.discarded_fds.items;
}

pub fn clearDiscardedFds(s: *Session) void {
    s.discarded_fds.clearRetainingCapacity();
}

/// Moves every received descriptor not yet handed out into `discardedFds`.
/// For tearing a connection down.
pub fn discardUnreadFds(s: *Session) Allocator.Error!void {
    try s.discarded_fds.appendSlice(s.gpa, s.in_fds.items[s.in_fds_head..]);
    s.in_fds.clearRetainingCapacity();
    s.in_fds_head = 0;
}

/// The next event addressed to a live object, or null if a whole one has not
/// arrived yet.
///
/// `wl_display`'s own events never come out of here: `delete_id` frees the id
/// it names, and `error` fails the session with `error.ProtocolError`. Events
/// addressed to an object this side has already destroyed are skipped, and
/// events addressed to an id it has never heard of are skipped too, as
/// libwayland does.
///
/// Once this has returned an error, the session is finished and every later
/// call returns the same one.
pub fn nextEvent(s: *Session) EventError!?Message {
    if (s.failure) |e| return e;
    return s.decodeNext() catch |e| {
        s.failure = e;
        return e;
    };
}

fn decodeNext(s: *Session) EventError!?Message {
    while (true) {
        const available = s.in.items[s.in_head..];
        if (available.len < wire.header_size) return null;
        const header = wire.Header.decode(available[0..wire.header_size]);
        if (header.size < wire.header_size or header.size % 4 != 0) return error.InvalidMessage;
        if (available.len < header.size) return null;
        const payload = available[wire.header_size..header.size];

        // A copy: registering an object below can move the entry.
        const entry = (s.objects.get(header.object) orelse {
            s.in_head += header.size;
            continue;
        }).*;
        if (header.opcode >= entry.interface.events.len) return error.InvalidOpcode;
        const sig = entry.interface.events[header.opcode];
        if (sig.args.len > wire.max_args) return error.InvalidMessage;

        const fd_count = sig.fdCount();
        const fds_available = s.in_fds.items[s.in_fds_head..];
        // The descriptors travel with the first byte of the send that carried
        // the message, so they may not have been read yet.
        if (fds_available.len < fd_count) return null;

        const args = s.args[0..sig.args.len];
        try wire.decodeArgs(payload, sig.args, fds_available[0..fd_count], args);
        s.in_head += header.size;
        s.in_fds_head += fd_count;

        // The server has created these whether or not this side still wants
        // them, and it allocates densely, so they must be recorded either way.
        for (sig.args, args) |spec, arg| {
            if (spec.kind != .new_id) continue;
            const interface = spec.interface orelse return error.InvalidNewId;
            s.objects.insertServer(s.gpa, arg.new_id, .{
                .interface = interface,
                .version = @min(entry.version, interface.version),
                .state = entry.state,
            }) catch |e| switch (e) {
                error.InvalidNewId => return error.InvalidNewId,
                error.OutOfMemory => return error.OutOfMemory,
            };
        }

        if (entry.state == .zombie) {
            for (args) |arg| switch (arg) {
                .fd => |fd| try s.discarded_fds.append(s.gpa, fd),
                else => {},
            };
            continue;
        }

        if (header.object == .display) {
            switch (header.opcode) {
                core.display_event.@"error" => {
                    const object = args[0].object;
                    s.error_message.clearRetainingCapacity();
                    try s.error_message.appendSlice(s.gpa, args[2].string.?);
                    s.protocol_error = .{
                        .object = object,
                        .interface = if (s.objects.get(object)) |e| e.interface else null,
                        .code = args[1].uint,
                        .message = s.error_message.items,
                    };
                    return error.ProtocolError;
                },
                core.display_event.delete_id => try s.objects.release(s.gpa, @fromBackingInt(args[0].uint)),
                else => unreachable,
            }
            continue;
        }

        if (sig.destructor) s.objects.destroy(header.object);
        return .{
            .object = header.object,
            .interface = entry.interface,
            .opcode = header.opcode,
            .args = args,
            .user_data = entry.user_data,
            .user_fn = entry.user_fn,
        };
    }
}

// -- tests -------------------------------------------------------------------

const testing = std.testing;

/// Encodes a server event for a test to feed in.
fn event(buf: []u8, object: ObjectId, interface: *const Interface, opcode: u16, args: []const Arg) ![]u8 {
    const size = try wire.encodedSize(interface.events[opcode].args, args);
    wire.encode(buf[0..size], object, opcode, args);
    return buf[0..size];
}

const test_iface: Interface = .{
    .name = "test_object",
    .version = 3,
    .requests = &.{
        .{ .name = "attach_fd", .args = &.{ .{ .kind = .fd }, .{ .kind = .uint } } },
        .{ .name = "make_child", .args = &.{.{ .kind = .new_id, .interface = &test_iface }} },
        .{ .name = "destroy", .destructor = true },
        .{ .name = "newer", .since = 3 },
    },
    .events = &.{
        .{ .name = "fd", .args = &.{ .{ .kind = .string }, .{ .kind = .fd } } },
        .{ .name = "child", .args = &.{.{ .kind = .new_id, .interface = &test_iface }} },
        .{ .name = "gone", .destructor = true },
    },
};

test "a request is queued as the bytes the wire expects" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();

    const registry = try s.newChild(.display, &core.registry);
    try s.request(.display, core.display_request.get_registry, &.{.{ .new_id = registry }});
    const words: [3]u32 = @bitCast(s.pending().bytes[0..12].*);
    try testing.expectEqualSlices(u32, &.{ 1, 12 << 16 | 1, 2 }, &words);
    try testing.expectEqual(@as(usize, 0), s.pending().fds.len);

    s.consumed(5, 0);
    try testing.expectEqual(@as(usize, 7), s.pending().bytes.len);
    s.consumed(7, 0);
    try testing.expectEqual(@as(usize, 0), s.pending().bytes.len);
}

test "requests are checked against the object and its version" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();

    const old = try s.newId(&test_iface, 2);
    try testing.expectError(error.UnsupportedVersion, s.request(old, 3, &.{}));
    try testing.expectError(error.InvalidOpcode, s.request(old, 9, &.{}));
    try testing.expectError(error.InvalidArgument, s.request(old, 0, &.{.{ .uint = 1 }}));
    try testing.expectError(error.UnsupportedVersion, s.newId(&test_iface, 4));

    try s.request(old, 2, &.{});
    try testing.expectError(error.InvalidObject, s.request(old, 2, &.{}));
    try testing.expectEqual(@as(?u32, null), s.versionOf(old));

    // A child takes its parent's version.
    const parent = try s.newId(&test_iface, 3);
    try testing.expectEqual(@as(?u32, 3), s.versionOf(try s.newChild(parent, &test_iface)));
    try testing.expectError(error.InvalidObject, s.newChild(old, &test_iface));
}

test "too many file descriptors are split at a message boundary" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 1);
    for (0..wire.max_fds_out + 5) |i| {
        try s.request(obj, 0, &.{ .{ .fd = @intCast(100 + i) }, .{ .uint = @intCast(i) } });
    }
    const message_size = 12;

    var batch = s.pending();
    try testing.expectEqual(@as(usize, wire.max_fds_out), batch.fds.len);
    try testing.expectEqual(@as(usize, wire.max_fds_out * message_size), batch.bytes.len);
    try testing.expectEqual(@as(Fd, 100), batch.fds[0]);

    // Half a message goes, and all the descriptors go with it.
    s.consumed(wire.max_fds_out * message_size - 6, wire.max_fds_out);
    batch = s.pending();
    try testing.expectEqual(@as(usize, 5), batch.fds.len);
    try testing.expectEqual(@as(Fd, 100 + wire.max_fds_out), batch.fds[0]);
    try testing.expectEqual(@as(usize, 6 + 5 * message_size), batch.bytes.len);
    s.consumed(batch.bytes.len, batch.fds.len);
    try testing.expectEqual(@as(usize, 0), s.pending().bytes.len);
    try testing.expectEqual(@as(usize, 0), s.out_marks.items.len);
}

test "events come out whole however the bytes are split" {
    var buf: [256]u8 = undefined;
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(testing.allocator);
    try stream.appendSlice(testing.allocator, try event(&buf, @fromBackingInt(2), &core.registry, 0, &.{
        .{ .uint = 7 }, .{ .string = "wl_compositor" }, .{ .uint = 6 },
    }));
    try stream.appendSlice(testing.allocator, try event(&buf, @fromBackingInt(2), &core.registry, 1, &.{.{ .uint = 7 }}));

    for (0..stream.items.len + 1) |split| {
        var s: Session = try .init(testing.allocator);
        defer s.deinit();
        const registry = try s.newChild(.display, &core.registry);
        try testing.expectEqual(@as(u32, 2), @backingInt(registry));

        try s.feed(stream.items[0..split]);
        var seen: usize = 0;
        while (try s.nextEvent()) |_| seen += 1;
        try s.feed(stream.items[split..]);
        while (try s.nextEvent()) |msg| {
            seen += 1;
            if (msg.opcode == 0) {
                try testing.expectEqualStrings("wl_compositor", msg.args[1].string.?);
                try testing.expectEqual(@as(u32, 6), msg.args[2].uint);
            }
        }
        try testing.expectEqual(@as(usize, 2), seen);
    }
}

test "an event waits for its file descriptor" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 1);

    try s.feed(try event(&buf, obj, &test_iface, 0, &.{ .{ .string = "x" }, .{ .fd = 0 } }));
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
    try s.receivedFd(42);
    const msg = (try s.nextEvent()).?;
    try testing.expectEqual(@as(Fd, 42), msg.args[1].fd);
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
}

test "events for a destroyed object are skipped, and their descriptors kept to close" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 1);
    try s.request(obj, 2, &.{});

    try s.feed(try event(&buf, obj, &test_iface, 0, &.{ .{ .string = "x" }, .{ .fd = 0 } }));
    try s.receivedFd(42);
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
    try testing.expectEqualSlices(Fd, &.{42}, s.discardedFds());
    s.clearDiscardedFds();

    // The id is still taken until the server lets go of it.
    try testing.expect(obj != try s.newId(&test_iface, 1));
    try s.feed(try event(&buf, .display, &core.display, core.display_event.delete_id, &.{.{ .uint = @backingInt(obj) }}));
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
    try testing.expectEqual(obj, try s.newId(&test_iface, 1));
}

test "an id the client never heard of is skipped" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    try s.feed(try event(&buf, @fromBackingInt(99), &core.registry, 1, &.{.{ .uint = 1 }}));
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
    try testing.expectEqual(@as(usize, 0), s.in.items.len - s.in_head);
}

test "objects the server creates are recorded, even for a zombie" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 2);
    const first: ObjectId = @fromBackingInt(ObjectId.server_start);
    const second: ObjectId = @fromBackingInt(ObjectId.server_start + 1);

    try s.feed(try event(&buf, obj, &test_iface, 1, &.{.{ .new_id = first }}));
    const msg = (try s.nextEvent()).?;
    try testing.expectEqual(first, msg.args[0].new_id);
    try testing.expectEqual(@as(?u32, 2), s.versionOf(first));

    try s.request(obj, 2, &.{});
    try s.feed(try event(&buf, obj, &test_iface, 1, &.{.{ .new_id = second }}));
    try testing.expectEqual(@as(?Message, null), try s.nextEvent());
    try testing.expect(s.objects.get(second) != null);
    try testing.expectEqual(@as(?u32, null), s.versionOf(second));

    // A destructor event kills a server object at once.
    try s.feed(try event(&buf, first, &test_iface, 2, &.{}));
    _ = (try s.nextEvent()).?;
    try testing.expect(s.objects.get(first) == null);
}

test "a server id out of sequence fails the session" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 1);
    try s.feed(try event(&buf, obj, &test_iface, 1, &.{.{ .new_id = @fromBackingInt(0xffff_ffff) }}));
    try testing.expectError(error.InvalidNewId, s.nextEvent());
    try testing.expectError(error.InvalidNewId, s.nextEvent());
    try testing.expectError(error.SessionFailed, s.request(obj, 2, &.{}));
}

test "wl_display.error fails the session and says why" {
    var buf: [128]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const obj = try s.newId(&test_iface, 1);
    try s.feed(try event(&buf, .display, &core.display, core.display_event.@"error", &.{
        .{ .object = obj }, .{ .uint = 3 }, .{ .string = "invalid thing" },
    }));
    try testing.expectError(error.ProtocolError, s.nextEvent());
    const e = s.protocol_error.?;
    try testing.expectEqual(obj, e.object);
    try testing.expectEqual(@as(u32, 3), e.code);
    try testing.expectEqualStrings("invalid thing", e.message);
    try testing.expectEqualStrings("test_object", e.interface.?.name);

    var out: [64]u8 = undefined;
    try testing.expectEqualStrings("test_object#2: error 3: invalid thing", try std.fmt.bufPrint(&out, "{f}", .{e}));
}

test "malformed headers fail the session" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const words = [_]u32{ 1, 6 << 16 };
    try s.feed(std.mem.asBytes(&words));
    try testing.expectError(error.InvalidMessage, s.nextEvent());
}

test "an opcode past the end of the interface fails the session" {
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    const words = [_]u32{ 1, 8 << 16 | 9 };
    try s.feed(std.mem.asBytes(&words));
    try testing.expectError(error.InvalidOpcode, s.nextEvent());
}

test "user data travels with the object and goes when it does" {
    var buf: [64]u8 = undefined;
    var s: Session = try .init(testing.allocator);
    defer s.deinit();
    var marker: u8 = 0;
    const obj = try s.newId(&test_iface, 1);
    try s.setUserData(obj, &marker, null);
    try s.feed(try event(&buf, obj, &test_iface, 2, &.{}));
    const msg = (try s.nextEvent()).?;
    try testing.expectEqual(@as(?*anyopaque, &marker), msg.user_data);
    try testing.expectError(error.InvalidObject, s.setUserData(obj, &marker, null));
}
