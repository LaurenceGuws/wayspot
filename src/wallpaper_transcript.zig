//! Strict operation histories for complete wallpaper publication rounds.

const std = @import("std");
const wallpaper = @import("wallpaper.zig");

const operation_capacity = 4096;

const Operation = union(enum) {
    connect,
    output: u8,
    outputs_complete,
    reserve: wallpaper.SurfaceHandle,
    create_surface: wallpaper.SurfaceHandle,
    create_empty_region: wallpaper.SurfaceHandle,
    set_input_region: wallpaper.SurfaceHandle,
    destroy_region: wallpaper.SurfaceHandle,
    create_layer: wallpaper.SurfaceHandle,
    create_viewport: wallpaper.SurfaceHandle,
    initial_commit: wallpaper.SurfaceHandle,
    configure: wallpaper.SurfaceHandle,
    create_shm: wallpaper.SurfaceHandle,
    create_buffer: wallpaper.SurfaceHandle,
    validate,
    map: wallpaper.SurfaceHandle,
    unmap: wallpaper.SurfaceHandle,
    flush: Flush,
    poll: Poll,
    finish,
    release: wallpaper.SurfaceHandle,
    discard: wallpaper.SurfaceHandle,
    disconnect_loss,
};

const Flush = enum { success, again, interrupted, failed };
const Poll = enum { writable, interrupted, timeout, stopped, failed };
const Outputs = enum { exact, missing, duplicate };
const State = enum { vacant, prepared, queued, published, retiring };

const Resource = struct {
    generation: u32 = 0,
    state: State = .vacant,
};

