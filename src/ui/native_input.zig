//! One local Wayland seat, with protocol-owned focus and bounded event storage.
//! No key injection, SDL events, repeat timer or text-input protocol here.
const std = @import("std");
const linux = std.os.linux;
const Connection = @import("wayland-client").Connection;
const wl = @import("wayland-protocols").wl;
const wire = @import("wayland-wire");
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
    modifiers: Modifiers,
    text: [64]u8 = @splat(0),
    text_len: u8 = 0,

    pub fn utf8(self: *const Key) []const u8 {
        return self.text[0..self.text_len];
    }
};
pub const Event = struct {
    surface: wire.ObjectId,
    value: union(enum) {
        keyboard_enter,
        keyboard_leave,
        key: Key,
        pointer_enter: Point,
        pointer_leave,
        motion: Point,
        button: struct { code: u32, pressed: bool, at: Point },
        scroll: i8,
    },
};
const Seat = struct { global: u32, object: wl.Seat, selected: bool = false, caps: wl.Seat.Capability = .{} };
const Target = struct { id: wire.ObjectId, keyboard: bool };
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
axis_units: i64 = 0,
axis_distance: f64 = 0,
axis_steps: ?i64 = null,
axis_highres: ?i64 = null,
queue: [max_events]Event = undefined,
count: usize = 0,

pub fn deinit(self: *Self) void {
    self.clearKeymap();
}

pub fn register(self: *Self, slot: usize, surface: wl.Surface, keyboard: bool) void {
    std.debug.assert(slot < self.targets.len and self.targets[slot] == null);
    self.targets[slot] = .{ .id = surface.id, .keyboard = keyboard };
}

/// Retire pending input for the exact destroyed role, not its sibling.
pub fn forget(self: *Self, slot: usize) void {
    const retired = self.targets[slot] orelse return;
    self.targets[slot] = null;
    if (self.keyboard_focus == retired.id) self.resetKeyboard();
    if (self.pointer_focus == retired.id) self.resetPointer();
    var kept: usize = 0;
    for (self.queue[0..self.count]) |event| {
        if (event.surface == retired.id) continue;
        self.queue[kept] = event;
        kept += 1;
    }
    self.count = kept;
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
    for (&self.seats) |*slot| {
        const seat = slot.* orelse continue;
        if (seat.global != global) continue;
        if (self.selected != null and self.selected.?.id == seat.object.id) {
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
        },
        .capabilities => |caps| slot.caps = caps.capabilities,
    }
    if (slot.selected) try self.devices(conn, seat, slot.caps);
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
        }
    } else if (self.pointer) |pointer| {
        try self.leavePointer();
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
        },
        .key => |key| {
            const focus = self.keyboard_focus orelse return;
            if (key.key >= max_keys) return;
            const state = self.state orelse return error.NativeKeymapMissing;
            switch (key.state) {
                .pressed => {
                    if (self.keys.isSet(key.key)) return;
                    self.keys.set(key.key);
                    self.emitted.set(key.key);
                },
                .released => {
                    if (!self.keys.isSet(key.key)) return;
                    self.keys.unset(key.key);
                    if (!self.emitted.isSet(key.key)) return;
                    self.emitted.unset(key.key);
                },
                else => return,
            }
            const code = key.key + 8;
            var translated: Key = .{
                .code = key.key,
                .symbol = xkb.xkb_state_key_get_one_sym(state, code),
                .pressed = key.state == .pressed,
                .repeatable = xkb.xkb_keymap_key_repeats(self.keymap.?, code) != 0,
                .modifiers = .{ .shift = modifier(state, "Shift"), .control = modifier(state, "Control"), .alt = modifier(state, "Mod1"), .logo = modifier(state, "Mod4") },
            };
            if (translated.pressed and !translated.modifiers.control and !translated.modifiers.alt and !translated.modifiers.logo) {
                const n = xkb.xkb_state_key_get_utf8(state, code, &translated.text, translated.text.len);
                if (n > 0 and n < translated.text.len) {
                    const bytes = translated.text[0..@intCast(n)];
                    // Navigation/control keys are key events, not text.
                    if (bytes[0] >= 32 and bytes[0] != 127 and std.unicode.utf8ValidateSlice(bytes)) translated.text_len = @intCast(n);
                }
            }
            try self.push(.{ .surface = focus, .value = .{ .key = translated } });
        },
    }
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

fn onPointer(self: *Self, _: *Connection, _: wl.Pointer, event: wl.Pointer.Event) !void {
    switch (event) {
        .enter => |entered| {
            try self.leavePointer();
            if (!self.target(entered.surface.id, false)) return;
            self.pointer_focus = entered.surface.id;
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
