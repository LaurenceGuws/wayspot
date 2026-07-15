//! Wayland layer contracts own plain values and exact typed transcripts.

const std = @import("std");
const sdl_io = @import("sdl_io");

/// max_wayland_operations bounds one layer setup transcript.
pub const max_wayland_operations: usize = 32;
/// max_wayland_ids bounds one simulated surface and its local tokens.
pub const max_wayland_ids: u32 = 1;
/// max_wayland_outputs bounds one compositor output list.
pub const max_wayland_outputs: u32 = 8;
/// max_wayland_anchor is the four-bit layer anchor mask.
pub const max_wayland_anchor: u32 = 15;
/// max_wayland_dimension matches the positive SDL window dimension bound.
pub const max_wayland_dimension: u32 = @intCast(std.math.maxInt(i32));

/// WaylandDisplayId is a nonzero local transcript display token.
pub const WaylandDisplayId = u32;
/// WaylandOutputId is a nonzero local transcript output token.
pub const WaylandOutputId = u32;
/// WaylandSurfaceId is a nonzero local transcript surface token.
pub const WaylandSurfaceId = u32;
/// LayerSurfaceId is a nonzero local transcript layer token.
pub const LayerSurfaceId = u32;

/// LayerNamespace is the fixed namespace used by the sunglasses layer.
pub const LayerNamespace = enum {
    sunglasses,
};

/// LayerValue is the bounded native layer value for the sunglasses overlay.
pub const LayerValue = struct {
    /// raw_value is the validated native layer value.
    raw_value: u32,

    /// init accepts only the active sunglasses layer value.
    pub fn init(raw_value: u32) WaylandError!LayerValue {
        if (raw_value != 3) return error.InvalidWaylandLayerValue;
        return .{ .raw_value = raw_value };
    }

    /// sunglasses returns the one active layer value.
    pub fn sunglasses() LayerValue {
        return .{ .raw_value = 3 };
    }

    /// raw returns the value passed to the native layer wrapper.
    pub fn raw(self: LayerValue) u32 {
        return self.raw_value;
    }
};

const ProtocolPhase = enum {
    new,
    await_output,
    await_layer,
    await_listener,
    await_size,
    await_anchor,
    await_exclusive_zone,
    await_keyboard,
    await_empty_input,
    await_first_commit,
    await_first_roundtrip,
    await_ack,
    await_second_commit,
    await_second_roundtrip,
    ready,
    destroyed,
    await_globals_deinit,
    deinitialized,
};

/// ConfigureFacts contains plain layer configure results.
pub const ConfigureFacts = struct {
    /// configured is true after the compositor supplies an initial configure.
    configured: bool,
    /// closed is true when the compositor closes the layer before configure.
    closed: bool,
    /// serial is the compositor configure serial.
    serial: u32,
    /// width is the configured plain width.
    width: u32,
    /// height is the configured plain height.
    height: u32,
};

/// WaylandError is the exact layer/display/surface transcript result set.
pub const WaylandError = error{
    WaylandSurfaceUnavailable,
    LayerShellRegistryFailed,
    LayerShellRegistryListenerFailed,
    LayerShellRoundtripFailed,
    LayerShellMissing,
    LayerShellCompositorMissing,
    LayerShellShmMissing,
    LayerShellOutputMissing,
    LayerShellSurfaceCreateFailed,
    LayerShellInputRegionFailed,
    LayerShellConfigureFailed,
    LayerShellClosed,
    LayerShellUnexpectedResult,
    SdlWindowSizeFailed,
    InvalidWaylandId,
    InvalidWaylandOutput,
    InvalidLayerSurface,
    WaylandGlobalsNotInitialized,
    WaylandGlobalsAlreadyInitialized,
    WaylandLayerNotCreated,
    WaylandLayerAlreadyCreated,
    WaylandLayerDestroyed,
    WaylandCleanupOutOfOrder,
    WaylandIoDeinitialized,
    InvalidWaylandAnchor,
    InvalidWaylandLayerValue,
    InvalidConfigureFacts,
    WaylandProtocolOutOfOrder,
    WaylandOutputNotSelected,
    WaylandConfigureSerialMismatch,
};

