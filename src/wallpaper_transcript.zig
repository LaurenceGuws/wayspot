//! Strict operation history for the wallpaper Wayland boundary.

const std = @import("std");
const wallpaper = @import("wallpaper.zig");

const operation_capacity = 64;

const Operation = enum {
    connect,
    registry,
    roundtrip_globals,
    bind_output_v4,
    roundtrip_output,
    require_output,
    disconnect,
    reserve,
    create_surface,
    create_empty_region,
    set_input_region,
    destroy_region,
    create_layer,
    set_layer_state,
    create_viewport,
    initial_commit,
    receive_configure,
    ack_configure,
    set_viewport,
    create_shm,
    map_pixels,
    create_pool,
    create_buffer,
    attach_damage_commit,
    flush,
    unmap,
    receive_release,
    destroy_buffer,
    destroy_pool,
    unmap_pixels,
    close_shm,
    destroy_viewport,
    destroy_layer,
    destroy_surface,
    free,
    disconnect_loss,
    discard,
};

const Transcript = struct {
    operations: [operation_capacity]Operation = undefined,
    count: u8 = 0,
    fail_at: ?u8 = null,
    connected: bool = false,
    occupied: bool = false,
    generation: u32 = 0,
    surface: bool = false,
    region: bool = false,
    layer: bool = false,
    viewport: bool = false,
    configured: bool = false,
    buffer: bool = false,
    pool: bool = false,
    mapping: bool = false,
    shm: bool = false,
    released: bool = false,
    committed: bool = false,

    pub fn openOutput(transcript: *Transcript, name: []const u8) !void {
        try transcript.connect();
        errdefer transcript.disconnect();
        try transcript.registry();
        try transcript.roundtripGlobals();
        try transcript.bindOutputV4(name);
        try transcript.roundtripOutput();
        try transcript.requireOutput(name);
    }

    pub fn prepare(
        transcript: *Transcript,
        monitor: *const wallpaper.Monitor,
        pixels: *const wallpaper.Image,
    ) !wallpaper.SurfaceHandle {
        const handle = try transcript.reserve(monitor.name());
        errdefer transcript.discard(handle);
        try transcript.createSurface(handle);
        try transcript.createEmptyRegion(handle);
        try transcript.setInputRegion(handle);
        try transcript.destroyRegion(handle);
        try transcript.createLayer(handle);
        try transcript.setLayerState(handle);
        try transcript.createViewport(handle);
        try transcript.initialCommit(handle);
        const configured = try transcript.receiveConfigure(handle, wallpaper.wayland_configure_capacity);
        _ = try wallpaper.surfacePixelCount(configured.width, configured.height);
        try transcript.ackConfigure(handle, configured.serial);
        try transcript.setViewport(handle, configured.width, configured.height);
        try transcript.createBuffer(handle, pixels);
        try transcript.attachDamageCommit(handle);
        try transcript.flush();
        return handle;
    }

    pub fn release(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        errdefer transcript.discard(handle);
        try transcript.unmap(handle);
        try transcript.flush();
        try transcript.receiveRelease(handle);
        transcript.destroyBuffer(handle);
        transcript.destroyPool(handle);
        transcript.unmapPixels(handle);
        transcript.closeShm(handle);
        transcript.destroyViewport(handle);
        transcript.destroyLayer(handle);
        transcript.destroySurface(handle);
        transcript.free(handle);
    }

    pub fn connect(transcript: *Transcript) !void {
        try transcript.step(.connect);
        transcript.connected = true;
    }

    pub fn registry(transcript: *Transcript) !void {
        std.debug.assert(transcript.connected);
        try transcript.step(.registry);
    }

    pub fn roundtripGlobals(transcript: *Transcript) !void {
        try transcript.step(.roundtrip_globals);
    }

    pub fn bindOutputV4(transcript: *Transcript, name: []const u8) !void {
        try std.testing.expectEqualStrings("DP-1", name);
        try transcript.step(.bind_output_v4);
    }

    pub fn roundtripOutput(transcript: *Transcript) !void {
        try transcript.step(.roundtrip_output);
    }

    pub fn requireOutput(transcript: *Transcript, name: []const u8) !void {
        try std.testing.expectEqualStrings("DP-1", name);
        try transcript.step(.require_output);
    }

    pub fn disconnect(transcript: *Transcript) void {
        std.debug.assert(transcript.connected);
        transcript.record(.disconnect);
        transcript.connected = false;
    }

    pub fn reserve(transcript: *Transcript, name: []const u8) !wallpaper.SurfaceHandle {
        try std.testing.expectEqualStrings("DP-1", name);
        try transcript.step(.reserve);
        std.debug.assert(!transcript.occupied);
        transcript.occupied = true;
        transcript.generation = 1;
        return .{ .generation = 1 };
    }

    pub fn createSurface(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.create_surface);
        transcript.surface = true;
    }

    pub fn createEmptyRegion(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.create_empty_region);
        transcript.region = true;
    }

    pub fn setInputRegion(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        std.debug.assert(transcript.region);
        try transcript.step(.set_input_region);
    }

    pub fn destroyRegion(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        std.debug.assert(transcript.region);
        try transcript.step(.destroy_region);
        transcript.region = false;
    }

    pub fn createLayer(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.create_layer);
        transcript.layer = true;
    }

    pub fn setLayerState(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.set_layer_state);
    }

    pub fn createViewport(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.create_viewport);
        transcript.viewport = true;
    }

    pub fn initialCommit(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        std.debug.assert(!transcript.buffer);
        try transcript.step(.initial_commit);
    }

    pub fn receiveConfigure(
        transcript: *Transcript,
        handle: wallpaper.SurfaceHandle,
        capacity: u8,
    ) !wallpaper.Configure {
        try transcript.checkHandle(handle);
        try std.testing.expectEqual(@as(u8, 16), capacity);
        try transcript.step(.receive_configure);
        transcript.configured = true;
        return .{ .serial = 42, .width = 1280, .height = 720 };
    }

    pub fn ackConfigure(transcript: *Transcript, handle: wallpaper.SurfaceHandle, serial: u32) !void {
        try transcript.checkHandle(handle);
        try std.testing.expectEqual(@as(u32, 42), serial);
        try transcript.step(.ack_configure);
    }

    pub fn setViewport(transcript: *Transcript, handle: wallpaper.SurfaceHandle, width: u32, height: u32) !void {
        try transcript.checkHandle(handle);
        try std.testing.expectEqual(@as(u32, 1280), width);
        try std.testing.expectEqual(@as(u32, 720), height);
        try transcript.step(.set_viewport);
    }

    pub fn createBuffer(
        transcript: *Transcript,
        handle: wallpaper.SurfaceHandle,
        pixels: *const wallpaper.Image,
    ) !void {
        try transcript.checkHandle(handle);
        try std.testing.expectEqual(@as(u32, 1920), pixels.width);
        try transcript.step(.create_shm);
        transcript.shm = true;
        try transcript.step(.map_pixels);
        transcript.mapping = true;
        try transcript.step(.create_pool);
        transcript.pool = true;
        try transcript.step(.create_buffer);
        transcript.buffer = true;
    }

    pub fn attachDamageCommit(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        std.debug.assert(transcript.configured);
        std.debug.assert(transcript.buffer);
        try transcript.step(.attach_damage_commit);
        transcript.committed = true;
    }

    pub fn flush(transcript: *Transcript) !void {
        try transcript.step(.flush);
    }

    pub fn unmap(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.unmap);
    }

    pub fn receiveRelease(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        try transcript.checkHandle(handle);
        try transcript.step(.receive_release);
        transcript.released = true;
    }

    pub fn destroyBuffer(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        transcript.checkHandle(handle) catch unreachable;
        std.debug.assert(transcript.released);
        transcript.record(.destroy_buffer);
        transcript.buffer = false;
    }

    pub fn destroyPool(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.pool);
        transcript.record(.destroy_pool);
        transcript.pool = false;
    }

    pub fn unmapPixels(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.mapping);
        transcript.record(.unmap_pixels);
        transcript.mapping = false;
    }

    pub fn closeShm(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.shm);
        transcript.record(.close_shm);
        transcript.shm = false;
    }

    pub fn destroyViewport(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.viewport);
        transcript.record(.destroy_viewport);
        transcript.viewport = false;
    }

    pub fn destroyLayer(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.layer);
        transcript.record(.destroy_layer);
        transcript.layer = false;
    }

    pub fn destroySurface(transcript: *Transcript, _: wallpaper.SurfaceHandle) void {
        std.debug.assert(transcript.surface);
        transcript.record(.destroy_surface);
        transcript.surface = false;
    }

    pub fn free(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        transcript.checkHandle(handle) catch unreachable;
        std.debug.assert(!transcript.surface and !transcript.layer and !transcript.viewport and
            !transcript.buffer and !transcript.pool and !transcript.mapping and !transcript.shm);
        transcript.record(.free);
        transcript.committed = false;
        transcript.occupied = false;
        transcript.generation = 0;
    }

    pub fn discard(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        transcript.checkHandle(handle) catch unreachable;
        if (transcript.committed) {
            transcript.record(.disconnect_loss);
            transcript.connected = false;
        }
        transcript.record(.discard);
        transcript.surface = false;
        transcript.region = false;
        transcript.layer = false;
        transcript.viewport = false;
        transcript.buffer = false;
        transcript.pool = false;
        transcript.mapping = false;
        transcript.shm = false;
        transcript.committed = false;
        transcript.occupied = false;
        transcript.generation = 0;
    }

    pub fn checkHandle(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        if (!transcript.occupied or handle.generation != transcript.generation) {
            return error.SurfaceHandleInvalid;
        }
    }

    pub fn step(transcript: *Transcript, operation: Operation) !void {
        transcript.record(operation);
        if (transcript.fail_at == transcript.count - 1) return error.SimulatedFailure;
    }

    pub fn record(transcript: *Transcript, operation: Operation) void {
        std.debug.assert(transcript.count < operation_capacity);
        transcript.operations[transcript.count] = operation;
        transcript.count += 1;
    }

    pub fn expect(transcript: *const Transcript, expected: []const Operation) !void {
        try std.testing.expectEqualSlices(Operation, expected, transcript.operations[0..transcript.count]);
    }
};

