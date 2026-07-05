//! Bounded Lua defaults loader for Wayspot appearance state.
//!
//! Lua is used only as a data surface. The loader creates a state without
//! standard libraries, executes one returned table with an instruction budget,
//! and maps accepted fields into fixed-size Zig appearance values.

const std = @import("std");
const defaults_asset = @import("defaults_asset");
const howl_lua = @import("howl_lua");
const appearance_owner = @import("../picker/appearance.zig");
const values = @import("../picker/appearance.zig");

const c = howl_lua.c;

pub const max_embedded_defaults_bytes: u32 = 32768;
pub const max_user_defaults_bytes: u32 = 32768;
pub const max_lua_instructions: u32 = 100000;
pub const max_table_depth: u32 = 4;
pub const max_total_keys: u32 = 128;
pub const max_color_entries: u32 = 32;

const embedded_defaults = defaults_asset.lua;
const user_defaults_relative = ".config/wayspot/defaults.lua";
const instruction_budget_error = "wayspot config exceeded Lua instruction budget";

const ApplyMode = enum {
    required,
    optional,
};

const Counters = struct {
    total_keys: u32 = 0,
    color_entries: u32 = 0,

    fn key(self: *Counters) !void {
        if (self.total_keys >= max_total_keys) return error.TooManyDefaultsKeys;
        self.total_keys += 1;
    }

    fn color(self: *Counters) !void {
        if (self.color_entries >= max_color_entries) return error.TooManyColors;
        self.color_entries += 1;
    }
};

/// Loads embedded defaults, then applies `$HOME/.config/wayspot/defaults.lua` when present.
/// Invalid user config returns an error after leaving the embedded value unmutated.
pub fn load(allocator: std.mem.Allocator, home: []const u8) !appearance_owner.Appearance {
    var appearance_state = try loadEmbedded();
    const user_path = try std.fs.path.join(allocator, &.{ home, user_defaults_relative });
    defer allocator.free(user_path);

    const user_bytes = std.Io.Dir.cwd().readFileAlloc(
        std.Options.debug_io,
        user_path,
        allocator,
        .limited(max_user_defaults_bytes),
    ) catch |err| switch (err) {
        error.FileNotFound => return appearance_state,
        else => return err,
    };
    defer allocator.free(user_bytes);

    var candidate = appearance_state;
    try applyBuffer(user_bytes, .optional, &candidate);
    appearance_state = candidate;
    return appearance_state;
}

/// Loads defaults using HOME from the process environment, falling back to embedded values.
pub fn loadFromEnvironment(allocator: std.mem.Allocator) !appearance_owner.Appearance {
    const home = if (std.c.getenv("HOME")) |home_z| std.mem.span(home_z) else ".";
    return load(allocator, home);
}

/// Parses the embedded Lua defaults and requires every production field.
pub fn loadEmbedded() !appearance_owner.Appearance {
    if (embedded_defaults.len > max_embedded_defaults_bytes) return error.EmbeddedDefaultsTooLarge;
    var appearance_state = try appearance_owner.currentHardcodedDefaults();
    try applyBuffer(embedded_defaults, .required, &appearance_state);
    return appearance_state;
}

/// Applies one Lua defaults buffer into `appearance` according to required or optional field mode.
pub fn applyBuffer(buffer: []const u8, mode: ApplyMode, appearance_state: *appearance_owner.Appearance) !void {
    if (buffer.len > max_user_defaults_bytes) return error.DefaultsTooLarge;
    var state = try LuaState.init();
    defer state.deinit();
    try state.loadAndRun(buffer);
    if (!c.lua_istable(state.raw, -1)) return error.DefaultsMustReturnTable;
    var counters = Counters{};
    try applyRoot(state.raw, c.lua_absindex(state.raw, -1), mode, appearance_state, &counters);
}

