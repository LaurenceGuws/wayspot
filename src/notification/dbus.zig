//! Notification DBus owns the Freedesktop interface and banner dispatch.

const std = @import("std");
const builtin = @import("builtin");
const history = @import("wayspot_history");
const notifications_state = @import("state.zig");
const notification_rows = @import("rows.zig");
const banner = @import("banner.zig");

const log = std.log.scoped(.notifications);

const guint = c_uint;
const gboolean = c_int;
const guchar = u8;
const gssize = isize;
const gsize = c_ulong;

const GBusType = c_int;
const GBusNameOwnerFlags = c_uint;
const G_BUS_TYPE_SESSION: GBusType = 2;
const G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE: GBusNameOwnerFlags = 1 << 2;

const GDBusConnection = opaque {};
const GDBusMethodInvocation = opaque {};
const GDBusNodeInfo = opaque {};
const GDBusInterfaceInfo = opaque {};
const GVariant = opaque {};
const GVariantType = opaque {};
const GMainLoop = opaque {};

const GError = extern struct {
    domain: c_uint,
    code: c_int,
    message: [*:0]u8,
};

const GDBusInterfaceVTable = extern struct {
    method_call: ?*const fn (
        ?*GDBusConnection,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        ?*GVariant,
        ?*GDBusMethodInvocation,
        ?*anyopaque,
    ) callconv(.c) void,
    get_property: ?*const fn (
        ?*GDBusConnection,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        ?*GDBusMethodInvocation,
        ?*anyopaque,
    ) callconv(.c) ?*GVariant,
    set_property: ?*const fn (
        ?*GDBusConnection,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        [*c]const u8,
        ?*GVariant,
        ?*GDBusMethodInvocation,
        ?*anyopaque,
    ) callconv(.c) gboolean,
};

extern fn g_bus_own_name(
    bus_type: GBusType,
    name: [*:0]const u8,
    flags: GBusNameOwnerFlags,
    bus_acquired_handler: ?*const fn (?*GDBusConnection, [*c]const u8, ?*anyopaque) callconv(.c) void,
    name_acquired_handler: ?*const fn (?*GDBusConnection, [*c]const u8, ?*anyopaque) callconv(.c) void,
    name_lost_handler: ?*const fn (?*GDBusConnection, [*c]const u8, ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
    user_data_free_func: ?*const fn (?*anyopaque) callconv(.c) void,
) guint;
extern fn g_bus_unown_name(owner_id: guint) void;
extern fn g_dbus_node_info_new_for_xml(xml_data: [*:0]const u8, error_out: *?*GError) ?*GDBusNodeInfo;
extern fn g_dbus_node_info_unref(info: *GDBusNodeInfo) void;
extern fn g_dbus_node_info_lookup_interface(info: *GDBusNodeInfo, name: [*:0]const u8) ?*GDBusInterfaceInfo;
extern fn g_dbus_connection_register_object(
    connection: ?*GDBusConnection,
    object_path: [*:0]const u8,
    interface_info: *GDBusInterfaceInfo,
    vtable: *const GDBusInterfaceVTable,
    user_data: ?*anyopaque,
    user_data_free_func: ?*const fn (?*anyopaque) callconv(.c) void,
    error_out: *?*GError,
) guint;
extern fn g_dbus_connection_unregister_object(connection: *GDBusConnection, registration_id: guint) gboolean;
extern fn g_dbus_connection_emit_signal(
    connection: *GDBusConnection,
    destination_bus_name: ?[*:0]const u8,
    object_path: [*:0]const u8,
    interface_name: [*:0]const u8,
    signal_name: [*:0]const u8,
    parameters: ?*GVariant,
    error_out: ?*?*GError,
) gboolean;
extern fn g_dbus_method_invocation_return_value(invocation: *GDBusMethodInvocation, parameters: ?*GVariant) void;
extern fn g_dbus_method_invocation_return_dbus_error(
    invocation: *GDBusMethodInvocation,
    error_name: [*:0]const u8,
    error_message: [*:0]const u8,
) void;
extern fn g_object_ref(object: *GDBusConnection) ?*GDBusConnection;
extern fn g_object_unref(object: *GDBusConnection) void;
extern fn g_error_free(error_value: *GError) void;
extern fn g_variant_new(format_string: [*:0]const u8, ...) ?*GVariant;
extern fn g_variant_new_strv(strv: [*]?[*:0]const u8, length: gssize) ?*GVariant;
extern fn g_variant_new_tuple(children: [*]?*GVariant, length: gssize) ?*GVariant;
extern fn g_variant_unref(value: ?*GVariant) void;
extern fn g_variant_n_children(value: *GVariant) gsize;
extern fn g_variant_get_child_value(value: *GVariant, index: gsize) ?*GVariant;
extern fn g_variant_get_string(value: *GVariant, length: ?*gsize) [*:0]const u8;
extern fn g_variant_get_uint32(value: *GVariant) u32;
extern fn g_variant_get_int32(value: *GVariant) i32;
extern fn g_variant_is_of_type(value: ?*GVariant, variant_type: *const GVariantType) gboolean;
extern fn g_variant_lookup(value: *GVariant, key: [*:0]const u8, format_string: [*:0]const u8, ...) gboolean;
extern fn g_main_loop_new(context: ?*opaque {}, is_running: gboolean) ?*GMainLoop;
extern fn g_main_loop_run(loop: *GMainLoop) void;
extern fn g_main_loop_unref(loop: *GMainLoop) void;
extern fn g_timeout_add_full(
    priority: c_int,
    interval: guint,
    function: *const fn (?*anyopaque) callconv(.c) gboolean,
    data: ?*anyopaque,
    notify: ?*const fn (?*anyopaque) callconv(.c) void,
) guint;
extern fn g_source_remove(tag: guint) gboolean;

pub fn run(allocator: std.mem.Allocator) !void {
    var dbus = try DBus.init(allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_notify = onNotifyBanner });
    try dbus.start();

    const loop = g_main_loop_new(null, 0) orelse return error.NotificationsMainLoopFailed;
    defer g_main_loop_unref(loop);
    g_main_loop_run(loop);
}

const service_name: [*:0]const u8 = "org.freedesktop.Notifications";
const interface_name: [*:0]const u8 = "org.freedesktop.Notifications";
const object_path: [*:0]const u8 = "/org/freedesktop/Notifications";

const server_name: [*:0]const u8 = "wayspot";
const server_vendor: [*:0]const u8 = "wayspot";
const server_version: [*:0]const u8 = "0.1.3-dev";
const server_spec_version: [*:0]const u8 = "1.3";
const max_action_pairs: u32 = 8;
const close_reason_expired: u32 = 1;
const close_reason_closed: u32 = 3;
const default_expire_timeout_ms: u32 = 4200;
const max_expire_timeout_ms: u32 = 60000;
const glib_priority_default: c_int = 0;
const glib_source_remove: gboolean = 0;
const glib_source_continue: gboolean = 1;

comptime {
    std.debug.assert(max_action_pairs > 0);
    std.debug.assert(default_expire_timeout_ms > 0);
    std.debug.assert(max_expire_timeout_ms >= default_expire_timeout_ms);
}

const introspection_xml: [*:0]const u8 =
    \\<node>
    \\<interface name='org.freedesktop.Notifications'>
    \\<method name='GetCapabilities'>
    \\<arg type='as' name='caps' direction='out'/>
    \\</method>
    \\<method name='Notify'>
    \\<arg type='s' name='app_name' direction='in'/>
    \\<arg type='u' name='replaces_id' direction='in'/>
    \\<arg type='s' name='app_icon' direction='in'/>
    \\<arg type='s' name='summary' direction='in'/>
    \\<arg type='s' name='body' direction='in'/>
    \\<arg type='as' name='actions' direction='in'/>
    \\<arg type='a{sv}' name='hints' direction='in'/>
    \\<arg type='i' name='expire_timeout' direction='in'/>
    \\<arg type='u' name='id' direction='out'/>
    \\</method>
    \\<method name='CloseNotification'>
    \\<arg type='u' name='id' direction='in'/>
    \\</method>
    \\<method name='GetServerInformation'>
    \\<arg type='s' name='name' direction='out'/>
    \\<arg type='s' name='vendor' direction='out'/>
    \\<arg type='s' name='version' direction='out'/>
    \\<arg type='s' name='spec_version' direction='out'/>
    \\</method>
    \\<signal name='NotificationClosed'>
    \\<arg type='u' name='id'/>
    \\<arg type='u' name='reason'/>
    \\</signal>
    \\<signal name='ActionInvoked'>
    \\<arg type='u' name='id'/>
    \\<arg type='s' name='action_key'/>
    \\</signal>
    \\<signal name='ActivationToken'>
    \\<arg type='u' name='id'/>
    \\<arg type='s' name='activation_token'/>
    \\</signal>
    \\</interface>
    \\</node>