/// WaylandCall is one exact typed layer/display/surface operation.
pub const WaylandCall = union(enum) {
    /// globals_init identifies the borrowed display token.
    globals_init: WaylandDisplayId,
    /// find_output carries one owned bounded display name.
    find_output: sdl_io.DisplayName,
    create_layer_surface: struct {
        /// surface_id identifies the borrowed surface token.
        surface_id: WaylandSurfaceId,
        /// output_id identifies the selected output token.
        output_id: WaylandOutputId,
        /// layer identifies the bounded native layer value.
        layer: LayerValue,
        /// namespace selects the fixed layer namespace.
        namespace: LayerNamespace,
    },
    /// add_listener identifies the live layer token.
    add_listener: LayerSurfaceId,
    set_size: struct {
        /// layer_id identifies the live layer token.
        layer_id: LayerSurfaceId,
        /// size is the positive requested window size.
        size: sdl_io.WindowSize,
    },
    set_anchor: struct {
        /// layer_id identifies the live layer token.
        layer_id: LayerSurfaceId,
        /// anchor is the fixed layer anchor mask.
        anchor: u32,
    },
    set_exclusive_zone: struct {
        /// layer_id identifies the live layer token.
        layer_id: LayerSurfaceId,
        /// zone is the requested exclusive zone.
        zone: i32,
    },
    set_keyboard_interactivity: struct {
        /// layer_id identifies the live layer token.
        layer_id: LayerSurfaceId,
        /// enabled is the requested keyboard interactivity flag.
        enabled: bool,
    },
    /// set_empty_input_region identifies the borrowed surface token.
    set_empty_input_region: WaylandSurfaceId,
    /// commit identifies the borrowed surface token.
    commit: WaylandSurfaceId,
    /// roundtrip identifies the borrowed display token.
    roundtrip: WaylandDisplayId,
    ack_configure: struct {
        /// layer_id identifies the live layer token.
        layer_id: LayerSurfaceId,
        /// serial is the acknowledged configure serial.
        serial: u32,
    },
    /// destroy_layer_surface identifies the live layer token.
    destroy_layer_surface: LayerSurfaceId,
    /// roundtrip_cleanup identifies the borrowed display token.
    roundtrip_cleanup: WaylandDisplayId,
    /// globals_deinit identifies the borrowed display token.
    globals_deinit: WaylandDisplayId,
};

/// WaylandReply is a plain typed operation result or exact layer error.
pub const WaylandReply = union(enum) {
    /// ok is a successful void operation reply.
    ok,
    /// output_id publishes one selected output token.
    output_id: WaylandOutputId,
    /// layer_id publishes one created layer token.
    layer_id: LayerSurfaceId,
    /// configure carries one typed configure result.
    configure: ConfigureFacts,
    /// failure carries the exact typed operation error.
    failure: WaylandError,
};

/// WaylandTranscript owns a bounded operation record and typed replies.
pub const WaylandTranscript = struct {
    /// expected owns the fixed operation sequence.
    expected: [max_wayland_operations]WaylandCall = undefined,
    /// replies owns one typed reply slot for each operation slot.
    replies: [max_wayland_operations]WaylandReply = [_]WaylandReply{.ok} ** max_wayland_operations,
    /// expected_count is the initialized expected prefix length.
    expected_count: usize = 0,
    /// operation_count is the consumed operation count.
    operation_count: usize = 0,
    /// layer_destroy_count proves layer cleanup cardinality.
    layer_destroy_count: usize = 0,
    /// globals_deinit_count proves globals cleanup cardinality.
    globals_deinit_count: usize = 0,

    /// init copies one bounded transcript into fixed storage.
    pub fn init(expected: []const WaylandCall) sdl_io.TranscriptError!WaylandTranscript {
        if (expected.len > max_wayland_operations) return error.TranscriptTooLong;
        var transcript = WaylandTranscript{ .expected_count = expected.len };
        @memcpy(transcript.expected[0..expected.len], expected);
        return transcript;
    }

    /// assertComplete proves every expected operation was consumed.
    pub fn assertComplete(self: *const WaylandTranscript) sdl_io.TranscriptError!void {
        if (self.operation_count != self.expected_count) return error.TranscriptIncomplete;
    }

    fn next(self: *WaylandTranscript, call: WaylandCall) sdl_io.TranscriptError!WaylandReply {
        if (self.operation_count >= self.expected_count) return error.TranscriptExhausted;
        const expected = self.expected[self.operation_count];
        if (!std.meta.eql(expected, call)) return error.TranscriptUnexpectedOperation;
        const reply = self.replies[self.operation_count];
        self.operation_count += 1;
        switch (call) {
            .destroy_layer_surface => self.layer_destroy_count += 1,
            .globals_deinit => self.globals_deinit_count += 1,
            else => {},
        }
        return reply;
    }

    fn nextForIo(self: *WaylandTranscript, call: WaylandCall) WaylandReply {
        return self.next(call) catch |err| {
            std.debug.panic("invalid Wayland transcript: {s}", .{@errorName(err)});
        };
    }
};

