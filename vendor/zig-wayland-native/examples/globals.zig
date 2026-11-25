// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Prints every global the compositor advertises, with its version: a small
//! `wayland-info`.

const std = @import("std");
const Connection = @import("client").Connection;
const wl = @import("wayland-protocols").wl;

pub fn main(init: std.process.Init) !void {
    var conn: Connection = try .connect(init.gpa, init.io, init.environ_map);
    defer conn.deinit();

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    const w = &stdout.interface;

    const display: wl.Display = .{ .id = .display };
    const registry = try display.getRegistry(&conn.session);
    try conn.setListener(registry, w, onRegistryEvent);
    // Every global is announced in reply to get_registry, so once the
    // compositor has answered everything sent so far, the list is complete.
    try conn.roundtrip();
    try w.flush();
}

fn onRegistryEvent(w: *std.Io.Writer, _: *Connection, _: wl.Registry, event: wl.Registry.Event) !void {
    switch (event) {
        .global => |global| try w.print("{d:>4}  {s} (version {d})\n", .{ global.name, global.interface, global.version }),
        .global_remove => {},
    }
}