;

const vtable = GDBusInterfaceVTable{
    .method_call = onMethodCall,
    .get_property = null,
    .set_property = null,
};

pub const DBus = struct {
    pub const Action = struct {
        key: []const u8,
        label: []const u8,
    };

    pub const NotifyEvent = struct {
        id: u32,
        app_name: []const u8,
        app_icon: []const u8,
        summary: []const u8,
        body: []const u8,
        expire_timeout: i32,
        replaced: bool,
        urgency: u8,
        transient: bool,
        actions: []const Action,
    };

    pub const ClosedEvent = struct {
        id: u32,
        reason: u32,
    };

    pub const Hooks = struct {
        on_notify: ?*const fn (NotifyEvent) void = null,
        on_closed: ?*const fn (ClosedEvent) void = null,
    };

    /// CloseResult identifies a durable close and a close published before
    /// parent-directory sync completed.
    pub const CloseResult = union(enum) {
        closed,
        committed_unsynced: history.ParentSyncError,
    };

    allocator: std.mem.Allocator,
    state: notifications_state.Store,
    timers: std.AutoHashMap(u32, guint),
    owner_id: guint = 0,
    registration_id: guint = 0,
    node_info: ?*GDBusNodeInfo = null,
    connection: ?*GDBusConnection = null,
    hooks: Hooks = .{},

    pub fn init(allocator: std.mem.Allocator) !DBus {
        var gerr: ?*GError = null;
        const node = g_dbus_node_info_new_for_xml(introspection_xml, &gerr);
        if (node == null) {
            logGError("failed to parse notifications introspection XML", gerr);
            return error.NotificationsIntrospectionFailed;
        }
        return .{
            .allocator = allocator,
            .state = notifications_state.Store.init(allocator),
            .timers = std.AutoHashMap(u32, guint).init(allocator),
            .node_info = node,
        };
    }

    pub fn start(self: *DBus) !void {
        if (self.owner_id != 0) return;
        self.owner_id = g_bus_own_name(
            G_BUS_TYPE_SESSION,
            service_name,
            G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE,
            onBusAcquired,
            onNameAcquired,
            onNameLost,
            self,
            null,
        );
        if (self.owner_id == 0) return error.NotificationsBusOwnFailed;
    }

    pub fn deinit(self: *DBus) void {
        if (self.registration_id != 0 and self.connection != null) {
            const removed = g_dbus_connection_unregister_object(self.connection.?, self.registration_id);
            if (removed == 0) log.warn("notifications object unregister failed", .{});
            self.registration_id = 0;
        }
        if (self.owner_id != 0) {
            g_bus_unown_name(self.owner_id);
            self.owner_id = 0;
        }
        if (self.connection) |conn| {
            g_object_unref(conn);
            self.connection = null;
        }
        if (self.node_info) |node| {
            g_dbus_node_info_unref(node);
            self.node_info = null;
        }
        self.clearTimers();
        self.timers.deinit();
        self.state.deinit();
    }

    pub fn setHooks(self: *DBus, hooks: Hooks) void {
        self.hooks = hooks;
    }

    pub fn clearHooks(self: *DBus) void {
        self.hooks = .{};
    }

    /// closeWithReason persists the complete durable row before removing live
    /// state. Pre-replace errors leave live state and effects unchanged.
    pub fn closeWithReason(self: *DBus, id: u32, reason: u32) anyerror!CloseResult {
        if (!self.state.map.contains(id)) return error.UnknownNotificationId;
        const history_path = try history.path(self.allocator);
        defer self.allocator.free(history_path);
        return closeWithReasonAtPathWithPersistence(
            self,
            id,
            reason,
            history_path,
            persistCloseHistory,
        );
    }

    /// prepareTimer reserves capacity and creates a new source without changing
    /// the current timer entry; TimerChange owns the prepared source.
    fn prepareTimer(self: *DBus, id: u32, expire_timeout: i32, urgency: u8) !TimerChange {
        const old_source = self.timers.get(id);
        try self.timers.ensureUnusedCapacity(1);
        const timeout_ms = dbusExpireTimeoutMs(expire_timeout, urgency) orelse return .{
            .dbus = self,
            .id = id,
            .old_source = old_source,
            .new_source = null,
        };
        const context = try self.allocator.create(TimeoutContext);
        context.* = .{ .dbus = self, .id = id, .source_id = 0 };
        const source_id = g_timeout_add_full(
            glib_priority_default,
            timeout_ms,
            onNotificationExpired,
            context,
            freeTimeoutContext,
        );
        context.source_id = source_id;
        if (source_id == 0) {
            self.allocator.destroy(context);
            return error.NotificationTimerFailed;
        }
        return .{
            .dbus = self,
            .id = id,
            .old_source = old_source,
            .new_source = source_id,
        };
    }

    fn cancelTimer(self: *DBus, id: u32) void {
        const removed = self.timers.fetchRemove(id) orelse return;
        const source_removed = g_source_remove(removed.value);
        if (source_removed == 0) log.debug("notification timer already removed id={d}", .{id});
    }

    fn clearTimers(self: *DBus) void {
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            const source_removed = g_source_remove(entry.value_ptr.*);
            if (source_removed == 0) {
                log.debug("notification timer already removed id={d}", .{entry.key_ptr.*});
            }
        }
        self.timers.clearRetainingCapacity();
    }

    pub fn emitActionInvoked(self: *DBus, id: u32, action_key: []const u8) void {
        const conn = self.connection orelse return;
        const key_z = self.allocator.dupeZ(u8, action_key) catch return;
        defer self.allocator.free(key_z);
        const emitted = g_dbus_connection_emit_signal(
            conn,
            null,
            object_path,
            interface_name,
            "ActionInvoked",
            g_variant_new("(us)", id, key_z.ptr),
            null,
        );
        if (emitted == 0) log.warn("ActionInvoked signal failed id={d}", .{id});
    }
};

/// TimerChange owns one prepared GLib source until commit or rollback.
/// Completion only swaps/removes already prepared state and cannot allocate.
const TimerChange = struct {
    dbus: *DBus,
    id: u32,
    old_source: ?guint,
    new_source: ?guint,
    completed: bool = false,

    fn commit(self: *TimerChange) void {
        std.debug.assert(!self.completed);
        if (self.new_source) |new_source| {
            if (self.old_source) |old_source| {
                std.debug.assert(self.dbus.timers.get(self.id) == old_source);
            } else {
                std.debug.assert(self.dbus.timers.get(self.id) == null);
            }
            self.dbus.timers.putAssumeCapacity(self.id, new_source);
        } else if (self.old_source) |old_source| {
            const removed = self.dbus.timers.fetchRemove(self.id) orelse unreachable;
            std.debug.assert(removed.value == old_source);
        }
        if (self.old_source) |old_source| {
            const source_removed = g_source_remove(old_source);
            if (source_removed == 0) log.debug("notification timer already removed id={d}", .{self.id});
        }
        self.completed = true;
    }

    fn rollback(self: *TimerChange) void {
        std.debug.assert(!self.completed);
        if (self.new_source) |new_source| {
            const source_removed = g_source_remove(new_source);
            if (source_removed == 0) log.debug("notification timer cleanup missed id={d}", .{self.id});
        }
        self.completed = true;
    }
};

