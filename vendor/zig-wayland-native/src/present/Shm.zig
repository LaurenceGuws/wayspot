// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The compositor's `wl_shm`, and the formats it has said it accepts.
//!
//! The formats arrive as `wl_shm.format` events straight after the global is
//! bound, so after `create` the caller round-trips once before relying on
//! `supports`. This takes over the `wl_shm`'s listener: nothing else should
//! set one.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = @import("client").Connection;
const wl = @import("wayland-protocols").wl;
const Format = @import("format.zig").Format;

const Shm = @This();

gpa: Allocator,
conn: *Connection,
shm: wl.Shm,
/// In the order the compositor announced them.
formats: std.ArrayList(Format) = .empty,

/// Starts listening for the formats `shm` announces. `conn` must stay where
/// it is for as long as this does.
pub fn create(gpa: Allocator, conn: *Connection, shm: wl.Shm) !*Shm {
    const s = try gpa.create(Shm);
    errdefer gpa.destroy(s);
    s.* = .{ .gpa = gpa, .conn = conn, .shm = shm };
    try conn.setListener(shm, s, onShmEvent);
    return s;
}

/// Stops listening. The `wl_shm` itself is the caller's to release.
pub fn destroy(s: *Shm) void {
    s.conn.clearListener(s.shm) catch {};
    s.formats.deinit(s.gpa);
    s.gpa.destroy(s);
}

/// Whether the compositor accepts `format` in shared memory. The protocol
/// requires every compositor to accept `argb8888` and `xrgb8888`, so those two
/// are always supported whether or not they have been announced yet.
pub fn supports(s: *const Shm, format: Format) bool {
    if (format == .argb8888 or format == .xrgb8888) return true;
    return std.mem.findScalar(Format, s.formats.items, format) != null;
}

fn onShmEvent(s: *Shm, _: *Connection, _: wl.Shm, event: wl.Shm.Event) !void {
    switch (event) {
        .format => |f| {
            const format = Format.fromShm(@backingInt(f.format));
            if (std.mem.findScalar(Format, s.formats.items, format) == null)
                try s.formats.append(s.gpa, format);
        },
    }
}
