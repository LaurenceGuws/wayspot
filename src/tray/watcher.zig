//! Small, bounded StatusNotifierWatcher service on the user D-Bus session.
//! The UI host opens on demand; application registration must outlive the picker.
const std = @import("std");
const dbus = @import("dbus_c");
const Stop = @import("../stop.zig");

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
pub const Item = struct {
    service: [max_name:0]u8 = @splat(0),
    length: u8 = 0,
    path: [max_path:0]u8 = @splat(0),
    path_length: u8 = 0,
    owner: [max_name:0]u8 = @splat(0),
    owner_length: u8 = 0,

    fn create(sender: []const u8, registration: []const u8) !Item {
        if (!validService(sender)) return error.InvalidOwner;
        const with_path = registration.len > 0 and registration[0] == '/';
        const service = if (with_path) sender else registration;
        const path = if (with_path) registration else "/StatusNotifierItem";
        if (!validService(service) or !validPath(path)) return error.InvalidItem;
        var result: Item = .{};
        @memcpy(result.service[0..service.len], service);
        result.length = @intCast(service.len);
        @memcpy(result.path[0..path.len], path);
        result.path_length = @intCast(path.len);
        @memcpy(result.owner[0..sender.len], sender);
        result.owner_length = @intCast(sender.len);
        return result;
    }

    pub fn serviceName(self: *const Item) []const u8 {
        return self.service[0..self.length];
    }
    pub fn pathName(self: *const Item) []const u8 {
        return self.path[0..self.path_length];
    }
    pub fn senderName(self: *const Item) []const u8 {
        return self.owner[0..self.owner_length];
    }
    pub fn identifier(self: *const Item, output: *[max_name + max_path + 1:0]u8) []const u8 {
        const service = self.serviceName();
        const path = self.pathName();
        @memcpy(output[0..service.len], service);
        @memcpy(output[service.len..][0..path.len], path);
        output[service.len + path.len] = 0;
        return output[0 .. service.len + path.len];
    }
};

fn validService(value: []const u8) bool {
    if (value.len < 2 or value.len >= max_name) return false;
    for (value, 0..) |byte, index| if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_' and byte != '-' and
        !(index == 0 and byte == ':')) return false;
    return std.mem.indexOfScalar(u8, value, '.') != null;
}
fn validPath(value: []const u8) bool {
    if (value.len < 2 or value.len >= max_path or value[0] != '/') return false;
    for (value[1..]) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '/' and byte != '_') return false;
    return true;
}

