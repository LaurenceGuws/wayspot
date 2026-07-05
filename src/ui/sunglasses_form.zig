//! Sunglasses form owns picker-pane controls for in-memory filter state edits.

const std = @import("std");
const picker_viewport = @import("picker_viewport.zig");
const sdl_text = @import("sdl_text.zig");
const sunglasses_state = @import("../sunglasses/state.zig");

const c = @import("sdl_c");

const default_monitor_name = "default";
pub const control_count: u32 = 8;
const value_column_width: f32 = 42;
const control_right_inset: f32 = picker_viewport.default_result_icon_right_inset;
const slider_height: f32 = 4;
const toggle_size: f32 = 16;
const knob_width: f32 = 8;
const knob_height: f32 = 20;
const text_font_px: u32 = 15;
const value_font_px: u32 = 14;

const Control = enum {
    monitor,
    red_blue_toggle,
    red_blue_slider,
    dim_toggle,
    dim_slider,
    image_toggle,
    image_opacity_slider,
    image_path,
};

pub const CommitResult = enum {
    no_change,
    changed,
    invalid,
};

pub const Form = struct {
    selected_monitor: u32 = 0,
    focus: Control = .monitor,
    path_edit_buf: [sunglasses_state.max_image_path_bytes]u8 = undefined,
    path_edit_len: u32 = 0,
    path_editing: bool = false,
    path_error: bool = false,

    pub fn ensureReady(self: *Form, state: *sunglasses_state.State) !void {
        if (state.count == 0) {
            const monitor = try state.ensureMonitor(default_monitor_name);
            if (monitor.name().len == 0) unreachable;
        }
        if (self.selected_monitor >= state.count) self.selected_monitor = 0;
    }

    pub fn focusNext(self: *Form, state: *sunglasses_state.State, reverse: bool) !void {
        try self.ensureReady(state);
        const current = controlIndex(self.focus);
        const next = if (reverse)
            (current + control_count - 1) % control_count
        else
            (current + 1) % control_count;
        self.setFocus(state, controlFromIndex(next));
    }

    pub fn focusAt(self: *Form, state: *sunglasses_state.State, layout: picker_viewport.ResultLayout, x: f32, y: f32) !bool {
        try self.ensureReady(state);
        const hit = controlAt(layout, x, y) orelse return false;
        const changed = self.focus != hit.control;
        self.setFocus(state, hit.control);
        return changed;
    }

    pub fn focusedControlChangesSavedState(self: *const Form) bool {
        return switch (self.focus) {
            .monitor,
            .image_path,
            => false,
            .red_blue_toggle,
            .red_blue_slider,
            .dim_toggle,
            .dim_slider,
            .image_toggle,
            .image_opacity_slider,
            => true,
        };
    }

    pub fn focusedPathInput(self: *const Form) bool {
        return self.focus == .image_path;
    }

    pub fn activateFocused(self: *Form, state: *sunglasses_state.State) !bool {
        try self.ensureReady(state);
        const monitor = currentMonitorMutable(state, self.selected_monitor);
        switch (self.focus) {
            .monitor => return self.selectNextMonitor(state),
            .red_blue_toggle => {
                monitor.red_blue_enabled = !monitor.red_blue_enabled;
                return true;
            },
            .dim_toggle => {
                monitor.dim_enabled = !monitor.dim_enabled;
                return true;
            },
            .image_toggle => {
                monitor.image_enabled = !monitor.image_enabled;
                return true;
            },
            .image_path => return false,
            else => return false,
        }
    }

    pub fn handleTextInput(self: *Form, state: *sunglasses_state.State, text: []const u8) !bool {
        try self.ensureReady(state);
        if (self.focus != .image_path) return false;
        self.seedPathEdit(currentMonitor(state, self.selected_monitor).imagePath());
        self.path_error = false;
        if (text.len == 0) return true;

        const remaining = sunglasses_state.max_image_path_bytes - self.path_edit_len;
        const copy_len: u32 = if (text.len > @as(@TypeOf(text.len), remaining)) remaining else @intCast(text.len);
        if (copy_len > 0) {
            const start = self.path_edit_len;
            const end = start + copy_len;
            @memcpy(self.path_edit_buf[start..end], text[0..copy_len]);
            self.path_edit_len = end;
        }
        if (text.len > @as(@TypeOf(text.len), copy_len)) self.path_error = true;
        return true;
    }

    pub fn handleBackspace(self: *Form, state: *sunglasses_state.State) !bool {
        try self.ensureReady(state);
        if (self.focus != .image_path) return false;
        self.seedPathEdit(currentMonitor(state, self.selected_monitor).imagePath());
        self.path_error = false;
        if (self.path_edit_len == 0) return true;
        self.path_edit_len = previousUtf8Start(self.pathEdit(), self.path_edit_len);
        return true;
    }

    pub fn commitFocused(self: *Form, state: *sunglasses_state.State) !CommitResult {
        try self.ensureReady(state);
        if (self.focus != .image_path) return .no_change;
        const monitor = currentMonitorMutable(state, self.selected_monitor);
        self.seedPathEdit(monitor.imagePath());
        const edit = self.pathEdit();

        if (edit.len == 0) {
            const changed = monitor.image_path_len != 0 or monitor.image_enabled;
            monitor.image_enabled = false;
            monitor.clearImagePath();
            self.path_error = false;
            self.path_editing = false;
            return if (changed) .changed else .no_change;
        }

        if (std.mem.eql(u8, monitor.imagePath(), edit)) {
            self.path_error = false;
            self.path_editing = false;
            return .no_change;
        }

        monitor.setImagePath(edit) catch {
            self.path_error = true;
            return .invalid;
        };
        self.path_error = false;
        self.path_editing = false;
        return .changed;
    }

    pub fn adjustFocused(self: *Form, state: *sunglasses_state.State, delta: i32) !bool {
        try self.ensureReady(state);
        const monitor = currentMonitorMutable(state, self.selected_monitor);
        switch (self.focus) {
            .monitor => return self.adjustSelectedMonitor(state, delta),
            .red_blue_slider => {
                const before = monitor.red_blue_value;
                monitor.setRedBlueValue(before + delta);
                return monitor.red_blue_value != before;
            },
            .dim_slider => {
                const before = monitor.dim_value;
                monitor.setDimValue(before + delta);
                return monitor.dim_value != before;
            },
            .image_opacity_slider => {
                const before = monitor.image_opacity;
                monitor.setImageOpacity(before + delta);
                return monitor.image_opacity != before;
            },
            else => return false,
        }
    }

    pub fn click(self: *Form, state: *sunglasses_state.State, layout: picker_viewport.ResultLayout, x: f32, y: f32) !bool {
        try self.ensureReady(state);
        const hit = controlAt(layout, x, y) orelse return false;
        self.setFocus(state, hit.control);
        const monitor = currentMonitorMutable(state, self.selected_monitor);
        switch (hit.control) {
            .red_blue_toggle => {
                monitor.red_blue_enabled = !monitor.red_blue_enabled;
                return true;
            },
            .dim_toggle => {
                monitor.dim_enabled = !monitor.dim_enabled;
                return true;
            },
            .image_toggle => {
                monitor.image_enabled = !monitor.image_enabled;
                return true;
            },
            .red_blue_slider => {
                const before = monitor.red_blue_value;
                monitor.setRedBlueValue(redBlueFromX(hit.row, x));
                return monitor.red_blue_value != before;
            },
            .dim_slider => {
                const before = monitor.dim_value;
                monitor.setDimValue(dimFromX(hit.row, x));
                return monitor.dim_value != before;
            },
            .image_opacity_slider => {
                const before = monitor.image_opacity;
                monitor.setImageOpacity(imageOpacityFromX(hit.row, x));
                return monitor.image_opacity != before;
            },
            .image_path => return false,
            .monitor => return self.selectNextMonitor(state),
        }
    }

    pub fn render(
        self: *Form,
        renderer: *c.SDL_Renderer,
        text: *sdl_text.TextEngine,
        layout: picker_viewport.ResultLayout,
        surface_scale: f32,
        state: *sunglasses_state.State,
    ) !void {
        try self.ensureReady(state);
        const monitor = currentMonitor(state, self.selected_monitor);
        try drawControlBackground(renderer, controlRow(layout, .monitor), self.focus == .monitor);
        try drawControlBackground(renderer, controlRow(layout, .red_blue_toggle), self.focus == .red_blue_toggle);
        try drawControlBackground(renderer, controlRow(layout, .red_blue_slider), self.focus == .red_blue_slider);
        try drawControlBackground(renderer, controlRow(layout, .dim_toggle), self.focus == .dim_toggle);
        try drawControlBackground(renderer, controlRow(layout, .dim_slider), self.focus == .dim_slider);
        try drawControlBackground(renderer, controlRow(layout, .image_toggle), self.focus == .image_toggle);
        try drawControlBackground(renderer, controlRow(layout, .image_opacity_slider), self.focus == .image_opacity_slider);
        try drawControlBackground(renderer, controlRow(layout, .image_path), self.focus == .image_path);

        try drawLabel(text, renderer, layout, .monitor, surface_scale, "Monitor");
        const monitor_row = controlRow(layout, .monitor);
        try text.draw(renderer, valueTextX(monitor_row), textY(layout, .monitor), monitor.name(), .{
            .color = .{ .r = 218, .g = 226, .b = 236 },
            .max_bytes = sunglasses_state.max_monitor_name_bytes,
            .font_size_px = text_font_px,
            .surface_scale = surface_scale,
        });

        try drawLabel(text, renderer, layout, .red_blue_toggle, surface_scale, "Red/Blue");
        try drawToggle(renderer, controlRow(layout, .red_blue_toggle), monitor.red_blue_enabled);
        try drawLabel(text, renderer, layout, .red_blue_slider, surface_scale, "Blue to red");
        try drawSignedSlider(renderer, controlRow(layout, .red_blue_slider), monitor.red_blue_value);
        try drawSignedValue(text, renderer, layout, .red_blue_slider, surface_scale, monitor.red_blue_value);

        try drawLabel(text, renderer, layout, .dim_toggle, surface_scale, "Dim");
        try drawToggle(renderer, controlRow(layout, .dim_toggle), monitor.dim_enabled);
        try drawLabel(text, renderer, layout, .dim_slider, surface_scale, "Dim amount");
        try drawUnsignedSlider(renderer, controlRow(layout, .dim_slider), monitor.dim_value);
        try drawUnsignedValue(text, renderer, layout, .dim_slider, surface_scale, monitor.dim_value);

        try drawLabel(text, renderer, layout, .image_toggle, surface_scale, "Image");
        try drawToggle(renderer, controlRow(layout, .image_toggle), monitor.image_enabled);
        try drawLabel(text, renderer, layout, .image_opacity_slider, surface_scale, "Image opacity");
        try drawImageOpacitySlider(renderer, controlRow(layout, .image_opacity_slider), monitor.image_opacity);
        try drawImageOpacityValue(text, renderer, layout, .image_opacity_slider, surface_scale, monitor.image_opacity);
        try drawLabel(text, renderer, layout, .image_path, surface_scale, "Image path");
        try self.drawPathValue(text, renderer, layout, surface_scale, monitor.imagePath());
    }

    fn setFocus(self: *Form, state: *sunglasses_state.State, control: Control) void {
        const changed = self.focus != control;
        self.focus = control;
        if (control == .image_path) {
            self.seedPathEdit(currentMonitor(state, self.selected_monitor).imagePath());
        } else if (changed) {
            self.path_editing = false;
            self.path_error = false;
        }
    }

    fn seedPathEdit(self: *Form, path: []const u8) void {
        if (self.path_editing) return;
        std.debug.assert(path.len <= sunglasses_state.max_image_path_bytes);
        @memcpy(self.path_edit_buf[0..path.len], path);
        self.path_edit_len = @intCast(path.len);
        self.path_editing = true;
        self.path_error = false;
    }

    fn pathEdit(self: *const Form) []const u8 {
        return self.path_edit_buf[0..self.path_edit_len];
    }

    fn drawPathValue(
        self: *const Form,
        text: *sdl_text.TextEngine,
        renderer: *c.SDL_Renderer,
        layout: picker_viewport.ResultLayout,
        surface_scale: f32,
        saved_path: []const u8,
    ) !void {
        const row = controlRow(layout, .image_path);
        const value = if (self.focus == .image_path and self.path_error)
            "invalid path"
        else if (self.focus == .image_path and self.path_editing and self.path_edit_len == 0)
            "empty clears"
        else if (self.focus == .image_path and self.path_editing)
            self.pathEdit()
        else
            pathSummary(saved_path);
        const color = if (self.focus == .image_path and self.path_error)
            sdl_text.Rgba8{ .r = 238, .g = 142, .b = 142 }
        else
            sdl_text.Rgba8{ .r = 186, .g = 202, .b = 224 };
        try text.draw(renderer, valueTextX(row), textY(layout, .image_path), value, .{
            .color = color,
            .max_bytes = sunglasses_state.max_image_path_bytes,
            .font_size_px = value_font_px,
            .surface_scale = surface_scale,
        });
    }

    fn adjustSelectedMonitor(self: *Form, state: *const sunglasses_state.State, delta: i32) bool {
        if (state.count <= 1) return false;
        const before = self.selected_monitor;
        const last = state.count - 1;
        if (delta < 0) {
            self.selected_monitor -= @min(self.selected_monitor, negativeMagnitude(delta));
        } else {
            const amount: u32 = @intCast(delta);
            self.selected_monitor = @min(last, self.selected_monitor + @min(last - self.selected_monitor, amount));
        }
        return self.selected_monitor != before;
    }

    fn selectNextMonitor(self: *Form, state: *const sunglasses_state.State) bool {
        if (state.count <= 1) return false;
        self.selected_monitor = (self.selected_monitor + 1) % state.count;
        return true;
    }
};

