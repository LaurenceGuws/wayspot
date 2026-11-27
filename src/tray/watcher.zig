//! Small, bounded StatusNotifierWatcher service on the user D-Bus session.
//! The UI host opens on demand; application registration must outlive the picker.
const std = @import("std");
const dbus = @import("dbus_c");
const Stop = @import("../stop.zig");

/// Maximum simultaneously registered status notifier items.
pub const max_items = 12;
const max_name = 160;
const max_path = 160;
const watcher_path: [*:0]const u8 = "/StatusNotifierWatcher";
const kde_interface: [*:0]const u8 = "org.kde.StatusNotifierWatcher";
const fd_interface: [*:0]const u8 = "org.freedesktop.StatusNotifierWatcher";
const kde_name: [*:0]const u8 = "org.kde.StatusNotifierWatcher";
const fd_name: [*:0]const u8 = "org.freedesktop.StatusNotifierWatcher";
const properties_interface: [*:0]const u8 = "org.freedesktop.DBus.Properties";
const introspect_interface: [*:0]const u8 = "org.freedesktop.DBus.Introspectable";

/// Unique DBus owner + item service/path. Never retain unbounded external text.
const Item = struct {
    service: [max_name:0]u8 = @splat(0),
    length: u8 = 0,
    path: [max_path:0]u8 = @splat(0),
    path_length: u8 = 0,
    owner: [max_name:0]u8 = @splat(0),
    owner_length: u8 = 0,

    fn create(sender: []const u8, registration: []const u8) !Item {
        var result: Item = .{};
        if (sender.len == 0 or sender[0] != ':' or !copyBounded(&result.owner, sender))
            return error.InvalidOwner;
        if (dbus.dbus_validate_bus_name(&result.owner, null) == 0) return error.InvalidOwner;
        result.owner_length = @intCast(sender.len);

        const with_path = registration.len > 0 and registration[0] == '/';
        const service = if (with_path) sender else registration;
        const path = if (with_path) registration else "/StatusNotifierItem";
        if (!copyBounded(&result.service, service) or !copyBounded(&result.path, path))
            return error.InvalidItem;
        if (path.len < 2 or dbus.dbus_validate_bus_name(&result.service, null) == 0 or
            dbus.dbus_validate_path(&result.path, null) == 0) return error.InvalidItem;
        result.length = @intCast(service.len);
        result.path_length = @intCast(path.len);
        return result;
    }

    fn serviceName(self: *const Item) [:0]const u8 {
        return self.service[0..self.length :0];
    }
    fn pathName(self: *const Item) [:0]const u8 {
        return self.path[0..self.path_length :0];
    }
    fn senderName(self: *const Item) [:0]const u8 {
        return self.owner[0..self.owner_length :0];
    }
    fn identifier(self: *const Item, output: *[max_name + max_path + 1:0]u8) [:0]const u8 {
        const service = self.serviceName();
        const path = self.pathName();
        @memcpy(output[0..service.len], service);
        @memcpy(output[service.len..][0..path.len], path);
        output[service.len + path.len] = 0;
        return output[0 .. service.len + path.len :0];
    }
};

fn copyBounded(buffer: []u8, value: []const u8) bool {
    if (value.len == 0 or value.len >= buffer.len) return false;
    if (std.mem.indexOfScalar(u8, value, 0) != null) return false;
    @memcpy(buffer[0..value.len], value);
    buffer[value.len] = 0;
    return true;
}

const State = struct {
    items: [max_items]Item = undefined,
    count: usize = 0,
    host: bool = true, // Wayspot's GUI host is available on demand.

    fn register(self: *State, candidate: Item) !?*const Item {
        for (self.items[0..self.count]) |*item| {
            if (std.mem.eql(u8, item.serviceName(), candidate.serviceName()) and
                std.mem.eql(u8, item.pathName(), candidate.pathName()))
            {
                if (!std.mem.eql(u8, item.senderName(), candidate.senderName()))
                    return error.InvalidOwner;
                return null;
            }
        }
        if (self.count == max_items) return error.TooManyTrayItems;
        self.items[self.count] = candidate;
        self.count += 1;
        return &self.items[self.count - 1];
    }

    fn unregister(
        self: *State,
        name: []const u8,
        previous_owner: []const u8,
        removed: *Item,
    ) bool {
        for (self.items[0..self.count], 0..) |entry, index| {
            if (!std.mem.eql(u8, previous_owner, entry.senderName())) continue;
            if (!std.mem.eql(u8, name, entry.senderName()) and
                !std.mem.eql(u8, name, entry.serviceName())) continue;
            removed.* = entry;
            self.count -= 1;
            self.items[index] = self.items[self.count];
            return true;
        }
        return false;
    }
};

