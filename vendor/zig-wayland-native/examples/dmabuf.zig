// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A window whose frames reach the compositor as dma-bufs, with no GPU API in
//! sight.
//!
//! The allocator here stands in for a GPU driver: it makes each buffer a
//! `memfd`, turns it into a dma-buf with `/dev/udmabuf`, and draws into its
//! own mapping of the memory. That only works for plain rows, which the CPU
//! can write: the LINEAR modifier, or failing that the implicit one
//! (`modifier.invalid`) -- a dma-buf with no driver metadata, which is what
//! udmabuf memory is, reads as linear under it, and older GPUs offer nothing
//! else. The compositor has to import dma-bufs at all, which means a GPU
//! renderer: weston's `--renderer=gl`, or sway on GLES.
//!
//! It needs read and write access to `/dev/udmabuf`. `--frames N` exits after
//! N frames, once the compositor has them.
//!
//! `--explicit-sync` turns on explicit sync with
//! `wp_linux_drm_syncobj_manager_v1`, still without a GPU API: each buffer
//! gets a DRM syncobj timeline, made with the kernel's syncobj ioctls on the
//! compositor's render node and imported as an opaque fd. The CPU signals a
//! frame's acquire point itself once it has drawn, and polls the release
//! point to know when the compositor has let go -- which arrives as no
//! Wayland event at all, so the loop waits on the socket with a timeout
//! rather than blocking in `dispatch`.

const std = @import("std");
const linux = std.os.linux;
const Connection = @import("client").Connection;
const present = @import("present");
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const xdg = protocols.xdg;
const zwp = protocols.zwp;

