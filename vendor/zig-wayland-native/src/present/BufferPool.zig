// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Buffers to draw into, which are never handed out while the compositor
//! still holds them.
//!
//! A buffer goes through three states. `acquire` hands out a *free* one as
//! *acquired*; presenting it makes it *busy*, because the compositor may read
//! it until it sends `wl_buffer.release`; the release makes it free again.
//! Two buffers are usually enough -- one on screen, one being drawn -- and a
//! third is made when both are busy, up to `Options.max_buffers`. When every
//! buffer is busy and no more may be made, `acquire` returns null and the
//! caller dispatches until a release arrives.
//!
//! Asking for a different size or format is a resize. Free buffers of the old
//! shape are destroyed at once; busy ones are marked stale and destroyed when
//! the compositor releases them, since destroying a buffer the compositor may
//! still be showing invites a glitch on some compositors.
//!
//! A pool has one of two backings, chosen when it is made:
//!
//! - **Shared memory** (`create`). Each buffer is its own `memfd`, mapped
//!   here and shared with the compositor through its own `wl_shm_pool`,
//!   which is destroyed straight away -- the buffer keeps what it needs of
//!   the pool alive. One pool per buffer costs a file descriptor each and
//!   makes a resize nothing more than a new buffer. `Buffer.pixels` is the
//!   mapping.
//! - **dma-buf** (`createDmabuf`). The memory comes from a
//!   `Dmabuf.BufferAllocator` -- a GPU driver, typically -- offered the
//!   modifiers the compositor accepts for the format. The pool turns what it
//!   allocated into a `wl_buffer` with `zwp_linux_buffer_params_v1`'s
//!   asynchronous `create`, so a buffer the compositor refuses is
//!   `error.BufferCreationFailed`, which a caller can fall back from, rather
//!   than a protocol error that ends the connection. That waits for the
//!   compositor's answer, dispatching as it does, so `acquire` on such a pool
//!   must not be called from a listener.
//!
//! Under explicit sync (`Presenter.enableExplicitSync`), the compositor no
//! longer promises `wl_buffer.release`, so a buffer presented with sync points
//! stays busy until the consumer, having seen the release point signal, calls
//! `released`.

const std = @import("std");
const linux = std.os.linux;
const Allocator = std.mem.Allocator;
const Connection = @import("client").Connection;
const Session = @import("protocol").Session;
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const Format = @import("format.zig").Format;
const Shm = @import("Shm.zig");
const bindings = @import("bindings.zig");
const Dmabuf = if (bindings.has_dmabuf) @import("Dmabuf.zig") else void;

const BufferPool = @This();

gpa: Allocator,
conn: *Connection,
backing: Backing,
options: Options,
buffers: std.ArrayList(*Buffer) = .empty,
/// What the dma-buf allocator returned when `acquire` last failed with
/// `error.AllocationFailed`.
allocator_error: ?anyerror = null,

pub const Backing = union(enum) {
    shm: *Shm,
    dmabuf: if (bindings.has_dmabuf) DmabufBacking else void,
};

const DmabufBacking = if (bindings.has_dmabuf) struct {
    dmabuf: *Dmabuf,
    allocator: Dmabuf.BufferAllocator,
} else void;

pub const Options = struct {
    /// How many buffers of the current shape may exist at once. Two is the
    /// least that lets drawing overlap with the compositor reading; three
    /// covers a compositor that holds on to the previous buffer for a frame.
    max_buffers: u8 = 3,
};

/// One buffer: the compositor's `wl_buffer`, and what backs it.
pub const Buffer = struct {
    pool: *BufferPool,
    wl_buffer: wl.Buffer,
    width: u32,
    height: u32,
    /// Bytes from the start of one row to the start of the next.
    stride: u32,
    format: Format,
    state: State = .acquired,
    /// Of a shape the pool no longer hands out; destroyed on release.
    stale: bool = false,
    /// Last presented with explicit sync, so `wl_buffer.release` is not to be
    /// waited for, and `BufferPool.released` says when it is free.
    explicit_release: bool = false,
    storage: Storage,

    pub const State = enum { free, acquired, busy };

    /// What the buffer's pixels live in.
    pub const Storage = union(enum) {
        shm: struct { memory: []align(std.heap.page_size_min) u8 },
        /// The allocator's handle, and what it allocated. No CPU mapping:
        /// the pixels are wherever the allocator put them.
        dmabuf: struct {
            handle: ?*anyopaque,
            modifier: u64,
            planes: [4]Plane,
            plane_count: u3,
        },
    };

    pub const Plane = struct {
        fd: std.posix.fd_t,
        offset: u32,
        stride: u32,
    };

    /// The pixels, `stride * height` bytes, mapped and writable. Only a
    /// buffer in shared memory has any; see `mapped` for one that may not.
    /// Valid until the buffer is destroyed.
    pub fn pixels(b: *const Buffer) []u8 {
        return b.mapped().?;
    }

    /// The pixels if the buffer is mapped -- in shared memory -- or null.
    pub fn mapped(b: *const Buffer) ?[]u8 {
        return switch (b.storage) {
            .shm => |shm| shm.memory,
            .dmabuf => null,
        };
    }
};

