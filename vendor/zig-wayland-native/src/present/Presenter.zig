// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Puts buffers on a `wl_surface`, and says when to draw the next one.
//!
//! `present` attaches a buffer, marks what changed, commits, and asks the
//! compositor with `wl_surface.frame` to say when it is a good time to draw
//! again. Until it says so, `ready` is false; when it does, `ready` turns true
//! and `on_frame`, if set, is called with the compositor's timestamp. A
//! caller that draws only when `ready` draws no faster than the compositor
//! shows frames, and not at all while the surface is hidden -- which is what
//! the frame callback is for.
//!
//! This owns no listener of the surface's, only of the frame callbacks it
//! requests, so the caller keeps the surface's own events.
//!
//! With `enableExplicitSync`, each present carries an acquire and a release
//! point on DRM syncobj timelines instead of relying on implicit sync; see
//! `Syncobj` for what that changes.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = @import("client").Connection;
const Session = @import("protocol").Session;
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const Buffer = @import("BufferPool.zig").Buffer;
const bindings = @import("bindings.zig");
const Syncobj = if (bindings.has_syncobj) @import("Syncobj.zig") else void;
const SyncSurface = if (bindings.has_syncobj) protocols.wp.LinuxDrmSyncobjSurfaceV1 else void;

const Presenter = @This();

gpa: Allocator,
conn: *Connection,
surface: wl.Surface,
/// The buffer scale last set on the surface.
scale: i32 = 1,
/// The frame callback not yet answered, if one is outstanding.
frame: ?wl.Callback = null,
/// The compositor's timestamp from the last frame callback, in
/// milliseconds with an undefined base -- good for measuring intervals.
last_frame_time: ?u32 = null,
/// Called when the compositor answers a frame callback.
on_frame: ?Hook = null,
/// The surface's explicit sync object, once `enableExplicitSync` has made
/// one.
sync_surface: ?SyncSurface = null,

pub const Hook = struct {
    context: ?*anyopaque,
    call: *const fn (context: ?*anyopaque, time: u32) void,
};

/// A rectangle in buffer pixels.
pub const Rect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const Options = struct {
    /// What changed since the last buffer presented on this surface, in
    /// buffer pixels. Null is the whole buffer.
    damage: ?[]const Rect = null,
    /// The buffer scale, when it differs from what the surface has. A
    /// buffer drawn at twice the surface's size for an output of scale 2 is
    /// presented with `.scale = 2`.
    scale: ?i32 = null,
    /// The acquire and release points, which are required once
    /// `enableExplicitSync` has been called and refused before it. Needs
    /// linux-drm-syncobj in the bindings.
    sync: ?(if (bindings.has_syncobj) Syncobj.Points else void) = null,
};

pub const PresentError = Connection.IoError || Session.RequestError || error{
    /// Explicit sync is on for this surface, and no points were given; the
    /// protocol would end the connection over it.
    SyncPointsRequired,
    /// Points were given, and explicit sync is not on for this surface.
    ExplicitSyncNotEnabled,
    /// Explicit sync is only defined for dma-buf buffers.
    SyncRequiresDmabuf,
    /// The acquire point is not before the release point on the same
    /// timeline; the protocol would end the connection over it.
    ConflictingSyncPoints,
};

/// A presenter for `surface`. `conn` must stay where it is for as long as
/// this does.
pub fn create(gpa: Allocator, conn: *Connection, surface: wl.Surface) Allocator.Error!*Presenter {
    const p = try gpa.create(Presenter);
    p.* = .{ .gpa = gpa, .conn = conn, .surface = surface };
    return p;
}

/// Frees the presenter. The surface is the caller's, and so is whatever is
/// on it.
pub fn destroy(p: *Presenter) void {
    // The callback may still be answered, and must not reach freed memory.
    if (p.frame) |cb| p.conn.clearListener(cb) catch {};
    p.disableExplicitSync();
    p.gpa.destroy(p);
}

/// Turns on explicit sync for the surface: from the next commit on, every
/// `present` must carry `Options.sync`, and only dma-buf buffers may be
/// presented. The protocol allows one sync object per surface. Needs
/// linux-drm-syncobj in the bindings, and is `void` without it.
pub const enableExplicitSync = if (bindings.has_syncobj) enableExplicitSyncImpl else {};

