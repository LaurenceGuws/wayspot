//! SDL display and window contracts own plain data and typed transcripts.

const std = @import("std");

/// max_displays bounds one SDL display query and its transcript facts.
pub const max_displays: u32 = 8;
/// max_display_name_bytes bounds one copied SDL display name.
pub const max_display_name_bytes: u32 = 96;
/// max_window_title_bytes bounds the sunglasses SDL window title.
pub const max_window_title_bytes: u32 = 160;
/// max_window_operations bounds one window/property transcript.
pub const max_window_operations: usize = 32;
/// max_window_ids bounds live local transcript ids for one surface.
pub const max_window_ids: u32 = 1;
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
    /// values is the copied valid display list.
    values: DisplayList,
    /// null_result models a null native display-list pointer with no free.
    null_result,
    /// invalid_count models a non-null list that must be freed before failure.
    invalid_count: i64,
};

/// DisplayNameResult owns one bounded transcript name or records a missing reply.
pub const DisplayNameResult = ?DisplayName;

/// DisplayBoundsResult is a typed transcript rectangle or a missing reply.
pub const DisplayBoundsResult = ?DisplayBounds;

/// DisplayScaleResult is a typed finite-scale reply or a missing reply.
pub const DisplayScaleResult = ?f32;

/// DisplayError is the exact result set shared by native and transcript display sources.
pub const DisplayError = error{
    SdlMonitorQueryFailed,
    TooManyMonitors,
    SdlMonitorNameMissing,
    InvalidMonitorName,
    SdlMonitorSizeMissing,
    InvalidMonitorSize,
    SdlMonitorScaleMissing,
};

/// NativeDisplaySource supplies display facts without exposing native types.
pub const NativeDisplaySource = struct {
    /// query_displays returns copied display ids and owns no native storage.
    query_displays: *const fn () DisplayError!DisplayList,
    /// query_name returns one copied bounded display name.
    query_name: *const fn (DisplayId) DisplayError!DisplayName,
    /// query_bounds returns one validated display rectangle.
    query_bounds: *const fn (DisplayId) DisplayError!DisplayBounds,
    /// query_scale returns one finite positive display scale.
    query_scale: *const fn (DisplayId) DisplayError!f64,
};

/// WindowError is the exact result set for the plain window/property seam.
pub const WindowError = error{
    SdlWindowFailed,
    SdlWindowPropertyMissing,
    SdlWindowSizeFailed,
    WaylandSurfaceUnavailable,
    InvalidWindowTitle,
    InvalidWindowSize,
    InvalidPropertyId,
    InvalidWindowId,
    InvalidWaylandIds,
};

