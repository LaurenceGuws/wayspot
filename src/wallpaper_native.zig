//! Owns native file, SDL image, Wayland, Hyprland socket, poll, and stop operations for wallpaper.

const std = @import("std");
const wallpaper = @import("wallpaper.zig");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});
const wl = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wlr-layer-shell-unstable-v1-client.h");
    @cInclude("viewporter-client.h");
});

/// Owns one signalfd and the signal mask restored exactly by `closeStop`.
pub const Stop = struct { fd: std.posix.fd_t, prior_mask: std.posix.sigset_t };

/// Owns one Wayland display and its resources; resident stop/socket2/path state is always borrowed.
pub const Native = struct {
    io: std.Io,
    file: ?std.Io.File = null,
    display: ?*wl.wl_display = null,
    registry_proxy: ?*wl.wl_registry = null,
    compositor: ?*wl.wl_compositor = null,
    shm: ?*wl.wl_shm = null,
    viewporter: ?*wl.wp_viewporter = null,
    layer_shell: ?*wl.zwlr_layer_shell_v1 = null,
    output_globals: [wallpaper.monitor_capacity]u32 = undefined,
    output_global_count: u8 = 0,
    outputs: [wallpaper.monitor_capacity]?*wl.wl_output = @splat(null),
    output_count: u8 = 0,
    output_snapshot: ?wallpaper.Snapshot = null,
    compositor_global: u32 = 0,
    shm_global: u32 = 0,
    viewporter_global: u32 = 0,
    layer_shell_global: u32 = 0,
    outputs_changed: bool = false,
    probe: OutputProbe = .{},
    global_count: u8 = 0,
    failed: bool = false,
    surfaces: [wallpaper.surface_resource_capacity]Surface = @splat(.{}),
    next_surface_generation: u32 = 1,
    flush_attempts: u8 = 0,
    flush_deadline: u64 = 0,

    pub fn open(native: *Native, path: []const u8) !void {
        std.debug.assert(native.file == null);
        native.file = if (std.fs.path.isAbsolute(path))
            try std.Io.Dir.openFileAbsolute(native.io, path, .{})
        else
            try std.Io.Dir.cwd().openFile(native.io, path, .{});
    }

    pub fn stat(native: *Native) !struct { kind: std.Io.File.Kind, size: u64 } {
        const value = try (native.file orelse unreachable).stat(native.io);
        return .{ .kind = value.kind, .size = value.size };
    }

    pub fn read(native: *Native, bytes: []u8) !usize {
        return (native.file orelse unreachable).readPositionalAll(native.io, bytes, 0);
    }

    pub fn close(native: *Native) void {
        const file = native.file orelse unreachable;
        file.close(native.io);
        native.file = null;
    }

    /// Returns the borrowed I/O clock in monotonic milliseconds for bounded waits.
    pub fn now(native: *Native) u64 {
        return @intCast(std.Io.Clock.awake.now(native.io).toMilliseconds());
    }

    /// Allocates one stable candidate display owner; allocation failure publishes nothing.
    pub fn createNative(native: *Native, allocator: std.mem.Allocator) !*Native {
        const candidate = try allocator.create(Native);
        candidate.* = .{ .io = native.io };
        return candidate;
    }

    /// Disconnects and frees one candidate or retired display owner exactly once.
    pub fn destroyNative(_: *Native, allocator: std.mem.Allocator, native: *Native) void {
        native.disconnect();
        allocator.destroy(native);
    }

    /// Opens the borrowed socket2 fd slot before the shared deadline; failure leaves it closed.
    pub fn reconnectEvent(
        native: *Native,
        event_fd: *std.posix.fd_t,
        path: []const u8,
        stop_fd: std.posix.fd_t,
        deadline: u64,
    ) !void {
        std.debug.assert(event_fd.* < 0);
        event_fd.* = try native.connectUnix(path, stop_fd, -1, deadline);
    }

    /// Closes the resident-owned socket2 descriptor and restores its absent sentinel.
    pub fn closeEvent(_: *Native, event_fd: *std.posix.fd_t) void {
        std.posix.close(event_fd.*);
        event_fd.* = -1;
    }

    /// Reads at most the caller's bounded socket2 buffer; EOF and errors remain visible.
    pub fn readEvent(_: *Native, event_fd: std.posix.fd_t, bytes: []u8) !usize {
        return std.posix.read(event_fd, bytes);
    }

    /// Opens one per-request Hyprland socket while stop and socket2 loss retain priority.
    pub fn connectRequest(
        native: *Native,
        path: []const u8,
        stop_fd: std.posix.fd_t,
        event_fd: std.posix.fd_t,
        deadline: u64,
    ) !std.posix.fd_t {
        return native.connectUnix(path, stop_fd, event_fd, deadline);
    }

    /// Writes one borrowed request suffix and exposes partial progress or failure.
    pub fn writeRequest(_: *Native, fd: std.posix.fd_t, bytes: []const u8) !usize {
        return std.posix.write(fd, bytes);
    }

    /// Reads into one borrowed bounded reply suffix and exposes EOF or failure.
    pub fn readReply(_: *Native, fd: std.posix.fd_t, bytes: []u8) !usize {
        return std.posix.read(fd, bytes);
    }

    /// Closes one per-call request descriptor exactly once.
    pub fn closeRequest(_: *Native, fd: std.posix.fd_t) void {
        std.posix.close(fd);
    }

    pub fn openOutputs(native: *Native, snapshot: *const wallpaper.Snapshot) !void {
        if (native.display != null) {
            if (native.output_snapshot == null or !native.output_snapshot.?.eql(snapshot)) {
                return error.WaylandOutputChanged;
            }
            return;
        }
        std.debug.assert(native.display == null);
        native.display = wl.wl_display_connect(null) orelse return error.WaylandConnectFailed;
        errdefer native.disconnect();
        native.registry_proxy = wl.wl_display_get_registry(native.display.?) orelse
            return error.WaylandRegistryFailed;
        if (wl.wl_registry_add_listener(native.registry_proxy, &registry_listener, native) != 0) {
            return error.WaylandRegistryFailed;
        }
        try native.roundtrip();
        if (native.compositor == null or native.shm == null or native.viewporter == null or
            native.layer_shell == null or native.output_global_count == 0)
        {
            return error.WaylandGlobalMissing;
        }
        for (native.output_globals[0..native.output_global_count]) |global| {
            native.probe = .{};
            const proxy: *wl.wl_output = @ptrCast(wl.wl_registry_bind(
                native.registry_proxy,
                global,
                &wl.wl_output_interface,
                4,
            ) orelse return error.WaylandOutputMissing);
            var retained = false;
            defer if (!retained) wl.wl_output_release(proxy);
            if (wl.wl_output_add_listener(proxy, &output_listener, &native.probe) != 0) {
                return error.WaylandOutputInvalid;
            }
            try native.roundtrip();
            if (!native.probe.name_seen or !native.probe.done or native.probe.invalid) {
                return error.WaylandOutputIncomplete;
            }
            const probe_name = native.probe.name_bytes[0..native.probe.name_length];
            const index = monitorIndex(snapshot, probe_name) orelse return error.WaylandOutputChanged;
            if (native.outputs[index] != null) return error.WaylandOutputDuplicate;
            native.outputs[index] = proxy;
            native.output_count += 1;
            retained = true;
        }
        if (native.output_count != snapshot.count) return error.WaylandOutputMissing;
        native.output_snapshot = snapshot.*;
        native.outputs_changed = false;
    }

    pub fn disconnect(native: *Native) void {
        if (native.display == null) return;
        for (&native.surfaces) |*surface| std.debug.assert(surface.state == .vacant);
        for (native.outputs) |proxy| if (proxy) |output| wl.wl_output_release(output);
        if (native.layer_shell) |proxy| wl.zwlr_layer_shell_v1_destroy(proxy);
        if (native.viewporter) |proxy| wl.wp_viewporter_destroy(proxy);
        if (native.shm) |proxy| wl.wl_shm_destroy(proxy);
        if (native.compositor) |proxy| wl.wl_compositor_destroy(proxy);
        if (native.registry_proxy) |proxy| wl.wl_registry_destroy(proxy);
        wl.wl_display_disconnect(native.display.?);
        native.display = null;
        native.registry_proxy = null;
        native.compositor = null;
        native.shm = null;
        native.viewporter = null;
        native.layer_shell = null;
        native.compositor_global = 0;
        native.shm_global = 0;
        native.viewporter_global = 0;
        native.layer_shell_global = 0;
        native.output_global_count = 0;
        native.outputs = @splat(null);
        native.output_count = 0;
        native.output_snapshot = null;
        native.outputs_changed = false;
    }

    pub fn prepare(
        native: *Native,
        monitor_index: u8,
        monitor: *const wallpaper.Monitor,
        pixels: *const wallpaper.Image,
    ) !wallpaper.SurfaceHandle {
        const snapshot = native.output_snapshot orelse return error.WaylandOutputMissing;
        if (monitor_index >= snapshot.count or native.outputs[monitor_index] == null) {
            return error.WaylandOutputMissing;
        }
        if (!snapshot.monitors[monitor_index].eql(monitor)) return error.WaylandOutputChanged;
        if (native.next_surface_generation == std.math.maxInt(u32)) return error.SurfaceGenerationExhausted;
        const surface_index = for (&native.surfaces, 0..) |*surface, index| {
            if (surface.state == .vacant) break index;
        } else return error.SurfaceCapacityExceeded;
        const handle = wallpaper.SurfaceHandle{
            .index = @intCast(surface_index),
            .generation = native.next_surface_generation,
        };
        native.next_surface_generation += 1;
        const surface = &native.surfaces[surface_index];
        surface.* = .{ .owner = native, .state = .prepared, .generation = handle.generation };
        errdefer native.discardPrepared(handle);
        surface.surface = wl.wl_compositor_create_surface(native.compositor.?) orelse
            return error.SurfaceCreateFailed;
        surface.region = wl.wl_compositor_create_region(native.compositor.?) orelse
            return error.SurfaceRegionFailed;
        wl.wl_surface_set_input_region(surface.surface orelse return error.SurfaceCreateFailed, surface.region);
        wl.wl_region_destroy(surface.region orelse return error.SurfaceRegionFailed);
        surface.region = null;
        surface.layer = wl.zwlr_layer_shell_v1_get_layer_surface(
            native.layer_shell.?,
            surface.surface.?,
            native.outputs[monitor_index].?,
            wl.ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND,
            "wayspot-beta-wallpaper",
        ) orelse return error.SurfaceLayerFailed;
        if (wl.zwlr_layer_surface_v1_add_listener(surface.layer, &layer_listener, surface) != 0) {
            return error.SurfaceLayerFailed;
        }
        const layer = surface.layer.?;
        wl.zwlr_layer_surface_v1_set_size(layer, 0, 0);
        wl.zwlr_layer_surface_v1_set_anchor(
            layer,
            wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                wl.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT,
        );
        wl.zwlr_layer_surface_v1_set_exclusive_zone(layer, -1);
        wl.zwlr_layer_surface_v1_set_keyboard_interactivity(
            layer,
            wl.ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE,
        );
        surface.viewport = wl.wp_viewporter_get_viewport(native.viewporter.?, surface.surface.?) orelse
            return error.SurfaceViewportFailed;
        wl.wl_surface_commit(surface.surface.?);
        const configure_started = std.Io.Clock.awake.now(native.io);
        var count: u8 = 0;
        while (surface.configure == null and count < wallpaper.wayland_configure_capacity) : (count += 1) {
            if (!try native.dispatch(configure_started)) break;
        }
        if (surface.closed) return error.SurfaceClosed;
        const configured = surface.configure orelse return error.SurfaceConfigureMissing;
        _ = try wallpaper.surfacePixelCount(configured.width, configured.height);
        wl.zwlr_layer_surface_v1_ack_configure(layer, configured.serial);
        surface.configured_width = configured.width;
        surface.configured_height = configured.height;
        wl.wp_viewport_set_destination(
            surface.viewport.?,
            @intCast(configured.width),
            @intCast(configured.height),
        );
        const length = pixels.pixels.len * @sizeOf(u32);
        surface.shm_fd = try std.posix.memfd_create("wayspot-wallpaper", std.os.linux.MFD.CLOEXEC);
        try (std.Io.File{ .handle = surface.shm_fd.? }).setLength(native.io, length);
        surface.mapping = try std.posix.mmap(
            null,
            length,
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = .SHARED },
            surface.shm_fd.?,
            0,
        );
        @memcpy(surface.mapping.?[0..length], std.mem.sliceAsBytes(pixels.pixels));
        surface.pool = wl.wl_shm_create_pool(native.shm.?, surface.shm_fd.?, @intCast(length)) orelse
            return error.SurfacePoolFailed;
        surface.buffer = wl.wl_shm_pool_create_buffer(
            surface.pool.?,
            0,
            @intCast(pixels.width),
            @intCast(pixels.height),
            @intCast(pixels.pitch),
            wl.WL_SHM_FORMAT_XRGB8888,
        ) orelse return error.SurfaceBufferFailed;
        if (wl.wl_buffer_add_listener(surface.buffer, &buffer_listener, surface) != 0) {
            return error.SurfaceBufferFailed;
        }
        return handle;
    }

    pub fn validatePublication(
        native: *Native,
        old: []const wallpaper.SurfaceHandle,
        next: []const wallpaper.SurfaceHandle,
    ) !void {
        if (old.len > wallpaper.monitor_capacity or next.len > wallpaper.monitor_capacity or
            old.len + next.len == 0)
        {
            return error.RoundHandleCountInvalid;
        }
        for (old, 0..) |handle, index| {
            if ((try native.checkedSurface(handle)).state != .published) return error.SurfaceStateInvalid;
            if (contains(old[0..index], handle) or contains(next, handle)) return error.SurfaceHandleDuplicate;
        }
        for (next, 0..) |handle, index| {
            if ((try native.checkedSurface(handle)).state != .prepared) return error.SurfaceStateInvalid;
            if (contains(next[0..index], handle)) return error.SurfaceHandleDuplicate;
        }
    }

    pub fn queueMap(native: *Native, handle: wallpaper.SurfaceHandle) void {
        const surface = native.checkedSurface(handle) catch unreachable;
        std.debug.assert(surface.state == .prepared);
        wl.wl_surface_attach(surface.surface.?, surface.buffer, 0, 0);
        wl.wl_surface_damage_buffer(surface.surface.?, 0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        wl.wl_surface_commit(surface.surface.?);
        surface.state = .queued;
    }

    pub fn queueUnmap(native: *Native, handle: wallpaper.SurfaceHandle) void {
        const surface = native.checkedSurface(handle) catch unreachable;
        std.debug.assert(surface.state == .published);
        wl.wl_surface_attach(surface.surface.?, null, 0, 0);
        wl.wl_surface_commit(surface.surface.?);
        surface.state = .retiring;
    }

    pub fn flushPublication(native: *Native, stop_fd: std.posix.fd_t) !void {
        const started = std.Io.Clock.awake.now(native.io);
        var flush_count: u8 = 0;
        var poll_count: u8 = 0;
        while (flush_count < wallpaper.publication_flush_capacity) {
            flush_count += 1;
            const result = wl.wl_display_flush(native.display.?);
            if (result >= 0) return;
            const flush_error = std.posix.errno(result);
            if (flush_error == .INTR) continue;
            if (flush_error != .AGAIN) return error.WaylandFlushFailed;
            while (poll_count < wallpaper.publication_poll_capacity) {
                poll_count += 1;
                const elapsed = started.durationTo(std.Io.Clock.awake.now(native.io)).toMilliseconds();
                if (elapsed >= wallpaper.wayland_wait_milliseconds) return error.WaylandFlushTimeout;
                var descriptors = [_]std.posix.pollfd{
                    .{
                        .fd = wl.wl_display_get_fd(native.display.?),
                        .events = std.posix.POLL.OUT,
                        .revents = 0,
                    },
                    .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
                };
                const remaining = wallpaper.wayland_wait_milliseconds - elapsed;
                const timeout = std.posix.timespec{
                    .sec = @intCast(remaining / 1000),
                    .nsec = @intCast((remaining % 1000) * std.time.ns_per_ms),
                };
                const ready = std.posix.ppoll(&descriptors, &timeout, null) catch |err| switch (err) {
                    error.SignalInterrupt => continue,
                    else => return err,
                };
                if (ready == 0) return error.WaylandFlushTimeout;
                const failed = std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL;
                if (descriptors[1].revents != 0) return error.WaylandFlushStopped;
                if (descriptors[0].revents & failed != 0) return error.WaylandFlushFailed;
                if (descriptors[0].revents & std.posix.POLL.OUT != 0) break;
            } else return error.WaylandFlushAttemptsExceeded;
        }
        return error.WaylandFlushAttemptsExceeded;
    }

    pub fn finishPublication(
        native: *Native,
        old: []const wallpaper.SurfaceHandle,
        next: []const wallpaper.SurfaceHandle,
    ) void {
        for (next) |handle| {
            const surface = native.checkedSurface(handle) catch unreachable;
            std.debug.assert(surface.state == .queued);
            surface.state = .published;
        }
        for (old) |handle| std.debug.assert((native.checkedSurface(handle) catch unreachable).state == .retiring);
    }

    /// Waits at most one second for release, then destroys one retired surface or fails visibly.
    pub fn releaseRetired(
        native: *Native,
        handle: wallpaper.SurfaceHandle,
        stop_fd: std.posix.fd_t,
    ) !void {
        const surface = try native.checkedSurface(handle);
        if (surface.state != .retiring) return error.SurfaceStateInvalid;
        const release_started = std.Io.Clock.awake.now(native.io);
        var count: u8 = 0;
        while (!surface.released and count < wallpaper.wayland_release_capacity) : (count += 1) {
            const elapsed = release_started.durationTo(std.Io.Clock.awake.now(native.io)).toMilliseconds();
            if (elapsed >= wallpaper.wayland_wait_milliseconds) break;
            const ready = try native.wait(
                stop_fd,
                -1,
                wallpaper.wayland_wait_milliseconds - elapsed,
            );
            if (ready.stop) return error.WaylandFlushStopped;
            if (ready.wayland) _ = try native.drainWayland();
        }
        if (!surface.released) return error.SurfaceReleaseMissing;
        wl.wl_buffer_destroy(surface.buffer.?);
        surface.buffer = null;
        wl.wl_shm_pool_destroy(surface.pool.?);
        surface.pool = null;
        std.posix.munmap(surface.mapping.?);
        surface.mapping = null;
        std.posix.close(surface.shm_fd.?);
        surface.shm_fd = null;
        wl.wp_viewport_destroy(surface.viewport.?);
        surface.viewport = null;
        wl.zwlr_layer_surface_v1_destroy(surface.layer.?);
        surface.layer = null;
        wl.wl_surface_destroy(surface.surface.?);
        surface.surface = null;
        std.debug.assert(surface.localResourcesReleased());
        surface.* = .{};
    }

    pub fn discardPrepared(native: *Native, handle: wallpaper.SurfaceHandle) void {
        const surface = native.checkedSurface(handle) catch unreachable;
        std.debug.assert(surface.state == .prepared);
        if (native.display != null) surface.destroyProxies();
        surface.destroyLocal();
        surface.* = .{};
    }

    pub fn disconnectAfterDisplayLoss(native: *Native) void {
        if (native.display) |display| wl.wl_display_disconnect(display);
        native.display = null;
        native.registry_proxy = null;
        native.compositor = null;
        native.shm = null;
        native.viewporter = null;
        native.layer_shell = null;
        native.compositor_global = 0;
        native.shm_global = 0;
        native.viewporter_global = 0;
        native.layer_shell_global = 0;
        native.outputs = @splat(null);
        native.output_count = 0;
        native.output_snapshot = null;
        native.outputs_changed = false;
        for (&native.surfaces) |*surface| {
            surface.destroyLocal();
            surface.* = .{};
        }
    }

    fn checkedSurface(native: *Native, handle: wallpaper.SurfaceHandle) !*Surface {
        if (handle.index >= wallpaper.surface_resource_capacity) return error.SurfaceHandleInvalid;
        const surface = &native.surfaces[handle.index];
        if (surface.state == .vacant or surface.generation == 0 or surface.generation != handle.generation) {
            return error.SurfaceHandleInvalid;
        }
        return surface;
    }

    fn roundtrip(native: *Native) !void {
        if (wl.wl_display_roundtrip(native.display.?) < 0 or native.failed) {
            return error.WaylandRoundtripFailed;
        }
    }

    /// Reports the sticky output/configure change marker owned by this display.
    pub fn outputsChanged(native: *Native) bool {
        return native.outputs_changed;
    }

    /// Dispatches already-read Wayland events and reports change; protocol failure is fatal.
    pub fn drainWayland(native: *Native) !bool {
        if (wl.wl_display_dispatch_pending(native.display.?) < 0 or native.failed) {
            return error.WaylandDispatchFailed;
        }
        const changed = native.outputs_changed;
        return changed;
    }

    /// Borrows resident fds for one bounded poll; stop wins and timeout zero still polls once.
    pub fn wait(
        native: *Native,
        stop_fd: std.posix.fd_t,
        event_fd: std.posix.fd_t,
        timeout_ms: ?u64,
    ) !wallpaper.Ready {
        var dispatches: u8 = 0;
        while (wl.wl_display_prepare_read(native.display.?) != 0) {
            if (dispatches == 128) return error.WaylandDispatchExceeded;
            dispatches += 1;
            _ = try native.drainWayland();
        }
        var prepared = true;
        errdefer if (prepared) wl.wl_display_cancel_read(native.display.?);
        const flush = wl.wl_display_flush(native.display.?);
        const write = flush < 0 and std.posix.errno(flush) == .AGAIN;
        if (flush < 0 and !write) return error.WaylandFlushFailed;
        if (write) {
            if (native.flush_attempts == 0) {
                native.flush_deadline = try std.math.add(u64, native.now(), wallpaper.wayland_wait_milliseconds);
            }
            if (native.flush_attempts == wallpaper.publication_flush_capacity or
                native.now() >= native.flush_deadline)
            {
                return error.WaylandFlushTimeout;
            }
            native.flush_attempts += 1;
        } else {
            native.flush_attempts = 0;
        }
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{
                .fd = wl.wl_display_get_fd(native.display.?),
                .events = std.posix.POLL.IN | if (write) std.posix.POLL.OUT else 0,
                .revents = 0,
            },
            .{ .fd = event_fd, .events = std.posix.POLL.IN, .revents = 0 },
        };
        const deadline = if (timeout_ms) |milliseconds|
            try std.math.add(u64, native.now(), milliseconds)
        else
            null;
        const count = try native.pollUntil(&fds, deadline, timeout_ms == 0);
        const failed = std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL;
        if (fds[0].revents != 0) {
            wl.wl_display_cancel_read(native.display.?);
            prepared = false;
            var record: [128]u8 = undefined;
            if (fds[0].revents & std.posix.POLL.IN != 0 and try std.posix.read(stop_fd, &record) != record.len) {
                return error.StopRecordIncomplete;
            }
            return .{ .stop = true };
        }
        if (fds[1].revents & failed != 0) {
            prepared = false;
            return error.WaylandDisplayLost;
        }
        var ready: wallpaper.Ready = .{ .deadline = count == 0 };
        if (fds[1].revents & std.posix.POLL.IN != 0) {
            prepared = false;
            if (wl.wl_display_read_events(native.display.?) < 0) return error.WaylandDisplayLost;
            ready.wayland = true;
        } else {
            wl.wl_display_cancel_read(native.display.?);
            prepared = false;
        }
        if (fds[2].revents & failed != 0) return error.EventSocketLost;
        ready.event = fds[2].revents & std.posix.POLL.IN != 0;
        return ready;
    }

    /// Waits for one request socket direction before the shared deadline with stop priority.
    pub fn waitSocket(
        native: *Native,
        fd: std.posix.fd_t,
        stop_fd: std.posix.fd_t,
        event_fd: std.posix.fd_t,
        write: bool,
        deadline: u64,
    ) !void {
        if (native.now() >= deadline) return error.ConnectionTimedOut;
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = fd, .events = if (write) std.posix.POLL.OUT else std.posix.POLL.IN, .revents = 0 },
            .{ .fd = event_fd, .events = std.posix.POLL.IN, .revents = 0 },
        };
        if (try native.pollUntil(&fds, deadline, false) == 0) return error.ConnectionTimedOut;
        if (fds[0].revents != 0) return error.Stopped;
        if (fds[2].revents != 0) return error.EventSocketLost;
        if (fds[1].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL) != 0) {
            return error.ConnectionResetByPeer;
        }
    }

    // Polls through at most 16 interruptions; zero means one nonblocking attempt, not no poll.
    fn pollUntil(native: *Native, fds: []std.posix.pollfd, deadline: ?u64, zero: bool) !usize {
        for (0..16) |_| {
            var timeout: std.posix.timespec = undefined;
            const timeout_ptr = if (zero) blk: {
                timeout = .{ .sec = 0, .nsec = 0 };
                break :blk &timeout;
            } else if (deadline) |end| blk: {
                const now_ms = native.now();
                if (now_ms >= end) return 0;
                const left = end - now_ms;
                timeout = .{
                    .sec = @intCast(left / 1000),
                    .nsec = @intCast(left % 1000 * std.time.ns_per_ms),
                };
                break :blk &timeout;
            } else null;
            return std.posix.ppoll(fds, timeout_ptr, null) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };
        }
        return error.PollInterruptExceeded;
    }

    // Opens one nonblocking Unix socket and either returns its sole fd owner or closes it on failure.
    fn connectUnix(
        native: *Native,
        path: []const u8,
        stop_fd: std.posix.fd_t,
        event_fd: std.posix.fd_t,
        deadline: u64,
    ) !std.posix.fd_t {
        if (path.len == 0 or path.len > 107) return error.SocketPathInvalid;
        const result = std.posix.system.socket(
            std.posix.AF.UNIX,
            std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK,
            0,
        );
        const fd: std.posix.fd_t = if (std.posix.errno(result) == .SUCCESS)
            @intCast(result)
        else
            return error.SocketOpenFailed;
        errdefer std.posix.close(fd);
        var address: std.posix.sockaddr.un = .{ .family = std.posix.AF.UNIX, .path = @splat(0) };
        @memcpy(address.path[0..path.len], path);
        const length: std.posix.socklen_t = @intCast(@offsetOf(std.posix.sockaddr.un, "path") + path.len + 1);
        switch (std.posix.errno(std.posix.system.connect(fd, @ptrCast(&address), length))) {
            .SUCCESS => {},
            .INPROGRESS => {
                try native.waitSocket(fd, stop_fd, event_fd, true, deadline);
                var value: c_int = 0;
                var value_len: std.posix.socklen_t = @sizeOf(c_int);
                if (std.posix.errno(std.posix.system.getsockopt(
                    fd,
                    std.posix.SOL.SOCKET,
                    std.posix.SO.ERROR,
                    @ptrCast(&value),
                    &value_len,
                )) != .SUCCESS or value_len != @sizeOf(c_int)) return error.SocketConnectFailed;
                if (value != 0) switch (@as(std.posix.E, @enumFromInt(value))) {
                    .CONNREFUSED, .NOENT, .AGAIN => return error.ConnectionRefused,
                    .CONNRESET => return error.ConnectionResetByPeer,
                    .TIMEDOUT => return error.ConnectionTimedOut,
                    else => return error.SocketConnectFailed,
                };
            },
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .NOENT, .AGAIN => return error.ConnectionRefused,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .INTR => return error.ConnectionInterrupted,
            else => return error.SocketConnectFailed,
        }
        return fd;
    }

    fn dispatch(native: *Native, started: std.Io.Clock.Timestamp) !bool {
        if (wl.wl_display_dispatch_pending(native.display.?) < 0 or native.failed) {
            return error.WaylandDispatchFailed;
        }
        const elapsed = started.durationTo(std.Io.Clock.awake.now(native.io)).toMilliseconds();
        if (elapsed >= wallpaper.wayland_wait_milliseconds) return false;
        if (wl.wl_display_flush(native.display.?) < 0) return error.WaylandFlushFailed;
        while (wl.wl_display_prepare_read(native.display.?) != 0) {
            if (wl.wl_display_dispatch_pending(native.display.?) < 0) return error.WaylandDispatchFailed;
        }
        var descriptors = [1]std.posix.pollfd{.{
            .fd = wl.wl_display_get_fd(native.display.?),
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};
        const ready = std.posix.poll(
            &descriptors,
            @intCast(wallpaper.wayland_wait_milliseconds - elapsed),
        ) catch |err| {
            wl.wl_display_cancel_read(native.display.?);
            return err;
        };
        if (ready == 0) {
            wl.wl_display_cancel_read(native.display.?);
            return false;
        }
        if (descriptors[0].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP | std.posix.POLL.NVAL) != 0) {
            wl.wl_display_cancel_read(native.display.?);
            return error.WaylandDispatchFailed;
        }
        if (wl.wl_display_read_events(native.display.?) < 0) return error.WaylandDispatchFailed;
        if (wl.wl_display_dispatch_pending(native.display.?) < 0 or native.failed) {
            return error.WaylandDispatchFailed;
        }
        return true;
    }

    pub fn decode(_: *Native, allocator: std.mem.Allocator, bytes: []const u8) !wallpaper.Image {
        const stream = sdl.SDL_IOFromConstMem(bytes.ptr, bytes.len) orelse return error.ImageStreamFailed;
        const decoded = sdl.SDL_LoadPNG_IO(stream, true) orelse return error.ImageDecodeFailed;
        defer sdl.SDL_DestroySurface(decoded);
        const width = try surfaceSide(decoded.*.w);
        const height = try surfaceSide(decoded.*.h);
        if (@as(u64, width) * height > wallpaper.image_pixel_capacity) return error.ImageDimensionsTooLarge;
        const pixels = try allocator.alloc(u32, @as(usize, width) * height);
        errdefer allocator.free(pixels);
        @memset(pixels, 0xff000000);
        const normalized = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            pixels.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(normalized);
        try xrgbSurface(normalized, width, height);
        if (!sdl.SDL_BlitSurface(decoded, null, normalized, null)) return error.ImageConvertFailed;
        return .{
            .width = width,
            .height = height,
            .pitch = width * 4,
            .pixels = pixels,
        };
    }

    pub fn scale(
        _: *Native,
        image: *const wallpaper.Image,
        crop: wallpaper.Crop,
        width: u32,
        height: u32,
        output: []u32,
    ) !void {
        const source = sdl.SDL_CreateSurfaceFrom(
            @intCast(image.width),
            @intCast(image.height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            @constCast(image.pixels.ptr),
            @intCast(image.pitch),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(source);
        const target = sdl.SDL_CreateSurfaceFrom(
            @intCast(width),
            @intCast(height),
            sdl.SDL_PIXELFORMAT_XRGB8888,
            output.ptr,
            @intCast(width * 4),
        ) orelse return error.ImageSurfaceFailed;
        defer sdl.SDL_DestroySurface(target);
        try xrgbSurface(source, image.width, image.height);
        try xrgbSurface(target, width, height);
        const source_rect = rect(crop.x, crop.y, crop.width, crop.height);
        const target_rect = rect(0, 0, width, height);
        if (!sdl.SDL_BlitSurfaceScaled(source, &source_rect, target, &target_rect, sdl.SDL_SCALEMODE_LINEAR)) {
            return error.ImageScaleFailed;
        }
    }
};

/// Builds both bounded Hyprland Unix paths; invalid components publish no partial paths.
pub fn buildSocketPaths(runtime: []const u8, signature: []const u8) !wallpaper.SocketPaths {
    if (runtime.len == 0 or signature.len == 0 or
        std.mem.indexOfScalar(u8, runtime, 0) != null or
        std.mem.indexOfAny(u8, signature, "\x00/") != null or
        !std.unicode.utf8ValidateSlice(runtime) or !std.unicode.utf8ValidateSlice(signature))
    {
        return error.HyprlandEnvironmentInvalid;
    }
    var paths: wallpaper.SocketPaths = .{ .request = .{}, .event = .{} };
    inline for (.{
        .{ &paths.request, ".socket.sock" },
        .{ &paths.event, ".socket2.sock" },
    }) |value| {
        const bytes = std.fmt.bufPrint(&value[0].bytes, "{s}/hypr/{s}/{s}", .{
            runtime, signature, value[1],
        }) catch return error.SocketPathTooLong;
        value[0].len = @intCast(bytes.len);
    }
    return paths;
}

/// Blocks termination signals and returns their signalfd plus the exact prior mask.
pub fn openStop() !Stop {
    var mask = std.posix.sigemptyset();
    std.posix.sigaddset(&mask, .INT);
    std.posix.sigaddset(&mask, .TERM);
    var prior: std.posix.sigset_t = undefined;
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, &prior);
    errdefer std.posix.sigprocmask(std.posix.SIG.SETMASK, &prior, null);
    return .{
        .fd = try std.posix.signalfd(-1, &mask, std.os.linux.SFD.CLOEXEC | std.os.linux.SFD.NONBLOCK),
        .prior_mask = prior,
    };
}

