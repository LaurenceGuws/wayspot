//! One invocation-local StatusNotifierHost snapshot. All external item facts
//! come fresh from the live session bus after the picker's first useful frame.
const std = @import("std");
const dbus = @import("dbus_c");
const watcher = @import("watcher.zig");

/// Maximum enumerated item identities and retained entries per refresh.
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

/// One validated item identity, copied display properties and optional owned ARGB pixels.
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

    /// Borrows the validated, NUL-terminated destination bus name.
    pub fn serviceName(self: *const Entry) [:0]const u8 {
        return self.service[0..self.service_len :0];
    }
    /// Borrows the validated, NUL-terminated item object path.
    pub fn objectPath(self: *const Entry) [:0]const u8 {
        return self.path[0..self.path_len :0];
    }
    /// Borrows the copied title or service-name fallback.
    pub fn titleText(self: *const Entry) []const u8 {
        return self.title[0..self.title_len];
    }
    /// Borrows the copied icon name, empty when unavailable.
    pub fn iconText(self: *const Entry) []const u8 {
        return self.icon_name[0..self.icon_len];
    }
    /// Borrows the validated menu path; empty means no advertised menu.
    pub fn menuPath(self: *const Entry) [:0]const u8 {
        return self.menu_path[0..self.menu_len :0];
    }

    fn setName(self: *Entry, service: []const u8, path: []const u8) !void {
        var service_bytes: [service_capacity:0]u8 = @splat(0);
        var path_bytes: [path_capacity:0]u8 = @splat(0);
        if (!copyBounded(&service_bytes, service) or !copyBounded(&path_bytes, path)) {
            return error.TrayItemIdentityInvalid;
        }
        if (dbus.dbus_validate_bus_name(&service_bytes, null) == 0 or
            dbus.dbus_validate_path(&path_bytes, null) == 0)
        {
            return error.TrayItemIdentityInvalid;
        }
        self.service = service_bytes;
        self.service_len = service.len;
        self.path = path_bytes;
        self.path_len = path.len;
        const fallback = if (std.mem.lastIndexOfScalar(u8, service, '.')) |index|
            service[index + 1 ..]
        else
            service;
        self.title_len = 0;
        self.title[0] = 0;
        self.copyTitle(fallback);
    }

    fn copyTitle(self: *Entry, value: []const u8) void {
        if (value.len == 0 or value.len >= title_capacity) return;
        if (!std.unicode.utf8ValidateSlice(value)) return;
        @memcpy(self.title[0..value.len], value);
        self.title_len = value.len;
        self.title[value.len] = 0;
    }
    fn copyIcon(self: *Entry, value: []const u8) void {
        if (value.len == 0 or value.len >= icon_capacity) return;
        if (!std.unicode.utf8ValidateSlice(value)) return;
        @memcpy(self.icon_name[0..value.len], value);
        self.icon_len = value.len;
        self.icon_name[value.len] = 0;
    }
    fn copyMenu(self: *Entry, value: []const u8) void {
        // The root path is the existing "no menu" convention.
        if (value.len < 2) return;
        var path_bytes: [path_capacity:0]u8 = @splat(0);
        if (!copyBounded(&path_bytes, value)) return;
        if (dbus.dbus_validate_path(&path_bytes, null) == 0) return;
        self.menu_path = path_bytes;
        self.menu_len = value.len;
    }

    fn parseIdentifier(self: *Entry, value: []const u8) !void {
        const slash = std.mem.indexOfScalar(u8, value, '/') orelse
            return error.TrayItemIdentityInvalid;
        try self.setName(value[0..slash], value[slash..]);
    }
    fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        if (self.pixels) |value| allocator.free(value);
        self.* = .{};
    }
};

