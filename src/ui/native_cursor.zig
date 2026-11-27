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

/// Binds the optional shape manager and the current pointer's shape device.
pub fn bindManager(self: *Self, conn: *Connection, registry: wl.Registry, global: u32, pointer: ?wl.Pointer) !void {
    if (self.manager != null) return;
    self.manager = try registry.bind(&conn.session, global, wp.CursorShapeManagerV1, 1);
    self.global = global;
    if (pointer) |p| try self.bindPointer(conn, p);
}

/// Rejects removal of the bound shape manager; unrelated globals are harmless.
pub fn removeManager(self: *Self, global: u32) !void {
    if (self.global == global) return error.NativeCursorManagerRemoved;
}

/// Creates at most one shape device for the selected pointer.
pub fn bindPointer(self: *Self, conn: *Connection, pointer: wl.Pointer) !void {
    if (self.manager) |manager| {
        if (self.device == null) self.device = try manager.getPointer(&conn.session, pointer);
    }
}

/// Retires the pointer-specific shape device, retaining the immutable fallback.
pub fn releasePointer(self: *Self, conn: *Connection) !void {
    const device = self.device orelse return;
    self.device = null;
    try device.destroy(&conn.session);
}

/// Retires cursor proxies and backing storage before the display connection closes.
pub fn deinit(self: *Self, conn: *Connection) void {
    self.releasePointer(conn) catch |err| {
        std.log.debug("native cursor device retirement: {s}", .{@errorName(err)});
    };
    if (self.surface) |surface| retireSurface(conn, surface);
    if (self.pool) |pool| retirePool(conn, pool);
    self.* = .{};
}

/// Sets the default cursor using the exact pointer-enter serial.
pub fn show(self: *Self, conn: *Connection, pointer: wl.Pointer, serial: u32) !void {
    const session = &conn.session;
    if (self.device) |device| {
        try device.setShape(session, serial, .default);
        return;
    }
    // Keep the same committed cursor buffer, never paint into it again.
    // No frame callback is requested for the cursor surface.
    if (self.surface) |surface| {
        std.debug.assert(self.pool != null);
        try pointer.setCursor(session, serial, surface, 1, 1);
        return;
    }
    std.debug.assert(self.pool == null);
    const compositor = self.compositor orelse return error.NativeCursorCompositor;
    const shm = self.shm orelse return error.NativeCursorShm;

    // Prepare the complete fallback before assigning a cursor role to the
    // surface. A failed pool or buffer acquisition cannot publish a cursor.
    const pool = try present.BufferPool.create(conn.gpa, conn, shm, .{ .max_buffers = 1 });
    errdefer retirePool(conn, pool);
    const buffer = (try pool.acquire(side, side, .argb8888)) orelse return error.NativeCursorBuffer;
    paint(buffer.pixels(), buffer.stride);
    const surface = try compositor.createSurface(session);
    errdefer retireSurface(conn, surface);
    try pointer.setCursor(session, serial, surface, 1, 1);
    try surface.attach(session, buffer.wl_buffer, 0, 0);
    try surface.setBufferScale(session, 2);
    try surface.damageBuffer(session, 0, 0, side, side);
    try surface.commit(session);
    buffer.state = .busy;
    self.surface = surface;
    self.pool = pool;
}

fn retireSurface(conn: *Connection, surface: wl.Surface) void {
    surface.destroy(&conn.session) catch |err| {
        std.log.debug("native cursor surface retirement: {s}", .{@errorName(err)});
    };
}

fn retirePool(conn: *Connection, pool: *present.BufferPool) void {
    // A non-live object already has no reachable callback context.
    for (pool.buffers.items) |buffer| {
        conn.clearListener(buffer.wl_buffer) catch |err| switch (err) {
            error.InvalidObject => continue,
        };
    }
    pool.destroy();
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
