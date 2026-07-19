//! Owns bounded wallpaper facts, parsing, image meaning, round publication, and resident reconciliation.

const std = @import("std");

pub const monitor_capacity = 16;
pub const monitor_name_capacity = 128;
pub const monitor_response_capacity = 64 * 1024;
pub const monitor_side_capacity = 16_384;
pub const monitor_pixel_capacity = 33_177_600;
pub const round_pixel_capacity = 67_108_864;
pub const event_line_capacity = 4096;
pub const event_read_capacity = 8192;
pub const event_batch_capacity = 64;
pub const image_path_capacity = 4095;
pub const image_file_capacity = 64 * 1024 * 1024;
pub const image_side_capacity = 16_384;
pub const image_pixel_capacity = 67_108_864;
pub const wayland_global_capacity = 128;
pub const wayland_configure_capacity = 16;
pub const wayland_release_capacity = 128;
pub const wayland_wait_milliseconds = 1000;
pub const surface_resource_capacity = monitor_capacity * 2;
pub const publication_flush_capacity = 16;
pub const publication_poll_capacity = 16;
/// One reconciliation may compare at most eight complete monitor snapshots.
pub const reconcile_attempt_capacity = 8;
/// Transient protocol mismatch waits at most 250ms before another snapshot.
pub const reconcile_wait_milliseconds = 250;
/// One reconciliation fails visibly after two seconds.
pub const reconcile_deadline_milliseconds = 2000;
/// One readiness result drains at most eight socket2 reads.
pub const event_drain_capacity = 8;
/// One readiness result accepts at most 64KiB from socket2.
pub const event_drain_byte_capacity = 64 * 1024;

/// Collapses resident work without retaining individual external events.
pub const Work = enum { idle, refresh, reconnect };
/// One classified wait result; stop has priority over every other bit.
pub const Ready = packed struct {
    stop: bool = false,
    wayland: bool = false,
    event: bool = false,
    deadline: bool = false,
};
/// Owns one bounded Unix socket path without allocation; callers borrow `slice()`.
pub const SocketPath = struct {
    bytes: [107]u8 = undefined,
    len: u8 = 0,

    /// Borrows the initialized path bytes.
    pub fn slice(path: *const SocketPath) []const u8 {
        return path.bytes[0..path.len];
    }
};
/// Owns the exact Hyprland request and socket2 paths used by one resident run.
pub const SocketPaths = struct { request: SocketPath, event: SocketPath };

/// Owns one published Round and the stable native pointer behind its callbacks.
pub fn Current(comptime Native: type) type {
    return struct { native: *Native, round: Round };
}

pub const Transform = enum(u3) {
    normal,
    rotate_90,
    rotate_180,
    rotate_270,
    flipped,
    flipped_90,
    flipped_180,
    flipped_270,
};

pub const Monitor = struct {
    name_bytes: [monitor_name_capacity]u8,
    name_len: u8,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    scale_100: u16,
    transform: Transform,

    pub fn name(monitor: *const Monitor) []const u8 {
        return monitor.name_bytes[0..monitor.name_len];
    }

    pub fn eql(a: *const Monitor, b: *const Monitor) bool {
        return std.mem.eql(u8, a.name(), b.name()) and a.x == b.x and a.y == b.y and
            a.width == b.width and a.height == b.height and a.scale_100 == b.scale_100 and
            a.transform == b.transform;
    }
};

pub const Snapshot = struct {
    monitors: [monitor_capacity]Monitor = undefined,
    count: u8 = 0,

    pub fn slice(snapshot: *const Snapshot) []const Monitor {
        return snapshot.monitors[0..snapshot.count];
    }

    pub fn eql(a: *const Snapshot, b: *const Snapshot) bool {
        if (a.count != b.count) return false;
        for (a.slice(), b.slice()) |left, right| {
            if (!left.eql(&right)) return false;
        }
        return true;
    }
};

/// Unknown fields are ignored because Hyprland extends this object; every retained field is required and typed.
pub fn parseMonitors(allocator: std.mem.Allocator, bytes: []const u8) !Snapshot {
    if (bytes.len > monitor_response_capacity) return error.MonitorResponseTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
        .parse_numbers = false,
        .duplicate_field_behavior = .@"error",
        .max_value_len = monitor_response_capacity,
    });
    defer parsed.deinit();
    const values = switch (parsed.value) {
        .array => |array| array.items,
        else => return error.MonitorArrayExpected,
    };
    if (values.len > monitor_capacity) return error.TooManyMonitors;

    var snapshot: Snapshot = .{};
    var pixels: u64 = 0;
    for (values) |value| {
        const object = switch (value) {
            .object => |object| object,
            else => return error.MonitorObjectExpected,
        };
        const disabled = try booleanField(object, "disabled");
        const monitor = try parseMonitor(object);
        if (disabled) continue;
        const monitor_pixels = @as(u64, monitor.width) * monitor.height;
        if (monitor_pixels > monitor_pixel_capacity) return error.MonitorPixelsTooMany;
        pixels += monitor_pixels;
        if (pixels > round_pixel_capacity) return error.RoundPixelsTooMany;
        snapshot.monitors[snapshot.count] = monitor;
        snapshot.count += 1;
    }
    if (snapshot.count == 0) return error.NoEnabledMonitors;
    std.mem.sort(Monitor, snapshot.monitors[0..snapshot.count], {}, monitorLessThan);
    for (snapshot.monitors[1..snapshot.count], snapshot.monitors[0 .. snapshot.count - 1]) |current, previous| {
        if (std.mem.eql(u8, current.name(), previous.name())) return error.DuplicateMonitorName;
    }
    return snapshot;
}

fn parseMonitor(object: std.json.ObjectMap) !Monitor {
    const name = try stringField(object, "name");
    if (name.len == 0) return error.MonitorNameEmpty;
    if (name.len > monitor_name_capacity) return error.MonitorNameTooLong;
    if (std.mem.indexOfScalar(u8, name, 0) != null) return error.MonitorNameInvalid;
    const width = try unsignedField(object, "width");
    const height = try unsignedField(object, "height");
    if (width == 0 or height == 0) return error.MonitorDimensionsZero;
    if (width > monitor_side_capacity or height > monitor_side_capacity) {
        return error.MonitorDimensionsTooLarge;
    }
    var monitor: Monitor = .{
        .name_bytes = undefined,
        .name_len = @intCast(name.len),
        .x = try signedField(object, "x"),
        .y = try signedField(object, "y"),
        .width = width,
        .height = height,
        .scale_100 = try parseScale(try numberField(object, "scale")),
        .transform = std.enums.fromInt(Transform, try unsignedField(object, "transform")) orelse
            return error.MonitorTransformInvalid,
    };
    @memcpy(monitor.name_bytes[0..name.len], name);
    return monitor;
}