/// Sole resident owns a private bus connection, item registrations and replies.
pub const Watcher = struct {
    connection: ?*dbus.DBusConnection = null,
    state: State = .{},

    /// Acquires both watcher names and the authenticated owner-change subscription.
    pub fn open(self: *Watcher) !void {
        if (self.connection != null) return error.TrayWatcherAlreadyOpen;
        self.connection = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse
            return error.TrayBusUnavailable;
        errdefer self.close();
        const conn = self.connection.?;
        dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
        dbus.dbus_connection_set_max_message_size(conn, 128 * 1024);
        dbus.dbus_connection_set_max_message_unix_fds(conn, 0);
        try ownName(conn, kde_name);
        // Startup failure closes this connection and releases any acquired names.
        try ownName(conn, fd_name);
        try subscribeOwnerChanges(conn);
    }

    /// Retires the private connection and its entire registration snapshot.
    pub fn close(self: *Watcher) void {
        if (self.connection) |conn| {
            dbus.dbus_connection_close(conn);
            dbus.dbus_connection_unref(conn);
            self.connection = null;
        }
        self.state = .{};
    }

    /// Borrows the poll descriptor, or -1 when the watcher is closed.
    pub fn fd(self: *const Watcher) !std.posix.fd_t {
        const conn = self.connection orelse return -1;
        var value: c_int = -1;
        if (dbus.dbus_connection_get_unix_fd(conn, &value) == 0 or value < 0)
            return error.TrayBusSocketUnavailable;
        return value;
    }

    /// Returns the current admitted registration count.
    pub fn count(self: *const Watcher) usize {
        return self.state.count;
    }

    /// Pumps at most 64 messages; true requests another immediate turn.
    pub fn advance(self: *Watcher) !bool {
        const conn = self.connection orelse return error.TrayBusUnavailable;
        if (dbus.dbus_connection_read_write(conn, 0) == 0) return error.TrayBusDisconnected;
        for (0..64) |_| {
            const message = dbus.dbus_connection_pop_message(conn) orelse return false;
            defer dbus.dbus_message_unref(message);
            try self.dispatch(message);
        }
        return true;
    }

    fn dispatch(self: *Watcher, message: *dbus.DBusMessage) !void {
        if (dbus.dbus_message_is_signal(message, dbus.DBUS_INTERFACE_DBUS, "NameOwnerChanged") != 0)
            return self.ownerChanged(message);
        if (dbus.dbus_message_get_type(message) != dbus.DBUS_MESSAGE_TYPE_METHOD_CALL or
            dbus.dbus_message_has_path(message, watcher_path) == 0) return;
        if (dbus.dbus_message_has_interface(message, properties_interface) != 0) {
            return self.propertyCall(message);
        }
        if (dbus.dbus_message_has_interface(message, introspect_interface) != 0) {
            if (dbus.dbus_message_is_method_call(
                message,
                introspect_interface,
                "Introspect",
            ) != 0) {
                if (dbus.dbus_message_has_signature(message, "") == 0)
                    return self.invalidArgs(message);
                return self.introspect(message);
            }
        }
        if (dbus.dbus_message_has_interface(message, kde_interface) == 0 and
            dbus.dbus_message_has_interface(message, fd_interface) == 0)
        {
            return self.replyError(
                message,
                "org.freedesktop.DBus.Error.UnknownInterface",
                "Unknown interface",
            );
        }
        if (watcherMethod(message, "RegisterStatusNotifierItem"))
            return self.registerItem(message);
        if (watcherMethod(message, "RegisterStatusNotifierHost")) {
            if (dbus.dbus_message_has_signature(message, "s") == 0)
                return self.invalidArgs(message);
            try self.replyEmpty(message);
            try self.signalNoArg("StatusNotifierHostRegistered");
            return;
        }
        return self.replyError(
            message,
            "org.freedesktop.DBus.Error.UnknownMethod",
            "Unknown tray watcher method",
        );
    }

    fn ownerChanged(self: *Watcher, message: *dbus.DBusMessage) !void {
        // A directed signal can bypass the match rule. Authenticate the bus
        // daemon's sender and object path before trusting an ownership event.
        if (dbus.dbus_message_has_sender(message, dbus.DBUS_SERVICE_DBUS) == 0 or
            dbus.dbus_message_has_path(message, dbus.DBUS_PATH_DBUS) == 0 or
            dbus.dbus_message_has_signature(message, "sss") == 0) return;
        var iter: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_init(message, &iter) == 0) return;
        const name = stringArg(&iter);
        if (dbus.dbus_message_iter_next(&iter) == 0) return;
        const previous_owner = stringArg(&iter);
        if (dbus.dbus_message_iter_next(&iter) == 0) return;
        const next_owner = stringArg(&iter);
        if (previous_owner.len == 0 or std.mem.eql(u8, previous_owner, next_owner)) return;

        // A unique-name loss removes its items; a well-known-name loss
        // removes only that name's registrations from that previous owner.
        for (0..max_items) |_| {
            var removed: Item = undefined;
            if (!self.state.unregister(name, previous_owner, &removed)) break;
            try self.signalItem("StatusNotifierItemUnregistered", &removed);
        }
    }

    fn registerItem(self: *Watcher, message: *dbus.DBusMessage) !void {
        if (dbus.dbus_message_has_signature(message, "s") == 0)
            return self.invalidArgs(message);
        var iter: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
        const sender = dbus.dbus_message_get_sender(message) orelse
            return self.invalidArgs(message);
        const candidate = Item.create(std.mem.span(sender), stringArg(&iter)) catch
            return self.invalidArgs(message);
        const conn = self.connection orelse return error.TrayBusDisconnected;
        if (!try senderOwnsRegistration(conn, candidate.serviceName(), candidate.senderName()))
            return self.invalidArgs(message);
        const item = self.state.register(candidate) catch return self.invalidArgs(message);
        try self.replyEmpty(message);
        if (item) |value| try self.signalItem("StatusNotifierItemRegistered", value);
    }

    fn propertyCall(self: *Watcher, message: *dbus.DBusMessage) !void {
        if (dbus.dbus_message_is_method_call(message, properties_interface, "Get") != 0) {
            if (dbus.dbus_message_has_signature(message, "ss") == 0)
                return self.invalidArgs(message);
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
            const interface = stringArg(&iter);
            if (dbus.dbus_message_iter_next(&iter) == 0) return self.invalidArgs(message);
            const property = std.meta.stringToEnum(Property, stringArg(&iter)) orelse
                return self.invalidArgs(message);
            if (!validWatcherInterface(interface)) return self.invalidArgs(message);
            const reply = dbus.dbus_message_new_method_return(message) orelse
                return error.OutOfMemory;
            defer dbus.dbus_message_unref(reply);
            var out: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(reply, &out);
            try self.appendProperty(&out, property);
            return self.send(reply);
        }
        if (dbus.dbus_message_is_method_call(message, properties_interface, "GetAll") != 0) {
            if (dbus.dbus_message_has_signature(message, "s") == 0)
                return self.invalidArgs(message);
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
            if (!validWatcherInterface(stringArg(&iter))) return self.invalidArgs(message);
            const reply = dbus.dbus_message_new_method_return(message) orelse
                return error.OutOfMemory;
            defer dbus.dbus_message_unref(reply);
            var root: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(reply, &root);
            try self.appendProperties(&root);
            return self.send(reply);
        }
        return self.replyError(
            message,
            "org.freedesktop.DBus.Error.UnknownMethod",
            "Unknown properties method",
        );
    }

    // Construction helpers end before send locks the message. Each opened
    // container is abandoned on failure, from the innermost scope outward.
    fn appendProperties(self: *const Watcher, root: *dbus.DBusMessageIter) !void {
        var dictionary = try openContainer(root, dbus.DBUS_TYPE_ARRAY, "{sv}");
        errdefer dbus.dbus_message_iter_abandon_container_if_open(root, &dictionary);
        for (std.enums.values(Property)) |property| {
            var entry = try openContainer(&dictionary, dbus.DBUS_TYPE_DICT_ENTRY, null);
            errdefer dbus.dbus_message_iter_abandon_container_if_open(&dictionary, &entry);
            try appendString(&entry, @tagName(property));
            try self.appendProperty(&entry, property);
            try closeContainer(&dictionary, &entry);
        }
        try closeContainer(root, &dictionary);
    }

    fn appendProperty(self: *const Watcher, iter: *dbus.DBusMessageIter, property: Property) !void {
        const signature: [*:0]const u8 = switch (property) {
            .RegisteredStatusNotifierItems => "as",
            .IsStatusNotifierHostRegistered => "b",
            .ProtocolVersion => "i",
        };
        var variant = try openContainer(iter, dbus.DBUS_TYPE_VARIANT, signature);
        errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &variant);
        switch (property) {
            .RegisteredStatusNotifierItems => {
                var array = try openContainer(&variant, dbus.DBUS_TYPE_ARRAY, "s");
                errdefer dbus.dbus_message_iter_abandon_container_if_open(&variant, &array);
                for (self.state.items[0..self.state.count]) |*item| {
                    var identifier: [max_name + max_path + 1:0]u8 = undefined;
                    try appendString(&array, item.identifier(&identifier).ptr);
                }
                try closeContainer(&variant, &array);
            },
            .IsStatusNotifierHostRegistered => {
                const value: dbus.dbus_bool_t = @intFromBool(self.state.host);
                if (dbus.dbus_message_iter_append_basic(
                    &variant,
                    dbus.DBUS_TYPE_BOOLEAN,
                    &value,
                ) == 0) return error.OutOfMemory;
            },
            .ProtocolVersion => {
                const version: dbus.dbus_int32_t = 0;
                if (dbus.dbus_message_iter_append_basic(
                    &variant,
                    dbus.DBUS_TYPE_INT32,
                    &version,
                ) == 0) return error.OutOfMemory;
            },
        }
        try closeContainer(iter, &variant);
    }

    fn introspect(self: *Watcher, request: *dbus.DBusMessage) !void {
        const xml: [*:0]const u8 =
            "<node><interface name='org.kde.StatusNotifierWatcher'>" ++
            "<method name='RegisterStatusNotifierItem'><arg type='s' direction='in'/></method>" ++
            "<method name='RegisterStatusNotifierHost'><arg type='s' direction='in'/></method>" ++
            "<property name='RegisteredStatusNotifierItems' type='as' access='read'/>" ++
            "<property name='IsStatusNotifierHostRegistered' type='b' access='read'/>" ++
            "<property name='ProtocolVersion' type='i' access='read'/>" ++
            "<signal name='StatusNotifierItemRegistered'><arg type='s'/></signal>" ++
            "<signal name='StatusNotifierItemUnregistered'><arg type='s'/></signal>" ++
            "<signal name='StatusNotifierHostRegistered'/></interface>" ++
            "<interface name='org.freedesktop.DBus.Properties'>" ++
            "<method name='Get'><arg type='s' direction='in'/><arg type='s' direction='in'/>" ++
            "<arg type='v' direction='out'/></method>" ++
            "<method name='GetAll'><arg type='s' direction='in'/>" ++
            "<arg type='a{sv}' direction='out'/></method>" ++
            "</interface></node>";
        const reply = dbus.dbus_message_new_method_return(request) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(reply, &iter);
        try appendString(&iter, xml);
        try self.send(reply);
    }

    fn signalItem(self: *Watcher, member: [*:0]const u8, item: *const Item) !void {
        var identifier: [max_name + max_path + 1:0]u8 = undefined;
        const value = item.identifier(&identifier);
        for ([_][*:0]const u8{ kde_interface, fd_interface }) |interface| {
            const signal = dbus.dbus_message_new_signal(watcher_path, interface, member) orelse
                return error.OutOfMemory;
            defer dbus.dbus_message_unref(signal);
            var iter: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(signal, &iter);
            try appendString(&iter, value.ptr);
            try self.send(signal);
        }
    }

    fn signalNoArg(self: *Watcher, member: [*:0]const u8) !void {
        for ([_][*:0]const u8{ kde_interface, fd_interface }) |interface| {
            const signal = dbus.dbus_message_new_signal(watcher_path, interface, member) orelse
                return error.OutOfMemory;
            defer dbus.dbus_message_unref(signal);
            try self.send(signal);
        }
    }

    fn replyEmpty(self: *Watcher, request: *dbus.DBusMessage) !void {
        const reply = dbus.dbus_message_new_method_return(request) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(reply);
        try self.send(reply);
    }

    fn invalidArgs(self: *Watcher, request: *dbus.DBusMessage) !void {
        try self.replyError(
            request,
            "org.freedesktop.DBus.Error.InvalidArgs",
            "Invalid tray argument or capacity exceeded",
        );
    }
    fn replyError(
        self: *Watcher,
        request: *dbus.DBusMessage,
        name: [*:0]const u8,
        reason: [*:0]const u8,
    ) !void {
        const reply = dbus.dbus_message_new_error(request, name, reason) orelse
            return error.OutOfMemory;
        defer dbus.dbus_message_unref(reply);
        try self.send(reply);
    }
    fn send(self: *Watcher, message: *dbus.DBusMessage) !void {
        const conn = self.connection orelse return error.TrayBusDisconnected;
        if (dbus.dbus_connection_send(conn, message, null) == 0) return error.OutOfMemory;
        for (0..8) |_| {
            if (dbus.dbus_connection_has_messages_to_send(conn) == 0) return;
            if (dbus.dbus_connection_read_write(conn, 25) == 0) return error.TrayBusDisconnected;
        }
        if (dbus.dbus_connection_has_messages_to_send(conn) != 0) return error.TraySendTimedOut;
    }
};

