//! Wayland output facts for wallpaper: never infer monitor state from Hyprland
//! socket JSON, filesystem, focus or a compositor-specific environment key.
const std = @import("std");
const wl = @import("wayland_c");
const wallpaper = @import("root.zig");

const Probe = struct {
    observer: ?*Observer = null,
    output: ?*wl.wl_output = null,
    logical: ?*wl.zxdg_output_v1 = null,
    global: u32 = 0,
    name: [wallpaper.monitor_name_capacity]u8 = undefined,
    name_len: u8 = 0,
    name_seen: bool = false,
    mode_seen: bool = false,
    width: i32 = 0,
    height: i32 = 0,
    transform: i32 = -1,
    position_seen: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    size_seen: bool = false,
    logical_width: i32 = 0,
    logical_height: i32 = 0,
    complete: bool = false,

    fn changed(probe: *Probe) void {
        probe.complete = false;
        if (probe.observer) |owner| {
            if (owner.ready) owner.dirty = true;
        }
    }
};

/// One Wayland connection observes all outputs and keeps no compositor model
/// beyond the currently received protocol facts. A registry topology change
/// requires a complete reconnection, never a guess about removed names.
pub const Observer = struct {
    display: ?*wl.wl_display = null,
    registry: ?*wl.wl_registry = null,
    manager: ?*wl.zxdg_output_manager_v1 = null,
    manager_global: ?u32 = null,
    records: [wallpaper.monitor_capacity]Probe = @splat(.{}),
    globals: [wallpaper.monitor_capacity]u32 = undefined,
    output_count: u8 = 0,
    ready: bool = false,
    dirty: bool = false,
    topology_changed: bool = false,
    failed: bool = false,

    /// Connect only to the actual Wayland display selected by the session.
    pub fn connect(self: *Observer) !void {
        std.debug.assert(self.display == null);
        self.display = wl.wl_display_connect(null) orelse return error.WaylandConnectFailed;
        errdefer self.disconnect();
        self.registry = wl.wl_display_get_registry(self.display.?) orelse return error.WaylandRegistryFailed;
        if (wl.wl_registry_add_listener(self.registry, &registry_listener, self) != 0) return error.WaylandRegistryFailed;
        try self.roundtrip();
        if (self.manager == null or self.output_count == 0) return error.WaylandGlobalMissing;
        for (self.globals[0..self.output_count], 0..) |global, i| {
            const probe = &self.records[i];
            probe.* = .{ .observer = self, .global = global };
            probe.output = @ptrCast(wl.wl_registry_bind(self.registry, global, &wl.wl_output_interface, 4) orelse
                return error.WaylandOutputMissing);
            if (wl.wl_output_add_listener(probe.output, &output_listener, probe) != 0)
                return error.WaylandOutputInvalid;
            probe.logical = wl.wayspot_xdg_output_manager_get_output(self.manager, probe.output) orelse
                return error.WaylandOutputMissing;
            if (wl.wayspot_xdg_output_add_listener(probe.logical, &xdg_listener, probe) != 0)
                return error.WaylandOutputInvalid;
        }
        try self.roundtrip();
        _ = try self.snapshot();
        self.ready = true;
        self.dirty = false;
        self.topology_changed = false;
    }

    /// Disconnect every borrowed Wayland proxy before resetting its records.
    pub fn disconnect(self: *Observer) void {
        if (self.display != null) {
            for (&self.records) |*probe| {
                if (probe.logical) |logical| wl.wayspot_xdg_output_destroy(logical);
                if (probe.output) |output| wl.wl_output_release(output);
            }
            if (self.manager) |manager| wl.wayspot_xdg_output_manager_destroy(manager);
            if (self.registry) |registry| wl.wl_registry_destroy(registry);
            wl.wl_display_disconnect(self.display.?);
        }
        self.* = .{};
    }

    fn roundtrip(self: *Observer) !void {
        if (wl.wl_display_roundtrip(self.display.?) < 0 or self.failed) return error.WaylandRoundtripFailed;
    }

    /// Return the one observer fd to the existing bounded resident poll loop.
    pub fn fd(self: *const Observer) std.posix.fd_t {
        return if (self.display) |display| wl.wl_display_get_fd(display) else -1;
    }

    /// Consume the already-readable output stream; the registry and per-output
    /// callbacks mark changes. A workspace or focus event cannot enter here.
    pub fn dispatch(self: *Observer) !bool {
        if (self.display == null) return error.WaylandConnectFailed;
        if (wl.wl_display_dispatch(self.display.?) < 0 or self.failed) return error.WaylandDisplayLost;
        return self.dirty or self.topology_changed;
    }

    /// A new output/removed output is re-enumerated before publication.
    /// Existing mode/geometry changes wait for their wl_output.done barrier.
    pub fn refresh(self: *Observer) !wallpaper.Snapshot {
        if (self.display == null or self.topology_changed) {
            self.disconnect();
            try self.connect();
        } else if (self.dirty) {
            try self.roundtrip();
        }
        const value = try self.snapshot();
        self.dirty = false;
        return value;
    }

    /// Construct one bounded snapshot from committed wl_output and xdg-output
    /// facts; never mix partial batches or invent fractional physical sizes.
    pub fn snapshot(self: *const Observer) !wallpaper.Snapshot {
        if (self.output_count == 0) return error.NoEnabledMonitors;
        var result: wallpaper.Snapshot = .{};
        var pixels: u64 = 0;
        for (self.records[0..self.output_count]) |*probe| {
            const monitor = try convert(probe);
            const count = @as(u64, monitor.width) * monitor.height;
            pixels += count;
            if (pixels > wallpaper.round_pixel_capacity) return error.RoundPixelsTooMany;
            result.monitors[result.count] = monitor;
            result.count += 1;
        }
        std.mem.sort(wallpaper.Monitor, result.monitors[0..result.count], {}, struct {
            fn less(_: void, left: wallpaper.Monitor, right: wallpaper.Monitor) bool {
                return std.mem.order(u8, left.name(), right.name()) == .lt;
            }
        }.less);
        for (result.monitors[1..result.count], result.monitors[0 .. result.count - 1]) |next, previous| {
            if (std.mem.eql(u8, next.name(), previous.name())) return error.WaylandOutputDuplicate;
        }
        return result;
    }
};