/// Closes the signalfd and restores the prior signal mask.
pub fn closeStop(stop: Stop) void {
    std.posix.close(stop.fd);
    std.posix.sigprocmask(std.posix.SIG.SETMASK, &stop.prior_mask, null);
}

const OutputProbe = struct {
    name_bytes: [wallpaper.monitor_name_capacity]u8 = undefined,
    name_length: u8 = 0,
    name_seen: bool = false,
    done: bool = false,
    invalid: bool = false,
};

const Surface = struct {
    owner: ?*Native = null,
    state: enum { vacant, prepared, queued, published, retiring } = .vacant,
    generation: u32 = 0,
    surface: ?*wl.wl_surface = null,
    region: ?*wl.wl_region = null,
    layer: ?*wl.zwlr_layer_surface_v1 = null,
    viewport: ?*wl.wp_viewport = null,
    shm_fd: ?std.posix.fd_t = null,
    mapping: ?[]align(std.heap.page_size_min) u8 = null,
    pool: ?*wl.wl_shm_pool = null,
    buffer: ?*wl.wl_buffer = null,
    configure: ?wallpaper.Configure = null,
    configure_count: u8 = 0,
    configured_width: u32 = 0,
    configured_height: u32 = 0,
    closed: bool = false,
    released: bool = false,

    fn destroyProxies(surface: *Surface) void {
        if (surface.region) |proxy| wl.wl_region_destroy(proxy);
        if (surface.buffer) |proxy| wl.wl_buffer_destroy(proxy);
        if (surface.pool) |proxy| wl.wl_shm_pool_destroy(proxy);
        if (surface.viewport) |proxy| wl.wp_viewport_destroy(proxy);
        if (surface.layer) |proxy| wl.zwlr_layer_surface_v1_destroy(proxy);
        if (surface.surface) |proxy| wl.wl_surface_destroy(proxy);
    }

    fn destroyLocal(surface: *Surface) void {
        if (surface.mapping) |mapping| std.posix.munmap(mapping);
        if (surface.shm_fd) |fd| std.posix.close(fd);
    }

    fn localResourcesReleased(surface: *const Surface) bool {
        return surface.surface == null and surface.layer == null and surface.viewport == null and
            surface.buffer == null and surface.pool == null and surface.mapping == null and surface.shm_fd == null;
    }
};