/// The errors `acquire` raises itself. It returns `anyerror` because a
/// dma-buf pool dispatches while it waits for the compositor, and a listener
/// dispatched then may return anything.
pub const AcquireError = Connection.IoError || Session.RequestError || error{
    /// The compositor has not said it accepts the format -- in shared memory,
    /// or as a dma-buf with any modifier -- or it has no single-plane layout
    /// a shared memory pool can allocate.
    UnsupportedFormat,
    /// Zero, or too large for the protocol's 32-bit sizes.
    InvalidSize,
    /// memfd_create, ftruncate or mmap failed.
    SystemResources,
    /// The dma-buf allocator failed; `allocator_error` says how.
    AllocationFailed,
    /// The allocator returned no planes, or more than four.
    InvalidAllocation,
    /// The compositor refused the dma-buf. Worth falling back from -- to
    /// another modifier, or to shared memory.
    BufferCreationFailed,
};

/// A pool drawing its buffers from `shm`. `conn` and `shm` must outlive it.
pub fn create(gpa: Allocator, conn: *Connection, shm: *Shm, options: Options) Allocator.Error!*BufferPool {
    const pool = try gpa.create(BufferPool);
    pool.* = .{ .gpa = gpa, .conn = conn, .backing = .{ .shm = shm }, .options = options };
    return pool;
}

/// A pool of dma-bufs from `allocator`, offered the modifiers `dmabuf` says
/// the compositor accepts. `conn` and `dmabuf` must outlive it. Needs
/// linux-dmabuf in the bindings, and is `void` without it.
pub const createDmabuf = if (bindings.has_dmabuf) createDmabufImpl else {};

fn createDmabufImpl(
    gpa: Allocator,
    conn: *Connection,
    dmabuf: *Dmabuf,
    allocator: Dmabuf.BufferAllocator,
    options: Options,
) Allocator.Error!*BufferPool {
    const pool = try gpa.create(BufferPool);
    pool.* = .{
        .gpa = gpa,
        .conn = conn,
        .backing = .{ .dmabuf = .{ .dmabuf = dmabuf, .allocator = allocator } },
        .options = options,
    };
    return pool;
}

/// Destroys every buffer, busy or not, and the pool. A buffer on screen stays
/// on screen: the compositor keeps what it last showed.
pub fn destroy(pool: *BufferPool) void {
    for (pool.buffers.items) |b| pool.free(b);
    pool.buffers.deinit(pool.gpa);
    pool.gpa.destroy(pool);
}

/// A buffer of `width` by `height` in `format` that the compositor is not
/// using, or null if every buffer is busy and no more may be made. What it
/// holds is whatever was last drawn in it, or zeros if it is new.
///
/// The buffer is the caller's until it is presented or given back with
/// `cancel`.
pub fn acquire(pool: *BufferPool, width: u32, height: u32, format: Format) anyerror!?*Buffer {
    switch (pool.backing) {
        .shm => |shm| if (format.bytesPerPixel() == null or !shm.supports(format)) return error.UnsupportedFormat,
        .dmabuf => |d| if (bindings.has_dmabuf) {
            if (!d.dmabuf.supports(format)) return error.UnsupportedFormat;
        } else unreachable,
    }
    if (width == 0 or height == 0 or width > std.math.maxInt(i32) or height > std.math.maxInt(i32))
        return error.InvalidSize;

    // Retire whatever is of another shape.
    var i: usize = 0;
    while (i < pool.buffers.items.len) {
        const b = pool.buffers.items[i];
        if (b.width == width and b.height == height and b.format == format) {
            i += 1;
            continue;
        }
        if (b.state == .free) {
            pool.free(b);
            _ = pool.buffers.swapRemove(i);
        } else {
            b.stale = true;
            i += 1;
        }
    }

    var current: usize = 0;
    for (pool.buffers.items) |b| {
        if (b.stale) continue;
        if (b.state == .free) {
            b.state = .acquired;
            return b;
        }
        current += 1;
    }
    if (current >= pool.options.max_buffers) return null;

    try pool.buffers.ensureUnusedCapacity(pool.gpa, 1);
    const b = switch (pool.backing) {
        .shm => |shm| try pool.allocateShm(shm, width, height, format),
        .dmabuf => |d| if (bindings.has_dmabuf) try pool.allocateDmabuf(d, width, height, format) else unreachable,
    };
    // Dispatching for a dma-buf may have run listeners that took buffers out
    // of the list, but none that put any in, so the room reserved is there.
    pool.buffers.appendAssumeCapacity(b);
    return b;
}