const Transcript = struct {
    id: u8 = 0,
    operations: [operation_capacity]Operation = undefined,
    count: u16 = 0,
    fail_at: ?u16 = null,
    flushes: []const Flush = &.{.success},
    polls: []const Poll = &.{},
    output_result: Outputs = .exact,
    flush_index: u8 = 0,
    poll_index: u8 = 0,
    connected: bool = false,
    outputs: u8 = 0,
    output_snapshot: ?wallpaper.Snapshot = null,
    resources: [wallpaper.surface_resource_capacity]Resource = @splat(.{}),
    next_generation: u32 = 1,
    stop_on_flush: bool = false,
    stop_on_release: bool = false,
    release_failure: ?u8 = null,
    release_count: u8 = 0,

    pub fn openOutputs(transcript: *Transcript, snapshot: *const wallpaper.Snapshot) !void {
        if (transcript.connected) {
            if (transcript.output_snapshot == null or !transcript.output_snapshot.?.eql(snapshot)) {
                return error.WaylandOutputChanged;
            }
            return;
        }
        try transcript.step(.connect);
        transcript.connected = true;
        errdefer transcript.disconnectAfterDisplayLoss();
        for (snapshot.slice(), 0..) |_, index| try transcript.step(.{ .output = @intCast(index) });
        switch (transcript.output_result) {
            .exact => {},
            .missing => return error.WaylandOutputMissing,
            .duplicate => return error.WaylandOutputDuplicate,
        }
        try transcript.step(.outputs_complete);
        transcript.outputs = snapshot.count;
        transcript.output_snapshot = snapshot.*;
    }

    pub fn scale(
        _: *Transcript,
        image: *const wallpaper.Image,
        _: wallpaper.Crop,
        width: u32,
        height: u32,
        pixels: []u32,
    ) !void {
        std.debug.assert(image.pixels.len > 0);
        std.debug.assert(pixels.len == @as(usize, width) * height);
        @memset(pixels, image.pixels[0]);
    }

    pub fn prepare(
        transcript: *Transcript,
        monitor_index: u8,
        monitor: *const wallpaper.Monitor,
        _: *const wallpaper.Image,
    ) !wallpaper.SurfaceHandle {
        const snapshot = transcript.output_snapshot orelse return error.OutputMissing;
        if (monitor_index >= snapshot.count) return error.OutputMissing;
        if (!snapshot.monitors[monitor_index].eql(monitor)) return error.WaylandOutputChanged;
        if (transcript.next_generation == std.math.maxInt(u32)) return error.SurfaceGenerationExhausted;
        const index = for (&transcript.resources, 0..) |resource, value| {
            if (resource.state == .vacant) break value;
        } else return error.SurfaceCapacityExceeded;
        const handle = wallpaper.SurfaceHandle{
            .index = @intCast(index),
            .generation = transcript.next_generation,
        };
        transcript.next_generation += 1;
        transcript.resources[index] = .{ .generation = handle.generation, .state = .prepared };
        errdefer transcript.discardPrepared(handle);
        const operations = [_]Operation{
            .{ .reserve = handle },
            .{ .create_surface = handle },
            .{ .create_empty_region = handle },
            .{ .set_input_region = handle },
            .{ .destroy_region = handle },
            .{ .create_layer = handle },
            .{ .create_viewport = handle },
            .{ .initial_commit = handle },
            .{ .configure = handle },
            .{ .create_shm = handle },
            .{ .create_buffer = handle },
        };
        for (operations) |operation| try transcript.step(operation);
        return handle;
    }

    pub fn validatePublication(
        transcript: *Transcript,
        old: []const wallpaper.SurfaceHandle,
        next: []const wallpaper.SurfaceHandle,
    ) !void {
        if (old.len > wallpaper.monitor_capacity or next.len > wallpaper.monitor_capacity or
            old.len + next.len == 0)
        {
            return error.RoundHandleCountInvalid;
        }
        for (old, 0..) |handle, index| {
            if ((try transcript.checkedResource(handle)).state != .published) return error.SurfaceStateInvalid;
            if (contains(old[0..index], handle) or contains(next, handle)) return error.SurfaceHandleDuplicate;
        }
        for (next, 0..) |handle, index| {
            if ((try transcript.checkedResource(handle)).state != .prepared) return error.SurfaceStateInvalid;
            if (contains(next[0..index], handle)) return error.SurfaceHandleDuplicate;
        }
        try transcript.step(.validate);
    }

    pub fn queueMap(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        const resource = transcript.checkedResource(handle) catch unreachable;
        std.debug.assert(resource.state == .prepared);
        transcript.record(.{ .map = handle });
        resource.state = .queued;
    }

    pub fn queueUnmap(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        const resource = transcript.checkedResource(handle) catch unreachable;
        std.debug.assert(resource.state == .published);
        transcript.record(.{ .unmap = handle });
        resource.state = .retiring;
    }

    pub fn flushPublication(transcript: *Transcript, stop: anytype) !void {
        const stopped = transcript.stop_on_flush or if (@TypeOf(stop) == bool) stop else false;
        var flush_count: u8 = 0;
        var poll_count: u8 = 0;
        while (flush_count < wallpaper.publication_flush_capacity) {
            flush_count += 1;
            const flush = transcript.nextFlush();
            transcript.record(.{ .flush = flush });
            switch (flush) {
                .success => return,
                .interrupted => continue,
                .failed => return error.WaylandFlushFailed,
                .again => {},
            }
            while (poll_count < wallpaper.publication_poll_capacity) {
                poll_count += 1;
                const poll = if (stopped) .stopped else transcript.nextPoll();
                transcript.record(.{ .poll = poll });
                switch (poll) {
                    .writable => break,
                    .interrupted => continue,
                    .timeout => return error.WaylandFlushTimeout,
                    .stopped => return error.WaylandFlushStopped,
                    .failed => return error.WaylandFlushFailed,
                }
            } else return error.WaylandFlushAttemptsExceeded;
        }
        return error.WaylandFlushAttemptsExceeded;
    }

    pub fn finishPublication(
        transcript: *Transcript,
        old: []const wallpaper.SurfaceHandle,
        next: []const wallpaper.SurfaceHandle,
    ) void {
        for (next) |handle| (transcript.checkedResource(handle) catch unreachable).state = .published;
        for (old) |handle| {
            std.debug.assert((transcript.checkedResource(handle) catch unreachable).state == .retiring);
        }
        transcript.record(.finish);
    }

    pub fn releaseRetired(transcript: *Transcript, handle: wallpaper.SurfaceHandle, _: anytype) !void {
        const resource = try transcript.checkedResource(handle);
        if (resource.state != .retiring) return error.SurfaceStateInvalid;
        if (transcript.stop_on_release) return error.WaylandFlushStopped;
        defer transcript.release_count += 1;
        if (transcript.release_failure == transcript.release_count) return error.SurfaceReleaseMissing;
        try transcript.step(.{ .release = handle });
        resource.* = .{};
    }

    pub fn discardPrepared(transcript: *Transcript, handle: wallpaper.SurfaceHandle) void {
        const resource = transcript.checkedResource(handle) catch unreachable;
        std.debug.assert(resource.state == .prepared);
        transcript.record(.{ .discard = handle });
        resource.* = .{};
    }

    pub fn disconnectAfterDisplayLoss(transcript: *Transcript) void {
        if (!transcript.connected) return;
        transcript.record(.disconnect_loss);
        transcript.connected = false;
        transcript.outputs = 0;
        transcript.output_snapshot = null;
        transcript.resources = @splat(.{});
    }

    fn checkedResource(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !*Resource {
        if (handle.index >= wallpaper.surface_resource_capacity) return error.SurfaceHandleInvalid;
        const resource = &transcript.resources[handle.index];
        if (resource.state == .vacant or resource.generation != handle.generation) {
            return error.SurfaceHandleInvalid;
        }
        return resource;
    }

    fn step(transcript: *Transcript, operation: Operation) !void {
        transcript.record(operation);
        if (transcript.fail_at == transcript.count - 1) return error.SimulatedFailure;
    }

    fn record(transcript: *Transcript, operation: Operation) void {
        std.debug.assert(transcript.count < operation_capacity);
        transcript.operations[transcript.count] = operation;
        transcript.count += 1;
    }

    fn nextFlush(transcript: *Transcript) Flush {
        if (transcript.flush_index == transcript.flushes.len) return .success;
        defer transcript.flush_index += 1;
        return transcript.flushes[transcript.flush_index];
    }

    fn nextPoll(transcript: *Transcript) Poll {
        if (transcript.poll_index == transcript.polls.len) return .timeout;
        defer transcript.poll_index += 1;
        return transcript.polls[transcript.poll_index];
    }
};

const ResidentOperation = union(enum) {
    now: u64,
    wait: struct { display: u8, stop_fd: u8, event_fd: u8, timeout: ?u64 },
    reconnect,
    request,
    read_event,
    create: u8,
    destroy: u8,
    rotate_receive,
    rotate_reply: bool,
    image_open,
    image_close,
};

const Resident = struct {
    operations: [2048]ResidentOperation = undefined,
    count: u16 = 0,
    waits: []const wallpaper.Ready,
    replies: []const []const u8,
    wait_index: u8 = 0,
    reply_index: u8 = 0,
    reply_done: bool = false,
    request_offset: u8 = 0,
    reply_offset: u16 = 0,
    request_chunk: u8 = 10,
    reply_chunk: u16 = std.math.maxInt(u16),
    block_write: bool = false,
    block_read: bool = false,
    reset_after_reply: bool = false,
    socket_waits: u8 = 0,
    request_closes: u8 = 0,
    request_failures: u8 = 0,
    reconnect_failures: u8 = 0,
    clock: u64 = 0,
    clock_steps: []const u64 = &.{},
    clock_step_index: u16 = 0,
    next_display: u8 = 2,
    stop_identity: u8 = 7,
    event_identity: u8 = 9,
    candidate_outputs: []const Outputs = &.{.exact},
    candidate_index: u8 = 0,
    output_changes: []const bool = &.{false},
    output_index: u8 = 0,
    event_reads: []const []const u8 = &.{"workspace>>1\n"},
    event_read_index: u8 = 0,
    event_losses: u8 = 0,
    wayland_changes: []const bool = &.{false},
    wayland_change_index: u8 = 0,
    stop_release_id: ?u8 = null,
    retirement_fail_offset: ?u8 = null,
    image_failures: u8 = 0,

    pub fn now(resident: *Resident) u64 {
        resident.record(.{ .now = resident.clock });
        return resident.clock;
    }

    pub fn receiveRotation(resident: *Resident) !bool {
        resident.record(.rotate_receive);
        return true;
    }

    pub fn replyRotation(resident: *Resident, success: bool) void {
        resident.record(.{ .rotate_reply = success });
    }

    pub fn open(resident: *Resident, _: []const u8) !void {
        resident.record(.image_open);
    }

    pub fn stat(_: *Resident) !struct { kind: std.Io.File.Kind, size: u64 } {
        return .{ .kind = .file, .size = 24 };
    }

    pub fn read(_: *Resident, bytes: []u8) !usize {
        const png = "\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\x00\x02\x00\x00\x00\x01";
        @memcpy(bytes, png);
        return bytes.len;
    }

    pub fn close(resident: *Resident) void {
        resident.record(.image_close);
    }

    pub fn decode(
        resident: *Resident,
        allocator: std.mem.Allocator,
        _: wallpaper.ImageFormat,
        _: []const u8,
    ) !wallpaper.Image {
        if (resident.image_failures > 0) {
            resident.image_failures -= 1;
            return error.ImageDecodeFailed;
        }
        const pixels = try allocator.alloc(u32, 2);
        @memset(pixels, 0xff203040);
        return .{ .width = 2, .height = 1, .pitch = 8, .pixels = pixels };
    }

    pub fn wait(
        resident: *Resident,
        native: *Transcript,
        stop_fd: u8,
        event_fd: u8,
        timeout: ?u64,
    ) !wallpaper.Ready {
        std.debug.assert(stop_fd == resident.stop_identity);
        std.debug.assert(event_fd == 0 or event_fd == resident.event_identity);
        resident.record(.{ .wait = .{
            .display = native.id,
            .stop_fd = stop_fd,
            .event_fd = event_fd,
            .timeout = timeout,
        } });
        if (timeout) |milliseconds| if (milliseconds != 0) {
            const advance = if (resident.clock_step_index < resident.clock_steps.len) step: {
                defer resident.clock_step_index += 1;
                break :step resident.clock_steps[resident.clock_step_index];
            } else milliseconds;
            resident.clock += advance;
        };
        if (resident.wait_index == resident.waits.len) return .{};
        defer resident.wait_index += 1;
        return resident.waits[resident.wait_index];
    }

    pub fn connectRequest(
        resident: *Resident,
        _: []const u8,
        stop_fd: u8,
        event_fd: u8,
        _: u64,
    ) !u8 {
        std.debug.assert(stop_fd == resident.stop_identity);
        std.debug.assert(event_fd == resident.event_identity);
        resident.record(.request);
        if (resident.request_failures > 0) {
            resident.request_failures -= 1;
            return error.ConnectionTimedOut;
        }
        if (resident.reply_index == resident.replies.len) return error.ConnectionTimedOut;
        resident.reply_done = false;
        return 11;
    }

    pub fn writeRequest(resident: *Resident, fd: u8, bytes: []const u8) anyerror!usize {
        std.debug.assert(fd == 11);
        if (resident.block_write) {
            resident.block_write = false;
            return error.WouldBlock;
        }
        const count = @min(bytes.len, resident.request_chunk);
        try std.testing.expectEqualStrings(
            "j/monitors"[resident.request_offset..][0..count],
            bytes[0..count],
        );
        resident.request_offset += @intCast(count);
        return count;
    }

    pub fn readReply(resident: *Resident, fd: u8, bytes: []u8) anyerror!usize {
        std.debug.assert(fd == 11);
        if (resident.reply_done) {
            resident.reply_index += 1;
            if (resident.reset_after_reply) return error.ConnectionResetByPeer;
            return 0;
        }
        const reply = resident.replies[resident.reply_index];
        if (resident.block_read) {
            resident.block_read = false;
            return error.WouldBlock;
        }
        const count = @min(bytes.len, resident.reply_chunk, reply.len - resident.reply_offset);
        @memcpy(bytes[0..count], reply[resident.reply_offset..][0..count]);
        resident.reply_offset += @intCast(count);
        resident.reply_done = resident.reply_offset == reply.len;
        return count;
    }

    pub fn closeRequest(resident: *Resident, fd: u8) void {
        std.debug.assert(fd == 11);
        resident.request_offset = 0;
        resident.reply_offset = 0;
        resident.request_closes += 1;
    }

    pub fn waitSocket(resident: *Resident, _: u8, _: u8, _: u8, _: bool, _: u64) !void {
        resident.socket_waits += 1;
    }

    pub fn readEvent(resident: *Resident, event_fd: u8, bytes: []u8) anyerror!usize {
        std.debug.assert(event_fd == resident.event_identity);
        resident.record(.read_event);
        if (resident.event_losses > 0) {
            resident.event_losses -= 1;
            return error.EventSocketLost;
        }
        if (resident.event_read_index == resident.event_reads.len) return error.WouldBlock;
        const source = resident.event_reads[resident.event_read_index];
        resident.event_read_index += 1;
        @memcpy(bytes[0..source.len], source);
        return source.len;
    }

    pub fn reconnectEvent(resident: *Resident, event_fd: *u8, _: []const u8, stop_fd: u8, _: u64) !void {
        std.debug.assert(stop_fd == resident.stop_identity);
        std.debug.assert(event_fd.* == 0);
        resident.record(.reconnect);
        if (resident.reconnect_failures > 0) {
            resident.reconnect_failures -= 1;
            return error.ConnectionRefused;
        }
        event_fd.* = resident.event_identity;
    }

    pub fn closeEvent(_: *Resident, event_fd: *u8) void {
        event_fd.* = 0;
    }

    pub fn drainWayland(resident: *Resident, _: *Transcript) !bool {
        if (resident.wayland_change_index == resident.wayland_changes.len) return false;
        defer resident.wayland_change_index += 1;
        return resident.wayland_changes[resident.wayland_change_index];
    }

    pub fn outputsChanged(resident: *Resident, _: *Transcript) bool {
        const changed = resident.output_changes[
            @min(
                resident.output_index,
                resident.output_changes.len - 1,
            )
        ];
        resident.output_index += 1;
        return changed;
    }

    pub fn createNative(resident: *Resident, allocator: std.mem.Allocator) !*Transcript {
        const native = try allocator.create(Transcript);
        const output = resident.candidate_outputs[
            @min(
                resident.candidate_index,
                resident.candidate_outputs.len - 1,
            )
        ];
        resident.candidate_index += 1;
        native.* = .{ .id = resident.next_display, .output_result = output };
        if (resident.stop_release_id == native.id) native.stop_on_release = true;
        if (native.id == 2) if (resident.retirement_fail_offset) |offset| {
            native.release_failure = offset;
        };
        resident.next_display += 1;
        resident.record(.{ .create = native.id });
        return native;
    }

    pub fn destroyNative(resident: *Resident, allocator: std.mem.Allocator, native: *Transcript) void {
        const id = native.id;
        native.disconnectAfterDisplayLoss();
        allocator.destroy(native);
        resident.record(.{ .destroy = id });
    }

    fn record(resident: *Resident, operation: ResidentOperation) void {
        std.debug.assert(resident.count < resident.operations.len);
        resident.operations[resident.count] = operation;
        resident.count += 1;
    }
};

test "two monitors prepare then publish as one ordered batch" {
    var transcript: Transcript = .{};
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var next = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    var current: wallpaper.Round = .{};
    try wallpaper.publishRound(&transcript, &current, &next, false);
    try std.testing.expectEqual(@as(u8, 2), current.monitors.count);
    try std.testing.expectEqual(@as(u8, 0), next.monitors.count);
    const tail = transcript.operations[transcript.count - 5 .. transcript.count];
    try std.testing.expectEqual(Operation.validate, tail[0]);
    try std.testing.expectEqual(Operation{ .map = current.handles[0] }, tail[1]);
    try std.testing.expectEqual(Operation{ .map = current.handles[1] }, tail[2]);
    try std.testing.expectEqual(Operation{ .flush = .success }, tail[3]);
    try std.testing.expectEqual(Operation.finish, tail[4]);
}

test "same snapshot replacement maps new then unmaps old and releases reverse" {
    var transcript: Transcript = .{};
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current: wallpaper.Round = .{};
    var first = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    try wallpaper.publishRound(&transcript, &current, &first, false);
    var next = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    const start = transcript.count;
    const old = current;
    try wallpaper.publishRound(&transcript, &current, &next, false);
    const operations = transcript.operations[start..transcript.count];
    try std.testing.expectEqual(Operation.validate, operations[0]);
    try std.testing.expectEqual(Operation{ .map = current.handles[0] }, operations[1]);
    try std.testing.expectEqual(Operation{ .map = current.handles[1] }, operations[2]);
    try std.testing.expectEqual(Operation{ .unmap = old.handles[1] }, operations[3]);
    try std.testing.expectEqual(Operation{ .unmap = old.handles[0] }, operations[4]);
    try std.testing.expectEqual(Operation{ .flush = .success }, operations[5]);
    try std.testing.expectEqual(Operation.finish, operations[6]);
    try std.testing.expectEqual(Operation{ .release = old.handles[1] }, operations[7]);
    try std.testing.expectEqual(Operation{ .release = old.handles[0] }, operations[8]);
}

test "healthy stop unmaps one batch and releases current in reverse" {
    var transcript: Transcript = .{};
    var current: wallpaper.Round = .{};
    var next = try preparedRound(&transcript);
    try wallpaper.publishRound(&transcript, &current, &next, false);
    const old = current;
    const start = transcript.count;
    try wallpaper.releaseRound(&transcript, &current, false);
    const operations = transcript.operations[start..transcript.count];
    try std.testing.expectEqual(Operation.validate, operations[0]);
    try std.testing.expectEqual(Operation{ .unmap = old.handles[1] }, operations[1]);
    try std.testing.expectEqual(Operation{ .unmap = old.handles[0] }, operations[2]);
    try std.testing.expectEqual(Operation{ .flush = .success }, operations[3]);
    try std.testing.expectEqual(Operation.finish, operations[4]);
    try std.testing.expectEqual(Operation{ .release = old.handles[1] }, operations[5]);
    try std.testing.expectEqual(Operation{ .release = old.handles[0] }, operations[6]);
    try std.testing.expectEqual(@as(u8, 0), current.monitors.count);
}

test "reconciliation swaps only Wayland ownership and preserves resident fds" {
    const first_snapshot = snapshotValue(1);
    const second_json =
        \\[{"name":"M0","width":2,"height":1,"x":1,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{ .waits = &.{}, .replies = &.{second_json} };
    const old = try std.testing.allocator.create(Transcript);
    old.* = .{ .id = 1 };
    try old.openOutputs(&first_snapshot);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var first = try wallpaper.prepareRound(old, std.testing.allocator, &first_snapshot, &image);
    var published: wallpaper.Round = .{};
    try wallpaper.publishRound(old, &published, &first, false);
    var current = wallpaper.Current(Transcript){ .native = old, .round = published };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var work: wallpaper.Work = .refresh;
    var paths = pathsValue();
    _ = try wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    );
    try std.testing.expectEqual(@as(u8, 2), current.native.id);
    try std.testing.expectEqual(resident.event_identity, event_fd);
    try std.testing.expectEqual(wallpaper.Work.idle, work);
    var saw_old_destroy = false;
    for (resident.operations[0..resident.count]) |operation| switch (operation) {
        .wait => |wait| {
            try std.testing.expectEqual(resident.stop_identity, wait.stop_fd);
            try std.testing.expectEqual(resident.event_identity, wait.event_fd);
        },
        .destroy => |id| if (id == 1) {
            saw_old_destroy = true;
        },
        else => {},
    };
    try std.testing.expect(saw_old_destroy);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "successful event reconnect survives transient request retries and preserves refresh" {
    var resident = Resident{
        .waits = &.{.{ .wayland = true }},
        .replies = &.{},
        .request_failures = wallpaper.reconcile_attempt_capacity,
        .wayland_changes = &.{true},
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var lines: wallpaper.EventLines = .{};
    var event_fd: u8 = 0;
    var work: wallpaper.Work = .reconnect;
    var paths = pathsValue();
    try std.testing.expectError(error.ConnectionTimedOut, wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    ));
    var reconnects: u8 = 0;
    var requests: u8 = 0;
    for (resident.operations[0..resident.count]) |operation| switch (operation) {
        .reconnect => reconnects += 1,
        .request => requests += 1,
        else => {},
    };
    try std.testing.expectEqual(@as(u8, 1), reconnects);
    try std.testing.expectEqual(wallpaper.reconcile_attempt_capacity, requests);
    try std.testing.expectEqual(resident.event_identity, event_fd);
    try std.testing.expectEqual(wallpaper.Work.refresh, work);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "successful event reconnect is reused after transient candidate mismatch" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{},
        .replies = &.{ reply, reply },
        .candidate_outputs = &.{ .missing, .exact },
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var lines: wallpaper.EventLines = .{};
    var event_fd: u8 = 0;
    var work: wallpaper.Work = .reconnect;
    var paths = pathsValue();
    _ = try wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    );
    var reconnects: u8 = 0;
    for (resident.operations[0..resident.count]) |operation| {
        if (operation == .reconnect) reconnects += 1;
    }
    try std.testing.expectEqual(@as(u8, 1), reconnects);
    try std.testing.expectEqual(@as(u8, 2), resident.candidate_index);
    try std.testing.expectEqual(resident.event_identity, event_fd);
    try std.testing.expectEqual(wallpaper.Work.idle, work);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "failed event reconnect keeps absent ownership and reconnect work" {
    var resident = Resident{
        .waits = &.{},
        .replies = &.{},
        .reconnect_failures = wallpaper.reconcile_attempt_capacity,
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var lines: wallpaper.EventLines = .{};
    var event_fd: u8 = 0;
    var work: wallpaper.Work = .reconnect;
    var paths = pathsValue();
    try std.testing.expectError(error.ConnectionRefused, wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    ));
    var reconnects: u8 = 0;
    for (resident.operations[0..resident.count]) |operation| {
        if (operation == .reconnect) reconnects += 1;
    }
    try std.testing.expectEqual(wallpaper.reconcile_attempt_capacity, reconnects);
    try std.testing.expectEqual(@as(u8, 0), event_fd);
    try std.testing.expectEqual(wallpaper.Work.reconnect, work);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "pre-drain event loss reconnects before requesting a snapshot" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{.{ .event = true }},
        .replies = &.{reply},
        .event_reads = &.{""},
        .candidate_outputs = &.{.exact},
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var work: wallpaper.Work = .refresh;
    var paths = pathsValue();
    _ = try wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    );
    var reconnects: u8 = 0;
    var requests: u8 = 0;
    for (resident.operations[0..resident.count]) |operation| switch (operation) {
        .reconnect => reconnects += 1,
        .request => requests += 1,
        else => {},
    };
    try std.testing.expectEqual(@as(u8, 1), reconnects);
    try std.testing.expectEqual(@as(u8, 1), requests);
    try std.testing.expectEqual(resident.event_identity, event_fd);
    try std.testing.expectEqual(wallpaper.Work.idle, work);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "both zero-time checks discard stale snapshots before candidate allocation" {
    const first_snapshot = snapshotValue(1);
    const stale_json =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const fresh_json =
        \\[{"name":"M0","width":2,"height":1,"x":1,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const races = [_]struct {
        waits: [5]wallpaper.Ready,
        event_reads: []const []const u8,
        wayland_changes: []const bool,
    }{
        .{
            .waits = .{ .{ .event = true }, .{ .wayland = true }, .{}, .{}, .{} },
            .event_reads = &.{"monitoradded>>M0\n"},
            .wayland_changes = &.{true},
        },
        .{
            .waits = .{ .{ .wayland = true }, .{ .event = true }, .{}, .{}, .{} },
            .event_reads = &.{"monitoradded>>M0\n"},
            .wayland_changes = &.{true},
        },
    };
    for (races) |race| {
        var resident = Resident{
            .waits = &race.waits,
            .replies = &.{ stale_json, fresh_json },
            .event_reads = race.event_reads,
            .wayland_changes = race.wayland_changes,
        };
        const native = try std.testing.allocator.create(Transcript);
        native.* = .{ .id = 1 };
        try native.openOutputs(&first_snapshot);
        var image = try imageValue();
        defer image.deinit(std.testing.allocator);
        var first = try wallpaper.prepareRound(native, std.testing.allocator, &first_snapshot, &image);
        var round: wallpaper.Round = .{};
        try wallpaper.publishRound(native, &round, &first, false);
        var current = wallpaper.Current(Transcript){ .native = native, .round = round };
        var lines: wallpaper.EventLines = .{};
        var event_fd = resident.event_identity;
        var paths = pathsValue();
        var work: wallpaper.Work = .refresh;
        _ = try wallpaper.reconcile(
            &resident,
            std.testing.allocator,
            &image,
            false,
            &current,
            resident.stop_identity,
            &event_fd,
            &paths,
            &lines,
            &work,
        );
        try std.testing.expectEqual(@as(u8, 1), resident.candidate_index);
        try std.testing.expectEqual(@as(i32, 1), current.round.monitors.monitors[0].x);
        var zero_waits: u8 = 0;
        for (resident.operations[0..resident.count]) |operation| switch (operation) {
            .wait => |wait| if (wait.timeout == 0) {
                zero_waits += 1;
            },
            else => {},
        };
        try std.testing.expectEqual(@as(u8, 4), zero_waits);
        try wallpaper.releaseRound(current.native, &current.round, false);
        resident.destroyNative(std.testing.allocator, current.native);
    }
}

test "changed configure with unchanged snapshot recreates candidate" {
    const snapshot = snapshotValue(1);
    const reply =
        \\[{"name":"M0","width":2,"height":2,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{ .{}, .{ .wayland = true }, .{}, .{}, .{} },
        .replies = &.{ reply, reply },
        .wayland_changes = &.{true},
        .output_changes = &.{true},
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    try native.openOutputs(&snapshot);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var first = try wallpaper.prepareRound(native, std.testing.allocator, &snapshot, &image);
    var round: wallpaper.Round = .{};
    try wallpaper.publishRound(native, &round, &first, false);
    var current = wallpaper.Current(Transcript){ .native = native, .round = round };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var paths = pathsValue();
    var work: wallpaper.Work = .refresh;
    _ = try wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    );
    try std.testing.expectEqual(@as(u8, 1), resident.candidate_index);
    try std.testing.expectEqual(@as(u8, 2), current.native.id);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "stop during old retirement remains sticky through new current cleanup" {
    const first_snapshot = snapshotValue(1);
    const second_json =
        \\[{"name":"M0","width":2,"height":1,"x":1,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{ .waits = &.{}, .replies = &.{second_json} };
    const old = try std.testing.allocator.create(Transcript);
    old.* = .{ .id = 1 };
    try old.openOutputs(&first_snapshot);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var first = try wallpaper.prepareRound(old, std.testing.allocator, &first_snapshot, &image);
    var published: wallpaper.Round = .{};
    try wallpaper.publishRound(old, &published, &first, false);
    old.stop_on_release = true;
    var current = wallpaper.Current(Transcript){ .native = old, .round = published };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var paths = pathsValue();
    var work: wallpaper.Work = .refresh;
    try std.testing.expectError(error.Stopped, wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    ));
    try std.testing.expectEqual(@as(u8, 2), current.native.id);
    try std.testing.expectEqual(@as(u8, 0), current.round.monitors.count);
    try std.testing.expectEqual(resident.event_identity, event_fd);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "unchanged round reaches one infinite idle wait and stop wins" {
    const snapshot = snapshotValue(1);
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{ .{}, .{}, .{ .stop = true } },
        .replies = &.{reply},
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    try native.openOutputs(&snapshot);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var next = try wallpaper.prepareRound(native, std.testing.allocator, &snapshot, &image);
    var round: wallpaper.Round = .{};
    try wallpaper.publishRound(native, &round, &next, false);
    var current = wallpaper.Current(Transcript){ .native = native, .round = round };
    var event_fd: u8 = 0;
    var paths = pathsValue();
    try std.testing.expectError(error.Stopped, wallpaper.run(
        &resident,
        std.testing.allocator,
        &image,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
    ));
    const last = resident.operations[resident.count - 1].wait;
    try std.testing.expectEqual(@as(?u64, null), last.timeout);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "direct rotate acknowledges only after forced complete replacement" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{ .{}, .{}, .{ .rotate = true }, .{}, .{}, .{ .stop = true } },
        .replies = &.{ reply, reply },
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var catalog = wallpaper.Catalog{ .allocator = std.testing.allocator, .prng = .init(4) };
    defer catalog.deinit();
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "first.png"));
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "second.png"));
    try catalog.shuffle();
    catalog.published = catalog.order.items[0];
    catalog.cursor = 1;
    var event_fd: u8 = 0;
    var paths = pathsValue();
    try std.testing.expectError(error.Stopped, wallpaper.runRotation(
        &resident,
        std.testing.allocator,
        &catalog,
        &image,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        10,
    ));
    var received: ?usize = null;
    var retired: ?usize = null;
    var acknowledged: ?usize = null;
    for (resident.operations[0..resident.count], 0..) |operation, index| switch (operation) {
        .rotate_receive => received = index,
        .destroy => |id| if (id == 2) {
            retired = index;
        },
        .rotate_reply => |success| {
            if (success) acknowledged = index;
        },
        else => {},
    };
    try std.testing.expect(received != null and retired != null and acknowledged != null);
    try std.testing.expect(received.? < retired.? and retired.? < acknowledged.?);
    try std.testing.expectEqual(@as(u8, 3), current.native.id);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "stop after publication replies error and every retirement failure keeps valid new Current" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,"scale":1.00,"transform":0,"disabled":false},
        \\ {"name":"M1","width":2,"height":1,"x":2,"y":0,"scale":1.00,"transform":0,"disabled":false}]
    ;
    for ([_]?u8{ 0, 1, null }) |failure| {
        var resident = Resident{
            .waits = &.{ .{}, .{}, .{ .rotate = true }, .{}, .{}, .{ .stop = true } },
            .replies = &.{ reply, reply },
            .retirement_fail_offset = failure,
            .stop_release_id = if (failure == null) 2 else null,
        };
        const native = try std.testing.allocator.create(Transcript);
        native.* = .{ .id = 1 };
        var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
        var image = try imageValue();
        defer image.deinit(std.testing.allocator);
        var catalog = wallpaper.Catalog{ .allocator = std.testing.allocator, .prng = .init(5) };
        defer catalog.deinit();
        try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "first.png"));
        try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "second.png"));
        try catalog.shuffle();
        catalog.published = catalog.order.items[0];
        catalog.cursor = 1;
        var event_fd: u8 = 0;
        var paths = pathsValue();
        const result = wallpaper.runRotation(
            &resident,
            std.testing.allocator,
            &catalog,
            &image,
            &current,
            resident.stop_identity,
            &event_fd,
            &paths,
            10,
        );
        if (failure == null) {
            try std.testing.expectError(error.Stopped, result);
            try std.testing.expectEqual(@as(u8, 0), current.round.monitors.count);
        } else {
            try std.testing.expectError(error.Stopped, result);
            try std.testing.expectEqual(@as(u8, 2), current.round.monitors.count);
        }
        var success = false;
        var failed = false;
        for (resident.operations[0..resident.count]) |operation| switch (operation) {
            .rotate_reply => |ok| if (ok) {
                success = true;
            } else {
                failed = true;
            },
            else => {},
        };
        if (failure == null) {
            try std.testing.expect(failed and !success);
        } else {
            try std.testing.expect(success and !failed);
        }
        if (current.round.monitors.count > 0) {
            try wallpaper.releaseRound(current.native, &current.round, false);
        }
        resident.destroyNative(std.testing.allocator, current.native);
    }
}

