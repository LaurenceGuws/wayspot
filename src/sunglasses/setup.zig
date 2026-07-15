//! Sunglasses setup owns one fixed typed window and layer command sequence.

const sdl_io = @import("sdl_io");
const wayland_io = @import("wayland_io");

/// SetupError combines the two plain adapter errors used by setup execution.
pub const SetupError = sdl_io.WindowError || wayland_io.WaylandError;

const LayerCleanupState = enum {
    absent,
    live,
    destroy_pending,
    destroyed,
    roundtrip_pending,
    cleaned,
};

const GlobalsCleanupState = enum {
    absent,
    live,
    deinit_pending,
    cleaned,
};

/// SetupResult makes an unfinished cleanup owner explicit to the caller.
pub const SetupResult = union(enum) {
    /// complete proves setup and cleanup both finished.
    complete,
    /// failure carries the exact reason and any caller-owned cleanup session.
    failure: struct {
        /// reason is the exact setup or cleanup error returned by the owner.
        reason: SetupError,
        /// cleanup is present whenever a window or Wayland resource remains owned.
        cleanup: ?CleanupSession,
    },
};

/// CleanupSession owns a partial transcript setup until cleanup succeeds.
pub const CleanupSession = struct {
    /// window remains owned until all pending Wayland cleanup succeeds.
    window: sdl_io.SdlWindowIo,
    /// layer_io retains the transcript state needed for cleanup retry.
    layer_io: wayland_io.WaylandIo,
    /// wayland_ids is published only after both borrowed handle lookups succeed.
    wayland_ids: ?sdl_io.SdlWaylandIds = null,
    /// layer_id remains until layer destruction and cleanup flush both succeed.
    layer_id: ?wayland_io.LayerSurfaceId = null,
    /// layer_state records the current cleanup phase.
    layer_state: LayerCleanupState = .absent,
    /// globals_state remains live until globals deinit succeeds.
    globals_state: GlobalsCleanupState = .absent,
    /// closed prevents a completed session from being reused.
    closed: bool = false,

    /// retryCleanup consumes pending cleanup operations and then closes the window.
    pub fn retryCleanup(self: *CleanupSession) SetupError!void {
        if (self.closed) return error.WaylandIoDeinitialized;
        if (self.layer_id) |id| switch (self.layer_state) {
            .live, .destroy_pending => {
                self.layer_state = .destroy_pending;
                try self.layer_io.destroyLayerSurface(id);
                self.layer_state = .destroyed;
            },
            .absent, .destroyed, .roundtrip_pending, .cleaned => {},
        };
        if (self.layer_state == .destroyed or self.layer_state == .roundtrip_pending) {
            const wayland_ids = self.ids() catch |err| return err;
            self.layer_state = .roundtrip_pending;
            try self.layer_io.roundtripCleanup(wayland_ids.display_id);
            self.layer_state = .cleaned;
            self.layer_id = null;
        }
        if (self.globals_state == .live or self.globals_state == .deinit_pending) {
            if (self.layer_state != .absent and self.layer_state != .cleaned) {
                return error.WaylandCleanupOutOfOrder;
            }
            const wayland_ids = self.ids() catch |err| return err;
            self.globals_state = .deinit_pending;
            try self.layer_io.globalsDeinit(wayland_ids.display_id);
            self.globals_state = .cleaned;
        }
        self.window.deinit();
        self.closed = true;
    }

    fn init(window: sdl_io.SdlWindowIo, layer_transcript: *wayland_io.WaylandTranscript) CleanupSession {
        return .{
            .window = window,
            .layer_io = wayland_io.WaylandIo.fromTranscript(layer_transcript),
        };
    }

    fn ids(self: *const CleanupSession) SetupError!sdl_io.SdlWaylandIds {
        return self.wayland_ids orelse error.InvalidWaylandIds;
    }
};