fn currentMonitor(state: *const sunglasses_state.State, selected_monitor: u32) *const sunglasses_state.MonitorState {
    return state.monitorAt(selected_monitor) orelse unreachable;
}

fn currentMonitorMutable(state: *sunglasses_state.State, selected_monitor: u32) *sunglasses_state.MonitorState {
    return state.monitorAtMutable(selected_monitor) orelse unreachable;
}

const Hit = struct {
    control: Control,
    row: picker_viewport.Rect,
};

fn controlIndex(control: Control) u32 {
    return switch (control) {
        .monitor => 0,
        .red_blue_toggle => 1,
        .red_blue_slider => 2,
        .dim_toggle => 3,
        .dim_slider => 4,
        .image_toggle => 5,
        .image_opacity_slider => 6,
        .image_path => 7,
    };
}

fn controlFromIndex(index: u32) Control {
    std.debug.assert(index < control_count);
    return switch (index) {
        0 => .monitor,
        1 => .red_blue_toggle,
        2 => .red_blue_slider,
        3 => .dim_toggle,
        4 => .dim_slider,
        5 => .image_toggle,
        6 => .image_opacity_slider,
        else => .image_path,
    };
}

fn controlRow(layout: picker_viewport.ResultLayout, control: Control) picker_viewport.Rect {
    return controlRowAtIndex(layout, controlIndex(control));
}

