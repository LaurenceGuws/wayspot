//! Bounded `com.canonical.dbusmenu` host for one deliberately opened tray menu.
//! No menu is queried until the user clicks a real registered StatusNotifierItem.
const std = @import("std");
const dbus = @import("dbus_c");

pub const capacity = 12;
const call_timeout_ms = 140;

pub const Row = struct {
    id: i32 = 0,
    label: [96]u8 = @splat(0),
    length: usize = 0,
    enabled: bool = true,
    visible: bool = true,
    submenu: bool = false,

    pub fn text(self: *const Row) []const u8 {
        return self.label[0..self.length];
    }
};

pub const Menu = struct {
    rows: [capacity]Row = undefined,
    count: usize = 0,
    parent: i32 = 0,

    fn append(self: *Menu, row: Row) void {
        if (self.count == self.rows.len or row.id <= 0 or !row.visible or row.length == 0) return;
        self.rows[self.count] = row;
        self.count += 1;
    }
};

pub fn fetch(service: [:0]const u8, path: [:0]const u8, parent: i32) !?Menu {
    if (path.len < 2 or path[0] != '/') return error.MenuPathInvalid;
    const conn = open() orelse return null;
    defer close(conn);
    const message = dbus.dbus_message_new_method_call(service.ptr, path.ptr, "com.canonical.dbusmenu", "GetLayout") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    var id = parent;
    var depth: i32 = 1;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &id) == 0 or
        dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &depth) == 0)
        return error.OutOfMemory;
    var array: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_open_container(&iter, dbus.DBUS_TYPE_ARRAY, "s", &array) == 0)
        return error.OutOfMemory;
    if (dbus.dbus_message_iter_close_container(&iter, &array) == 0) return error.OutOfMemory;
    const reply = dbus.dbus_connection_send_with_reply_and_block(conn, message, call_timeout_ms, null) orelse
        return null;
    defer dbus.dbus_message_unref(reply);
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN) return null;
    var menu: Menu = .{ .parent = parent };
    parseLayout(&menu, reply);
    return if (menu.count != 0) menu else null;
}

/// Fires the requested DBusMenu action; never waits on application-side work.
pub fn click(service: [:0]const u8, path: [:0]const u8, id: i32) !void {
    if (id <= 0 or path.len < 2) return error.TrayMenuSelectionInvalid;
    const conn = open() orelse return error.TrayBusUnavailable;
    defer close(conn);
    const message = dbus.dbus_message_new_method_call(service.ptr, path.ptr, "com.canonical.dbusmenu", "Event") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    var action_id = id;
    var action: [*:0]const u8 = "clicked";
    var timestamp: dbus.dbus_uint32_t = 0;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &action_id) == 0 or
        dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&action)) == 0)
        return error.OutOfMemory;
    var variant: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_open_container(&iter, dbus.DBUS_TYPE_VARIANT, "s", &variant) == 0)
        return error.OutOfMemory;
    var empty: [*:0]const u8 = "";
    if (dbus.dbus_message_iter_append_basic(&variant, dbus.DBUS_TYPE_STRING, @ptrCast(&empty)) == 0 or
        dbus.dbus_message_iter_close_container(&iter, &variant) == 0)
        return error.OutOfMemory;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_UINT32, &timestamp) == 0)
        return error.OutOfMemory;
    if (dbus.dbus_connection_send(conn, message, null) == 0) return error.TrayMenuSendFailed;
    dbus.dbus_connection_flush(conn);
}

fn open() ?*dbus.DBusConnection {
    const conn = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse return null;
    dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
    dbus.dbus_connection_set_max_message_size(conn, 128 * 1024);
    dbus.dbus_connection_set_max_message_unix_fds(conn, 0);
    return conn;
}
fn close(conn: *dbus.DBusConnection) void {
    dbus.dbus_connection_close(conn);
    dbus.dbus_connection_unref(conn);
}

fn readString(iter: *dbus.DBusMessageIter) []const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING) return "";
    var ptr: [*c]const u8 = null;
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&ptr));
    return if (ptr == null) "" else std.mem.span(ptr);
}