/// WindowTitle owns one bounded SDL title without a sentinel or C pointer.
pub const WindowTitle = struct {
    /// bytes owns the title bytes without a sentinel.
    bytes: [max_window_title_bytes]u8 = undefined,
    /// len is the initialized title length and is at most 160.
    len: u32 = 0,

    /// init copies a non-empty title without embedded NUL bytes.
    pub fn init(text: []const u8) WindowError!WindowTitle {
        if (text.len == 0 or text.len > max_window_title_bytes) return error.InvalidWindowTitle;
        for (text) |byte| if (byte == 0) return error.InvalidWindowTitle;
        var title = WindowTitle{};
        @memcpy(title.bytes[0..text.len], text);
        title.len = @intCast(text.len);
        return title;
    }

    /// slice returns the retained title bytes.
    pub fn slice(self: *const WindowTitle) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// WindowSize owns positive SDL window dimensions.
pub const WindowSize = struct {
    /// width is the positive SDL window width.
    width: i32,
    /// height is the positive SDL window height.
    height: i32,

    /// init rejects zero and negative dimensions before a native call.
    pub fn init(width: i32, height: i32) WindowError!WindowSize {
        if (width <= 0 or height <= 0) return error.InvalidWindowSize;
        return .{ .width = width, .height = height };
    }
};

/// SdlPropertyId is a nonzero local transcript property token.
pub const SdlPropertyId = u32;
/// SdlWindowId is a nonzero local transcript window token.
pub const SdlWindowId = u32;
/// SdlWaylandHandleId is a nonzero plain token for one borrowed SDL handle.
pub const SdlWaylandHandleId = u32;
/// SdlWaylandIds carries plain tokens for SDL-provided Wayland handles.
pub const SdlWaylandIds = struct {
    /// display_id is the nonzero plain display token.
    display_id: SdlWaylandHandleId,
    /// surface_id is the nonzero plain surface token.
    surface_id: SdlWaylandHandleId,
};

/// SdlWindowCall is one exact typed property or window operation.
pub const SdlWindowCall = union(enum) {
    property_create,
    set_title: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// title carries the bounded title value.
        title: WindowTitle,
    },
    set_width: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// value is the positive requested width.
        value: i32,
    },
    set_height: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// value is the positive requested height.
        value: i32,
    },
    set_hidden: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// value is the requested hidden flag.
        value: bool,
    },
    set_custom_surface_role: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// value is the requested custom-role flag.
        value: bool,
    },
    set_create_egl_window: struct {
        /// property_id identifies the live property set.
        property_id: SdlPropertyId,
        /// value is the requested EGL-window flag.
        value: bool,
    },
    window_create: SdlPropertyId,
    window_properties: SdlWindowId,
    wayland_display_pointer: SdlPropertyId,
    wayland_surface_pointer: SdlPropertyId,
    window_resize: struct {
        /// window_id identifies the live window.
        window_id: SdlWindowId,
        /// size carries the positive requested size.
        size: WindowSize,
    },
    property_destroy: SdlPropertyId,
    window_destroy: SdlWindowId,
};

/// SdlWindowReply is a plain typed operation result or exact product error.
pub const SdlWindowReply = union(enum) {
    /// ok is a successful void operation reply.
    ok,
    /// property_id publishes the created property token.
    property_id: SdlPropertyId,
    /// window_id publishes the created window token.
    window_id: SdlWindowId,
    /// window_properties carries the borrowed SDL property-set token.
    window_properties: SdlPropertyId,
    /// wayland_handle carries one borrowed display or surface token.
    wayland_handle: SdlWaylandHandleId,
    /// failure carries the exact typed operation error.
    failure: WindowError,
};

fn validPropertyId(id: SdlPropertyId) bool {
    return id != 0 and id <= max_window_ids;
}

fn validWindowId(id: SdlWindowId) bool {
    return id != 0 and id <= max_window_ids;
}

fn validWaylandIds(ids: SdlWaylandIds) bool {
    return validWaylandHandleId(ids.display_id) and validWaylandHandleId(ids.surface_id);
}

fn validWaylandHandleId(id: SdlWaylandHandleId) bool {
    return id != 0 and id <= max_window_ids;
}

fn validWindowSize(size: WindowSize) bool {
    return size.width > 0 and size.height > 0;
}