const LuaState = struct {
    raw: *c.lua_State,

    /// Creates a Lua state without opening standard libraries.
    fn init() !LuaState {
        const raw = c.luaL_newstate() orelse return error.LuaOutOfMemory;
        return .{ .raw = raw };
    }

    /// Clears the hook before closing the state.
    fn deinit(self: LuaState) void {
        c.lua_sethook(self.raw, null, 0, 0);
        c.lua_close(self.raw);
    }

    /// Loads text-only Lua and executes it with a count hook budget.
    fn loadAndRun(self: LuaState, buffer: []const u8) !void {
        const chunk_name: [:0]const u8 = "wayspot-defaults";
        const text_mode: [:0]const u8 = "t";
        const loaded = c.luaL_loadbufferx(self.raw, buffer.ptr, buffer.len, chunk_name.ptr, text_mode.ptr);
        if (loaded != c.LUA_OK) return error.LuaLoadFailed;
        c.lua_sethook(self.raw, instructionHook, c.LUA_MASKCOUNT, max_lua_instructions);
        const called = c.lua_pcallk(self.raw, 0, 1, 0, @as(c.lua_KContext, 0), null);
        c.lua_sethook(self.raw, null, 0, 0);
        if (called != c.LUA_OK) {
            if (luaMessageEquals(self.raw, instruction_budget_error)) return error.LuaInstructionBudgetExceeded;
            return error.LuaExecutionFailed;
        }
    }
};

fn instructionHook(raw_maybe: ?*c.lua_State, debug_info: ?*c.lua_Debug) callconv(.c) void {
    if (debug_info == null) return;
    const raw = raw_maybe orelse return;
    const pushed = c.lua_pushlstring(raw, instruction_budget_error.ptr, instruction_budget_error.len);
    if (pushed == null) return;
    const raised = c.lua_error(raw);
    std.debug.assert(raised != 0);
}

fn luaMessageEquals(raw: *c.lua_State, expected: []const u8) bool {
    var len = @as(@TypeOf(expected.len), 0);
    const ptr = c.lua_tolstring(raw, -1, &len) orelse return false;
    const actual = ptr[0..len];
    return std.mem.eql(u8, actual, expected);
}

fn applyRoot(raw: *c.lua_State, index: c_int, mode: ApplyMode, appearance_state: *appearance_owner.Appearance, counters: *Counters) !void {
    const fields = [_][]const u8{ "fonts", "picker", "banner", "sunglasses_form" };
    try validateNamedFields(raw, index, &fields, counters);
    if (try pushTableField(raw, index, "fonts", mode)) {
        defer c.lua_pop(raw, 1);
        try applyFonts(raw, c.lua_absindex(raw, -1), mode, &appearance_state.fonts, counters, 1);
    }
    if (try pushTableField(raw, index, "picker", mode)) {
        defer c.lua_pop(raw, 1);
        try applyPicker(raw, c.lua_absindex(raw, -1), mode, &appearance_state.picker, counters, 1);
    }
    if (try pushTableField(raw, index, "banner", mode)) {
        defer c.lua_pop(raw, 1);
        try applyBanner(raw, c.lua_absindex(raw, -1), mode, &appearance_state.banner, counters, 1);
    }
    if (try pushTableField(raw, index, "sunglasses_form", mode)) {
        defer c.lua_pop(raw, 1);
        try applySunglassesForm(raw, c.lua_absindex(raw, -1), mode, &appearance_state.sunglasses_form, counters, 1);
    }
}

fn applyFonts(raw: *c.lua_State, index: c_int, mode: ApplyMode, target: *appearance_owner.FontAppearance, counters: *Counters, depth: u32) !void {
    try ensureDepth(depth);
    const fields = [_][]const u8{ "candidates", "default_px" };
    try validateNamedFields(raw, index, &fields, counters);
    try applyFontCandidates(raw, index, mode, target, counters);
    try applyFontPxField(raw, index, "default_px", mode, &target.default_px);
}

fn applyPicker(raw: *c.lua_State, index: c_int, mode: ApplyMode, target: *appearance_owner.PickerAppearance, counters: *Counters, depth: u32) !void {
    try ensureDepth(depth);
    const fields = [_][]const u8{
        "background",
        "query_placeholder",
        "query_text",
        "query_cursor",
        "query_divider",
        "row_selected_fill",
        "row_normal_fill",
        "title_selected",
        "title_normal",
        "subtitle_selected",
        "subtitle_normal",
        "empty_text",
        "scrollbar_track",
        "scrollbar_thumb",
    };
    try validateNamedFields(raw, index, &fields, counters);
    try applyColorField(raw, index, "background", mode, &target.background, counters);
    if (try pushTableField(raw, index, "query_placeholder", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.query_placeholder, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "query_text", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.query_text, counters, depth + 1);
    }
    try applyColorField(raw, index, "query_cursor", mode, &target.query_cursor, counters);
    try applyColorField(raw, index, "query_divider", mode, &target.query_divider, counters);
    try applyColorField(raw, index, "row_selected_fill", mode, &target.row_selected_fill, counters);
    try applyColorField(raw, index, "row_normal_fill", mode, &target.row_normal_fill, counters);
    if (try pushTableField(raw, index, "title_selected", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.title_selected, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "title_normal", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.title_normal, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "subtitle_selected", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.subtitle_selected, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "subtitle_normal", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.subtitle_normal, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "empty_text", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.empty_text, counters, depth + 1);
    }
    try applyColorField(raw, index, "scrollbar_track", mode, &target.scrollbar_track, counters);
    try applyColorField(raw, index, "scrollbar_thumb", mode, &target.scrollbar_thumb, counters);
}