const PersistHistory = *const fn (
    std.mem.Allocator,
    []const u8,
    history.RowInput,
    bool,
) anyerror!history.SaveResult;

const PersistClose = *const fn (
    std.mem.Allocator,
    []const u8,
    u32,
    u32,
) anyerror!history.SaveResult;

/// NotifyCommit identifies a successful live commit or a published history
/// replacement whose parent sync failed after Store and timer commit.
const NotifyCommit = union(enum) {
    accepted: u32,
    committed_unsynced: struct {
        id: u32,
        sync_error: history.ParentSyncError,
    },
};

const TimeoutContext = struct {
    dbus: *DBus,
    id: u32,
    source_id: guint,
};

/// Returns true only for the timer source currently installed for the id.
fn timeoutSourceIsCurrent(context: *const TimeoutContext) bool {
    const current_source = context.dbus.timers.get(context.id) orelse return false;
    return current_source == context.source_id;
}

fn onNotificationExpired(user_data: ?*anyopaque) callconv(.c) gboolean {
    const raw = user_data orelse return glib_source_remove;
    const context: *TimeoutContext = @ptrCast(@alignCast(raw));
    if (!timeoutSourceIsCurrent(context)) return glib_source_remove;
    const history_path = history.path(context.dbus.allocator) catch |err| {
        log.warn("notification expiry history path failed id={d} err={s}", .{ context.id, @errorName(err) });
        return glib_source_continue;
    };
    defer context.dbus.allocator.free(history_path);
    return expireAtPathWithPersistence(
        context.dbus,
        context.id,
        context.source_id,
        history_path,
        persistCloseHistory,
    );
}

/// expireAtPathWithPersistence keeps the current source and live row when the
/// durable close has not replaced the history file yet.
fn expireAtPathWithPersistence(
    self: *DBus,
    id: u32,
    source_id: guint,
    history_path: []const u8,
    persist: PersistClose,
) gboolean {
    if (self.timers.get(id) != source_id) return glib_source_remove;

    const result = closeWithReasonAtPathWithPersistence(
        self,
        id,
        close_reason_expired,
        history_path,
        persist,
    ) catch |err| switch (err) {
        error.UnknownNotificationId => {
            self.cancelTimer(id);
            return glib_source_remove;
        },
        else => {
            log.warn("notification expiry retry id={d} err={s}", .{ id, @errorName(err) });
            return glib_source_continue;
        },
    };

    return switch (result) {
        .closed => glib_source_remove,
        .committed_unsynced => |err| committed: {
            log.warn("notification expiry committed unsynced id={d} err={s}", .{
                id,
                @errorName(err),
            });
            break :committed glib_source_remove;
        },
    };
}

fn freeTimeoutContext(user_data: ?*anyopaque) callconv(.c) void {
    const raw = user_data orelse return;
    const context: *TimeoutContext = @ptrCast(@alignCast(raw));
    context.dbus.allocator.destroy(context);
}

fn onBusAcquired(connection: ?*GDBusConnection, _: [*c]const u8, user_data: ?*anyopaque) callconv(.c) void {
    if (connection == null or user_data == null) return;
    const self: *DBus = @ptrCast(@alignCast(user_data.?));

    if (self.connection) |existing| {
        g_object_unref(existing);
    }
    self.connection = g_object_ref(connection.?);

    const node_info = self.node_info orelse return;
    const iface = g_dbus_node_info_lookup_interface(node_info, interface_name) orelse return;

    var gerr: ?*GError = null;
    self.registration_id = g_dbus_connection_register_object(
        connection,
        object_path,
        iface,
        &vtable,
        self,
        null,
        &gerr,
    );
    if (self.registration_id == 0) {
        logGError("failed to register notifications object", gerr);
    }
}

fn onNameAcquired(_: ?*GDBusConnection, name: [*c]const u8, _: ?*anyopaque) callconv(.c) void {
    if (name != null) {
        log.info("owned dbus name: {s}", .{std.mem.span(name)});
    }
}

fn onNameLost(_: ?*GDBusConnection, name: [*c]const u8, user_data: ?*anyopaque) callconv(.c) void {
    if (name != null) {
        log.warn("lost dbus name: {s}", .{std.mem.span(name)});
    }
    if (user_data == null) return;
    const self: *DBus = @ptrCast(@alignCast(user_data.?));
    self.registration_id = 0;
    std.process.exit(1);
}

fn onMethodCall(
    _: ?*GDBusConnection,
    _: [*c]const u8,
    _: [*c]const u8,
    _: [*c]const u8,
    method_name: [*c]const u8,
    parameters: ?*GVariant,
    invocation: ?*GDBusMethodInvocation,
    user_data: ?*anyopaque,
) callconv(.c) void {
    if (invocation == null or user_data == null) return;
    const self: *DBus = @ptrCast(@alignCast(user_data.?));
    const method = std.mem.span(method_name);

    if (std.mem.eql(u8, method, "GetCapabilities")) {
        handleGetCapabilities(invocation.?);
        return;
    }
    if (std.mem.eql(u8, method, "GetServerInformation")) {
        handleGetServerInformation(invocation.?);
        return;
    }
    if (std.mem.eql(u8, method, "Notify")) {
        handleNotify(self, parameters, invocation.?);
        return;
    }
    if (std.mem.eql(u8, method, "CloseNotification")) {
        handleCloseNotification(self, parameters, invocation.?);
        return;
    }

    g_dbus_method_invocation_return_dbus_error(
        invocation.?,
        "org.freedesktop.DBus.Error.UnknownMethod",
        "Unknown method",
    );
}

fn handleGetCapabilities(invocation: *GDBusMethodInvocation) void {
    var capabilities = [_]?[*:0]const u8{
        "body",
        null,
    };
    const caps = g_variant_new_strv(@ptrCast(&capabilities[0]), 1);
    var tuple_items = [_]?*GVariant{caps};
    g_dbus_method_invocation_return_value(invocation, g_variant_new_tuple(@ptrCast(&tuple_items[0]), 1));
}

fn handleGetServerInformation(invocation: *GDBusMethodInvocation) void {
    g_dbus_method_invocation_return_value(
        invocation,
        g_variant_new("(ssss)", server_name, server_vendor, server_version, server_spec_version),
    );
}

fn handleNotify(self: *DBus, parameters: ?*GVariant, invocation: *GDBusMethodInvocation) void {
    const payload = parameters orelse {
        returnInvalidArgs(invocation, "Notify expects parameters");
        return;
    };

    if (g_variant_n_children(payload) != 8) {
        returnInvalidArgs(invocation, "Notify expects 8 arguments");
        return;
    }

    const app_name_variant = g_variant_get_child_value(payload, 0);
    defer g_variant_unref(app_name_variant);
    const replaces_id_variant = g_variant_get_child_value(payload, 1);
    defer g_variant_unref(replaces_id_variant);
    const app_icon_variant = g_variant_get_child_value(payload, 2);
    defer g_variant_unref(app_icon_variant);
    const summary_variant = g_variant_get_child_value(payload, 3);
    defer g_variant_unref(summary_variant);
    const body_variant = g_variant_get_child_value(payload, 4);
    defer g_variant_unref(body_variant);
    const actions_variant = g_variant_get_child_value(payload, 5);
    defer g_variant_unref(actions_variant);
    const hints_variant = g_variant_get_child_value(payload, 6);
    defer g_variant_unref(hints_variant);
    const expire_timeout_variant = g_variant_get_child_value(payload, 7);
    defer g_variant_unref(expire_timeout_variant);

    if (g_variant_is_of_type(hints_variant, variantType("a{sv}")) == 0) {
        returnInvalidArgs(invocation, "Notify hints must be a{sv}");
        return;
    }

    const app_name = g_variant_get_string(app_name_variant.?, null);
    const app_icon = g_variant_get_string(app_icon_variant.?, null);
    const summary = g_variant_get_string(summary_variant.?, null);
    const body = g_variant_get_string(body_variant.?, null);
    const replaces_id = g_variant_get_uint32(replaces_id_variant.?);
    const expire_timeout = g_variant_get_int32(expire_timeout_variant.?);
    const action_pairs = parseActions(self.allocator, actions_variant.?) catch &.{};
    defer if (action_pairs.len > 0) self.allocator.free(action_pairs);
    const has_actions = action_pairs.len > 0;
    const parsed_hints = parseHints(hints_variant.?);

    const request = notifications_state.NotifyRequest{
        .app_name = std.mem.span(app_name),
        .summary = std.mem.span(summary),
        .body = std.mem.span(body),
        .replaces_id = replaces_id,
        .expire_timeout = expire_timeout,
        .has_actions = has_actions,
    };
    const commit = applyNotify(
        self,
        request,
        std.mem.span(app_icon),
        parsed_hints.urgency,
        parsed_hints.transient,
        action_pairs,
    ) catch |err| {
        returnNotifyFailure(invocation, err);
        return;
    };
    const id = switch (commit) {
        .accepted => |accepted_id| accepted_id,
        .committed_unsynced => |published| {
            returnNotifyCommittedUnsynced(invocation, published.id, published.sync_error);
            return;
        },
    };
    log.info(
        "notify id={d} app=\"{s}\" summary=\"{s}\" urgency={d} actions={d} replaced={}",
        .{
            id,
            std.mem.span(app_name),
            std.mem.span(summary),
            parsed_hints.urgency,
            @as(u32, @intCast(action_pairs.len)),
            request.replaces_id != 0 and id == request.replaces_id,
        },
    );

    g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", id));
}

