//! One local Wayland seat, with protocol-owned focus and bounded event storage.
//! No key injection, SDL events, polling timer or background thread.
const std = @import("std");
const linux = std.os.linux;
const Connection = @import("wayland-client").Connection;
const wl = @import("wayland-protocols").wl;
const wire = @import("wayland-wire");
const Cursor = @import("native_cursor.zig");
const zwp = @import("wayland-protocols").zwp;
const xkb = @import("xkb_c");
const Self = @This();

const max_seats = 8;
const max_keys = 768;
const max_keymap_bytes = 1024 * 1024;
pub const max_events = 128;
pub const Point = struct { x: f64, y: f64 };
pub const Modifiers = struct { shift: bool = false, control: bool = false, alt: bool = false, logo: bool = false };
pub const Key = struct {
    code: u32,
    symbol: u32,
    pressed: bool,
    repeatable: bool,
    repeated: bool = false,
    compose_consumed: bool = false,
    modifiers: Modifiers,
    text: [64]u8 = @splat(0),
    text_len: u8 = 0,

    pub fn utf8(self: *const Key) []const u8 {
        return self.text[0..self.text_len];
    }
};
pub const ImeText = struct {
    bytes: [256]u8 = undefined,
    len: u16 = 0,

    pub fn slice(self: *const ImeText) []const u8 {
        return self.bytes[0..self.len];
    }

    fn set(self: *ImeText, text: ?[:0]const u8) !void {
        const value = text orelse "";
        if (value.len > self.bytes.len or !std.unicode.utf8ValidateSlice(value)) return error.NativeImeText;
        @memcpy(self.bytes[0..value.len], value);
        self.len = @intCast(value.len);
    }

    fn boundary(self: *const ImeText, offset: i32) bool {
        if (offset < 0 or offset > self.len) return false;
        return offset == self.len or self.bytes[@intCast(offset)] & 0xc0 != 0x80;
    }
};

/// One text-input-v3 done transaction, not individual string callbacks.
/// The future picker adapter applies deletion, commit, then preedit; only
/// serial_matches allows a new surrounding-state update to be sent.
pub const ImeBatch = struct {
    preedit: ImeText = .{},
    commit: ImeText = .{},
    cursor_begin: i32 = 0,
    cursor_end: i32 = 0,
    delete_before: u32 = 0,
    delete_after: u32 = 0,
    serial_matches: bool = false,
};

pub const Event = struct {
    surface: wire.ObjectId,
    value: union(enum) {
        keyboard_enter,
        keyboard_leave,
        key: Key,
        ime: ImeBatch,
        ime_cancel,
        pointer_enter: Point,
        pointer_leave,
        motion: Point,
        button: struct { code: u32, pressed: bool, at: Point },
        scroll: i8,
    },
};
const Seat = struct { global: u32, object: wl.Seat, selected: bool = false, caps: wl.Seat.Capability = .{} };
const Target = struct { id: wire.ObjectId, keyboard: bool };
const Repeat = struct { code: u32, deadline: std.Io.Timestamp, interval: std.Io.Duration };
const Masks = struct { depressed: u32 = 0, latched: u32 = 0, locked: u32 = 0, group: u32 = 0 };

seats: [max_seats]?Seat = @splat(null),
selected: ?wl.Seat = null,
keyboard: ?wl.Keyboard = null,
pointer: ?wl.Pointer = null,
targets: [2]?Target = @splat(null),
keyboard_focus: ?wire.ObjectId = null,
pointer_focus: ?wire.ObjectId = null,
keys: std.StaticBitSet(max_keys) = .empty,
emitted: std.StaticBitSet(max_keys) = .empty,
buttons: std.StaticBitSet(16) = .empty,
point: Point = .{ .x = 0, .y = 0 },
keymap: ?*xkb.struct_xkb_keymap = null,
state: ?*xkb.struct_xkb_state = null,
masks: Masks = .{},
repeat_rate: i32 = 0,
repeat_delay: i32 = 0,
repeat: ?Repeat = null,
compose: ?*xkb.struct_xkb_compose_state = null,
compose_locale: ?[:0]const u8 = null,
cursor: Cursor = .{},
ime_manager: ?zwp.TextInputManagerV3 = null,
ime_global: ?u32 = null,
ime_object: ?zwp.TextInputV3 = null,
ime_focus: ?wire.ObjectId = null,
ime_serial: u32 = 0,
ime_pending: ImeBatch = .{},
ime_preedit: bool = false,
axis_units: i64 = 0,
axis_distance: f64 = 0,
axis_steps: ?i64 = null,
axis_highres: ?i64 = null,
queue: [max_events]Event = undefined,
count: usize = 0,

