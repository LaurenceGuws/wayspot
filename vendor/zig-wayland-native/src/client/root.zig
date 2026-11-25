// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A Wayland client connection: the socket, the file descriptors that travel
//! over it, and the loop that hands events to listeners.
//!
//! Everything about the protocol itself -- the wire format, object ids,
//! protocol errors -- is the `protocol` module's, and a `Connection` holds a
//! `protocol.Session` to do it. What is here is only the I/O.
//!
//! ```zig
//! const client = @import("client");
//! const wl = @import("wayland-protocols").wl;
//!
//! var conn: client.Connection = try .connect(gpa, io, environ_map);
//! defer conn.deinit();
//!
//! const display: wl.Display = .{ .id = .display };
//! const registry = try display.getRegistry(&conn.session);
//! try conn.setListener(registry, &state, onRegistryEvent);
//! try conn.roundtrip();
//! ```

pub const Connection = @import("Connection.zig");

test {
    _ = Connection;
}
