//! A disposable native Wayland SNI/DBusMenu client. The fixed colors and
//! receipts witness real method delivery, not an imitation of Wayspot's UI.
//! Explicit private fixture only; no input injection or installed service.
const std = @import("std");
const dbus = @import("dbus_c");
const Connection = @import("wayland-client").Connection;
const present = @import("wayland-present");
const protocols = @import("wayland-protocols");
const wl = protocols.wl;
const xdg = protocols.xdg;
const Iter = dbus.DBusMessageIter;
const Message = dbus.DBusMessage;
const Bus = dbus.DBusConnection;
const service = "org.kde.StatusNotifierItem-4242-1";
const item_path = "/StatusNotifierItem";
const menu_path = "/TrayMenu";
const item_iface = "org.kde.StatusNotifierItem";
const menu_iface = "com.canonical.dbusmenu";
const properties = "org.freedesktop.DBus.Properties";
const icon_side = 22;
const initial_color = 0x203040;

// zig-audit: acknowledge anytype
// reason: The fixed protocol writer accepts only the typed scalar values at its local call sites.
fn put(iter: *Iter, kind: c_int, value: anytype) !void {
    // zig-audit: acknowledge ptr_cast
    // reason: libdbus copies the exact typed scalar or string-pointer value at this call.
    if (dbus.dbus_message_iter_append_basic(iter, kind, @ptrCast(&value)) == 0) return error.DbusAppendFailed;
}

fn string(iter: *Iter, value: [*:0]const u8) !void {
    try put(iter, dbus.DBUS_TYPE_STRING, value);
}

fn open(iter: *Iter, kind: c_int, signature: ?[*:0]const u8) !Iter {
    var child: Iter = undefined;
    if (dbus.dbus_message_iter_open_container(iter, kind, signature, &child) == 0) return error.DbusContainerFailed;
    return child;
}

fn close(iter: *Iter, child: *Iter) !void {
    if (dbus.dbus_message_iter_close_container(iter, child) == 0) return error.DbusContainerFailed;
}

// zig-audit: acknowledge anytype
// reason: Typed scalar properties share the same bounded D-Bus dictionary encoding.
fn property(iter: *Iter, key: [*:0]const u8, signature: [*:0]const u8, kind: c_int, value: anytype) !void {
    var entry = try open(iter, dbus.DBUS_TYPE_DICT_ENTRY, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &entry);
    try string(&entry, key);
    var variant = try open(&entry, dbus.DBUS_TYPE_VARIANT, signature);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&entry, &variant);
    try put(&variant, kind, value);
    try close(&entry, &variant);
    try close(iter, &entry);
}

fn icon(iter: *Iter) !void {
    var entry = try open(iter, dbus.DBUS_TYPE_DICT_ENTRY, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &entry);
    try string(&entry, "IconPixmap");
    var variant = try open(&entry, dbus.DBUS_TYPE_VARIANT, "a(iiay)");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&entry, &variant);
    var images = try open(&variant, dbus.DBUS_TYPE_ARRAY, "(iiay)");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&variant, &images);
    var image = try open(&images, dbus.DBUS_TYPE_STRUCT, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&images, &image);
    try put(&image, dbus.DBUS_TYPE_INT32, @as(i32, icon_side));
    try put(&image, dbus.DBUS_TYPE_INT32, @as(i32, icon_side));
    var bytes = try open(&image, dbus.DBUS_TYPE_ARRAY, "y");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&image, &bytes);
    var pixels: [icon_side * icon_side * 4]u8 = undefined;
    for (0..icon_side) |y| {
        for (0..icon_side) |x| {
            const color: [4]u8 = if (x >= 7 and x <= 14 and y >= 10 and y <= 11) .{ 255, 240, 244, 250 } else if (x > 2 and x < 19 and y > 2 and y < 19) .{ 255, 35, 210, 115 } else .{ 255, 18, 30, 25 };
            @memcpy(pixels[(y * icon_side + x) * 4 ..][0..4], &color);
        }
    }
    const data: [*]const u8 = &pixels;
    // zig-audit: acknowledge ptr_cast
    // reason: libdbus expects a pointer to the borrowed fixed-array data pointer.
    if (dbus.dbus_message_iter_append_fixed_array(&bytes, dbus.DBUS_TYPE_BYTE, @ptrCast(&data), pixels.len) == 0) return error.DbusAppendFailed;
    try close(&image, &bytes);
    try close(&images, &image);
    try close(&variant, &images);
    try close(&entry, &variant);
    try close(iter, &entry);
}

