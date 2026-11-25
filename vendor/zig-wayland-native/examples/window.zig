// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A window: an `xdg_toplevel` showing a moving gradient, drawn by the CPU
//! into buffers from `present.BufferPool` and put on screen by
//! `present.Presenter` as fast as the compositor asks for frames. It follows
//! the size the compositor asks for and goes away when it is closed.
//!
//! `--frames N` exits after N frames, once the compositor has them, which is
//! how to check it against a headless compositor.

const std = @import("std");
const Connection = @import("client").Connection;
const present = @import("present");
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const xdg = protocols.xdg;

const State = struct {
    compositor: ?wl.Compositor = null,
    wl_shm: ?wl.Shm = null,
    wm_base: ?xdg.WmBase = null,

    width: u32 = 640,
    height: u32 = 480,
    /// The first configure has been acknowledged, so buffers may be attached.
    configured: bool = false,
    running: bool = true,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var frame_limit: ?usize = null;
    for (args[1..], 1..) |arg, i| {
        if (std.mem.eql(u8, arg, "--frames") and i + 1 < args.len)
            frame_limit = try std.fmt.parseInt(usize, args[i + 1], 10);
    }

    var conn: Connection = try .connect(gpa, init.io, init.environ_map);
    defer conn.deinit();
    const s = &conn.session;

    var state: State = .{};
    const registry = try (wl.Display{ .id = .display }).getRegistry(s);
    try conn.setListener(registry, &state, onRegistryEvent);
    try conn.roundtrip();

    const compositor = state.compositor orelse return error.NoCompositor;
    const wm_base = state.wm_base orelse return error.NoXdgWmBase;
    try conn.setListener(wm_base, {}, onWmBaseEvent);

    const shm: *present.Shm = try .create(gpa, &conn, state.wl_shm orelse return error.NoShm);
    defer shm.destroy();
    const pool: *present.BufferPool = try .create(gpa, &conn, shm, .{});
    defer pool.destroy();

    const surface = try compositor.createSurface(s);
    const presenter: *present.Presenter = try .create(gpa, &conn, surface);
    defer presenter.destroy();

    const xdg_surface = try wm_base.getXdgSurface(s, surface);
    const toplevel = try xdg_surface.getToplevel(s);
    try conn.setListener(xdg_surface, &state, onXdgSurfaceEvent);
    try conn.setListener(toplevel, &state, onToplevelEvent);
    try toplevel.setTitle(s, "zig-wayland-native");
    try toplevel.setAppId(s, "dev.jcollie.zig-wayland-native");
    // Nothing may be attached until the compositor has sent the first
    // configure, and it sends that in reply to this empty commit.
    try surface.commit(s);

    var frames: usize = 0;
    while (state.running) {
        if (state.configured and presenter.ready()) {
            if (try pool.acquire(state.width, state.height, .xrgb8888)) |buffer| {
                draw(buffer, frames);
                try presenter.present(buffer, .{});
                frames += 1;
                if (frame_limit) |limit| if (frames >= limit) {
                    try conn.roundtrip();
                    std.log.info("presented {d} frames at {d}x{d} from {d} buffers", .{ frames, state.width, state.height, pool.count() });
                    return;
                };
            }
        }
        _ = try conn.dispatch();
    }
}

/// A gradient with a checkerboard over it, sliding a little every frame.
fn draw(buffer: *present.Buffer, frame: usize) void {
    const shift = frame * 4;
    for (0..buffer.height) |y| {
        const row: []align(1) u32 = @ptrCast(buffer.pixels()[y * buffer.stride ..][0 .. buffer.width * 4]);
        for (row, 0..) |*pixel, x| {
            const r: u32 = @intCast(x * 255 / buffer.width);
            const g: u32 = @intCast(y * 255 / buffer.height);
            const b: u32 = if (((x + shift) / 32 + y / 32) % 2 == 0) 0xc0 else 0x60;
            pixel.* = r << 16 | g << 8 | b;
        }
    }
}

fn onRegistryEvent(state: *State, conn: *Connection, registry: wl.Registry, event: wl.Registry.Event) !void {
    const global = switch (event) {
        .global => |g| g,
        .global_remove => return,
    };
    const s = &conn.session;
    if (std.mem.eql(u8, global.interface, "wl_compositor")) {
        state.compositor = try registry.bind(s, global.name, wl.Compositor, @min(global.version, 4));
    } else if (std.mem.eql(u8, global.interface, "wl_shm")) {
        state.wl_shm = try registry.bind(s, global.name, wl.Shm, 1);
    } else if (std.mem.eql(u8, global.interface, "xdg_wm_base")) {
        state.wm_base = try registry.bind(s, global.name, xdg.WmBase, @min(global.version, 2));
    }
}

fn onWmBaseEvent(_: void, conn: *Connection, wm_base: xdg.WmBase, event: xdg.WmBase.Event) !void {
    switch (event) {
        .ping => |ping| try wm_base.pong(&conn.session, ping.serial),
    }
}

fn onToplevelEvent(state: *State, _: *Connection, _: xdg.Toplevel, event: xdg.Toplevel.Event) void {
    switch (event) {
        // Zero means the compositor has no opinion, and the window keeps the
        // size it has.
        .configure => |c| {
            if (c.width > 0) state.width = @intCast(c.width);
            if (c.height > 0) state.height = @intCast(c.height);
        },
        .close => state.running = false,
        else => {},
    }
}

fn onXdgSurfaceEvent(state: *State, conn: *Connection, xdg_surface: xdg.Surface, event: xdg.Surface.Event) !void {
    switch (event) {
        .configure => |c| {
            try xdg_surface.ackConfigure(&conn.session, c.serial);
            state.configured = true;
        },
    }
}