fn returnNotifyFailure(invocation: *GDBusMethodInvocation, err: anyerror) void {
    var message: [96:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(&message, "Notify failed: {s}", .{@errorName(err)}) catch {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.Failed",
            "Notify failed",
        );
        return;
    };
    g_dbus_method_invocation_return_dbus_error(
        invocation,
        "org.freedesktop.DBus.Error.Failed",
        text.ptr,
    );
}

fn returnNotifyCommittedUnsynced(
    invocation: *GDBusMethodInvocation,
    id: u32,
    sync_error: history.ParentSyncError,
) void {
    var message: [128:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(
        &message,
        "Notify committed id={d}; history parent sync failed: {s}",
        .{ id, @errorName(sync_error) },
    ) catch {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.Failed",
            "Notify committed; history parent sync failed",
        );
        return;
    };
    g_dbus_method_invocation_return_dbus_error(
        invocation,
        "org.freedesktop.DBus.Error.Failed",
        text.ptr,
    );
}

/// applyNotify commits Store, timer, History, hooks, and legacy rows in order.
/// Pre-replace History errors roll back Store and timer; post-replace parent sync
/// errors return a committed-but-unsynced result after all effects publish.
fn applyNotify(
    self: *DBus,
    request: notifications_state.NotifyRequest,
    app_icon: []const u8,
    urgency: u8,
    transient: bool,
    actions: []const DBus.Action,
) anyerror!NotifyCommit {
    const history_path = try history.path(self.allocator);
    defer self.allocator.free(history_path);
    return applyNotifyAtPath(self, request, app_icon, urgency, transient, actions, history_path);
}

fn applyNotifyAtPath(
    self: *DBus,
    request: notifications_state.NotifyRequest,
    app_icon: []const u8,
    urgency: u8,
    transient: bool,
    actions: []const DBus.Action,
    history_path: []const u8,
) anyerror!NotifyCommit {
    return applyNotifyAtPathWithPersistence(
        self,
        request,
        app_icon,
        urgency,
        transient,
        actions,
        history_path,
        persistHistory,
    );
}

fn applyNotifyAtPathWithPersistence(
    self: *DBus,
    request: notifications_state.NotifyRequest,
    app_icon: []const u8,
    urgency: u8,
    transient: bool,
    actions: []const DBus.Action,
    history_path: []const u8,
    persist: PersistHistory,
) anyerror!NotifyCommit {
    const replaced = request.replaces_id != 0 and self.state.map.getPtr(request.replaces_id) != null;
    var store_change = try self.state.prepareNotify(request);
    var timer_change = self.prepareTimer(store_change.id, request.expire_timeout, urgency) catch |err| {
        store_change.rollback();
        return err;
    };
    const save_result = persist(self.allocator, history_path, .{
        .id = store_change.id,
        .created_ns = 0,
        .updated_ns = 0,
        .app_name = request.app_name,
        .app_icon = app_icon,
        .summary = request.summary,
        .body = request.body,
        .urgency = urgency,
        .transient = transient,
        .active = true,
    }, replaced) catch |err| {
        timer_change.rollback();
        store_change.rollback();
        return err;
    };

    timer_change.commit();
    store_change.commit();

    if (self.hooks.on_notify) |on_notify| {
        on_notify(.{
            .id = store_change.id,
            .app_name = request.app_name,
            .app_icon = app_icon,
            .summary = request.summary,
            .body = request.body,
            .expire_timeout = request.expire_timeout,
            .replaced = replaced,
            .urgency = urgency,
            .transient = transient,
            .actions = actions,
        });
    }
    recordNotificationRow(
        self.allocator,
        store_change.id,
        request.app_name,
        app_icon,
        request.summary,
        request.body,
        urgency,
        transient,
    ) catch |err| {
        std.log.warn("notification rows record failed id={d} err={s}", .{ store_change.id, @errorName(err) });
    };
    return switch (save_result) {
        .published => .{ .accepted = store_change.id },
        .parent_sync_failed => |err| .{ .committed_unsynced = .{
            .id = store_change.id,
            .sync_error = err,
        } },
    };
}

/// closeWithReasonAtPathWithPersistence saves the durable close before removing
/// the live row. Parent-sync failure is already a committed close.
fn closeWithReasonAtPathWithPersistence(
    self: *DBus,
    id: u32,
    reason: u32,
    history_path: []const u8,
    persist: PersistClose,
) anyerror!DBus.CloseResult {
    if (!self.state.map.contains(id)) return error.UnknownNotificationId;
    const save_result = try persist(self.allocator, history_path, id, reason);

    const closed = self.state.close(id);
    std.debug.assert(closed);
    self.cancelTimer(id);
    recordNotificationClosed(id, reason);
    emitNotificationClosed(self, id, reason);
    if (self.hooks.on_closed) |on_closed| {
        on_closed(.{
            .id = id,
            .reason = reason,
        });
    }

    return switch (save_result) {
        .published => .closed,
        .parent_sync_failed => |err| .{ .committed_unsynced = err },
    };
}

fn recordNotificationRow(
    allocator: std.mem.Allocator,
    id: u32,
    app_name: []const u8,
    app_icon: []const u8,
    summary: []const u8,
    body: []const u8,
    urgency: u8,
    transient: bool,
) !void {
    if (builtin.is_test) {
        test_legacy_row_calls += 1;
        if (!test_record_legacy_rows) return;
    }
    return notification_rows.recordNotify(
        allocator,
        id,
        app_name,
        app_icon,
        summary,
        body,
        urgency,
        transient,
    );
}

fn recordNotificationClosed(id: u32, reason: u32) void {
    if (builtin.is_test) {
        test_legacy_close_calls += 1;
        if (!test_record_legacy_rows) return;
    }
    notification_rows.recordClosed(id, reason);
}

fn persistHistory(
    allocator: std.mem.Allocator,
    history_path: []const u8,
    input: history.RowInput,
    replacement: bool,
) anyerror!history.SaveResult {
    const now_ns = realtimeNs();
    var saved_history = try history.History.loadAtPath(allocator, history_path, now_ns);
    defer saved_history.deinit();
    var created_ns = now_ns;
    if (replacement) {
        for (saved_history.rows.items) |existing| {
            if (existing.id == input.id) {
                created_ns = existing.created_ns;
                break;
            }
        }
    }
    var row = input;
    row.created_ns = created_ns;
    row.updated_ns = now_ns;
    try saved_history.upsert(row);
    saved_history.pruneOld(now_ns);
    return saved_history.saveAtPathResult(history_path);
}

