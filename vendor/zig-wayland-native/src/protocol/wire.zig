// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The Wayland wire format: how one message is laid out in bytes.
//!
//! Every message is a two-word header followed by its arguments, and every
//! word is 32 bits in the byte order of the machine, since both ends of a
//! Wayland connection are always on the same machine. The header is the
//! object id, then the message size in bytes in the upper 16 bits and the
//! opcode in the lower 16. Arguments follow in declaration order:
//!
//! | Type | Encoding |
//! | --- | --- |
//! | `int`, `uint` | one word |
//! | `fixed` | one word, signed 24.8 fixed point |
//! | `object`, `new_id` | one word, the id; 0 is null |
//! | `string` | a word giving the length *including* the terminating NUL, then the bytes, padded to a word; length 0 is null |
//! | `array` | a word giving the length, then the bytes, padded to a word |
//! | `fd` | nothing at all -- it travels beside the bytes as `SCM_RIGHTS` ancillary data |
//!
//! Nothing here allocates or performs I/O. Decoding treats its input as
//! hostile: every length is checked against what is actually there before it
//! is used, and a malformed message is an error rather than a panic.
//!
//! https://wayland.freedesktop.org/docs/book/Protocol.html#wire-format

const std = @import("std");
const native_endian = @import("builtin").cpu.arch.endian();
const Interface = @import("Interface.zig");

/// The size of a message header in bytes.
pub const header_size = 8;

/// The largest message either end will send or accept. The size field could
/// say 65535, but libwayland has always refused anything larger than its
/// 4096-byte buffer, so a message bigger than this is one no compositor built
/// on it will read.
pub const max_message_size = 4096;

/// The most arguments one message may have, counting a bare `new_id` as the
/// three it expands to. libwayland's limit is 20; this leaves room.
pub const max_args = 32;

/// The most file descriptors one `sendmsg` may carry. libwayland's `MAX_FDS_OUT`,
/// and so the most a compositor built on it will accept at once.
pub const max_fds_out = 28;

/// A file descriptor, as the operating system numbers them.
pub const Fd = std.posix.fd_t;

/// An object id. 0 is the null object; the client allocates ids from 1 up and
/// the server from `ObjectId.server_start` up.
pub const ObjectId = enum(u32) {
    null = 0,
    /// `wl_display`, the one object that exists before anything is sent.
    display = 1,
    _,

    /// The first id in the range the server allocates from.
    pub const server_start: u32 = 0xff00_0000;

    pub fn isServer(id: ObjectId) bool {
        return @backingInt(id) >= server_start;
    }

    pub fn format(id: ObjectId, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("{d}", .{@backingInt(id)});
    }
};

/// A signed 24.8 fixed-point number, which is how the protocol carries
/// surface-local coordinates.
pub const Fixed = enum(i32) {
    _,

    pub fn fromInt(i: i24) Fixed {
        return @fromBackingInt(@as(i32, i) * 256);
    }

    /// Rounds toward zero, and saturates rather than wrapping outside the
    /// range a 24.8 number can hold.
    pub fn fromDouble(d: f64) Fixed {
        const scaled = d * 256.0;
        if (std.math.isNan(scaled)) return @fromBackingInt(0);
        const clamped = std.math.clamp(scaled, std.math.minInt(i32), std.math.maxInt(i32));
        return @fromBackingInt(@as(i32, @intFromFloat(clamped)));
    }

    /// The integer part, rounded toward zero.
    pub fn toInt(f: Fixed) i32 {
        return @divTrunc(@backingInt(f), 256);
    }

    pub fn toDouble(f: Fixed) f64 {
        return @as(f64, @floatFromInt(@backingInt(f))) / 256.0;
    }
};

/// One argument value, tagged with its wire type.
///
/// In a decoded event, `string` and `array` borrow from the buffer the
/// message was decoded from.
pub const Arg = union(Interface.Kind) {
    int: i32,
    uint: u32,
    fixed: Fixed,
    string: ?[:0]const u8,
    object: ObjectId,
    new_id: ObjectId,
    array: []const u8,
    fd: Fd,
};