fn field(object: std.json.ObjectMap, name: []const u8) !std.json.Value {
    return object.get(name) orelse error.MonitorFieldMissing;
}

fn stringField(object: std.json.ObjectMap, name: []const u8) ![]const u8 {
    return switch (try field(object, name)) {
        .string => |value| value,
        else => error.MonitorFieldTypeInvalid,
    };
}

fn numberField(object: std.json.ObjectMap, name: []const u8) ![]const u8 {
    return switch (try field(object, name)) {
        .number_string => |value| value,
        else => error.MonitorFieldTypeInvalid,
    };
}

fn booleanField(object: std.json.ObjectMap, name: []const u8) !bool {
    return switch (try field(object, name)) {
        .bool => |value| value,
        else => error.MonitorFieldTypeInvalid,
    };
}

fn unsignedField(object: std.json.ObjectMap, name: []const u8) !u32 {
    return std.fmt.parseInt(u32, try numberField(object, name), 10) catch error.MonitorIntegerInvalid;
}

fn signedField(object: std.json.ObjectMap, name: []const u8) !i32 {
    return std.fmt.parseInt(i32, try numberField(object, name), 10) catch error.MonitorIntegerInvalid;
}

fn parseScale(bytes: []const u8) !u16 {
    const dot = std.mem.indexOfScalar(u8, bytes, '.') orelse return error.MonitorScaleInvalid;
    if (dot == 0 or dot + 3 != bytes.len) return error.MonitorScaleInvalid;
    if (bytes[0] == '0' and dot != 1) return error.MonitorScaleInvalid;
    for (bytes[0..dot]) |byte| if (!std.ascii.isDigit(byte)) return error.MonitorScaleInvalid;
    if (!std.ascii.isDigit(bytes[dot + 1]) or !std.ascii.isDigit(bytes[dot + 2])) {
        return error.MonitorScaleInvalid;
    }
    const whole = std.fmt.parseInt(u16, bytes[0..dot], 10) catch return error.MonitorScaleInvalid;
    if (whole > 10) return error.MonitorScaleInvalid;
    const scale = whole * 100 + (bytes[dot + 1] - '0') * 10 + bytes[dot + 2] - '0';
    if (scale == 0 or scale > 1000) return error.MonitorScaleInvalid;
    return scale;
}

fn monitorLessThan(_: void, left: Monitor, right: Monitor) bool {
    return std.mem.order(u8, left.name(), right.name()) == .lt;
}

pub const Event = enum { refresh, ignore, malformed };

pub const Feed = struct {
    events: [event_batch_capacity]Event = undefined,
    count: u8 = 0,
    consumed: usize = 0,

    pub fn slice(feed: *const Feed) []const Event {
        return feed.events[0..feed.count];
    }
};

pub const EventLines = struct {
    bytes: [event_line_capacity]u8 = undefined,
    len: u16 = 0,
    discarding: bool = false,

    /// Feed stops at an event boundary when its output is full; consumed preserves the caller's remainder.
    pub fn feed(lines: *EventLines, input: []const u8) Feed {
        var result: Feed = .{};
        while (result.consumed < input.len and result.count < event_batch_capacity) {
            const byte = input[result.consumed];
            result.consumed += 1;
            if (lines.discarding) {
                if (byte == '\n') {
                    lines.discarding = false;
                    result.events[result.count] = .malformed;
                    result.count += 1;
                }
                continue;
            }
            if (byte == '\n') {
                result.events[result.count] = classify(lines.bytes[0..lines.len]);
                result.count += 1;
                lines.len = 0;
            } else if (lines.len == event_line_capacity) {
                lines.len = 0;
                lines.discarding = true;
            } else {
                lines.bytes[lines.len] = byte;
                lines.len += 1;
            }
        }
        return result;
    }
};

/// Drains one bounded socket2 batch; loss or excess is visible and no event mutates monitor facts.
pub fn drainEvents(source: anytype, event_fd: anytype, lines: *EventLines, work: *Work) !bool {
    var bytes: [event_read_capacity]u8 = undefined;
    var total: usize = 0;
    var changed = false;
    for (0..event_drain_capacity) |_| {
        const count = source.readEvent(event_fd, &bytes) catch |err| switch (err) {
            error.WouldBlock => return changed,
            else => return err,
        };
        if (count == 0) return error.EventSocketLost;
        total += count;
        if (total > event_drain_byte_capacity) return error.EventDrainExceeded;
        var offset: usize = 0;
        while (offset < count) {
            const feed = lines.feed(bytes[offset..count]);
            std.debug.assert(feed.consumed > 0);
            offset += feed.consumed;
            for (feed.slice()) |event| if (event == .refresh) {
                work.* = .refresh;
                changed = true;
            };
        }
        if (count < bytes.len) return changed;
    }
    return error.EventDrainExceeded;
}

pub const Image = struct {
    width: u32,
    height: u32,
    pitch: u32,
    pixels: []u32,

    pub fn deinit(image: *Image, allocator: std.mem.Allocator) void {
        allocator.free(image.pixels);
        image.* = undefined;
    }
};

pub const Crop = struct { x: u32, y: u32, width: u32, height: u32 };
pub const SurfaceHandle = packed struct { index: u8, generation: u32 };
pub const Configure = struct { serial: u32, width: u32, height: u32 };

pub const Round = struct {
    monitors: Snapshot = .{},
    handles: [monitor_capacity]SurfaceHandle = undefined,

    pub fn handleSlice(round: *const Round) []const SurfaceHandle {
        return round.handles[0..round.monitors.count];
    }
};

comptime {
    std.debug.assert(surface_resource_capacity == monitor_capacity * 2);
    std.debug.assert(surface_resource_capacity <= std.math.maxInt(u8));
}

pub fn openOutputs(source: anytype, snapshot: *const Snapshot) !void {
    if (snapshot.count == 0 or snapshot.count > monitor_capacity) return error.OutputSnapshotInvalid;
    try source.openOutputs(snapshot);
}

pub fn prepareRound(
    source: anytype,
    allocator: std.mem.Allocator,
    snapshot: *const Snapshot,
    image: *const Image,
) !Round {
    try openOutputs(source, snapshot);
    var round = Round{ .monitors = snapshot.* };
    round.monitors.count = 0;
    errdefer discardRound(source, &round);
    for (snapshot.slice(), 0..) |*monitor, index| {
        var pixels = try coverImage(source, allocator, image, monitor.width, monitor.height);
        defer pixels.deinit(allocator);
        round.handles[index] = try source.prepare(@intCast(index), monitor, &pixels);
        round.monitors.count = @intCast(index + 1);
    }
    round.monitors = snapshot.*;
    return round;
}