fn itemProperties(iter: *Iter, has_menu: bool, supported: bool) !void {
    var dict = try open(iter, dbus.DBUS_TYPE_ARRAY, "{sv}");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &dict);
    if (supported) {
        try property(&dict, "Id", "s", dbus.DBUS_TYPE_STRING, @as([*:0]const u8, "wayspot-canary"));
        try property(&dict, "Title", "s", dbus.DBUS_TYPE_STRING, @as([*:0]const u8, "Wayspot Tray Canary"));
        try property(&dict, "Status", "s", dbus.DBUS_TYPE_STRING, @as([*:0]const u8, "Active"));
        try property(&dict, "IconName", "s", dbus.DBUS_TYPE_STRING, @as([*:0]const u8, ""));
        try property(&dict, "ItemIsMenu", "b", dbus.DBUS_TYPE_BOOLEAN, @as(dbus.dbus_bool_t, 0));
        try property(&dict, "Menu", "o", dbus.DBUS_TYPE_OBJECT_PATH, @as([*:0]const u8, if (has_menu) menu_path else "/"));
        try icon(&dict);
    }
    try close(iter, &dict);
}

fn menuRow(children: *Iter, id: i32, label: [*:0]const u8, enabled: bool, submenu: bool) !void {
    var variant = try open(children, dbus.DBUS_TYPE_VARIANT, "(ia{sv}av)");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(children, &variant);
    var row = try open(&variant, dbus.DBUS_TYPE_STRUCT, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&variant, &row);
    try put(&row, dbus.DBUS_TYPE_INT32, id);
    var dict = try open(&row, dbus.DBUS_TYPE_ARRAY, "{sv}");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&row, &dict);
    try property(&dict, "label", "s", dbus.DBUS_TYPE_STRING, label);
    try property(&dict, "enabled", "b", dbus.DBUS_TYPE_BOOLEAN, @as(dbus.dbus_bool_t, @intFromBool(enabled)));
    if (submenu) try property(&dict, "children-display", "s", dbus.DBUS_TYPE_STRING, @as([*:0]const u8, "submenu"));
    try close(&row, &dict);
    var empty = try open(&row, dbus.DBUS_TYPE_ARRAY, "v");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&row, &empty);
    try close(&row, &empty);
    try close(&variant, &row);
    try close(children, &variant);
}

fn menuLayout(iter: *Iter, parent: i32) !void {
    try put(iter, dbus.DBUS_TYPE_UINT32, @as(u32, 1));
    var root = try open(iter, dbus.DBUS_TYPE_STRUCT, null);
    errdefer dbus.dbus_message_iter_abandon_container_if_open(iter, &root);
    try put(&root, dbus.DBUS_TYPE_INT32, parent);
    var dict = try open(&root, dbus.DBUS_TYPE_ARRAY, "{sv}");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&root, &dict);
    try close(&root, &dict);
    var children = try open(&root, dbus.DBUS_TYPE_ARRAY, "v");
    errdefer dbus.dbus_message_iter_abandon_container_if_open(&root, &children);
    if (parent == 0) {
        try menuRow(&children, 7, "Open Canary", true, false);
        try menuRow(&children, 8, "Disabled", false, false);
        try menuRow(&children, 9, "More", true, true);
    } else if (parent == 9) {
        try menuRow(&children, 10, "Nested Action", true, false);
    }
    try close(&root, &children);
    try close(iter, &root);
}

fn equal(value: [*c]const u8, expected: []const u8) bool {
    return value != null and std.mem.eql(u8, std.mem.span(value), expected);
}

fn readInt(iter: *Iter) i32 {
    var value: i32 = 0;
    dbus.dbus_message_iter_get_basic(iter, &value);
    return value;
}

fn readString(iter: *Iter) [*c]const u8 {
    var value: [*c]const u8 = null;
    // zig-audit: acknowledge ptr_cast
    // reason: This signature-checked string read returns a borrowed C string pointer.
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&value));
    return value;
}