test "one file and invalid alternatives never select published or replace Current" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    for ([_]usize{ 1, 3 }) |count| {
        var resident = Resident{
            .waits = &.{ .{}, .{}, .{ .rotate = true }, .{ .stop = true } },
            .replies = &.{reply},
            .image_failures = @intCast(count - 1),
        };
        const native = try std.testing.allocator.create(Transcript);
        native.* = .{ .id = 1 };
        var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
        var image = try imageValue();
        defer image.deinit(std.testing.allocator);
        var catalog = wallpaper.Catalog{ .allocator = std.testing.allocator, .prng = .init(6) };
        defer catalog.deinit();
        for (0..count) |index| {
            const name = if (index == 0) "published.png" else if (index == 1) "bad.jpg" else "missing.png";
            try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, name));
        }
        try catalog.shuffle();
        catalog.published = catalog.order.items[0];
        catalog.cursor = 1;
        var event_fd: u8 = 0;
        var paths = pathsValue();
        try std.testing.expectError(error.Stopped, wallpaper.runRotation(
            &resident,
            std.testing.allocator,
            &catalog,
            &image,
            &current,
            resident.stop_identity,
            &event_fd,
            &paths,
            10,
        ));
        try std.testing.expectEqual(@as(u8, 2), current.native.id);
        var success = false;
        var failure = false;
        for (resident.operations[0..resident.count]) |operation| switch (operation) {
            .rotate_reply => |ok| if (ok) {
                success = true;
            } else {
                failure = true;
            },
            else => {},
        };
        try std.testing.expect(failure and !success);
        try wallpaper.releaseRound(current.native, &current.round, false);
        resident.destroyNative(std.testing.allocator, current.native);
    }
}