pub fn publishRound(source: anytype, current: *Round, next: *Round, stop: anytype) !void {
    if (next.monitors.count == 0) return error.RoundEmpty;
    if (current.monitors.count != 0 and !current.monitors.eql(&next.monitors)) {
        return error.RoundSnapshotChanged;
    }
    try source.validatePublication(current.handleSlice(), next.handleSlice());
    for (next.handleSlice()) |handle| source.queueMap(handle);
    var old_index = current.monitors.count;
    while (old_index > 0) {
        old_index -= 1;
        source.queueUnmap(current.handles[old_index]);
    }
    source.flushPublication(stop) catch |err| {
        source.disconnectAfterDisplayLoss();
        return err;
    };
    source.finishPublication(current.handleSlice(), next.handleSlice());
    const old = current.*;
    current.* = next.*;
    next.* = .{};
    var index = old.monitors.count;
    while (index > 0) {
        index -= 1;
        source.releaseRetired(old.handles[index], stop) catch |err| {
            source.disconnectAfterDisplayLoss();
            return err;
        };
    }
}

pub fn releaseRound(source: anytype, current: *Round, stop: anytype) !void {
    if (current.monitors.count == 0) return;
    try source.validatePublication(current.handleSlice(), &.{});
    var index = current.monitors.count;
    while (index > 0) {
        index -= 1;
        source.queueUnmap(current.handles[index]);
    }
    source.flushPublication(stop) catch |err| {
        source.disconnectAfterDisplayLoss();
        return err;
    };
    source.finishPublication(current.handleSlice(), &.{});
    const old = current.*;
    current.* = .{};
    index = old.monitors.count;
    while (index > 0) {
        index -= 1;
        source.releaseRetired(old.handles[index], stop) catch |err| {
            source.disconnectAfterDisplayLoss();
            return err;
        };
    }
}

pub fn discardRound(source: anytype, round: *Round) void {
    var index = round.monitors.count;
    while (index > 0) {
        index -= 1;
        source.discardPrepared(round.handles[index]);
    }
    round.* = .{};
}

/// Tries at most eight snapshots in two seconds; Current changes only after candidate publication.
pub fn reconcile(
    resident: anytype,
    allocator: std.mem.Allocator,
    image: *const Image,
    current: anytype,
    stop_fd: anytype,
    event_fd: anytype,
    paths: *const SocketPaths,
    lines: *EventLines,
    work: *Work,
) !void {
    const deadline = try std.math.add(u64, resident.now(), reconcile_deadline_milliseconds);
    for (0..reconcile_attempt_capacity) |attempt| {
        _ = try waitForWork(resident, current.native, stop_fd, event_fd, lines, work, 0);
        if (work.* == .reconnect) {
            resident.reconnectEvent(event_fd, paths.event.slice(), stop_fd, deadline) catch |err| {
                if (attempt + 1 == reconcile_attempt_capacity) return err;
                try waitAttempt(resident, current.native, stop_fd, event_fd, deadline, lines, work);
                continue;
            };
        }
        var reply: [monitor_response_capacity]u8 = undefined;
        const count = requestMonitors(
            resident,
            paths.request.slice(),
            stop_fd,
            event_fd.*,
            &reply,
            deadline,
        ) catch |err| {
            if (err == error.EventSocketLost) {
                resident.closeEvent(event_fd);
                lines.* = .{};
                work.* = .reconnect;
            }
            if (!transient(err) or attempt + 1 == reconcile_attempt_capacity) return err;
            try waitAttempt(resident, current.native, stop_fd, event_fd, deadline, lines, work);
            continue;
        };
        const snapshot = try parseMonitors(allocator, reply[0..count]);
        if (try waitForWork(resident, current.native, stop_fd, event_fd, lines, work, 0)) {
            if (attempt + 1 == reconcile_attempt_capacity) return error.ReconcileExhausted;
            try waitAttempt(resident, current.native, stop_fd, event_fd, deadline, lines, work);
            continue;
        }
        if (snapshot.eql(&current.round.monitors) and !resident.outputsChanged(current.native)) {
            work.* = .idle;
            return;
        }
        const candidate = try resident.createNative(allocator);
        var candidate_round: Round = .{};
        var candidate_owned = true;
        defer if (candidate_owned) {
            discardRound(candidate, &candidate_round);
            resident.destroyNative(allocator, candidate);
        };
        candidate_round = prepareRound(candidate, allocator, &snapshot, image) catch |err| {
            if (!transient(err) or attempt + 1 == reconcile_attempt_capacity) return err;
            try waitAttempt(resident, current.native, stop_fd, event_fd, deadline, lines, work);
            continue;
        };
        var published: Round = .{};
        publishRound(candidate, &published, &candidate_round, stop_fd) catch |err| {
            candidate_round = .{};
            return err;
        };
        const old_native = current.native;
        var old_round = current.round;
        current.* = .{ .native = candidate, .round = published };
        candidate_owned = false;
        releaseRound(old_native, &old_round, stop_fd) catch |err| {
            old_native.disconnectAfterDisplayLoss();
            resident.destroyNative(allocator, old_native);
            if (err == error.WaylandFlushStopped) {
                releaseRound(current.native, &current.round, stop_fd) catch {
                    current.native.disconnectAfterDisplayLoss();
                    current.round = .{};
                };
                return error.Stopped;
            }
            return err;
        };
        resident.destroyNative(allocator, old_native);
        work.* = .idle;
        return;
    }
    return error.ReconcileExhausted;
}

/// Reads one complete bounded `j/monitors` reply and closes its per-call socket on every path.
pub fn requestMonitors(
    source: anytype,
    path: []const u8,
    stop_fd: anytype,
    event_fd: anytype,
    reply: []u8,
    deadline: u64,
) !usize {
    const fd = try source.connectRequest(path, stop_fd, event_fd, deadline);
    defer source.closeRequest(fd);
    var offset: usize = 0;
    var attempts: u8 = 0;
    while (offset < "j/monitors".len and attempts < 32) : (attempts += 1) {
        offset += source.writeRequest(fd, "j/monitors"[offset..]) catch |err| switch (err) {
            error.WouldBlock => {
                try source.waitSocket(fd, stop_fd, event_fd, true, deadline);
                continue;
            },
            else => return err,
        };
    }
    if (offset != "j/monitors".len) return error.RequestWriteIncomplete;
    offset = 0;
    attempts = 0;
    while (attempts < 32) : (attempts += 1) {
        var probe: [1]u8 = undefined;
        const output = if (offset == reply.len) &probe else reply[offset..];
        const count = source.readReply(fd, output) catch |err| switch (err) {
            error.WouldBlock => {
                try source.waitSocket(fd, stop_fd, event_fd, false, deadline);
                continue;
            },
            else => return err,
        };
        if (offset == reply.len and count != 0) return error.MonitorResponseTooLong;
        if (count == 0) return offset;
        offset += count;
    }
    return error.RequestReadAttemptsExceeded;
}

