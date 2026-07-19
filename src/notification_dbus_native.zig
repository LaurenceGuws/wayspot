//! Adapts one private libdbus session connection to the notification service.

const std = @import("std");
const builtin = @import("builtin");
const notification = @import("notification.zig");
const service = @import("notification_dbus.zig");

const c = @cImport({
    @cInclude("dbus/dbus.h");
});

const name = "org.freedesktop.Notifications";
const path = "/org/freedesktop/Notifications";
const interface = "org.freedesktop.Notifications";
const message_capacity = 64 * 1024;
const wait_milliseconds = 100;
const send_turn_capacity = 8;
const send_wait_milliseconds = 25;

pub const Native = struct {
    stop: *const std.atomic.Value(bool),
    connection: ?*c.DBusConnection = null,
    message: ?*c.DBusMessage = null,

    pub fn open(native: *Native) !void {
        std.debug.assert(native.connection == null);
        std.debug.assert(native.message == null);

        const connection = c.dbus_bus_get_private(c.DBUS_BUS_SESSION, null) orelse {
            return error.SessionBusUnavailable;
        };
        native.connection = connection;
        c.dbus_connection_set_exit_on_disconnect(connection, 0);
        c.dbus_connection_set_max_message_size(connection, message_capacity);
        c.dbus_connection_set_max_message_unix_fds(connection, 0);
        std.debug.assert(c.dbus_connection_get_max_message_size(connection) == message_capacity);
        std.debug.assert(c.dbus_connection_get_max_message_unix_fds(connection) == 0);
    }

    pub fn own(native: *Native) !void {
        const connection = native.connection orelse return error.ConnectionMissing;
        const result = c.dbus_bus_request_name(
            connection,
            name,
            c.DBUS_NAME_FLAG_DO_NOT_QUEUE,
            null,
        );
        if (result != c.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER and
            result != c.DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER)
        {
            return error.NameOwned;
        }
    }

    pub fn next(native: *Native) !service.Event {
        std.debug.assert(native.connection != null);
        std.debug.assert(native.message == null);
        if (native.stop.load(.acquire)) return .stop;

        const connection = native.connection.?;
        if (c.dbus_connection_read_write(connection, wait_milliseconds) == 0) return .bus_lost;
        if (native.stop.load(.acquire)) return .stop;
        const message = c.dbus_connection_pop_message(connection) orelse return .idle;
        native.message = message;

        if (c.dbus_message_is_signal(message, c.DBUS_INTERFACE_DBUS, "NameLost") != 0) {
            const lost = readOneString(message) orelse {
                native.releaseMessage();
                return .idle;
            };
            if (std.mem.eql(u8, lost, name)) return .name_lost;
            native.releaseMessage();
            return .idle;
        }
        if (c.dbus_message_get_type(message) != c.DBUS_MESSAGE_TYPE_METHOD_CALL or
            c.dbus_message_has_path(message, path) == 0 or
            c.dbus_message_has_interface(message, interface) == 0)
        {
            return .{ .reject = .unknown_method };
        }

        const member_pointer = c.dbus_message_get_member(message) orelse {
            return .{ .reject = .unknown_method };
        };
        const member = std.mem.span(member_pointer);
        if (std.mem.eql(u8, member, "GetCapabilities")) {
            return noArguments(message, .get_capabilities);
        }
        if (std.mem.eql(u8, member, "Notify")) return parseNotify(message);
        if (std.mem.eql(u8, member, "CloseNotification")) return parseClose(message);
        if (std.mem.eql(u8, member, "GetServerInformation")) {
            return noArguments(message, .get_server_information);
        }
        return .{ .reject = .unknown_method };
    }

    pub fn replyCapabilities(native: *Native) !void {
        const reply = c.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer c.dbus_message_unref(reply);
        var root: c.DBusMessageIter = undefined;
        var array: c.DBusMessageIter = undefined;
        c.dbus_message_iter_init_append(reply, &root);
        if (c.dbus_message_iter_open_container(&root, c.DBUS_TYPE_ARRAY, "s", &array) == 0) {
            return error.OutOfMemory;
        }
        if (c.dbus_message_iter_close_container(&root, &array) == 0) {
            c.dbus_message_iter_abandon_container(&root, &array);
            return error.OutOfMemory;
        }
        try native.sendReply(reply);
    }

    pub fn replyNotify(native: *Native, id: u32) !void {
        std.debug.assert(id != 0);
        const reply = c.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer c.dbus_message_unref(reply);
        var iter: c.DBusMessageIter = undefined;
        c.dbus_message_iter_init_append(reply, &iter);
        var value: c.dbus_uint32_t = id;
        if (c.dbus_message_iter_append_basic(&iter, c.DBUS_TYPE_UINT32, &value) == 0) {
            return error.OutOfMemory;
        }
        try native.sendReply(reply);
    }

    pub fn signalClosed(native: *Native, id: u32, reason: service.CloseReason) !void {
        std.debug.assert(id != 0);
        const signal = c.dbus_message_new_signal(path, interface, "NotificationClosed") orelse {
            return error.OutOfMemory;
        };
        defer c.dbus_message_unref(signal);
        var iter: c.DBusMessageIter = undefined;
        c.dbus_message_iter_init_append(signal, &iter);
        var notification_id: c.dbus_uint32_t = id;
        var close_reason: c.dbus_uint32_t = @intFromEnum(reason);
        if (c.dbus_message_iter_append_basic(&iter, c.DBUS_TYPE_UINT32, &notification_id) == 0 or
            c.dbus_message_iter_append_basic(&iter, c.DBUS_TYPE_UINT32, &close_reason) == 0)
        {
            return error.OutOfMemory;
        }
        try native.send(signal);
    }

    pub fn replyClose(native: *Native) !void {
        const reply = c.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer c.dbus_message_unref(reply);
        try native.sendReply(reply);
    }

    pub fn replyServerInformation(native: *Native) !void {
        const reply = c.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer c.dbus_message_unref(reply);
        var iter: c.DBusMessageIter = undefined;
        c.dbus_message_iter_init_append(reply, &iter);
        const values = [_][*:0]const u8{ "wayspot", "wayspot", "0.1.0", "1.3" };
        for (values) |value| {
            var pointer = value;
            if (c.dbus_message_iter_append_basic(&iter, c.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0) {
                return error.OutOfMemory;
            }
        }
        try native.sendReply(reply);
    }

    pub fn replyError(native: *Native, err: service.ReplyError) !void {
        const error_name: [*:0]const u8, const message: [*:0]const u8 = switch (err) {
            .unknown_method => .{ "org.freedesktop.DBus.Error.UnknownMethod", "Unknown method" },
            .invalid_signature => .{ "org.freedesktop.DBus.Error.InvalidArgs", "Invalid arguments" },
            .unknown_notification => .{
                "org.freedesktop.Notifications.Error.NonExistentNotification",
                "Unknown notification",
            },
            .out_of_memory => .{ "org.freedesktop.DBus.Error.NoMemory", "Out of memory" },
            else => .{ "org.freedesktop.DBus.Error.LimitsExceeded", "Notification exceeds Wayspot bounds" },
        };
        const reply = c.dbus_message_new_error(
            native.message orelse return error.MessageMissing,
            error_name,
            message,
        ) orelse return error.OutOfMemory;
        defer c.dbus_message_unref(reply);
        try native.sendReply(reply);
    }

    pub fn close(native: *Native) void {
        native.releaseMessage();
        if (native.connection) |connection| {
            c.dbus_connection_close(connection);
            c.dbus_connection_unref(connection);
            native.connection = null;
        }
    }

    fn sendReply(native: *Native, reply: *c.DBusMessage) !void {
        defer native.releaseMessage();
        try native.send(reply);
    }

    fn send(native: *Native, message: *c.DBusMessage) !void {
        const connection = native.connection orelse return error.ConnectionMissing;
        if (c.dbus_connection_send(connection, message, null) == 0) return error.OutOfMemory;
        for (0..send_turn_capacity) |_| {
            if (c.dbus_connection_has_messages_to_send(connection) == 0) return;
            if (c.dbus_connection_read_write(connection, send_wait_milliseconds) == 0) return error.BusLost;
        }
        return error.SendTimedOut;
    }

    fn releaseMessage(native: *Native) void {
        if (native.message) |message| {
            c.dbus_message_unref(message);
            native.message = null;
        }
    }
};

fn noArguments(message: *c.DBusMessage, method: service.Method) service.Event {
    if (c.dbus_message_has_signature(message, "") == 0) return .{ .reject = .invalid_signature };
    return .{ .method = method };
}

fn parseClose(message: *c.DBusMessage) service.Event {
    if (c.dbus_message_has_signature(message, "u") == 0) return .{ .reject = .invalid_signature };
    var iter: c.DBusMessageIter = undefined;
    if (c.dbus_message_iter_init(message, &iter) == 0) return .{ .reject = .invalid_signature };
    var id: c.dbus_uint32_t = 0;
    c.dbus_message_iter_get_basic(&iter, &id);
    return .{ .method = .{ .close = id } };
}

fn parseNotify(message: *c.DBusMessage) service.Event {
    if (c.dbus_message_has_signature(message, "susssasa{sv}i") == 0) {
        return .{ .reject = .invalid_signature };
    }
    var iter: c.DBusMessageIter = undefined;
    if (c.dbus_message_iter_init(message, &iter) == 0) return .{ .reject = .invalid_signature };

    const app_name = readString(&iter);
    const replaces_id = readU32(&iter);
    const app_icon = readString(&iter);
    const summary = readString(&iter);
    const body = readString(&iter);
    const action_error = countActions(&iter);
    if (action_error) |err| return .{ .reject = err };
    const hint_error = countHints(&iter);
    if (hint_error) |err| return .{ .reject = err };
    const expire_timeout = readI32(&iter);
    return .{ .method = .{ .notify = .{
        .replaces_id = replaces_id,
        .app_name = app_name,
        .app_icon = app_icon,
        .summary = summary,
        .body = body,
        .expire_timeout = expire_timeout,
    } } };
}

fn readOneString(message: *c.DBusMessage) ?[]const u8 {
    if (c.dbus_message_has_signature(message, "s") == 0) return null;
    var iter: c.DBusMessageIter = undefined;
    if (c.dbus_message_iter_init(message, &iter) == 0) return null;
    return readString(&iter);
}

fn readString(iter: *c.DBusMessageIter) []const u8 {
    std.debug.assert(c.dbus_message_iter_get_arg_type(iter) == c.DBUS_TYPE_STRING);
    var pointer: [*:0]const u8 = undefined;
    c.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    _ = c.dbus_message_iter_next(iter);
    return std.mem.span(pointer);
}

fn readU32(iter: *c.DBusMessageIter) u32 {
    std.debug.assert(c.dbus_message_iter_get_arg_type(iter) == c.DBUS_TYPE_UINT32);
    var value: c.dbus_uint32_t = 0;
    c.dbus_message_iter_get_basic(iter, &value);
    _ = c.dbus_message_iter_next(iter);
    return value;
}

fn readI32(iter: *c.DBusMessageIter) i32 {
    std.debug.assert(c.dbus_message_iter_get_arg_type(iter) == c.DBUS_TYPE_INT32);
    var value: c.dbus_int32_t = 0;
    c.dbus_message_iter_get_basic(iter, &value);
    _ = c.dbus_message_iter_next(iter);
    return value;
}

fn countActions(iter: *c.DBusMessageIter) ?service.ReplyError {
    std.debug.assert(c.dbus_message_iter_get_arg_type(iter) == c.DBUS_TYPE_ARRAY);
    var actions: c.DBusMessageIter = undefined;
    c.dbus_message_iter_recurse(iter, &actions);
    var count: usize = 0;
    while (c.dbus_message_iter_get_arg_type(&actions) != c.DBUS_TYPE_INVALID) {
        if (count == 64) return .too_many_actions;
        const action = readString(&actions);
        if (action.len > 256) return .too_many_actions;
        count += 1;
    }
    _ = c.dbus_message_iter_next(iter);
    if (count % 2 != 0) return .invalid_signature;
    return null;
}

fn countHints(iter: *c.DBusMessageIter) ?service.ReplyError {
    std.debug.assert(c.dbus_message_iter_get_arg_type(iter) == c.DBUS_TYPE_ARRAY);
    var hints: c.DBusMessageIter = undefined;
    c.dbus_message_iter_recurse(iter, &hints);
    var count: usize = 0;
    while (c.dbus_message_iter_get_arg_type(&hints) != c.DBUS_TYPE_INVALID) {
        if (count == 64) return .too_many_hints;
        var entry: c.DBusMessageIter = undefined;
        c.dbus_message_iter_recurse(&hints, &entry);
        const key = readString(&entry);
        if (key.len > 256) return .too_many_hints;
        count += 1;
        _ = c.dbus_message_iter_next(&hints);
    }
    _ = c.dbus_message_iter_next(iter);
    return null;
}

test "action arrays require bounded key label pairs" {
    try std.testing.expectEqual(null, try actionError(&.{ "open", "Open" }));
    try std.testing.expectEqual(service.ReplyError.invalid_signature, try actionError(&.{"open"}));

    var actions: [65][]const u8 = @splat("x");
    try std.testing.expectEqual(service.ReplyError.too_many_actions, try actionError(&actions));
    var long: [257]u8 = @splat('x');
    try std.testing.expectEqual(service.ReplyError.too_many_actions, try actionError(&.{&long}));
}

test "hint dictionaries bound count and key bytes" {
    try std.testing.expectEqual(null, try hintError(&.{"urgency"}));

    var keys: [65][]const u8 = @splat("x");
    try std.testing.expectEqual(service.ReplyError.too_many_hints, try hintError(&keys));
    var long: [257]u8 = @splat('x');
    try std.testing.expectEqual(service.ReplyError.too_many_hints, try hintError(&.{&long}));
}

test "generated action and hint bounds match native iterators" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzCollections, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzCollections({}, &empty);
}