// Copy only representable, nonempty strings into caller-owned zeroed storage.
fn copyBounded(buffer: []u8, value: []const u8) bool {
    if (value.len == 0 or value.len >= buffer.len) return false;
    if (std.mem.indexOfScalar(u8, value, 0) != null) return false;
    @memcpy(buffer[0..value.len], value);
    buffer[value.len] = 0;
    return true;
}

/// Owns one bounded live item snapshot and its pixel allocations.
pub const Snapshot = struct {
    entries: [capacity]Entry = undefined,
    count: usize = 0,

    /// Releases every retained pixmap using the allocator supplied to read.
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
        const reply = try get(
            conn,
            watcher_name,
            watcher_path,
            watcher_iface,
            "RegisteredStatusNotifierItems",
        ) orelse return snapshot;
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        if (dbus.dbus_message_iter_init(reply, &iter) == 0 or
            dbus.dbus_message_iter_get_arg_type(&iter) != dbus.DBUS_TYPE_VARIANT) return snapshot;
        var variant: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&iter, &variant);
        if (dbus.dbus_message_iter_get_arg_type(&variant) != dbus.DBUS_TYPE_ARRAY or
            dbus.dbus_message_iter_get_element_type(&variant) != dbus.DBUS_TYPE_STRING)
        {
            return snapshot;
        }
        var items: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&variant, &items);
        // Bound attempted identities, not only visible entries. Passive and
        // malformed registrations must not extend the worker's fetch budget.
        for (0..capacity) |_| {
            if (dbus.dbus_message_iter_get_arg_type(&items) != dbus.DBUS_TYPE_STRING) break;
            if (canceled) |stop| if (stop.load(.acquire)) break;
            var entry: Entry = .{};
            errdefer entry.deinit(allocator);
            if (entry.parseIdentifier(readString(&items))) |_| {
                // Missing property replies retain the identity fallback.
                // Allocation failure is not an unavailable external item.
                try fetch(&entry, conn, allocator, canceled);
                if (!entry.passive) {
                    snapshot.entries[snapshot.count] = entry;
                    snapshot.count += 1;
                } else {
                    entry.deinit(allocator);
                }
            } else |err| {
                std.debug.assert(err == error.TrayItemIdentityInvalid);
            }
            if (dbus.dbus_message_iter_next(&items) == 0) break;
        }
        return snapshot;
    }

    /// Sends the selected item's activation without waiting for an action reply.
    /// Connection acquisition and transport flushing remain synchronous.
    pub fn activate(self: *const Snapshot, index: usize, x: i32, y: i32, button: u8) !void {
        if (index >= self.count) return error.TrayIndexInvalid;
        const item = &self.entries[index];
        const method: [*:0]const u8 = if (button == 3 or item.item_is_menu)
            "ContextMenu"
        else if (button == 2)
            "SecondaryActivate"
        else
            "Activate";
        const conn = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse
            return error.TrayBusUnavailable;
        defer {
            dbus.dbus_connection_close(conn);
            dbus.dbus_connection_unref(conn);
        }
        dbus.dbus_connection_set_exit_on_disconnect(conn, 0);
        const call = dbus.dbus_message_new_method_call(
            item.serviceName().ptr,
            item.objectPath().ptr,
            item.interface,
            method,
        ) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(call);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(call, &iter);
        if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &x) == 0 or
            dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_INT32, &y) == 0)
            return error.OutOfMemory;
        if (dbus.dbus_connection_send(conn, call, null) == 0) return error.TraySendFailed;
        dbus.dbus_connection_flush(conn);
    }
};

fn appendString(iter: *dbus.DBusMessageIter, value: [*:0]const u8) !void {
    // zig-audit: acknowledge ptr_cast
    // reason: libdbus copies a C string using the address of its pointer value.
    if (dbus.dbus_message_iter_append_basic(iter, dbus.DBUS_TYPE_STRING, @ptrCast(&value)) == 0)
        return error.OutOfMemory;
}