const open_operations = [_]Operation{
    .connect,
    .registry,
    .roundtrip_globals,
    .bind_output_v4,
    .roundtrip_output,
    .require_output,
};

const prepare_operations = [_]Operation{
    .reserve,
    .create_surface,
    .create_empty_region,
    .set_input_region,
    .destroy_region,
    .create_layer,
    .set_layer_state,
    .create_viewport,
    .initial_commit,
    .receive_configure,
    .ack_configure,
    .set_viewport,
    .create_shm,
    .map_pixels,
    .create_pool,
    .create_buffer,
    .attach_damage_commit,
    .flush,
};

const release_operations = [_]Operation{
    .unmap,
    .flush,
    .receive_release,
    .destroy_buffer,
    .destroy_pool,
    .unmap_pixels,
    .close_shm,
    .destroy_viewport,
    .destroy_layer,
    .destroy_surface,
    .free,
};

test "one named output maps and releases one background surface in exact order" {
    var transcript: Transcript = .{};
    try wallpaper.openOutput(&transcript, "DP-1");
    var pixels = try image();
    defer pixels.deinit(std.testing.allocator);
    const monitor = monitorValue();
    const handle = try wallpaper.prepareSurface(&transcript, &monitor, &pixels);
    try wallpaper.releaseSurface(&transcript, handle);
    transcript.disconnect();
    try transcript.expect(&open_operations ++ prepare_operations ++ release_operations ++ .{.disconnect});
    try std.testing.expect(!transcript.occupied);
}