fn persistCloseHistory(
    allocator: std.mem.Allocator,
    history_path: []const u8,
    id: u32,
    reason: u32,
) anyerror!history.SaveResult {
    const now_ns = realtimeNs();
    var saved_history = try history.History.loadAtPath(allocator, history_path, now_ns);
    defer saved_history.deinit();

    const existing = for (saved_history.rows.items) |row| {
        if (row.id == id) break row;
    } else return error.HistoryRowNotFound;

    try saved_history.upsert(.{
        .id = existing.id,
        .created_ns = existing.created_ns,
        .updated_ns = now_ns,
        .app_name = existing.app_name,
        .app_icon = existing.app_icon,
        .summary = existing.summary,
        .body = existing.body,
        .urgency = existing.urgency,
        .transient = existing.transient,
        .active = false,
        .closed_reason = reason,
    });
    return saved_history.saveAtPathResult(history_path);
}

fn persistHistoryPublishedUnsynced(
    allocator: std.mem.Allocator,
    history_path: []const u8,
    input: history.RowInput,
    replacement: bool,
) anyerror!history.SaveResult {
    const save_result = try persistHistory(allocator, history_path, input, replacement);
    return switch (save_result) {
        .published => .{ .parent_sync_failed = error.InputOutput },
        .parent_sync_failed => |err| .{ .parent_sync_failed = err },
    };
}

fn persistCloseHistoryPublishedUnsynced(
    allocator: std.mem.Allocator,
    history_path: []const u8,
    id: u32,
    reason: u32,
) anyerror!history.SaveResult {
    const save_result = try persistCloseHistory(allocator, history_path, id, reason);
    return switch (save_result) {
        .published => .{ .parent_sync_failed = error.InputOutput },
        .parent_sync_failed => |err| .{ .parent_sync_failed = err },
    };
}

fn realtimeNs() u64 {
    var ts: std.os.linux.timespec = undefined;
    const rc = std.os.linux.clock_gettime(.REALTIME, &ts);
    if (std.os.linux.errno(rc) != .SUCCESS) return 0;
    const seconds_ns: u64 = @intCast(ts.sec * std.time.ns_per_s);
    const nanos: u64 = @intCast(ts.nsec);
    return seconds_ns + nanos;
}

fn onNotifyBanner(event: DBus.NotifyEvent) void {
    banner.spawn(.{
        .app_name = event.app_name,
        .summary = event.summary,
        .body = event.body,
        .expire_timeout = event.expire_timeout,
        .urgency = event.urgency,
    }) catch |err| {
        log.warn("notification banner spawn failed id={d} err={s}", .{ event.id, @errorName(err) });
    };
}

fn handleCloseNotification(self: *DBus, parameters: ?*GVariant, invocation: *GDBusMethodInvocation) void {
    const payload = parameters orelse {
        returnInvalidArgs(invocation, "CloseNotification expects parameters");
        return;
    };

    if (g_variant_n_children(payload) != 1) {
        returnInvalidArgs(invocation, "CloseNotification expects one argument");
        return;
    }

    const id_variant = g_variant_get_child_value(payload, 0);
    defer g_variant_unref(id_variant);
    const notification_id = g_variant_get_uint32(id_variant.?);

    const result = self.closeWithReason(notification_id, close_reason_closed) catch |err| {
        switch (err) {
            error.UnknownNotificationId => g_dbus_method_invocation_return_dbus_error(
                invocation,
                "org.freedesktop.Notifications.InvalidId",
                "Unknown notification id",
            ),
            error.HistoryRowNotFound => g_dbus_method_invocation_return_dbus_error(
                invocation,
                "org.freedesktop.Notifications.HistoryRowNotFound",
                "No durable notification history row",
            ),
            else => returnCloseFailure(invocation, err),
        }
        return;
    };

    switch (result) {
        .closed => g_dbus_method_invocation_return_value(invocation, g_variant_new("()")),
        .committed_unsynced => |err| returnCloseCommittedUnsynced(invocation, notification_id, err),
    }
}

fn returnCloseFailure(invocation: *GDBusMethodInvocation, err: anyerror) void {
    var message: [96:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(&message, "Close failed: {s}", .{@errorName(err)}) catch {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.Failed",
            "Close failed",
        );
        return;
    };
    g_dbus_method_invocation_return_dbus_error(
        invocation,
        "org.freedesktop.DBus.Error.Failed",
        text.ptr,
    );
}

fn returnCloseCommittedUnsynced(
    invocation: *GDBusMethodInvocation,
    id: u32,
    sync_error: history.ParentSyncError,
) void {
    var message: [128:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(
        &message,
        "Close committed id={d}; history parent sync failed: {s}",
        .{ id, @errorName(sync_error) },
    ) catch {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.Failed",
            "Close committed; history parent sync failed",
        );
        return;
    };
    g_dbus_method_invocation_return_dbus_error(
        invocation,
        "org.freedesktop.DBus.Error.Failed",
        text.ptr,
    );
}

fn emitNotificationClosed(self: *DBus, id: u32, reason: u32) void {
    const conn = self.connection orelse return;
    const emitted = g_dbus_connection_emit_signal(
        conn,
        null,
        object_path,
        interface_name,
        "NotificationClosed",
        g_variant_new("(uu)", id, reason),
        null,
    );
    if (emitted == 0) log.warn("NotificationClosed signal failed id={d}", .{id});
}

fn returnInvalidArgs(invocation: *GDBusMethodInvocation, message: [*:0]const u8) void {
    g_dbus_method_invocation_return_dbus_error(
        invocation,
        "org.freedesktop.DBus.Error.InvalidArgs",
        message,
    );
}

fn dbusExpireTimeoutMs(expire_timeout: i32, urgency: u8) ?guint {
    if (urgency == 2) return null;
    if (expire_timeout == 0) return null;
    if (expire_timeout < 0) return default_expire_timeout_ms;
    const requested: u32 = @intCast(expire_timeout);
    return @min(requested, max_expire_timeout_ms);
}

const ParsedHints = struct {
    urgency: u8 = 1,
    transient: bool = false,
};

fn parseHints(hints_variant: *GVariant) ParsedHints {
    var result: ParsedHints = .{};
    var urgency: guchar = result.urgency;
    if (g_variant_lookup(hints_variant, "urgency", "y", &urgency) != 0) {
        result.urgency = urgency;
    }
    var transient_bool: gboolean = 0;
    if (g_variant_lookup(hints_variant, "transient", "b", &transient_bool) != 0) {
        result.transient = transient_bool != 0;
    }
    return result;
}

fn parseActions(allocator: std.mem.Allocator, actions_variant: *GVariant) ![]DBus.Action {
    const child_count = g_variant_n_children(actions_variant);
    if (child_count < 2) return &.{};

    const pair_count = child_count / 2;
    const admitted_pairs = @min(pair_count, max_action_pairs);
    var actions = try allocator.alloc(DBus.Action, @intCast(admitted_pairs));
    errdefer allocator.free(actions);

    var out_idx: u32 = 0;
    var i: gsize = 0;
    while (i + 1 < child_count and out_idx < actions.len) : (i += 2) {
        const key_variant = g_variant_get_child_value(actions_variant, i);
        defer g_variant_unref(key_variant);
        const label_variant = g_variant_get_child_value(actions_variant, i + 1);
        defer g_variant_unref(label_variant);

        const key = std.mem.span(g_variant_get_string(key_variant.?, null));
        const label = std.mem.span(g_variant_get_string(label_variant.?, null));
        actions[out_idx] = .{
            .key = key,
            .label = label,
        };
        out_idx += 1;
    }

    return actions[0..out_idx];
}

fn variantType(signature: [*:0]const u8) *const GVariantType {
    return @ptrCast(signature);
}

fn logGError(context: []const u8, gerr: ?*GError) void {
    if (gerr) |err| {
        defer g_error_free(err);
        log.err("{s}: {s}", .{ context, std.mem.span(err.message) });
        return;
    }
    log.err("{s}", .{context});
}