fn controlRowAtIndex(layout: picker_viewport.ResultLayout, index: u32) picker_viewport.Rect {
    std.debug.assert(index < control_count);
    const row_step = layout.row_height + layout.row_gap;
    const y = layout.result_top + row_step * @as(f32, @floatFromInt(index));
    return .{ .x = layout.row_x, .y = y, .w = layout.row_width, .h = layout.row_height };
}

fn textY(layout: picker_viewport.ResultLayout, control: Control) f32 {
    const row = controlRow(layout, control);
    return row.y + (row.h - layout.title_line_height) / 2;
}

fn controlAt(layout: picker_viewport.ResultLayout, x: f32, y: f32) ?Hit {
    const row_index = controlIndexAtPoint(layout, x, y) orelse return null;
    if (row_index >= control_count) return null;
    const control = controlFromIndex(row_index);
    return .{ .control = control, .row = controlRow(layout, control) };
}

fn controlIndexAtPoint(layout: picker_viewport.ResultLayout, x: f32, y: f32) ?u32 {
    if (x < layout.row_x or x >= layout.row_x + layout.row_width) return null;
    if (y < layout.result_top) return null;

    const row_step = layout.row_height + layout.row_gap;
    if (row_step <= 0) return null;

    const row_float = @floor((y - layout.result_top) / row_step);
    if (row_float >= @as(f32, @floatFromInt(control_count))) return null;

    const row: u32 = @intFromFloat(row_float);
    const top = layout.result_top + row_step * @as(f32, @floatFromInt(row));
    return if (y < top + layout.row_height) row else null;
}