/// Blocks one resident thread until stop or fatal error while borrowing resident fds and image.
pub fn run(
    resident: anytype,
    allocator: std.mem.Allocator,
    image: *const Image,
    current: anytype,
    stop_fd: anytype,
    event_fd: anytype,
    paths: *const SocketPaths,
) !void {
    var lines: EventLines = .{};
    var work: Work = .refresh;
    while (true) {
        if (work == .idle) {
            _ = try waitForWork(resident, current.native, stop_fd, event_fd, &lines, &work, null);
        } else {
            try reconcile(resident, allocator, image, current, stop_fd, event_fd, paths, &lines, &work);
        }
    }
}

// Blocks one bounded convergence interval without taking ownership of resident state.
fn waitAttempt(
    resident: anytype,
    native: anytype,
    stop_fd: anytype,
    event_fd: anytype,
    deadline: u64,
    lines: *EventLines,
    work: *Work,
) !void {
    const now = resident.now();
    if (now >= deadline) return error.ReconcileTimeout;
    _ = try waitForWork(resident, native, stop_fd, event_fd, lines, work, @min(
        reconcile_wait_milliseconds,
        deadline - now,
    ));
}

// Classifies one borrowed-fd wait and drains only the descriptors reported ready.
fn waitForWork(
    resident: anytype,
    native: anytype,
    stop_fd: anytype,
    event_fd: anytype,
    lines: *EventLines,
    work: *Work,
    timeout: ?u64,
) !bool {
    const ready = resident.wait(native, stop_fd, event_fd.*, timeout) catch |err| {
        if (err != error.EventSocketLost) return err;
        resident.closeEvent(event_fd);
        lines.* = .{};
        work.* = .reconnect;
        return true;
    };
    if (ready.stop) return error.Stopped;
    var changed = false;
    if (ready.wayland and try resident.drainWayland(native)) {
        work.* = .refresh;
        changed = true;
    }
    if (ready.event) changed = drainEvents(resident, event_fd.*, lines, work) catch |err| {
        if (err != error.EventSocketLost) return err;
        resident.closeEvent(event_fd);
        lines.* = .{};
        work.* = .reconnect;
        return true;
    } or changed;
    return changed;
}

// Names only protocol-order failures that another complete snapshot may resolve.
fn transient(err: anyerror) bool {
    return switch (err) {
        error.ConnectionRefused,
        error.ConnectionResetByPeer,
        error.ConnectionTimedOut,
        error.ConnectionInterrupted,
        error.EventSocketLost,
        error.WaylandOutputMissing,
        error.WaylandOutputChanged,
        => true,
        else => false,
    };
}

pub fn loadImage(source: anytype, allocator: std.mem.Allocator, path: []const u8) !Image {
    try validateImagePath(path);
    const bytes = bytes: {
        try source.open(path);
        defer source.close();
        const stat = try source.stat();
        if (stat.kind != .file) return error.ImageNotRegularFile;
        if (stat.size > image_file_capacity) return error.ImageFileTooLarge;
        const bytes = try allocator.alloc(u8, @intCast(stat.size));
        errdefer allocator.free(bytes);
        if (try source.read(bytes) != bytes.len) return error.ImageReadIncomplete;
        break :bytes bytes;
    };
    defer allocator.free(bytes);
    const dimensions = try inspectPng(bytes);
    var image = try source.decode(allocator, bytes);
    errdefer image.deinit(allocator);
    try validateImage(&image);
    if (image.width != dimensions.width or image.height != dimensions.height) {
        return error.ImageDimensionsChanged;
    }
    return image;
}

pub fn coverImage(
    source: anytype,
    allocator: std.mem.Allocator,
    image: *const Image,
    width: u32,
    height: u32,
) !Image {
    try validateImage(image);
    const crop = try coverCrop(image.width, image.height, width, height);
    const count = try surfacePixelCount(width, height);
    const pixels = try allocator.alloc(u32, count);
    errdefer allocator.free(pixels);
    try source.scale(image, crop, width, height, pixels);
    return .{ .width = width, .height = height, .pitch = width * 4, .pixels = pixels };
}

pub fn coverCrop(source_width: u32, source_height: u32, width: u32, height: u32) !Crop {
    _ = try surfacePixelCount(source_width, source_height);
    _ = try surfacePixelCount(width, height);
    var crop_width = source_width;
    var crop_height = source_height;
    const source_ratio = @as(u64, source_width) * height;
    const target_ratio = @as(u64, source_height) * width;
    if (source_ratio > target_ratio) {
        crop_width = @intCast(@max(1, @as(u64, source_height) * width / height));
    } else if (source_ratio < target_ratio) {
        crop_height = @intCast(@max(1, @as(u64, source_width) * height / width));
    }
    return .{
        .x = (source_width - crop_width) / 2,
        .y = (source_height - crop_height) / 2,
        .width = crop_width,
        .height = crop_height,
    };
}

fn validateImagePath(path: []const u8) !void {
    if (path.len == 0) return error.ImagePathEmpty;
    if (path.len > image_path_capacity) return error.ImagePathTooLong;
    if (!std.unicode.utf8ValidateSlice(path) or std.mem.indexOfScalar(u8, path, 0) != null) {
        return error.ImagePathInvalid;
    }
}

fn validateImage(image: *const Image) !void {
    const count = try surfacePixelCount(image.width, image.height);
    if (image.pitch != image.width * 4) return error.ImagePitchInvalid;
    if (image.pixels.len != count) return error.ImagePixelsInvalid;
}

pub fn surfacePixelCount(width: u32, height: u32) !usize {
    if (width == 0 or height == 0) return error.ImageDimensionsZero;
    if (width > image_side_capacity or height > image_side_capacity) return error.ImageDimensionsTooLarge;
    const count = @as(u64, width) * height;
    if (count > image_pixel_capacity) return error.ImagePixelsTooMany;
    return @intCast(count);
}

fn inspectPng(bytes: []const u8) !struct { width: u32, height: u32 } {
    if (bytes.len < 24 or !std.mem.eql(u8, bytes[0..8], "\x89PNG\r\n\x1a\n") or
        !std.mem.eql(u8, bytes[12..16], "IHDR"))
    {
        return error.ImagePngInvalid;
    }
    const width = std.mem.readInt(u32, bytes[16..20], .big);
    const height = std.mem.readInt(u32, bytes[20..24], .big);
    _ = try surfacePixelCount(width, height);
    return .{ .width = width, .height = height };
}