pub const State = struct {
    items: [max_items]Item = undefined,
    count: usize = 0,
    host: bool = true, // Wayspot's GUI host is available on demand.

    fn register(self: *State, sender: []const u8, name: []const u8) !?*const Item {
        const candidate = try Item.create(sender, name);
        for (self.items[0..self.count]) |*item| {
            if (std.mem.eql(u8, item.serviceName(), candidate.serviceName()) and
                std.mem.eql(u8, item.pathName(), candidate.pathName())) return null;
        }
        if (self.count == max_items) return error.TooManyTrayItems;
        self.items[self.count] = candidate;
        self.count += 1;
        return &self.items[self.count - 1];
    }

    fn unregister(self: *State, owner: []const u8, removed: *Item) bool {
        for (self.items[0..self.count], 0..) |entry, index| {
            if (!std.mem.eql(u8, owner, entry.senderName()) and
                !std.mem.eql(u8, owner, entry.serviceName())) continue;
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

    pub fn open(self: *Watcher) !void {
        self.connection = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse
            return error.TrayBusUnavailable;
        errdefer self.close();
        const conn = self.connection.?;
        dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
        dbus.dbus_connection_set_max_message_size(conn, 128 * 1024);
        dbus.dbus_connection_set_max_message_unix_fds(conn, 0);
        try ownName(conn, kde_name);
        // The KDE name is the de-facto modern interface; also expose the
        // freedesktop spelling where no other watcher owns it.
        try ownName(conn, fd_name);
        dbus.dbus_bus_add_match(conn, "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged'", null);
        dbus.dbus_connection_flush(conn);
    }

    pub fn close(self: *Watcher) void {
        if (self.connection) |conn| {
            dbus.dbus_connection_close(conn);
            dbus.dbus_connection_unref(conn);
            self.connection = null;
        }
        self.state = .{};
    }

    pub fn fd(self: *const Watcher) !std.posix.fd_t {
        const conn = self.connection orelse return -1;
        var value: c_int = -1;
        if (dbus.dbus_connection_get_unix_fd(conn, &value) == 0 or value < 0) return error.TrayBusSocketUnavailable;
        return value;
    }

    pub fn count(self: *const Watcher) usize {
        return self.state.count;
    }

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
        if (dbus.dbus_message_is_signal(message, dbus.DBUS_INTERFACE_DBUS, "NameOwnerChanged") != 0) {
            if (dbus.dbus_message_has_signature(message, "sss") == 0) return;
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return;
            const name = stringArg(&iter);
            _ = dbus.dbus_message_iter_next(&iter);
            const previous_owner = stringArg(&iter);
            _ = dbus.dbus_message_iter_next(&iter);
            // A vanished unique name OR a replaced well-known name removes
            // only registrations belonging to that exact name. Removing all
            // registrations held by `previous_owner` when a single well-known
            // name moves would incorrectly discard the owner's other icons.
            // A newly acquired name removes nothing.
            if (previous_owner.len == 0) return;
            while (true) {
                var removed: Item = undefined;
                if (!self.state.unregister(name, &removed)) break;
                try self.signalItem("StatusNotifierItemUnregistered", &removed);
            }
            return;
        }
        if (dbus.dbus_message_get_type(message) != dbus.DBUS_MESSAGE_TYPE_METHOD_CALL or
            dbus.dbus_message_has_path(message, watcher_path) == 0) return;
        if (dbus.dbus_message_has_interface(message, properties_interface) != 0) {
            return self.propertyCall(message);
        }
        if (dbus.dbus_message_has_interface(message, introspect_interface) != 0) {
            if (dbus.dbus_message_is_method_call(message, introspect_interface, "Introspect") != 0) {
                return self.introspect(message);
            }
        }
        if (dbus.dbus_message_has_interface(message, kde_interface) == 0 and
            dbus.dbus_message_has_interface(message, fd_interface) == 0)
        {
            return self.replyError(message, "org.freedesktop.DBus.Error.UnknownInterface", "Unknown interface");
        }
        if (dbus.dbus_message_is_method_call(message, kde_interface, "RegisterStatusNotifierItem") != 0 or
            dbus.dbus_message_is_method_call(message, fd_interface, "RegisterStatusNotifierItem") != 0)
        {
            if (dbus.dbus_message_has_signature(message, "s") == 0) return self.invalidArgs(message);
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
            const registration = stringArg(&iter);
            const sender = dbus.dbus_message_get_sender(message) orelse return self.invalidArgs(message);
            // Do not advertise nonexistent services or permit one client to
            // claim another client's unique name. The watcher must never be
            // a registry of unverified arbitrary text from the session bus.
            if (registration.len != 0 and registration[0] != '/') {
                if (registration.len >= max_name) return self.invalidArgs(message);
                if (registration[0] == ':' and !std.mem.eql(u8, registration, std.mem.span(sender)))
                    return self.invalidArgs(message);
                if (!senderOwnsRegistration(self.connection.?, registration, std.mem.span(sender)))
                    return self.invalidArgs(message);
            }
            const item = self.state.register(std.mem.span(sender), registration) catch return self.invalidArgs(message);
            try self.replyEmpty(message);
            if (item) |value| try self.signalItem("StatusNotifierItemRegistered", value);
            return;
        }
        if (dbus.dbus_message_is_method_call(message, kde_interface, "RegisterStatusNotifierHost") != 0 or
            dbus.dbus_message_is_method_call(message, fd_interface, "RegisterStatusNotifierHost") != 0)
        {
            if (dbus.dbus_message_has_signature(message, "s") == 0) return self.invalidArgs(message);
            try self.replyEmpty(message);
            try self.signalNoArg("StatusNotifierHostRegistered");
            return;
        }
        return self.replyError(message, "org.freedesktop.DBus.Error.UnknownMethod", "Unknown tray watcher method");
    }

    fn propertyCall(self: *Watcher, message: *dbus.DBusMessage) !void {
        if (dbus.dbus_message_is_method_call(message, properties_interface, "Get") != 0) {
            if (dbus.dbus_message_has_signature(message, "ss") == 0) return self.invalidArgs(message);
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
            const interface = stringArg(&iter);
            _ = dbus.dbus_message_iter_next(&iter);
            const property = stringArg(&iter);
            if (!validWatcherInterface(interface)) return self.invalidArgs(message);
            const reply = dbus.dbus_message_new_method_return(message) orelse return error.OutOfMemory;
            defer dbus.dbus_message_unref(reply);
            var out: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(reply, &out);
            self.appendProperty(&out, property) catch return self.invalidArgs(message);
            return self.send(reply);
        }
        if (dbus.dbus_message_is_method_call(message, properties_interface, "GetAll") != 0) {
            if (dbus.dbus_message_has_signature(message, "s") == 0) return self.invalidArgs(message);
            var iter: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_init(message, &iter) == 0) return self.invalidArgs(message);
            if (!validWatcherInterface(stringArg(&iter))) return self.invalidArgs(message);
            const reply = dbus.dbus_message_new_method_return(message) orelse return error.OutOfMemory;
            defer dbus.dbus_message_unref(reply);
            var root: dbus.DBusMessageIter = undefined;
            var dictionary: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(reply, &root);
            if (dbus.dbus_message_iter_open_container(&root, dbus.DBUS_TYPE_ARRAY, "{sv}", &dictionary) == 0)
                return error.OutOfMemory;
            for ([_][*:0]const u8{ "RegisteredStatusNotifierItems", "IsStatusNotifierHostRegistered", "ProtocolVersion" }) |name| {
                var entry: dbus.DBusMessageIter = undefined;
                if (dbus.dbus_message_iter_open_container(&dictionary, dbus.DBUS_TYPE_DICT_ENTRY, null, &entry) == 0)
                    return error.OutOfMemory;
                var ptr = name;
                if (dbus.dbus_message_iter_append_basic(&entry, dbus.DBUS_TYPE_STRING, @ptrCast(&ptr)) == 0)
                    return error.OutOfMemory;
                try self.appendProperty(&entry, std.mem.span(name));
                if (dbus.dbus_message_iter_close_container(&dictionary, &entry) == 0) return error.OutOfMemory;
            }
            if (dbus.dbus_message_iter_close_container(&root, &dictionary) == 0) return error.OutOfMemory;
            return self.send(reply);
        }
        return self.replyError(message, "org.freedesktop.DBus.Error.UnknownMethod", "Unknown properties method");
    }

    fn appendProperty(self: *Watcher, iter: *dbus.DBusMessageIter, property: []const u8) !void {
        const signature: [*:0]const u8 = if (std.mem.eql(u8, property, "RegisteredStatusNotifierItems"))
            "as"
        else if (std.mem.eql(u8, property, "IsStatusNotifierHostRegistered"))
            "b"
        else if (std.mem.eql(u8, property, "ProtocolVersion"))
            "i"
        else
            return error.UnknownProperty;
        var variant: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_open_container(iter, dbus.DBUS_TYPE_VARIANT, signature, &variant) == 0)
            return error.OutOfMemory;
        if (std.mem.eql(u8, property, "RegisteredStatusNotifierItems")) {
            var array: dbus.DBusMessageIter = undefined;
            if (dbus.dbus_message_iter_open_container(&variant, dbus.DBUS_TYPE_ARRAY, "s", &array) == 0)
                return error.OutOfMemory;
            for (self.state.items[0..self.state.count]) |*item| {
                var identifier: [max_name + max_path + 1:0]u8 = undefined;
                _ = item.identifier(&identifier);
                var pointer: [*:0]const u8 = @ptrCast(&identifier);
                if (dbus.dbus_message_iter_append_basic(&array, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0)
                    return error.OutOfMemory;
            }
            if (dbus.dbus_message_iter_close_container(&variant, &array) == 0) return error.OutOfMemory;
        } else if (std.mem.eql(u8, property, "IsStatusNotifierHostRegistered")) {
            var value: dbus.dbus_bool_t = @intFromBool(self.state.host);
            if (dbus.dbus_message_iter_append_basic(&variant, dbus.DBUS_TYPE_BOOLEAN, &value) == 0)
                return error.OutOfMemory;
        } else {
            var version: dbus.dbus_int32_t = 0;
            if (dbus.dbus_message_iter_append_basic(&variant, dbus.DBUS_TYPE_INT32, &version) == 0)
                return error.OutOfMemory;
        }
        if (dbus.dbus_message_iter_close_container(iter, &variant) == 0) return error.OutOfMemory;
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
            "<method name='GetAll'><arg type='s' direction='in'/><arg type='a{sv}' direction='out'/></method>" ++
            "</interface></node>";
        const reply = dbus.dbus_message_new_method_return(request) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(reply, &iter);
        var pointer = xml;
        if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0)
            return error.OutOfMemory;
        try self.send(reply);
    }

    fn signalItem(self: *Watcher, member: [*:0]const u8, item: *const Item) !void {
        var identifier: [max_name + max_path + 1:0]u8 = undefined;
        _ = item.identifier(&identifier);
        for ([_][*:0]const u8{ kde_interface, fd_interface }) |interface| {
            const signal = dbus.dbus_message_new_signal(watcher_path, interface, member) orelse return error.OutOfMemory;
            defer dbus.dbus_message_unref(signal);
            var iter: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_init_append(signal, &iter);
            var pointer: [*:0]const u8 = @ptrCast(&identifier);
            if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0)
                return error.OutOfMemory;
            try self.send(signal);
        }
    }

    fn signalNoArg(self: *Watcher, member: [*:0]const u8) !void {
        for ([_][*:0]const u8{ kde_interface, fd_interface }) |interface| {
            const signal = dbus.dbus_message_new_signal(watcher_path, interface, member) orelse return error.OutOfMemory;
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
        try self.replyError(request, "org.freedesktop.DBus.Error.InvalidArgs", "Invalid tray argument or capacity exceeded");
    }
    fn replyError(self: *Watcher, request: *dbus.DBusMessage, name: [*:0]const u8, reason: [*:0]const u8) !void {
        const reply = dbus.dbus_message_new_error(request, name, reason) orelse return error.OutOfMemory;
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
        return error.TraySendTimedOut;
    }
};