const Property = enum {
    RegisteredStatusNotifierItems,
    IsStatusNotifierHostRegistered,
    ProtocolVersion,
};

fn watcherMethod(message: *dbus.DBusMessage, member: [*:0]const u8) bool {
    return dbus.dbus_message_is_method_call(message, kde_interface, member) != 0 or
        dbus.dbus_message_is_method_call(message, fd_interface, member) != 0;
}

fn openContainer(
    iter: *dbus.DBusMessageIter,
    kind: c_int,
    signature: ?[*:0]const u8,
) !dbus.DBusMessageIter {
    var child: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_open_container(iter, kind, signature, &child) == 0)
        return error.OutOfMemory;
    return child;
}

fn closeContainer(iter: *dbus.DBusMessageIter, child: *dbus.DBusMessageIter) !void {
    if (dbus.dbus_message_iter_close_container(iter, child) == 0) return error.OutOfMemory;
}

fn appendString(iter: *dbus.DBusMessageIter, value: [*:0]const u8) !void {
    // zig-audit: acknowledge ptr_cast
    // reason: libdbus copies a C string using the address of its pointer value.
    if (dbus.dbus_message_iter_append_basic(iter, dbus.DBUS_TYPE_STRING, @ptrCast(&value)) == 0)
        return error.OutOfMemory;
}