fn drawControlBackground(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, focused: bool) !void {
    const shade: u8 = if (focused) 64 else 31;
    const color = c.SDL_SetRenderDrawColor(renderer, shade, shade, if (focused) 82 else 38, 255);
    const rect = c.SDL_FRect{ .x = row.x, .y = row.y, .w = row.w, .h = row.h };
    const filled = c.SDL_RenderFillRect(renderer, &rect);
    if (!color or !filled) return error.SdlRenderFailed;
}

fn drawLabel(
    text: *sdl_text.TextEngine,
    renderer: *c.SDL_Renderer,
    layout: picker_viewport.ResultLayout,
    control: Control,
    surface_scale: f32,
    value: []const u8,
) !void {
    try text.draw(renderer, layout.title_x, textY(layout, control), value, .{
        .color = .{ .r = 216, .g = 222, .b = 230 },
        .max_bytes = 32,
        .font_size_px = text_font_px,
        .surface_scale = surface_scale,
    });
}

fn drawToggle(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, enabled: bool) !void {
    const box = toggleRect(row);
    const border_color = c.SDL_SetRenderDrawColor(renderer, 112, 126, 144, 255);
    const border_rect = c.SDL_FRect{ .x = box.x, .y = box.y, .w = box.w, .h = box.h };
    const border_drawn = c.SDL_RenderRect(renderer, &border_rect);
    if (!border_color or !border_drawn) return error.SdlRenderFailed;
    if (!enabled) return;

    const fill_color = c.SDL_SetRenderDrawColor(renderer, 222, 231, 242, 255);
    const inset = c.SDL_FRect{ .x = box.x + 4, .y = box.y + 4, .w = box.w - 8, .h = box.h - 8 };
    const filled = c.SDL_RenderFillRect(renderer, &inset);
    if (!fill_color or !filled) return error.SdlRenderFailed;
}