test "stop and rotate readiness together sends no reply and stop propagates" {
    var resident = Resident{ .waits = &.{.{ .stop = true, .rotate = true }}, .replies = &.{} };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var catalog = wallpaper.Catalog{ .allocator = std.testing.allocator, .prng = .init(7) };
    defer catalog.deinit();
    try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, "a.png"));
    try catalog.shuffle();
    catalog.published = catalog.order.items[0];
    var event_fd: u8 = 0;
    var paths = pathsValue();
    try std.testing.expectError(error.Stopped, wallpaper.runRotation(
        &resident,
        std.testing.allocator,
        &catalog,
        &image,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        10,
    ));
    for (resident.operations[0..resident.count]) |operation| switch (operation) {
        .rotate_reply => return error.UnexpectedRotationReply,
        else => {},
    };
    resident.destroyNative(std.testing.allocator, current.native);
}

test "independent snapshot and output order retries without changing current early" {
    const first_snapshot = snapshotValue(1);
    const second_json =
        \\[{"name":"M0","width":2,"height":1,"x":2,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{},
        .replies = &.{ second_json, second_json },
        .candidate_outputs = &.{ .missing, .exact },
    };
    const old = try std.testing.allocator.create(Transcript);
    old.* = .{ .id = 1 };
    try old.openOutputs(&first_snapshot);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var next = try wallpaper.prepareRound(old, std.testing.allocator, &first_snapshot, &image);
    var round: wallpaper.Round = .{};
    try wallpaper.publishRound(old, &round, &next, false);
    var current = wallpaper.Current(Transcript){ .native = old, .round = round };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var paths = pathsValue();
    var work: wallpaper.Work = .refresh;
    _ = try wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    );
    try std.testing.expectEqual(@as(u8, 3), current.native.id);
    try std.testing.expectEqual(@as(i32, 2), current.round.monitors.monitors[0].x);
    try std.testing.expectEqual(@as(u8, 2), resident.candidate_index);
    try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "request wire handles partial would-block EOF and closes once" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{},
        .replies = &.{reply},
        .request_chunk = 2,
        .reply_chunk = 7,
        .block_write = true,
        .block_read = true,
    };
    var bytes: [wallpaper.monitor_response_capacity]u8 = undefined;
    const count = try wallpaper.requestMonitors(
        &resident,
        "/run/hypr/x/.socket.sock",
        resident.stop_identity,
        resident.event_identity,
        &bytes,
        2000,
    );
    try std.testing.expectEqualStrings(reply, bytes[0..count]);
    try std.testing.expectEqual(@as(u8, 2), resident.socket_waits);
    try std.testing.expectEqual(@as(u8, 1), resident.request_closes);
}