fn validWatcherInterface(value: []const u8) bool {
    return std.mem.eql(u8, value, std.mem.span(kde_interface)) or
        std.mem.eql(u8, value, std.mem.span(fd_interface));
}

fn stringArg(iter: *dbus.DBusMessageIter) []const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING) return "";
    var pointer: [*c]const u8 = null;
    // zig-audit: acknowledge ptr_cast
    // reason: Signature-checked string read writes a borrowed C string pointer.
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    return if (pointer == null) "" else std.mem.span(pointer);
}

fn subscribeOwnerChanges(conn: *dbus.DBusConnection) !void {
    // The translated DBusError is opaque. Use an acknowledged AddMatch call
    // rather than relying on the unchecked convenience call with a null error.
    const request = dbus.dbus_message_new_method_call(
        dbus.DBUS_SERVICE_DBUS,
        dbus.DBUS_PATH_DBUS,
        dbus.DBUS_INTERFACE_DBUS,
        "AddMatch",
    ) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(request);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(request, &iter);
    try appendString(
        &iter,
        "type='signal',sender='org.freedesktop.DBus',path='/org/freedesktop/DBus'," ++
            "interface='org.freedesktop.DBus',member='NameOwnerChanged'",
    );
    const reply = dbus.dbus_connection_send_with_reply_and_block(conn, request, 150, null) orelse
        return error.TrayOwnerSubscriptionFailed;
    defer dbus.dbus_message_unref(reply);
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN or
        dbus.dbus_message_has_signature(reply, "") == 0) return error.TrayOwnerSubscriptionFailed;
}