pub fn deinit(self: *Self, conn: *Connection) void {
    self.cursor.deinit(conn);
    self.clearKeymap();
    if (self.compose) |state| xkb.xkb_compose_state_unref(state);
    self.compose = null;
    if (self.compose_locale) |locale| conn.gpa.free(locale);
    self.compose_locale = null;
}

pub fn register(self: *Self, slot: usize, surface: wl.Surface, keyboard: bool) void {
    std.debug.assert(slot < self.targets.len and self.targets[slot] == null);
    self.targets[slot] = .{ .id = surface.id, .keyboard = keyboard };
}

/// Retire pending input for the exact destroyed role, not its sibling.
pub fn forget(self: *Self, conn: *Connection, slot: usize) !void {
    const retired = self.targets[slot] orelse return;
    self.targets[slot] = null;
    const disable_ime = self.ime_focus == retired.id;
    if (disable_ime) self.resetIme();
    if (self.keyboard_focus == retired.id) self.resetKeyboard();
    if (self.pointer_focus == retired.id) self.resetPointer();
    var kept: usize = 0;
    for (self.queue[0..self.count]) |event| {
        if (event.surface == retired.id) continue;
        self.queue[kept] = event;
        kept += 1;
    }
    self.count = kept;
    if (disable_ime) {
        try self.ime_object.?.disable(&conn.session);
        try self.commitIme(conn);
    }
}

pub fn pop(self: *Self) ?Event {
    if (self.count == 0) return null;
    const event = self.queue[0];
    self.count -= 1;
    std.mem.copyForwards(Event, self.queue[0..self.count], self.queue[1..][0..self.count]);
    return event;
}

fn push(self: *Self, event: Event) !void {
    // Pointer storms need only the latest adjacent motion. Never coalesce
    // across a button, focus, key or scroll transition.
    if (event.value == .motion and self.count != 0) {
        const last = &self.queue[self.count - 1];
        if (last.surface == event.surface and last.value == .motion) {
            last.* = event;
            return;
        }
    }
    if (self.count == max_events) return error.NativeInputOverflow;
    self.queue[self.count] = event;
    self.count += 1;
}

fn target(self: *const Self, id: wire.ObjectId, keyboard: bool) bool {
    for (self.targets) |entry| if (entry) |t| {
        if (t.id == id and (!keyboard or t.keyboard)) return true;
    };
    return false;
}

pub fn bindSeat(self: *Self, conn: *Connection, registry: wl.Registry, global: u32, version: u32) !void {
    if (version < 5) return; // release and pointer frame are required.
    for (&self.seats) |*slot| {
        if (slot.* != null) continue;
        const seat = try registry.bind(&conn.session, global, wl.Seat, @min(version, 8));
        slot.* = .{ .global = global, .object = seat };
        try conn.setListener(seat, self, onSeat);
        return;
    }
    return error.NativeSeatLimit;
}

pub fn removeSeat(self: *Self, conn: *Connection, global: u32) !void {
    if (self.ime_global == global) return error.NativeImeManagerRemoved;
    for (&self.seats) |*slot| {
        const seat = slot.* orelse continue;
        if (seat.global != global) continue;
        if (self.selected != null and self.selected.?.id == seat.object.id) {
            if (self.ime_focus) |focus| try self.push(.{ .surface = focus, .value = .ime_cancel });
            self.resetIme();
            if (self.ime_object) |object| {
                try conn.clearListener(object);
                try object.destroy(&conn.session);
                self.ime_object = null;
                self.ime_serial = 0;
            }
            try self.devices(conn, seat.object, .{});
            self.selected = null;
        }
        try conn.clearListener(seat.object);
        try seat.object.release(&conn.session);
        slot.* = null;
        return;
    }
}

