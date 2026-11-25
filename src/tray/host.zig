//! One invocation-local StatusNotifierHost snapshot. All external item facts
//! come fresh from the live session bus after the picker's first useful frame.
const std = @import("std");
const dbus = @import("dbus_c");
const watcher = @import("watcher.zig");

pub const capacity = watcher.max_items;
const service_capacity = 160;
const path_capacity = 160;
const title_capacity = 120;
const icon_capacity = 160;
const pixel_side_limit = 128;
const max_pixmap_bytes = pixel_side_limit * pixel_side_limit * 4;
const call_milliseconds = 70;

const watcher_name: [*:0]const u8 = "org.kde.StatusNotifierWatcher";
const watcher_path: [*:0]const u8 = "/StatusNotifierWatcher";
const watcher_iface: [*:0]const u8 = "org.kde.StatusNotifierWatcher";
const kde_item: [*:0]const u8 = "org.kde.StatusNotifierItem";
const fd_item: [*:0]const u8 = "org.freedesktop.StatusNotifierItem";
const properties: [*:0]const u8 = "org.freedesktop.DBus.Properties";

pub const Entry = struct {
    service: [service_capacity:0]u8 = @splat(0),
    service_len: usize = 0,
    path: [path_capacity:0]u8 = @splat(0),
    path_len: usize = 0,
    title: [title_capacity:0]u8 = @splat(0),
    title_len: usize = 0,
    icon_name: [icon_capacity:0]u8 = @splat(0),
    icon_len: usize = 0,
    menu_path: [path_capacity:0]u8 = @splat(0),
    menu_len: usize = 0,
    item_is_menu: bool = false,
    passive: bool = false,
    interface: [*:0]const u8 = kde_item,
    pixels: ?[]u32 = null,
    width: u16 = 0,
    height: u16 = 0,

    pub fn serviceName(self: *const Entry) [:0]const u8 {
        return self.service[0..self.service_len :0];
    }
    pub fn objectPath(self: *const Entry) [:0]const u8 {
        return self.path[0..self.path_len :0];
    }
    pub fn titleText(self: *const Entry) []const u8 {
        return self.title[0..self.title_len];
    }
    pub fn iconText(self: *const Entry) []const u8 {
        return self.icon_name[0..self.icon_len];
    }
    pub fn menuPath(self: *const Entry) [:0]const u8 {
        return self.menu_path[0..self.menu_len :0];
    }

    fn setName(self: *Entry, service: []const u8, path: []const u8) !void {
        if (service.len == 0 or service.len >= service_capacity or path.len == 0 or
            path.len >= path_capacity or path[0] != '/') return error.TrayItemIdentityInvalid;
        for (service) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != ':' and byte != '_' and byte != '-')
            return error.TrayItemIdentityInvalid;
        for (path) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '/' and byte != '_')
            return error.TrayItemIdentityInvalid;
        @memcpy(self.service[0..service.len], service);
        self.service_len = service.len;
        @memcpy(self.path[0..path.len], path);
        self.path_len = path.len;
        const fallback = if (std.mem.lastIndexOfScalar(u8, service, '.')) |index| service[index + 1 ..] else service;
        self.copyTitle(fallback);
    }

    fn copyTitle(self: *Entry, value: []const u8) void {
        if (value.len == 0 or value.len >= title_capacity or !std.unicode.utf8ValidateSlice(value)) return;
        @memcpy(self.title[0..value.len], value);
        self.title_len = value.len;
        self.title[value.len] = 0;
    }
    fn copyIcon(self: *Entry, value: []const u8) void {
        if (value.len == 0 or value.len >= icon_capacity or !std.unicode.utf8ValidateSlice(value)) return;
        @memcpy(self.icon_name[0..value.len], value);
        self.icon_len = value.len;
        self.icon_name[value.len] = 0;
    }
    fn copyMenu(self: *Entry, value: []const u8) void {
        if (value.len < 2 or value.len >= path_capacity or value[0] != '/') return;
        @memcpy(self.menu_path[0..value.len], value);
        self.menu_len = value.len;
        self.menu_path[value.len] = 0;
    }

    fn parseIdentifier(self: *Entry, value: []const u8) !void {
        const slash = std.mem.indexOfScalar(u8, value, '/') orelse return error.TrayItemIdentityInvalid;
        try self.setName(value[0..slash], value[slash..]);
    }
    fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        if (self.pixels) |value| allocator.free(value);
        self.* = .{};
    }
};