fn applyBanner(raw: *c.lua_State, index: c_int, mode: ApplyMode, target: *appearance_owner.BannerAppearance, counters: *Counters, depth: u32) !void {
    try ensureDepth(depth);
    const fields = [_][]const u8{
        "critical_background",
        "low_background",
        "normal_background",
        "accent",
        "accent_width",
        "app_text",
        "summary_text",
        "body_text",
        "text_x",
        "app_y",
        "summary_y",
        "body_y",
    };
    try validateNamedFields(raw, index, &fields, counters);
    try applyColorField(raw, index, "critical_background", mode, &target.critical_background, counters);
    try applyColorField(raw, index, "low_background", mode, &target.low_background, counters);
    try applyColorField(raw, index, "normal_background", mode, &target.normal_background, counters);
    try applyColorField(raw, index, "accent", mode, &target.accent, counters);
    try applyChromeField(raw, index, "accent_width", mode, &target.accent_w);
    if (try pushTableField(raw, index, "app_text", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.app_text, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "summary_text", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.summary_text, counters, depth + 1);
    }
    if (try pushTableField(raw, index, "body_text", mode)) {
        defer c.lua_pop(raw, 1);
        try applyText(raw, c.lua_absindex(raw, -1), mode, &target.body_text, counters, depth + 1);
    }
    try applyChromeField(raw, index, "text_x", mode, &target.content_x);
    try applyChromeField(raw, index, "app_y", mode, &target.app_top);
    try applyChromeField(raw, index, "summary_y", mode, &target.summary_top);
    try applyChromeField(raw, index, "body_y", mode, &target.body_top);
}

fn applySunglassesForm(raw: *c.lua_State, index: c_int, mode: ApplyMode, target: *appearance_owner.SunglassesFormAppearance, counters: *Counters, depth: u32) !void {
    try ensureDepth(depth);
    const fields = [_][]const u8{
        "value_column_width",
        "slider_height",
        "toggle_size",
        "knob_width",
        "knob_height",
        "toggle_inset",
        "value_column_min_x",
        "value_column_fraction",
        "text_font_px",
        "value_font_px",
        "monitor_value",
        "path_error",
        "form_value",
        "focused_row_fill",
        "normal_row_fill",
        "label",
        "toggle_border",
        "toggle_fill",
        "slider_track",
        "slider_knob",
    };
    try validateNamedFields(raw, index, &fields, counters);
    try applyChromeField(raw, index, "value_column_width", mode, &target.value_gap);
    try applyChromeField(raw, index, "slider_height", mode, &target.track_h);
    try applyChromeField(raw, index, "toggle_size", mode, &target.toggle_box);
    try applyChromeField(raw, index, "knob_width", mode, &target.knob_w);
    try applyChromeField(raw, index, "knob_height", mode, &target.knob_h);
    try applyChromeField(raw, index, "toggle_inset", mode, &target.toggle_pad);
    try applyLayoutField(raw, index, "value_column_min_x", mode, &target.value_min_x);
    try applyOpacityField(raw, index, "value_column_fraction", mode, &target.value_fraction);
    try applyFontPxField(raw, index, "text_font_px", mode, &target.label_px);
    try applyFontPxField(raw, index, "value_font_px", mode, &target.value_px);
    try applyColorField(raw, index, "monitor_value", mode, &target.monitor_value, counters);
    try applyColorField(raw, index, "path_error", mode, &target.path_error, counters);
    try applyColorField(raw, index, "form_value", mode, &target.form_value, counters);
    try applyColorField(raw, index, "focused_row_fill", mode, &target.focused_row_fill, counters);
    try applyColorField(raw, index, "normal_row_fill", mode, &target.normal_row_fill, counters);
    try applyColorField(raw, index, "label", mode, &target.label, counters);
    try applyColorField(raw, index, "toggle_border", mode, &target.toggle_border, counters);
    try applyColorField(raw, index, "toggle_fill", mode, &target.toggle_fill, counters);
    try applyColorField(raw, index, "slider_track", mode, &target.slider_track, counters);
    try applyColorField(raw, index, "slider_knob", mode, &target.slider_knob, counters);
}