const State = struct {
    compositor: ?wl.Compositor = null,
    wm_base: ?xdg.WmBase = null,
    linux_dmabuf: ?zwp.LinuxDmabufV1 = null,
    syncobj_manager: ?protocols.wp.LinuxDrmSyncobjManagerV1 = null,

    width: u32 = 640,
    height: u32 = 480,
    configured: bool = false,
    running: bool = true,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var frame_limit: ?usize = null;
    var explicit_sync = false;
    for (args[1..], 1..) |arg, i| {
        if (std.mem.eql(u8, arg, "--frames") and i + 1 < args.len)
            frame_limit = try std.fmt.parseInt(usize, args[i + 1], 10);
        if (std.mem.eql(u8, arg, "--explicit-sync")) explicit_sync = true;
    }

    var udmabuf: Udmabuf = try .open();
    defer udmabuf.close();

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

    const dmabuf: *present.Dmabuf = try .create(gpa, &conn, state.linux_dmabuf orelse return error.NoLinuxDmabuf);
    defer dmabuf.destroy();
    // The default feedback, or the modifier events, in reply to the bind.
    try conn.roundtrip();
    if (dmabuf.mainDevice()) |device| std.log.info("compositor's main device: {d}:{d}", .{ device >> 8 & 0xfff, device & 0xff });
    const offered = try dmabuf.modifiers(gpa, .xrgb8888);
    defer gpa.free(offered);
    for (offered) |m| std.log.info("the compositor offers XR24 with modifier 0x{x:0>16}", .{m});

    var drm: ?DrmSyncobj = null;
    defer if (drm) |*d| d.close();
    if (explicit_sync) {
        const manager = state.syncobj_manager orelse return error.NoSyncobjManager;
        drm = try .open(dmabuf.mainDevice());
        udmabuf.explicit = .{ .drm = &drm.?, .syncobj = .init(&conn, manager) };
    }

    const pool: *present.BufferPool = try .createDmabuf(gpa, &conn, dmabuf, udmabuf.allocator(), .{});
    defer pool.destroy();

    const surface = try compositor.createSurface(s);
    const presenter: *present.Presenter = try .create(gpa, &conn, surface);
    defer presenter.destroy();
    if (udmabuf.explicit) |e| try presenter.enableExplicitSync(e.syncobj);

    const xdg_surface = try wm_base.getXdgSurface(s, surface);
    const toplevel = try xdg_surface.getToplevel(s);
    try conn.setListener(xdg_surface, &state, onXdgSurfaceEvent);
    try conn.setListener(toplevel, &state, onToplevelEvent);
    try toplevel.setTitle(s, "zig-wayland-native dma-buf");
    try surface.commit(s);

    var frames: usize = 0;
    var released_by_point: usize = 0;
    while (state.running) {
        // Under explicit sync nothing on the socket says a buffer is free
        // again: its release point does, and it is asked here.
        if (drm) |*d| {
            var i = pool.buffers.items.len;
            while (i > 0) {
                i -= 1;
                const buffer = pool.buffers.items[i];
                if (buffer.state != .busy or !buffer.explicit_release) continue;
                const memory: *Udmabuf.Memory = @ptrCast(@alignCast(buffer.storage.dmabuf.handle.?));
                if (try d.query(memory.syncobj) >= memory.point) {
                    pool.released(buffer);
                    released_by_point += 1;
                }
            }
        }

        if (state.configured and presenter.ready()) {
            if (try pool.acquire(state.width, state.height, .xrgb8888)) |buffer| {
                const memory: *Udmabuf.Memory = @ptrCast(@alignCast(buffer.storage.dmabuf.handle.?));
                try memory.draw(buffer, frames);
                if (drm) |*d| {
                    // Acquire at 2n+1, which the CPU signals now that the
                    // pixels are written; release at 2n+2, which the
                    // compositor signals when it has finished with them.
                    memory.point += 2;
                    try d.signal(memory.syncobj, memory.point - 1);
                    try presenter.present(buffer, .{ .sync = .{
                        .acquire = .{ .timeline = memory.timeline.?, .value = memory.point - 1 },
                        .release = .{ .timeline = memory.timeline.?, .value = memory.point },
                    } });
                } else try presenter.present(buffer, .{});
                frames += 1;
                if (frame_limit) |limit| if (frames >= limit) {
                    try conn.roundtrip();
                    std.log.info("presented {d} dma-buf frames at {d}x{d} from {d} buffers{s}", .{
                        frames,
                        state.width,
                        state.height,
                        pool.count(),
                        if (drm != null) " with explicit sync" else "",
                    });
                    if (drm != null) std.log.info("{d} buffers came back through their release points", .{released_by_point});
                    return;
                };
            }
        }

        // Wait for the compositor, but not for ever: a release point may
        // signal while the socket stays quiet.
        try conn.flush();
        _ = try conn.dispatchPending();
        var poll_fds: [1]linux.pollfd = .{.{ .fd = conn.fd, .events = linux.POLL.IN, .revents = 0 }};
        const ready = linux.poll(&poll_fds, 1, if (drm != null) 5 else -1);
        if (std.posix.errno(ready) == .SUCCESS and ready > 0) {
            try conn.read();
            _ = try conn.dispatchPending();
        }
    }
}