test "request reset accepts only an already complete JSON array" {
    const complete =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    var resident = Resident{
        .waits = &.{},
        .replies = &.{complete},
        .reply_chunk = 7,
        .reset_after_reply = true,
    };
    var bytes: [wallpaper.monitor_response_capacity]u8 = undefined;
    const count = try wallpaper.requestMonitors(
        &resident,
        "/run/hypr/x/.socket.sock",
        resident.stop_identity,
        resident.event_identity,
        &bytes,
        2000,
    );
    try std.testing.expectEqualStrings(complete, bytes[0..count]);
    try std.testing.expectEqual(@as(u8, 1), resident.request_closes);

    resident = .{
        .waits = &.{},
        .replies = &.{complete[0 .. complete.len - 1]},
        .reset_after_reply = true,
    };
    try std.testing.expectError(error.ConnectionResetByPeer, wallpaper.requestMonitors(
        &resident,
        "/run/hypr/x/.socket.sock",
        resident.stop_identity,
        resident.event_identity,
        &bytes,
        2000,
    ));
    try std.testing.expectEqual(@as(u8, 1), resident.request_closes);
}

test "balanced malformed reset frame reaches parser but no candidate or publication" {
    var resident = Resident{
        .waits = &.{},
        .replies = &.{"[}"},
        .reset_after_reply = true,
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var lines: wallpaper.EventLines = .{};
    var event_fd = resident.event_identity;
    var work: wallpaper.Work = .refresh;
    var paths = pathsValue();
    if (wallpaper.reconcile(
        &resident,
        std.testing.allocator,
        &image,
        false,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        &lines,
        &work,
    )) |_| return error.ExpectedMalformedJson else |_| {}
    try std.testing.expectEqual(@as(u8, 0), resident.candidate_index);
    try std.testing.expectEqual(@as(u8, 0), current.round.monitors.count);
    try std.testing.expectEqual(@as(u8, 1), current.native.id);
    try std.testing.expectEqual(@as(u8, 1), resident.request_closes);
    resident.destroyNative(std.testing.allocator, current.native);
}

test "generated request progress remains bounded and closes once" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzRequest, .{});
        return;
    }
    var smith = std.testing.Smith{ .in = "" };
    try fuzzRequest({}, &smith);
}