fn onSeat(self: *Self, conn: *Connection, seat: wl.Seat, event: wl.Seat.Event) !void {
    const slot = for (&self.seats) |*entry| {
        if (entry.* != null and entry.*.?.object.id == seat.id) break &entry.*.?;
    } else return;
    switch (event) {
        .name => |name| {
            // Both supported desktops use seat0. Never merge agent/private
            // seat input into the user's picker. No implicit seat fallback.
            if (!std.mem.eql(u8, name.name, "seat0")) return;
            if (self.selected != null and self.selected.?.id != seat.id) return error.NativeSeatAmbiguous;
            self.selected = seat;
            slot.selected = true;
            try self.bindImeSeat(conn, seat);
        },
        .capabilities => |caps| slot.caps = caps.capabilities,
    }
    if (slot.selected) try self.devices(conn, seat, slot.caps);
}

pub fn bindImeManager(self: *Self, conn: *Connection, registry: wl.Registry, global: u32) !void {
    if (self.ime_manager != null) return;
    self.ime_manager = try registry.bind(&conn.session, global, zwp.TextInputManagerV3, 1);
    self.ime_global = global;
    if (self.selected) |seat| try self.bindImeSeat(conn, seat);
}

fn bindImeSeat(self: *Self, conn: *Connection, seat: wl.Seat) !void {
    if (self.ime_manager) |manager| if (self.ime_object == null) {
        const object = try manager.getTextInput(&conn.session, seat);
        self.ime_object = object;
        try conn.setListener(object, self, onIme);
    };
}

fn commitIme(self: *Self, conn: *Connection) !void {
    try self.ime_object.?.commit(&conn.session);
    self.ime_serial +%= 1;
}

fn resetIme(self: *Self) void {
    self.ime_focus = null;
    self.ime_pending = .{};
    self.ime_preedit = false;
    self.repeat = null;
    self.resetCompose();
}

fn onIme(self: *Self, conn: *Connection, object: zwp.TextInputV3, event: zwp.TextInputV3.Event) !void {
    switch (event) {
        .enter => |entered| {
            if (self.ime_focus) |focus| try self.push(.{ .surface = focus, .value = .ime_cancel });
            self.resetIme();
            if (!self.target(entered.surface.id, true)) return;
            self.ime_focus = entered.surface.id;
            try object.enable(&conn.session);
            // Surrounding text and cursor geometry belong to the actual
            // editable widget, not this transport. Advertise neither until
            // the picker adapter supplies them.
            try self.commitIme(conn);
        },
        .leave => |left| if (self.ime_focus == left.surface.id) {
            self.resetIme();
            try self.push(.{ .surface = left.surface.id, .value = .ime_cancel });
        },
        else => {
            const focus = self.ime_focus orelse return;
            switch (event) {
                .preedit_string => |value| {
                    try self.ime_pending.preedit.set(value.text);
                    const text = &self.ime_pending.preedit;
                    if (!(value.cursor_begin == -1 and value.cursor_end == -1) and (!text.boundary(value.cursor_begin) or !text.boundary(value.cursor_end))) return error.NativeImeCursor;
                    self.ime_pending.cursor_begin = value.cursor_begin;
                    self.ime_pending.cursor_end = value.cursor_end;
                },
                .commit_string => |value| try self.ime_pending.commit.set(value.text),
                .delete_surrounding_text => |value| {
                    if (value.before_length > 256 or value.after_length > 256) return error.NativeImeText;
                    self.ime_pending.delete_before = value.before_length;
                    self.ime_pending.delete_after = value.after_length;
                },
                .done => |value| {
                    // The v3 specification applies edits even for a stale
                    // serial, but forbids updating client state until matched.
                    self.ime_pending.serial_matches = value.serial == self.ime_serial;
                    self.ime_preedit = self.ime_pending.preedit.len != 0;
                    self.repeat = null;
                    self.resetCompose();
                    try self.push(.{ .surface = focus, .value = .{ .ime = self.ime_pending } });
                    self.ime_pending = .{};
                },
                else => {}, // v2 events are not negotiated
            }
        },
    }
}