test "output discovery failures disconnect only after connection" {
    for (0..open_operations.len) |failure| {
        var transcript = Transcript{ .fail_at = @intCast(failure) };
        try std.testing.expectError(error.SimulatedFailure, wallpaper.openOutput(&transcript, "DP-1"));
        try std.testing.expect(!transcript.connected);
        if (failure > 0) {
            try std.testing.expectEqual(Operation.disconnect, transcript.operations[transcript.count - 1]);
        }
    }
}

test "every preparation failure discards its checked surface" {
    var fail: u8 = 7;
    while (fail < open_operations.len + prepare_operations.len) : (fail += 1) {
        var transcript = Transcript{ .fail_at = fail };
        try wallpaper.openOutput(&transcript, "DP-1");
        var pixels = try image();
        defer pixels.deinit(std.testing.allocator);
        const monitor = monitorValue();
        try std.testing.expectError(
            error.SimulatedFailure,
            wallpaper.prepareSurface(&transcript, &monitor, &pixels),
        );
        try std.testing.expect(!transcript.occupied);
        if (fail == open_operations.len + prepare_operations.len - 1) {
            try std.testing.expectEqual(Operation.disconnect_loss, transcript.operations[transcript.count - 2]);
        }
        try std.testing.expectEqual(Operation.discard, transcript.operations[transcript.count - 1]);
    }
}

test "every release failure disconnects before local discard" {
    const release_start = open_operations.len + prepare_operations.len;
    for (release_start..release_start + 3) |failure| {
        var transcript: Transcript = .{};
        var pixels = try image();
        defer pixels.deinit(std.testing.allocator);
        const monitor = monitorValue();
        try wallpaper.openOutput(&transcript, monitor.name());
        const handle = try wallpaper.prepareSurface(&transcript, &monitor, &pixels);
        transcript.fail_at = @intCast(failure);
        try std.testing.expectError(
            error.SimulatedFailure,
            wallpaper.releaseSurface(&transcript, handle),
        );
        try std.testing.expect(!transcript.occupied);
        try std.testing.expectEqual(Operation.disconnect_loss, transcript.operations[transcript.count - 2]);
        try std.testing.expectEqual(Operation.discard, transcript.operations[transcript.count - 1]);
    }
}

test "invalid handles and pixels perform no surface work" {
    var transcript: Transcript = .{};
    var pixels = try image();
    defer pixels.deinit(std.testing.allocator);
    var monitor = monitorValue();
    monitor.width -= 1;
    try std.testing.expectError(
        error.SurfacePixelsInvalid,
        wallpaper.prepareSurface(&transcript, &monitor, &pixels),
    );
    try std.testing.expectEqual(@as(u8, 0), transcript.count);
    try std.testing.expectError(
        error.SurfaceHandleInvalid,
        transcript.createSurface(.{ .generation = 2 }),
    );
}

fn monitorValue() wallpaper.Monitor {
    var monitor: wallpaper.Monitor = .{
        .name_bytes = undefined,
        .name_len = 4,
        .x = 0,
        .y = 0,
        .width = 1920,
        .height = 1080,
        .scale_100 = 100,
        .transform = .normal,
    };
    @memcpy(monitor.name_bytes[0..4], "DP-1");
    return monitor;
}

fn image() !wallpaper.Image {
    const pixels = try std.testing.allocator.alloc(u32, 1920 * 1080);
    @memset(pixels, 0xff123456);
    return .{ .width = 1920, .height = 1080, .pitch = 1920 * 4, .pixels = pixels };
}