fn parseLayout(menu: *Menu, reply: *dbus.DBusMessage) void {
    var root: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &root) == 0 or
        dbus.dbus_message_iter_get_arg_type(&root) != dbus.DBUS_TYPE_UINT32) return;
    _ = dbus.dbus_message_iter_next(&root);
    if (dbus.dbus_message_iter_get_arg_type(&root) != dbus.DBUS_TYPE_STRUCT) return;
    var layout: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&root, &layout);
    if (dbus.dbus_message_iter_get_arg_type(&layout) != dbus.DBUS_TYPE_INT32) return;
    _ = dbus.dbus_message_iter_next(&layout);
    if (dbus.dbus_message_iter_get_arg_type(&layout) != dbus.DBUS_TYPE_ARRAY) return;
    _ = dbus.dbus_message_iter_next(&layout);
    if (dbus.dbus_message_iter_get_arg_type(&layout) != dbus.DBUS_TYPE_ARRAY) return;
    var children: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&layout, &children);
    for (0..capacity + 8) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&children) != dbus.DBUS_TYPE_VARIANT) break;
        var item: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&children, &item);
        if (dbus.dbus_message_iter_get_arg_type(&item) == dbus.DBUS_TYPE_STRUCT)
            parseRow(menu, &item);
        _ = dbus.dbus_message_iter_next(&children);
    }
}

fn parseRow(menu: *Menu, entry: *dbus.DBusMessageIter) void {
    var child: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(entry, &child);
    if (dbus.dbus_message_iter_get_arg_type(&child) != dbus.DBUS_TYPE_INT32) return;
    var row: Row = .{};
    dbus.dbus_message_iter_get_basic(&child, &row.id);
    _ = dbus.dbus_message_iter_next(&child);
    if (dbus.dbus_message_iter_get_arg_type(&child) != dbus.DBUS_TYPE_ARRAY) return;
    var attrs: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&child, &attrs);
    for (0..32) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&attrs) != dbus.DBUS_TYPE_DICT_ENTRY) break;
        var pair: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&attrs, &pair);
        const key = readString(&pair);
        _ = dbus.dbus_message_iter_next(&pair);
        if (dbus.dbus_message_iter_get_arg_type(&pair) == dbus.DBUS_TYPE_VARIANT) {
            var value: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_recurse(&pair, &value);
            if (std.mem.eql(u8, key, "label")) {
                const label = readString(&value);
                if (label.len < row.label.len and std.unicode.utf8ValidateSlice(label)) {
                    @memcpy(row.label[0..label.len], label);
                    row.length = label.len;
                }
            } else if (std.mem.eql(u8, key, "children-display")) {
                row.submenu = std.mem.eql(u8, readString(&value), "submenu");
            } else if (std.mem.eql(u8, key, "enabled") or std.mem.eql(u8, key, "visible")) {
                if (dbus.dbus_message_iter_get_arg_type(&value) == dbus.DBUS_TYPE_BOOLEAN) {
                    var present: dbus.dbus_bool_t = 0;
                    dbus.dbus_message_iter_get_basic(&value, &present);
                    if (std.mem.eql(u8, key, "enabled")) row.enabled = present != 0 else row.visible = present != 0;
                }
            }
        }
        _ = dbus.dbus_message_iter_next(&attrs);
    }
    menu.append(row);
}

test "menu bounded rows reject separators and hidden items" {
    var menu: Menu = .{};
    menu.append(.{ .id = 0, .length = 1 });
    menu.append(.{ .id = 1, .length = 1, .visible = false });
    menu.append(.{ .id = 2, .length = 1, .enabled = false });
    try std.testing.expectEqual(@as(usize, 1), menu.count);
    try std.testing.expectEqual(@as(i32, 2), menu.rows[0].id);
    try std.testing.expect(!menu.rows[0].enabled);
}

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

test "explicit private bus DBusMenu layout and activation round trip" {
    const enabled = getenv("WAYSPOT_TRAY_PRIVATE_TEST") orelse return;
    if (!std.mem.eql(u8, std.mem.span(enabled), "1")) return;
    const current = (try fetch("org.kde.StatusNotifierItem-4242-1", "/TrayMenu", 0)) orelse
        return error.MissingMenu;
    try std.testing.expectEqual(@as(usize, 1), current.count);
    try std.testing.expectEqual(@as(i32, 7), current.rows[0].id);
    try std.testing.expectEqualStrings("Open Mock Settings", current.rows[0].text());
    try click("org.kde.StatusNotifierItem-4242-1", "/TrayMenu", current.rows[0].id);
}
