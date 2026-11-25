// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Explicit synchronization: `wp_linux_drm_syncobj_manager_v1`.
//!
//! Needs `staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml` in the
//! consumer's bindings, passed to `addProtocols` in `extra`.
//!
//! With explicit sync the compositor stops guessing when a buffer is ready
//! and when it is finished with one. Each commit that attaches a buffer
//! carries an *acquire point* -- a point on a DRM syncobj timeline that the
//! renderer signals when the pixels are written -- and a *release point*,
//! which the compositor signals when it no longer reads them. A timeline is
//! imported from a file descriptor: on Mesa, the opaque fd a Vulkan timeline
//! semaphore exports is exactly a DRM syncobj.
//!
//! `Presenter.enableExplicitSync` turns it on for a surface. From then on:
//!
//! - every `present` must give both points (`Presenter.Options.sync`), and
//!   the buffer must be a dma-buf -- the protocol makes either omission a
//!   protocol error that ends the connection, so `present` refuses first;
//! - `wl_buffer.release` is no longer defined for that surface's buffers, so
//!   the pool stops waiting for it, and the consumer calls
//!   `BufferPool.released` once the release point has signalled.

const std = @import("std");
const Connection = @import("client").Connection;
const wp = @import("wayland-protocols").wp;

const Syncobj = @This();

conn: *Connection,
manager: wp.LinuxDrmSyncobjManagerV1,

/// A manager the consumer has bound. `conn` must stay where it is for as long
/// as this is used.
pub fn init(conn: *Connection, manager: wp.LinuxDrmSyncobjManagerV1) Syncobj {
    return .{ .conn = conn, .manager = manager };
}

/// Imports the DRM syncobj timeline `fd` refers to. The request is sent
/// before this returns, and `fd` stays the caller's: close it whenever.
pub fn importTimeline(s: Syncobj, fd: std.posix.fd_t) !Timeline {
    const object = try s.manager.importTimeline(&s.conn.session, fd);
    try s.conn.flush();
    return .{ .object = object };
}

pub const Timeline = struct {
    object: wp.LinuxDrmSyncobjTimelineV1,

    /// The compositor may still be waiting on points of it; destroying the
    /// object does not cancel those.
    pub fn destroy(t: Timeline, conn: *Connection) !void {
        try t.object.destroy(&conn.session);
    }
};

/// A point on a timeline.
pub const Point = struct {
    timeline: Timeline,
    value: u64,
};

/// The two points one commit carries. On the same timeline, `acquire` must
/// come strictly before `release`.
pub const Points = struct {
    acquire: Point,
    release: Point,
};