test "partial preparation discards only new resources in reverse" {
    const snapshot = snapshotValue(3);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var transcript = Transcript{ .fail_at = 26 };
    try std.testing.expectError(
        error.SimulatedFailure,
        wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image),
    );
    try std.testing.expectEqual(
        Operation{ .discard = .{ .index = 1, .generation = 2 } },
        transcript.operations[transcript.count - 2],
    );
    try std.testing.expectEqual(
        Operation{ .discard = .{ .index = 0, .generation = 1 } },
        transcript.operations[transcript.count - 1],
    );
}

test "every preparation task failure leaves no prepared resource" {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    const operation_count = 2 + snapshot.count + snapshot.count * 11;
    for (0..operation_count) |failure| {
        var transcript = Transcript{ .fail_at = @intCast(failure) };
        if (wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image)) |round| {
            var owned = round;
            wallpaper.discardRound(&transcript, &owned);
        } else |_| {}
        for (transcript.resources) |resource| {
            try std.testing.expect(resource.state == .vacant);
        }
    }
}

test "missing and duplicate output sets disconnect before surface work" {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    inline for (.{
        .{ Outputs.missing, error.WaylandOutputMissing },
        .{ Outputs.duplicate, error.WaylandOutputDuplicate },
    }) |history| {
        var transcript = Transcript{ .output_result = history[0] };
        try std.testing.expectError(
            history[1],
            wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image),
        );
        try std.testing.expectEqual(Operation.disconnect_loss, transcript.operations[transcript.count - 1]);
        for (transcript.resources) |resource| try std.testing.expect(resource.state == .vacant);
    }
}

test "same snapshot retry after partial preparation reuses exact outputs" {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var transcript = Transcript{ .fail_at = 15 };
    try std.testing.expectError(
        error.SimulatedFailure,
        wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image),
    );
    try expectNoResources(&transcript);
    const connect_count = countOperation(&transcript, .connect);
    transcript.fail_at = null;
    var round = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    defer wallpaper.discardRound(&transcript, &round);
    try std.testing.expectEqual(connect_count, countOperation(&transcript, .connect));
}

test "changed snapshots reject retry before surface work" {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    inline for (.{ "name", "geometry", "count" }) |change| {
        var transcript = Transcript{ .fail_at = 15 };
        try std.testing.expectError(
            error.SimulatedFailure,
            wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image),
        );
        try expectNoResources(&transcript);
        transcript.fail_at = null;
        var changed = snapshot;
        if (std.mem.eql(u8, change, "name")) {
            changed.monitors[0].name_bytes[0] = 'B';
        } else if (std.mem.eql(u8, change, "geometry")) {
            changed.monitors[0].x += 1;
        } else {
            changed.count = 1;
        }
        const before = transcript.count;
        try std.testing.expectError(
            error.WaylandOutputChanged,
            wallpaper.prepareRound(&transcript, std.testing.allocator, &changed, &image),
        );
        try std.testing.expectEqual(before, transcript.count);
        try expectNoResources(&transcript);
    }
}

test "prepare rejects index monitor divergence before allocation" {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var transcript: Transcript = .{};
    try wallpaper.openOutputs(&transcript, &snapshot);
    var pixels = try wallpaper.coverImage(&transcript, std.testing.allocator, &image, 2, 2);
    defer pixels.deinit(std.testing.allocator);
    var changed = snapshot.monitors[0];
    changed.x += 1;
    const before_count = transcript.count;
    const before_generation = transcript.next_generation;
    try std.testing.expectError(
        error.WaylandOutputChanged,
        transcript.prepare(0, &changed, &pixels),
    );
    try std.testing.expectEqual(before_count, transcript.count);
    try std.testing.expectEqual(before_generation, transcript.next_generation);
    try expectNoResources(&transcript);
}

test "flush EAGAIN writable success retains one semantic batch" {
    const flushes = [_]Flush{ .again, .success };
    const polls = [_]Poll{.writable};
    var transcript = Transcript{ .flushes = &flushes, .polls = &polls };
    var current: wallpaper.Round = .{};
    var next = try preparedRound(&transcript);
    try wallpaper.publishRound(&transcript, &current, &next, false);
    try std.testing.expectEqual(@as(u8, 2), transcript.flush_index);
    try std.testing.expectEqual(@as(u8, 1), transcript.poll_index);
}

