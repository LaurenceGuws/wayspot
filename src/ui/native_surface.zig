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
const wp = @import("wayland-protocols").wp;
const Allocator = std.mem.Allocator;

pub const Role = enum { picker, notification };
pub const max_buffers: usize = 3;
pub const max_surfaces: usize = 2;
pub const max_buffer_bytes: usize = 16 * 1024 * 1024;
const max_outputs = 32;
pub const scale_unit: u32 = 120;
const max_scale: u32 = 8 * scale_unit;

fn validateScale(scale: u32) !void {
    if (scale == 0 or scale > max_scale) return error.InvalidSurfaceScale;
}

fn integerScale(factor: i32) !u32 {
    if (factor <= 0 or factor > max_scale / scale_unit) return error.InvalidSurfaceScale;
    return @as(u32, @intCast(factor)) * scale_unit;
}

/// Positive Wayland fractional-scale rounding, halfway away from zero.
/// Use integer arithmetic; the protocol's 120ths are the authority.
pub fn scaledPixels(logical: u32, scale: u32) !u32 {
    try validateScale(scale);
    const value = (@as(u64, logical) * scale + scale_unit / 2) / scale_unit;
    return std.math.cast(u32, value) orelse error.InvalidSurfaceExtent;
}

pub const Extent = struct {
    width: u32,
    height: u32,

    pub fn validate(size: Extent) !void {
        if (size.width == 0 or size.height == 0 or size.width > 4096 or size.height > 4096) return error.InvalidSurfaceExtent;
        if (@as(u64, size.width) * size.height * 4 > max_buffer_bytes) return error.InvalidSurfaceExtent;
    }
    pub fn scaled(size: Extent, scale: u32) !Extent {
        try size.validate();
        const pixels: Extent = .{
            .width = try scaledPixels(size.width, scale),
            .height = try scaledPixels(size.height, scale),
        };
        try pixels.validate();
        return pixels;
    }
};

const Output = struct {
    global: u32,
    object: wl.Output,
    scale: u32 = scale_unit,
    pending_scale: u32 = scale_unit,
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
    viewporter: ?wp.Viewporter = null,
    fractional_manager: ?wp.FractionalScaleManagerV1 = null,
    globals: [5]?u32 = @splat(null),
    outputs: [max_outputs]?Output = @splat(null),
    discovery_done: bool = false,
    sync_pending: bool = false,
    failed: bool = false,
    surfaces: u8 = 0,
    occupied: [max_surfaces]?*Surface = @splat(null),

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
                // A removed bound manager invalidates this display owner;
                // ordinary output hotplug does not.
                for (self.globals) |name| if (name == r.name) return error.NativeGlobalRemoved;
                for (&self.outputs, 0..) |*slot, i| {
                    const output = slot.* orelse continue;
                    if (output.global != r.name) continue;
                    try conn.clearListener(output.object);
                    try output.object.release(&conn.session);
                    slot.* = null;
                    for (self.occupied) |item| if (item) |surface| {
                        surface.entered_outputs.unset(i);
                        try surface.refreshScale();
                    };
                    break;
                }
                return;
            },
        };
        const session = &conn.session;
        if (std.mem.eql(u8, global.interface, "wl_compositor") and self.compositor == null) {
            if (global.version < 4) return error.NativeCompositorVersion;
            self.compositor = try registry.bind(session, global.name, wl.Compositor, @min(global.version, 6));
            self.globals[0] = global.name;
        } else if (std.mem.eql(u8, global.interface, "wl_shm") and self.shm == null) {
            const object = try registry.bind(session, global.name, wl.Shm, 1);
            self.shm = try .create(self.allocator, conn, object);
            self.globals[1] = global.name;
        } else if (std.mem.eql(u8, global.interface, "zwlr_layer_shell_v1") and self.manager == null) {
            self.manager = try registry.bind(session, global.name, zwlr.LayerShellV1, 1);
            self.globals[2] = global.name;
        } else if (std.mem.eql(u8, global.interface, "wp_viewporter") and self.viewporter == null) {
            self.viewporter = try registry.bind(session, global.name, wp.Viewporter, 1);
            self.globals[3] = global.name;
        } else if (std.mem.eql(u8, global.interface, "wp_fractional_scale_manager_v1") and self.fractional_manager == null) {
            self.fractional_manager = try registry.bind(session, global.name, wp.FractionalScaleManagerV1, 1);
            self.globals[4] = global.name;
        } else if (std.mem.eql(u8, global.interface, "wl_output") and global.version >= 3) {
            // Version 3 provides release on hot-unplug. Older outputs are
            // not needed by the supported compositors; absent hints mean 1x.
            for (&self.outputs) |*slot| {
                if (slot.* != null) continue;
                const object = try registry.bind(session, global.name, wl.Output, @min(global.version, 4));
                slot.* = .{ .global = global.name, .object = object };
                try conn.setListener(object, self, onOutput);
                return;
            }
            return error.NativeOutputLimit;
        }
    }

    fn outputIndex(self: *const Display, object: wl.Output) ?usize {
        for (self.outputs, 0..) |slot, i| {
            if (slot) |output| if (output.object.id == object.id) return i;
        }
        return null;
    }

    fn onOutput(self: *Display, _: *Connection, object: wl.Output, event: wl.Output.Event) !void {
        const i = self.outputIndex(object) orelse return;
        const output = &self.outputs[i].?;
        switch (event) {
            .scale => |hint| output.pending_scale = try integerScale(hint.factor),
            .done => {
                if (output.scale == output.pending_scale) return;
                output.scale = output.pending_scale;
                for (self.occupied) |item| if (item) |surface| {
                    try surface.refreshScale();
                };
            },
            else => {},
        }
    }
};