/// DRM syncobj timelines on a render node, through the kernel's ioctls:
/// what a Vulkan timeline semaphore is underneath, on Mesa.
const DrmSyncobj = struct {
    fd: linux.fd_t,

    const Create = extern struct { handle: u32, flags: u32 };
    const Destroy = extern struct { handle: u32, pad: u32 = 0 };
    const Handle = extern struct { handle: u32, flags: u32, fd: i32, pad: u32 = 0 };
    const TimelineArray = extern struct { handles: u64, points: u64, count_handles: u32, flags: u32 };

    const create_ioctl = ioctlReadWrite(0xBF, @sizeOf(Create));
    const destroy_ioctl = ioctlReadWrite(0xC0, @sizeOf(Destroy));
    const handle_to_fd_ioctl = ioctlReadWrite(0xC1, @sizeOf(Handle));
    const query_ioctl = ioctlReadWrite(0xCB, @sizeOf(TimelineArray));
    const timeline_signal_ioctl = ioctlReadWrite(0xCD, @sizeOf(TimelineArray));

    fn ioctlReadWrite(comptime nr: u8, comptime size: u32) u32 {
        return 3 << 30 | size << 16 | @as(u32, 'd') << 8 | nr;
    }

    /// The render node whose device is `main_device`, or the first render
    /// node that opens when the compositor has not said which it uses. A
    /// syncobj's fd can be imported on any DRM device, so the choice only
    /// has to be one that works.
    fn open(main_device: ?u64) !DrmSyncobj {
        var fallback: ?linux.fd_t = null;
        for (128..192) |minor| {
            var path_buf: [32]u8 = undefined;
            const path = try std.fmt.bufPrintSentinel(&path_buf, "/dev/dri/renderD{d}", .{minor}, 0);
            const rc = linux.open(path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0);
            if (std.posix.errno(rc) != .SUCCESS) continue;
            const fd: linux.fd_t = @intCast(rc);
            var st: linux.Statx = undefined;
            if (main_device) |want| if (std.posix.errno(linux.statx(fd, "", linux.AT.EMPTY_PATH, .{}, &st)) == .SUCCESS and
                makedev(st.rdev_major, st.rdev_minor) == want)
            {
                if (fallback) |f| _ = linux.close(f);
                return .{ .fd = fd };
            };
            if (fallback == null) fallback = fd else _ = linux.close(fd);
        }
        return .{ .fd = fallback orelse return error.NoRenderNode };
    }

    /// A `dev_t` from its parts, as glibc's `makedev` packs them.
    fn makedev(major: u64, minor: u64) u64 {
        return (minor & 0xff) | (major & 0xfff) << 8 | (minor & ~@as(u64, 0xff)) << 12 | (major & ~@as(u64, 0xfff)) << 32;
    }

    fn close(d: *DrmSyncobj) void {
        _ = linux.close(d.fd);
    }

    fn ioctl(d: *const DrmSyncobj, request: u32, arg: anytype) !void {
        while (true) {
            switch (std.posix.errno(linux.ioctl(d.fd, request, @intFromPtr(arg)))) {
                .SUCCESS => return,
                .INTR => continue,
                else => |e| {
                    std.log.err("DRM syncobj ioctl 0x{x} failed: {t}", .{ request, e });
                    return error.SyncobjIoctlFailed;
                },
            }
        }
    }

    /// A new timeline, at point 0.
    fn create(d: *const DrmSyncobj) !u32 {
        var arg: Create = .{ .handle = 0, .flags = 0 };
        try d.ioctl(create_ioctl, &arg);
        return arg.handle;
    }

    fn destroy(d: *const DrmSyncobj, handle: u32) void {
        var arg: Destroy = .{ .handle = handle };
        d.ioctl(destroy_ioctl, &arg) catch {};
    }

    /// The timeline as an opaque fd, which is what
    /// `wp_linux_drm_syncobj_manager_v1.import_timeline` takes.
    fn exportFd(d: *const DrmSyncobj, handle: u32) !linux.fd_t {
        var arg: Handle = .{ .handle = handle, .flags = 0, .fd = -1 };
        try d.ioctl(handle_to_fd_ioctl, &arg);
        return arg.fd;
    }

    fn signal(d: *const DrmSyncobj, handle: u32, point: u64) !void {
        var h = handle;
        var p = point;
        var arg: TimelineArray = .{ .handles = @intFromPtr(&h), .points = @intFromPtr(&p), .count_handles = 1, .flags = 0 };
        try d.ioctl(timeline_signal_ioctl, &arg);
    }

    /// The last point signalled.
    fn query(d: *const DrmSyncobj, handle: u32) !u64 {
        var h = handle;
        var p: u64 = 0;
        var arg: TimelineArray = .{ .handles = @intFromPtr(&h), .points = @intFromPtr(&p), .count_handles = 1, .flags = 0 };
        try d.ioctl(query_ioctl, &arg);
        return p;
    }
};