fn drawSignedSlider(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, value: i32) !void {
    const track = sliderTrack(row);
    try drawSliderTrack(renderer, track);
    const normalized = @as(f32, @floatFromInt(sunglasses_state.clampRedBlue(value) - sunglasses_state.red_blue_min)) /
        @as(f32, @floatFromInt(sunglasses_state.red_blue_max - sunglasses_state.red_blue_min));
    try drawSliderKnob(renderer, track, normalized);
}

fn drawUnsignedSlider(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, value: i32) !void {
    const track = sliderTrack(row);
    try drawSliderTrack(renderer, track);
    const normalized = @as(f32, @floatFromInt(sunglasses_state.clampDim(value) - sunglasses_state.dim_min)) /
        @as(f32, @floatFromInt(sunglasses_state.dim_max - sunglasses_state.dim_min));
    try drawSliderKnob(renderer, track, normalized);
}

fn drawImageOpacitySlider(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, value: i32) !void {
    const track = sliderTrack(row);
    try drawSliderTrack(renderer, track);
    const normalized = @as(f32, @floatFromInt(sunglasses_state.clampImageOpacity(value) - sunglasses_state.image_opacity_min)) /
        @as(f32, @floatFromInt(sunglasses_state.image_opacity_max - sunglasses_state.image_opacity_min));
    try drawSliderKnob(renderer, track, normalized);
}

fn drawSliderTrack(renderer: *c.SDL_Renderer, track: picker_viewport.Rect) !void {
    const color = c.SDL_SetRenderDrawColor(renderer, 92, 104, 120, 255);
    const rect = c.SDL_FRect{ .x = track.x, .y = track.y, .w = track.w, .h = track.h };
    const filled = c.SDL_RenderFillRect(renderer, &rect);
    if (!color or !filled) return error.SdlRenderFailed;
}

fn drawSliderKnob(renderer: *c.SDL_Renderer, track: picker_viewport.Rect, normalized: f32) !void {
    const x = track.x + (track.w * @min(1, @max(0, normalized))) - (knob_width / 2);
    const y = track.y + (track.h / 2) - (knob_height / 2);
    const color = c.SDL_SetRenderDrawColor(renderer, 228, 235, 244, 255);
    const rect = c.SDL_FRect{ .x = x, .y = y, .w = knob_width, .h = knob_height };
    const filled = c.SDL_RenderFillRect(renderer, &rect);
    if (!color or !filled) return error.SdlRenderFailed;
}