const Action = enum { Activate, SecondaryActivate, ContextMenu, Menu };
const State = struct {
    io: std.Io,
    has_menu: bool,
    compositor: ?wl.Compositor = null,
    shm: ?wl.Shm = null,
    shell: ?xdg.WmBase = null,
    width: u32 = 320,
    height: u32 = 180,
    configured: bool = false,
    running: bool = true,
    dirty: bool = true,
    color: u32 = initial_color,
    sequence: u32 = 0,

    // zig-audit: acknowledge anytype
    // reason: Fixed-format JSON receipts carry only local action names and numeric witnesses.
    fn emit(self: *const State, comptime fmt: []const u8, args: anytype) !void {
        var storage: [256]u8 = undefined;
        const line = try std.fmt.bufPrint(&storage, fmt ++ "\n", args);
        try std.Io.File.stdout().writeStreamingAll(self.io, line);
    }

    fn action(self: *State, kind: Action, x: i32, y: i32, id: i32) !void {
        self.sequence = try std.math.add(u32, self.sequence, 1);
        self.color = switch (kind) {
            .Activate => 0x23d273,
            .SecondaryActivate => 0xa040d0,
            .ContextMenu => 0xf09538,
            .Menu => if (id == 7) 0x356bff else 0x00a0c0,
        };
        self.dirty = true;
        try self.emit("{{\"event\":\"action\",\"method\":\"{s}\",\"x\":{d},\"y\":{d},\"id\":{d},\"sequence\":{d}}}", .{ @tagName(kind), x, y, id, self.sequence });
    }

    fn registry(self: *State, conn: *Connection, object: wl.Registry, event: wl.Registry.Event) !void {
        const global = switch (event) {
            .global => |g| g,
            .global_remove => return,
        };
        if (std.mem.eql(u8, global.interface, "wl_compositor")) {
            self.compositor = try object.bind(&conn.session, global.name, wl.Compositor, @min(global.version, 4));
        } else if (std.mem.eql(u8, global.interface, "wl_shm")) {
            self.shm = try object.bind(&conn.session, global.name, wl.Shm, 1);
        } else if (std.mem.eql(u8, global.interface, "xdg_wm_base")) {
            self.shell = try object.bind(&conn.session, global.name, xdg.WmBase, 1);
        }
    }

    fn ping(_: void, conn: *Connection, base: xdg.WmBase, event: xdg.WmBase.Event) !void {
        switch (event) {
            .ping => |value| try base.pong(&conn.session, value.serial),
        }
    }

    fn top(self: *State, _: *Connection, _: xdg.Toplevel, event: xdg.Toplevel.Event) !void {
        switch (event) {
            .configure => |value| {
                if (value.width > 2048 or value.height > 2048 or value.width < 0 or value.height < 0) return error.CanaryExtent;
                if (value.width != 0) self.width = @intCast(value.width);
                if (value.height != 0) self.height = @intCast(value.height);
            },
            .close => self.running = false,
            else => {},
        }
    }

    fn configure(self: *State, conn: *Connection, surface: xdg.Surface, event: xdg.Surface.Event) !void {
        switch (event) {
            .configure => |value| try surface.ackConfigure(&conn.session, value.serial),
        }
        self.configured = true;
        self.dirty = true;
    }

    fn paint(self: *State, pool: *present.BufferPool, presenter: *present.Presenter) !void {
        if (!self.configured or !self.dirty or !presenter.ready()) return;
        // Bound held buffers across *all* extents, not just the current one.
        var held: usize = 0;
        for (pool.buffers.items) |buffer| {
            if (buffer.state == .busy) held += 1;
        }
        if (held >= 3) return;
        const buffer = (try pool.acquire(self.width, self.height, .xrgb8888)) orelse return;
        const memory = buffer.pixels();
        for (0..self.height) |y| {
            // zig-audit: acknowledge ptr_cast
            // reason: The presenter owns this packed 32-bit XRGB SHM row; alignment 1 is explicit.
            const row: []align(1) u32 = @ptrCast(memory[y * buffer.stride ..][0 .. self.width * 4]);
            @memset(row, self.color);
        }
        try presenter.present(buffer, .{});
        self.dirty = false;
        try self.emit("{{\"event\":\"committed\",\"sequence\":{d},\"rgb\":{d}}}", .{ self.sequence, self.color });
    }
};

fn send(bus: *Bus, reply: *Message) !void {
    if (dbus.dbus_connection_send(bus, reply, null) == 0) return error.DbusSendFailed;
}