const registry_listener = wl.wl_registry_listener{
    .global = registryGlobal,
    .global_remove = registryRemove,
};

fn registryGlobal(
    data: ?*anyopaque,
    registry: ?*wl.wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    const native: *Native = @ptrCast(@alignCast(data));
    if (native.global_count == wallpaper.wayland_global_capacity) {
        native.failed = true;
        return;
    }
    native.global_count += 1;
    const interface_name = std.mem.span(interface);
    if (std.mem.eql(u8, interface_name, "wl_compositor")) {
        if (!bindGlobal(&native.compositor, registry, name, version, 4, &wl.wl_compositor_interface)) {
            native.failed = true;
        } else native.compositor_global = name;
    } else if (std.mem.eql(u8, interface_name, "wl_shm")) {
        if (!bindGlobal(&native.shm, registry, name, version, 1, &wl.wl_shm_interface)) {
            native.failed = true;
        } else native.shm_global = name;
    } else if (std.mem.eql(u8, interface_name, "wp_viewporter")) {
        if (!bindGlobal(&native.viewporter, registry, name, version, 1, &wl.wp_viewporter_interface)) {
            native.failed = true;
        } else native.viewporter_global = name;
    } else if (std.mem.eql(u8, interface_name, "zwlr_layer_shell_v1")) {
        if (!bindGlobal(
            &native.layer_shell,
            registry,
            name,
            version,
            3,
            &wl.zwlr_layer_shell_v1_interface,
        )) native.failed = true else native.layer_shell_global = name;
    } else if (std.mem.eql(u8, interface_name, "wl_output")) {
        if (version < 4 or native.output_global_count == wallpaper.monitor_capacity) {
            native.failed = true;
            return;
        }
        native.output_globals[native.output_global_count] = name;
        native.output_global_count += 1;
        if (native.output_snapshot != null) native.outputs_changed = true;
    }
}