fn ownName(conn: *dbus.DBusConnection, name: [*:0]const u8) !void {
    const result = dbus.dbus_bus_request_name(conn, name, dbus.DBUS_NAME_FLAG_DO_NOT_QUEUE, null);
    if (result != dbus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER and
        result != dbus.DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER) return error.TrayWatcherAlreadyOwned;
}

// A registered well-known service must be owned by the registering sender.
// NameOwnerChanged handles its later disappearance or replacement.
fn senderOwnsRegistration(
    conn: *dbus.DBusConnection,
    registration: [:0]const u8,
    sender: [:0]const u8,
) !bool {
    if (std.mem.eql(u8, registration, sender)) return true;
    if (registration[0] == ':') return false;
    const request = dbus.dbus_message_new_method_call(
        dbus.DBUS_SERVICE_DBUS,
        dbus.DBUS_PATH_DBUS,
        dbus.DBUS_INTERFACE_DBUS,
        "GetNameOwner",
    ) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(request);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(request, &iter);
    try appendString(&iter, registration.ptr);
    const reply = dbus.dbus_connection_send_with_reply_and_block(conn, request, 150, null) orelse
        return false;
    defer dbus.dbus_message_unref(reply);
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN or
        dbus.dbus_message_has_signature(reply, "s") == 0) return false;
    var result: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &result) == 0) return false;
    return std.mem.eql(u8, stringArg(&result), sender);
}