/// SetupPlan contains the bounded values shared by native and transcript setup.
pub const SetupPlan = struct {
    /// monitor_name selects the compositor output.
    monitor_name: sdl_io.DisplayName,
    /// title is the bounded SDL window title.
    title: sdl_io.WindowTitle,
    /// size is the positive window and layer size.
    size: sdl_io.WindowSize,
    /// layer is the one active sunglasses layer value.
    layer: wayland_io.LayerValue,
    /// namespace is the fixed sunglasses layer namespace.
    namespace: wayland_io.LayerNamespace,

    /// init creates one fixed bounded setup plan.
    pub fn init(
        monitor_name: sdl_io.DisplayName,
        title: sdl_io.WindowTitle,
        size: sdl_io.WindowSize,
    ) SetupPlan {
        return .{
            .monitor_name = monitor_name,
            .title = title,
            .size = size,
            .layer = wayland_io.LayerValue.sunglasses(),
            .namespace = .sunglasses,
        };
    }
};

/// WindowCommand is one fixed SDL setup step.
pub const WindowCommand = enum {
    /// property_create allocates the SDL property set.
    property_create,
    /// set_title writes the bounded window title.
    set_title,
    /// set_width writes the positive window width.
    set_width,
    /// set_height writes the positive window height.
    set_height,
    /// set_hidden writes the hidden property.
    set_hidden,
    /// set_custom_surface_role writes the custom Wayland role property.
    set_custom_surface_role,
    /// set_create_egl_window writes the EGL-window property.
    set_create_egl_window,
    /// window_create creates the SDL window.
    window_create,
    /// property_destroy releases the property set after window creation.
    property_destroy,
};

/// window_commands is the exact SDL setup order consumed by both executors.
pub const window_commands = [_]WindowCommand{
    .property_create,
    .set_title,
    .set_width,
    .set_height,
    .set_hidden,
    .set_custom_surface_role,
    .set_create_egl_window,
    .window_create,
    .property_destroy,
};

/// LayerCommand is one fixed Wayland setup step.
pub const LayerCommand = enum {
    /// resolve_wayland_handles resolves the borrowed SDL Wayland handles.
    resolve_wayland_handles,
    /// globals_init initializes the layer globals.
    globals_init,
    /// find_output selects the named output.
    find_output,
    /// create_layer_surface creates the configured layer.
    create_layer_surface,
    /// add_listener installs the one configure listener.
    add_listener,
    /// set_size writes the layer size.
    set_size,
    /// set_anchor writes the fixed full-output anchor mask.
    set_anchor,
    /// set_exclusive_zone writes the full-output exclusive zone.
    set_exclusive_zone,
    /// set_keyboard_interactivity writes the noninteractive mode.
    set_keyboard_interactivity,
    /// set_empty_input_region removes pointer input.
    set_empty_input_region,
    /// first_commit publishes the initial layer state.
    first_commit,
    /// first_roundtrip receives the configure facts.
    first_roundtrip,
    /// ack_configure acknowledges the published configure serial.
    ack_configure,
    /// resize_window resizes the SDL window after configure.
    resize_window,
    /// second_commit publishes the resized layer state.
    second_commit,
    /// second_roundtrip completes the configured layer setup.
    second_roundtrip,
};

/// layer_commands is the exact Wayland setup order consumed by both executors.
pub const layer_commands = [_]LayerCommand{
    .resolve_wayland_handles,
    .globals_init,
    .find_output,
    .create_layer_surface,
    .add_listener,
    .set_size,
    .set_anchor,
    .set_exclusive_zone,
    .set_keyboard_interactivity,
    .set_empty_input_region,
    .first_commit,
    .first_roundtrip,
    .ack_configure,
    .resize_window,
    .second_commit,
    .second_roundtrip,
};