/// WaylandIo consumes the plain layer transcript without native imports.
pub const WaylandIo = struct {
    /// transcript is the caller-owned fixed operation record.
    transcript: *WaylandTranscript,
    /// globals_live proves the compositor-global owner is initialized.
    globals_live: bool = false,
    /// layer_id is the one live layer owned after creation succeeds.
    layer_id: ?LayerSurfaceId = null,
    /// layer_was_created distinguishes no layer after failed create from destroy.
    layer_was_created: bool = false,
    /// roundtrip_cleaned proves the required flush after layer destruction.
    roundtrip_cleaned: bool = false,
    /// deinitialized rejects reuse after global cleanup.
    deinitialized: bool = false,
    /// protocol_phase enforces the one ordered sunglasses setup protocol.
    protocol_phase: ProtocolPhase = .new,
    /// selected_output is published only by a successful findOutput call.
    selected_output: ?WaylandOutputId = null,
    /// configured_serial is published only by a valid first configure reply.
    configured_serial: ?u32 = null,

    /// fromTranscript selects one caller-owned fixed transcript.
    pub fn fromTranscript(transcript: *WaylandTranscript) WaylandIo {
        return .{ .transcript = transcript };
    }

    /// globalsInit records compositor-global setup.
    pub fn globalsInit(self: *WaylandIo, display_id: WaylandDisplayId) WaylandError!void {
        if (self.deinitialized) return error.WaylandIoDeinitialized;
        if (self.globals_live) return error.WaylandGlobalsAlreadyInitialized;
        if (!validDisplayId(display_id)) return error.InvalidWaylandId;
        try self.expectOk(.{ .globals_init = display_id });
        self.globals_live = true;
        self.protocol_phase = .await_output;
    }

    /// findOutput records one bounded monitor-name lookup.
    pub fn findOutput(self: *WaylandIo, name: sdl_io.DisplayName) WaylandError!WaylandOutputId {
        try self.requireOutputPhase();
        return switch (self.transcript.nextForIo(.{ .find_output = name })) {
            .output_id => |id| blk: {
                if (!validOutputId(id)) break :blk error.InvalidWaylandOutput;
                self.selected_output = id;
                self.protocol_phase = .await_layer;
                break :blk id;
            },
            .failure => |err| err,
            else => @panic("Wayland transcript returned the wrong output reply"),
        };
    }

    /// createLayerSurface records one layer-surface creation.
    pub fn createLayerSurface(
        self: *WaylandIo,
        surface_id: WaylandSurfaceId,
        output_id: WaylandOutputId,
        layer: LayerValue,
        namespace: LayerNamespace,
    ) WaylandError!LayerSurfaceId {
        if (!validSurfaceId(surface_id)) return error.InvalidWaylandId;
        if (!validOutputId(output_id)) return error.InvalidWaylandOutput;
        try self.requireGlobals();
        if (self.protocol_phase == .destroyed or self.protocol_phase == .await_globals_deinit) {
            return error.WaylandLayerDestroyed;
        }
        if (self.layer_id != null) return error.WaylandLayerAlreadyCreated;
        if (self.selected_output != output_id) return error.WaylandOutputNotSelected;
        if (self.protocol_phase != .await_layer) return error.WaylandProtocolOutOfOrder;
        return switch (self.transcript.nextForIo(.{ .create_layer_surface = .{
            .surface_id = surface_id,
            .output_id = output_id,
            .layer = layer,
            .namespace = namespace,
        } })) {
            .layer_id => |id| blk: {
                if (!validLayerId(id)) break :blk error.InvalidLayerSurface;
                self.layer_id = id;
                self.layer_was_created = true;
                self.protocol_phase = .await_listener;
                break :blk id;
            },
            .failure => |err| err,
            else => @panic("Wayland transcript returned the wrong layer reply"),
        };
    }

    /// addListener records the configure listener installation.
    pub fn addListener(self: *WaylandIo, layer_id: LayerSurfaceId) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_listener);
        try self.expectOk(.{ .add_listener = layer_id });
        self.protocol_phase = .await_size;
    }

    /// setSize records one positive layer size.
    pub fn setSize(self: *WaylandIo, layer_id: LayerSurfaceId, size: sdl_io.WindowSize) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_size);
        if (size.width <= 0 or size.height <= 0) return error.SdlWindowSizeFailed;
        try self.expectOk(.{ .set_size = .{ .layer_id = layer_id, .size = size } });
        self.protocol_phase = .await_anchor;
    }

    /// setAnchor records one layer anchor mask.
    pub fn setAnchor(self: *WaylandIo, layer_id: LayerSurfaceId, anchor: u32) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_anchor);
        if (anchor == 0 or anchor > max_wayland_anchor) return error.InvalidWaylandAnchor;
        try self.expectOk(.{ .set_anchor = .{ .layer_id = layer_id, .anchor = anchor } });
        self.protocol_phase = .await_exclusive_zone;
    }

    /// setExclusiveZone records one layer exclusive zone.
    pub fn setExclusiveZone(self: *WaylandIo, layer_id: LayerSurfaceId, zone: i32) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_exclusive_zone);
        try self.expectOk(.{ .set_exclusive_zone = .{ .layer_id = layer_id, .zone = zone } });
        self.protocol_phase = .await_keyboard;
    }

    /// setKeyboardInteractivity records one keyboard mode.
    pub fn setKeyboardInteractivity(self: *WaylandIo, layer_id: LayerSurfaceId, enabled: bool) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_keyboard);
        try self.expectOk(.{ .set_keyboard_interactivity = .{ .layer_id = layer_id, .enabled = enabled } });
        self.protocol_phase = .await_empty_input;
    }

    /// setEmptyInputRegion records the input-region operation.
    pub fn setEmptyInputRegion(self: *WaylandIo, surface_id: WaylandSurfaceId) WaylandError!void {
        try self.requireSurfacePhase(surface_id, .await_empty_input);
        try self.expectOk(.{ .set_empty_input_region = surface_id });
        self.protocol_phase = .await_first_commit;
    }

    /// commit records one surface commit.
    pub fn commit(self: *WaylandIo, surface_id: WaylandSurfaceId) WaylandError!void {
        try self.requireSurface(surface_id);
        switch (self.protocol_phase) {
            .await_first_commit, .await_second_commit => {},
            else => return error.WaylandProtocolOutOfOrder,
        }
        try self.expectOk(.{ .commit = surface_id });
        self.protocol_phase = switch (self.protocol_phase) {
            .await_first_commit => .await_first_roundtrip,
            .await_second_commit => .await_second_roundtrip,
            else => unreachable,
        };
    }

    /// roundtrip records one configure reply.
    pub fn roundtrip(self: *WaylandIo, display_id: WaylandDisplayId) WaylandError!ConfigureFacts {
        try self.requireGlobals();
        try self.requireCurrentLayer();
        switch (self.protocol_phase) {
            .await_first_roundtrip, .await_second_roundtrip => {},
            else => return error.WaylandProtocolOutOfOrder,
        }
        if (!validDisplayId(display_id)) return error.InvalidWaylandId;
        return switch (self.transcript.nextForIo(.{ .roundtrip = display_id })) {
            .configure => |facts| {
                try validateConfigureFacts(facts);
                if (facts.closed) return error.LayerShellClosed;
                if (!facts.configured) return error.InvalidConfigureFacts;
                if (self.protocol_phase == .await_first_roundtrip) {
                    self.configured_serial = facts.serial;
                    self.protocol_phase = .await_ack;
                } else {
                    self.protocol_phase = .ready;
                }
                return facts;
            },
            .failure => |err| err,
            else => @panic("Wayland transcript returned the wrong configure reply"),
        };
    }

    /// ackConfigure records one configure acknowledgement.
    pub fn ackConfigure(self: *WaylandIo, layer_id: LayerSurfaceId, serial: u32) WaylandError!void {
        try self.requireLayerPhase(layer_id, .await_ack);
        if (serial == 0) return error.InvalidConfigureFacts;
        if (self.configured_serial != serial) return error.WaylandConfigureSerialMismatch;
        try self.expectOk(.{ .ack_configure = .{ .layer_id = layer_id, .serial = serial } });
        self.protocol_phase = .await_second_commit;
    }

    /// destroyLayerSurface records one layer cleanup.
    pub fn destroyLayerSurface(self: *WaylandIo, layer_id: LayerSurfaceId) WaylandError!void {
        try self.requireLayer(layer_id);
        try self.expectOk(.{ .destroy_layer_surface = layer_id });
        self.layer_id = null;
        self.protocol_phase = .destroyed;
    }

    /// roundtripCleanup records one borrowed-display flush.
    pub fn roundtripCleanup(self: *WaylandIo, display_id: WaylandDisplayId) WaylandError!void {
        try self.requireGlobals();
        if (!self.layer_was_created or self.layer_id != null) return error.WaylandCleanupOutOfOrder;
        if (self.roundtrip_cleaned) return error.WaylandCleanupOutOfOrder;
        if (self.protocol_phase != .destroyed) return error.WaylandCleanupOutOfOrder;
        if (!validDisplayId(display_id)) return error.InvalidWaylandId;
        try self.expectOk(.{ .roundtrip_cleanup = display_id });
        self.roundtrip_cleaned = true;
        self.protocol_phase = .await_globals_deinit;
    }

    /// globalsDeinit records one compositor-global cleanup.
    pub fn globalsDeinit(self: *WaylandIo, display_id: WaylandDisplayId) WaylandError!void {
        if (self.deinitialized) return error.WaylandIoDeinitialized;
        try self.requireGlobals();
        if (self.layer_id != null) return error.WaylandCleanupOutOfOrder;
        if (self.layer_was_created and !self.roundtrip_cleaned) {
            return error.WaylandCleanupOutOfOrder;
        }
        if (self.layer_was_created and self.protocol_phase != .await_globals_deinit) {
            return error.WaylandCleanupOutOfOrder;
        }
        if (!validDisplayId(display_id)) return error.InvalidWaylandId;
        try self.expectOk(.{ .globals_deinit = display_id });
        self.globals_live = false;
        self.deinitialized = true;
        self.protocol_phase = .deinitialized;
    }

    fn expectOk(self: *WaylandIo, call: WaylandCall) WaylandError!void {
        return switch (self.transcript.nextForIo(call)) {
            .ok => {},
            .failure => |err| err,
            else => @panic("Wayland transcript returned the wrong void reply"),
        };
    }

    fn requireGlobals(self: *const WaylandIo) WaylandError!void {
        if (self.deinitialized) return error.WaylandIoDeinitialized;
        if (!self.globals_live) return error.WaylandGlobalsNotInitialized;
    }

    fn requireOutputPhase(self: *const WaylandIo) WaylandError!void {
        try self.requireGlobals();
        switch (self.protocol_phase) {
            .await_output => {},
            .destroyed, .await_globals_deinit => return error.WaylandLayerDestroyed,
            else => {
                if (self.layer_id != null) return error.WaylandLayerAlreadyCreated;
                return error.WaylandProtocolOutOfOrder;
            },
        }
    }

    fn requireLayer(self: *const WaylandIo, layer_id: LayerSurfaceId) WaylandError!void {
        if (!validLayerId(layer_id)) return error.InvalidLayerSurface;
        try self.requireGlobals();
        const active = self.layer_id orelse {
            return if (self.layer_was_created)
                error.WaylandLayerDestroyed
            else
                error.WaylandLayerNotCreated;
        };
        if (active != layer_id) return error.InvalidLayerSurface;
    }

    fn requireLayerPhase(
        self: *const WaylandIo,
        layer_id: LayerSurfaceId,
        expected: ProtocolPhase,
    ) WaylandError!void {
        try self.requireLayer(layer_id);
        if (self.protocol_phase != expected) return error.WaylandProtocolOutOfOrder;
    }

    fn requireCurrentLayer(self: *const WaylandIo) WaylandError!void {
        const layer_id = self.layer_id orelse {
            return if (self.layer_was_created)
                error.WaylandLayerDestroyed
            else
                error.WaylandLayerNotCreated;
        };
        try self.requireLayer(layer_id);
    }

    fn requireSurface(self: *const WaylandIo, surface_id: WaylandSurfaceId) WaylandError!void {
        if (!validSurfaceId(surface_id)) return error.InvalidWaylandId;
        try self.requireGlobals();
        if (self.layer_id == null) {
            return if (self.layer_was_created)
                error.WaylandLayerDestroyed
            else
                error.WaylandLayerNotCreated;
        }
    }

    fn requireSurfacePhase(
        self: *const WaylandIo,
        surface_id: WaylandSurfaceId,
        expected: ProtocolPhase,
    ) WaylandError!void {
        try self.requireSurface(surface_id);
        if (self.protocol_phase != expected) return error.WaylandProtocolOutOfOrder;
    }
};