/// Standalone compatibility entrypoint; the resident drives the same turns.
pub fn run(io: std.Io) !void {
    const stop = try Stop.open();
    defer stop.close();
    var watcher: Watcher = .{};
    try watcher.open();
    defer watcher.close();
    while (true) {
        const more = try watcher.advance();
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop.fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = try watcher.fd(), .events = std.posix.POLL.IN, .revents = 0 },
        };
        if (try std.posix.poll(&fds, if (more) 0 else -1) == 0) continue;
        if (fds[0].revents != 0) {
            try Stop.consume(io, stop.fd);
            return;
        }
    }
}

test "item registrations retain only checked owner/service/path and de-duplicate" {
    var state: State = .{};
    const first_item = try Item.create(":1.12", "org.kde.StatusNotifierItem-12-1");
    const first = (try state.register(first_item)).?;
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-12-1", first.serviceName());
    try std.testing.expectEqualStrings("/StatusNotifierItem", first.pathName());
    try std.testing.expect((try state.register(first_item)) == null);
    const second = (try state.register(try Item.create(":1.14", "/Some/Item"))).?;
    try std.testing.expectEqualStrings(":1.14", second.serviceName());
    try std.testing.expectEqualStrings("/Some/Item", second.pathName());
    try std.testing.expectEqual(@as(usize, 2), state.count);
    var removed: Item = undefined;
    try std.testing.expect(state.unregister(":1.12", ":1.12", &removed));
    try std.testing.expectEqual(@as(usize, 1), state.count);
    try std.testing.expect(!state.unregister(":1.12", ":1.12", &removed));
    try std.testing.expect(state.unregister(":1.14", ":1.14", &removed));
    try std.testing.expectEqual(@as(usize, 0), state.count);
    try std.testing.expectError(error.InvalidItem, Item.create(":1.12", "bad/name"));
}

test "losing one well-known item name does not unregister siblings of the same sender" {
    var state: State = .{};
    const first = try Item.create(":1.12", "org.kde.StatusNotifierItem-One");
    const second = try Item.create(":1.12", "org.kde.StatusNotifierItem-Two");
    try std.testing.expect((try state.register(first)) != null);
    try std.testing.expect((try state.register(second)) != null);
    var removed: Item = undefined;
    try std.testing.expect(state.unregister("org.kde.StatusNotifierItem-One", ":1.12", &removed));
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-One", removed.serviceName());
    try std.testing.expectEqual(@as(usize, 1), state.count);
    try std.testing.expectEqualStrings(
        "org.kde.StatusNotifierItem-Two",
        state.items[0].serviceName(),
    );
    try std.testing.expect(state.unregister(":1.12", ":1.12", &removed));
    try std.testing.expectEqual(@as(usize, 0), state.count);
}