fn bindGlobal(
    current: anytype,
    registry: ?*wl.wl_registry,
    name: u32,
    advertised: u32,
    required: u32,
    interface: *const wl.wl_interface,
) bool {
    if (current.* != null or advertised < required) return false;
    current.* = @ptrCast(wl.wl_registry_bind(registry, name, interface, required));
    return current.* != null;
}

// Marks a retained output/global loss; the resident loop replaces the whole display.
fn registryRemove(data: ?*anyopaque, _: ?*wl.wl_registry, name: u32) callconv(.c) void {
    const native: *Native = @ptrCast(@alignCast(data));
    if (name == native.compositor_global or name == native.shm_global or
        name == native.viewporter_global or name == native.layer_shell_global)
    {
        native.failed = true;
        return;
    }
    for (native.output_globals[0..native.output_global_count]) |global| if (name == global) {
        native.outputs_changed = true;
        return;
    };
}

const output_listener = wl.wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = outputDescription,
};

fn outputGeometry(
    data: ?*anyopaque,
    _: ?*wl.wl_output,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: [*c]const u8,
    _: [*c]const u8,
    _: i32,
) callconv(.c) void {
    _ = data;
}

fn outputMode(
    data: ?*anyopaque,
    _: ?*wl.wl_output,
    _: u32,
    _: i32,
    _: i32,
    _: i32,
) callconv(.c) void {
    _ = data;
}

