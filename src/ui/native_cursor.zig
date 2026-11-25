//! Cursor-shape when advertised, otherwise one immutable 2x SHM arrow.
//! No theme lookup, GPU, cursor animation or additional event-loop owner.
const std = @import("std");
const Connection = @import("wayland-client").Connection;
const protocol = @import("wayland-protocols");
const wl = protocol.wl;
const wp = protocol.wp;
const present = @import("wayland-present");
const Self = @This();
const side = 48;

compositor: ?wl.Compositor = null,
shm: ?*present.Shm = null,
manager: ?wp.CursorShapeManagerV1 = null,
global: ?u32 = null,
device: ?wp.CursorShapeDeviceV1 = null,
surface: ?wl.Surface = null,
pool: ?*present.BufferPool = null,

pub fn bindManager(self: *Self, conn: *Connection, registry: wl.Registry, global: u32, pointer: ?wl.Pointer) !void {
    if (self.manager != null) return;
    self.manager = try registry.bind(&conn.session, global, wp.CursorShapeManagerV1, 1);
    self.global = global;
    if (pointer) |p| try self.bindPointer(conn, p);
}

pub fn removeManager(self: *Self, global: u32) !void {
    if (self.global == global) return error.NativeCursorManagerRemoved;
}

pub fn bindPointer(self: *Self, conn: *Connection, pointer: wl.Pointer) !void {
    if (self.manager) |manager| {
        if (self.device == null) self.device = try manager.getPointer(&conn.session, pointer);
    }
}

pub fn releasePointer(self: *Self, conn: *Connection) !void {
    if (self.device) |device| try device.destroy(&conn.session);
    self.device = null;
}

pub fn deinit(self: *Self, conn: *Connection) void {
    self.releasePointer(conn) catch {};
    if (self.surface) |surface| surface.destroy(&conn.session) catch {};
    if (self.pool) |pool| {
        for (pool.buffers.items) |buffer| conn.clearListener(buffer.wl_buffer) catch {};
        pool.destroy();
    }
}

pub fn show(self: *Self, conn: *Connection, pointer: wl.Pointer, serial: u32) !void {
    const session = &conn.session;
    if (self.device) |device| {
        try device.setShape(session, serial, .default);
        return;
    }
    // Keep the same committed cursor buffer, never paint into it again.
    // No frame callback is requested for the cursor surface.
    if (self.surface == null) {
        self.surface = try (self.compositor orelse return error.NativeCursorCompositor).createSurface(session);
        try pointer.setCursor(session, serial, self.surface.?, 1, 1);
        self.pool = try .create(conn.gpa, conn, self.shm orelse return error.NativeCursorShm, .{ .max_buffers = 1 });
        const buffer = (try self.pool.?.acquire(side, side, .argb8888)) orelse return error.NativeCursorBuffer;
        paint(buffer.pixels(), buffer.stride);
        try self.surface.?.attach(session, buffer.wl_buffer, 0, 0);
        try self.surface.?.setBufferScale(session, 2);
        try self.surface.?.damageBuffer(session, 0, 0, side, side);
        try self.surface.?.commit(session);
        buffer.state = .busy;
        return;
    }
    try pointer.setCursor(session, serial, self.surface.?, 1, 1);
}

fn paint(pixels: []u8, stride: u32) void {
    @memset(pixels, 0);
    // A simple outlined arrow, including a short stem. Integer geometry at
    // 2x is intentional; the compositor may resample at fractional scale.
    for (0..side) |y| for (0..side) |x| {
        const lx = x / 2;
        const ly = y / 2;
        const inside = ly >= 1 and ly <= 20 and lx >= 1 and (lx <= @min(ly, 13) or (ly >= 12 and lx >= 5 and lx <= 8));
        if (!inside) continue;
        const white = ly >= 3 and ly <= 17 and lx >= 2 and lx + 1 <= @min(ly, 12);
        const pixel: u32 = if (white) 0xffffffff else 0xff151515;
        std.mem.writeInt(u32, pixels[y * stride + x * 4 ..][0..4], pixel, @import("builtin").cpu.arch.endian());
    };
}
