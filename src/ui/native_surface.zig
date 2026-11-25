//! Native Wayland layer lifetimes and release-fenced CPU presentation.
//! No SDL video, toolkit, compositor CLI, timer or thread belongs here.
//! One visible-session connection can own a picker and a banner. The caller
//! drives its fd, paints only when admitted, and retires it when both close.
const std = @import("std");
const linux = std.os.linux;
const Connection = @import("wayland-client").Connection;
const present = @import("wayland-present");
const wl = @import("wayland-protocols").wl;
const zwlr = @import("wayland-protocols").zwlr;
const Allocator = std.mem.Allocator;

pub const Role = enum { picker, notification };
pub const max_buffers: usize = 3;
pub const max_surfaces: usize = 2;
pub const max_buffer_bytes: usize = 16 * 1024 * 1024;
pub const Extent = struct {
    width: u32,
    height: u32,

    pub fn validate(size: Extent) !void {
        if (size.width == 0 or size.height == 0 or size.width > 4096 or size.height > 4096) return error.InvalidSurfaceExtent;
        if (@as(u64, size.width) * size.height * 4 > max_buffer_bytes) return error.InvalidSurfaceExtent;
    }
};

/// A caller-owned event loop uses fd(), readReady() and flush(). Creation and
/// barriers are asynchronous: an unresponsive compositor never requires a
/// blocking roundtrip. The pinned transport's blocking send has a finite
/// socket timeout; failure poisons the connection rather than replaying bytes.
pub const Display = struct {
    allocator: Allocator,
    conn: Connection,
    compositor: ?wl.Compositor = null,
    manager: ?zwlr.LayerShellV1 = null,
    shm: ?*present.Shm = null,
    globals: [3]?u32 = @splat(null),
    discovery_done: bool = false,
    sync_pending: bool = false,
    failed: bool = false,
    surfaces: u8 = 0,
    occupied: [max_surfaces]bool = @splat(false),

    pub const Status = enum { discovering, ready, unavailable, failed };

    pub fn open(allocator: Allocator, io: std.Io, env: *const std.process.Environ.Map) !*Display {
        return adopt(allocator, try Connection.connect(allocator, io, env));
    }

    /// Takes the connection even on failure. Also used by deterministic
    /// socketpair tests; no special testing transport in product code.
    pub fn adopt(allocator: Allocator, conn: Connection) !*Display {
        var owned = conn;
        const self = allocator.create(Display) catch |err| {
            owned.deinit();
            return err;
        };
        self.* = .{ .allocator = allocator, .conn = owned };
        errdefer self.destroy();
        const timeout: linux.timeval = .{ .sec = 2, .usec = 0 };
        if (linux.errno(linux.setsockopt(self.conn.fd, linux.SOL.SOCKET, linux.SO.SNDTIMEO, std.mem.asBytes(&timeout), @sizeOf(linux.timeval))) != .SUCCESS) return error.NativeSendTimeoutSetup;
        const registry = try (wl.Display{ .id = .display }).getRegistry(&self.conn.session);
        try self.conn.setListener(registry, self, onRegistry);
        try self.requestSync();
        return self;
    }

    pub fn destroy(self: *Display) void {
        std.debug.assert(self.surfaces == 0);
        if (self.shm) |shm| shm.destroy();
        self.conn.deinit();
        self.allocator.destroy(self);
    }

    pub fn status(self: *const Display) Status {
        if (self.failed) return .failed;
        if (!self.discovery_done) return .discovering;
        if (self.compositor == null or self.manager == null or self.shm == null) return .unavailable;
        return .ready;
    }

    pub fn fd(self: *const Display) std.posix.fd_t {
        return self.conn.fd;
    }

    /// Call only for a readable/hung-up socket, on the single owner thread.
    pub fn readReady(self: *Display) !void {
        if (self.failed) return error.NativeConnectionFailed;
        errdefer self.failed = true;
        try self.conn.read();
        _ = try self.conn.dispatchPending();
        try self.flush();
    }

    pub fn flush(self: *Display) !void {
        if (self.failed) return error.NativeConnectionFailed;
        errdefer self.failed = true;
        try self.conn.flush();
    }

    /// One explicit sync fence. Following role destruction, wait for its
    /// reply in the event loop before requesting physical window focus.
    pub fn requestSync(self: *Display) !void {
        if (self.failed) return error.NativeConnectionFailed;
        if (self.sync_pending) return error.NativeSyncPending;
        errdefer self.failed = true;
        const callback = try (wl.Display{ .id = .display }).sync(&self.conn.session);
        try self.conn.setListener(callback, self, onSync);
        self.sync_pending = true;
        try self.flush();
    }

    fn onSync(self: *Display, _: *Connection, _: wl.Callback, _: wl.Callback.Event) void {
        self.discovery_done = true;
        self.sync_pending = false;
    }

    fn onRegistry(self: *Display, conn: *Connection, registry: wl.Registry, event: wl.Registry.Event) !void {
        const global = switch (event) {
            .global => |g| g,
            .global_remove => |r| {
                // Output removal is not connection loss. Only the three
                // required globals invalidate future presentation ownership.
                for (self.globals) |name| if (name == r.name) return error.NativeGlobalRemoved;
                return;
            },
        };
        const session = &conn.session;
        if (std.mem.eql(u8, global.interface, "wl_compositor") and self.compositor == null) {
            if (global.version < 4) return error.NativeCompositorVersion;
            self.compositor = try registry.bind(session, global.name, wl.Compositor, 4);
            self.globals[0] = global.name;
        } else if (std.mem.eql(u8, global.interface, "wl_shm") and self.shm == null) {
            const object = try registry.bind(session, global.name, wl.Shm, 1);
            self.shm = try .create(self.allocator, conn, object);
            self.globals[1] = global.name;
        } else if (std.mem.eql(u8, global.interface, "zwlr_layer_shell_v1") and self.manager == null) {
            self.manager = try registry.bind(session, global.name, zwlr.LayerShellV1, 1);
            self.globals[2] = global.name;
        }
    }
};