fn convert(probe: *const Probe) !wallpaper.Monitor {
    if (!probe.complete or !probe.name_seen or !probe.mode_seen or
        !probe.position_seen or !probe.size_seen or probe.transform < 0)
        return error.WaylandOutputIncomplete;
    const transform = std.enums.fromInt(wallpaper.Transform, @as(u32, @intCast(probe.transform))) orelse
        return error.WaylandOutputInvalid;
    if (probe.width <= 0 or probe.height <= 0 or probe.logical_width <= 0 or probe.logical_height <= 0)
        return error.WaylandOutputInvalid;
    const rotated = transform == .rotate_90 or transform == .rotate_270 or
        transform == .flipped_90 or transform == .flipped_270;
    const width: u32 = @intCast(if (rotated) probe.height else probe.width);
    const height: u32 = @intCast(if (rotated) probe.width else probe.height);
    if (width > wallpaper.monitor_side_capacity or height > wallpaper.monitor_side_capacity or
        @as(u64, width) * height > wallpaper.monitor_pixel_capacity) return error.MonitorPixelsTooMany;
    const scale_x: f64 = @as(f64, @floatFromInt(width)) / @as(f64, @floatFromInt(probe.logical_width));
    const scale_y: f64 = @as(f64, @floatFromInt(height)) / @as(f64, @floatFromInt(probe.logical_height));
    const scale = @max(scale_x, scale_y);
    if (!std.math.isFinite(scale) or scale <= 0 or scale > 10) return error.MonitorScaleInvalid;
    var monitor: wallpaper.Monitor = .{
        .name_bytes = undefined,
        .name_len = probe.name_len,
        .x = probe.x,
        .y = probe.y,
        .width = width,
        .height = height,
        .scale = scale,
        .transform = transform,
    };
    @memcpy(monitor.name_bytes[0..probe.name_len], probe.name[0..probe.name_len]);
    return monitor;
}