fn fuzzCollections(_: void, smith: *std.testing.Smith) !void {
    var bytes: [257]u8 = @splat('x');
    var values: [65][]const u8 = undefined;
    const count = smith.value(u8) % (values.len + 1);
    const length = smith.value(u16) % (bytes.len + 1);
    for (values[0..count]) |*value| value.* = bytes[0..length];

    const actions = try actionError(values[0..count]);
    if (count > 64 or length > 256) {
        try std.testing.expectEqual(service.ReplyError.too_many_actions, actions);
    } else if (count % 2 != 0) {
        try std.testing.expectEqual(service.ReplyError.invalid_signature, actions);
    } else {
        try std.testing.expectEqual(null, actions);
    }

    const hints = try hintError(values[0..count]);
    if (count > 64 or length > 256) {
        try std.testing.expectEqual(service.ReplyError.too_many_hints, hints);
    } else {
        try std.testing.expectEqual(null, hints);
    }
}

fn actionError(actions: []const []const u8) !?service.ReplyError {
    const message = c.dbus_message_new_signal(path, interface, "Test") orelse return error.OutOfMemory;
    defer c.dbus_message_unref(message);
    var root: c.DBusMessageIter = undefined;
    var array: c.DBusMessageIter = undefined;
    c.dbus_message_iter_init_append(message, &root);
    if (c.dbus_message_iter_open_container(&root, c.DBUS_TYPE_ARRAY, "s", &array) == 0) {
        return error.OutOfMemory;
    }
    for (actions) |action| {
        const terminated = try std.testing.allocator.dupeZ(u8, action);
        defer std.testing.allocator.free(terminated);
        var pointer: [*:0]const u8 = terminated;
        if (c.dbus_message_iter_append_basic(&array, c.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0) {
            c.dbus_message_iter_abandon_container(&root, &array);
            return error.OutOfMemory;
        }
    }
    if (c.dbus_message_iter_close_container(&root, &array) == 0) {
        c.dbus_message_iter_abandon_container(&root, &array);
        return error.OutOfMemory;
    }
    var read: c.DBusMessageIter = undefined;
    std.debug.assert(c.dbus_message_iter_init(message, &read) != 0);
    return countActions(&read);
}

fn hintError(keys: []const []const u8) !?service.ReplyError {
    const message = c.dbus_message_new_signal(path, interface, "Test") orelse return error.OutOfMemory;
    defer c.dbus_message_unref(message);
    var root: c.DBusMessageIter = undefined;
    var array: c.DBusMessageIter = undefined;
    c.dbus_message_iter_init_append(message, &root);
    if (c.dbus_message_iter_open_container(&root, c.DBUS_TYPE_ARRAY, "{sv}", &array) == 0) {
        return error.OutOfMemory;
    }
    for (keys) |key| try appendHint(&array, key);
    if (c.dbus_message_iter_close_container(&root, &array) == 0) {
        c.dbus_message_iter_abandon_container(&root, &array);
        return error.OutOfMemory;
    }
    var read: c.DBusMessageIter = undefined;
    std.debug.assert(c.dbus_message_iter_init(message, &read) != 0);
    return countHints(&read);
}

fn appendHint(array: *c.DBusMessageIter, key: []const u8) !void {
    const terminated = try std.testing.allocator.dupeZ(u8, key);
    defer std.testing.allocator.free(terminated);
    var pointer: [*:0]const u8 = terminated;
    var entry: c.DBusMessageIter = undefined;
    var variant: c.DBusMessageIter = undefined;
    if (c.dbus_message_iter_open_container(array, c.DBUS_TYPE_DICT_ENTRY, null, &entry) == 0) {
        return error.OutOfMemory;
    }
    if (c.dbus_message_iter_append_basic(&entry, c.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0 or
        c.dbus_message_iter_open_container(&entry, c.DBUS_TYPE_VARIANT, "s", &variant) == 0)
    {
        c.dbus_message_iter_abandon_container(array, &entry);
        return error.OutOfMemory;
    }
    if (c.dbus_message_iter_append_basic(&variant, c.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0 or
        c.dbus_message_iter_close_container(&entry, &variant) == 0 or
        c.dbus_message_iter_close_container(array, &entry) == 0)
    {
        c.dbus_message_iter_abandon_container_if_open(&entry, &variant);
        c.dbus_message_iter_abandon_container_if_open(array, &entry);
        return error.OutOfMemory;
    }
}