test "flush and poll attempt endpoints are exact" {
    const again = [_]Flush{.again} ** wallpaper.publication_flush_capacity;
    const writable = [_]Poll{.writable} ** wallpaper.publication_poll_capacity;
    var transcript = Transcript{ .flushes = &again, .polls = &writable };
    var current: wallpaper.Round = .{};
    var next = try preparedRound(&transcript);
    try std.testing.expectError(
        error.WaylandFlushAttemptsExceeded,
        wallpaper.publishRound(&transcript, &current, &next, false),
    );
    try std.testing.expectEqual(wallpaper.publication_flush_capacity, transcript.flush_index);
    try std.testing.expectEqual(wallpaper.publication_poll_capacity, transcript.poll_index);
}

test "flush timeout stop and attempt exhaustion disconnect before swap" {
    const histories = [_]struct { polls: []const Poll, stopped: bool, expected: anyerror }{
        .{ .polls = &.{.timeout}, .stopped = false, .expected = error.WaylandFlushTimeout },
        .{ .polls = &.{.writable}, .stopped = true, .expected = error.WaylandFlushStopped },
        .{
            .polls = &([_]Poll{.interrupted} ** wallpaper.publication_poll_capacity),
            .stopped = false,
            .expected = error.WaylandFlushAttemptsExceeded,
        },
    };
    for (histories) |history| {
        var transcript = Transcript{ .flushes = &.{.again}, .polls = history.polls };
        var current: wallpaper.Round = .{};
        var next = try preparedRound(&transcript);
        try std.testing.expectError(
            history.expected,
            wallpaper.publishRound(&transcript, &current, &next, history.stopped),
        );
        try std.testing.expectEqual(@as(u8, 0), current.monitors.count);
        try std.testing.expectEqual(Operation.disconnect_loss, transcript.operations[transcript.count - 1]);
    }
}

test "whole transition validates before queueing" {
    var transcript: Transcript = .{};
    var next = try preparedRound(&transcript);
    next.handles[1] = next.handles[0];
    var current: wallpaper.Round = .{};
    const before = transcript.count;
    try std.testing.expectError(
        error.SurfaceHandleDuplicate,
        wallpaper.publishRound(&transcript, &current, &next, false),
    );
    try std.testing.expectEqual(before, transcript.count);
}

test "sixteen current and sixteen replacement resources fit exactly" {
    var transcript: Transcript = .{};
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    const snapshot = snapshotValue(wallpaper.monitor_capacity);
    var current: wallpaper.Round = .{};
    var first = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    try wallpaper.publishRound(&transcript, &current, &first, false);
    var next = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    var occupied: usize = 0;
    for (transcript.resources) |resource| if (resource.state != .vacant) {
        occupied += 1;
    };
    try std.testing.expectEqual(@as(usize, wallpaper.surface_resource_capacity), occupied);
    try wallpaper.publishRound(&transcript, &current, &next, false);
}

test "generation max is reserved before resource mutation" {
    var transcript: Transcript = .{ .next_generation = std.math.maxInt(u32) - 1 };
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    try wallpaper.openOutputs(&transcript, &snapshot);
    var pixels = try wallpaper.coverImage(&transcript, std.testing.allocator, &image, 2, 2);
    defer pixels.deinit(std.testing.allocator);
    const last = try transcript.prepare(0, &snapshot.monitors[0], &pixels);
    try std.testing.expectEqual(std.math.maxInt(u32) - 1, last.generation);
    const before = transcript.count;
    try std.testing.expectError(
        error.SurfaceGenerationExhausted,
        transcript.prepare(1, &snapshot.monitors[1], &pixels),
    );
    try std.testing.expectEqual(before, transcript.count);
    transcript.discardPrepared(last);
}

test "generated round histories remain within fixed ownership bounds" {
    if (@import("builtin").fuzz) {
        try std.testing.fuzz({}, fuzzRounds, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzRounds({}, &empty);
}

fn preparedRound(transcript: *Transcript) !wallpaper.Round {
    const snapshot = snapshotValue(2);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    return wallpaper.prepareRound(transcript, std.testing.allocator, &snapshot, &image);
}

fn snapshotValue(count: u8) wallpaper.Snapshot {
    var snapshot: wallpaper.Snapshot = .{};
    for (0..count) |index| {
        var monitor: wallpaper.Monitor = .{
            .name_bytes = undefined,
            .name_len = 2,
            .x = @intCast(index),
            .y = 0,
            .width = 2,
            .height = 2,
            .scale_100 = 100,
            .transform = .normal,
        };
        monitor.name_bytes[0] = 'A';
        monitor.name_bytes[1] = @intCast('0' + index);
        snapshot.monitors[index] = monitor;
    }
    snapshot.count = count;
    return snapshot;
}

fn pathsValue() wallpaper.SocketPaths {
    var paths: wallpaper.SocketPaths = .{
        .request = .{},
        .event = .{},
    };
    const request = "/run/hypr/x/.socket.sock";
    const event = "/run/hypr/x/.socket2.sock";
    @memcpy(paths.request.bytes[0..request.len], request);
    paths.request.len = request.len;
    @memcpy(paths.event.bytes[0..event.len], event);
    paths.event.len = event.len;
    return paths;
}

fn imageValue() !wallpaper.Image {
    const pixels = try std.testing.allocator.alloc(u32, 4);
    @memset(pixels, 0xff123456);
    return .{ .width = 2, .height = 2, .pitch = 8, .pixels = pixels };
}

fn contains(handles: []const wallpaper.SurfaceHandle, needle: wallpaper.SurfaceHandle) bool {
    for (handles) |handle| if (handle == needle) return true;
    return false;
}

fn expectNoResources(transcript: *const Transcript) !void {
    for (transcript.resources) |resource| try std.testing.expect(resource.state == .vacant);
}

fn countOperation(transcript: *const Transcript, expected: Operation) usize {
    var count: usize = 0;
    for (transcript.operations[0..transcript.count]) |operation| {
        if (std.meta.eql(operation, expected)) count += 1;
    }
    return count;
}

fn fuzzRounds(_: void, smith: *std.testing.Smith) !void {
    const count = smith.valueRangeAtMost(u8, 1, wallpaper.monitor_capacity);
    const snapshot = snapshotValue(count);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var transcript: Transcript = .{};
    var next = try wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image);
    var current: wallpaper.Round = .{};
    try wallpaper.publishRound(&transcript, &current, &next, false);
    try std.testing.expectEqual(count, current.monitors.count);
    var occupied: usize = 0;
    for (transcript.resources) |resource| if (resource.state != .vacant) {
        occupied += 1;
    };
    try std.testing.expectEqual(@as(usize, count), occupied);
    try std.testing.expect(transcript.count <= operation_capacity);
}

fn fuzzRequest(_: void, smith: *std.testing.Smith) !void {
    const reply = "[]";
    var resident = Resident{
        .waits = &.{},
        .replies = &.{reply},
        .request_chunk = smith.valueRangeAtMost(u8, 1, 10),
        .reply_chunk = smith.valueRangeAtMost(u16, 1, reply.len),
        .block_write = smith.value(bool),
        .block_read = smith.value(bool),
    };
    var bytes: [wallpaper.monitor_response_capacity]u8 = undefined;
    const count = try wallpaper.requestMonitors(
        &resident,
        "request",
        resident.stop_identity,
        resident.event_identity,
        &bytes,
        2000,
    );
    try std.testing.expectEqualStrings(reply, bytes[0..count]);
    try std.testing.expectEqual(@as(u8, 1), resident.request_closes);
    try std.testing.expect(resident.socket_waits <= 2);
}

const ScheduleSummary = struct {
    image_opens: u16 = 0,
    direct_successes: u16 = 0,
    direct_failures: u16 = 0,
    reconnects: u16 = 0,
    timed_waits: [128]u64 = undefined,
    timed_wait_count: u8 = 0,
    final_clock: u64 = 0,
};

fn runScheduleHistory(
    waits: []const wallpaper.Ready,
    clock_steps: []const u64,
    replies: []const []const u8,
    image_failures: u8,
    event_losses: u8,
    event_reads: []const []const u8,
    comptime interval_milliseconds: u64,
) !ScheduleSummary {
    var resident = Resident{
        .waits = waits,
        .replies = replies,
        .clock_steps = clock_steps,
        .image_failures = image_failures,
        .event_losses = event_losses,
        .event_reads = event_reads,
    };
    const native = try std.testing.allocator.create(Transcript);
    native.* = .{ .id = 1 };
    var current = wallpaper.Current(Transcript){ .native = native, .round = .{} };
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var catalog = wallpaper.Catalog{ .allocator = std.testing.allocator, .prng = .init(81) };
    defer catalog.deinit();
    for ([_][]const u8{ "a.png", "b.png", "c.png", "d.png" }) |name| {
        try catalog.paths.append(std.testing.allocator, try std.testing.allocator.dupe(u8, name));
    }
    try catalog.shuffle();
    catalog.published = catalog.order.items[0];
    catalog.cursor = 1;
    var event_fd: u8 = 0;
    var paths = pathsValue();
    try std.testing.expectError(error.Stopped, wallpaper.runRotation(
        &resident,
        std.testing.allocator,
        &catalog,
        &image,
        &current,
        resident.stop_identity,
        &event_fd,
        &paths,
        interval_milliseconds,
    ));
    var summary: ScheduleSummary = .{ .final_clock = resident.clock };
    for (resident.operations[0..resident.count]) |operation| switch (operation) {
        .image_open => summary.image_opens += 1,
        .rotate_reply => |success| if (success) {
            summary.direct_successes += 1;
        } else {
            summary.direct_failures += 1;
        },
        .reconnect => summary.reconnects += 1,
        .wait => |wait| if (wait.timeout) |timeout| if (timeout > 0) {
            std.debug.assert(summary.timed_wait_count < summary.timed_waits.len);
            summary.timed_waits[summary.timed_wait_count] = timeout;
            summary.timed_wait_count += 1;
        },
        else => {},
    };
    if (current.round.monitors.count > 0) try wallpaper.releaseRound(current.native, &current.round, false);
    resident.destroyNative(std.testing.allocator, current.native);
    return summary;
}

test "product rotation intervals and exact deadline boundary are explicit" {
    try std.testing.expectEqual(@as(u64, 900_000), wallpaper.beta_rotation_interval_milliseconds);
    try std.testing.expectEqual(@as(u64, 3_600_000), wallpaper.production_rotation_interval_milliseconds);
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const summary = try runScheduleHistory(
        &.{ .{}, .{}, .{ .event = true }, .{}, .{}, .{}, .{ .stop = true } },
        &.{ 9, 1 },
        &.{ reply, reply },
        0,
        0,
        &.{"workspace>>2\n"},
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), summary.image_opens);
    try std.testing.expectEqualSlices(u64, &.{ 10, 1, 10 }, summary.timed_waits[0..summary.timed_wait_count]);
    try std.testing.expectEqual(@as(u64, 20), summary.final_clock);
}