fn outputDone(data: ?*anyopaque, _: ?*wl.wl_output) callconv(.c) void {
    const probe: *OutputProbe = @ptrCast(@alignCast(data));
    if (!probe.name_seen) {
        probe.invalid = true;
        return;
    }
    probe.done = true;
}

fn outputScale(_: ?*anyopaque, _: ?*wl.wl_output, _: i32) callconv(.c) void {}

fn outputName(data: ?*anyopaque, _: ?*wl.wl_output, name: [*c]const u8) callconv(.c) void {
    const probe: *OutputProbe = @ptrCast(@alignCast(data));
    const bytes = std.mem.span(name);
    if (probe.name_seen or bytes.len == 0 or bytes.len > wallpaper.monitor_name_capacity or
        !std.unicode.utf8ValidateSlice(bytes))
    {
        probe.invalid = true;
        return;
    }
    @memcpy(probe.name_bytes[0..bytes.len], bytes);
    probe.name_length = @intCast(bytes.len);
    probe.name_seen = true;
}

fn outputDescription(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}

const layer_listener = wl.zwlr_layer_surface_v1_listener{
    .configure = layerConfigure,
    .closed = layerClosed,
};

fn layerConfigure(
    data: ?*anyopaque,
    layer: ?*wl.zwlr_layer_surface_v1,
    serial: u32,
    width: u32,
    height: u32,
) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    const owner = surface.owner;
    if (width == 0 or height == 0 or surface.configure_count == wallpaper.wayland_configure_capacity) {
        surface.closed = true;
        if (owner) |native| native.failed = true;
        return;
    }
    surface.configure_count += 1;
    if (surface.state == .published) {
        if (layer) |proxy| wl.zwlr_layer_surface_v1_ack_configure(proxy, serial);
        if (width != surface.configured_width or height != surface.configured_height) {
            if (owner) |native| native.outputs_changed = true;
        }
    }
    surface.configure = .{ .serial = serial, .width = width, .height = height };
}