/// Under explicit sync: the compositor has passed the release point `b` was
/// presented with, so it is free again. The pool cannot see that happen
/// itself, since it is a DRM syncobj rather than an event.
pub fn released(pool: *BufferPool, b: *Buffer) void {
    std.debug.assert(b.pool == pool);
    if (b.state != .busy) return;
    b.state = .free;
    if (b.stale) pool.remove(b);
}

/// Gives back a buffer from `acquire` without presenting it.
pub fn cancel(pool: *BufferPool, b: *Buffer) void {
    std.debug.assert(b.pool == pool and b.state == .acquired);
    b.state = .free;
    if (b.stale) pool.remove(b);
}

/// How many buffers exist, stale ones included.
pub fn count(pool: *const BufferPool) usize {
    return pool.buffers.items.len;
}

fn allocateShm(pool: *BufferPool, shm: *Shm, width: u32, height: u32, format: Format) AcquireError!*Buffer {
    const bpp = format.bytesPerPixel().?;
    // Rows start on a word boundary, which pixman -- and so most
    // compositors' software paths -- insists on for the 24-bit formats.
    const row = std.math.mul(u32, width, bpp) catch return error.InvalidSize;
    const stride = std.math.add(u32, row, 3) catch return error.InvalidSize;
    const aligned = stride & ~@as(u32, 3);
    const size = std.math.mul(u32, aligned, height) catch return error.InvalidSize;
    if (size > std.math.maxInt(i32) or width > std.math.maxInt(i32) or height > std.math.maxInt(i32))
        return error.InvalidSize;

    const rc = linux.memfd_create("wayland-shm", linux.MFD.CLOEXEC | linux.MFD.ALLOW_SEALING);
    if (linux.errno(rc) != .SUCCESS) return error.SystemResources;
    const fd: linux.fd_t = @intCast(rc);
    // The descriptor only has to live until the request carrying it is sent.
    defer _ = linux.close(fd);
    if (linux.errno(linux.ftruncate(fd, size)) != .SUCCESS) return error.SystemResources;
    // The compositor maps this too; sealing it against shrinking means no
    // client can make it read past the end. Best effort.
    _ = linux.fcntl(fd, linux.F.ADD_SEALS, linux.F.SEAL_SHRINK | linux.F.SEAL_SEAL);

    const mapped = linux.mmap(null, size, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, fd, 0);
    if (linux.errno(mapped) != .SUCCESS) return error.SystemResources;
    const memory = @as([*]align(std.heap.page_size_min) u8, @ptrFromInt(mapped))[0..size];
    errdefer _ = linux.munmap(memory.ptr, memory.len);

    const b = try pool.gpa.create(Buffer);
    errdefer pool.gpa.destroy(b);

    const s = &pool.conn.session;
    const shm_pool = try shm.shm.createPool(s, fd, @intCast(size));
    const wl_buffer = try shm_pool.createBuffer(s, 0, @intCast(width), @intCast(height), @intCast(aligned), @fromBackingInt(format.toShm()));
    try shm_pool.destroy(s);
    try pool.conn.flush();

    b.* = .{
        .pool = pool,
        .wl_buffer = wl_buffer,
        .width = width,
        .height = height,
        .stride = aligned,
        .format = format,
        .storage = .{ .shm = .{ .memory = memory } },
    };
    try pool.conn.setListener(wl_buffer, b, onBufferEvent);
    return b;
}