/// SdlWindowTranscript owns a bounded operation record and typed replies.
pub const SdlWindowTranscript = struct {
    /// expected owns the fixed operation sequence.
    expected: [max_window_operations]SdlWindowCall = undefined,
    /// replies owns one typed reply slot for each operation slot.
    replies: [max_window_operations]SdlWindowReply = [_]SdlWindowReply{.ok} ** max_window_operations,
    /// expected_count is the initialized expected prefix length.
    expected_count: usize = 0,
    /// operation_count is the consumed operation count.
    operation_count: usize = 0,
    /// property_destroy_count proves property cleanup cardinality.
    property_destroy_count: usize = 0,
    /// window_destroy_count proves window cleanup cardinality.
    window_destroy_count: usize = 0,

    /// init copies a bounded transcript into fixed storage.
    pub fn init(expected: []const SdlWindowCall) TranscriptError!SdlWindowTranscript {
        if (expected.len > max_window_operations) return error.TranscriptTooLong;
        var transcript = SdlWindowTranscript{ .expected_count = expected.len };
        @memcpy(transcript.expected[0..expected.len], expected);
        return transcript;
    }

    /// assertComplete proves every expected operation was consumed.
    pub fn assertComplete(self: *const SdlWindowTranscript) TranscriptError!void {
        if (self.operation_count != self.expected_count) return error.TranscriptIncomplete;
    }

    fn next(self: *SdlWindowTranscript, call: SdlWindowCall) TranscriptError!SdlWindowReply {
        if (self.operation_count >= self.expected_count) return error.TranscriptExhausted;
        const expected = self.expected[self.operation_count];
        if (!std.meta.eql(expected, call)) return error.TranscriptUnexpectedOperation;
        const reply = self.replies[self.operation_count];
        self.operation_count += 1;
        switch (call) {
            .property_destroy => self.property_destroy_count += 1,
            .window_destroy => self.window_destroy_count += 1,
            else => {},
        }
        return reply;
    }

    fn nextForIo(self: *SdlWindowTranscript, call: SdlWindowCall) SdlWindowReply {
        return self.next(call) catch |err| {
            std.debug.panic("invalid SDL window transcript: {s}", .{@errorName(err)});
        };
    }
};

/// SdlWindowPropertyIo consumes a plain typed property transcript.
pub const SdlWindowPropertyIo = struct {
    /// transcript is the caller-owned fixed operation record.
    transcript: *SdlWindowTranscript,
    /// id is the nonzero local property token.
    id: SdlPropertyId,
    /// live gates every setter after the single cleanup operation.
    live: bool = true,

    /// create records one bounded property allocation and validates its id.
    pub fn create(transcript: *SdlWindowTranscript) WindowError!SdlWindowPropertyIo {
        return switch (transcript.nextForIo(.property_create)) {
            .property_id => |id| if (validPropertyId(id))
                .{ .transcript = transcript, .id = id }
            else
                error.InvalidPropertyId,
            .failure => |err| err,
            else => @panic("SDL property transcript returned the wrong reply"),
        };
    }

    /// setTitle records the bounded title setter.
    pub fn setTitle(self: *SdlWindowPropertyIo, title: WindowTitle) WindowError!void {
        try self.expectOk(.{ .set_title = .{ .property_id = self.id, .title = title } });
    }

    /// setWidth records the bounded width setter.
    pub fn setWidth(self: *SdlWindowPropertyIo, value: i32) WindowError!void {
        try self.ensureLive();
        if (value <= 0) return error.InvalidWindowSize;
        try self.expectOk(.{ .set_width = .{ .property_id = self.id, .value = value } });
    }

    /// setHeight records the bounded height setter.
    pub fn setHeight(self: *SdlWindowPropertyIo, value: i32) WindowError!void {
        try self.ensureLive();
        if (value <= 0) return error.InvalidWindowSize;
        try self.expectOk(.{ .set_height = .{ .property_id = self.id, .value = value } });
    }

    /// setHidden records the hidden property setter.
    pub fn setHidden(self: *SdlWindowPropertyIo, value: bool) WindowError!void {
        try self.expectOk(.{ .set_hidden = .{ .property_id = self.id, .value = value } });
    }

    /// setCustomSurfaceRole records the custom Wayland role setter.
    pub fn setCustomSurfaceRole(self: *SdlWindowPropertyIo, value: bool) WindowError!void {
        try self.expectOk(.{ .set_custom_surface_role = .{ .property_id = self.id, .value = value } });
    }

    /// setCreateEglWindow records the EGL-window property setter.
    pub fn setCreateEglWindow(self: *SdlWindowPropertyIo, value: bool) WindowError!void {
        try self.expectOk(.{ .set_create_egl_window = .{ .property_id = self.id, .value = value } });
    }

    /// deinit records exactly one property cleanup.
    pub fn deinit(self: *SdlWindowPropertyIo) void {
        if (!self.live) return;
        self.expectOk(.{ .property_destroy = self.id }) catch |err| {
            std.debug.panic("SDL property cleanup failed: {s}", .{@errorName(err)});
        };
        self.live = false;
    }

    fn expectOk(self: *SdlWindowPropertyIo, call: SdlWindowCall) WindowError!void {
        try self.ensureLive();
        return switch (self.transcript.nextForIo(call)) {
            .ok => {},
            .failure => |err| err,
            else => @panic("SDL property transcript returned the wrong reply"),
        };
    }

    fn ensureLive(self: *const SdlWindowPropertyIo) WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
    }
};