fn matches(message: *Message, interface: [*:0]const u8, method: [*:0]const u8, signature: [*:0]const u8) bool {
    return dbus.dbus_message_is_method_call(message, interface, method) != 0 and dbus.dbus_message_has_signature(message, signature) != 0;
}

fn respond(state: *State, bus: *Bus, message: *Message) !void {
    if (dbus.dbus_message_get_type(message) != dbus.DBUS_MESSAGE_TYPE_METHOD_CALL) return;
    const path = dbus.dbus_message_get_path(message);
    const reply = dbus.dbus_message_new_method_return(message) orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(reply);
    var output: Iter = undefined;
    dbus.dbus_message_iter_init_append(reply, &output);
    var input: Iter = undefined;
    if (equal(path, item_path) and matches(message, properties, "GetAll", "s")) {
        if (dbus.dbus_message_iter_init(message, &input) == 0) return error.DbusArguments;
        try itemProperties(&output, state.has_menu, equal(readString(&input), item_iface));
        try state.emit("{{\"event\":\"fetch\"}}", .{});
    } else if (equal(path, item_path) and dbus.dbus_message_has_signature(message, "ii") != 0 and dbus.dbus_message_has_interface(message, item_iface) != 0) {
        const member = dbus.dbus_message_get_member(message);
        const kind: Action = if (equal(member, "Activate")) .Activate else if (equal(member, "SecondaryActivate")) .SecondaryActivate else if (equal(member, "ContextMenu")) .ContextMenu else return error.UnexpectedCanaryMethod;
        if (dbus.dbus_message_iter_init(message, &input) == 0) return error.DbusArguments;
        const x = readInt(&input);
        if (dbus.dbus_message_iter_next(&input) == 0) return error.DbusArguments;
        try state.action(kind, x, readInt(&input), 0);
    } else if (state.has_menu and equal(path, menu_path) and matches(message, menu_iface, "GetLayout", "iias")) {
        if (dbus.dbus_message_iter_init(message, &input) == 0) return error.DbusArguments;
        const parent = readInt(&input);
        if (parent != 0 and parent != 9) return error.UnexpectedMenuParent;
        try menuLayout(&output, parent);
        try state.emit("{{\"event\":\"layout\",\"parent\":{d}}}", .{parent});
    } else if (state.has_menu and equal(path, menu_path) and matches(message, menu_iface, "Event", "isvu")) {
        if (dbus.dbus_message_iter_init(message, &input) == 0) return error.DbusArguments;
        const id = readInt(&input);
        if (dbus.dbus_message_iter_next(&input) == 0) return error.DbusArguments;
        if ((id != 7 and id != 10) or !equal(readString(&input), "clicked")) return error.UnexpectedMenuAction;
        try state.action(.Menu, 0, 0, id);
    } else {
        const failure = dbus.dbus_message_new_error(message, "org.freedesktop.DBus.Error.UnknownMethod", "Unsupported canary method") orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(failure);
        return send(bus, failure);
    }
    try send(bus, reply);
}

