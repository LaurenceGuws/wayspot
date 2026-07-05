//! Notification daemon owns the Freedesktop D-Bus service and banner dispatch.

const std = @import("std");
const history_cache = @import("history_cache.zig");
const notifications_state = @import("state.zig");
const notifications_runtime = @import("runtime.zig");
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
const G_BUS_NAME_OWNER_FLAGS_REPLACE: GBusNameOwnerFlags = 1 << 1;

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
    var daemon = try Daemon.init(allocator);
    defer daemon.deinit();
    daemon.setHooks(.{ .on_notify = onNotifyBanner });
    try daemon.start();

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

pub const Daemon = struct {
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

    allocator: std.mem.Allocator,
    state: notifications_state.Store,
    timers: std.AutoHashMap(u32, guint),
    owner_id: guint = 0,
    registration_id: guint = 0,
    node_info: ?*GDBusNodeInfo = null,
    connection: ?*GDBusConnection = null,
    hooks: Hooks = .{},

    pub fn init(allocator: std.mem.Allocator) !Daemon {
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

    pub fn start(self: *Daemon) !void {
        if (self.owner_id != 0) return;
        self.owner_id = g_bus_own_name(
            G_BUS_TYPE_SESSION,
            service_name,
            G_BUS_NAME_OWNER_FLAGS_REPLACE,
            onBusAcquired,
            onNameAcquired,
            onNameLost,
            self,
            null,
        );
        if (self.owner_id == 0) return error.NotificationsBusOwnFailed;
    }

    pub fn deinit(self: *Daemon) void {
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

    pub fn setHooks(self: *Daemon, hooks: Hooks) void {
        self.hooks = hooks;
    }

    pub fn clearHooks(self: *Daemon) void {
        self.hooks = .{};
    }

    pub fn closeWithReason(self: *Daemon, id: u32, reason: u32) bool {
        if (!self.state.close(id)) return false;
        self.cancelTimer(id);
        notifications_runtime.recordClosed(id, reason);
        emitNotificationClosed(self, id, reason);
        if (self.hooks.on_closed) |on_closed| {
            on_closed(.{
                .id = id,
                .reason = reason,
            });
        }
        return true;
    }

    fn replaceTimer(self: *Daemon, id: u32, expire_timeout: i32, urgency: u8) !void {
        self.cancelTimer(id);
        const timeout_ms = daemonExpireTimeoutMs(expire_timeout, urgency) orelse return;
        const context = try self.allocator.create(TimeoutContext);
        context.* = .{ .daemon = self, .id = id };
        const source_id = g_timeout_add_full(
            glib_priority_default,
            timeout_ms,
            onNotificationExpired,
            context,
            freeTimeoutContext,
        );
        if (source_id == 0) {
            self.allocator.destroy(context);
            return error.NotificationTimerFailed;
        }
        self.timers.put(id, source_id) catch |err| {
            const source_removed = g_source_remove(source_id);
            if (source_removed == 0) log.debug("notification timer cleanup missed id={d}", .{id});
            return err;
        };
    }

    fn cancelTimer(self: *Daemon, id: u32) void {
        const removed = self.timers.fetchRemove(id) orelse return;
        const source_removed = g_source_remove(removed.value);
        if (source_removed == 0) log.debug("notification timer already removed id={d}", .{id});
    }

    fn clearTimers(self: *Daemon) void {
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            const source_removed = g_source_remove(entry.value_ptr.*);
            if (source_removed == 0) {
                log.debug("notification timer already removed id={d}", .{entry.key_ptr.*});
            }
        }
        self.timers.clearRetainingCapacity();
    }

    pub fn emitActionInvoked(self: *Daemon, id: u32, action_key: []const u8) void {
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

const TimeoutContext = struct {
    daemon: *Daemon,
    id: u32,
};

fn onNotificationExpired(user_data: ?*anyopaque) callconv(.c) gboolean {
    const raw = user_data orelse return glib_source_remove;
    const context: *TimeoutContext = @ptrCast(@alignCast(raw));
    const removed = context.daemon.timers.fetchRemove(context.id);
    if (removed != null) {
        const closed = context.daemon.closeWithReason(context.id, close_reason_expired);
        if (!closed) log.debug("notification expiry ignored inactive id={d}", .{context.id});
    }
    return glib_source_remove;
}

fn freeTimeoutContext(user_data: ?*anyopaque) callconv(.c) void {
    const raw = user_data orelse return;
    const context: *TimeoutContext = @ptrCast(@alignCast(raw));
    context.daemon.allocator.destroy(context);
}

fn onBusAcquired(connection: ?*GDBusConnection, _: [*c]const u8, user_data: ?*anyopaque) callconv(.c) void {
    if (connection == null or user_data == null) return;
    const self: *Daemon = @ptrCast(@alignCast(user_data.?));

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
    const self: *Daemon = @ptrCast(@alignCast(user_data.?));
    self.registration_id = 0;
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
    const self: *Daemon = @ptrCast(@alignCast(user_data.?));
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

fn handleNotify(self: *Daemon, parameters: ?*GVariant, invocation: *GDBusMethodInvocation) void {
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

    const replaced = replaces_id != 0 and self.state.map.getPtr(replaces_id) != null;
    const id = self.state.notify(.{
        .app_name = std.mem.span(app_name),
        .summary = std.mem.span(summary),
        .body = std.mem.span(body),
        .replaces_id = replaces_id,
        .expire_timeout = expire_timeout,
        .has_actions = has_actions,
    }) catch {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.NoMemory",
            "Unable to persist notification",
        );
        return;
    };
    self.replaceTimer(id, expire_timeout, parsed_hints.urgency) catch {
        const removed_after_timer_failure = self.state.close(id);
        if (!removed_after_timer_failure) log.debug("timer failure cleanup missed id={d}", .{id});
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.DBus.Error.NoMemory",
            "Unable to schedule notification expiry",
        );
        return;
    };

    if (self.hooks.on_notify) |on_notify| {
        on_notify(.{
            .id = id,
            .app_name = std.mem.span(app_name),
            .app_icon = std.mem.span(app_icon),
            .summary = std.mem.span(summary),
            .body = std.mem.span(body),
            .expire_timeout = expire_timeout,
            .replaced = replaced and id == replaces_id,
            .urgency = parsed_hints.urgency,
            .transient = parsed_hints.transient,
            .actions = action_pairs,
        });
    }
    persistHistory(self.allocator, .{
        .id = id,
        .created_ns = 0,
        .updated_ns = 0,
        .app_name = std.mem.span(app_name),
        .app_icon = std.mem.span(app_icon),
        .summary = std.mem.span(summary),
        .body = std.mem.span(body),
        .urgency = parsed_hints.urgency,
        .transient = parsed_hints.transient,
        .active = true,
    }) catch |err| {
        log.warn("notification history save failed id={d} app=\"{s}\" err={s}", .{
            id,
            std.mem.span(app_name),
            @errorName(err),
        });
    };
    notifications_runtime.recordNotify(
        self.allocator,
        id,
        std.mem.span(app_name),
        std.mem.span(app_icon),
        std.mem.span(summary),
        std.mem.span(body),
        parsed_hints.urgency,
        parsed_hints.transient,
    ) catch |err| {
        std.log.warn("notifications runtime record failed id={d} err={s}", .{ id, @errorName(err) });
    };
    log.info(
        "notify id={d} app=\"{s}\" summary=\"{s}\" urgency={d} actions={d} replaced={}",
        .{
            id,
            std.mem.span(app_name),
            std.mem.span(summary),
            parsed_hints.urgency,
            @as(u32, @intCast(action_pairs.len)),
            replaced and id == replaces_id,
        },
    );

    g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", id));
}

fn persistHistory(allocator: std.mem.Allocator, input: history_cache.RowInput) !void {
    const now_ns = realtimeNs();
    var cache = try history_cache.load(allocator, now_ns);
    defer cache.deinit();
    var row = input;
    row.created_ns = now_ns;
    row.updated_ns = now_ns;
    try cache.upsert(row);
    cache.pruneOld(now_ns);
    const path = try history_cache.cachePath(allocator);
    defer allocator.free(path);
    try cache.saveAtPath(path);
}

fn realtimeNs() u64 {
    var ts: std.os.linux.timespec = undefined;
    const rc = std.os.linux.clock_gettime(.REALTIME, &ts);
    if (std.os.linux.errno(rc) != .SUCCESS) return 0;
    const seconds_ns: u64 = @intCast(ts.sec * std.time.ns_per_s);
    const nanos: u64 = @intCast(ts.nsec);
    return seconds_ns + nanos;
}

fn onNotifyBanner(event: Daemon.NotifyEvent) void {
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

fn handleCloseNotification(self: *Daemon, parameters: ?*GVariant, invocation: *GDBusMethodInvocation) void {
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

    const closed = self.closeWithReason(notification_id, close_reason_closed);
    if (!closed) {
        g_dbus_method_invocation_return_dbus_error(
            invocation,
            "org.freedesktop.Notifications.InvalidId",
            "Unknown notification id",
        );
        return;
    }

    g_dbus_method_invocation_return_value(invocation, g_variant_new("()"));
}

fn emitNotificationClosed(self: *Daemon, id: u32, reason: u32) void {
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

fn daemonExpireTimeoutMs(expire_timeout: i32, urgency: u8) ?guint {
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

fn parseActions(allocator: std.mem.Allocator, actions_variant: *GVariant) ![]Daemon.Action {
    const child_count = g_variant_n_children(actions_variant);
    if (child_count < 2) return &.{};

    const pair_count = child_count / 2;
    const admitted_pairs = @min(pair_count, max_action_pairs);
    var actions = try allocator.alloc(Daemon.Action, @intCast(admitted_pairs));
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

test "daemon expiry timeout follows notification spec sentinel values" {
    try std.testing.expectEqual(default_expire_timeout_ms, daemonExpireTimeoutMs(-1, 1).?);
    try std.testing.expectEqual(@as(?guint, null), daemonExpireTimeoutMs(0, 1));
    try std.testing.expectEqual(@as(?guint, null), daemonExpireTimeoutMs(5000, 2));
    try std.testing.expectEqual(@as(guint, 1), daemonExpireTimeoutMs(1, 1).?);
    try std.testing.expectEqual(max_expire_timeout_ms, daemonExpireTimeoutMs(@intCast(max_expire_timeout_ms + 1), 1));
}