/// An allocator that makes dma-bufs out of memfds with `/dev/udmabuf`.
const Udmabuf = struct {
    device: linux.fd_t,
    /// Set for explicit sync: each buffer then gets a timeline of its own.
    explicit: ?Explicit = null,

    const Explicit = struct {
        drm: *DrmSyncobj,
        syncobj: present.Syncobj,
    };

    /// `struct udmabuf_create` from `<linux/udmabuf.h>`.
    const Create = extern struct {
        memfd: u32,
        flags: u32,
        offset: u64,
        size: u64,
    };
    const create_ioctl: u32 = ioctlWrite('u', 0x42, @sizeOf(Create));
    const flags_cloexec = 0x01;

    /// `DMA_BUF_IOCTL_SYNC` from `<linux/dma-buf.h>`, which brackets CPU
    /// access so that caches are flushed before the GPU reads.
    const sync_ioctl: u32 = ioctlWrite('b', 0, @sizeOf(u64));
    const sync_write: u64 = 2;
    const sync_start: u64 = 0;
    const sync_end: u64 = 4;

    fn ioctlWrite(comptime kind: u8, comptime nr: u8, comptime size: u32) u32 {
        return 1 << 30 | size << 16 | @as(u32, kind) << 8 | nr;
    }

    /// One buffer's memory: the memfd, the dma-buf made of it, and a mapping.
    const Memory = struct {
        memfd: linux.fd_t,
        dmabuf: linux.fd_t,
        pixels: []align(std.heap.page_size_min) u8,
        /// Under explicit sync: the buffer's DRM syncobj timeline, the
        /// compositor's import of it, and the release point of the last
        /// frame drawn in it.
        syncobj: u32 = 0,
        timeline: ?present.Syncobj.Timeline = null,
        point: u64 = 0,

        fn draw(m: *Memory, buffer: *present.Buffer, frame: usize) !void {
            try m.sync(sync_start | sync_write);
            defer m.sync(sync_end | sync_write) catch {};
            const shift = frame * 4;
            for (0..buffer.height) |y| {
                const row: []align(1) u32 = @ptrCast(m.pixels[y * buffer.stride ..][0 .. buffer.width * 4]);
                for (row, 0..) |*pixel, x| {
                    const r: u32 = if (((x + shift) / 32 + y / 32) % 2 == 0) 0xc0 else 0x60;
                    const g: u32 = @intCast(y * 255 / buffer.height);
                    const b: u32 = @intCast(x * 255 / buffer.width);
                    pixel.* = r << 16 | g << 8 | b;
                }
            }
        }

        fn sync(m: *Memory, flags: u64) !void {
            var f = flags;
            if (std.posix.errno(linux.ioctl(m.dmabuf, sync_ioctl, @intFromPtr(&f))) != .SUCCESS) return error.DmabufSyncFailed;
        }
    };

    fn open() !Udmabuf {
        const rc = linux.open("/dev/udmabuf", .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0);
        if (std.posix.errno(rc) != .SUCCESS) {
            std.log.err("cannot open /dev/udmabuf: {t}", .{std.posix.errno(rc)});
            return error.NoUdmabuf;
        }
        return .{ .device = @intCast(rc) };
    }

    fn close(u: *Udmabuf) void {
        _ = linux.close(u.device);
    }

    fn allocator(u: *Udmabuf) present.Dmabuf.BufferAllocator {
        return .{ .context = u, .allocate = allocate, .free = free };
    }

    fn allocate(context: ?*anyopaque, width: u32, height: u32, format: present.Format, modifiers: []const u64) anyerror!present.Dmabuf.Allocation {
        const u: *Udmabuf = @ptrCast(@alignCast(context.?));
        // The CPU can only write plain rows: LINEAR if it is offered, or the
        // implicit modifier, under which memory with no driver metadata is
        // read as rows.
        const chosen = for ([_]u64{ present.modifier.linear, present.modifier.invalid }) |m| {
            if (std.mem.findScalar(u64, modifiers, m) != null) break m;
        } else return error.LinearNotOffered;
        // GPUs want linear rows aligned: radeonsi refuses to import a LINEAR
        // buffer whose stride is not a multiple of 256, and it is the
        // strictest of the common drivers.
        const stride = std.mem.alignForward(u32, width * (format.bytesPerPixel() orelse return error.UnsupportedFormat), 256);
        const size = std.mem.alignForward(usize, @as(usize, stride) * height, std.heap.pageSize());

        const memfd_rc = linux.memfd_create("udmabuf", linux.MFD.CLOEXEC | linux.MFD.ALLOW_SEALING);
        if (std.posix.errno(memfd_rc) != .SUCCESS) return error.SystemResources;
        const memfd: linux.fd_t = @intCast(memfd_rc);
        errdefer _ = linux.close(memfd);
        if (std.posix.errno(linux.ftruncate(memfd, @intCast(size))) != .SUCCESS) return error.SystemResources;
        // udmabuf insists that the memory cannot shrink out from under it.
        if (std.posix.errno(linux.fcntl(memfd, linux.F.ADD_SEALS, linux.F.SEAL_SHRINK)) != .SUCCESS) return error.SystemResources;

        var request: Create = .{ .memfd = @intCast(memfd), .flags = flags_cloexec, .offset = 0, .size = size };
        const dmabuf_rc = linux.ioctl(u.device, create_ioctl, @intFromPtr(&request));
        if (std.posix.errno(dmabuf_rc) != .SUCCESS) return error.UdmabufCreateFailed;
        const dmabuf: linux.fd_t = @intCast(dmabuf_rc);
        errdefer _ = linux.close(dmabuf);

        const mapped = linux.mmap(null, size, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, memfd, 0);
        if (std.posix.errno(mapped) != .SUCCESS) return error.SystemResources;

        const memory = try std.heap.page_allocator.create(Memory);
        memory.* = .{
            .memfd = memfd,
            .dmabuf = dmabuf,
            .pixels = @as([*]align(std.heap.page_size_min) u8, @ptrFromInt(mapped))[0..size],
        };
        if (u.explicit) |e| {
            memory.syncobj = try e.drm.create();
            const timeline_fd = try e.drm.exportFd(memory.syncobj);
            // Sent and flushed before this returns, so the fd can go.
            defer _ = linux.close(timeline_fd);
            memory.timeline = try e.syncobj.importTimeline(timeline_fd);
        }
        return .{
            .handle = memory,
            .modifier = chosen,
            .planes = .{ .{ .fd = dmabuf, .offset = 0, .stride = stride }, undefined, undefined, undefined },
            .plane_count = 1,
        };
    }

    fn free(context: ?*anyopaque, handle: ?*anyopaque) void {
        const u: *Udmabuf = @ptrCast(@alignCast(context.?));
        const memory: *Memory = @ptrCast(@alignCast(handle.?));
        if (u.explicit) |e| {
            if (memory.timeline) |t| t.destroy(e.syncobj.conn) catch {};
            e.drm.destroy(memory.syncobj);
        }
        _ = linux.munmap(memory.pixels.ptr, memory.pixels.len);
        _ = linux.close(memory.dmabuf);
        _ = linux.close(memory.memfd);
        std.heap.page_allocator.destroy(memory);
    }
};