test "dbus expiry timeout follows notification spec sentinel values" {
    try std.testing.expectEqual(default_expire_timeout_ms, dbusExpireTimeoutMs(-1, 1).?);
    try std.testing.expectEqual(@as(?guint, null), dbusExpireTimeoutMs(0, 1));
    try std.testing.expectEqual(@as(?guint, null), dbusExpireTimeoutMs(5000, 2));
    try std.testing.expectEqual(@as(guint, 1), dbusExpireTimeoutMs(1, 1).?);
    try std.testing.expectEqual(max_expire_timeout_ms, dbusExpireTimeoutMs(@intCast(max_expire_timeout_ms + 1), 1));
}

var test_notify_hook_count: u32 = 0;
var test_legacy_row_calls: u32 = 0;
var test_legacy_close_calls: u32 = 0;
var test_record_legacy_rows: bool = true;

fn countTestNotify(_: DBus.NotifyEvent) void {
    test_notify_hook_count += 1;
}

var test_closed_hook_count: u32 = 0;
var test_closed_hook_id: u32 = 0;
var test_closed_hook_reason: u32 = 0;

fn countTestClosed(event: DBus.ClosedEvent) void {
    test_closed_hook_count += 1;
    test_closed_hook_id = event.id;
    test_closed_hook_reason = event.reason;
}

fn saveTestHistory(path: []const u8, input: history.RowInput) !void {
    var saved = history.History.init(std.testing.allocator);
    defer saved.deinit();
    try saved.upsert(input);
    try saved.saveAtPath(path);
}

fn failPersistClose(
    _: std.mem.Allocator,
    _: []const u8,
    _: u32,
    _: u32,
) anyerror!history.SaveResult {
    return error.InputOutput;
}

fn dbusTestPath(tmp: std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, name });
}

fn readTestHistory(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        std.Options.debug_io,
        path,
        std.testing.allocator,
        .limited(history.max_file_bytes),
    );
}

fn expectNotifyRollback(
    dbus: *DBus,
    id: u32,
    next_id: u32,
    timer: ?guint,
    history_path: []const u8,
    old_file: []const u8,
) !void {
    try std.testing.expectEqual(@as(u32, 1), dbus.state.len());
    try std.testing.expectEqual(next_id, dbus.state.next_id);
    try std.testing.expectEqual(timer, dbus.timers.get(id));
    const state_row = dbus.state.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("old-app", state_row.app_name);
    try std.testing.expectEqualStrings("old-summary", state_row.summary);
    try std.testing.expectEqualStrings("old-body", state_row.body);
    try std.testing.expectEqual(@as(i32, 5000), state_row.expire_timeout);
    try std.testing.expect(!state_row.has_actions);
    const current_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(current_file);
    try std.testing.expectEqualStrings(old_file, current_file);
    try std.testing.expectEqual(@as(u32, 0), test_notify_hook_count);
    try std.testing.expectEqual(@as(u32, 0), test_legacy_row_calls);
}

fn expectCloseRollback(
    dbus: *DBus,
    id: u32,
    timer: ?guint,
    history_path: []const u8,
    old_file: []const u8,
) !void {
    try std.testing.expectEqual(@as(u32, 1), dbus.state.len());
    try std.testing.expectEqual(timer, dbus.timers.get(id));
    const state_row = dbus.state.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("close-app", state_row.app_name);
    try std.testing.expectEqualStrings("close-summary", state_row.summary);
    try std.testing.expectEqualStrings("close-body", state_row.body);
    const current_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(current_file);
    try std.testing.expectEqualStrings(old_file, current_file);
    try std.testing.expectEqual(@as(u32, 0), test_closed_hook_count);
    try std.testing.expectEqual(@as(u32, 0), test_legacy_close_calls);
}

test "TimerChange keeps old source until commit or rollback" {
    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();

    var first = try dbus.prepareTimer(7, 10, 1);
    const first_source = first.new_source orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?guint, null), dbus.timers.get(7));
    first.commit();
    try std.testing.expectEqual(first_source, dbus.timers.get(7).?);

    var second = try dbus.prepareTimer(7, 20, 1);
    const second_source = second.new_source orelse return error.TestUnexpectedResult;
    try std.testing.expect(second_source != first_source);
    try std.testing.expectEqual(first_source, dbus.timers.get(7).?);
    second.rollback();
    try std.testing.expectEqual(first_source, dbus.timers.get(7).?);

    var third = try dbus.prepareTimer(7, 30, 1);
    third.commit();
    try std.testing.expectEqual(third.new_source.?, dbus.timers.get(7).?);
    dbus.cancelTimer(7);
}

test "timer expiry rejects stale source and accepts current source" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();

    dbus.state.next_id = 7;
    const id = try dbus.state.notify(.{
        .app_name = "app",
        .summary = "summary",
        .body = "body",
        .expire_timeout = 1000,
    });
    var saved = history.History.init(std.testing.allocator);
    defer saved.deinit();
    try saved.upsert(.{
        .id = id,
        .created_ns = 1,
        .updated_ns = realtimeNs(),
        .app_name = "app",
        .app_icon = "icon",
        .summary = "summary",
        .body = "body",
        .active = true,
    });
    try saved.saveAtPath(history_path);

    var first = try dbus.prepareTimer(id, 10, 1);
    const first_source = first.new_source orelse return error.TestUnexpectedResult;
    first.commit();

    var second = try dbus.prepareTimer(id, 20, 1);
    const second_source = second.new_source orelse return error.TestUnexpectedResult;
    second.commit();

    var stale_context = TimeoutContext{
        .dbus = &dbus,
        .id = id,
        .source_id = first_source,
    };
    try std.testing.expect(!timeoutSourceIsCurrent(&stale_context));
    try std.testing.expectEqual(glib_source_remove, onNotificationExpired(&stale_context));
    try std.testing.expectEqual(second_source, dbus.timers.get(id).?);
    try std.testing.expect(dbus.state.map.get(id) != null);

    var current_context = TimeoutContext{
        .dbus = &dbus,
        .id = id,
        .source_id = second_source,
    };
    try std.testing.expect(timeoutSourceIsCurrent(&current_context));
    try std.testing.expectEqual(
        glib_source_remove,
        expireAtPathWithPersistence(&dbus, id, second_source, history_path, persistCloseHistory),
    );
    try std.testing.expectEqual(@as(?guint, null), dbus.timers.get(id));
    try std.testing.expect(dbus.state.map.get(id) == null);
}

