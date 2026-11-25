// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The Wayland protocol with the I/O taken out.
//!
//! This module encodes requests and decodes events, keeps track of which
//! object each id names, and handles the parts of the protocol that belong to
//! the connection rather than to the application -- `wl_display.error` and
//! `wl_display.delete_id`. It never opens, reads, writes or closes anything:
//! bytes and file descriptors go in and come out, and moving them is the job
//! of the `client` module, or of a test.
//!
//! The bindings the scanner generates are written against this module, so a
//! program can speak a protocol through `Session` with no socket at all.

pub const wire = @import("wire.zig");
pub const core = @import("core.zig");
pub const Interface = @import("Interface.zig");
pub const ObjectMap = @import("ObjectMap.zig");
pub const Session = @import("Session.zig");

pub const Arg = wire.Arg;
pub const Fd = wire.Fd;
pub const Fixed = wire.Fixed;
pub const ObjectId = wire.ObjectId;
pub const Message = Session.Message;

/// The id of a generated object, or of an optional one, for a request
/// argument: `.null` for a missing object.
pub fn objectId(object: anytype) ObjectId {
    return switch (@typeInfo(@TypeOf(object))) {
        .optional => if (object) |o| o.id else .null,
        .null => .null,
        else => object.id,
    };
}

test {
    _ = wire;
    _ = ObjectMap;
    _ = Session;
}