fn layerClosed(data: ?*anyopaque, _: ?*wl.zwlr_layer_surface_v1) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    surface.closed = true;
    if (surface.owner) |native| native.failed = true;
}

const buffer_listener = wl.wl_buffer_listener{ .release = bufferRelease };

fn bufferRelease(data: ?*anyopaque, _: ?*wl.wl_buffer) callconv(.c) void {
    const surface: *Surface = @ptrCast(@alignCast(data));
    surface.released = true;
}

fn surfaceSide(value: c_int) !u32 {
    if (value <= 0) return error.ImageDimensionsZero;
    if (value > wallpaper.image_side_capacity) return error.ImageDimensionsTooLarge;
    return @intCast(value);
}

fn xrgbSurface(surface: *sdl.SDL_Surface, width: u32, height: u32) !void {
    if (surface.*.format != sdl.SDL_PIXELFORMAT_XRGB8888 or surface.*.w != width or
        surface.*.h != height or surface.*.pitch != width * 4 or surface.*.pixels == null)
    {
        return error.ImageFormatInvalid;
    }
}

fn rect(x: u32, y: u32, width: u32, height: u32) sdl.SDL_Rect {
    return .{ .x = @intCast(x), .y = @intCast(y), .w = @intCast(width), .h = @intCast(height) };
}