pub const Snapshot = struct {
    entries: [capacity]Entry = undefined,
    count: usize = 0,

    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        for (self.entries[0..self.count]) |*entry| entry.deinit(allocator);
        self.count = 0;
    }

    /// The DBus host is a temporary picker connection. No watcher or UI
    /// daemon is started here, and a missing watcher simply means no icons.
    pub fn read(allocator: std.mem.Allocator, canceled: ?*const std.atomic.Value(bool)) !Snapshot {
        var snapshot: Snapshot = .{};
        errdefer snapshot.deinit(allocator);
        if (canceled) |stop| if (stop.load(.acquire)) return snapshot;
        const conn = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse return snapshot;
        defer {
            dbus.dbus_connection_close(conn);
            dbus.dbus_connection_unref(conn);
        }
        dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
        dbus.dbus_connection_set_max_message_size(conn, 256 * 1024);
        dbus.dbus_connection_set_max_message_unix_fds(conn, 0);
        const reply = try get(conn, watcher_name, watcher_path, watcher_iface, "RegisteredStatusNotifierItems") orelse
            return snapshot;
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_init(reply, &iter) == 0 or
            dbus.dbus_message_iter_get_arg_type(&iter) != dbus.DBUS_TYPE_VARIANT) return snapshot;
        var variant: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&iter, &variant);
        if (dbus.dbus_message_iter_get_arg_type(&variant) != dbus.DBUS_TYPE_ARRAY) return snapshot;
        var items: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&variant, &items);
        while (dbus.dbus_message_iter_get_arg_type(&items) == dbus.DBUS_TYPE_STRING and
            snapshot.count < capacity)
        {
            if (canceled) |stop| if (stop.load(.acquire)) break;
            const label = readString(&items);
            var entry: Entry = .{};
            if (entry.parseIdentifier(label)) |_| {
                // Items may disappear between enumeration and property lookup.
                // Do not allow a slow or malformed item to fail the picker.
                fetch(&entry, conn, allocator) catch {};
                if (!entry.passive) {
                    snapshot.entries[snapshot.count] = entry;
                    snapshot.count += 1;
                } else entry.deinit(allocator);
            } else |_| {}
            _ = dbus.dbus_message_iter_next(&items);
        }
        return snapshot;
    }

    /// The user activated a real item. Do not block the SDL input thread
    /// waiting for the external application to execute its action.
    pub fn activate(self: *const Snapshot, index: usize, x: i32, y: i32, button: u8) !void {
        if (index >= self.count) return error.TrayIndexInvalid;
        const item = &self.entries[index];
        const method: [*:0]const u8 = if (button == 3 or item.item_is_menu)
            "ContextMenu"
        else if (button == 2)
            "SecondaryActivate"
        else
            "Activate";
        const conn = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse return error.TrayBusUnavailable;
        defer {
            dbus.dbus_connection_close(conn);
            dbus.dbus_connection_unref(conn);
        }
        dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
        const call = dbus.dbus_message_new_method_call(item.serviceName().ptr, item.objectPath().ptr, item.interface, method) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(call);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(call, &iter);
        if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, @constCast(&x)) == 0 or
            dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, @constCast(&y)) == 0)
            return error.OutOfMemory;
        if (dbus.dbus_connection_send(conn, call, null) == 0) return error.TraySendFailed;
        dbus.dbus_connection_flush(conn);
    }
};

fn get(conn: *dbus.DBusConnection, name: [*:0]const u8, path: [*:0]const u8, item_interface: [*:0]const u8, key: [*:0]const u8) !?*dbus.DBusMessage {
    const message = dbus.dbus_message_new_method_call(name, path, properties, "Get") orelse
        return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    var iface_pointer = item_interface;
    var key_pointer = key;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&iface_pointer)) == 0 or
        dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&key_pointer)) == 0)
        return error.OutOfMemory;
    const reply = dbus.dbus_connection_send_with_reply_and_block(conn, message, call_milliseconds, null) orelse
        return null;
    if (dbus.dbus_message_get_type(reply) == dbus.DBUS_MESSAGE_TYPE_ERROR) {
        dbus.dbus_message_unref(reply);
        return null;
    }
    return reply;
}