fn validDisplayId(id: WaylandDisplayId) bool {
    return id != 0 and id <= max_wayland_ids;
}

fn validSurfaceId(id: WaylandSurfaceId) bool {
    return id != 0 and id <= max_wayland_ids;
}

fn validLayerId(id: LayerSurfaceId) bool {
    return id != 0 and id <= max_wayland_ids;
}

fn validOutputId(id: WaylandOutputId) bool {
    return id != 0 and id <= max_wayland_outputs;
}

/// validateConfigureFacts applies the bounded configure contract to any adapter.
pub fn validateConfigureFacts(facts: ConfigureFacts) WaylandError!void {
    if (facts.configured) {
        if (facts.closed or facts.serial == 0 or facts.width == 0 or facts.height == 0) {
            return error.InvalidConfigureFacts;
        }
        if (facts.width > max_wayland_dimension or facts.height > max_wayland_dimension) {
            return error.InvalidConfigureFacts;
        }
        return;
    }
    if (!facts.closed or facts.serial != 0 or facts.width != 0 or facts.height != 0) {
        return error.InvalidConfigureFacts;
    }
}

test "Wayland transcript proves exact setup and reverse cleanup" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const size = try sdl_io.WindowSize.init(1920, 1080);
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    transcript.replies[10] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
    var io = WaylandIo.fromTranscript(&transcript);
    try io.globalsInit(1);
    const output = try io.findOutput(monitor_name);
    const layer = try io.createLayerSurface(1, output, .sunglasses(), .sunglasses);
    try io.addListener(layer);
    try io.setSize(layer, size);
    try io.setAnchor(layer, 15);
    try io.setExclusiveZone(layer, -1);
    try io.setKeyboardInteractivity(layer, false);
    try io.setEmptyInputRegion(1);
    try io.commit(1);
    const configure = try io.roundtrip(1);
    try std.testing.expect(configure.configured);
    try io.ackConfigure(layer, configure.serial);
    try io.destroyLayerSurface(layer);
    try io.roundtripCleanup(1);
    try io.globalsDeinit(1);
    try transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), transcript.globals_deinit_count);
}