fn monitorIndex(snapshot: *const wallpaper.Snapshot, name: []const u8) ?u8 {
    for (snapshot.slice(), 0..) |monitor, index| {
        if (std.mem.eql(u8, monitor.name(), name)) return @intCast(index);
    }
    return null;
}

fn contains(handles: []const wallpaper.SurfaceHandle, needle: wallpaper.SurfaceHandle) bool {
    for (handles) |handle| if (handle == needle) return true;
    return false;
}

fn surfaceParity(
    native: *Native,
    allocator: std.mem.Allocator,
    snapshot: *const wallpaper.Snapshot,
    image: *const wallpaper.Image,
    stop_fd: std.posix.fd_t,
) !void {
    var next = try wallpaper.prepareRound(native, allocator, snapshot, image);
    var current: wallpaper.Round = .{};
    try wallpaper.publishRound(native, &current, &next, stop_fd);
    try wallpaper.releaseRound(native, &current, stop_fd);
}

// Compiles every resident Native operation through the same concrete theorem as Transcript.
fn reconcileParity(
    native: *Native,
    allocator: std.mem.Allocator,
    image: *const wallpaper.Image,
    current: *wallpaper.Current(Native),
    stop_fd: std.posix.fd_t,
    event_fd: *std.posix.fd_t,
    paths: *const wallpaper.SocketPaths,
) !void {
    var lines: wallpaper.EventLines = .{};
    var work: wallpaper.Work = .refresh;
    try wallpaper.reconcile(
        native,
        allocator,
        image,
        current,
        stop_fd,
        event_fd,
        paths,
        &lines,
        &work,
    );
}

test "native adapter reaches every one-surface operation without a display" {
    _ = surfaceParity;
    _ = reconcileParity;
    _ = buildSocketPaths;
    _ = openStop;
    _ = closeStop;
}

test "Hyprland socket paths are exact and bounded" {
    const paths = try buildSocketPaths("/run/user/1000", "instance");
    try std.testing.expectEqualStrings(
        "/run/user/1000/hypr/instance/.socket.sock",
        paths.request.slice(),
    );
    try std.testing.expectEqualStrings(
        "/run/user/1000/hypr/instance/.socket2.sock",
        paths.event.slice(),
    );
    try std.testing.expectError(error.HyprlandEnvironmentInvalid, buildSocketPaths("", "x"));
    try std.testing.expectError(error.HyprlandEnvironmentInvalid, buildSocketPaths("/run", "a/b"));
    var runtime: [100]u8 = @splat('a');
    try std.testing.expectError(error.SocketPathTooLong, buildSocketPaths(&runtime, "instance"));
}