fn getAll(conn: *dbus.DBusConnection, entry: *Entry, interface: [*:0]const u8) !?*dbus.DBusMessage {
    const message = dbus.dbus_message_new_method_call(entry.serviceName().ptr, entry.objectPath().ptr, properties, "GetAll") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    var pointer = interface;
    if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0)
        return error.OutOfMemory;
    const reply = dbus.dbus_connection_send_with_reply_and_block(conn, message, call_milliseconds, null) orelse return null;
    if (dbus.dbus_message_get_type(reply) == dbus.DBUS_MESSAGE_TYPE_ERROR) {
        dbus.dbus_message_unref(reply);
        return null;
    }
    // Some applications expose only the freedesktop Item interface and reply
    // with an empty property dictionary for the KDE spelling. Treat that as
    // an unsupported interface, not a valid item with no icon or actions.
    var result: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &result) != 0 and
        dbus.dbus_message_iter_get_arg_type(&result) == dbus.DBUS_TYPE_ARRAY)
    {
        var entries: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&result, &entries);
        if (dbus.dbus_message_iter_get_arg_type(&entries) == dbus.DBUS_TYPE_INVALID) {
            dbus.dbus_message_unref(reply);
            return null;
        }
    }
    return reply;
}

fn readString(iter: *dbus.DBusMessageIter) []const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING and
        dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_OBJECT_PATH) return "";
    var pointer: [*c]const u8 = null;
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    return if (pointer != null) std.mem.span(pointer) else "";
}

fn parseProperties(entry: *Entry, allocator: std.mem.Allocator, reply: *dbus.DBusMessage) !void {
    var root: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &root) == 0 or
        dbus.dbus_message_iter_get_arg_type(&root) != dbus.DBUS_TYPE_ARRAY) return;
    var attributes: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&root, &attributes);
    for (0..80) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&attributes) != dbus.DBUS_TYPE_DICT_ENTRY) break;
        var attribute: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&attributes, &attribute);
        const name = readString(&attribute);
        _ = dbus.dbus_message_iter_next(&attribute);
        if (dbus.dbus_message_iter_get_arg_type(&attribute) == dbus.DBUS_TYPE_VARIANT) {
            var value: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_recurse(&attribute, &value);
            if (std.mem.eql(u8, name, "IconName") and entry.icon_len == 0) entry.copyIcon(readString(&value)) else if (std.mem.eql(u8, name, "AttentionIconName") and entry.icon_len == 0) entry.copyIcon(readString(&value)) else if (std.mem.eql(u8, name, "Title")) entry.copyTitle(readString(&value)) else if (std.mem.eql(u8, name, "Status")) entry.passive = std.mem.eql(u8, readString(&value), "Passive") else if (std.mem.eql(u8, name, "ItemIsMenu") and dbus.dbus_message_iter_get_arg_type(&value) == dbus.DBUS_TYPE_BOOLEAN) {
                var flag: dbus.dbus_bool_t = 0;
                dbus.dbus_message_iter_get_basic(&value, &flag);
                entry.item_is_menu = flag != 0;
            } else if (std.mem.eql(u8, name, "Menu")) entry.copyMenu(readString(&value)) else if ((std.mem.eql(u8, name, "IconPixmap") or
                std.mem.eql(u8, name, "AttentionIconPixmap")) and entry.pixels == null)
            {
                try readPixmap(entry, allocator, &value);
            }
        }
        _ = dbus.dbus_message_iter_next(&attributes);
    }
}