const registry_listener = wl.wl_registry_listener{ .global = registryGlobal, .global_remove = registryRemove };
fn registryGlobal(data: ?*anyopaque, registry: ?*wl.wl_registry, id: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const self: *Observer = @ptrCast(@alignCast(data));
    const name = std.mem.span(interface);
    if (std.mem.eql(u8, name, "zxdg_output_manager_v1")) {
        if (self.manager != null or version < 3) {
            self.failed = true;
            return;
        }
        self.manager = @ptrCast(wl.wl_registry_bind(registry, id, wl.wayspot_xdg_output_manager_interface(), 3));
        if (self.manager == null) self.failed = true else self.manager_global = id;
    } else if (std.mem.eql(u8, name, "wl_output")) {
        if (version < 4 or self.output_count == wallpaper.monitor_capacity) {
            self.failed = true;
            return;
        }
        self.globals[self.output_count] = id;
        self.output_count += 1;
        if (self.ready) self.topology_changed = true;
    }
}
fn registryRemove(data: ?*anyopaque, _: ?*wl.wl_registry, id: u32) callconv(.c) void {
    const self: *Observer = @ptrCast(@alignCast(data));
    for (self.globals[0..self.output_count]) |global| if (global == id) {
        self.topology_changed = true;
        return;
    };
    // A removed manager invalidates the observer's source of logical facts.
    if (self.manager_global == id) self.topology_changed = true;
}

const output_listener = wl.wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = outputDescription,
};
fn outputGeometry(data: ?*anyopaque, _: ?*wl.wl_output, _: i32, _: i32, _: i32, _: i32, _: i32, _: [*c]const u8, _: [*c]const u8, transform: i32) callconv(.c) void {
    const probe: *Probe = @ptrCast(@alignCast(data));
    if (probe.transform == transform) return;
    probe.transform = transform;
    probe.changed();
}
fn outputMode(data: ?*anyopaque, _: ?*wl.wl_output, flags: u32, width: i32, height: i32, _: i32) callconv(.c) void {
    if (flags & wl.WL_OUTPUT_MODE_CURRENT == 0) return;
    const probe: *Probe = @ptrCast(@alignCast(data));
    if (probe.mode_seen and probe.width == width and probe.height == height) return;
    probe.width = width;
    probe.height = height;
    probe.mode_seen = true;
    probe.changed();
}
fn outputDone(data: ?*anyopaque, _: ?*wl.wl_output) callconv(.c) void {
    const probe: *Probe = @ptrCast(@alignCast(data));
    probe.complete = true;
    // Only a preceding meaningful field mutation marks the observer dirty.
}
// Effective scale is derived from the physical mode and xdg logical size.
fn outputScale(_: ?*anyopaque, _: ?*wl.wl_output, _: i32) callconv(.c) void {}
fn outputName(data: ?*anyopaque, _: ?*wl.wl_output, name: [*c]const u8) callconv(.c) void {
    const probe: *Probe = @ptrCast(@alignCast(data));
    const value = std.mem.span(name);
    if (value.len == 0 or value.len > wallpaper.monitor_name_capacity or !std.unicode.utf8ValidateSlice(value)) {
        if (probe.observer) |owner| owner.failed = true;
        return;
    }
    if (probe.name_seen and std.mem.eql(u8, probe.name[0..probe.name_len], value)) return;
    @memcpy(probe.name[0..value.len], value);
    probe.name_len = @intCast(value.len);
    probe.name_seen = true;
    probe.changed();
}
fn outputDescription(_: ?*anyopaque, _: ?*wl.wl_output, _: [*c]const u8) callconv(.c) void {}