/// The only writable borrow of a SHM buffer. The callback may not dispatch
/// Wayland, retain pixels or return an SDL renderer that still references them.
pub const Frame = struct {
    /// Logical geometry stays fixed as pixel density changes.
    logical_extent: Extent,
    scale_120: u32,
    /// Physical buffer extent and stride, not logical coordinates.
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
    scale_120: u32 = scale_unit,
    fractional_preferred: ?u32 = null,
    integer_preferred: ?u32 = null,
    entered_outputs: std.StaticBitSet(max_outputs) = .empty,
    viewport: ?wp.Viewport = null,
    fractional: ?wp.FractionalScaleV1 = null,
    surface: ?wl.Surface = null,
    layer: ?zwlr.LayerSurfaceV1 = null,
    pool: ?*present.BufferPool = null,
    presenter: ?*present.Presenter = null,
    dirty: bool = true,
    closed: bool = false,
    painting: bool = false,

    /// Queue an empty initial commit; no buffer exists until configure.
    /// Null output leaves placement to the compositor; a supplied output
    /// must be a currently bound object on this connection. The heap address
    /// stays stable for protocol callback lifetime.
    pub fn create(display: *Display, role: Role, requested: Extent, output: ?wl.Output) !*Surface {
        try requested.validate();
        if (display.status() != .ready) return error.NativeDisplayNotReady;
        if (output) |target| if (display.outputIndex(target) == null) return error.NativeOutputUnknown;
        if (display.surfaces >= max_surfaces) return error.NativeSurfaceLimit;
        if (display.occupied[@backingInt(role)] != null) return error.NativeRoleAlreadyOwned;
        const self = try display.allocator.create(Surface);
        self.* = .{ .display = display, .role = role, .requested = requested };
        display.surfaces += 1;
        display.occupied[@backingInt(role)] = self;
        errdefer {
            display.failed = true;
            self.destroy() catch {};
        }
        const conn = &display.conn;
        const session = &conn.session;
        const surface = try display.compositor.?.createSurface(session);
        self.surface = surface;
        try conn.setListener(surface, self, onSurface);
        // Fractional scaling is a pair: never request fractional hints when
        // the compositor cannot accept a logical-size viewport destination.
        if (display.viewporter != null and display.fractional_manager != null) {
            self.viewport = try display.viewporter.?.getViewport(session, surface);
            self.fractional = try display.fractional_manager.?.getFractionalScale(session, surface);
            try conn.setListener(self.fractional.?, self, onFractional);
        }
        self.pool = try .create(display.allocator, conn, display.shm.?, .{ .max_buffers = max_buffers });
        self.presenter = try .create(display.allocator, conn, surface);
        const layer = try display.manager.?.getLayerSurface(session, surface, output, if (role == .picker) .overlay else .top, if (role == .picker) "wayspot-picker" else "wayspot-notification");
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
                _ = try extent.scaled(self.scale_120);
                try layer.ackConfigure(&conn.session, config.serial);
                if (self.extent == null or !std.meta.eql(self.extent.?, extent)) {
                    self.extent = extent;
                    self.dirty = true;
                }
            },
            .closed => self.closed = true,
        }
    }

    fn refreshScale(self: *Surface) !void {
        var fallback: u32 = scale_unit;
        for (self.display.outputs, 0..) |slot, i| {
            if (slot) |output| if (self.entered_outputs.isSet(i)) {
                fallback = @max(fallback, output.scale);
            };
        }
        const wanted = self.fractional_preferred orelse self.integer_preferred orelse fallback;
        if (wanted == self.scale_120 or self.closed) return;
        if (self.extent) |extent| _ = try extent.scaled(wanted);
        self.scale_120 = wanted;
        self.dirty = true;
    }

    fn onSurface(self: *Surface, _: *Connection, _: wl.Surface, event: wl.Surface.Event) !void {
        switch (event) {
            .enter => |value| if (self.display.outputIndex(value.output)) |i| {
                self.entered_outputs.set(i);
            },
            .leave => |value| if (self.display.outputIndex(value.output)) |i| {
                self.entered_outputs.unset(i);
            },
            .preferred_buffer_scale => |hint| self.integer_preferred = try integerScale(hint.factor),
            .preferred_buffer_transform => return, // Rasterize in normal orientation.
        }
        try self.refreshScale();
    }

    fn onFractional(self: *Surface, _: *Connection, _: wp.FractionalScaleV1, event: wp.FractionalScaleV1.Event) !void {
        switch (event) {
            .preferred_scale => |hint| {
                try validateScale(hint.scale);
                self.fractional_preferred = hint.scale;
                try self.refreshScale();
            },
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
        const pixels = try extent.scaled(self.scale_120);
        const buffer = (pool.acquire(pixels.width, pixels.height, .xrgb8888) catch |err| {
            self.display.failed = true;
            return err;
        }) orelse return .buffers_busy;
        std.debug.assert(pool.count() <= max_buffers and buffer.state == .acquired);
        self.painting = true;
        defer self.painting = false;
        paint(context, Frame{ .logical_extent = extent, .scale_120 = self.scale_120, .extent = pixels, .stride = buffer.stride, .pixels = buffer.pixels() }) catch |err| {
            pool.cancel(buffer);
            return err;
        };
        const buffer_scale: i32 = if (self.viewport) |viewport| blk: {
            viewport.setDestination(&self.display.conn.session, @intCast(extent.width), @intCast(extent.height)) catch |err| {
                self.display.failed = true;
                return err;
            };
            break :blk 1;
        } else blk: {
            std.debug.assert(self.scale_120 % scale_unit == 0);
            break :blk @intCast(self.scale_120 / scale_unit);
        };
        self.presenter.?.present(buffer, .{ .scale = buffer_scale }) catch |err| {
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
            display.occupied[@backingInt(self.role)] = null;
            display.allocator.destroy(self);
        }
        if (self.presenter) |presenter| presenter.destroy();
        if (self.layer) |layer| {
            conn.clearListener(layer) catch {};
            layer.destroy(&conn.session) catch {
                display.failed = true;
            };
        }
        if (self.fractional) |fractional| {
            conn.clearListener(fractional) catch {};
            fractional.destroy(&conn.session) catch {
                display.failed = true;
            };
        }
        if (self.viewport) |viewport| viewport.destroy(&conn.session) catch {
            display.failed = true;
        };
        if (self.surface) |surface| {
            conn.clearListener(surface) catch {};
            surface.destroy(&conn.session) catch {
                display.failed = true;
            };
        }
        if (self.pool) |pool| {
            for (pool.buffers.items) |buffer| conn.clearListener(buffer.wl_buffer) catch {};
            pool.destroy();
        }
        try display.flush();
    }
};
