//! Bounded `com.canonical.dbusmenu` host for one deliberately opened tray menu.
//! No menu is queried until the user clicks a real registered StatusNotifierItem.
const std = @import("std");
const dbus = @import("dbus_c");

/// Maximum visible menu rows retained for one opened layout.
pub const capacity = 12;
const child_capacity = capacity + 8;
const property_capacity = 32;
const call_timeout_ms = 140;

/// A copied menu row carrying the stable external action id and its admission flags.
pub const Row = struct {
    id: i32 = 0,
    label: [96]u8 = @splat(0),
    length: usize = 0,
    enabled: bool = true,
    visible: bool = true,
    submenu: bool = false,

    /// Borrows the row's validated UTF-8 label.
    pub fn text(self: *const Row) []const u8 {
        return self.label[0..self.length];
    }
};

/// Bounded snapshot of one requested parent; no retained D-Bus message pointers.
pub const Menu = struct {
    rows: [capacity]Row = undefined,
    count: usize = 0,
    parent: i32 = 0,

    fn append(self: *Menu, row: Row) !void {
        if (row.id <= 0 or !row.visible or row.length == 0) return;
        for (self.rows[0..self.count]) |existing| {
            if (existing.id == row.id) return error.MenuDuplicateId;
        }
        if (self.count == self.rows.len) return;
        self.rows[self.count] = row;
        self.count += 1;
    }
};

/// Fetches one level of the exact parent from a validated menu destination.
/// Empty or malformed layout replies yield no menu; ambiguous action ids fail explicitly.
pub fn fetch(service: [:0]const u8, path: [:0]const u8, parent: i32) !?Menu {
    try validateDestination(service, path);
    if (parent < 0) return error.TrayMenuSelectionInvalid;
    const conn = open() orelse return null;
    defer close(conn);
    const message = dbus.dbus_message_new_method_call(
        service.ptr,
        path.ptr,
        "com.canonical.dbusmenu",
        "GetLayout",
    ) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    const id = parent;
    const depth: i32 = 1;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &id) == 0 or
        dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &depth) == 0)
        return error.OutOfMemory;
    // Abandon only during construction, never after the message is sent.
    {
        var array: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_open_container(&iter, dbus.DBUS_TYPE_ARRAY, "s", &array) == 0)
            return error.OutOfMemory;
        errdefer dbus.dbus_message_iter_abandon_container_if_open(&iter, &array);
        if (dbus.dbus_message_iter_close_container(&iter, &array) == 0) return error.OutOfMemory;
    }
    const reply = dbus.dbus_connection_send_with_reply_and_block(
        conn,
        message,
        call_timeout_ms,
        null,
    ) orelse return null;
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{ .parent = parent };
    try parseLayout(&menu, reply);
    return if (menu.count != 0) menu else null;
}

/// Sends the caller-selected action id without waiting for an application-side reply.
/// The caller owns row admission; connection acquisition and flushing are synchronous.
pub fn click(service: [:0]const u8, path: [:0]const u8, id: i32) !void {
    if (id <= 0) return error.TrayMenuSelectionInvalid;
    try validateDestination(service, path);
    const conn = open() orelse return error.TrayBusUnavailable;
    defer close(conn);
    const message = dbus.dbus_message_new_method_call(
        service.ptr,
        path.ptr,
        "com.canonical.dbusmenu",
        "Event",
    ) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    const timestamp: dbus.dbus_uint32_t = 0;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &id) == 0)
        return error.OutOfMemory;
    try appendString(&iter, "clicked");
    {
        var variant: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_open_container(&iter, dbus.DBUS_TYPE_VARIANT, "s", &variant) == 0)
            return error.OutOfMemory;
        errdefer dbus.dbus_message_iter_abandon_container_if_open(&iter, &variant);
        try appendString(&variant, "");
        if (dbus.dbus_message_iter_close_container(&iter, &variant) == 0)
            return error.OutOfMemory;
    }
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_UINT32, &timestamp) == 0)
        return error.OutOfMemory;
    if (dbus.dbus_connection_send(conn, message, null) == 0) return error.TrayMenuSendFailed;
    dbus.dbus_connection_flush(conn);
}

fn validateDestination(service: [:0]const u8, path: [:0]const u8) !void {
    if (std.mem.indexOfScalar(u8, service, 0) != null or
        dbus.dbus_validate_bus_name(service.ptr, null) == 0)
    {
        return error.MenuServiceInvalid;
    }
    if (path.len < 2 or std.mem.indexOfScalar(u8, path, 0) != null or
        dbus.dbus_validate_path(path.ptr, null) == 0)
    {
        return error.MenuPathInvalid;
    }
}