fn devices(self: *Self, conn: *Connection, seat: wl.Seat, caps: wl.Seat.Capability) !void {
    if (caps.keyboard) {
        if (self.keyboard == null) {
            const keyboard = try seat.getKeyboard(&conn.session);
            self.keyboard = keyboard;
            try conn.setListener(keyboard, self, onKeyboard);
        }
    } else if (self.keyboard) |keyboard| {
        try self.leaveKeyboard();
        self.clearKeymap();
        self.repeat_rate = 0;
        self.repeat_delay = 0;
        try conn.clearListener(keyboard);
        try keyboard.release(&conn.session);
        self.keyboard = null;
    }
    if (caps.pointer) {
        if (self.pointer == null) {
            const pointer = try seat.getPointer(&conn.session);
            self.pointer = pointer;
            try conn.setListener(pointer, self, onPointer);
            try self.cursor.bindPointer(conn, pointer);
        }
    } else if (self.pointer) |pointer| {
        try self.leavePointer();
        try self.cursor.releasePointer(conn);
        try conn.clearListener(pointer);
        try pointer.release(&conn.session);
        self.pointer = null;
    }
}

fn clearKeymap(self: *Self) void {
    if (self.state) |state| xkb.xkb_state_unref(state);
    if (self.keymap) |map| xkb.xkb_keymap_unref(map);
    self.state = null;
    self.keymap = null;
    self.repeat = null;
    self.resetCompose();
}

fn loadKeymap(self: *Self, allocator: std.mem.Allocator, fd: i32, size: u32, format: wl.Keyboard.KeymapFormat) !void {
    defer _ = linux.close(fd);
    if (format != .xkb_v1 or size == 0 or size > max_keymap_bytes) return error.NativeKeymapFormat;
    const bytes = try allocator.alloc(u8, size);
    defer allocator.free(bytes);
    var offset: usize = 0;
    while (offset < bytes.len) {
        const n = linux.pread(fd, bytes[offset..].ptr, bytes.len - offset, @intCast(offset));
        switch (linux.errno(n)) {
            .SUCCESS => {
                if (n == 0) return error.NativeKeymapTruncated;
                offset += n;
            },
            .INTR => continue,
            else => return error.NativeKeymapRead,
        }
    }
    if (bytes[bytes.len - 1] != 0 or std.mem.indexOfScalar(u8, bytes[0 .. bytes.len - 1], 0) != null) return error.NativeKeymapFormat;
    const context = xkb.xkb_context_new(xkb.XKB_CONTEXT_NO_DEFAULT_INCLUDES | xkb.XKB_CONTEXT_NO_ENVIRONMENT_NAMES) orelse return error.NativeXkbContext;
    defer xkb.xkb_context_unref(context);
    const map = xkb.xkb_keymap_new_from_buffer(context, bytes.ptr, bytes.len - 1, xkb.XKB_KEYMAP_FORMAT_TEXT_V1, xkb.XKB_KEYMAP_COMPILE_NO_FLAGS) orelse return error.NativeKeymapParse;
    errdefer xkb.xkb_keymap_unref(map);
    const state = xkb.xkb_state_new(map) orelse return error.NativeXkbState;
    self.clearKeymap();
    self.keymap = map;
    self.state = state;
    self.applyMasks();
}

fn applyMasks(self: *Self) void {
    if (self.state) |state| _ = xkb.xkb_state_update_mask(state, self.masks.depressed, self.masks.latched, self.masks.locked, 0, 0, self.masks.group);
}

fn resetKeyboard(self: *Self) void {
    self.keyboard_focus = null;
    self.repeat = null;
    self.resetCompose();
    self.keys = .empty;
    self.emitted = .empty;
    self.masks = .{};
    self.applyMasks();
}

fn leaveKeyboard(self: *Self) !void {
    const focus = self.keyboard_focus;
    self.resetKeyboard();
    if (focus) |id| try self.push(.{ .surface = id, .value = .keyboard_leave });
}

