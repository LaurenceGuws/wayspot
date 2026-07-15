//! SDL display IO owns native display calls and their typed test transcript.

const std = @import("std");
const c = @import("sdl_c");

/// max_displays bounds one SDL display query and its transcript facts.
pub const max_displays: u32 = 8;
/// max_display_name_bytes bounds one copied SDL display name.
pub const max_display_name_bytes: u32 = 96;
const max_transcript_operations: usize = 2 + @as(usize, max_displays) * 3;

/// DisplayId is the plain SDL display identity used across the IO seam.
pub const DisplayId = u32;

/// DisplayName owns one bounded SDL display name without exposing C storage.
pub const DisplayName = struct {
    /// bytes owns one display name and never exposes the SDL pointer.
    bytes: [max_display_name_bytes]u8 = undefined,
    /// len is the retained byte count and never exceeds max_display_name_bytes.
    len: u32 = 0,

    /// init copies a non-empty name without embedded NUL bytes into bounded storage.
    pub fn init(text: []const u8) !DisplayName {
        if (text.len == 0 or text.len > max_display_name_bytes) {
            return error.InvalidMonitorName;
        }
        for (text) |byte| if (byte == 0) return error.InvalidMonitorName;
        var name = DisplayName{};
        @memcpy(name.bytes[0..text.len], text);
        name.len = @intCast(text.len);
        return name;
    }

    /// slice returns the retained display name bytes.
    pub fn slice(self: *const DisplayName) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// DisplayBounds owns validated positive display dimensions.
pub const DisplayBounds = struct {
    /// width is a positive display width in pixels.
    width: i32,
    /// height is a positive display height in pixels.
    height: i32,

    /// init rejects empty or negative display geometry.
    pub fn init(width: i32, height: i32) !DisplayBounds {
        if (width <= 0 or height <= 0) return error.InvalidMonitorSize;
        return .{ .width = width, .height = height };
    }
};

/// DisplayFacts carries plain validated facts from one SDL display.
pub const DisplayFacts = struct {
    /// id identifies the display without a C type.
    id: DisplayId,
    /// name owns the bounded display name.
    name: DisplayName,
    /// bounds owns validated positive display dimensions.
    bounds: DisplayBounds,
    /// scale is absent only when SDL reports an invalid scale.
    scale: ?f64,
};

/// DisplayList owns the bounded SDL display ids after native storage is freed.
pub const DisplayList = struct {
    /// items owns at most max_displays ids after SDL storage is released.
    items: [max_displays]DisplayId = undefined,
    /// count is the number of initialized items.
    count: u32 = 0,
};

/// DisplayOperation is one exact operation in a bounded display transcript.
pub const DisplayOperation = enum {
    query_displays,
    release_displays,
    query_name,
    query_bounds,
    query_scale,
};

/// DisplayCall binds one transcript operation to its plain display input.
pub const DisplayCall = struct {
    /// operation is the next native or transcript call.
    operation: DisplayOperation,
    /// display_id is present only for per-display operations.
    display_id: ?DisplayId = null,
};

/// DisplayListResult distinguishes a null SDL list from a freed invalid-count list.
pub const DisplayListResult = union(enum) {
    values: DisplayList,
    null_result,
    invalid_count: i64,
};

/// DisplayNameResult owns one bounded transcript name or records a missing reply.
pub const DisplayNameResult = ?DisplayName;

/// DisplayBoundsResult is a typed transcript rectangle or a missing reply.
pub const DisplayBoundsResult = ?DisplayBounds;

/// DisplayScaleResult is a typed finite-scale reply or a missing reply.
pub const DisplayScaleResult = ?f32;

/// TranscriptError is returned only by test transcript construction/checking.
pub const TranscriptError = error{
    TranscriptTooLong,
    TranscriptExhausted,
    TranscriptUnexpectedOperation,
    TranscriptIncomplete,
};

/// DisplayTranscript stores a fixed operation record and typed display replies.
pub const DisplayTranscript = struct {
    /// expected owns the fixed operation record used by the transcript.
    expected: [max_transcript_operations]DisplayCall = undefined,
    /// expected_count bounds the initialized prefix of expected.
    expected_count: u32 = 0,
    /// operation_count tracks consumed operations.
    operation_count: u32 = 0,
    /// display_result distinguishes null, valid, and invalid-count SDL results.
    display_result: DisplayListResult = .{ .values = .{} },
    /// names owns fixed reply text copied from bounded transcript inputs.
    names: [max_displays]DisplayNameResult,
    /// bounds contains typed bounds replies for the fixed display slots.
    bounds: [max_displays]DisplayBoundsResult,
    /// scales contains typed external scale replies for the fixed display slots.
    scales: [max_displays]DisplayScaleResult,
    /// released_display_lists counts exact SDL-free records in simulation.
    released_display_lists: u32 = 0,

    /// init copies a bounded expected transcript into fixed owned storage.
    pub fn init(expected: []const DisplayCall) TranscriptError!DisplayTranscript {
        if (expected.len > max_transcript_operations) return error.TranscriptTooLong;
        var transcript = DisplayTranscript{
            .expected_count = @intCast(expected.len),
            .names = [_]?DisplayName{null} ** max_displays,
            .bounds = [_]?DisplayBounds{null} ** max_displays,
            .scales = [_]?f32{null} ** max_displays,
        };
        @memcpy(transcript.expected[0..expected.len], expected);
        return transcript;
    }

    /// assertComplete proves the fixed transcript was consumed exactly.
    pub fn assertComplete(self: *const DisplayTranscript) TranscriptError!void {
        if (self.operation_count != self.expected_count) return error.TranscriptIncomplete;
    }

    fn record(self: *DisplayTranscript, call: DisplayCall) TranscriptError!void {
        if (self.operation_count >= self.expected_count) return error.TranscriptExhausted;
        const expected = self.expected[self.operation_count];
        if (expected.operation != call.operation or expected.display_id != call.display_id) {
            return error.TranscriptUnexpectedOperation;
        }
        self.operation_count += 1;
    }

    // Transcript mismatches are test-seam failures, not product errors. Panic
    // keeps them visible while leaving native SdlDisplayIo error sets exact.
    fn recordForIo(self: *DisplayTranscript, call: DisplayCall) void {
        self.record(call) catch |err| {
            std.debug.panic("invalid SDL display transcript: {s}", .{@errorName(err)});
        };
    }

    fn releaseDisplayList(self: *DisplayTranscript) void {
        self.recordForIo(.{ .operation = .release_displays });
        self.released_display_lists += 1;
    }
};

/// SdlDisplayIo separates native SDL calls from a fixed typed transcript.
pub const SdlDisplayIo = struct {
    /// source selects native SDL or a caller-owned test transcript.
    source: Source,

    const Source = union(enum) {
        native,
        transcript: *DisplayTranscript,
    };

    /// native selects the production SDL implementation.
    pub fn native() SdlDisplayIo {
        return .{ .source = .native };
    }

    /// fromTranscript selects one caller-owned fixed transcript.
    pub fn fromTranscript(transcript: *DisplayTranscript) SdlDisplayIo {
        return .{ .source = .{ .transcript = transcript } };
    }

    /// queryDisplays returns bounded ids and records the native list cleanup.
    pub fn queryDisplays(self: *SdlDisplayIo) !DisplayList {
        return switch (self.source) {
            .native => queryDisplaysNative(),
            .transcript => |transcript| {
                transcript.recordForIo(.{ .operation = .query_displays });
                return switch (transcript.display_result) {
                    .values => |value| {
                        transcript.releaseDisplayList();
                        return validateDisplayList(value);
                    },
                    .null_result => error.SdlMonitorQueryFailed,
                    .invalid_count => |raw_count| {
                        transcript.releaseDisplayList();
                        if (raw_count < 0) return error.SdlMonitorQueryFailed;
                        return error.TooManyMonitors;
                    },
                };
            },
        };
    }

    /// queryFacts returns one display with an absent optional SDL scale on scale failure.
    pub fn queryFacts(self: *SdlDisplayIo, id: DisplayId) !DisplayFacts {
        const name = try self.queryName(id);
        const bounds = try self.queryBounds(id);
        const scale = self.queryScale(id) catch |err| switch (err) {
            error.SdlMonitorScaleMissing => null,
        };
        return .{ .id = id, .name = name, .bounds = bounds, .scale = scale };
    }

    /// queryName returns one validated plain display name.
    pub fn queryName(self: *SdlDisplayIo, id: DisplayId) !DisplayName {
        return switch (self.source) {
            .native => queryNameNative(id),
            .transcript => |transcript| {
                transcript.recordForIo(.{ .operation = .query_name, .display_id = id });
                const index = transcriptIndex(transcript, id) orelse
                    return error.SdlMonitorNameMissing;
                return transcript.names[index] orelse error.SdlMonitorNameMissing;
            },
        };
    }

    /// queryBounds returns one validated plain display rectangle.
    pub fn queryBounds(self: *SdlDisplayIo, id: DisplayId) !DisplayBounds {
        return switch (self.source) {
            .native => queryBoundsNative(id),
            .transcript => |transcript| {
                transcript.recordForIo(.{ .operation = .query_bounds, .display_id = id });
                const index = transcriptIndex(transcript, id) orelse
                    return error.SdlMonitorSizeMissing;
                return transcript.bounds[index] orelse error.SdlMonitorSizeMissing;
            },
        };
    }

    /// queryScale returns a finite positive source scale or its exact source error.
    pub fn queryScale(self: *SdlDisplayIo, id: DisplayId) !f64 {
        return switch (self.source) {
            .native => queryScaleNative(id),
            .transcript => |transcript| {
                transcript.recordForIo(.{ .operation = .query_scale, .display_id = id });
                const index = transcriptIndex(transcript, id) orelse
                    return error.SdlMonitorScaleMissing;
                const value = transcript.scales[index] orelse return error.SdlMonitorScaleMissing;
                return mapDisplayScale(value);
            },
        };
    }
};

fn queryDisplaysNative() !DisplayList {
    var raw_count: c_int = 0;
    const ids = c.SDL_GetDisplays(&raw_count) orelse return error.SdlMonitorQueryFailed;
    defer c.SDL_free(ids);
    const count = try mapDisplayCount(@intCast(raw_count));
    var result = DisplayList{ .count = count };
    var index: u32 = 0;
    while (index < count) : (index += 1) result.items[index] = @intCast(ids[index]);
    return result;
}

fn queryNameNative(id: DisplayId) !DisplayName {
    const name_ptr = c.SDL_GetDisplayName(@intCast(id)) orelse return error.SdlMonitorNameMissing;
    return displayNameFromSentinel(name_ptr);
}

/// displayNameFromSentinel scans only max_display_name_bytes plus its terminator.
fn displayNameFromSentinel(name_ptr: [*]const u8) !DisplayName {
    const max_len: usize = max_display_name_bytes;
    var length: usize = 0;
    while (length <= max_len) : (length += 1) {
        if (name_ptr[length] == 0) return DisplayName.init(name_ptr[0..length]);
    }
    return error.InvalidMonitorName;
}

fn queryBoundsNative(id: DisplayId) !DisplayBounds {
    var rect: c.SDL_Rect = undefined;
    if (!c.SDL_GetDisplayBounds(@intCast(id), &rect)) return error.SdlMonitorSizeMissing;
    return DisplayBounds.init(rect.w, rect.h);
}

fn queryScaleNative(id: DisplayId) !f64 {
    return mapDisplayScale(c.SDL_GetDisplayContentScale(@intCast(id)));
}

fn transcriptIndex(transcript: *const DisplayTranscript, id: DisplayId) ?usize {
    const ids = switch (transcript.display_result) {
        .values => |value| value,
        .null_result, .invalid_count => return null,
    };
    if (ids.count > max_displays) return null;
    var index: usize = 0;
    while (index < ids.count) : (index += 1) {
        if (ids.items[index] == id) return index;
    }
    return null;
}

fn mapDisplayCount(raw_count: i64) !u32 {
    if (raw_count < 0) return error.SdlMonitorQueryFailed;
    if (raw_count > @as(i64, max_displays)) return error.TooManyMonitors;
    return @intCast(raw_count);
}

fn mapDisplayScale(value: f32) !f64 {
    if (!std.math.isFinite(value) or value <= 0) return error.SdlMonitorScaleMissing;
    return @floatCast(value);
}

fn validateDisplayList(list: DisplayList) !DisplayList {
    if (list.count > max_displays) return error.TooManyMonitors;
    return list;
}

fn nextFuzzValue(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

test "SDL display mapping rejects invalid bounded facts" {
    try std.testing.expectEqual(
        @as(u32, max_displays),
        try mapDisplayCount(@intCast(max_displays)),
    );
    try std.testing.expectError(error.SdlMonitorQueryFailed, mapDisplayCount(-1));
    try std.testing.expectError(
        error.TooManyMonitors,
        mapDisplayCount(@as(i64, max_displays) + 1),
    );
    try std.testing.expectError(error.TooManyMonitors, mapDisplayCount(std.math.maxInt(i64)));
    try std.testing.expectError(error.InvalidMonitorSize, DisplayBounds.init(0, 1080));
    const embedded_nul = [_]u8{ 'D', 'P', 0, '-', '1' };
    try std.testing.expectError(error.InvalidMonitorName, DisplayName.init(&embedded_nul));
    try std.testing.expectError(error.SdlMonitorScaleMissing, mapDisplayScale(0));
    try std.testing.expectError(error.SdlMonitorScaleMissing, mapDisplayScale(std.math.nan(f32)));
    try std.testing.expectError(error.SdlMonitorScaleMissing, mapDisplayScale(std.math.inf(f32)));
}

test "fuzz bounded SDL display facts" {
    var state: u32 = 0x7a31_2e19;
    var iteration: u32 = 0;
    while (iteration < 512) : (iteration += 1) {
        const width: i32 = @bitCast(nextFuzzValue(&state));
        const height: i32 = @bitCast(nextFuzzValue(&state));
        const bounds = DisplayBounds.init(width, height);
        if (width <= 0 or height <= 0) {
            try std.testing.expectError(error.InvalidMonitorSize, bounds);
        } else {
            _ = try bounds;
        }

        const raw_count: c_int = @bitCast(nextFuzzValue(&state));
        const count = mapDisplayCount(@intCast(raw_count));
        if (raw_count < 0) {
            try std.testing.expectError(error.SdlMonitorQueryFailed, count);
        } else if (raw_count > max_displays) {
            try std.testing.expectError(error.TooManyMonitors, count);
        } else {
            _ = try count;
        }

        var name: [max_display_name_bytes + 1]u8 = undefined;
        @memset(&name, 'n');
        const name_len: usize = @intCast(nextFuzzValue(&state) % (max_display_name_bytes + 2));
        const name_result = DisplayName.init(name[0..name_len]);
        if (name_len == 0 or name_len > max_display_name_bytes) {
            try std.testing.expectError(error.InvalidMonitorName, name_result);
        } else {
            _ = try name_result;
        }

        const scale_value: f32 = @floatFromInt(nextFuzzValue(&state) & 0x7fff);
        const scale_result = mapDisplayScale(scale_value);
        if (scale_value <= 0) {
            try std.testing.expectError(error.SdlMonitorScaleMissing, scale_result);
        } else {
            _ = try scale_result;
        }
    }
}

test "SDL display names use a bounded sentinel scan" {
    const max_len: usize = max_display_name_bytes;
    var exact: [max_len + 1]u8 = undefined;
    @memset(exact[0..max_len], 'x');
    exact[max_len] = 0;
    const name = try displayNameFromSentinel(exact[0..].ptr);
    try std.testing.expectEqual(max_len, name.slice().len);

    var missing: [max_len + 1]u8 = undefined;
    @memset(&missing, 'x');
    try std.testing.expectError(
        error.InvalidMonitorName,
        displayNameFromSentinel(missing[0..].ptr),
    );
}

test "SDL display transcript proves success and list cleanup" {
    const expected = [_]DisplayCall{
        .{ .operation = .query_displays },
        .{ .operation = .release_displays },
        .{ .operation = .query_name, .display_id = 7 },
        .{ .operation = .query_bounds, .display_id = 7 },
        .{ .operation = .query_scale, .display_id = 7 },
    };
    var transcript = try DisplayTranscript.init(expected[0..]);
    var displays = DisplayList{};
    displays.count = 1;
    displays.items[0] = 7;
    transcript.display_result = .{ .values = displays };
    transcript.names[0] = try DisplayName.init("DP-1");
    transcript.bounds[0] = try DisplayBounds.init(1920, 1080);
    transcript.scales[0] = 1.25;

    var io = SdlDisplayIo.fromTranscript(&transcript);
    _ = try io.queryDisplays();
    const facts = try io.queryFacts(7);
    try std.testing.expectEqualStrings("DP-1", facts.name.slice());
    try std.testing.expectEqual(@as(i32, 1920), facts.bounds.width);
    try std.testing.expectEqual(@as(f64, 1.25), facts.scale.?);
    try std.testing.expectEqual(@as(u32, 1), transcript.released_display_lists);
    try transcript.assertComplete();
}

test "SDL display transcript proves query and overbound failures" {
    {
        const expected = [_]DisplayCall{.{ .operation = .query_displays }};
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .null_result;
        var io = SdlDisplayIo.fromTranscript(&transcript);
        try std.testing.expectError(error.SdlMonitorQueryFailed, io.queryDisplays());
        try std.testing.expectEqual(@as(u32, 0), transcript.released_display_lists);
        try transcript.assertComplete();
    }
    {
        const expected = [_]DisplayCall{
            .{ .operation = .query_displays },
            .{ .operation = .release_displays },
        };
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .{ .invalid_count = -1 };
        var io = SdlDisplayIo.fromTranscript(&transcript);
        try std.testing.expectError(error.SdlMonitorQueryFailed, io.queryDisplays());
        try std.testing.expectEqual(@as(u32, 1), transcript.released_display_lists);
        try transcript.assertComplete();
    }
    {
        const expected = [_]DisplayCall{
            .{ .operation = .query_displays },
            .{ .operation = .release_displays },
        };
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .{ .invalid_count = @as(i64, max_displays) + 1 };
        var io = SdlDisplayIo.fromTranscript(&transcript);
        try std.testing.expectError(error.TooManyMonitors, io.queryDisplays());
        try std.testing.expectEqual(@as(u32, 1), transcript.released_display_lists);
        try transcript.assertComplete();
    }
    {
        const expected = [_]DisplayCall{
            .{ .operation = .query_displays },
            .{ .operation = .release_displays },
        };
        var transcript = try DisplayTranscript.init(expected[0..]);
        var displays = DisplayList{};
        displays.count = max_displays;
        transcript.display_result = .{ .values = displays };
        var io = SdlDisplayIo.fromTranscript(&transcript);
        _ = try io.queryDisplays();
        try transcript.assertComplete();
    }
}

test "SDL display transcript preserves exact fact failures" {
    const ids = [_]DisplayId{7};
    var displays = DisplayList{};
    displays.count = ids.len;
    displays.items[0] = ids[0];

    {
        const expected = [_]DisplayCall{.{ .operation = .query_name, .display_id = 7 }};
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .{ .values = displays };
        transcript.names[0] = null;
        var io = SdlDisplayIo.fromTranscript(&transcript);
        try std.testing.expectError(error.SdlMonitorNameMissing, io.queryFacts(7));
        try transcript.assertComplete();
    }
    {
        const expected = [_]DisplayCall{
            .{ .operation = .query_name, .display_id = 7 },
            .{ .operation = .query_bounds, .display_id = 7 },
        };
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .{ .values = displays };
        transcript.names[0] = try DisplayName.init("DP-1");
        transcript.bounds[0] = null;
        var io = SdlDisplayIo.fromTranscript(&transcript);
        try std.testing.expectError(error.SdlMonitorSizeMissing, io.queryFacts(7));
        try transcript.assertComplete();
    }
    {
        const expected = [_]DisplayCall{
            .{ .operation = .query_name, .display_id = 7 },
            .{ .operation = .query_bounds, .display_id = 7 },
            .{ .operation = .query_scale, .display_id = 7 },
        };
        var transcript = try DisplayTranscript.init(expected[0..]);
        transcript.display_result = .{ .values = displays };
        transcript.names[0] = try DisplayName.init("DP-1");
        transcript.bounds[0] = try DisplayBounds.init(1920, 1080);
        transcript.scales[0] = null;
        var io = SdlDisplayIo.fromTranscript(&transcript);
        const facts = try io.queryFacts(7);
        try std.testing.expect(facts.scale == null);
        try transcript.assertComplete();
    }
}

test "SDL display transcript rejects a malformed display count before indexing" {
    const expected = [_]DisplayCall{.{ .operation = .query_name, .display_id = 7 }};
    var transcript = try DisplayTranscript.init(expected[0..]);
    var displays = DisplayList{};
    displays.count = max_displays + 1;
    displays.items[0] = 7;
    transcript.display_result = .{ .values = displays };
    transcript.names[0] = try DisplayName.init("DP-1");

    var io = SdlDisplayIo.fromTranscript(&transcript);
    try std.testing.expectError(error.SdlMonitorNameMissing, io.queryName(7));
    try transcript.assertComplete();
}

test "SDL display transcript rejects an overlong expected record" {
    var expected: [max_transcript_operations + 1]DisplayCall = undefined;
    try std.testing.expectError(error.TranscriptTooLong, DisplayTranscript.init(expected[0..]));
}

test "SDL display transcript checks mismatch and exhaustion" {
    const expected = [_]DisplayCall{.{ .operation = .query_displays }};
    var transcript = try DisplayTranscript.init(expected[0..]);
    try std.testing.expectError(
        error.TranscriptUnexpectedOperation,
        transcript.record(.{ .operation = .query_name, .display_id = 7 }),
    );
    try transcript.record(.{ .operation = .query_displays });
    try std.testing.expectError(
        error.TranscriptExhausted,
        transcript.record(.{ .operation = .query_displays }),
    );
}