fn drawSignedValue(
    text: *sdl_text.TextEngine,
    renderer: *c.SDL_Renderer,
    layout: picker_viewport.ResultLayout,
    control: Control,
    surface_scale: f32,
    value: i32,
) !void {
    var buf: [16]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&buf, "{d}", .{sunglasses_state.clampRedBlue(value)});
    const row = controlRow(layout, control);
    try text.draw(renderer, valueTextX(row), textY(layout, control), rendered, .{
        .color = .{ .r = 186, .g = 202, .b = 224 },
        .max_bytes = 16,
        .font_size_px = value_font_px,
        .surface_scale = surface_scale,
    });
}

fn drawUnsignedValue(
    text: *sdl_text.TextEngine,
    renderer: *c.SDL_Renderer,
    layout: picker_viewport.ResultLayout,
    control: Control,
    surface_scale: f32,
    value: i32,
) !void {
    var buf: [16]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&buf, "{d}", .{sunglasses_state.clampDim(value)});
    const row = controlRow(layout, control);
    try text.draw(renderer, valueTextX(row), textY(layout, control), rendered, .{
        .color = .{ .r = 186, .g = 202, .b = 224 },
        .max_bytes = 16,
        .font_size_px = value_font_px,
        .surface_scale = surface_scale,
    });
}

fn drawImageOpacityValue(
    text: *sdl_text.TextEngine,
    renderer: *c.SDL_Renderer,
    layout: picker_viewport.ResultLayout,
    control: Control,
    surface_scale: f32,
    value: i32,
) !void {
    var buf: [16]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&buf, "{d}", .{sunglasses_state.clampImageOpacity(value)});
    const row = controlRow(layout, control);
    try text.draw(renderer, valueTextX(row), textY(layout, control), rendered, .{
        .color = .{ .r = 186, .g = 202, .b = 224 },
        .max_bytes = 16,
        .font_size_px = value_font_px,
        .surface_scale = surface_scale,
    });
}

fn toggleRect(row: picker_viewport.Rect) picker_viewport.Rect {
    return .{
        .x = valueTextX(row),
        .y = row.y + (row.h - toggle_size) / 2,
        .w = toggle_size,
        .h = toggle_size,
    };
}

fn sliderTrack(row: picker_viewport.Rect) picker_viewport.Rect {
    const track_x = valueTextX(row) + value_column_width;
    const track_right = row.x + row.w - control_right_inset;
    return .{
        .x = track_x,
        .y = row.y + (row.h - slider_height) / 2,
        .w = @max(1, track_right - track_x),
        .h = slider_height,
    };
}

fn valueTextX(row: picker_viewport.Rect) f32 {
    return row.x + @max(122, row.w * 0.28);
}

fn redBlueFromX(row: picker_viewport.Rect, x: f32) i32 {
    const track = sliderTrack(row);
    const normalized = @min(1, @max(0, (x - track.x) / track.w));
    const span = sunglasses_state.red_blue_max - sunglasses_state.red_blue_min;
    return sunglasses_state.clampRedBlue(sunglasses_state.red_blue_min + @as(i32, @intFromFloat(@round(normalized * @as(f32, @floatFromInt(span))))));
}

fn dimFromX(row: picker_viewport.Rect, x: f32) i32 {
    const track = sliderTrack(row);
    const normalized = @min(1, @max(0, (x - track.x) / track.w));
    const span = sunglasses_state.dim_max - sunglasses_state.dim_min;
    return sunglasses_state.clampDim(sunglasses_state.dim_min + @as(i32, @intFromFloat(@round(normalized * @as(f32, @floatFromInt(span))))));
}

fn imageOpacityFromX(row: picker_viewport.Rect, x: f32) i32 {
    const track = sliderTrack(row);
    const normalized = @min(1, @max(0, (x - track.x) / track.w));
    const span = sunglasses_state.image_opacity_max - sunglasses_state.image_opacity_min;
    return sunglasses_state.clampImageOpacity(sunglasses_state.image_opacity_min + @as(i32, @intFromFloat(@round(normalized * @as(f32, @floatFromInt(span))))));
}