fn validWatcherInterface(value: []const u8) bool {
    return std.mem.eql(u8, value, std.mem.span(kde_interface)) or
        std.mem.eql(u8, value, std.mem.span(fd_interface));
}

fn stringArg(iter: *dbus.DBusMessageIter) []const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING) return "";
    var pointer: [*c]const u8 = null;
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    return if (pointer == null) "" else std.mem.span(pointer);
}

fn ownName(conn: *dbus.DBusConnection, name: [*:0]const u8) !void {
    const result = dbus.dbus_bus_request_name(conn, name, dbus.DBUS_NAME_FLAG_DO_NOT_QUEUE, null);
    if (result != dbus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER and
        result != dbus.DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER) return error.TrayWatcherAlreadyOwned;
}

// A registered well-known service must be owned by the registering sender.
// NameOwnerChanged handles its later disappearance or replacement.
fn senderOwnsRegistration(conn: *dbus.DBusConnection, registration: []const u8, sender: []const u8) bool {
    if (std.mem.eql(u8, registration, sender)) return true;
    if (registration.len == 0 or registration.len >= max_name) return false;
    const request = dbus.dbus_message_new_method_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner") orelse return false;
    defer dbus.dbus_message_unref(request);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(request, &iter);
    // Do not assume a borrowed slice is null-terminated for libdbus.
    var nul: [max_name:0]u8 = @splat(0);
    @memcpy(nul[0..registration.len], registration);
    var pointer: [*:0]const u8 = @ptrCast(&nul);
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0)
        return false;
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
        _ = try std.posix.poll(&fds, if (more) 0 else -1);
        if (fds[0].revents != 0) {
            try Stop.consume(io, stop.fd);
            return;
        }
    }
}