test "registration checks the complete bounded bus identity grammar" {
    for ([_][]const u8{ "", "org.example.Owner", ":1..2", ":1.2\x00x" }) |sender| {
        try std.testing.expectError(error.InvalidOwner, Item.create(sender, "/Item"));
    }
    for ([_][]const u8{
        "",
        "not-a-service",
        "org..example",
        "org.1example",
        "/Bad//Path",
        "/Trailing/",
        "/bad-path",
        "/",
        "/Item\x00suffix",
    }) |name| {
        try std.testing.expectError(error.InvalidItem, Item.create(":1.2", name));
    }
    var path: [max_path]u8 = @splat('x');
    path[0] = '/';
    try std.testing.expectError(error.InvalidItem, Item.create(":1.2", &path));
    const item = try Item.create(":1.2", path[0 .. path.len - 1]);
    var storage: [max_name + max_path + 1:0]u8 = undefined;
    const identifier = item.identifier(&storage);
    try std.testing.expectEqual(@as(usize, 4 + max_path - 1), identifier.len);
    try std.testing.expectEqual(@as(u8, 0), identifier[identifier.len]);
}

test "a stale previous owner cannot retire the current registration" {
    var state: State = .{};
    const service = "org.example.Item";
    const original = try Item.create(":1.2", service);
    const replacement = try Item.create(":1.3", service);
    try std.testing.expect((try state.register(original)) != null);
    try std.testing.expectError(error.InvalidOwner, state.register(replacement));
    var removed: Item = undefined;
    try std.testing.expect(!state.unregister(service, ":1.3", &removed));
    try std.testing.expect(state.unregister(service, ":1.2", &removed));
    try std.testing.expect((try state.register(replacement)) != null);
    try std.testing.expect(!state.unregister(service, ":1.2", &removed));
    try std.testing.expectEqualStrings(":1.3", state.items[0].senderName());
    try std.testing.expect(state.unregister(":1.3", ":1.3", &removed));
    try std.testing.expectEqual(@as(usize, 0), state.count);
}

fn ownerSignalTest(
    sender: [*:0]const u8,
    path: [*:0]const u8,
    previous: [*:0]const u8,
) !*dbus.DBusMessage {
    const message = dbus.dbus_message_new_signal(
        path,
        dbus.DBUS_INTERFACE_DBUS,
        "NameOwnerChanged",
    ) orelse return error.OutOfMemory;
    errdefer dbus.dbus_message_unref(message);
    if (dbus.dbus_message_set_sender(message, sender) == 0) return error.OutOfMemory;
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    try appendString(&iter, "org.example.Item");
    try appendString(&iter, previous);
    try appendString(&iter, "");
    return message;
}

test "owner changes require the bus daemon identity and exact previous owner" {
    var watcher: Watcher = .{};
    const item = try Item.create(":1.2", "org.example.Item");
    try std.testing.expect((try watcher.state.register(item)) != null);
    const cases = [_]struct {
        sender: [*:0]const u8,
        path: [*:0]const u8,
        previous: [*:0]const u8,
    }{
        .{ .sender = ":1.3", .path = dbus.DBUS_PATH_DBUS, .previous = ":1.2" },
        .{ .sender = dbus.DBUS_SERVICE_DBUS, .path = "/Other", .previous = ":1.2" },
        .{ .sender = dbus.DBUS_SERVICE_DBUS, .path = dbus.DBUS_PATH_DBUS, .previous = ":1.3" },
    };
    for (cases) |case| {
        const signal = try ownerSignalTest(case.sender, case.path, case.previous);
        defer dbus.dbus_message_unref(signal);
        // Rejected events must not attempt an outgoing notification or mutate state.
        try watcher.dispatch(signal);
        try std.testing.expectEqual(@as(usize, 1), watcher.count());
        try std.testing.expectEqualStrings(":1.2", watcher.state.items[0].senderName());
    }
}