fn classify(line: []const u8) Event {
    if (std.mem.indexOfScalar(u8, line, 0) != null) return .malformed;
    const separator = std.mem.indexOf(u8, line, ">>") orelse return .malformed;
    if (separator == 0) return .malformed;
    const name = line[0..separator];
    for (name) |byte| {
        if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_') return .malformed;
    }
    inline for (.{
        "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded",
    }) |refresh| {
        if (std.mem.eql(u8, name, refresh)) return .refresh;
    }
    return .ignore;
}

const one_monitor =
    \\[{"name":"DP-1","width":1920,"height":1080,"x":-1920,"y":0,
    \\"scale":1.25,"transform":0,"disabled":false}]
;

test "monitor response retains exact facts and ignores extensions" {
    const json =
        \\[{"name":"DP-2","width":2560,"height":1440,"x":0,"y":0,"scale":1.00,
        \\"transform":3,"disabled":false,"future":{"nested":true}},
        \\{"name":"DP-1","width":1920,"height":1080,"x":-1920,"y":0,"scale":1.25,
        \\"transform":0,"disabled":false}]
    ;
    const snapshot = try parseMonitors(std.testing.allocator, json);
    try std.testing.expectEqual(@as(u8, 2), snapshot.count);
    try std.testing.expectEqualStrings("DP-1", snapshot.monitors[0].name());
    try std.testing.expectEqual(@as(i32, -1920), snapshot.monitors[0].x);
    try std.testing.expectEqual(@as(u16, 125), snapshot.monitors[0].scale_100);
    try std.testing.expectEqual(Transform.rotate_270, snapshot.monitors[1].transform);
}

test "snapshot equality covers every retained fact" {
    const first = try parseMonitors(std.testing.allocator, one_monitor);
    const same = try parseMonitors(std.testing.allocator,
        \\[{"future":1,"disabled":false,"transform":0,"scale":1.25,"y":0,
        \\"x":-1920,"height":1080,"width":1920,"name":"DP-1"}]
    );
    const changed = try parseMonitors(std.testing.allocator,
        \\[{"name":"DP-1","width":1920,"height":1080,"x":-1919,"y":0,
        \\"scale":1.25,"transform":0,"disabled":false}]
    );
    try std.testing.expect(first.eql(&same));
    try std.testing.expect(!first.eql(&changed));
}

test "scale accepts only pinned two-decimal spelling" {
    try std.testing.expectEqual(@as(u16, 1), try parseScale("0.01"));
    try std.testing.expectEqual(@as(u16, 100), try parseScale("1.00"));
    try std.testing.expectEqual(@as(u16, 125), try parseScale("1.25"));
    try std.testing.expectEqual(@as(u16, 1000), try parseScale("10.00"));
    inline for (.{
        "0.00", "1",        "1.0",   "01.00",    "+1.00", "-1.00", "1.000", "1e0", "1e999",
        "NaN",  "Infinity", "10.01", "65535.00",
    }) |invalid| {
        try std.testing.expectError(error.MonitorScaleInvalid, parseScale(invalid));
    }
}

test "transform tags match the pinned Hyprland wire values" {
    const transforms = std.enums.values(Transform);
    try std.testing.expectEqual(@as(usize, 8), transforms.len);
    for (transforms, 0..) |transform, value| {
        try std.testing.expectEqual(value, @intFromEnum(transform));
    }
}