test "output probe owns only one exact name and done identity" {
    var probe: OutputProbe = .{};
    outputName(&probe, null, "DP-1");
    outputDone(&probe, null);
    try std.testing.expect(probe.name_seen);
    try std.testing.expect(probe.done);
    try std.testing.expectEqualStrings("DP-1", probe.name_bytes[0..probe.name_length]);
    outputName(&probe, null, "DP-1");
    try std.testing.expect(probe.invalid);
    probe = .{};
    outputDone(&probe, null);
    try std.testing.expect(probe.invalid);
}

test "surface handles reject absent stale and wrong generations" {
    var native = Native{ .io = std.testing.io };
    native.surfaces[3] = .{ .state = .prepared, .generation = 7 };
    _ = try native.checkedSurface(.{ .index = 3, .generation = 7 });
    try std.testing.expectError(
        error.SurfaceHandleInvalid,
        native.checkedSurface(.{ .index = 3, .generation = 8 }),
    );
    try std.testing.expectError(
        error.SurfaceHandleInvalid,
        native.checkedSurface(.{ .index = 4, .generation = 7 }),
    );
    native.surfaces[3] = .{};
    try std.testing.expectError(
        error.SurfaceHandleInvalid,
        native.checkedSurface(.{ .index = 3, .generation = 7 }),
    );
}

test "configure histories are bounded" {
    var native: Native = .{ .io = std.testing.io };
    var surface: Surface = .{
        .owner = &native,
        .state = .published,
        .configured_width = 2,
        .configured_height = 2,
    };
    layerConfigure(&surface, null, 1, 2, 2);
    try std.testing.expect(!native.outputs_changed);
    layerConfigure(&surface, null, 2, 3, 2);
    try std.testing.expect(native.outputs_changed);
    surface = .{ .owner = &native };
    native.failed = false;
    for (0..wallpaper.wayland_configure_capacity) |serial| {
        layerConfigure(&surface, null, @intCast(serial), 1, 1);
    }
    layerConfigure(&surface, null, 99, 1, 1);
    try std.testing.expect(surface.closed);
    try std.testing.expect(native.failed);
    surface = .{ .owner = &native };
    native.failed = false;
    layerConfigure(&surface, null, 1, 0, 1);
    try std.testing.expect(surface.closed);
    try std.testing.expect(native.failed);
}

test "zero-time poll observes an already-ready descriptor" {
    var sockets: [2]std.posix.fd_t = undefined;
    const result = std.posix.system.socketpair(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC,
        0,
        &sockets,
    );
    try std.testing.expectEqual(std.posix.E.SUCCESS, std.posix.errno(result));
    const writer = std.Io.File{ .handle = sockets[0], .flags = .{ .nonblocking = false } };
    const reader = std.Io.File{ .handle = sockets[1], .flags = .{ .nonblocking = false } };
    defer writer.close(std.testing.io);
    defer reader.close(std.testing.io);
    try writer.writeStreamingAll(std.testing.io, "x");
    var fds = [_]std.posix.pollfd{
        .{ .fd = sockets[1], .events = std.posix.POLL.IN, .revents = 0 },
    };
    var native: Native = .{ .io = std.testing.io };
    try std.testing.expectEqual(@as(usize, 1), try native.pollUntil(&fds, native.now(), true));
    try std.testing.expect(fds[0].revents & std.posix.POLL.IN != 0);
}

test "native PNG file decode and linear cover scaling" {
    const png =
        "\x89PNG\r\n\x1a\n" ++
        "\x00\x00\x00\x0dIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89" ++
        "\x00\x00\x00\x0dIDAT\x78\x9c\x63\xf8\xcf\xc0\xd0\x00\x00\x04\x81\x01\x80\x2c\x55\xce\xb0" ++
        "\x00\x00\x00\x00IEND\xae\x42\x60\x82";
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "one.png", .data = png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "one.png", std.testing.allocator);
    defer std.testing.allocator.free(path);

    var native = Native{ .io = std.testing.io };
    var image = try wallpaper.loadImage(&native, std.testing.allocator, path);
    defer image.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 1), image.width);
    try std.testing.expectEqual(@as(u32, 1), image.height);
    try std.testing.expectEqual(@as(u32, 0xff800000), image.pixels[0]);
    var pixels = try wallpaper.coverImage(&native, std.testing.allocator, &image, 3, 2);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 12), pixels.pitch);
    for (pixels.pixels) |pixel| try std.testing.expectEqual(@as(u32, 0xff800000), pixel);
    try std.testing.expect(native.file == null);
}

test "native malformed PNG closes its file and publishes no image" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var png: [24]u8 = @splat(0);
    @memcpy(png[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(png[12..16], "IHDR");
    std.mem.writeInt(u32, png[16..20], 1, .big);
    std.mem.writeInt(u32, png[20..24], 1, .big);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "broken.png", .data = &png });
    const path = try temporary.dir.realPathFileAlloc(std.testing.io, "broken.png", std.testing.allocator);
    defer std.testing.allocator.free(path);
    var native = Native{ .io = std.testing.io };
    try std.testing.expectError(
        error.ImageDecodeFailed,
        wallpaper.loadImage(&native, std.testing.allocator, path),
    );
    try std.testing.expect(native.file == null);
}

test "native unsupported IO acquires no file" {
    var native = Native{ .io = std.Io.failing };
    if (native.open("wallpaper.png")) |_| {
        return error.ExpectedOpenFailure;
    } else |_| {}
    try std.testing.expect(native.file == null);
}

test "bounded malformed PNG data publishes no partial image" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzPng, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzPng({}, &empty);
}

fn fuzzPng(_: void, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var native = Native{ .io = std.Io.failing };
    if (native.decode(std.testing.allocator, input)) |value| {
        var image = value;
        defer image.deinit(std.testing.allocator);
        try std.testing.expect(image.width > 0 and image.width <= wallpaper.image_side_capacity);
        try std.testing.expect(image.height > 0 and image.height <= wallpaper.image_side_capacity);
        try std.testing.expectEqual(@as(usize, image.width) * image.height, image.pixels.len);
    } else |_| {}
}