fn modifier(state: *xkb.struct_xkb_state, name: [*:0]const u8) bool {
    return xkb.xkb_state_mod_name_is_active(state, name, xkb.XKB_STATE_MODS_EFFECTIVE) == 1;
}

fn onKeyboard(self: *Self, conn: *Connection, _: wl.Keyboard, event: wl.Keyboard.Event) !void {
    switch (event) {
        .keymap => |map| try self.loadKeymap(conn.gpa, map.fd, map.size, map.format),
        .enter => |entered| {
            try self.leaveKeyboard();
            if (!self.target(entered.surface.id, true)) return;
            if (entered.keys.len % 4 != 0 or entered.keys.len > max_keys * 4) return error.NativeKeyArray;
            try self.ensureCompose(conn.gpa);
            self.keyboard_focus = entered.surface.id;
            // Inherited held keys are facts, not presses to replay.
            var at: usize = 0;
            while (at < entered.keys.len) : (at += 4) {
                const key = std.mem.readInt(u32, entered.keys[at..][0..4], @import("builtin").cpu.arch.endian());
                if (key < max_keys) self.keys.set(key);
            }
            try self.push(.{ .surface = entered.surface.id, .value = .keyboard_enter });
        },
        .leave => |left| if (self.keyboard_focus == left.surface.id) {
            try self.leaveKeyboard();
        },
        .modifiers => |mods| {
            self.masks = .{ .depressed = mods.mods_depressed, .latched = mods.mods_latched, .locked = mods.mods_locked, .group = mods.group };
            self.applyMasks();
        },
        .repeat_info => |repeat| {
            if (repeat.rate < 0 or repeat.delay < 0) return error.NativeRepeatInfo;
            self.repeat_rate = repeat.rate;
            self.repeat_delay = repeat.delay;
            self.repeat = null;
        },
        .key => |key| {
            const focus = self.keyboard_focus orelse return;
            if (key.key >= max_keys) return;
            if (self.state == null) return error.NativeKeymapMissing;
            switch (key.state) {
                .pressed => {
                    if (self.keys.isSet(key.key)) return;
                    self.keys.set(key.key);
                    self.emitted.set(key.key);
                },
                .released => {
                    if (self.repeat != null and self.repeat.?.code == key.key) self.repeat = null;
                    if (!self.keys.isSet(key.key)) return;
                    self.keys.unset(key.key);
                    if (!self.emitted.isSet(key.key)) return;
                    self.emitted.unset(key.key);
                },
                else => return,
            }
            const translated = self.translateKey(key.key, key.state == .pressed, false);
            if (translated.pressed and (translated.repeatable or translated.compose_consumed or translated.symbol == xkb.XKB_KEY_Escape or translated.symbol == xkb.XKB_KEY_Tab or translated.symbol == xkb.XKB_KEY_Return or translated.symbol == xkb.XKB_KEY_KP_Enter)) {
                self.repeat = null;
                if (self.repeat_rate > 0 and !self.ime_preedit and repeatEligible(translated)) {
                    self.repeat = .{
                        .code = key.key,
                        .deadline = std.Io.Clock.awake.now(conn.io).addDuration(.fromMilliseconds(self.repeat_delay)),
                        .interval = .fromNanoseconds(@divTrunc(std.time.ns_per_s, @as(i64, @min(self.repeat_rate, 100)))),
                    };
                }
            }
            try self.push(.{ .surface = focus, .value = .{ .key = translated } });
        },
    }
}

/// A single repeat deadline, owned by the visible event loop. Real input
/// readiness and queued transitions take priority over this timer. No catch-up
/// bursts: a late wake emits one repeat, then schedules from the current time.
pub fn repeatDeadline(self: *const Self) ?std.Io.Timestamp {
    return if (self.repeat) |held| held.deadline else null;
}

