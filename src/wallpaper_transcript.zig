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

    pub fn flushPublication(transcript: *Transcript, stopped: bool) !void {
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

    pub fn releaseRetired(transcript: *Transcript, handle: wallpaper.SurfaceHandle) !void {
        const resource = try transcript.checkedResource(handle);
        if (resource.state != .retiring) return error.SurfaceStateInvalid;
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

test "partial preparation discards only new resources in reverse" {
    const snapshot = snapshotValue(3);
    var image = try imageValue();
    defer image.deinit(std.testing.allocator);
    var transcript = Transcript{ .fail_at = 26 };
    try std.testing.expectError(
        error.SimulatedFailure,
        wallpaper.prepareRound(&transcript, std.testing.allocator, &snapshot, &image),
    );
    try std.testing.expectEqual(Operation{ .discard = .{ .index = 1, .generation = 2 } }, transcript.operations[transcript.count - 2]);
    try std.testing.expectEqual(Operation{ .discard = .{ .index = 0, .generation = 1 } }, transcript.operations[transcript.count - 1]);
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