fn appendString(iter: *dbus.DBusMessageIter, value: [*:0]const u8) !void {
    // zig-audit: acknowledge ptr_cast
    // reason: libdbus copies a C string using the address of its pointer value.
    if (dbus.dbus_message_iter_append_basic(iter, dbus.DBUS_TYPE_STRING, @ptrCast(&value)) == 0)
        return error.OutOfMemory;
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

fn readString(iter: *dbus.DBusMessageIter) ?[]const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING) return null;
    var ptr: [*c]const u8 = null;
    // zig-audit: acknowledge ptr_cast
    // reason: Signature-checked string read writes a borrowed C string pointer.
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&ptr));
    return if (ptr == null) null else std.mem.span(ptr);
}

fn parseLayout(menu: *Menu, reply: *dbus.DBusMessage) !void {
    std.debug.assert(menu.count == 0);
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN or
        dbus.dbus_message_has_signature(reply, "u(ia{sv}av)") == 0) return;
    var root: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &root) == 0) return;
    if (dbus.dbus_message_iter_next(&root) == 0) return;
    var layout: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&root, &layout);
    var parent: i32 = undefined;
    dbus.dbus_message_iter_get_basic(&layout, &parent);
    if (parent != menu.parent) return;
    if (dbus.dbus_message_iter_next(&layout) == 0) return;
    if (dbus.dbus_message_iter_next(&layout) == 0) return;
    var children: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&layout, &children);
    for (0..child_capacity) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&children) != dbus.DBUS_TYPE_VARIANT) break;
        var item: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&children, &item);
        if (try parseRow(&item)) |row| try menu.append(row);
        if (dbus.dbus_message_iter_next(&children) == 0) break;
    }
}

const Property = enum { label, enabled, visible, @"children-display", type };

fn parseRow(entry: *dbus.DBusMessageIter) !?Row {
    if (dbus.dbus_message_iter_get_arg_type(entry) != dbus.DBUS_TYPE_STRUCT) return null;
    // Each child is a variant, so the root signature cannot validate its payload.
    const signature = dbus.dbus_message_iter_get_signature(entry);
    if (signature == null) return error.OutOfMemory;
    defer dbus.dbus_free(signature);
    if (!std.mem.eql(u8, std.mem.span(signature), "(ia{sv}av)")) return null;

    var child: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(entry, &child);
    var row: Row = .{};
    dbus.dbus_message_iter_get_basic(&child, &row.id);
    if (dbus.dbus_message_iter_next(&child) == 0) return null;
    var attrs: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&child, &attrs);
    var seen: std.EnumSet(Property) = .empty;
    for (0..property_capacity) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&attrs) != dbus.DBUS_TYPE_DICT_ENTRY)
            return row;
        var pair: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&attrs, &pair);
        const key = readString(&pair) orelse return null;
        if (std.meta.stringToEnum(Property, key)) |property| {
            if (seen.contains(property)) return null;
            seen.insert(property);
            if (dbus.dbus_message_iter_next(&pair) == 0) return null;
            var value: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_recurse(&pair, &value);
            if (!applyProperty(&row, property, &value)) return null;
        }
        if (dbus.dbus_message_iter_next(&attrs) == 0) return row;
    }
    // A truncated property dictionary could hide enabled=false or visible=false.
    return null;
}

fn applyProperty(row: *Row, property: Property, value: *dbus.DBusMessageIter) bool {
    switch (property) {
        .label => {
            const label = readString(value) orelse return false;
            if (label.len >= row.label.len or !std.unicode.utf8ValidateSlice(label)) return false;
            @memcpy(row.label[0..label.len], label);
            row.length = label.len;
        },
        .@"children-display" => {
            const display = readString(value) orelse return false;
            row.submenu = std.mem.eql(u8, display, "submenu");
        },
        .type => {
            const kind = readString(value) orelse return false;
            if (std.mem.eql(u8, kind, "separator")) return false;
        },
        .enabled, .visible => {
            if (dbus.dbus_message_iter_get_arg_type(value) != dbus.DBUS_TYPE_BOOLEAN)
                return false;
            var present: dbus.dbus_bool_t = 0;
            dbus.dbus_message_iter_get_basic(value, &present);
            if (property == .enabled) row.enabled = present != 0 else row.visible = present != 0;
        },
    }
    return true;
}