fn get(
    conn: *dbus.DBusConnection,
    name: [*:0]const u8,
    path: [*:0]const u8,
    item_interface: [*:0]const u8,
    key: [*:0]const u8,
) !?*dbus.DBusMessage {
    const message = dbus.dbus_message_new_method_call(name, path, properties, "Get") orelse
        return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    try appendString(&iter, item_interface);
    try appendString(&iter, key);
    const reply = dbus.dbus_connection_send_with_reply_and_block(
        conn,
        message,
        call_milliseconds,
        null,
    ) orelse return null;
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN or
        dbus.dbus_message_has_signature(reply, "v") == 0)
    {
        dbus.dbus_message_unref(reply);
        return null;
    }
    return reply;
}

fn getAll(
    conn: *dbus.DBusConnection,
    entry: *const Entry,
    interface: [*:0]const u8,
) !?*dbus.DBusMessage {
    const message = dbus.dbus_message_new_method_call(
        entry.serviceName().ptr,
        entry.objectPath().ptr,
        properties,
        "GetAll",
    ) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var iter: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &iter);
    try appendString(&iter, interface);
    const reply = dbus.dbus_connection_send_with_reply_and_block(
        conn,
        message,
        call_milliseconds,
        null,
    ) orelse return null;
    if (!validPropertyReply(reply)) {
        dbus.dbus_message_unref(reply);
        return null;
    }
    return reply;
}

fn validPropertyReply(reply: *dbus.DBusMessage) bool {
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN or
        dbus.dbus_message_has_signature(reply, "a{sv}") == 0)
    {
        return false;
    }
    var root: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &root) == 0) return false;
    var entries: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&root, &entries);
    // An empty KDE dictionary may mean only the freedesktop interface exists.
    return dbus.dbus_message_iter_get_arg_type(&entries) == dbus.DBUS_TYPE_DICT_ENTRY;
}

fn readString(iter: *dbus.DBusMessageIter) []const u8 {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_STRING and
        dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_OBJECT_PATH) return "";
    var pointer: [*c]const u8 = null;
    // zig-audit: acknowledge ptr_cast
    // reason: Signature-checked string/path read writes a borrowed C string pointer.
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    return if (pointer != null) std.mem.span(pointer) else "";
}

fn parseProperties(entry: *Entry, allocator: std.mem.Allocator, reply: *dbus.DBusMessage) !void {
    if (!validPropertyReply(reply)) return;
    var root: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(reply, &root) == 0) return;
    var attributes: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&root, &attributes);
    for (0..80) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&attributes) != dbus.DBUS_TYPE_DICT_ENTRY) break;
        var attribute: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&attributes, &attribute);
        const name = readString(&attribute);
        if (dbus.dbus_message_iter_next(&attribute) != 0 and
            dbus.dbus_message_iter_get_arg_type(&attribute) == dbus.DBUS_TYPE_VARIANT)
        {
            var value: dbus.DBusMessageIter = undefined;
            dbus.dbus_message_iter_recurse(&attribute, &value);
            try applyProperty(entry, allocator, name, &value);
        }
        if (dbus.dbus_message_iter_next(&attributes) == 0) break;
    }
}

fn applyProperty(
    entry: *Entry,
    allocator: std.mem.Allocator,
    name: []const u8,
    value: *dbus.DBusMessageIter,
) !void {
    if (std.mem.eql(u8, name, "IconName") or std.mem.eql(u8, name, "AttentionIconName")) {
        if (entry.icon_len == 0) entry.copyIcon(readString(value));
    } else if (std.mem.eql(u8, name, "Title")) {
        entry.copyTitle(readString(value));
    } else if (std.mem.eql(u8, name, "Status")) {
        entry.passive = std.mem.eql(u8, readString(value), "Passive");
    } else if (std.mem.eql(u8, name, "ItemIsMenu")) {
        if (dbus.dbus_message_iter_get_arg_type(value) != dbus.DBUS_TYPE_BOOLEAN) return;
        var flag: dbus.dbus_bool_t = 0;
        dbus.dbus_message_iter_get_basic(value, &flag);
        entry.item_is_menu = flag != 0;
    } else if (std.mem.eql(u8, name, "Menu")) {
        entry.copyMenu(readString(value));
    } else if (std.mem.eql(u8, name, "IconPixmap") or
        std.mem.eql(u8, name, "AttentionIconPixmap"))
    {
        if (entry.pixels == null) try readPixmap(entry, allocator, value);
    }
}