/// runTranscript executes the setup plan and returns any unfinished cleanup owner.
pub fn runTranscript(
    plan: SetupPlan,
    window_transcript: *sdl_io.SdlWindowTranscript,
    layer_transcript: *wayland_io.WaylandTranscript,
) SetupResult {
    const window = buildWindow(plan, window_transcript) catch |err| return .{ .failure = .{
        .reason = err,
        .cleanup = null,
    } };
    var session = CleanupSession.init(window, layer_transcript);
    executeLayer(plan, &session) catch |err| return .{ .failure = .{
        .reason = err,
        .cleanup = session,
    } };
    session.retryCleanup() catch |err| return .{ .failure = .{
        .reason = err,
        .cleanup = session,
    } };
    return .complete;
}

fn buildWindow(
    plan: SetupPlan,
    window_transcript: *sdl_io.SdlWindowTranscript,
) SetupError!sdl_io.SdlWindowIo {
    var properties: ?sdl_io.SdlWindowPropertyIo = null;
    errdefer if (properties) |*value| value.deinit();
    var window: ?sdl_io.SdlWindowIo = null;
    for (window_commands) |command| switch (command) {
        .property_create => properties = try sdl_io.SdlWindowPropertyIo.create(window_transcript),
        .set_title => try properties.?.setTitle(plan.title),
        .set_width => try properties.?.setWidth(plan.size.width),
        .set_height => try properties.?.setHeight(plan.size.height),
        .set_hidden => try properties.?.setHidden(true),
        .set_custom_surface_role => try properties.?.setCustomSurfaceRole(true),
        .set_create_egl_window => try properties.?.setCreateEglWindow(true),
        .window_create => window = try sdl_io.SdlWindowIo.create(window_transcript, &properties.?),
        .property_destroy => {
            properties.?.deinit();
            properties = null;
        },
    };
    return window orelse unreachable;
}

fn executeLayer(plan: SetupPlan, session: *CleanupSession) SetupError!void {
    var output_id: wayland_io.WaylandOutputId = undefined;
    var configure_serial: u32 = 0;
    for (layer_commands) |command| switch (command) {
        .resolve_wayland_handles => {
            session.wayland_ids = try session.window.waylandIds();
        },
        .globals_init => {
            const ids = try session.ids();
            try session.layer_io.globalsInit(ids.display_id);
            session.globals_state = .live;
        },
        .find_output => output_id = try session.layer_io.findOutput(plan.monitor_name),
        .create_layer_surface => {
            const ids = try session.ids();
            session.layer_id = try session.layer_io.createLayerSurface(
                ids.surface_id,
                output_id,
                plan.layer,
                plan.namespace,
            );
            session.layer_state = .live;
        },
        .add_listener => try session.layer_io.addListener(session.layer_id.?),
        .set_size => try session.layer_io.setSize(session.layer_id.?, plan.size),
        .set_anchor => try session.layer_io.setAnchor(session.layer_id.?, 15),
        .set_exclusive_zone => try session.layer_io.setExclusiveZone(session.layer_id.?, -1),
        .set_keyboard_interactivity => try session.layer_io.setKeyboardInteractivity(
            session.layer_id.?,
            false,
        ),
        .set_empty_input_region => {
            const ids = try session.ids();
            try session.layer_io.setEmptyInputRegion(ids.surface_id);
        },
        .first_commit => {
            const ids = try session.ids();
            try session.layer_io.commit(ids.surface_id);
        },
        .first_roundtrip => {
            const ids = try session.ids();
            configure_serial = (try session.layer_io.roundtrip(ids.display_id)).serial;
        },
        .ack_configure => try session.layer_io.ackConfigure(session.layer_id.?, configure_serial),
        .resize_window => try session.window.resize(plan.size),
        .second_commit => {
            const ids = try session.ids();
            try session.layer_io.commit(ids.surface_id);
        },
        .second_roundtrip => {
            const ids = try session.ids();
            _ = try session.layer_io.roundtrip(ids.display_id);
        },
    };
}