test "Wayland transcript rejects invalid local ids" {
    var transcript = try WaylandTranscript.init(&[_]WaylandCall{});
    var io = WaylandIo.fromTranscript(&transcript);
    try std.testing.expectError(error.InvalidWaylandId, io.globalsInit(0));
    try std.testing.expectError(
        error.InvalidWaylandOutput,
        io.createLayerSurface(1, 0, .sunglasses(), .sunglasses),
    );
}

test "Wayland layer value rejects unknown values and preserves identity" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const layer_value = LayerValue.sunglasses();
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = layer_value,
            .namespace = .sunglasses,
        } },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    var io = WaylandIo.fromTranscript(&transcript);
    try std.testing.expectError(error.InvalidWaylandLayerValue, LayerValue.init(2));
    try io.globalsInit(1);
    _ = try io.findOutput(monitor_name);
    const layer_id = try io.createLayerSurface(1, 1, layer_value, .sunglasses);
    try std.testing.expectEqual(layer_value, transcript.expected[2].create_layer_surface.layer);
    try io.destroyLayerSurface(layer_id);
    try io.roundtripCleanup(1);
    try io.globalsDeinit(1);
    try transcript.assertComplete();
}

test "Wayland mock rejects skipped and repeated protocol calls" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const size = try sdl_io.WindowSize.init(1920, 1080);
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    transcript.replies[10] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
    transcript.replies[13] = transcript.replies[10];
    var io = WaylandIo.fromTranscript(&transcript);

    try std.testing.expectError(error.WaylandGlobalsNotInitialized, io.findOutput(monitor_name));
    try std.testing.expectEqual(@as(usize, 0), transcript.operation_count);
    try io.globalsInit(1);
    try std.testing.expectError(error.WaylandGlobalsAlreadyInitialized, io.globalsInit(1));
    try std.testing.expectEqual(@as(usize, 1), transcript.operation_count);
    try std.testing.expectError(
        error.WaylandOutputNotSelected,
        io.createLayerSurface(1, 1, .sunglasses(), .sunglasses),
    );
    try std.testing.expectEqual(@as(usize, 1), transcript.operation_count);
    _ = try io.findOutput(monitor_name);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.findOutput(monitor_name));
    try std.testing.expectEqual(@as(usize, 2), transcript.operation_count);
    const layer = try io.createLayerSurface(1, 1, .sunglasses(), .sunglasses);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.setSize(layer, size));
    try std.testing.expectEqual(@as(usize, 3), transcript.operation_count);
    try io.addListener(layer);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.addListener(layer));
    try std.testing.expectEqual(@as(usize, 4), transcript.operation_count);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.setAnchor(layer, 15));
    try std.testing.expectEqual(@as(usize, 4), transcript.operation_count);
    try io.setSize(layer, size);
    try io.setAnchor(layer, 15);
    try io.setExclusiveZone(layer, -1);
    try io.setKeyboardInteractivity(layer, false);
    try io.setEmptyInputRegion(1);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.roundtrip(1));
    try std.testing.expectEqual(@as(usize, 9), transcript.operation_count);
    try io.commit(1);
    _ = try io.roundtrip(1);
    try std.testing.expectError(
        error.WaylandConfigureSerialMismatch,
        io.ackConfigure(layer, 8),
    );
    try std.testing.expectEqual(@as(usize, 11), transcript.operation_count);
    try io.ackConfigure(layer, 7);
    try std.testing.expectError(error.WaylandProtocolOutOfOrder, io.roundtrip(1));
    try std.testing.expectEqual(@as(usize, 12), transcript.operation_count);
    try io.commit(1);
    _ = try io.roundtrip(1);
    try io.destroyLayerSurface(layer);
    try io.roundtripCleanup(1);
    try io.globalsDeinit(1);
    try transcript.assertComplete();
}