fn onRegistryEvent(state: *State, conn: *Connection, registry: wl.Registry, event: wl.Registry.Event) !void {
    const global = switch (event) {
        .global => |g| g,
        .global_remove => return,
    };
    const s = &conn.session;
    if (std.mem.eql(u8, global.interface, "wl_compositor")) {
        state.compositor = try registry.bind(s, global.name, wl.Compositor, @min(global.version, 4));
    } else if (std.mem.eql(u8, global.interface, "xdg_wm_base")) {
        state.wm_base = try registry.bind(s, global.name, xdg.WmBase, @min(global.version, 2));
    } else if (std.mem.eql(u8, global.interface, "zwp_linux_dmabuf_v1")) {
        state.linux_dmabuf = try registry.bind(s, global.name, zwp.LinuxDmabufV1, @min(global.version, 4));
    } else if (std.mem.eql(u8, global.interface, "wp_linux_drm_syncobj_manager_v1")) {
        state.syncobj_manager = try registry.bind(s, global.name, protocols.wp.LinuxDrmSyncobjManagerV1, 1);
    }
}

fn onWmBaseEvent(_: void, conn: *Connection, wm_base: xdg.WmBase, event: xdg.WmBase.Event) !void {
    switch (event) {
        .ping => |ping| try wm_base.pong(&conn.session, ping.serial),
    }
}

fn onToplevelEvent(state: *State, _: *Connection, _: xdg.Toplevel, event: xdg.Toplevel.Event) void {
    switch (event) {
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