test "notify History failure rolls back Store timer file hooks and rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);
    const directory_path = try dbusTestPath(tmp, ".");
    defer std.testing.allocator.free(directory_path);

    test_notify_hook_count = 0;
    defer test_notify_hook_count = 0;
    test_legacy_row_calls = 0;
    defer test_legacy_row_calls = 0;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_notify = countTestNotify });
    const no_actions: []const DBus.Action = &.{};
    dbus.state.next_id = 200;
    const old_request = notifications_state.NotifyRequest{
        .app_name = "old-app",
        .summary = "old-summary",
        .body = "old-body",
        .expire_timeout = 5000,
    };
    const id = try dbus.state.notify(old_request);
    var old_timer_change = try dbus.prepareTimer(id, old_request.expire_timeout, 1);
    old_timer_change.commit();
    var old_history = history.History.init(std.testing.allocator);
    defer old_history.deinit();
    try old_history.upsert(.{
        .id = id,
        .created_ns = 1,
        .updated_ns = 2,
        .app_name = old_request.app_name,
        .app_icon = "old-icon",
        .summary = old_request.summary,
        .body = old_request.body,
        .urgency = 1,
        .active = true,
    });
    try old_history.saveAtPath(history_path);
    const old_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(old_file);
    const old_next_id = dbus.state.next_id;
    const old_timer = dbus.timers.get(id);

    const oversized_body = [_]u8{'x'} ** (history.max_body_bytes + 1);
    try std.testing.expectError(
        error.HistoryFieldTooLong,
        applyNotifyAtPath(&dbus, .{
            .app_name = "new-app",
            .summary = "new-summary",
            .body = &oversized_body,
            .replaces_id = id,
            .expire_timeout = 9000,
        }, "new-icon", 2, true, no_actions, history_path),
    );
    try expectNotifyRollback(&dbus, id, old_next_id, old_timer, history_path, old_file);

    try std.testing.expectError(
        error.IsDir,
        applyNotifyAtPath(&dbus, .{
            .app_name = "new-app",
            .summary = "new-summary",
            .body = "new-body",
            .replaces_id = id,
        }, "new-icon", 2, true, no_actions, directory_path),
    );
    try expectNotifyRollback(&dbus, id, old_next_id, old_timer, history_path, old_file);

    try std.testing.expectError(
        error.HistoryFieldTooLong,
        applyNotifyAtPath(&dbus, .{
            .app_name = "new-app",
            .summary = "new-summary",
            .body = &oversized_body,
        }, "new-icon", 2, true, no_actions, history_path),
    );
    try expectNotifyRollback(&dbus, id, old_next_id, old_timer, history_path, old_file);

    const save_failure_path = "/proc/wayspot-notification-history-order2.json";
    const save_result = applyNotifyAtPath(&dbus, .{
        .app_name = "new-app",
        .summary = "new-summary",
        .body = "new-body",
        .replaces_id = id,
    }, "new-icon", 2, true, no_actions, save_failure_path);
    if (save_result) |_| return error.TestUnexpectedResult else |_| {}
    try expectNotifyRollback(&dbus, id, old_next_id, old_timer, history_path, old_file);
}

test "post-replace History failure commits Store timer and effects" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    test_notify_hook_count = 0;
    defer test_notify_hook_count = 0;
    test_legacy_row_calls = 0;
    defer test_legacy_row_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_notify = countTestNotify });
    const no_actions: []const DBus.Action = &.{};
    const commit = try applyNotifyAtPathWithPersistence(
        &dbus,
        .{
            .app_name = "new-app",
            .summary = "new-summary",
            .body = "new-body",
            .expire_timeout = 5000,
        },
        "new-icon",
        1,
        true,
        no_actions,
        history_path,
        persistHistoryPublishedUnsynced,
    );
    switch (commit) {
        .accepted => return error.TestUnexpectedResult,
        .committed_unsynced => |published| {
            try std.testing.expectEqual(@as(u32, 1), published.id);
            try std.testing.expectEqual(error.InputOutput, published.sync_error);
        },
    }

    try std.testing.expectEqual(@as(u32, 1), dbus.state.len());
    try std.testing.expectEqual(@as(u32, 2), dbus.state.next_id);
    const row = dbus.state.map.get(1) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("new-app", row.app_name);
    try std.testing.expectEqualStrings("new-summary", row.summary);
    try std.testing.expect(dbus.timers.get(1) != null);
    try std.testing.expectEqual(@as(u32, 1), test_notify_hook_count);
    try std.testing.expectEqual(@as(u32, 1), test_legacy_row_calls);

    var saved = try history.History.loadAtPath(std.testing.allocator, history_path, 0);
    defer saved.deinit();
    try std.testing.expectEqual(@as(u32, 1), saved.len());
    try std.testing.expectEqualStrings("new-summary", saved.rows.items[0].summary);
}

test "notify history preserves replacement created time and dates new rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    test_notify_hook_count = 0;
    defer test_notify_hook_count = 0;
    test_legacy_row_calls = 0;
    defer test_legacy_row_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    const old_id = try dbus.state.notify(.{
        .app_name = "old-app",
        .summary = "old-summary",
        .body = "old-body",
    });
    const old_created_ns: u64 = 77;
    try saveTestHistory(history_path, .{
        .id = old_id,
        .created_ns = old_created_ns,
        .updated_ns = realtimeNs(),
        .app_name = "old-app",
        .app_icon = "old-icon",
        .summary = "old-summary",
        .body = "old-body",
        .active = true,
    });

    const replacement = try applyNotifyAtPath(
        &dbus,
        .{
            .app_name = "new-app",
            .summary = "new-summary",
            .body = "new-body",
            .replaces_id = old_id,
        },
        "new-icon",
        2,
        true,
        &.{},
        history_path,
    );
    switch (replacement) {
        .accepted => |id| try std.testing.expectEqual(old_id, id),
        .committed_unsynced => return error.TestUnexpectedResult,
    }

    const created_before_new = realtimeNs();
    const new_result = try applyNotifyAtPath(
        &dbus,
        .{
            .app_name = "fresh-app",
            .summary = "fresh-summary",
            .body = "fresh-body",
        },
        "fresh-icon",
        1,
        false,
        &.{},
        history_path,
    );
    switch (new_result) {
        .accepted => |id| try std.testing.expectEqual(@as(u32, 2), id),
        .committed_unsynced => return error.TestUnexpectedResult,
    }

    var loaded = try history.History.loadAtPath(std.testing.allocator, history_path, realtimeNs());
    defer loaded.deinit();
    var found_replacement = false;
    var found_new = false;
    for (loaded.rows.items) |row| {
        if (row.id == old_id) {
            found_replacement = true;
            try std.testing.expectEqual(old_created_ns, row.created_ns);
            try std.testing.expectEqualStrings("new-app", row.app_name);
            try std.testing.expectEqualStrings("new-summary", row.summary);
        }
        if (row.id == 2) {
            found_new = true;
            try std.testing.expect(row.created_ns >= created_before_new);
            try std.testing.expectEqualStrings("fresh-summary", row.summary);
        }
    }
    try std.testing.expect(found_replacement);
    try std.testing.expect(found_new);
}

test "close persists every durable field before live removal" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    test_closed_hook_count = 0;
    defer test_closed_hook_count = 0;
    test_legacy_close_calls = 0;
    defer test_legacy_close_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_closed = countTestClosed });
    const id = try dbus.state.notify(.{
        .app_name = "close-app",
        .summary = "close-summary",
        .body = "close-body",
    });
    var timer = try dbus.prepareTimer(id, 10, 1);
    timer.commit();
    const original_updated_ns = realtimeNs();
    try saveTestHistory(history_path, .{
        .id = id,
        .created_ns = 123,
        .updated_ns = original_updated_ns,
        .app_name = "durable-app",
        .app_icon = "durable-icon",
        .summary = "durable-summary",
        .body = "durable-body",
        .urgency = 2,
        .transient = true,
        .active = true,
    });

    const result = try closeWithReasonAtPathWithPersistence(
        &dbus,
        id,
        close_reason_closed,
        history_path,
        persistCloseHistory,
    );
    try std.testing.expectEqual(DBus.CloseResult.closed, result);
    try std.testing.expect(dbus.state.map.get(id) == null);
    try std.testing.expectEqual(@as(?guint, null), dbus.timers.get(id));
    try std.testing.expectEqual(@as(u32, 1), test_closed_hook_count);
    try std.testing.expectEqual(id, test_closed_hook_id);
    try std.testing.expectEqual(close_reason_closed, test_closed_hook_reason);
    try std.testing.expectEqual(@as(u32, 1), test_legacy_close_calls);

    var loaded = try history.History.loadAtPath(std.testing.allocator, history_path, realtimeNs());
    defer loaded.deinit();
    const row = loaded.rows.items[0];
    try std.testing.expectEqual(id, row.id);
    try std.testing.expectEqual(@as(u64, 123), row.created_ns);
    try std.testing.expect(row.updated_ns >= original_updated_ns);
    try std.testing.expectEqualStrings("durable-app", row.app_name);
    try std.testing.expectEqualStrings("durable-icon", row.app_icon);
    try std.testing.expectEqualStrings("durable-summary", row.summary);
    try std.testing.expectEqualStrings("durable-body", row.body);
    try std.testing.expectEqual(@as(u8, 2), row.urgency);
    try std.testing.expect(row.transient);
    try std.testing.expect(!row.active);
    try std.testing.expectEqual(close_reason_closed, row.closed_reason);
}