pub fn advanceRepeat(self: *Self, now: std.Io.Timestamp) !bool {
    const held = self.repeat orelse return false;
    if (now.nanoseconds < held.deadline.nanoseconds or self.count != 0) return false;
    const focus = self.keyboard_focus orelse {
        self.repeat = null;
        return false;
    };
    if (!self.keys.isSet(held.code) or !self.emitted.isSet(held.code) or self.state == null) {
        self.repeat = null;
        return false;
    }
    const key = self.translateKey(held.code, true, true);
    if (!repeatEligible(key)) {
        self.repeat = null;
        return false;
    }
    try self.push(.{ .surface = focus, .value = .{ .key = key } });
    self.repeat.?.deadline = now.addDuration(held.interval);
    return true;
}

fn repeatEligible(key: Key) bool {
    if (!key.repeatable or key.compose_consumed or key.modifiers.control or key.modifiers.alt or key.modifiers.logo) return false;
    // Enter, Tab and Escape are one-shot picker actions even if a keymap
    // describes them as repeating. Only editing/navigation or text repeats.
    return key.text_len != 0 or switch (key.symbol) {
        xkb.XKB_KEY_BackSpace, xkb.XKB_KEY_Up, xkb.XKB_KEY_Down, xkb.XKB_KEY_Left, xkb.XKB_KEY_Right, xkb.XKB_KEY_Delete => true,
        else => false,
    };
}

/// Retain the locale choice but do not open a compose table for a banner-only
/// connection. The first editable keyboard focus prepares it before keys.
pub fn rememberComposeLocale(self: *Self, allocator: std.mem.Allocator, env: *const std.process.Environ.Map) !void {
    std.debug.assert(self.compose == null and self.compose_locale == null);
    const locale = for ([_][]const u8{ "LC_ALL", "LC_CTYPE", "LANG" }) |name| {
        if (env.get(name)) |value| if (value.len != 0) break value;
    } else "C.UTF-8";
    self.compose_locale = try allocator.dupeSentinel(u8, locale, 0);
}

fn ensureCompose(self: *Self, allocator: std.mem.Allocator) !void {
    const locale = self.compose_locale orelse return;
    self.compose_locale = null;
    defer allocator.free(locale);
    std.debug.assert(self.compose == null);
    const context = xkb.xkb_context_new(xkb.XKB_CONTEXT_NO_FLAGS) orelse return error.NativeXkbContext;
    defer xkb.xkb_context_unref(context);
    const table = xkb.xkb_compose_table_new_from_locale(context, locale.ptr, xkb.XKB_COMPOSE_COMPILE_NO_FLAGS) orelse {
        std.log.warn("native compose table unavailable; using direct XKB text", .{});
        return;
    };
    defer xkb.xkb_compose_table_unref(table);
    self.compose = xkb.xkb_compose_state_new(table, xkb.XKB_COMPOSE_STATE_NO_FLAGS) orelse return error.NativeComposeState;
}

fn resetCompose(self: *Self) void {
    if (self.compose) |state| xkb.xkb_compose_state_reset(state);
}

fn translateKey(self: *Self, raw: u32, pressed: bool, repeated: bool) Key {
    const state = self.state.?;
    const code = raw + 8;
    var key: Key = .{
        .code = raw,
        .symbol = xkb.xkb_state_key_get_one_sym(state, code),
        .pressed = pressed,
        .repeated = repeated,
        .repeatable = xkb.xkb_keymap_key_repeats(self.keymap.?, code) != 0,
        .modifiers = .{ .shift = modifier(state, "Shift"), .control = modifier(state, "Control"), .alt = modifier(state, "Mod1"), .logo = modifier(state, "Mod4") },
    };
    if (!pressed) return key;
    if (key.modifiers.control or key.modifiers.alt or key.modifiers.logo) {
        self.resetCompose();
        return key;
    }
    // A compositor forwards keys the input method did not consume. Do not
    // disable direct XKB text merely because a text-input global exists.
    if (!repeated and !self.ime_preedit) if (self.compose) |compose| {
        _ = xkb.xkb_compose_state_feed(compose, key.symbol);
        switch (xkb.xkb_compose_state_get_status(compose)) {
            xkb.XKB_COMPOSE_COMPOSING => {
                key.repeatable = false;
                key.compose_consumed = true;
                return key;
            },
            xkb.XKB_COMPOSE_COMPOSED => {
                acceptText(&key, xkb.xkb_compose_state_get_utf8(compose, &key.text, key.text.len));
                self.resetCompose();
                key.repeatable = false;
                key.compose_consumed = true;
                return key;
            },
            xkb.XKB_COMPOSE_CANCELLED => {
                self.resetCompose();
                key.repeatable = false;
                key.compose_consumed = true;
                return key;
            },
            else => {},
        }
    };
    acceptText(&key, xkb.xkb_state_key_get_utf8(state, code, &key.text, key.text.len));
    return key;
}