fn applyText(raw: *c.lua_State, index: c_int, mode: ApplyMode, target: *appearance_owner.TextAppearance, counters: *Counters, depth: u32) !void {
    try ensureDepth(depth);
    const fields = [_][]const u8{ "color", "font_px" };
    try validateNamedFields(raw, index, &fields, counters);
    try applyColorField(raw, index, "color", mode, &target.color, counters);
    try applyFontPxField(raw, index, "font_px", mode, &target.font_px);
}

fn pushTableField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode) !bool {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    if (field_type == c.LUA_TNIL) {
        c.lua_pop(raw, 1);
        if (mode == .required) return error.MissingDefaultsField;
        return false;
    }
    if (field_type != c.LUA_TTABLE) {
        c.lua_pop(raw, 1);
        return error.InvalidDefaultsField;
    }
    return true;
}

fn applyFontCandidates(raw: *c.lua_State, parent: c_int, mode: ApplyMode, target: *appearance_owner.FontAppearance, counters: *Counters) !void {
    const field_type = c.lua_getfield(raw, parent, "candidates");
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TTABLE) return error.InvalidDefaultsField;
    const candidate_count = try validateFontCandidateArray(raw, -1, counters);
    var parsed = values.FontCandidates{};
    var index: u32 = 1;
    while (index <= candidate_count) : (index += 1) {
        const item_type = c.lua_rawgeti(raw, -1, @intCast(index));
        defer c.lua_pop(raw, 1);
        if (item_type != c.LUA_TSTRING) return error.InvalidDefaultsField;
        const item = stackString(raw, -1) orelse return error.InvalidDefaultsField;
        if (item.len > values.max_string_bytes) return error.StringTooLong;
        try parsed.append(item);
    }
    target.candidates = parsed;
}

fn applyColorField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode, target: *appearance_owner.Rgba8, counters: *Counters) !void {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TTABLE) return error.InvalidDefaultsField;
    target.* = try readColor(raw, -1, counters);
}

fn applyFontPxField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode, target: *u16) !void {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TNUMBER or c.lua_isinteger(raw, -1) == 0) return error.InvalidDefaultsField;
    target.* = try values.fontPx(c.lua_tointegerx(raw, -1, null));
}

fn applyChromeField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode, target: *f32) !void {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TNUMBER) return error.InvalidDefaultsField;
    target.* = try values.chromePx(c.lua_tonumberx(raw, -1, null));
}

fn applyLayoutField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode, target: *f32) !void {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TNUMBER) return error.InvalidDefaultsField;
    target.* = try values.layoutPx(c.lua_tonumberx(raw, -1, null));
}

fn applyOpacityField(raw: *c.lua_State, parent: c_int, name: [:0]const u8, mode: ApplyMode, target: *f32) !void {
    const field_type = c.lua_getfield(raw, parent, name.ptr);
    defer c.lua_pop(raw, 1);
    if (field_type == c.LUA_TNIL) {
        if (mode == .required) return error.MissingDefaultsField;
        return;
    }
    if (field_type != c.LUA_TNUMBER) return error.InvalidDefaultsField;
    target.* = try values.opacity(c.lua_tonumberx(raw, -1, null));
}

fn readColor(raw: *c.lua_State, index: c_int, counters: *Counters) !appearance_owner.Rgba8 {
    try counters.color();
    const table_index = c.lua_absindex(raw, index);
    var components = [_]i64{ 0, 0, 0, 0 };
    var seen = [_]bool{ false, false, false, false };
    var component_count: u32 = 0;

    c.lua_pushnil(raw);
    while (c.lua_next(raw, table_index) != 0) {
        const key_type = c.lua_type(raw, -2);
        const value_type = c.lua_type(raw, -1);
        if (key_type != c.LUA_TNUMBER or c.lua_isinteger(raw, -2) == 0) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        const key = c.lua_tointegerx(raw, -2, null);
        if (key < 1 or key > 4) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        if (value_type == c.LUA_TTABLE) {
            c.lua_pop(raw, 2);
            return error.DefaultsTableTooDeep;
        }
        if (value_type != c.LUA_TNUMBER or c.lua_isinteger(raw, -1) == 0) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        const component_slot = key - 1;
        seen[@intCast(component_slot)] = true;
        components[@intCast(component_slot)] = c.lua_tointegerx(raw, -1, null);
        component_count += 1;
        if (component_count > 4) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        c.lua_pop(raw, 1);
    }
    if (component_count != 4) return error.InvalidDefaultsField;
    for (seen) |was_seen| {
        if (!was_seen) return error.InvalidDefaultsField;
    }
    return values.Rgba8.fromComponents(
        components[0],
        components[1],
        components[2],
        components[3],
    );
}