test "menu bounded rows reject separators and hidden items" {
    var menu: Menu = .{};
    try menu.append(.{ .id = 0, .length = 1 });
    try menu.append(.{ .id = 1, .length = 1, .visible = false });
    try menu.append(.{ .id = 2, .length = 1, .enabled = false });
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

const TestProperty = struct {
    key: [:0]const u8,
    value: union(enum) { string: [:0]const u8, boolean: bool },
};

fn openTest(
    iter: *dbus.DBusMessageIter,
    kind: c_int,
    signature: ?[*:0]const u8,
) !dbus.DBusMessageIter {
    var child: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_open_container(iter, kind, signature, &child) == 0)
        return error.OutOfMemory;
    return child;
}

fn closeTest(iter: *dbus.DBusMessageIter, child: *dbus.DBusMessageIter) !void {
    if (dbus.dbus_message_iter_close_container(iter, child) == 0) return error.OutOfMemory;
}

fn appendPropertyTest(iter: *dbus.DBusMessageIter, property: TestProperty) !void {
    var pair = try openTest(iter, dbus.DBUS_TYPE_DICT_ENTRY, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &pair);
    try appendString(&pair, property.key.ptr);
    var value = try openTest(&pair, dbus.DBUS_TYPE_VARIANT, switch (property.value) {
        .string => "s",
        .boolean => "b",
    });
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&pair, &value);
    switch (property.value) {
        .string => |string| try appendString(&value, string.ptr),
        .boolean => |boolean| {
            const flag: dbus.dbus_bool_t = @intFromBool(boolean);
            if (dbus.dbus_message_iter_append_basic(&value, dbus.DBUS_TYPE_BOOLEAN, &flag) == 0)
                return error.OutOfMemory;
        },
    }
    try closeTest(&pair, &value);
    try closeTest(iter, &pair);
}

const TestRow = struct {
    id: i32,
    properties: []const TestProperty,
    omit_children: bool = false,
};

fn appendRowTest(iter: *dbus.DBusMessageIter, row: TestRow) !void {
    const signature = if (row.omit_children) "(ia{sv})" else "(ia{sv}av)";
    var variant = try openTest(iter, dbus.DBUS_TYPE_VARIANT, signature);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &variant);
    var child = try openTest(&variant, dbus.DBUS_TYPE_STRUCT, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&variant, &child);
    if (dbus.dbus_message_iter_append_basic(&child, dbus.DBUS_TYPE_INT32, &row.id) == 0)
        return error.OutOfMemory;
    var attrs = try openTest(&child, dbus.DBUS_TYPE_ARRAY, "{sv}");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&child, &attrs);
    for (row.properties) |property| try appendPropertyTest(&attrs, property);
    try closeTest(&child, &attrs);
    if (!row.omit_children) {
        var children = try openTest(&child, dbus.DBUS_TYPE_ARRAY, "v");
        errdefer dbus.dbus_message_iter_abandon_container_if_open(&child, &children);
        try closeTest(&child, &children);
    }
    try closeTest(&variant, &child);
    try closeTest(iter, &variant);
}

fn layoutTest(parent: i32, rows: []const TestRow) !*dbus.DBusMessage {
    const message = dbus.dbus_message_new(dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN) orelse
        return error.OutOfMemory;
    errdefer dbus.dbus_message_unref(message);
    var root: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &root);
    const revision: u32 = 42;
    if (dbus.dbus_message_iter_append_basic(&root, dbus.DBUS_TYPE_UINT32, &revision) == 0)
        return error.OutOfMemory;
    var layout = try openTest(&root, dbus.DBUS_TYPE_STRUCT, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&root, &layout);
    if (dbus.dbus_message_iter_append_basic(&layout, dbus.DBUS_TYPE_INT32, &parent) == 0)
        return error.OutOfMemory;
    var attrs = try openTest(&layout, dbus.DBUS_TYPE_ARRAY, "{sv}");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&layout, &attrs);
    try closeTest(&layout, &attrs);
    var children = try openTest(&layout, dbus.DBUS_TYPE_ARRAY, "v");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&layout, &children);
    for (rows) |row| try appendRowTest(&children, row);
    try closeTest(&layout, &children);
    try closeTest(&root, &layout);
    return message;
}

const test_label = TestProperty{ .key = "label", .value = .{ .string = "Action" } };

test "layout reply belongs to its requested parent" {
    const reply = try layoutTest(9, &.{.{ .id = 7, .properties = &.{test_label} }});
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{ .parent = 0 };
    try parseLayout(&menu, reply);
    try std.testing.expectEqual(@as(usize, 0), menu.count);
}