test "stop wins at deadline and direct success wins collision then resets" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const stopped = try runScheduleHistory(
        &.{ .{}, .{}, .{ .stop = true } },
        &.{10},
        &.{reply},
        0,
        0,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 0), stopped.image_opens);
    try std.testing.expectEqual(@as(u64, 10), stopped.final_clock);

    const direct = try runScheduleHistory(
        &.{ .{}, .{}, .{ .rotate = true }, .{}, .{}, .{ .stop = true } },
        &.{10},
        &.{ reply, reply },
        0,
        0,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), direct.image_opens);
    try std.testing.expectEqual(@as(u16, 1), direct.direct_successes);
    try std.testing.expectEqualSlices(u64, &.{ 10, 10 }, direct.timed_waits[0..direct.timed_wait_count]);
}

test "failed direct preserves deadline and failed schedule waits one full interval" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const direct = try runScheduleHistory(
        &.{ .{}, .{}, .{ .rotate = true }, .{}, .{}, .{}, .{}, .{}, .{ .stop = true } },
        &.{ 4, 6 },
        &.{ reply, reply, reply },
        3,
        0,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), direct.direct_failures);
    try std.testing.expectEqualSlices(u64, &.{ 10, 6, 10 }, direct.timed_waits[0..direct.timed_wait_count]);

    const scheduled = try runScheduleHistory(
        &.{ .{}, .{}, .{}, .{}, .{}, .{ .stop = true } },
        &.{10},
        &.{ reply, reply },
        3,
        0,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 3), scheduled.image_opens);
    try std.testing.expectEqualSlices(u64, &.{ 10, 10 }, scheduled.timed_waits[0..scheduled.timed_wait_count]);
}

test "delayed wake reconnect and focus storms never catch up" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const delayed = try runScheduleHistory(
        &.{ .{}, .{}, .{}, .{}, .{}, .{ .stop = true } },
        &.{100},
        &.{ reply, reply },
        0,
        0,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), delayed.image_opens);
    try std.testing.expectEqualSlices(u64, &.{ 10, 10 }, delayed.timed_waits[0..delayed.timed_wait_count]);

    const focus_storm = try runScheduleHistory(
        &.{
            .{}, .{}, .{ .event = true }, .{ .event = true }, .{ .event = true },
            .{}, .{}, .{ .stop = true },
        },
        &.{ 2, 3, 5 },
        &.{ reply, reply },
        0,
        0,
        &.{ "workspace>>2\n", "focusedmon>>DP-1,1\n", "activewindow>>kitty,title\n" },
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), focus_storm.image_opens);

    const reconnect_storm = try runScheduleHistory(
        &.{ .{}, .{}, .{ .event = true }, .{}, .{}, .{}, .{}, .{}, .{ .stop = true } },
        &.{ 5, 5 },
        &.{ reply, reply, reply },
        0,
        1,
        &.{},
        10,
    );
    try std.testing.expectEqual(@as(u16, 1), reconnect_storm.image_opens);
    try std.testing.expect(reconnect_storm.reconnects >= 2);
}

test "overnight history performs one round per interval" {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const rounds = 32;
    var waits: [2 + rounds * 3 + 1]wallpaper.Ready = @splat(.{});
    waits[waits.len - 1] = .{ .stop = true };
    var replies: [rounds + 1][]const u8 = @splat(reply);
    const summary = try runScheduleHistory(&waits, &.{}, &replies, 0, 0, &.{}, 10);
    try std.testing.expectEqual(@as(u16, rounds), summary.image_opens);
    try std.testing.expectEqual(@as(u8, rounds + 1), summary.timed_wait_count);
    try std.testing.expectEqual(@as(u64, (rounds + 1) * 10), summary.final_clock);
}

test "schedule histories remain bounded under Smith readiness and time" {
    if (@inComptime()) {
        try std.testing.fuzz({}, fuzzSchedule, .{});
        return;
    }
    var smith = std.testing.Smith{ .in = "" };
    try fuzzSchedule({}, &smith);
}

fn fuzzSchedule(_: void, smith: *std.testing.Smith) !void {
    const reply =
        \\[{"name":"M0","width":2,"height":1,"x":0,"y":0,
        \\"scale":1.00,"transform":0,"disabled":false}]
    ;
    const direct = smith.value(bool);
    const fail = smith.value(bool);
    const advance = smith.valueRangeAtMost(u64, 0, 100);
    const summary = try runScheduleHistory(
        &.{ .{}, .{}, .{ .rotate = direct }, .{}, .{}, .{ .stop = true } },
        &.{advance},
        &.{ reply, reply },
        if (fail) 3 else 0,
        0,
        &.{},
        10,
    );
    try std.testing.expect(summary.image_opens <= 3);
    try std.testing.expect(summary.direct_successes + summary.direct_failures <= 1);
}