fn validateFontCandidateArray(raw: *c.lua_State, index: c_int, counters: *Counters) !u32 {
    const table_index = c.lua_absindex(raw, index);
    const max_candidate_key: c.lua_Integer = @intCast(values.max_font_candidates);
    var seen = [_]bool{false} ** values.max_font_candidates;
    var candidate_count: u32 = 0;
    var max_index: u32 = 0;

    c.lua_pushnil(raw);
    while (c.lua_next(raw, table_index) != 0) {
        const key_type = c.lua_type(raw, -2);
        const value_type = c.lua_type(raw, -1);
        if (key_type != c.LUA_TNUMBER or c.lua_isinteger(raw, -2) == 0) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        const key = c.lua_tointegerx(raw, -2, null);
        if (key < 1) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        if (key > max_candidate_key) {
            c.lua_pop(raw, 2);
            return error.TooManyFontCandidates;
        }
        if (value_type == c.LUA_TTABLE) {
            c.lua_pop(raw, 2);
            return error.DefaultsTableTooDeep;
        }
        if (value_type != c.LUA_TSTRING) {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        }
        counters.key() catch |err| {
            c.lua_pop(raw, 2);
            return err;
        };
        const candidate_index: u32 = @intCast(key);
        seen[@intCast(candidate_index - 1)] = true;
        if (candidate_index > max_index) max_index = candidate_index;
        candidate_count += 1;
        c.lua_pop(raw, 1);
    }
    if (candidate_count == 0) return error.EmptyFontCandidates;
    if (candidate_count != max_index) return error.InvalidDefaultsField;
    for (seen[0..max_index]) |was_seen| {
        if (!was_seen) return error.InvalidDefaultsField;
    }
    return candidate_count;
}

fn validateNamedFields(raw: *c.lua_State, index: c_int, allowed: []const []const u8, counters: *Counters) !void {
    c.lua_pushnil(raw);
    var saw_unknown = false;
    while (c.lua_next(raw, index) != 0) {
        const key = stackString(raw, -2) orelse {
            c.lua_pop(raw, 2);
            return error.InvalidDefaultsField;
        };
        if (key.len > values.max_string_bytes) {
            c.lua_pop(raw, 2);
            return error.StringTooLong;
        }
        try counters.key();
        if (!fieldAllowed(key, allowed)) {
            saw_unknown = true;
        }
        c.lua_pop(raw, 1);
    }
    if (saw_unknown) return error.UnknownDefaultsField;
}

fn fieldAllowed(key: []const u8, allowed: []const []const u8) bool {
    for (allowed) |candidate| {
        if (std.mem.eql(u8, key, candidate)) return true;
    }
    return false;
}

fn ensureDepth(depth: u32) !void {
    if (depth > max_table_depth) return error.DefaultsTableTooDeep;
}

fn stackString(raw: *c.lua_State, index: c_int) ?[]const u8 {
    if (c.lua_type(raw, index) != c.LUA_TSTRING) return null;
    var len = @as(@TypeOf(embedded_defaults.len), 0);
    const ptr = c.lua_tolstring(raw, index, &len) orelse return null;
    return ptr[0..len];
}

test "embedded defaults parse and preserve current visual defaults" {
    const parsed = try loadEmbedded();
    const expected = try appearance_owner.currentHardcodedDefaults();
    try std.testing.expectEqual(expected.picker.background, parsed.picker.background);
    try std.testing.expectEqual(expected.banner.summary_text, parsed.banner.summary_text);
    try std.testing.expectEqual(expected.sunglasses_form.slider_knob, parsed.sunglasses_form.slider_knob);
    try std.testing.expectEqual(@as(u32, 4), parsed.fonts.candidates.count);
}