test "malformed action attributes cannot default to an enabled visible row" {
    const reply = try layoutTest(0, &.{
        .{ .id = 7, .properties = &.{
            test_label,
            .{ .key = "enabled", .value = .{ .string = "false" } },
        } },
        .{ .id = 8, .properties = &.{
            test_label,
            .{ .key = "visible", .value = .{ .string = "false" } },
        } },
        .{ .id = 9, .properties = &.{test_label} },
    });
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{};
    try parseLayout(&menu, reply);
    try std.testing.expectEqual(@as(usize, 1), menu.count);
    try std.testing.expectEqual(@as(i32, 9), menu.rows[0].id);
}

test "incomplete row structs and labelled separators never become actions" {
    const reply = try layoutTest(0, &.{
        .{ .id = 7, .properties = &.{test_label}, .omit_children = true },
        .{ .id = 8, .properties = &.{
            test_label,
            .{ .key = "type", .value = .{ .string = "separator" } },
        } },
        .{ .id = 9, .properties = &.{test_label} },
    });
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{};
    try parseLayout(&menu, reply);
    try std.testing.expectEqual(@as(usize, 1), menu.count);
    try std.testing.expectEqual(@as(i32, 9), menu.rows[0].id);
}

test "oversized property list cannot hide an explicit disabled flag" {
    var properties: [33]TestProperty = @splat(.{
        .key = "extension",
        .value = .{ .string = "ignored" },
    });
    properties[0] = test_label;
    properties[32] = .{ .key = "enabled", .value = .{ .boolean = false } };
    const reply = try layoutTest(0, &.{.{ .id = 7, .properties = &properties }});
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{};
    try parseLayout(&menu, reply);
    try std.testing.expectEqual(@as(usize, 0), menu.count);
}

test "ambiguous row ids refuse the layout" {
    const reply = try layoutTest(0, &.{
        .{ .id = 7, .properties = &.{test_label} },
        .{ .id = 7, .properties = &.{test_label} },
    });
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{};
    try std.testing.expectError(error.MenuDuplicateId, parseLayout(&menu, reply));
}

test "recognized duplicate properties are refused and exact property bound is admitted" {
    var properties: [property_capacity]TestProperty = @splat(.{
        .key = "extension",
        .value = .{ .string = "ignored" },
    });
    properties[0] = test_label;
    properties[properties.len - 1] = .{ .key = "enabled", .value = .{ .boolean = false } };
    const reply = try layoutTest(0, &.{
        .{ .id = 7, .properties = &properties },
        .{ .id = 8, .properties = &.{ test_label, test_label } },
    });
    defer dbus.dbus_message_unref(reply);
    var menu: Menu = .{};
    try parseLayout(&menu, reply);
    try std.testing.expectEqual(@as(usize, 1), menu.count);
    try std.testing.expectEqual(@as(i32, 7), menu.rows[0].id);
    try std.testing.expect(!menu.rows[0].enabled);
}

test "row and scan limits retain only the bounded prefix" {
    var rows: [child_capacity + 1]TestRow = undefined;
    for (&rows, 0..) |*row, i| {
        row.* = .{ .id = @intCast(i + 1), .properties = &.{test_label} };
    }
    const full = try layoutTest(0, &rows);
    defer dbus.dbus_message_unref(full);
    var menu: Menu = .{};
    try parseLayout(&menu, full);
    try std.testing.expectEqual(capacity, menu.count);
    try std.testing.expectEqual(@as(i32, capacity), menu.rows[capacity - 1].id);

    for (rows[0..child_capacity]) |*row| row.properties = &.{};
    const beyond = try layoutTest(0, &rows);
    defer dbus.dbus_message_unref(beyond);
    menu = .{};
    try parseLayout(&menu, beyond);
    try std.testing.expectEqual(@as(usize, 0), menu.count);
}

test "invalid destinations refuse before acquiring a bus connection" {
    try std.testing.expectError(error.MenuServiceInvalid, fetch("bad", "/Menu", 0));
    try std.testing.expectError(error.MenuPathInvalid, fetch("org.example.Item", "/bad//path", 0));
    try std.testing.expectError(error.MenuPathInvalid, click("org.example.Item", "/bad-path", 7));
    try std.testing.expectError(
        error.MenuServiceInvalid,
        click("org.example.Item\x00suffix", "/Menu", 7),
    );
    try std.testing.expectError(
        error.TrayMenuSelectionInvalid,
        fetch("org.example.Item", "/Menu", -1),
    );
    try std.testing.expectError(
        error.TrayMenuSelectionInvalid,
        click("org.example.Item", "/Menu", 0),
    );
}