fn readPixmap(entry: *Entry, allocator: std.mem.Allocator, iter: *dbus.DBusMessageIter) !void {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_ARRAY) return;
    var images: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(iter, &images);
    var best_distance: usize = std.math.maxInt(usize);
    for (0..16) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&images) != dbus.DBUS_TYPE_STRUCT) break;
        var image: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&images, &image);
        if (dbus.dbus_message_iter_get_arg_type(&image) != dbus.DBUS_TYPE_INT32) break;
        var w: i32 = 0;
        var h: i32 = 0;
        dbus.dbus_message_iter_get_basic(&image, &w);
        _ = dbus.dbus_message_iter_next(&image);
        if (dbus.dbus_message_iter_get_arg_type(&image) != dbus.DBUS_TYPE_INT32) break;
        dbus.dbus_message_iter_get_basic(&image, &h);
        _ = dbus.dbus_message_iter_next(&image);
        if (w > 0 and h > 0 and w <= pixel_side_limit and h <= pixel_side_limit and
            dbus.dbus_message_iter_get_arg_type(&image) == dbus.DBUS_TYPE_ARRAY)
        {
            const count: usize = @as(usize, @intCast(w)) * @as(usize, @intCast(h));
            const distance: usize = @intCast(@abs(w - 22) + @abs(h - 22));
            if (count * 4 <= max_pixmap_bytes and distance < best_distance) {
                var data: dbus.DBusMessageIter = undefined;
                dbus.dbus_message_iter_recurse(&image, &data);
                if (dbus.dbus_message_iter_get_arg_type(&data) == dbus.DBUS_TYPE_BYTE) {
                    var bytes: [*c]const u8 = null;
                    var length: c_int = 0;
                    // `get_fixed_array` takes the *element* iterator after
                    // recursing into `ay`, not the parent array container.
                    // Passing the parent triggers a fatal libdbus assertion.
                    dbus.dbus_message_iter_get_fixed_array(&data, @ptrCast(&bytes), &length);
                    if (bytes != null and length == count * 4) {
                        const next = try allocator.alloc(u32, count);
                        if (entry.pixels) |old| allocator.free(old);
                        for (next, 0..) |*pixel, index| {
                            const start = index * 4;
                            pixel.* = std.mem.readInt(u32, bytes[start..][0..4], .big);
                        }
                        entry.pixels = next;
                        entry.width = @intCast(w);
                        entry.height = @intCast(h);
                        best_distance = distance;
                    }
                }
            }
        }
        _ = dbus.dbus_message_iter_next(&images);
    }
}

fn fetch(self: *Entry, conn: *dbus.DBusConnection, allocator: std.mem.Allocator) !void {
    const reply = try getAll(conn, self, kde_item) orelse blk: {
        self.interface = fd_item;
        break :blk try getAll(conn, self, fd_item) orelse return;
    };
    defer dbus.dbus_message_unref(reply);
    try parseProperties(self, allocator, reply);
}

// Expose one function in Entry's namespace without retaining a vtable.
comptime {
    _ = fetch;
}

test "item identifiers are parsed strictly and cheaply" {
    var entry: Entry = .{};
    try entry.parseIdentifier("org.kde.StatusNotifierItem-55-1/StatusNotifierItem");
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-55-1", entry.serviceName());
    try std.testing.expectEqualStrings("/StatusNotifierItem", entry.objectPath());
    try std.testing.expectError(error.TrayItemIdentityInvalid, entry.parseIdentifier("not-an-item"));
    try std.testing.expectError(error.TrayItemIdentityInvalid, entry.parseIdentifier("anything/../../escape"));
}

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

test "explicit private-session fixture supplies an actual pixmap and activation" {
    const enabled = getenv("WAYSPOT_TRAY_PRIVATE_TEST") orelse return;
    if (!std.mem.eql(u8, std.mem.span(enabled), "1")) return;
    var snapshot = try Snapshot.read(std.testing.allocator, null);
    defer snapshot.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), snapshot.count);
    const item = &snapshot.entries[0];
    const fd_mode = getenv("WAYSPOT_TRAY_MOCK_FD_ONLY") != null;
    try std.testing.expectEqualStrings(if (fd_mode) "org.freedesktop.StatusNotifierItem" else "org.kde.StatusNotifierItem", std.mem.span(item.interface));
    try std.testing.expectEqualStrings("Wayspot Tray Test", item.titleText());
    try std.testing.expectEqual(@as(u16, 22), item.width);
    try std.testing.expectEqual(@as(u16, 22), item.height);
    const expected_argb: u32 = 0xff23d273;
    try std.testing.expectEqual(expected_argb, item.pixels.?[11 * 22 + 6]);
    try snapshot.activate(0, 495, 23, 1);
}