// The byte slice borrows the reply message, never retained by Entry.
const Pixmap = struct {
    width: u16,
    height: u16,
    bytes: []const u8,

    fn distance(self: Pixmap) usize {
        return @as(usize, @abs(@as(i32, self.width) - 22)) +
            @abs(@as(i32, self.height) - 22);
    }
};

fn readImage(iter: *dbus.DBusMessageIter) ?Pixmap {
    var image: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(iter, &image);
    if (dbus.dbus_message_iter_get_arg_type(&image) != dbus.DBUS_TYPE_INT32) return null;
    var w: i32 = 0;
    var h: i32 = 0;
    dbus.dbus_message_iter_get_basic(&image, &w);
    if (dbus.dbus_message_iter_next(&image) == 0 or
        dbus.dbus_message_iter_get_arg_type(&image) != dbus.DBUS_TYPE_INT32) return null;
    dbus.dbus_message_iter_get_basic(&image, &h);
    if (w <= 0 or h <= 0 or w > pixel_side_limit or h > pixel_side_limit) return null;
    if (dbus.dbus_message_iter_next(&image) == 0 or
        dbus.dbus_message_iter_get_arg_type(&image) != dbus.DBUS_TYPE_ARRAY or
        dbus.dbus_message_iter_get_element_type(&image) != dbus.DBUS_TYPE_BYTE or
        dbus.dbus_message_iter_has_next(&image) != 0) return null;

    const count: usize = @as(usize, @intCast(w)) * @as(usize, @intCast(h));
    std.debug.assert(count * 4 <= max_pixmap_bytes);
    var data: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(&image, &data);
    if (dbus.dbus_message_iter_get_arg_type(&data) != dbus.DBUS_TYPE_BYTE) return null;
    var bytes: [*c]const u8 = null;
    var length: c_int = 0;
    // libdbus returns the borrowed array through this pointer-to-pointer.
    // zig-audit: acknowledge ptr_cast
    // reason: The checked byte-array element iterator returns a borrowed data pointer.
    dbus.dbus_message_iter_get_fixed_array(&data, @ptrCast(&bytes), &length);
    if (bytes == null or length != count * 4) return null;
    return .{ .width = @intCast(w), .height = @intCast(h), .bytes = bytes[0 .. count * 4] };
}

fn readPixmap(entry: *Entry, allocator: std.mem.Allocator, iter: *dbus.DBusMessageIter) !void {
    if (dbus.dbus_message_iter_get_arg_type(iter) != dbus.DBUS_TYPE_ARRAY or
        dbus.dbus_message_iter_get_element_type(iter) != dbus.DBUS_TYPE_STRUCT) return;
    var images: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(iter, &images);
    var best: ?Pixmap = null;
    for (0..16) |_| {
        if (dbus.dbus_message_iter_get_arg_type(&images) != dbus.DBUS_TYPE_STRUCT) break;
        if (readImage(&images)) |candidate| {
            if (best == null or candidate.distance() < best.?.distance()) best = candidate;
        }
        if (dbus.dbus_message_iter_next(&images) == 0) break;
    }
    const chosen = best orelse return;
    // Allocate only once, after validating and ranking every admitted candidate.
    const pixels = try allocator.alloc(u32, chosen.bytes.len / 4);
    for (pixels, 0..) |*pixel, index| {
        pixel.* = std.mem.readInt(u32, chosen.bytes[index * 4 ..][0..4], .big);
    }
    if (entry.pixels) |old| allocator.free(old);
    entry.pixels = pixels;
    entry.width = chosen.width;
    entry.height = chosen.height;
}