test "Wayland mock rejects closed configure facts without publishing them" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const size = try sdl_io.WindowSize.init(1920, 1080);
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    transcript.replies[10] = .{ .configure = .{
        .configured = false,
        .closed = true,
        .serial = 0,
        .width = 0,
        .height = 0,
    } };
    var io = WaylandIo.fromTranscript(&transcript);
    try io.globalsInit(1);
    _ = try io.findOutput(monitor_name);
    const layer = try io.createLayerSurface(1, 1, .sunglasses(), .sunglasses);
    try io.addListener(layer);
    try io.setSize(layer, size);
    try io.setAnchor(layer, 15);
    try io.setExclusiveZone(layer, -1);
    try io.setKeyboardInteractivity(layer, false);
    try io.setEmptyInputRegion(1);
    try io.commit(1);
    try std.testing.expectError(error.LayerShellClosed, io.roundtrip(1));
    try std.testing.expectEqual(@as(usize, 11), transcript.operation_count);
    try std.testing.expect(io.configured_serial == null);
    try io.destroyLayerSurface(layer);
    try io.roundtripCleanup(1);
    try io.globalsDeinit(1);
    try transcript.assertComplete();
}

test "Wayland mock enforces lifecycle and cleanup order" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const size = try sdl_io.WindowSize.init(1920, 1080);
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    transcript.replies[10] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
    var io = WaylandIo.fromTranscript(&transcript);

    try std.testing.expectError(error.WaylandGlobalsNotInitialized, io.findOutput(monitor_name));
    try std.testing.expectError(error.WaylandGlobalsNotInitialized, io.globalsDeinit(1));
    try io.globalsInit(1);
    try std.testing.expectError(error.WaylandGlobalsAlreadyInitialized, io.globalsInit(1));
    _ = try io.findOutput(monitor_name);
    const layer = try io.createLayerSurface(1, 1, .sunglasses(), .sunglasses);
    try std.testing.expectError(
        error.WaylandLayerAlreadyCreated,
        io.createLayerSurface(1, 1, .sunglasses(), .sunglasses),
    );
    try io.addListener(layer);
    try io.setSize(layer, size);
    try std.testing.expectError(error.InvalidWaylandAnchor, io.setAnchor(layer, 0));
    try std.testing.expectError(error.InvalidWaylandAnchor, io.setAnchor(layer, 16));
    try io.setAnchor(layer, 15);
    try io.setExclusiveZone(layer, -1);
    try io.setKeyboardInteractivity(layer, false);
    try io.setEmptyInputRegion(1);
    try io.commit(1);
    const configure = try io.roundtrip(1);
    try io.ackConfigure(layer, configure.serial);
    try io.destroyLayerSurface(layer);
    try std.testing.expectError(error.WaylandLayerDestroyed, io.findOutput(monitor_name));
    try std.testing.expectError(
        error.WaylandLayerDestroyed,
        io.createLayerSurface(1, 1, .sunglasses(), .sunglasses),
    );
    try std.testing.expectError(error.WaylandLayerDestroyed, io.addListener(layer));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.setSize(layer, size));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.setAnchor(layer, 15));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.setExclusiveZone(layer, -1));
    try std.testing.expectError(
        error.WaylandLayerDestroyed,
        io.setKeyboardInteractivity(layer, false),
    );
    try std.testing.expectError(error.WaylandLayerDestroyed, io.setEmptyInputRegion(1));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.commit(1));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.roundtrip(1));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.ackConfigure(layer, 7));
    try std.testing.expectError(error.WaylandLayerDestroyed, io.destroyLayerSurface(layer));
    try std.testing.expectError(error.WaylandCleanupOutOfOrder, io.globalsDeinit(1));
    try io.roundtripCleanup(1);
    try std.testing.expectError(error.WaylandCleanupOutOfOrder, io.roundtripCleanup(1));
    try io.globalsDeinit(1);
    try std.testing.expectError(error.WaylandIoDeinitialized, io.globalsDeinit(1));
    try std.testing.expectError(error.WaylandIoDeinitialized, io.findOutput(monitor_name));
    try transcript.assertComplete();
}

test "Wayland mock rejects invalid configure facts" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const expected = [_]WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = try sdl_io.WindowSize.init(1920, 1080) } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var transcript = try WaylandTranscript.init(&expected);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
    transcript.replies[10] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 0,
        .width = max_wayland_dimension + 1,
        .height = 1080,
    } };
    var io = WaylandIo.fromTranscript(&transcript);
    try io.globalsInit(1);
    _ = try io.findOutput(monitor_name);
    const layer = try io.createLayerSurface(1, 1, .sunglasses(), .sunglasses);
    try io.addListener(layer);
    try io.setSize(layer, try sdl_io.WindowSize.init(1920, 1080));
    try io.setAnchor(layer, 15);
    try io.setExclusiveZone(layer, -1);
    try io.setKeyboardInteractivity(layer, false);
    try io.setEmptyInputRegion(1);
    try io.commit(1);
    try std.testing.expectError(error.InvalidConfigureFacts, io.roundtrip(1));
    try io.destroyLayerSurface(layer);
    try io.roundtripCleanup(1);
    try io.globalsDeinit(1);
    try transcript.assertComplete();
}