fn pathSummary(path: []const u8) []const u8 {
    if (path.len == 0) return "not set";
    return std.fs.path.basename(path);
}

fn previousUtf8Start(text: []const u8, end: u32) u32 {
    std.debug.assert(text.len >= @as(@TypeOf(text.len), end));
    if (end == 0) return 0;
    var index = end - 1;
    while (index > 0 and (text[index] & 0b1100_0000) == 0b1000_0000) : (index -= 1) {}
    return index;
}

fn negativeMagnitude(delta: i32) u32 {
    std.debug.assert(delta < 0);
    return @as(u32, @intCast(-(delta + 1))) + 1;
}

test "form ensures a default monitor and mutates bounded controls" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    try std.testing.expectEqual(@as(u32, 1), state.count);
    try std.testing.expectEqualStrings(default_monitor_name, state.monitors[0].name());

    form.focus = .red_blue_toggle;
    try std.testing.expect(try form.activateFocused(&state));
    try std.testing.expect(state.monitors[0].red_blue_enabled);

    form.focus = .red_blue_slider;
    try std.testing.expect(try form.adjustFocused(&state, 250));
    try std.testing.expectEqual(sunglasses_state.red_blue_max, state.monitors[0].red_blue_value);

    form.focus = .dim_slider;
    try std.testing.expect(try form.adjustFocused(&state, 250));
    try std.testing.expectEqual(sunglasses_state.dim_max, state.monitors[0].dim_value);

    form.focus = .image_toggle;
    try std.testing.expect(try form.activateFocused(&state));
    try std.testing.expect(state.monitors[0].image_enabled);

    form.focus = .image_opacity_slider;
    try std.testing.expect(try form.adjustFocused(&state, 250));
    try std.testing.expectEqual(sunglasses_state.image_opacity_max, state.monitors[0].image_opacity);
}

test "form focus wraps in both directions" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.focusNext(&state, false);
    try std.testing.expectEqual(Control.red_blue_toggle, form.focus);
    try form.focusNext(&state, true);
    try std.testing.expectEqual(Control.monitor, form.focus);
    try form.focusNext(&state, true);
    try std.testing.expectEqual(Control.image_path, form.focus);
}

test "monitor row activation and click cycle monitors" {
    var state = sunglasses_state.defaultState();
    try state.append(try sunglasses_state.MonitorState.init("HDMI-A-1"));
    try state.append(try sunglasses_state.MonitorState.init("DP-1"));
    var form = Form{};

    form.focus = .monitor;
    try std.testing.expect(try form.activateFocused(&state));
    try std.testing.expectEqual(@as(u32, 1), form.selected_monitor);

    const layout = picker_viewport.ResultLayout.default(control_count);
    try std.testing.expect(try form.click(&state, layout, layout.row_x + 20, layout.result_top + 20));
    try std.testing.expectEqual(@as(u32, 0), form.selected_monitor);
}

test "form hit testing follows picker row geometry and gaps" {
    var state = sunglasses_state.defaultState();
    var form = Form{};
    const layout = picker_viewport.ResultLayout.default(control_count);
    const slider = layout.rowRect(2);
    const gap_y = slider.y - (picker_viewport.default_result_row_gap / 2);

    try form.ensureReady(&state);
    try std.testing.expect(!try form.click(&state, layout, slider.x + 20, gap_y));
    try std.testing.expectEqual(Control.monitor, form.focus);

    try std.testing.expect(try form.focusAt(&state, layout, slider.x + 20, slider.y + 2));
    try std.testing.expectEqual(Control.red_blue_slider, form.focus);
    try std.testing.expect(try form.click(&state, layout, slider.x + slider.w - 2, slider.y + (slider.h / 2)));
    try std.testing.expectEqual(sunglasses_state.red_blue_max, state.monitors[0].red_blue_value);
}