fn acceptText(key: *Key, len: i32) void {
    if (len <= 0 or len >= key.text.len) return;
    const bytes = key.text[0..@intCast(len)];
    if (bytes[0] >= 32 and bytes[0] != 127 and std.unicode.utf8ValidateSlice(bytes)) key.text_len = @intCast(len);
}

fn resetPointer(self: *Self) void {
    self.pointer_focus = null;
    self.buttons = .empty;
    self.axis_units = 0;
    self.axis_steps = null;
    self.axis_highres = null;
    self.axis_distance = 0;
}

fn leavePointer(self: *Self) !void {
    const focus = self.pointer_focus;
    self.resetPointer();
    if (focus) |id| try self.push(.{ .surface = id, .value = .pointer_leave });
}

fn onPointer(self: *Self, conn: *Connection, pointer: wl.Pointer, event: wl.Pointer.Event) !void {
    switch (event) {
        .enter => |entered| {
            try self.leavePointer();
            if (!self.target(entered.surface.id, false)) return;
            self.pointer_focus = entered.surface.id;
            try self.cursor.show(conn, pointer, entered.serial);
            self.point = .{ .x = entered.surface_x.toDouble(), .y = entered.surface_y.toDouble() };
            try self.push(.{ .surface = entered.surface.id, .value = .{ .pointer_enter = self.point } });
        },
        .leave => |left| if (self.pointer_focus == left.surface.id) {
            try self.leavePointer();
        },
        .motion => |motion| if (self.pointer_focus) |id| {
            self.point = .{ .x = motion.surface_x.toDouble(), .y = motion.surface_y.toDouble() };
            try self.push(.{ .surface = id, .value = .{ .motion = self.point } });
        },
        .button => |button| if (self.pointer_focus) |id| {
            if (button.button < 272 or button.button >= 288) return;
            const index = button.button - 272;
            switch (button.state) {
                .pressed => {
                    if (self.buttons.isSet(index)) return;
                    self.buttons.set(index);
                },
                .released => {
                    if (!self.buttons.isSet(index)) return;
                    self.buttons.unset(index);
                },
                else => return,
            }
            try self.push(.{ .surface = id, .value = .{ .button = .{ .code = button.button, .pressed = button.state == .pressed, .at = self.point } } });
        },
        .axis => |axis| if (self.pointer_focus != null and axis.axis == .vertical_scroll) {
            self.axis_distance += axis.value.toDouble();
        },
        .axis_discrete => |axis| if (self.pointer_focus != null and axis.axis == .vertical_scroll) {
            self.axis_steps = (self.axis_steps orelse 0) +| axis.discrete;
        },
        .axis_value120 => |axis| if (self.pointer_focus != null and axis.axis == .vertical_scroll) {
            self.axis_highres = (self.axis_highres orelse 0) +| axis.value120;
        },
        .frame => {
            // Prefer high-resolution wheel units, then discrete detents;
            // continuous motion uses 10 logical pixels per detent. Never
            // count the accompanying continuous axis a second time.
            const units = self.axis_highres orelse if (self.axis_steps) |steps| steps *| 120 else @as(i64, @intFromFloat(std.math.clamp(self.axis_distance * 12, -720.0, 720.0)));
            self.axis_units = std.math.clamp(self.axis_units +| units, -720, 720);
            const ticks = @divTrunc(self.axis_units, 120);
            self.axis_units -= ticks * 120;
            self.axis_steps = null;
            self.axis_highres = null;
            self.axis_distance = 0;
            if (self.pointer_focus) |id| if (ticks != 0) {
                try self.push(.{ .surface = id, .value = .{ .scroll = @intCast(ticks * 3) } });
            };
        },
        else => {},
    }
}