const xdg_listener = wl.wayspot_xdg_output_listener{
    .logical_position = logicalPosition,
    .logical_size = logicalSize,
    .done = logicalDone,
    .name = logicalName,
    .description = logicalDescription,
};
fn logicalPosition(data: ?*anyopaque, _: ?*wl.zxdg_output_v1, x: i32, y: i32) callconv(.c) void {
    const probe: *Probe = @ptrCast(@alignCast(data));
    if (probe.position_seen and probe.x == x and probe.y == y) return;
    probe.x = x;
    probe.y = y;
    probe.position_seen = true;
    probe.changed();
}
fn logicalSize(data: ?*anyopaque, _: ?*wl.zxdg_output_v1, width: i32, height: i32) callconv(.c) void {
    const probe: *Probe = @ptrCast(@alignCast(data));
    if (probe.size_seen and probe.logical_width == width and probe.logical_height == height) return;
    probe.logical_width = width;
    probe.logical_height = height;
    probe.size_seen = true;
    probe.changed();
}
fn logicalDone(_: ?*anyopaque, _: ?*wl.zxdg_output_v1) callconv(.c) void {}
fn logicalName(_: ?*anyopaque, _: ?*wl.zxdg_output_v1, _: [*c]const u8) callconv(.c) void {}
fn logicalDescription(_: ?*anyopaque, _: ?*wl.zxdg_output_v1, _: [*c]const u8) callconv(.c) void {}

test "logical 1.5x output yields physical buffer size and exact logical origin" {
    var observer: Observer = .{};
    observer.output_count = 1;
    const probe = &observer.records[0];
    probe.* = .{
        .global = 1,
        .name_seen = true,
        .name_len = 8,
        .mode_seen = true,
        .width = 3840,
        .height = 2160,
        .transform = 0,
        .position_seen = true,
        .x = 1920,
        .y = -80,
        .size_seen = true,
        .logical_width = 2560,
        .logical_height = 1440,
        .complete = true,
    };
    @memcpy(probe.name[0..8], "HDMI-A-1");
    const snapshot = try observer.snapshot();
    try std.testing.expectEqual(@as(u8, 1), snapshot.count);
    try std.testing.expectEqualStrings("HDMI-A-1", snapshot.monitors[0].name());
    try std.testing.expectEqual(@as(i32, 1920), snapshot.monitors[0].x);
    try std.testing.expectEqual(@as(u32, 3840), snapshot.monitors[0].width);
    try std.testing.expectEqual(@as(f64, 1.5), snapshot.monitors[0].scale);
}

test "topology refuses incomplete, duplicate, rotated and oversize output snapshots" {
    var observer: Observer = .{};
    observer.output_count = 1;
    const probe = &observer.records[0];
    probe.* = .{ .name_seen = true, .name_len = 1, .mode_seen = true, .width = 1920, .height = 1080, .transform = 1, .position_seen = true, .size_seen = true, .logical_width = 720, .logical_height = 1280 };
    probe.name[0] = 'A';
    try std.testing.expectError(error.WaylandOutputIncomplete, observer.snapshot());
    probe.complete = true;
    const result = try observer.snapshot();
    try std.testing.expectEqual(@as(u32, 1080), result.monitors[0].width);
    try std.testing.expectEqual(@as(u32, 1920), result.monitors[0].height);
    observer.output_count = 2;
    observer.records[1] = observer.records[0];
    try std.testing.expectError(error.WaylandOutputDuplicate, observer.snapshot());
}

