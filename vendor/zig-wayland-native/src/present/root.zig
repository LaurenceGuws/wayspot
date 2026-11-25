// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Getting pixels on screen: buffers to draw into, and a presenter that puts
//! them on a surface at the compositor's pace.
//!
//! It does not care what drew the pixels. A CPU renderer draws straight into
//! `Buffer.pixels`; a GPU renderer that reads back does the same with what it
//! read. A GPU renderer that exports its images hands them over as dma-bufs
//! instead, through `Dmabuf` and `BufferPool.createDmabuf`, behind the same
//! `acquire` and `present`, with explicit sync through `Syncobj` if it wants
//! it. Those two need `linux-dmabuf-v1` and `linux-drm-syncobj-v1` in the
//! bindings; `has_dmabuf` and `has_syncobj` say whether they are there.
//!
//! ```zig
//! const shm = try present.Shm.create(gpa, &conn, wl_shm);
//! try conn.roundtrip(); // for the formats
//! const pool = try present.BufferPool.create(gpa, &conn, shm, .{});
//! const presenter = try present.Presenter.create(gpa, &conn, surface);
//!
//! while (running) {
//!     if (presenter.ready()) {
//!         if (try pool.acquire(width, height, .xrgb8888)) |buffer| {
//!             draw(buffer.pixels(), buffer.stride);
//!             try presenter.present(buffer, .{});
//!         }
//!     }
//!     _ = try conn.dispatch();
//! }
//! ```
//!
//! This module imports the consumer's generated bindings, so its `wl.Buffer`
//! and `wl.Surface` are the consumer's own types; `addPresent` in `build.zig`
//! wires that up. Like `client`, it is Linux-only.

const format = @import("format.zig");
const bindings = @import("bindings.zig");

pub const Format = format.Format;
pub const fourcc = format.fourcc;
pub const modifier = format.modifier;
pub const Shm = @import("Shm.zig");
pub const BufferPool = @import("BufferPool.zig");
pub const Buffer = BufferPool.Buffer;
pub const Presenter = @import("Presenter.zig");

/// Whether the bindings this module was built against have
/// `linux-dmabuf-v1`, and so whether `Dmabuf` can be used.
pub const has_dmabuf = bindings.has_dmabuf;
/// Whether they have `linux-drm-syncobj-v1`, and so whether `Syncobj` and
/// `Presenter.enableExplicitSync` can be used.
pub const has_syncobj = bindings.has_syncobj;

/// `zwp_linux_dmabuf_v1`: what the compositor accepts, and the allocator
/// interface for buffers whose memory someone else allocates.
pub const Dmabuf = @import("Dmabuf.zig");
pub const Feedback = @import("Feedback.zig");
/// `wp_linux_drm_syncobj_manager_v1`: explicit sync.
pub const Syncobj = @import("Syncobj.zig");

test {
    _ = format;
}

// Every function analysed, whichever bindings this was built against: the
// build compiles these tests once with linux-dmabuf and linux-drm-syncobj
// and once without, so that the code behind `has_dmabuf` and `has_syncobj`
// stays out of reach when they are absent and compiles when they are there.
test "every declaration is analyzed" {
    const std = @import("std");
    std.testing.refAllDecls(Shm);
    std.testing.refAllDecls(BufferPool);
    std.testing.refAllDecls(Presenter);
    if (has_dmabuf) {
        std.testing.refAllDecls(Dmabuf);
        std.testing.refAllDecls(Feedback);
    }
    if (has_syncobj) std.testing.refAllDecls(Syncobj);
}
