// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The compositor's `zwp_linux_dmabuf_v1`, and what it accepts.
//!
//! Needs `stable/linux-dmabuf/linux-dmabuf-v1.xml` in the consumer's bindings,
//! passed to `addProtocols` in `extra`. The consumer binds the global -- at
//! version 4 or later if the compositor has it, for feedback -- and hands it
//! to `create`, which takes over its listener, as `Shm` does `wl_shm`'s.
//!
//! - At version 4 and later, the default feedback is requested at once, and
//!   `feedback()` is it: the main device, and the tranches of format and
//!   modifier pairs in the compositor's order of preference. One round trip
//!   after `create` brings the first batch.
//! - At version 3, the compositor sends a `modifier` event per pair instead,
//!   straight after the bind; one round trip brings them all. There is no
//!   main device, and `mainDevice()` says so by being null rather than
//!   guessing.
//! - Before version 3 there are only formats, whose modifier is
//!   `modifier.invalid`: whatever the driver picks.
//!
//! The memory behind a dma-buf is allocated by whoever renders -- a GPU
//! driver, typically -- so this module never allocates it. `Allocator` is
//! how `BufferPool` asks for some.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = @import("client").Connection;
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const zwp = protocols.zwp;
const format_ = @import("format.zig");
const Format = format_.Format;
const Feedback = @import("Feedback.zig");

const Dmabuf = @This();

gpa: Allocator,
conn: *Connection,
object: zwp.LinuxDmabufV1,
/// The version `object` was bound at.
version: u32,
default: *Feedback,

/// What a GPU-side allocator provides to `BufferPool.createDmabuf`.
///
/// `allocate` is given the modifiers the compositor accepts for the format,
/// in its order of preference, picks one it can produce, and allocates.
/// `free` is called with the handle when the pool retires the buffer: after
/// the compositor has released it, or when the pool is destroyed.
pub const BufferAllocator = struct {
    context: ?*anyopaque,
    allocate: *const fn (context: ?*anyopaque, width: u32, height: u32, format: Format, modifiers: []const u64) anyerror!Allocation,
    free: *const fn (context: ?*anyopaque, handle: ?*anyopaque) void,
};

/// One allocated dma-buf.
///
/// The plane descriptors stay the allocator's. The pool sends them to the
/// compositor and flushes before `acquire` returns, and never closes them:
/// the allocator may close them as soon as the buffer exists, or keep them
/// until `free`, as suits it.
pub const Allocation = struct {
    /// Whatever the allocator needs to find this again in `free` -- a
    /// Vulkan image, say.
    handle: ?*anyopaque,
    /// The modifier it was allocated with, one of those it was offered.
    modifier: u64,
    planes: [4]Plane = undefined,
    plane_count: u3,

    pub fn planeSlice(a: *const Allocation) []const Plane {
        return a.planes[0..a.plane_count];
    }
};

pub const Plane = struct {
    fd: std.posix.fd_t,
    offset: u32,
    stride: u32,
};

/// Starts listening to `object`, which the consumer has bound. `conn` must
/// stay where it is for as long as this does.
pub fn create(gpa: Allocator, conn: *Connection, object: zwp.LinuxDmabufV1) !*Dmabuf {
    const s = &conn.session;
    const version = s.versionOf(object.id) orelse return error.InvalidObject;
    const d = try gpa.create(Dmabuf);
    errdefer gpa.destroy(d);

    const feedback_object: ?zwp.LinuxDmabufFeedbackV1 = if (version >= 4) try object.getDefaultFeedback(s) else null;
    const default: *Feedback = try .create(gpa, conn, feedback_object);
    errdefer default.destroy();

    d.* = .{ .gpa = gpa, .conn = conn, .object = object, .version = version, .default = default };
    if (version < 4) try conn.setListener(object, d, onDmabufEvent);
    return d;
}

/// Destroys the default feedback object and frees everything. The
/// `zwp_linux_dmabuf_v1` itself is the caller's to destroy.
pub fn destroy(d: *Dmabuf) void {
    if (d.version < 4) d.conn.clearListener(d.object) catch {};
    d.default.destroy();
    d.gpa.destroy(d);
}

/// The default feedback: what the compositor accepts for any surface.
pub fn feedback(d: *const Dmabuf) *Feedback {
    return d.default;
}

/// The device the compositor composites on, as a `dev_t`, if it has said.
pub fn mainDevice(d: *const Dmabuf) ?u64 {
    return d.default.main_device;
}

/// The modifiers the compositor accepts with `format`, in its order of
/// preference. Owned by the caller.
pub fn modifiers(d: *const Dmabuf, gpa: Allocator, format: Format) Allocator.Error![]u64 {
    return d.default.modifiers(gpa, format);
}

pub fn supports(d: *const Dmabuf, format: Format) bool {
    return d.default.supports(format);
}

/// Feedback for one surface, which can say more than the default -- that a
/// fullscreen window could be scanned out directly, say. Needs version 4.
/// The caller destroys it.
pub fn surfaceFeedback(d: *Dmabuf, surface: wl.Surface) !*Feedback {
    if (d.version < 4) return error.UnsupportedVersion;
    const object = try d.object.getSurfaceFeedback(&d.conn.session, surface);
    return Feedback.create(d.gpa, d.conn, object);
}

fn onDmabufEvent(d: *Dmabuf, _: *Connection, _: zwp.LinuxDmabufV1, event: zwp.LinuxDmabufV1.Event) !void {
    switch (event) {
        // From version 3 the same formats come again with their modifiers,
        // so these are only worth anything before it.
        .format => |f| if (d.version < 3) try d.default.addLegacy(.{
            .format = @fromBackingInt(f.format),
            .modifier = format_.modifier.invalid,
        }),
        .modifier => |m| try d.default.addLegacy(.{
            .format = @fromBackingInt(m.format),
            .modifier = @as(u64, m.modifier_hi) << 32 | m.modifier_lo,
        }),
    }
}