test "Wayland output mutations require a done barrier before publication" {
    var owner: Observer = .{ .ready = true, .output_count = 1 };
    const probe = &owner.records[0];
    probe.* = .{ .observer = &owner };
    outputName(probe, null, "DP-1");
    outputGeometry(probe, null, 0, 0, 0, 0, 0, "", "", 0);
    outputMode(probe, null, wl.WL_OUTPUT_MODE_CURRENT, 1920, 1080, 60000);
    logicalPosition(probe, null, 0, 0);
    logicalSize(probe, null, 1920, 1080);
    try std.testing.expect(owner.dirty);
    try std.testing.expectError(error.WaylandOutputIncomplete, owner.snapshot());
    outputDone(probe, null);
    const initial = try owner.snapshot();
    try std.testing.expectEqualStrings("DP-1", initial.monitors[0].name());
    try std.testing.expectEqual(@as(u32, 1920), initial.monitors[0].width);
    owner.dirty = false;
    logicalSize(probe, null, 1280, 720);
    try std.testing.expectError(error.WaylandOutputIncomplete, owner.snapshot());
    outputDone(probe, null);
    const resized = try owner.snapshot();
    try std.testing.expectEqual(@as(f64, 1.5), resized.monitors[0].scale);
    try std.testing.expect(!initial.eql(&resized));
    owner.dirty = false;
    outputMode(probe, null, 0, 2560, 1440, 60000);
    try std.testing.expect(!owner.dirty);
    const unchanged = try owner.snapshot();
    try std.testing.expect(initial.eql(&unchanged) == false);
    try std.testing.expect(unchanged.eql(&resized));
}

test "Wayland removal compares the actual tracked global IDs" {
    var owner: Observer = .{ .ready = true, .output_count = 2, .manager_global = 73 };
    owner.globals[0] = 12;
    owner.globals[1] = 34;
    registryRemove(&owner, null, 55);
    try std.testing.expect(!owner.topology_changed);
    registryRemove(&owner, null, 12);
    try std.testing.expect(owner.topology_changed);
    owner.topology_changed = false;
    registryRemove(&owner, null, 73);
    try std.testing.expect(owner.topology_changed);
}

test "bad transforms and impossible pixel dimensions never escape output snapshot" {
    var observer: Observer = .{ .output_count = 1 };
    const probe = &observer.records[0];
    probe.* = .{ .name_seen = true, .name_len = 1, .mode_seen = true, .width = 1920, .height = 1080, .transform = 8, .position_seen = true, .size_seen = true, .logical_width = 1920, .logical_height = 1080, .complete = true };
    probe.name[0] = 'A';
    try std.testing.expectError(error.WaylandOutputInvalid, observer.snapshot());
    probe.transform = 0;
    probe.width = 16385;
    try std.testing.expectError(error.MonitorPixelsTooMany, observer.snapshot());
    probe.width = 1920;
    probe.logical_width = 0;
    try std.testing.expectError(error.WaylandOutputInvalid, observer.snapshot());
    probe.logical_width = 1920;
    probe.complete = false;
    try std.testing.expectError(error.WaylandOutputIncomplete, observer.snapshot());
}

test "repeated identical output facts and unrelated globals do not schedule publication" {
    var owner: Observer = .{ .ready = true, .output_count = 1 };
    const probe = &owner.records[0];
    probe.* = .{ .observer = &owner };
    outputName(probe, null, "DP-1");
    outputGeometry(probe, null, 0, 0, 0, 0, 0, "", "", 0);
    outputMode(probe, null, wl.WL_OUTPUT_MODE_CURRENT, 1920, 1080, 60000);
    logicalPosition(probe, null, 0, 0);
    logicalSize(probe, null, 1920, 1080);
    outputDone(probe, null);
    const initial = try owner.snapshot();
    owner.dirty = false;
    for (1..1001) |id| {
        registryGlobal(&owner, null, @intCast(id), "wl_seat", 9);
        outputName(probe, null, "DP-1");
        outputGeometry(probe, null, 0, 0, 0, 0, 0, "", "", 0);
        outputMode(probe, null, wl.WL_OUTPUT_MODE_CURRENT, 1920, 1080, 60000);
        outputScale(probe, null, 1);
        logicalPosition(probe, null, 0, 0);
        logicalSize(probe, null, 1920, 1080);
        outputDone(probe, null);
    }
    try std.testing.expect(!owner.failed and !owner.dirty and !owner.topology_changed);
    try std.testing.expect(initial.eql(&(try owner.snapshot())));
}