fn fetch(
    self: *Entry,
    conn: *dbus.DBusConnection,
    allocator: std.mem.Allocator,
    canceled: ?*const std.atomic.Value(bool),
) !void {
    const reply = try getAll(conn, self, kde_item) orelse blk: {
        if (canceled) |stop| if (stop.load(.acquire)) return;
        self.interface = fd_item;
        break :blk try getAll(conn, self, fd_item) orelse return;
    };
    defer dbus.dbus_message_unref(reply);
    try parseProperties(self, allocator, reply);
}

test "item identifiers are parsed strictly and cheaply" {
    var entry: Entry = .{};
    try entry.parseIdentifier("org.kde.StatusNotifierItem-55-1/StatusNotifierItem");
    try std.testing.expectEqualStrings("org.kde.StatusNotifierItem-55-1", entry.serviceName());
    try std.testing.expectEqualStrings("/StatusNotifierItem", entry.objectPath());
    try std.testing.expectError(
        error.TrayItemIdentityInvalid,
        entry.parseIdentifier("not-an-item"),
    );
    try std.testing.expectError(
        error.TrayItemIdentityInvalid,
        entry.parseIdentifier("anything/../../escape"),
    );
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
    try std.testing.expectEqualStrings(
        if (fd_mode) "org.freedesktop.StatusNotifierItem" else "org.kde.StatusNotifierItem",
        std.mem.span(item.interface),
    );
    try std.testing.expectEqualStrings("Wayspot Tray Test", item.titleText());
    try std.testing.expectEqual(@as(u16, 22), item.width);
    try std.testing.expectEqual(@as(u16, 22), item.height);
    const expected_argb: u32 = 0xff23d273;
    try std.testing.expectEqual(expected_argb, item.pixels.?[11 * 22 + 6]);
    try snapshot.activate(0, 495, 23, 1);
}

test "identity validates full D-Bus grammar and preserves the previous entry" {
    var entry: Entry = .{};
    try entry.parseIdentifier("org.example.LongName/Long_Path");
    for ([_][]const u8{
        "bad/Valid",
        "org..example/Valid",
        "org.1example/Valid",
        "org.example/Bad//Path",
        "org.example/Trailing/",
        ":1.23/Bad-Path",
    }) |identity| {
        try std.testing.expectError(error.TrayItemIdentityInvalid, entry.parseIdentifier(identity));
        try std.testing.expectEqualStrings("org.example.LongName", entry.serviceName());
        try std.testing.expectEqualStrings("/Long_Path", entry.objectPath());
    }
    try entry.parseIdentifier(":1.2/A");
    try std.testing.expectEqualStrings(":1.2", entry.serviceName());
    try std.testing.expectEqualStrings("/A", entry.objectPath());
}

test "menu paths cannot publish invalid D-Bus paths" {
    var entry: Entry = .{};
    entry.copyMenu("/bad//path");
    try std.testing.expectEqual(@as(usize, 0), entry.menu_len);
    entry.copyMenu("/Valid_Menu");
    try std.testing.expectEqualStrings("/Valid_Menu", entry.menuPath());
    entry.copyMenu("/invalid-path");
    try std.testing.expectEqualStrings("/Valid_Menu", entry.menuPath());
}