/// SdlWindowIo consumes a plain typed window transcript.
pub const SdlWindowIo = struct {
    /// transcript is the caller-owned fixed operation record.
    transcript: *SdlWindowTranscript,
    /// id is the nonzero local window token.
    id: SdlWindowId,
    /// live gates every window operation after the single cleanup operation.
    live: bool = true,

    /// create records one bounded window creation after property setup.
    pub fn create(transcript: *SdlWindowTranscript, properties: *const SdlWindowPropertyIo) WindowError!SdlWindowIo {
        if (properties.transcript != transcript or !properties.live or !validPropertyId(properties.id)) {
            return error.InvalidPropertyId;
        }
        return switch (transcript.nextForIo(.{ .window_create = properties.id })) {
            .window_id => |id| if (validWindowId(id))
                .{ .transcript = transcript, .id = id }
            else
                error.InvalidWindowId,
            .failure => |err| err,
            else => @panic("SDL window transcript returned the wrong reply"),
        };
    }

    /// waylandIds records the exact property and two pointer lookups.
    pub fn waylandIds(self: *SdlWindowIo) WindowError!SdlWaylandIds {
        try self.ensureLive();
        const properties_id: SdlPropertyId = switch (self.transcript.nextForIo(.{ .window_properties = self.id })) {
            .window_properties => |id| id,
            .failure => |err| return err,
            else => @panic("SDL Wayland transcript returned the wrong reply"),
        };
        if (!validPropertyId(properties_id)) return error.InvalidPropertyId;
        const display_id: SdlWaylandHandleId = switch (self.transcript.nextForIo(.{
            .wayland_display_pointer = properties_id,
        })) {
            .wayland_handle => |id| id,
            .failure => |err| return err,
            else => @panic("SDL Wayland transcript returned the wrong display reply"),
        };
        if (!validWaylandHandleId(display_id)) return error.InvalidWaylandIds;
        const surface_id: SdlWaylandHandleId = switch (self.transcript.nextForIo(.{
            .wayland_surface_pointer = properties_id,
        })) {
            .wayland_handle => |id| id,
            .failure => |err| return err,
            else => @panic("SDL Wayland transcript returned the wrong surface reply"),
        };
        if (!validWaylandHandleId(surface_id)) return error.InvalidWaylandIds;
        return .{ .display_id = display_id, .surface_id = surface_id };
    }

    /// resize records one positive window resize.
    pub fn resize(self: *SdlWindowIo, size: WindowSize) WindowError!void {
        try self.ensureLive();
        if (!validWindowSize(size)) return error.InvalidWindowSize;
        try self.expectOk(.{ .window_resize = .{ .window_id = self.id, .size = size } });
    }

    /// deinit records exactly one window cleanup.
    pub fn deinit(self: *SdlWindowIo) void {
        if (!self.live) return;
        self.expectOk(.{ .window_destroy = self.id }) catch |err| {
            std.debug.panic("SDL window cleanup failed: {s}", .{@errorName(err)});
        };
        self.live = false;
    }

    fn expectOk(self: *SdlWindowIo, call: SdlWindowCall) WindowError!void {
        try self.ensureLive();
        return switch (self.transcript.nextForIo(call)) {
            .ok => {},
            .failure => |err| err,
            else => @panic("SDL window transcript returned the wrong reply"),
        };
    }

    fn ensureLive(self: *const SdlWindowIo) WindowError!void {
        if (!self.live) return error.InvalidWindowId;
    }
};

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
        native: NativeDisplaySource,
        transcript: *DisplayTranscript,
    };

    /// native selects a production source without importing native types.
    pub fn native(source: NativeDisplaySource) SdlDisplayIo {
        return .{ .source = .{ .native = source } };
    }

    /// fromTranscript selects one caller-owned fixed transcript.
    pub fn fromTranscript(transcript: *DisplayTranscript) SdlDisplayIo {
        return .{ .source = .{ .transcript = transcript } };
    }

    /// queryDisplays returns bounded ids and records the native list cleanup.
    pub fn queryDisplays(self: *SdlDisplayIo) !DisplayList {
        return switch (self.source) {
            .native => |source| source.query_displays(),
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
            else => |other| return other,
        };
        return .{ .id = id, .name = name, .bounds = bounds, .scale = scale };
    }

    /// queryName returns one validated plain display name.
    pub fn queryName(self: *SdlDisplayIo, id: DisplayId) !DisplayName {
        return switch (self.source) {
            .native => |source| source.query_name(id),
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
            .native => |source| source.query_bounds(id),
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
            .native => |source| source.query_scale(id),
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

/// mapDisplayCount validates one native display count without narrowing first.
pub fn mapDisplayCount(raw_count: i64) DisplayError!u32 {
    if (raw_count < 0) return error.SdlMonitorQueryFailed;
    if (raw_count > @as(i64, max_displays)) return error.TooManyMonitors;
    return @intCast(raw_count);
}

/// mapDisplayScale validates one finite positive display scale.
pub fn mapDisplayScale(value: f32) DisplayError!f64 {
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

test "SDL display names retain the exact bounded bytes" {
    const max_len: usize = max_display_name_bytes;
    var exact: [max_len + 1]u8 = undefined;
    @memset(exact[0..max_len], 'x');
    exact[max_len] = 0;
    const name = try DisplayName.init(exact[0..max_len]);
    try std.testing.expectEqual(max_len, name.slice().len);

    var missing: [max_len + 1]u8 = undefined;
    @memset(&missing, 'x');
    try std.testing.expectError(
        error.InvalidMonitorName,
        DisplayName.init(missing[0..]),
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

test "SDL property mock rejects every operation after deinit" {
    const title = try WindowTitle.init("title");
    const expected = [_]SdlWindowCall{ .property_create, .{ .property_destroy = 1 } };
    var transcript = try SdlWindowTranscript.init(&expected);
    transcript.replies[0] = .{ .property_id = 1 };
    var properties = try SdlWindowPropertyIo.create(&transcript);
    properties.deinit();

    try std.testing.expectError(error.InvalidPropertyId, properties.setTitle(title));
    try std.testing.expectError(error.InvalidPropertyId, properties.setWidth(1));
    try std.testing.expectError(error.InvalidPropertyId, properties.setHeight(1));
    try std.testing.expectError(error.InvalidPropertyId, properties.setHidden(true));
    try std.testing.expectError(error.InvalidPropertyId, properties.setCustomSurfaceRole(true));
    try std.testing.expectError(error.InvalidPropertyId, properties.setCreateEglWindow(true));
    try transcript.assertComplete();
}

test "SDL property mock validates positive dimensions before recording" {
    const expected = [_]SdlWindowCall{ .property_create, .{ .property_destroy = 1 } };
    var transcript = try SdlWindowTranscript.init(&expected);
    transcript.replies[0] = .{ .property_id = 1 };
    var properties = try SdlWindowPropertyIo.create(&transcript);

    try std.testing.expectError(error.InvalidWindowSize, properties.setWidth(0));
    try std.testing.expectError(error.InvalidWindowSize, properties.setHeight(-1));
    try std.testing.expectEqual(@as(usize, 1), transcript.operation_count);
    properties.deinit();
    try transcript.assertComplete();
}

test "SDL window mock rejects use after deinit and foreign properties" {
    const expected = [_]SdlWindowCall{
        .property_create,
        .{ .window_create = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_destroy = 1 },
        .{ .property_destroy = 1 },
    };
    var transcript = try SdlWindowTranscript.init(&expected);
    transcript.replies[0] = .{ .property_id = 1 };
    transcript.replies[1] = .{ .window_id = 1 };
    transcript.replies[2] = .{ .window_properties = 1 };
    transcript.replies[3] = .{ .wayland_handle = 1 };
    transcript.replies[4] = .{ .wayland_handle = 1 };
    var properties = try SdlWindowPropertyIo.create(&transcript);
    var foreign_transcript = try SdlWindowTranscript.init(&[_]SdlWindowCall{});
    try std.testing.expectError(
        error.InvalidPropertyId,
        SdlWindowIo.create(&foreign_transcript, &properties),
    );

    var window = try SdlWindowIo.create(&transcript, &properties);
    try std.testing.expectEqual(
        SdlWaylandIds{ .display_id = 1, .surface_id = 1 },
        try window.waylandIds(),
    );
    window.deinit();
    try std.testing.expectError(error.InvalidWindowId, window.waylandIds());
    try std.testing.expectError(
        error.InvalidWindowId,
        window.resize(try WindowSize.init(1, 1)),
    );
    properties.deinit();
    try transcript.assertComplete();
    try foreign_transcript.assertComplete();
}

test "SDL window handle bridge preserves exact lookup failures" {
    {
        const expected = [_]SdlWindowCall{
            .property_create,
            .{ .window_create = 1 },
            .{ .window_properties = 1 },
            .{ .window_destroy = 1 },
            .{ .property_destroy = 1 },
        };
        var transcript = try SdlWindowTranscript.init(&expected);
        transcript.replies[0] = .{ .property_id = 1 };
        transcript.replies[1] = .{ .window_id = 1 };
        transcript.replies[2] = .{ .failure = error.SdlWindowPropertyMissing };
        var properties = try SdlWindowPropertyIo.create(&transcript);
        var window = try SdlWindowIo.create(&transcript, &properties);
        try std.testing.expectError(error.SdlWindowPropertyMissing, window.waylandIds());
        window.deinit();
        properties.deinit();
        try transcript.assertComplete();
    }
    {
        const expected = [_]SdlWindowCall{
            .property_create,
            .{ .window_create = 1 },
            .{ .window_properties = 1 },
            .{ .wayland_display_pointer = 1 },
            .{ .window_destroy = 1 },
            .{ .property_destroy = 1 },
        };
        var transcript = try SdlWindowTranscript.init(&expected);
        transcript.replies[0] = .{ .property_id = 1 };
        transcript.replies[1] = .{ .window_id = 1 };
        transcript.replies[2] = .{ .window_properties = 1 };
        transcript.replies[3] = .{ .failure = error.WaylandSurfaceUnavailable };
        var properties = try SdlWindowPropertyIo.create(&transcript);
        var window = try SdlWindowIo.create(&transcript, &properties);
        try std.testing.expectError(error.WaylandSurfaceUnavailable, window.waylandIds());
        window.deinit();
        properties.deinit();
        try transcript.assertComplete();
    }
    {
        const expected = [_]SdlWindowCall{
            .property_create,
            .{ .window_create = 1 },
            .{ .window_properties = 1 },
            .{ .wayland_display_pointer = 1 },
            .{ .wayland_surface_pointer = 1 },
            .{ .window_destroy = 1 },
            .{ .property_destroy = 1 },
        };
        var transcript = try SdlWindowTranscript.init(&expected);
        transcript.replies[0] = .{ .property_id = 1 };
        transcript.replies[1] = .{ .window_id = 1 };
        transcript.replies[2] = .{ .window_properties = 1 };
        transcript.replies[3] = .{ .wayland_handle = 1 };
        transcript.replies[4] = .{ .failure = error.WaylandSurfaceUnavailable };
        var properties = try SdlWindowPropertyIo.create(&transcript);
        var window = try SdlWindowIo.create(&transcript, &properties);
        try std.testing.expectError(error.WaylandSurfaceUnavailable, window.waylandIds());
        window.deinit();
        properties.deinit();
        try transcript.assertComplete();
    }
}