test "monitor required fields and types reject exactly" {
    try std.testing.expectError(error.MonitorFieldMissing, parseMonitors(std.testing.allocator,
        \\[{"name":"DP-1","width":1920,"height":1080,"x":0,"y":0,
        \\"scale":1.00,"transform":0}]
    ));
    try std.testing.expectError(error.MonitorFieldTypeInvalid, parseMonitors(std.testing.allocator,
        \\[{"name":"DP-1","width":"1920","height":1080,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ));
    try std.testing.expectError(error.DuplicateField, parseMonitors(std.testing.allocator,
        \\[{"name":"DP-1","name":"DP-2","width":1,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ));
}

test "monitor identity dimensions coordinates transform and availability are bounded" {
    try expectMonitorError(error.MonitorNameEmpty,
        \\[{"name":"","width":1,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.MonitorDimensionsZero,
        \\[{"name":"A","width":0,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.MonitorDimensionsTooLarge,
        \\[{"name":"A","width":16385,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.MonitorPixelsTooMany,
        \\[{"name":"A","width":8192,"height":4096,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.MonitorIntegerInvalid,
        \\[{"name":"A","width":1,"height":1,"x":2147483648,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.MonitorTransformInvalid,
        \\[{"name":"A","width":1,"height":1,"x":0,"y":0,"scale":1.00,"transform":8,"disabled":false}]
    );
    try expectMonitorError(error.NoEnabledMonitors,
        \\[{"name":"A","width":1,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":true}]
    );
    try expectMonitorError(error.NoEnabledMonitors, "[]");
}

test "monitor name count and round pixels are bounded after sorting" {
    var exact_name: [monitor_name_capacity]u8 = @splat('a');
    var name: [monitor_name_capacity + 1]u8 = @splat('a');
    var json: [512]u8 = undefined;
    const exact_name_json = try std.fmt.bufPrint(&json,
        \\[{{"name":"{s}","width":1,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}}]
    , .{&exact_name});
    const named = try parseMonitors(std.testing.allocator, exact_name_json);
    try std.testing.expectEqual(@as(usize, monitor_name_capacity), named.monitors[0].name().len);
    const overlong = try std.fmt.bufPrint(&json,
        \\[{{"name":"{s}","width":1,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}}]
    , .{&name});
    try std.testing.expectError(error.MonitorNameTooLong, parseMonitors(std.testing.allocator, overlong));
    try expectMonitorError(error.DuplicateMonitorName,
        \\[{"name":"A","width":1,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\{"name":"A","width":1,"height":1,"x":1,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try expectMonitorError(error.RoundPixelsTooMany,
        \\[{"name":"A","width":7680,"height":4320,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\{"name":"B","width":7680,"height":4320,"x":1,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\{"name":"C","width":1920,"height":1080,"x":2,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    const exact = try parseMonitors(std.testing.allocator,
        \\[{"name":"A","width":7680,"height":4320,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\{"name":"B","width":7680,"height":4320,"x":1,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\{"name":"C","width":736,"height":1024,"x":2,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    );
    try std.testing.expectEqual(@as(u8, 3), exact.count);

    var many_json: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&many_json);
    try writer.writeAll("[");
    for (0..monitor_capacity + 1) |index| {
        if (index != 0) try writer.writeAll(",");
        try writer.print(
            "{{\"name\":\"M{d}\",\"width\":1,\"height\":1,\"x\":0,\"y\":0," ++
                "\"scale\":1.00,\"transform\":0,\"disabled\":false}}",
            .{index},
        );
    }
    try writer.writeAll("]");
    try std.testing.expectError(
        error.TooManyMonitors,
        parseMonitors(std.testing.allocator, writer.buffered()),
    );
}

test "monitor response bytes and JSON are bounded" {
    var exact: [monitor_response_capacity]u8 = @splat(' ');
    @memcpy(exact[0..one_monitor.len], one_monitor);
    const exact_snapshot = try parseMonitors(std.testing.allocator, &exact);
    try std.testing.expectEqual(@as(u8, 1), exact_snapshot.count);
    var excessive: [monitor_response_capacity + 1]u8 = @splat(' ');
    try std.testing.expectError(
        error.MonitorResponseTooLong,
        parseMonitors(std.testing.allocator, &excessive),
    );
    var invalid_utf8 = [_]u8{ '[', 0xff, ']' };
    try std.testing.expectError(error.InvalidUtf8, parseMonitors(std.testing.allocator, &invalid_utf8));
    try std.testing.expectError(
        error.MonitorArrayExpected,
        parseMonitors(std.testing.allocator, "{}"),
    );
    try std.testing.expectError(
        error.MonitorObjectExpected,
        parseMonitors(std.testing.allocator, "[1]"),
    );
    if (parseMonitors(std.testing.allocator, "[") catch null) |_| return error.ExpectedMalformedJson;
}

test "event fragments coalesce and classify without payload state" {
    var lines: EventLines = .{};
    try std.testing.expectEqual(@as(usize, 0), lines.feed("monitoradd").count);
    const feed = lines.feed("ed>>DP-1\nworkspace>>1\nconfigreloaded>>\n");
    try std.testing.expectEqualSlices(Event, &.{ .refresh, .ignore, .refresh }, feed.slice());
    try std.testing.expectEqual(@as(u16, 0), lines.len);
}

test "only exact monitor and config event names refresh" {
    var lines: EventLines = .{};
    const feed = lines.feed(
        "monitoradded>>A\nmonitoraddedv2>>1,A,x\nmonitorremoved>>A\n" ++
            "monitorremovedv2>>1,A,x\nconfigreloaded>>\nfocusedmon>>A,1\n" ++
            "workspace>>1\nactivewindow>>kitty,x\nopenwindow>>x\nmouse>>move\n",
    );
    try std.testing.expectEqualSlices(Event, &.{
        .refresh, .refresh, .refresh, .refresh, .refresh,
        .ignore,  .ignore,  .ignore,  .ignore,  .ignore,
    }, feed.slice());
}

test "malformed and overlong lines preserve following valid lines" {
    var lines: EventLines = .{};
    const malformed = lines.feed(">>x\nmissing\nbad-name>>x\nok>>a\x00b\nworkspace>>1\n");
    try std.testing.expectEqualSlices(
        Event,
        &.{ .malformed, .malformed, .malformed, .malformed, .ignore },
        malformed.slice(),
    );
    var bytes: [event_line_capacity + 32]u8 = @splat('a');
    bytes[event_line_capacity + 1] = '\n';
    @memcpy(bytes[event_line_capacity + 2 ..][0.."monitoradded>>A\n".len], "monitoradded>>A\n");
    const overlong = lines.feed(bytes[0 .. event_line_capacity + 2 + "monitoradded>>A\n".len]);
    try std.testing.expectEqualSlices(Event, &.{ .malformed, .refresh }, overlong.slice());
}

test "event batch returns an exact unconsumed remainder" {
    const line = "workspace>>1\n";
    var bytes: [line.len * (event_batch_capacity + 1)]u8 = undefined;
    for (0..event_batch_capacity + 1) |index| @memcpy(bytes[index * line.len ..][0..line.len], line);
    var lines: EventLines = .{};
    const first = lines.feed(&bytes);
    try std.testing.expectEqual(@as(u8, event_batch_capacity), first.count);
    try std.testing.expectEqual(line.len * event_batch_capacity, first.consumed);
    const second = lines.feed(bytes[first.consumed..]);
    try std.testing.expectEqualSlices(Event, &.{.ignore}, second.slice());
    try std.testing.expectEqual(bytes.len - first.consumed, second.consumed);
}

test "generated monitor JSON and arbitrary bytes remain bounded" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzMonitors, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzMonitors({}, &empty);
}

test "generated event histories remain bounded" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzEvents, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzEvents({}, &empty);
}

const FileStat = struct { kind: std.Io.File.Kind, size: u64 };

const ImageStep = union(enum) {
    open: bool,
    stat: ?FileStat,
    read: enum { complete, short, fail },
    close,
    decode: union(enum) {
        image: struct { width: u32, height: u32 },
        failed,
        dimensions_failed,
        format_failed,
        convert_failed,
    },
    scale: bool,
};

const ImageTranscript = struct {
    steps: []const ImageStep,
    index: usize = 0,
    opened: bool = false,

    fn open(transcript: *ImageTranscript, _: []const u8) !void {
        const success = switch (try transcript.next()) {
            .open => |value| value,
            else => return error.ImageTranscriptMismatch,
        };
        if (!success) return error.ImageOpenFailed;
        transcript.opened = true;
    }

    fn stat(transcript: *ImageTranscript) !FileStat {
        std.debug.assert(transcript.opened);
        return switch (try transcript.next()) {
            .stat => |value| value orelse error.ImageStatFailed,
            else => error.ImageTranscriptMismatch,
        };
    }

    fn read(transcript: *ImageTranscript, bytes: []u8) !usize {
        std.debug.assert(transcript.opened);
        return switch (try transcript.next()) {
            .read => |result| switch (result) {
                .complete => blk: {
                    pngHeader(bytes, 4, 3);
                    break :blk bytes.len;
                },
                .short => bytes.len - 1,
                .fail => error.ImageReadFailed,
            },
            else => error.ImageTranscriptMismatch,
        };
    }

    fn close(transcript: *ImageTranscript) void {
        std.debug.assert(transcript.opened);
        std.debug.assert((transcript.next() catch unreachable) == .close);
        transcript.opened = false;
    }

    fn decode(transcript: *ImageTranscript, allocator: std.mem.Allocator, _: []const u8) !Image {
        std.debug.assert(!transcript.opened);
        const dimensions = switch (try transcript.next()) {
            .decode => |result| switch (result) {
                .image => |value| value,
                .failed => return error.ImageDecodeFailed,
                .dimensions_failed => return error.ImageDimensionsTooLarge,
                .format_failed => return error.ImageFormatInvalid,
                .convert_failed => return error.ImageConvertFailed,
            },
            else => return error.ImageTranscriptMismatch,
        };
        const pixels = try allocator.alloc(u32, try surfacePixelCount(dimensions.width, dimensions.height));
        @memset(pixels, 0xff102030);
        return .{
            .width = dimensions.width,
            .height = dimensions.height,
            .pitch = dimensions.width * 4,
            .pixels = pixels,
        };
    }

    fn scale(
        transcript: *ImageTranscript,
        _: *const Image,
        crop: Crop,
        width: u32,
        height: u32,
        output: []u32,
    ) !void {
        const success = switch (try transcript.next()) {
            .scale => |value| value,
            else => return error.ImageTranscriptMismatch,
        };
        if (!success) return error.ImageScaleFailed;
        try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 4, .height = 3 }, crop);
        try std.testing.expectEqual(@as(u32, 8), width);
        try std.testing.expectEqual(@as(u32, 6), height);
        @memset(output, 0xff102030);
    }

    fn done(transcript: *const ImageTranscript) !void {
        try std.testing.expectEqual(transcript.steps.len, transcript.index);
        try std.testing.expect(!transcript.opened);
    }

    fn next(transcript: *ImageTranscript) !ImageStep {
        if (transcript.index == transcript.steps.len) return error.ImageTranscriptMismatch;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

test "image task owns exact file decode and scale history" {
    const steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 4, .height = 3 } } },
        .{ .scale = true },
    };
    var transcript = ImageTranscript{ .steps = &steps };
    var image = try loadImage(&transcript, std.testing.allocator, "wallpaper.png");
    defer image.deinit(std.testing.allocator);
    var pixels = try coverImage(&transcript, std.testing.allocator, &image, 8, 6);
    defer pixels.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 32), pixels.pitch);
    try std.testing.expectEqual(@as(u32, 0xff102030), pixels.pixels[47]);
    try transcript.done();
}

test "image file failures close exactly once before decode" {
    const histories = [_]struct { expected: anyerror, steps: []const ImageStep }{
        .{ .expected = error.ImageOpenFailed, .steps = &.{.{ .open = false }} },
        .{ .expected = error.ImageStatFailed, .steps = &.{ .{ .open = true }, .{ .stat = null }, .close } },
        .{
            .expected = error.ImageNotRegularFile,
            .steps = &.{ .{ .open = true }, .{ .stat = .{ .kind = .directory, .size = 24 } }, .close },
        },
        .{
            .expected = error.ImageFileTooLarge,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = image_file_capacity + 1 } },
                .close,
            },
        },
        .{
            .expected = error.ImageReadIncomplete,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .short },
                .close,
            },
        },
        .{
            .expected = error.ImageReadFailed,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .fail },
                .close,
            },
        },
        .{
            .expected = error.ImageDecodeFailed,
            .steps = &.{
                .{ .open = true },
                .{ .stat = .{ .kind = .file, .size = 24 } },
                .{ .read = .complete },
                .close,
                .{ .decode = .failed },
            },
        },
    };
    for (histories) |history| {
        var transcript = ImageTranscript{ .steps = history.steps };
        try std.testing.expectError(
            history.expected,
            loadImage(&transcript, std.testing.allocator, "wallpaper.png"),
        );
        try transcript.done();
    }
}

test "image path dimensions crop and allocation endpoints are exact" {
    var transcript = ImageTranscript{ .steps = &.{} };
    try std.testing.expectError(error.ImagePathEmpty, loadImage(&transcript, std.testing.allocator, ""));
    var path: [image_path_capacity + 1]u8 = @splat('a');
    try std.testing.expectError(error.ImagePathTooLong, loadImage(&transcript, std.testing.allocator, &path));
    const valid_path_steps = [_]ImageStep{.{ .open = false }};
    transcript = .{ .steps = &valid_path_steps };
    try std.testing.expectError(
        error.ImageOpenFailed,
        loadImage(&transcript, std.testing.allocator, path[0..image_path_capacity]),
    );
    try transcript.done();
    transcript = .{ .steps = &.{} };
    path[0] = 0;
    try std.testing.expectError(error.ImagePathInvalid, loadImage(&transcript, std.testing.allocator, path[0..1]));
    path[0] = 0xff;
    try std.testing.expectError(error.ImagePathInvalid, loadImage(&transcript, std.testing.allocator, path[0..1]));
    try std.testing.expectError(error.ImageDimensionsZero, coverCrop(0, 1, 1, 1));
    try std.testing.expectError(error.ImageDimensionsTooLarge, coverCrop(image_side_capacity + 1, 1, 1, 1));
    try std.testing.expectError(error.ImagePixelsTooMany, coverCrop(8192, 8193, 1, 1));

    try std.testing.expectEqual(Crop{ .x = 2, .y = 0, .width = 5, .height = 5 }, try coverCrop(9, 5, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 2, .y = 0, .width = 5, .height = 5 }, try coverCrop(10, 5, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 2, .width = 5, .height = 5 }, try coverCrop(5, 9, 1, 1));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 7, .height = 3 }, try coverCrop(7, 3, 14, 6));
    try std.testing.expectEqual(Crop{ .x = 0, .y = 0, .width = 1, .height = 1 }, try coverCrop(1, 1, 3, 2));
    try std.testing.expectEqual(
        Crop{ .x = 0, .y = 0, .width = 8192, .height = 8192 },
        try coverCrop(8192, 8192, 1, 1),
    );

    const steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = image_file_capacity } },
        .close,
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    transcript = .{ .steps = &steps };
    try std.testing.expectError(error.OutOfMemory, loadImage(&transcript, failing.allocator(), "wallpaper.png"));
    try transcript.done();
}

test "decode dimension format convert and scale failures publish no pixels" {
    const failures = [_]struct { expected: anyerror, result: ImageStep }{
        .{ .expected = error.ImageDecodeFailed, .result = .{ .decode = .failed } },
        .{ .expected = error.ImageDimensionsTooLarge, .result = .{ .decode = .dimensions_failed } },
        .{ .expected = error.ImageFormatInvalid, .result = .{ .decode = .format_failed } },
        .{ .expected = error.ImageConvertFailed, .result = .{ .decode = .convert_failed } },
    };
    for (failures) |failure| {
        const steps = [_]ImageStep{
            .{ .open = true },
            .{ .stat = .{ .kind = .file, .size = 24 } },
            .{ .read = .complete },
            .close,
            failure.result,
        };
        var failed = ImageTranscript{ .steps = &steps };
        try std.testing.expectError(
            failure.expected,
            loadImage(&failed, std.testing.allocator, "wallpaper.png"),
        );
        try failed.done();
    }

    const decode_steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 3, .height = 3 } } },
    };
    var transcript = ImageTranscript{ .steps = &decode_steps };
    try std.testing.expectError(
        error.ImageDimensionsChanged,
        loadImage(&transcript, std.testing.allocator, "wallpaper.png"),
    );
    try transcript.done();

    var source_pixels = [_]u32{0xff000000} ** 12;
    const image = Image{ .width = 4, .height = 3, .pitch = 16, .pixels = &source_pixels };
    const scale_steps = [_]ImageStep{.{ .scale = false }};
    transcript = .{ .steps = &scale_steps };
    try std.testing.expectError(
        error.ImageScaleFailed,
        coverImage(&transcript, std.testing.allocator, &image, 8, 6),
    );
    try transcript.done();

    const allocation_steps = [_]ImageStep{
        .{ .open = true },
        .{ .stat = .{ .kind = .file, .size = 24 } },
        .{ .read = .complete },
        .close,
        .{ .decode = .{ .image = .{ .width = 4, .height = 3 } } },
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    transcript = .{ .steps = &allocation_steps };
    try std.testing.expectError(
        error.OutOfMemory,
        loadImage(&transcript, failing.allocator(), "wallpaper.png"),
    );
    try transcript.done();

    failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    transcript = .{ .steps = &.{} };
    try std.testing.expectError(
        error.OutOfMemory,
        coverImage(&transcript, failing.allocator(), &image, 8, 6),
    );
    try transcript.done();
}

test "Smith crop arithmetic and PNG headers remain bounded" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzImage, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzImage({}, &empty);
}

fn expectMonitorError(expected: anyerror, json: []const u8) !void {
    try std.testing.expectError(expected, parseMonitors(std.testing.allocator, json));
}

fn pngHeader(bytes: []u8, width: u32, height: u32) void {
    @memset(bytes, 0);
    @memcpy(bytes[0..8], "\x89PNG\r\n\x1a\n");
    @memcpy(bytes[12..16], "IHDR");
    std.mem.writeInt(u32, bytes[16..20], width, .big);
    std.mem.writeInt(u32, bytes[20..24], height, .big);
}

fn fuzzImage(_: void, smith: *std.testing.Smith) !void {
    const source_width = smith.value(u32);
    const source_height = smith.value(u32);
    const width = smith.value(u32);
    const height = smith.value(u32);
    if (coverCrop(source_width, source_height, width, height)) |crop| {
        try std.testing.expect(crop.width > 0 and crop.height > 0);
        try std.testing.expect(crop.x + crop.width <= source_width);
        try std.testing.expect(crop.y + crop.height <= source_height);
    } else |_| {}
    var bytes: [64]u8 = undefined;
    const slice = bytes[0..smith.slice(&bytes)];
    if (inspectPng(slice)) |dimensions| {
        try std.testing.expect(dimensions.width <= image_side_capacity);
        try std.testing.expect(dimensions.height <= image_side_capacity);
    } else |_| {}
}

fn fuzzMonitors(_: void, smith: *std.testing.Smith) !void {
    var arbitrary: [2048]u8 = undefined;
    if (parseMonitors(std.testing.allocator, arbitrary[0..smith.slice(&arbitrary)]) catch null) |snapshot| {
        try assertSnapshot(&snapshot);
    }

    var json: [8192]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&json);
    try writer.writeAll("[");
    const count = smith.valueRangeAtMost(u8, 1, monitor_capacity);
    for (0..count) |index| {
        if (index != 0) try writer.writeAll(",");
        const width = smith.valueRangeAtMost(u16, 1, 4096);
        const height = smith.valueRangeAtMost(u16, 1, 2160);
        try writer.print(
            "{{\"name\":\"M{d:0>2}\",\"width\":{d},\"height\":{d},\"x\":{d},\"y\":0," ++
                "\"scale\":1.25,\"transform\":{d},\"disabled\":false,\"future\":null}}",
            .{ index, width, height, smith.valueRangeAtMost(i16, -4096, 4096), index % 8 },
        );
    }
    try writer.writeAll("]");
    const snapshot = try parseMonitors(std.testing.allocator, writer.buffered());
    try std.testing.expectEqual(count, snapshot.count);
    try assertSnapshot(&snapshot);
}

fn assertSnapshot(snapshot: *const Snapshot) !void {
    try std.testing.expect(snapshot.count > 0);
    try std.testing.expect(snapshot.count <= monitor_capacity);
    var pixels: u64 = 0;
    for (snapshot.slice(), 0..) |monitor, index| {
        try std.testing.expect(monitor.name().len > 0);
        try std.testing.expect(monitor.name().len <= monitor_name_capacity);
        try std.testing.expect(monitor.width > 0 and monitor.height > 0);
        pixels += @as(u64, monitor.width) * monitor.height;
        if (index > 0) try std.testing.expect(std.mem.order(
            u8,
            snapshot.monitors[index - 1].name(),
            monitor.name(),
        ) == .lt);
    }
    try std.testing.expect(pixels <= round_pixel_capacity);
}

fn fuzzEvents(_: void, smith: *std.testing.Smith) !void {
    var input: [event_read_capacity]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    var lines: EventLines = .{};
    var consumed: usize = 0;
    var feeds: usize = 0;
    while (consumed < bytes.len and feeds <= bytes.len) : (feeds += 1) {
        const feed = lines.feed(bytes[consumed..]);
        try std.testing.expect(feed.count <= event_batch_capacity);
        try std.testing.expect(feed.consumed <= bytes.len - consumed);
        if (feed.consumed == 0) break;
        consumed += feed.consumed;
    }
    try std.testing.expect(consumed <= bytes.len);
    try std.testing.expect(lines.len <= event_line_capacity);

    const choices = [_][]const u8{
        "monitoradded>>A\n",
        "workspace>>1\n",
        "bad\n",
        "configreloaded>>\n",
    };
    const tags = [_]Event{ .refresh, .ignore, .malformed, .refresh };
    var history: [event_batch_capacity * 20]u8 = undefined;
    var expected: [event_batch_capacity]Event = undefined;
    var actual: [event_batch_capacity]Event = undefined;
    var history_len: usize = 0;
    const count = smith.valueRangeAtMost(u8, 1, event_batch_capacity);
    for (0..count) |index| {
        const choice = smith.valueRangeLessThan(u8, 0, choices.len);
        @memcpy(history[history_len..][0..choices[choice].len], choices[choice]);
        history_len += choices[choice].len;
        expected[index] = tags[choice];
    }
    lines = .{};
    consumed = 0;
    var emitted: usize = 0;
    while (consumed < history_len) {
        const remaining = history_len - consumed;
        const chunk = smith.valueRangeAtMost(u16, 1, @intCast(remaining));
        const feed = lines.feed(history[consumed .. consumed + chunk]);
        @memcpy(actual[emitted..][0..feed.count], feed.slice());
        emitted += feed.count;
        consumed += feed.consumed;
    }
    try std.testing.expectEqual(@as(usize, count), emitted);
    try std.testing.expectEqualSlices(Event, expected[0..count], actual[0..emitted]);
    try std.testing.expectEqual(@as(u16, 0), lines.len);
}