/// The only writable borrow of a SHM buffer. The callback may not dispatch
/// Wayland, retain pixels or return an SDL renderer that still references them.
pub const Frame = struct {
    extent: Extent,
    stride: u32,
    pixels: []u8,
};
pub const Draw = enum { not_configured, clean, frame_pending, buffers_busy, presented, closed };

pub const Surface = struct {
    display: *Display,
    role: Role,
    requested: Extent,
    extent: ?Extent = null,
    surface: ?wl.Surface = null,
    layer: ?zwlr.LayerSurfaceV1 = null,
    pool: ?*present.BufferPool = null,
    presenter: ?*present.Presenter = null,
    dirty: bool = true,
    closed: bool = false,
    painting: bool = false,

    /// Queue an empty initial commit; no buffer exists until configure.
    /// The heap address stays stable for protocol callback lifetime.
    pub fn create(display: *Display, role: Role, requested: Extent) !*Surface {
        try requested.validate();
        if (display.status() != .ready) return error.NativeDisplayNotReady;
        if (display.surfaces >= max_surfaces) return error.NativeSurfaceLimit;
        if (display.occupied[@backingInt(role)]) return error.NativeRoleAlreadyOwned;
        const self = try display.allocator.create(Surface);
        self.* = .{ .display = display, .role = role, .requested = requested };
        display.surfaces += 1;
        display.occupied[@backingInt(role)] = true;
        errdefer {
            display.failed = true;
            self.destroy() catch {};
        }
        const conn = &display.conn;
        const session = &conn.session;
        const surface = try display.compositor.?.createSurface(session);
        self.surface = surface;
        self.pool = try .create(display.allocator, conn, display.shm.?, .{ .max_buffers = max_buffers });
        self.presenter = try .create(display.allocator, conn, surface);
        const layer = try display.manager.?.getLayerSurface(session, surface, null, if (role == .picker) .overlay else .top, if (role == .picker) "wayspot-picker" else "wayspot-notification");
        self.layer = layer;
        try conn.setListener(layer, self, onLayer);
        try layer.setSize(session, requested.width, requested.height);
        try layer.setAnchor(session, if (role == .picker) .{} else .{ .top = true, .right = true });
        try layer.setExclusiveZone(session, -1);
        try layer.setKeyboardInteractivity(session, if (role == .picker) .exclusive else .none);
        if (role == .notification) try layer.setMargin(session, 16, 16, 0, 0);
        try surface.commit(session);
        try display.flush();
        return self;
    }

    fn onLayer(self: *Surface, conn: *Connection, layer: zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event) !void {
        switch (event) {
            .configure => |config| {
                if (self.closed) return;
                const extent: Extent = .{
                    .width = if (config.width == 0) self.requested.width else config.width,
                    .height = if (config.height == 0) self.requested.height else config.height,
                };
                try extent.validate();
                try layer.ackConfigure(&conn.session, config.serial);
                if (self.extent == null or !std.meta.eql(self.extent.?, extent)) {
                    self.extent = extent;
                    self.dirty = true;
                }
            },
            .closed => self.closed = true,
        }
    }

    pub fn invalidate(self: *Surface) void {
        self.dirty = true;
    }

    /// One paint and commit at most. Frame readiness and buffer release are
    /// distinct fences; neither substitutes for the other. The upstream
    /// pool bounds *current-shape* buffers only, so count all held shapes
    /// here before acquire. Rapid resizes cannot grow a stale-buffer tail.
    pub fn draw(self: *Surface, context: anytype, comptime paint: anytype) !Draw {
        if (self.display.failed) return error.NativeConnectionFailed;
        if (self.closed) return .closed;
        const extent = self.extent orelse return .not_configured;
        if (!self.dirty) return .clean;
        if (!self.presenter.?.ready()) return .frame_pending;
        std.debug.assert(!self.painting);
        const pool = self.pool.?;
        var held: usize = 0;
        for (pool.buffers.items) |buffer| {
            std.debug.assert(buffer.state != .acquired);
            if (buffer.state == .busy) held += 1;
        }
        if (held >= max_buffers) return .buffers_busy;
        const buffer = (pool.acquire(extent.width, extent.height, .xrgb8888) catch |err| {
            self.display.failed = true;
            return err;
        }) orelse return .buffers_busy;
        std.debug.assert(pool.count() <= max_buffers and buffer.state == .acquired);
        self.painting = true;
        defer self.painting = false;
        paint(context, Frame{ .extent = extent, .stride = buffer.stride, .pixels = buffer.pixels() }) catch |err| {
            pool.cancel(buffer);
            return err;
        };
        self.presenter.?.present(buffer, .{}) catch |err| {
            // A partial request/commit is not safe to retry. No further
            // dispatch or writes on this connection until it is retired.
            self.display.failed = true;
            return err;
        };
        self.dirty = false;
        return .presented;
    }

    /// Consume the surface even on failure. Never wait for release: all
    /// retired SHM mappings are abandoned, not reused or modified. Remove
    /// callback contexts before freeing the pool and keep sibling surfaces
    /// alive on a healthy connection. A caller may request a sync fence.
    pub fn destroy(self: *Surface) !void {
        std.debug.assert(!self.painting);
        const display = self.display;
        const conn = &display.conn;
        defer {
            display.surfaces -= 1;
            display.occupied[@backingInt(self.role)] = false;
            display.allocator.destroy(self);
        }
        if (self.presenter) |presenter| presenter.destroy();
        if (self.layer) |layer| {
            conn.clearListener(layer) catch {};
            layer.destroy(&conn.session) catch {
                display.failed = true;
            };
        }
        if (self.surface) |surface| surface.destroy(&conn.session) catch {
            display.failed = true;
        };
        if (self.pool) |pool| {
            for (pool.buffers.items) |buffer| conn.clearListener(buffer.wl_buffer) catch {};
            pool.destroy();
        }
        try display.flush();
    }
};