pub const Header = struct {
    object: ObjectId,
    opcode: u16,
    /// The whole message, header included, in bytes.
    size: u16,

    pub fn decode(bytes: *const [header_size]u8) Header {
        const word = std.mem.readInt(u32, bytes[4..8], native_endian);
        return .{
            .object = @fromBackingInt(std.mem.readInt(u32, bytes[0..4], native_endian)),
            .opcode = @truncate(word),
            .size = @intCast(word >> 16),
        };
    }

    pub fn encode(h: Header, bytes: *[header_size]u8) void {
        std.mem.writeInt(u32, bytes[0..4], @backingInt(h.object), native_endian);
        std.mem.writeInt(u32, bytes[4..8], @as(u32, h.size) << 16 | h.opcode, native_endian);
    }
};

pub const EncodeError = error{
    /// The message would be larger than `max_message_size`.
    MessageTooLarge,
    /// A `null` string or object where the signature does not allow one, or
    /// an argument of the wrong kind.
    InvalidArgument,
};

pub const DecodeError = error{
    /// The size field is smaller than a header, not a whole number of words,
    /// or disagrees with the arguments the signature says are there.
    InvalidMessage,
    /// A null string or object where the signature does not allow one.
    NullArgument,
    /// A string that is not terminated by its NUL.
    InvalidString,
};

fn padded(len: usize) usize {
    return std.mem.alignForward(usize, len, 4);
}

/// The size of the whole message, header included, that `encode` will write
/// for `args`, after checking them against `specs`.
pub fn encodedSize(specs: []const Interface.Arg, args: []const Arg) EncodeError!u16 {
    if (specs.len != args.len) return error.InvalidArgument;
    var size: usize = header_size;
    for (specs, args) |spec, arg| {
        if (spec.kind != std.meta.activeTag(arg)) return error.InvalidArgument;
        size += switch (arg) {
            .int, .uint, .fixed, .new_id => 4,
            .object => |id| blk: {
                if (id == .null and !spec.nullable) return error.InvalidArgument;
                break :blk 4;
            },
            .string => |s| blk: {
                const str = s orelse {
                    if (!spec.nullable) return error.InvalidArgument;
                    break :blk 4;
                };
                if (str.len >= max_message_size) return error.MessageTooLarge;
                break :blk 4 + padded(str.len + 1);
            },
            .array => |a| blk: {
                if (a.len >= max_message_size) return error.MessageTooLarge;
                break :blk 4 + padded(a.len);
            },
            .fd => 0,
        };
        if (size > max_message_size) return error.MessageTooLarge;
    }
    return @intCast(size);
}

/// Writes a message into `out`, which must be exactly `encodedSize` bytes.
/// File descriptors are not written; the caller sends them beside the bytes.
pub fn encode(out: []u8, object: ObjectId, opcode: u16, args: []const Arg) void {
    std.debug.assert(out.len >= header_size and out.len <= max_message_size);
    Header.encode(.{ .object = object, .opcode = opcode, .size = @intCast(out.len) }, out[0..header_size]);
    var pos: usize = header_size;
    for (args) |arg| {
        switch (arg) {
            .int => |v| putWord(out, &pos, @bitCast(v)),
            .uint => |v| putWord(out, &pos, v),
            .fixed => |v| putWord(out, &pos, @bitCast(@backingInt(v))),
            .object, .new_id => |v| putWord(out, &pos, @backingInt(v)),
            .string => |s| if (s) |str| {
                putWord(out, &pos, @intCast(str.len + 1));
                putBytes(out, &pos, str[0 .. str.len + 1]);
            } else putWord(out, &pos, 0),
            .array => |a| {
                putWord(out, &pos, @intCast(a.len));
                putBytes(out, &pos, a);
            },
            .fd => {},
        }
    }
    std.debug.assert(pos == out.len);
}

fn putWord(out: []u8, pos: *usize, word: u32) void {
    std.mem.writeInt(u32, out[pos.*..][0..4], word, native_endian);
    pos.* += 4;
}

fn putBytes(out: []u8, pos: *usize, bytes: []const u8) void {
    const len = padded(bytes.len);
    @memcpy(out[pos.*..][0..bytes.len], bytes);
    @memset(out[pos.* + bytes.len .. pos.* + len], 0);
    pos.* += len;
}

