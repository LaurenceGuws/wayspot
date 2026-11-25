// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! What the compositor says about the dma-bufs it would like: which device
//! it composites on, and which format and modifier pairs it accepts, in
//! order of preference.
//!
//! This is `zwp_linux_dmabuf_feedback_v1` from version 4 of linux-dmabuf,
//! for the default feedback or one surface's. The compositor sends a format
//! table as a file descriptor -- sixteen bytes an entry, `u32` format, four
//! bytes of padding, `u64` modifier -- then the main device, then one or more
//! *tranches*, each a target device, some flags, and indices into the table.
//! `done` ends a batch. Nothing here changes until `done`: a batch is
//! assembled on the side and swapped in whole, so the fields always describe
//! one consistent answer.
//!
//! The compositor may send a new batch at any time -- a window moved to
//! another output, direct scanout became possible. Each one sets `changed`
//! and calls `on_change`, and the consumer reallocates if it cares.
//!
//! For a compositor older than version 4 there is no feedback object, and
//! `Dmabuf` fills one of these from the `format` and `modifier` events
//! instead: a single tranche with no device, and `main_device` null, because
//! that compositor never says which device it uses.

const std = @import("std");
const linux = std.os.linux;
const Allocator = std.mem.Allocator;
const Connection = @import("client").Connection;
const format_ = @import("format.zig");
const Format = format_.Format;
const bindings = @import("bindings.zig");
const protocols = @import("wayland-protocols");

const Feedback = @This();

gpa: Allocator,
conn: *Connection,
/// Null when filled from a version 3 compositor's events.
object: ?FeedbackObject,

/// The device the compositor composites on, as a `dev_t`. Null when the
/// compositor has not said -- which a version 3 compositor never does.
main_device: ?u64 = null,
/// In the compositor's order of preference: the first tranche is the one it
/// would most like buffers to match.
tranches: std.ArrayList(Tranche) = .empty,
/// How many batches have arrived. Zero until the first `done`.
generation: u32 = 0,
/// Set by each batch, for the consumer to clear once it has acted on it.
changed: bool = false,
/// Called after each batch.
on_change: ?Hook = null,

// The batch being assembled.
table: []FormatModifier = &.{},
pending_main_device: ?u64 = null,
pending_tranches: std.ArrayList(Tranche) = .empty,
building: Building = .{},

const FeedbackObject = if (bindings.has_dmabuf) protocols.zwp.LinuxDmabufFeedbackV1 else void;

pub const FormatModifier = struct {
    format: Format,
    modifier: u64,
};

pub const Tranche = struct {
    /// The device buffers matching this tranche should be allocated on, as
    /// a `dev_t`; null for a version 3 compositor's single tranche.
    target_device: ?u64,
    /// Buffers matching this tranche may be scanned out directly, without
    /// the compositor copying them.
    scanout: bool,
    /// In the compositor's order.
    pairs: []const FormatModifier,
};

pub const Hook = struct {
    context: ?*anyopaque,
    call: *const fn (context: ?*anyopaque, feedback: *Feedback) void,
};

const Building = struct {
    target_device: ?u64 = null,
    scanout: bool = false,
    indices: std.ArrayList(u16) = .empty,
};

/// An empty feedback, listening to `object` if one is given.
pub fn create(gpa: Allocator, conn: *Connection, object: ?FeedbackObject) !*Feedback {
    const f = try gpa.create(Feedback);
    errdefer gpa.destroy(f);
    f.* = .{ .gpa = gpa, .conn = conn, .object = object };
    if (bindings.has_dmabuf) {
        if (object) |o| try conn.setListener(o, f, onEvent);
    }
    return f;
}

/// Destroys the feedback object, if there is one, and frees everything.
pub fn destroy(f: *Feedback) void {
    if (bindings.has_dmabuf) {
        if (f.object) |o| o.destroy(&f.conn.session) catch {};
    }
    freeTranches(f.gpa, &f.tranches);
    freeTranches(f.gpa, &f.pending_tranches);
    f.building.indices.deinit(f.gpa);
    f.gpa.free(f.table);
    f.gpa.destroy(f);
}

/// The modifiers the compositor accepts with `format`, in its order of
/// preference and without repeats. Owned by the caller.
pub fn modifiers(f: *const Feedback, gpa: Allocator, format: Format) Allocator.Error![]u64 {
    var list: std.ArrayList(u64) = .empty;
    errdefer list.deinit(gpa);
    for (f.tranches.items) |tranche| {
        for (tranche.pairs) |pair| {
            if (pair.format != format) continue;
            if (std.mem.findScalar(u64, list.items, pair.modifier) != null) continue;
            try list.append(gpa, pair.modifier);
        }
    }
    return list.toOwnedSlice(gpa);
}