test "form hit testing keeps all controls when result rows clamp below count" {
    const layout = picker_viewport.ResultLayout.forWindow(
        picker_viewport.default_base_width,
        picker_viewport.min_base_height,
        control_count,
    );
    try std.testing.expect(layout.visible_rows < control_count);

    var index: u32 = 0;
    while (index < control_count) : (index += 1) {
        const control = controlFromIndex(index);
        const row = controlRow(layout, control);
        try std.testing.expectEqual(layout.row_x, row.x);
        try std.testing.expectEqual(layout.row_width, row.w);
        try std.testing.expectEqual(layout.row_height, row.h);

        const hit = controlAt(layout, row.x + 2, row.y + (row.h / 2)) orelse return error.ExpectedFormControlHit;
        try std.testing.expectEqual(control, hit.control);
    }
}

test "monitor-only focus changes do not require saved state" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    try std.testing.expect(!form.focusedControlChangesSavedState());
    form.focus = .red_blue_toggle;
    try std.testing.expect(form.focusedControlChangesSavedState());
    form.focus = .monitor;
    try std.testing.expect(!try form.activateFocused(&state));
    try std.testing.expect(!form.focusedControlChangesSavedState());
}

test "image path text input appends within bounded edit buffer" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    form.focus = .image_path;

    try std.testing.expect(try form.handleTextInput(&state, "/tmp/"));
    try std.testing.expect(try form.handleTextInput(&state, "overlay.png"));
    try std.testing.expectEqualStrings("/tmp/overlay.png", form.pathEdit());

    form.path_edit_len = sunglasses_state.max_image_path_bytes - 1;
    try std.testing.expect(try form.handleTextInput(&state, "abcdef"));
    try std.testing.expectEqual(sunglasses_state.max_image_path_bytes, form.path_edit_len);
    try std.testing.expect(form.path_error);
}

test "image path backspace deletes from edit buffer" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    form.focus = .image_path;
    try std.testing.expect(try form.handleTextInput(&state, "/tmp/a.png"));
    try std.testing.expect(try form.handleBackspace(&state));
    try std.testing.expectEqualStrings("/tmp/a.pn", form.pathEdit());
}

test "image path commit saves valid absolute path" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    form.focus = .image_path;
    try std.testing.expect(try form.handleTextInput(&state, "/tmp/wayspot-overlay.png"));

    try std.testing.expectEqual(CommitResult.changed, try form.commitFocused(&state));
    try std.testing.expectEqualStrings("/tmp/wayspot-overlay.png", state.monitors[0].imagePath());
    try std.testing.expect(!form.path_error);
}

test "image path empty commit clears path and disables image" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    state.monitors[0].image_enabled = true;
    try state.monitors[0].setImagePath("/tmp/wayspot-overlay.png");
    form.focus = .image_path;
    form.seedPathEdit(state.monitors[0].imagePath());
    form.path_edit_len = 0;

    try std.testing.expectEqual(CommitResult.changed, try form.commitFocused(&state));
    try std.testing.expect(!state.monitors[0].image_enabled);
    try std.testing.expectEqualStrings("", state.monitors[0].imagePath());
}

test "image path invalid commit keeps focus and state unchanged" {
    var state = sunglasses_state.defaultState();
    var form = Form{};

    try form.ensureReady(&state);
    try state.monitors[0].setImagePath("/tmp/old.png");
    form.focus = .image_path;
    form.seedPathEdit(state.monitors[0].imagePath());
    form.path_edit_len = 0;
    try std.testing.expect(try form.handleTextInput(&state, "relative.png"));

    try std.testing.expectEqual(CommitResult.invalid, try form.commitFocused(&state));
    try std.testing.expectEqualStrings("/tmp/old.png", state.monitors[0].imagePath());
    try std.testing.expect(form.path_error);
    try std.testing.expect(form.focusedPathInput());
}

test "image opacity hit testing uses bounded slider range" {
    var state = sunglasses_state.defaultState();
    var form = Form{};
    const layout = picker_viewport.ResultLayout.default(control_count);
    const row = controlRow(layout, .image_opacity_slider);

    try form.ensureReady(&state);
    try std.testing.expect(try form.click(&state, layout, row.x + row.w - 2, row.y + (row.h / 2)));
    try std.testing.expectEqual(Control.image_opacity_slider, form.focus);
    try std.testing.expectEqual(sunglasses_state.image_opacity_max, state.monitors[0].image_opacity);
}