/// Decodes the arguments of one message from `payload`, the bytes after its
/// header, into `out`, which must be as long as `specs`. `fds` are the file
/// descriptors that arrived for it, exactly `Signature.fdCount` of them, and
/// are handed out in order.
///
/// Strings and arrays in `out` borrow from `payload`.
pub fn decodeArgs(
    payload: []const u8,
    specs: []const Interface.Arg,
    fds: []const Fd,
    out: []Arg,
) DecodeError!void {
    std.debug.assert(out.len == specs.len);
    var pos: usize = 0;
    var next_fd: usize = 0;
    for (specs, out) |spec, *arg| {
        arg.* = switch (spec.kind) {
            .int => .{ .int = @bitCast(try takeWord(payload, &pos)) },
            .uint => .{ .uint = try takeWord(payload, &pos) },
            .fixed => .{ .fixed = @fromBackingInt(@as(i32, @bitCast(try takeWord(payload, &pos)))) },
            .object => blk: {
                const id: ObjectId = @fromBackingInt(try takeWord(payload, &pos));
                if (id == .null and !spec.nullable) return error.NullArgument;
                break :blk .{ .object = id };
            },
            .new_id => blk: {
                const id: ObjectId = @fromBackingInt(try takeWord(payload, &pos));
                if (id == .null) return error.NullArgument;
                break :blk .{ .new_id = id };
            },
            .string => blk: {
                const len = try takeWord(payload, &pos);
                if (len == 0) {
                    if (!spec.nullable) return error.NullArgument;
                    break :blk .{ .string = null };
                }
                const bytes = try takeBytes(payload, &pos, len);
                if (bytes[len - 1] != 0) return error.InvalidString;
                break :blk .{ .string = bytes[0 .. len - 1 :0] };
            },
            .array => blk: {
                const len = try takeWord(payload, &pos);
                break :blk .{ .array = try takeBytes(payload, &pos, len) };
            },
            .fd => blk: {
                if (next_fd >= fds.len) return error.InvalidMessage;
                next_fd += 1;
                break :blk .{ .fd = fds[next_fd - 1] };
            },
        };
    }
    if (pos != payload.len) return error.InvalidMessage;
}

fn takeWord(payload: []const u8, pos: *usize) DecodeError!u32 {
    if (payload.len - pos.* < 4) return error.InvalidMessage;
    const word = std.mem.readInt(u32, payload[pos.*..][0..4], native_endian);
    pos.* += 4;
    return word;
}

fn takeBytes(payload: []const u8, pos: *usize, len: u32) DecodeError![]const u8 {
    // Compared before padding so that a length near the top of `u32` cannot
    // wrap into something that looks small.
    const available = payload.len - pos.*;
    if (len > available) return error.InvalidMessage;
    const len_padded = padded(len);
    if (len_padded > available) return error.InvalidMessage;
    const bytes = payload[pos.*..][0..len];
    pos.* += len_padded;
    return bytes;
}

const testing = std.testing;

fn roundTrip(specs: []const Interface.Arg, args: []const Arg, fds: []const Fd) !void {
    const size = try encodedSize(specs, args);
    var buf: [max_message_size]u8 = undefined;
    encode(buf[0..size], @fromBackingInt(7), 3, args);

    const header = Header.decode(buf[0..header_size]);
    try testing.expectEqual(@as(ObjectId, @fromBackingInt(7)), header.object);
    try testing.expectEqual(@as(u16, 3), header.opcode);
    try testing.expectEqual(size, header.size);

    var out: [max_args]Arg = undefined;
    try decodeArgs(buf[header_size..size], specs, fds, out[0..specs.len]);
    for (args, out[0..specs.len]) |want, got| {
        switch (want) {
            .string => |s| if (s) |str|
                try testing.expectEqualStrings(str, got.string.?)
            else
                try testing.expectEqual(@as(?[:0]const u8, null), got.string),
            .array => |a| try testing.expectEqualSlices(u8, a, got.array),
            else => try testing.expectEqual(want, got),
        }
    }
}

test "every kind survives a round trip" {
    try roundTrip(&.{
        .{ .kind = .int },
        .{ .kind = .uint },
        .{ .kind = .fixed },
        .{ .kind = .object, .nullable = true },
        .{ .kind = .new_id },
        .{ .kind = .fd },
        .{ .kind = .string },
        .{ .kind = .array },
    }, &.{
        .{ .int = -5 },
        .{ .uint = 0xdead_beef },
        .{ .fixed = Fixed.fromDouble(-1.5) },
        .{ .object = .null },
        .{ .new_id = @fromBackingInt(42) },
        .{ .fd = 9 },
        .{ .string = "wl_compositor" },
        .{ .array = &.{ 1, 2, 3, 4, 5 } },
    }, &.{9});
}