fn appendImageTest(
    images: *dbus.DBusMessageIter,
    w: i32,
    h: i32,
    byte_count: usize,
    argb: [4]u8,
) !void {
    var image: dbus.DBusMessageIter = undefined;
    try std.testing.expect(
        dbus.dbus_message_iter_open_container(images, dbus.DBUS_TYPE_STRUCT, null, &image) != 0,
    );
    try std.testing.expect(dbus.dbus_message_iter_append_basic(
        &image,
        dbus.DBUS_TYPE_INT32,
        &w,
    ) != 0);
    try std.testing.expect(dbus.dbus_message_iter_append_basic(
        &image,
        dbus.DBUS_TYPE_INT32,
        &h,
    ) != 0);
    var data: dbus.DBusMessageIter = undefined;
    try std.testing.expect(
        dbus.dbus_message_iter_open_container(&image, dbus.DBUS_TYPE_ARRAY, "y", &data) != 0,
    );
    for (0..byte_count) |index| {
        const byte = argb[index % argb.len];
        try std.testing.expect(
            dbus.dbus_message_iter_append_basic(&data, dbus.DBUS_TYPE_BYTE, &byte) != 0,
        );
    }
    try std.testing.expect(dbus.dbus_message_iter_close_container(&image, &data) != 0);
    try std.testing.expect(dbus.dbus_message_iter_close_container(images, &image) != 0);
}

test "pixmap decoding chooses one exact bounded image before allocating" {
    const message = dbus.dbus_message_new(dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN) orelse
        return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var root: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &root);
    var images: dbus.DBusMessageIter = undefined;
    try std.testing.expect(
        dbus.dbus_message_iter_open_container(&root, dbus.DBUS_TYPE_ARRAY, "(iiay)", &images) != 0,
    );
    try appendImageTest(&images, -1, 22, 4, .{ 1, 2, 3, 4 });
    try appendImageTest(&images, 129, 1, 4, .{ 1, 2, 3, 4 });
    try appendImageTest(&images, 22, 22, 3, .{ 1, 2, 3, 4 });
    try appendImageTest(&images, 16, 16, 16 * 16 * 4, .{ 255, 1, 2, 3 });
    try appendImageTest(&images, 22, 22, 22 * 22 * 4, .{ 128, 35, 210, 115 });
    try appendImageTest(&images, 22, 22, 22 * 22 * 4, .{ 255, 4, 5, 6 });
    try std.testing.expect(dbus.dbus_message_iter_close_container(&root, &images) != 0);

    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const allocator = failing.allocator();
    var entry: Entry = .{};
    defer entry.deinit(allocator);
    try std.testing.expect(dbus.dbus_message_iter_init(message, &root) != 0);
    try readPixmap(&entry, allocator, &root);
    try std.testing.expectEqual(@as(usize, 1), failing.allocations);
    try std.testing.expectEqual(@as(u16, 22), entry.width);
    try std.testing.expectEqual(@as(u16, 22), entry.height);
    const pixels = entry.pixels orelse return error.TestExpectedPixmap;
    try std.testing.expectEqual(@as(usize, 22 * 22), pixels.len);
    for (pixels) |pixel| try std.testing.expectEqual(@as(u32, 0x8023d273), pixel);

    // A replacement that cannot allocate must not retire the previous image.
    try std.testing.expect(dbus.dbus_message_iter_init(message, &root) != 0);
    try std.testing.expectError(error.OutOfMemory, readPixmap(&entry, allocator, &root));
    try std.testing.expectEqual(pixels.ptr, entry.pixels.?.ptr);
    try std.testing.expectEqual(@as(u16, 22), entry.width);
}

test "property replies require a nonempty exact dictionary" {
    const message = dbus.dbus_message_new(dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN) orelse
        return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    try std.testing.expect(!validPropertyReply(message));
    var root: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &root);
    var dictionary: dbus.DBusMessageIter = undefined;
    try std.testing.expect(
        dbus.dbus_message_iter_open_container(
            &root,
            dbus.DBUS_TYPE_ARRAY,
            "{sv}",
            &dictionary,
        ) != 0,
    );
    try std.testing.expect(dbus.dbus_message_iter_close_container(&root, &dictionary) != 0);
    try std.testing.expect(!validPropertyReply(message));
    try appendString(&root, "extra");
    try std.testing.expect(!validPropertyReply(message));
}