test "missing user config keeps embedded defaults" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const tmp_root = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}", .{&tmp.sub_path});
    defer std.testing.allocator.free(tmp_root);
    const home = try std.Io.Dir.cwd().realPathFileAlloc(std.testing.io, tmp_root, std.testing.allocator);
    defer std.testing.allocator.free(home);
    const parsed = try load(std.testing.allocator, home);
    const embedded = try loadEmbedded();
    try std.testing.expectEqual(embedded.picker.query_text, parsed.picker.query_text);
}

test "malformed user config returns error without mutating embedded defaults" {
    var defaults = try loadEmbedded();
    const before = defaults;
    try std.testing.expectError(error.LuaLoadFailed, applyBuffer("return {", .optional, &defaults));
    try std.testing.expectEqual(before.picker.background, defaults.picker.background);
}

test "user config applies partial overrides" {
    var defaults = try loadEmbedded();
    try applyBuffer(
        \\return { picker = { query_text = { color = { 1, 2, 3, 4 } } } }
    , .optional, &defaults);
    try std.testing.expectEqual(appearance_owner.Rgba8{ .r = 1, .g = 2, .b = 3, .a = 4 }, defaults.picker.query_text.color);
    try std.testing.expectEqual(@as(u16, 17), defaults.picker.query_text.font_px);
}

test "color arrays reject extra keys holes and functions" {
    var defaults = try loadEmbedded();
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { picker = { background = { 1, 2, 3, 4, extra = 5 } } }", .optional, &defaults));
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { picker = { background = { [1] = 1, [2] = 2, [4] = 4 } } }", .optional, &defaults));
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { picker = { background = { 1, 2, 3, function() end } } }", .optional, &defaults));
}

test "font candidate arrays reject extra keys holes nested tables and functions" {
    var defaults = try loadEmbedded();
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { fonts = { candidates = { 'one', extra = 'two' } } }", .optional, &defaults));
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { fonts = { candidates = { [1] = 'one', [3] = 'three' } } }", .optional, &defaults));
    try std.testing.expectError(error.DefaultsTableTooDeep, applyBuffer("return { fonts = { candidates = { 'one', { 'two' } } } }", .optional, &defaults));
    try std.testing.expectError(error.InvalidDefaultsField, applyBuffer("return { fonts = { candidates = { 'one', function() end } } }", .optional, &defaults));
}

test "overlong strings and too many font candidates are rejected" {
    var defaults = try loadEmbedded();
    const long_string =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    try std.testing.expectError(error.StringTooLong, applyBuffer("return { fonts = { candidates = { '" ++ long_string ++ "' } } }", .optional, &defaults));
    try std.testing.expectError(error.TooManyFontCandidates, applyBuffer("return { fonts = { candidates = { '1','2','3','4','5','6','7','8','9' } } }", .optional, &defaults));
}

test "out of range font chrome color opacity key count and depth values are rejected" {
    var defaults = try loadEmbedded();
    try std.testing.expectError(error.FontSizeOutOfRange, applyBuffer("return { picker = { query_text = { font_px = 99 } } }", .optional, &defaults));
    try std.testing.expectError(error.ChromeOutOfRange, applyBuffer("return { banner = { accent_width = 99 } }", .optional, &defaults));
    try std.testing.expectError(error.ColorComponentOutOfRange, applyBuffer("return { picker = { background = { 300, 0, 0, 255 } } }", .optional, &defaults));
    try std.testing.expectError(error.OpacityOutOfRange, applyBuffer("return { sunglasses_form = { value_column_fraction = 2 } }", .optional, &defaults));
    try std.testing.expectError(error.UnknownDefaultsField, applyBuffer("return { unknown = 1 }", .optional, &defaults));
    try std.testing.expectError(error.DefaultsTableTooDeep, applyBuffer("return { picker = { query_text = { color = { { 1 }, 2, 3, 4 } } } }", .optional, &defaults));
}

test "too many retained keys are rejected" {
    var defaults = try loadEmbedded();
    try std.testing.expectError(error.TooManyDefaultsKeys, applyBuffer(
        \\local t = { fonts = { candidates = { 'a' }, default_px = 17 } }
        \\for i = 1, 140 do t["x" .. i] = i end
        \\return t
    , .optional, &defaults));
}

test "infinite loop Lua is stopped by the instruction budget" {
    var defaults = try loadEmbedded();
    try std.testing.expectError(error.LuaInstructionBudgetExceeded, applyBuffer("while true do end", .optional, &defaults));
}