test "strings at every padding" {
    const specs: []const Interface.Arg = &.{.{ .kind = .string, .nullable = true }};
    try roundTrip(specs, &.{.{ .string = "" }}, &.{});
    try roundTrip(specs, &.{.{ .string = "a" }}, &.{});
    try roundTrip(specs, &.{.{ .string = "ab" }}, &.{});
    try roundTrip(specs, &.{.{ .string = "abc" }}, &.{});
    try roundTrip(specs, &.{.{ .string = "abcd" }}, &.{});
    try roundTrip(specs, &.{.{ .string = null }}, &.{});
}

test "the empty string is not the null string" {
    const specs: []const Interface.Arg = &.{.{ .kind = .string }};
    try testing.expectEqual(@as(u16, 16), try encodedSize(specs, &.{.{ .string = "" }}));
    try testing.expectError(error.InvalidArgument, encodedSize(specs, &.{.{ .string = null }}));
}

test "arrays at every padding" {
    const specs: []const Interface.Arg = &.{.{ .kind = .array }};
    try roundTrip(specs, &.{.{ .array = &.{} }}, &.{});
    try roundTrip(specs, &.{.{ .array = &.{1} }}, &.{});
    try roundTrip(specs, &.{.{ .array = &.{ 1, 2, 3, 4, 5, 6, 7 } }}, &.{});
}

test "the header matches the specification's example" {
    // Object 1, opcode 1 (get_registry), 12 bytes long.
    var bytes: [12]u8 = undefined;
    encode(&bytes, .display, 1, &.{.{ .new_id = @fromBackingInt(2) }});
    const words: [3]u32 = @bitCast(bytes);
    try testing.expectEqualSlices(u32, &.{ 1, 12 << 16 | 1, 2 }, &words);
}

test "a message too large to send is refused" {
    const big: [max_message_size - header_size - 4 + 1]u8 = @splat('x');
    try testing.expectError(error.MessageTooLarge, encodedSize(
        &.{.{ .kind = .array }},
        &.{.{ .array = &big }},
    ));
}

test "a hostile length is refused rather than trusted" {
    var out: [1]Arg = undefined;
    const specs: []const Interface.Arg = &.{.{ .kind = .string }};
    // Lengths near the top of u32, which would wrap if padded before checking.
    for ([_]u32{ 0xffff_ffff, 0xffff_fffd, 5, 8 }) |len| {
        var payload: [8]u8 = @splat(0);
        std.mem.writeInt(u32, payload[0..4], len, native_endian);
        try testing.expectError(error.InvalidMessage, decodeArgs(&payload, specs, &.{}, &out));
    }
}

test "strings must carry their terminator" {
    var payload: [8]u8 = .{ 0, 0, 0, 0, 'a', 'b', 'c', 'd' };
    std.mem.writeInt(u32, payload[0..4], 4, native_endian);
    var out: [1]Arg = undefined;
    try testing.expectError(error.InvalidString, decodeArgs(&payload, &.{.{ .kind = .string }}, &.{}, &out));
}

test "null where it is not allowed is refused" {
    const payload: [4]u8 = @splat(0);
    var out: [1]Arg = undefined;
    try testing.expectError(error.NullArgument, decodeArgs(&payload, &.{.{ .kind = .object }}, &.{}, &out));
    try testing.expectError(error.NullArgument, decodeArgs(&payload, &.{.{ .kind = .new_id }}, &.{}, &out));
    try testing.expectError(error.NullArgument, decodeArgs(&payload, &.{.{ .kind = .string }}, &.{}, &out));
}

test "truncated and overlong payloads are refused" {
    var out: [1]Arg = undefined;
    const payload: [6]u8 = @splat(0);
    try testing.expectError(error.InvalidMessage, decodeArgs(payload[0..2], &.{.{ .kind = .uint }}, &.{}, &out));
    try testing.expectError(error.InvalidMessage, decodeArgs(payload[0..6], &.{.{ .kind = .uint }}, &.{}, &out));
}

test "fixed point" {
    try testing.expectEqual(@as(f64, 1.5), Fixed.fromDouble(1.5).toDouble());
    try testing.expectEqual(@as(i32, -2), Fixed.fromDouble(-2.75).toInt());
    try testing.expectEqual(@as(i32, 256 * 10), @backingInt(Fixed.fromInt(10)));
    try testing.expectEqual(@as(i32, std.math.maxInt(i32)), @backingInt(Fixed.fromDouble(1e300)));
    try testing.expectEqual(@as(i32, 0), @backingInt(Fixed.fromDouble(std.math.nan(f64))));
}