/// Whether the compositor accepts `format` with any modifier at all.
pub fn supports(f: *const Feedback, format: Format) bool {
    for (f.tranches.items) |tranche| {
        for (tranche.pairs) |pair| if (pair.format == format) return true;
    }
    return false;
}

/// Adds a pair to the single tranche of a version 3 compositor, which says
/// what it accepts one event at a time with no batches.
pub fn addLegacy(f: *Feedback, pair: FormatModifier) Allocator.Error!void {
    if (f.tranches.items.len == 0) try f.tranches.append(f.gpa, .{ .target_device = null, .scanout = false, .pairs = &.{} });
    const tranche = &f.tranches.items[0];
    for (tranche.pairs) |p| if (p.format == pair.format and p.modifier == pair.modifier) return;
    const pairs = try f.gpa.alloc(FormatModifier, tranche.pairs.len + 1);
    @memcpy(pairs[0..tranche.pairs.len], tranche.pairs);
    pairs[tranche.pairs.len] = pair;
    f.gpa.free(tranche.pairs);
    tranche.pairs = pairs;
    f.changed = true;
}

fn freeTranches(gpa: Allocator, list: *std.ArrayList(Tranche)) void {
    for (list.items) |t| gpa.free(t.pairs);
    list.deinit(gpa);
}

/// A `dev_t` from the array the protocol carries it in, which is exactly
/// `sizeof(dev_t)` bytes -- eight on Linux. Anything else is not one.
fn devT(bytes: []const u8) ?u64 {
    if (bytes.len != @sizeOf(u64)) return null;
    return std.mem.readInt(u64, bytes[0..8], @import("builtin").cpu.arch.endian());
}

const EventUnion = if (bindings.has_dmabuf) protocols.zwp.LinuxDmabufFeedbackV1.Event else void;

fn onEvent(f: *Feedback, _: *Connection, _: FeedbackObject, event: EventUnion) !void {
    switch (event) {
        .format_table => |t| {
            defer _ = linux.close(t.fd);
            try f.readTable(t.fd, t.size);
        },
        .main_device => |d| f.pending_main_device = devT(d.device),
        .tranche_target_device => |d| f.building.target_device = devT(d.device),
        .tranche_flags => |flags| f.building.scanout = flags.flags.scanout,
        .tranche_formats => |formats| {
            const count = formats.indices.len / 2;
            try f.building.indices.ensureUnusedCapacity(f.gpa, count);
            for (0..count) |i| {
                f.building.indices.appendAssumeCapacity(std.mem.readInt(u16, formats.indices[i * 2 ..][0..2], @import("builtin").cpu.arch.endian()));
            }
        },
        .tranche_done => {
            // Indices past the end of the table are the compositor's mistake,
            // and are dropped rather than trusted.
            var pairs: std.ArrayList(FormatModifier) = .empty;
            errdefer pairs.deinit(f.gpa);
            for (f.building.indices.items) |i| {
                if (i < f.table.len) try pairs.append(f.gpa, f.table[i]);
            }
            try f.pending_tranches.ensureUnusedCapacity(f.gpa, 1);
            f.pending_tranches.appendAssumeCapacity(.{
                .target_device = f.building.target_device,
                .scanout = f.building.scanout,
                .pairs = try pairs.toOwnedSlice(f.gpa),
            });
            f.building.indices.clearRetainingCapacity();
            f.building.target_device = null;
            f.building.scanout = false;
        },
        .done => {
            freeTranches(f.gpa, &f.tranches);
            f.tranches = f.pending_tranches;
            f.pending_tranches = .empty;
            f.main_device = f.pending_main_device;
            f.generation += 1;
            f.changed = true;
            if (f.on_change) |hook| hook.call(hook.context, f);
        },
    }
}

/// Copies the format table out of the file the compositor sent. A table
/// that is not a whole number of entries is read as far as it goes.
fn readTable(f: *Feedback, fd: linux.fd_t, size: u32) !void {
    const entry_size = 16;
    const count = size / entry_size;
    const table = try f.gpa.alloc(FormatModifier, count);
    errdefer f.gpa.free(table);
    if (count > 0) {
        const mapped = linux.mmap(null, size, .{ .READ = true }, .{ .TYPE = .PRIVATE }, fd, 0);
        if (linux.errno(mapped) != .SUCCESS) return error.FormatTableUnreadable;
        const bytes = @as([*]const u8, @ptrFromInt(mapped))[0..size];
        defer _ = linux.munmap(bytes.ptr, bytes.len);
        const endian = @import("builtin").cpu.arch.endian();
        for (table, 0..) |*entry, i| {
            const raw = bytes[i * entry_size ..][0..entry_size];
            entry.* = .{
                .format = @fromBackingInt(std.mem.readInt(u32, raw[0..4], endian)),
                .modifier = std.mem.readInt(u64, raw[8..16], endian),
            };
        }
    }
    f.gpa.free(f.table);
    f.table = table;
}