test "item registrations retain only checked owner/service/path and de-duplicate" {
    var state: State = .{};
    const first = (try state.register(":1.12", "org.kde.StatusNotifierItem-12-1")).?;
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-12-1", first.serviceName());
    try std.testing.expectEqualStrings("/StatusNotifierItem", first.pathName());
    try std.testing.expect((try state.register(":1.12", "org.kde.StatusNotifierItem-12-1")) == null);
    const second = (try state.register(":1.14", "/Some/Item")).?;
    try std.testing.expectEqualStrings(":1.14", second.serviceName());
    try std.testing.expectEqualStrings("/Some/Item", second.pathName());
    try std.testing.expectEqual(@as(usize, 2), state.count);
    var removed: Item = undefined;
    try std.testing.expect(state.unregister(":1.12", &removed));
    try std.testing.expectEqual(@as(usize, 1), state.count);
    try std.testing.expect(!state.unregister(":1.12", &removed));
    try std.testing.expect(state.unregister(":1.14", &removed));
    try std.testing.expectEqual(@as(usize, 0), state.count);
    try std.testing.expectError(error.InvalidItem, state.register(":1.12", "bad/name"));
}

test "losing one well-known item name does not unregister siblings of the same sender" {
    var state: State = .{};
    try std.testing.expect((try state.register(":1.12", "org.kde.StatusNotifierItem-One")) != null);
    try std.testing.expect((try state.register(":1.12", "org.kde.StatusNotifierItem-Two")) != null);
    var removed: Item = undefined;
    try std.testing.expect(state.unregister("org.kde.StatusNotifierItem-One", &removed));
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-One", removed.serviceName());
    try std.testing.expectEqual(@as(usize, 1), state.count);
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-Two", state.items[0].serviceName());
    try std.testing.expect(state.unregister(":1.12", &removed));
    try std.testing.expectEqual(@as(usize, 0), state.count);
}