test "close missing durable row leaves live state and timer unchanged" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "missing.json");
    defer std.testing.allocator.free(history_path);

    test_closed_hook_count = 0;
    defer test_closed_hook_count = 0;
    test_legacy_close_calls = 0;
    defer test_legacy_close_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    const id = try dbus.state.notify(.{
        .app_name = "close-app",
        .summary = "close-summary",
        .body = "close-body",
    });
    var timer = try dbus.prepareTimer(id, 10, 1);
    timer.commit();

    try std.testing.expectError(
        error.UnknownNotificationId,
        closeWithReasonAtPathWithPersistence(
            &dbus,
            id + 1,
            close_reason_closed,
            history_path,
            persistCloseHistory,
        ),
    );
    try std.testing.expectError(
        error.HistoryRowNotFound,
        closeWithReasonAtPathWithPersistence(
            &dbus,
            id,
            close_reason_closed,
            history_path,
            persistCloseHistory,
        ),
    );
    try std.testing.expectEqual(@as(u32, 1), dbus.state.len());
    try std.testing.expectEqual(timer.new_source, dbus.timers.get(id));
    try std.testing.expectEqual(@as(u32, 0), test_closed_hook_count);
    try std.testing.expectEqual(@as(u32, 0), test_legacy_close_calls);
    try std.testing.expectError(
        error.FileNotFound,
        readTestHistory(history_path),
    );
}

test "close pre-replace failure preserves live state timer file and effects" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);
    const directory_path = try dbusTestPath(tmp, ".");
    defer std.testing.allocator.free(directory_path);

    test_closed_hook_count = 0;
    defer test_closed_hook_count = 0;
    test_legacy_close_calls = 0;
    defer test_legacy_close_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_closed = countTestClosed });
    const id = try dbus.state.notify(.{
        .app_name = "close-app",
        .summary = "close-summary",
        .body = "close-body",
    });
    var timer = try dbus.prepareTimer(id, 10, 1);
    timer.commit();
    try saveTestHistory(history_path, .{
        .id = id,
        .created_ns = 123,
        .updated_ns = realtimeNs(),
        .app_name = "close-app",
        .summary = "close-summary",
        .body = "close-body",
        .active = true,
    });
    const old_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(old_file);
    const old_timer = dbus.timers.get(id);

    try std.testing.expectError(
        error.IsDir,
        closeWithReasonAtPathWithPersistence(
            &dbus,
            id,
            close_reason_closed,
            directory_path,
            persistCloseHistory,
        ),
    );
    try expectCloseRollback(&dbus, id, old_timer, history_path, old_file);

    try std.testing.expectError(
        error.InputOutput,
        closeWithReasonAtPathWithPersistence(
            &dbus,
            id,
            close_reason_closed,
            history_path,
            failPersistClose,
        ),
    );
    try expectCloseRollback(&dbus, id, old_timer, history_path, old_file);
}

test "close parent sync failure commits live close and effects" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    test_closed_hook_count = 0;
    defer test_closed_hook_count = 0;
    test_legacy_close_calls = 0;
    defer test_legacy_close_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_closed = countTestClosed });
    const id = try dbus.state.notify(.{
        .app_name = "close-app",
        .summary = "close-summary",
        .body = "close-body",
    });
    var timer = try dbus.prepareTimer(id, 10, 1);
    timer.commit();
    try saveTestHistory(history_path, .{
        .id = id,
        .created_ns = 321,
        .updated_ns = realtimeNs(),
        .app_name = "durable-app",
        .app_icon = "durable-icon",
        .summary = "durable-summary",
        .body = "durable-body",
        .urgency = 2,
        .transient = true,
        .active = true,
    });

    const result = try closeWithReasonAtPathWithPersistence(
        &dbus,
        id,
        close_reason_expired,
        history_path,
        persistCloseHistoryPublishedUnsynced,
    );
    switch (result) {
        .closed => return error.TestUnexpectedResult,
        .committed_unsynced => |err| try std.testing.expectEqual(error.InputOutput, err),
    }
    try std.testing.expect(dbus.state.map.get(id) == null);
    try std.testing.expectEqual(@as(?guint, null), dbus.timers.get(id));
    try std.testing.expectEqual(@as(u32, 1), test_closed_hook_count);
    try std.testing.expectEqual(@as(u32, 1), test_legacy_close_calls);

    var loaded = try history.History.loadAtPath(std.testing.allocator, history_path, realtimeNs());
    defer loaded.deinit();
    const row = loaded.rows.items[0];
    try std.testing.expectEqual(@as(u64, 321), row.created_ns);
    try std.testing.expectEqualStrings("durable-app", row.app_name);
    try std.testing.expectEqualStrings("durable-icon", row.app_icon);
    try std.testing.expectEqualStrings("durable-summary", row.summary);
    try std.testing.expectEqualStrings("durable-body", row.body);
    try std.testing.expectEqual(@as(u8, 2), row.urgency);
    try std.testing.expect(row.transient);
    try std.testing.expect(!row.active);
    try std.testing.expectEqual(close_reason_expired, row.closed_reason);
}

test "expiry retries pre-replace failure and closes on success" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    test_closed_hook_count = 0;
    defer test_closed_hook_count = 0;
    test_legacy_close_calls = 0;
    defer test_legacy_close_calls = 0;
    test_record_legacy_rows = false;
    defer test_record_legacy_rows = true;

    var dbus = try DBus.init(std.testing.allocator);
    defer dbus.deinit();
    dbus.setHooks(.{ .on_closed = countTestClosed });
    const id = try dbus.state.notify(.{
        .app_name = "expiry-app",
        .summary = "expiry-summary",
        .body = "expiry-body",
    });
    var timer = try dbus.prepareTimer(id, 10, 1);
    timer.commit();
    const source_id = timer.new_source orelse return error.TestUnexpectedResult;
    try saveTestHistory(history_path, .{
        .id = id,
        .created_ns = 456,
        .updated_ns = realtimeNs(),
        .app_name = "expiry-app",
        .app_icon = "expiry-icon",
        .summary = "expiry-summary",
        .body = "expiry-body",
        .active = true,
    });
    const old_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(old_file);

    try std.testing.expectEqual(
        glib_source_continue,
        expireAtPathWithPersistence(&dbus, id, source_id, history_path, failPersistClose),
    );
    try std.testing.expectEqual(source_id, dbus.timers.get(id).?);
    try std.testing.expect(dbus.state.map.get(id) != null);
    try std.testing.expectEqual(@as(u32, 0), test_closed_hook_count);
    try std.testing.expectEqual(@as(u32, 0), test_legacy_close_calls);
    const current_file = try readTestHistory(history_path);
    defer std.testing.allocator.free(current_file);
    try std.testing.expectEqualStrings(old_file, current_file);

    try std.testing.expectEqual(
        glib_source_remove,
        expireAtPathWithPersistence(&dbus, id, source_id, history_path, persistCloseHistory),
    );
    try std.testing.expect(dbus.state.map.get(id) == null);
    try std.testing.expectEqual(@as(?guint, null), dbus.timers.get(id));
    try std.testing.expectEqual(@as(u32, 1), test_closed_hook_count);
    try std.testing.expectEqual(@as(u32, 1), test_legacy_close_calls);

    var loaded = try history.History.loadAtPath(std.testing.allocator, history_path, realtimeNs());
    defer loaded.deinit();
    try std.testing.expect(!loaded.rows.items[0].active);
    try std.testing.expectEqual(close_reason_expired, loaded.rows.items[0].closed_reason);
}

test "DBus deinit creates no durable history row" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const history_path = try dbusTestPath(tmp, "history.json");
    defer std.testing.allocator.free(history_path);

    var dbus = try DBus.init(std.testing.allocator);
    const id = try dbus.state.notify(.{
        .app_name = "deinit-app",
        .summary = "deinit-summary",
        .body = "deinit-body",
    });
    try std.testing.expectEqual(@as(u32, 1), id);
    dbus.deinit();

    try std.testing.expectError(
        error.FileNotFound,
        readTestHistory(history_path),
    );
}