fn enableExplicitSyncImpl(p: *Presenter, syncobj: Syncobj) Session.RequestError!void {
    if (p.sync_surface != null) return;
    p.sync_surface = try syncobj.manager.getSurface(&p.conn.session, p.surface);
}

/// Turns explicit sync off again, and `wl_buffer.release` means something
/// once more for buffers presented after this.
pub fn disableExplicitSync(p: *Presenter) void {
    if (bindings.has_syncobj) {
        if (p.sync_surface) |sync| sync.destroy(&p.conn.session) catch {};
    }
    p.sync_surface = null;
}

/// Whether the compositor has answered the last frame callback, so that a
/// frame drawn now will be shown rather than queued behind another.
pub fn ready(p: *const Presenter) bool {
    return p.frame == null;
}

/// Attaches `buffer`, damages what `options` says changed, commits, and
/// sends it all. `buffer` must have come from `BufferPool.acquire`, and is
/// the compositor's until it releases it.
pub fn present(p: *Presenter, buffer: *Buffer, options: Options) PresentError!void {
    std.debug.assert(buffer.state == .acquired);
    const s = &p.conn.session;
    const version = s.versionOf(p.surface.id) orelse return error.InvalidObject;

    // Everything the protocol would punish with a protocol error is refused
    // here, before anything is sent.
    if (bindings.has_syncobj) {
        if (p.sync_surface != null) {
            const sync = options.sync orelse return error.SyncPointsRequired;
            if (buffer.storage != .dmabuf) return error.SyncRequiresDmabuf;
            if (sync.acquire.timeline.object.id == sync.release.timeline.object.id and
                sync.acquire.value >= sync.release.value) return error.ConflictingSyncPoints;
        } else if (options.sync != null) return error.ExplicitSyncNotEnabled;
    }

    if (p.frame == null) {
        const cb = try p.surface.frame(s);
        p.conn.setListener(cb, p, onFrameEvent) catch unreachable;
        p.frame = cb;
    }

    try p.surface.attach(s, buffer.wl_buffer, 0, 0);

    const scale = options.scale orelse p.scale;
    if (scale != p.scale) {
        try p.surface.setBufferScale(s, scale);
        p.scale = scale;
    }

    const whole: [1]Rect = .{.{ .x = 0, .y = 0, .width = @intCast(buffer.width), .height = @intCast(buffer.height) }};
    for (options.damage orelse &whole) |r| {
        if (version >= 4) {
            try p.surface.damageBuffer(s, r.x, r.y, r.width, r.height);
        } else {
            // Before version 4 there is only damage in surface coordinates,
            // which a scaled buffer has to be divided into, rounding outward.
            const x0 = @divFloor(r.x, scale);
            const y0 = @divFloor(r.y, scale);
            const x1 = std.math.divCeil(i32, r.x + r.width, scale) catch unreachable;
            const y1 = std.math.divCeil(i32, r.y + r.height, scale) catch unreachable;
            try p.surface.damage(s, x0, y0, x1 - x0, y1 - y0);
        }
    }

    if (bindings.has_syncobj) {
        if (p.sync_surface) |sync_surface| {
            const sync = options.sync.?;
            try sync_surface.setAcquirePoint(s, sync.acquire.timeline.object, @truncate(sync.acquire.value >> 32), @truncate(sync.acquire.value));
            try sync_surface.setReleasePoint(s, sync.release.timeline.object, @truncate(sync.release.value >> 32), @truncate(sync.release.value));
        }
    }

    try p.surface.commit(s);
    buffer.state = .busy;
    buffer.explicit_release = p.sync_surface != null;
    try p.conn.flush();
}

fn onFrameEvent(p: *Presenter, _: *Connection, _: wl.Callback, event: wl.Callback.Event) void {
    switch (event) {
        .done => |done| {
            p.frame = null;
            p.last_frame_time = done.callback_data;
            if (p.on_frame) |hook| hook.call(hook.context, done.callback_data);
        },
    }
}