fn register(bus: *Bus) !void {
    if (dbus.dbus_bus_request_name(bus, service, dbus.DBUS_NAME_FLAG_DO_NOT_QUEUE, null) != dbus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) return error.CanaryNameUnavailable;
    const request = dbus.dbus_message_new_method_call("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(request);
    var iter: Iter = undefined;
    dbus.dbus_message_iter_init_append(request, &iter);
    try string(&iter, service);
    const reply = dbus.dbus_connection_send_with_reply_and_block(bus, request, 1000, null) orelse return error.CanaryRegistrationFailed;
    defer dbus.dbus_message_unref(reply);
    if (dbus.dbus_message_get_type(reply) != dbus.DBUS_MESSAGE_TYPE_METHOD_RETURN) return error.CanaryRegistrationFailed;
}

/// Run only inside an explicitly provisioned private fixture.
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2 or (!std.mem.eql(u8, args[1], "menu") and !std.mem.eql(u8, args[1], "context"))) return error.UsageCanaryMenuOrContext;
    const env = init.environ_map;
    const runtime = env.get("XDG_RUNTIME_DIR") orelse return error.PrivateRuntimeRequired;
    const expected = env.get("WAYSPOT_CANARY_RUNTIME") orelse return error.PrivateRuntimeRequired;
    if (!std.mem.eql(u8, runtime, expected) or !std.fs.path.isAbsolute(runtime) or std.mem.startsWith(u8, runtime, "/run/user/") or env.get("WAYLAND_SOCKET") != null or !std.mem.eql(u8, env.get("WAYLAND_DISPLAY") orelse "", "wayland-0")) return error.PrivateRuntimeRequired;
    const parent = std.fs.path.dirname(runtime) orelse return error.PrivateRuntimeRequired;
    const address = try std.fmt.allocPrint(init.arena.allocator(), "unix:path={s}/bus", .{parent});
    if (!std.mem.eql(u8, env.get("DBUS_SESSION_BUS_ADDRESS") orelse "", address)) return error.PrivateBusRequired;
    var state: State = .{ .io = init.io, .has_menu = std.mem.eql(u8, args[1], "menu") };
    var conn = try Connection.connect(init.gpa, init.io, env);
    defer conn.deinit();
    const s = &conn.session;
    const registry = try (wl.Display{ .id = .display }).getRegistry(s);
    try conn.setListener(registry, &state, State.registry);
    try conn.roundtrip();
    const shell = state.shell orelse return error.NoXdgShell;
    try conn.setListener(shell, {}, State.ping);
    const shm = try present.Shm.create(init.gpa, &conn, state.shm orelse return error.NoShm);
    defer shm.destroy();
    try conn.roundtrip();
    const pool = try present.BufferPool.create(init.gpa, &conn, shm, .{});
    defer pool.destroy();
    const surface = try (state.compositor orelse return error.NoCompositor).createSurface(s);
    const role = try shell.getXdgSurface(s, surface);
    const top = try role.getToplevel(s);
    try conn.setListener(role, &state, State.configure);
    try conn.setListener(top, &state, State.top);
    try top.setTitle(s, "Wayspot Tray Canary");
    try top.setAppId(s, "wayspot.tray-canary");
    try surface.commit(s);
    const presenter = try present.Presenter.create(init.gpa, &conn, surface);
    defer presenter.destroy();
    const bus = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse return error.CanaryBusUnavailable;
    defer {
        dbus.dbus_connection_close(bus);
        dbus.dbus_connection_unref(bus);
    }
    dbus.dbus_connection_set_exit_on_disconnect(bus, 0);
    dbus.dbus_connection_set_max_message_size(bus, 128 * 1024);
    dbus.dbus_connection_set_max_message_unix_fds(bus, 0);
    var bus_fd: c_int = -1;
    if (dbus.dbus_connection_get_unix_fd(bus, &bus_fd) == 0 or bus_fd < 0) return error.CanaryBusSocket;
    try register(bus);
    try state.emit("{{\"event\":\"registered\"}}", .{});
    while (state.running) {
        // zig-audit: acknowledge discard
        // reason: Callbacks own the configure facts; dispatch count is not a state transition.
        _ = try conn.dispatchPending();
        if (!state.running) break;
        if (dbus.dbus_connection_read_write(bus, 0) == 0) return error.CanaryBusDisconnected;
        var more = true;
        for (0..32) |_| {
            const message = dbus.dbus_connection_pop_message(bus) orelse {
                more = false;
                break;
            };
            defer dbus.dbus_message_unref(message);
            try respond(&state, bus, message);
        }
        try state.paint(pool, presenter);
        try conn.flush();
        var fds = [_]std.posix.pollfd{
            .{ .fd = conn.fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = bus_fd, .events = std.posix.POLL.IN | @as(i16, if (dbus.dbus_connection_has_messages_to_send(bus) != 0) std.posix.POLL.OUT else 0), .revents = 0 },
            .{ .fd = 0, .events = std.posix.POLL.IN | std.posix.POLL.HUP, .revents = 0 },
        };
        // zig-audit: acknowledge discard
        // reason: Readiness is consumed from revents, not the count of ready descriptors.
        _ = try std.posix.poll(&fds, if (more) 0 else -1);
        if (fds[0].revents != 0) try conn.read();
        if (fds[2].revents != 0) break; // Closing the control pipe retires the exact canary.
    }
    try top.destroy(s);
    try role.destroy(s);
    try surface.destroy(s);
    try conn.flush();
    try state.emit("{{\"event\":\"stopped\"}}", .{});
}