const ParamsResult = union(enum) { pending, created: wl.Buffer, failed };

fn allocateDmabuf(pool: *BufferPool, d: DmabufBacking, width: u32, height: u32, format: Format) anyerror!*Buffer {
    const modifiers = try d.dmabuf.modifiers(pool.gpa, format);
    defer pool.gpa.free(modifiers);
    if (modifiers.len == 0) return error.UnsupportedFormat;

    const allocation = d.allocator.allocate(d.allocator.context, width, height, format, modifiers) catch |e| {
        pool.allocator_error = e;
        return error.AllocationFailed;
    };
    errdefer d.allocator.free(d.allocator.context, allocation.handle);
    if (allocation.plane_count == 0 or allocation.plane_count > 4) return error.InvalidAllocation;

    const b = try pool.gpa.create(Buffer);
    errdefer pool.gpa.destroy(b);

    const s = &pool.conn.session;
    const params = try d.dmabuf.object.createParams(s);
    var result: ParamsResult = .pending;
    try pool.conn.setListener(params, &result, onParamsEvent);
    // Whatever happens, the params object is finished with, and `result`
    // must not be written after this frame is gone.
    defer {
        pool.conn.clearListener(params) catch {};
        params.destroy(s) catch {};
    }
    const hi: u32 = @truncate(allocation.modifier >> 32);
    const lo: u32 = @truncate(allocation.modifier);
    for (allocation.planeSlice(), 0..) |plane, i| {
        try params.add(s, plane.fd, @intCast(i), plane.offset, plane.stride, hi, lo);
    }
    try params.create(s, @intCast(width), @intCast(height), @backingInt(format), .{});
    try pool.conn.flush();
    while (result == .pending) _ = try pool.conn.dispatch();

    const wl_buffer = switch (result) {
        .pending => unreachable,
        .failed => return error.BufferCreationFailed,
        .created => |buffer| buffer,
    };
    var planes: [4]Buffer.Plane = undefined;
    for (allocation.planeSlice(), 0..) |plane, i| planes[i] = .{ .fd = plane.fd, .offset = plane.offset, .stride = plane.stride };
    b.* = .{
        .pool = pool,
        .wl_buffer = wl_buffer,
        .width = width,
        .height = height,
        .stride = allocation.planes[0].stride,
        .format = format,
        .storage = .{ .dmabuf = .{
            .handle = allocation.handle,
            .modifier = allocation.modifier,
            .planes = planes,
            .plane_count = allocation.plane_count,
        } },
    };
    try pool.conn.setListener(wl_buffer, b, onBufferEvent);
    return b;
}

fn onParamsEvent(
    result: *ParamsResult,
    _: *Connection,
    _: if (bindings.has_dmabuf) protocols.zwp.LinuxBufferParamsV1 else void,
    event: if (bindings.has_dmabuf) protocols.zwp.LinuxBufferParamsV1.Event else void,
) void {
    result.* = switch (event) {
        .created => |c| .{ .created = c.buffer },
        .failed => .failed,
    };
}

fn onBufferEvent(b: *Buffer, _: *Connection, _: wl.Buffer, event: wl.Buffer.Event) void {
    switch (event) {
        .release => {
            // Under explicit sync this event means nothing, and the buffer
            // may already be back in use; `released` is the word that counts.
            if (b.explicit_release or b.state != .busy) return;
            b.state = .free;
            if (b.stale) b.pool.remove(b);
        },
    }
}

/// Takes `b` out of the list and frees it.
fn remove(pool: *BufferPool, b: *Buffer) void {
    const i = std.mem.findScalar(*Buffer, pool.buffers.items, b).?;
    _ = pool.buffers.swapRemove(i);
    pool.free(b);
}

/// Destroys `b`'s `wl_buffer`, unmaps it and frees it, leaving the list alone.
fn free(pool: *BufferPool, b: *Buffer) void {
    // A destructor request cannot fail for want of memory in a way worth
    // reporting here: the session is gone if it does.
    b.wl_buffer.destroy(&pool.conn.session) catch {};
    switch (b.storage) {
        .shm => |shm| _ = linux.munmap(shm.memory.ptr, shm.memory.len),
        .dmabuf => |dmabuf| if (bindings.has_dmabuf) {
            const allocator = pool.backing.dmabuf.allocator;
            allocator.free(allocator.context, dmabuf.handle);
        } else unreachable,
    }
    pool.gpa.destroy(b);
}
