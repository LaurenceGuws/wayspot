//! Sunglasses form owns picker-pane controls for in-memory filter state edits.

const std = @import("std");
const picker_viewport = @import("picker_viewport.zig");
const sdl_text = @import("sdl_text.zig");
const sunglasses_state = @import("../sunglasses/state.zig");

const c = @import("sdl_c");

const default_monitor_name = "default";
const control_count: u32 = 5;
const row_height: f32 = 42;
const row_gap: f32 = 2;
const label_x_offset: f32 = 10;
const value_column_width: f32 = 46;
const control_right_inset: f32 = 12;
const form_text_line_height: f32 = 18;
const slider_height: f32 = 4;
const toggle_size: f32 = 16;
const knob_width: f32 = 8;
const knob_height: f32 = 20;

const Control = enum {
    monitor,
    red_blue_toggle,
    red_blue_slider,
    dim_toggle,
    dim_slider,
};

pub const Form = struct {
    selected_monitor: u32 = 0,
    focus: Control = .monitor,

    pub fn ensureReady(self: *Form, state: *sunglasses_state.State) !void {
        if (state.count == 0) {
            const monitor = try state.ensureMonitor(default_monitor_name);
            if (monitor.name().len == 0) unreachable;
        }
        if (self.selected_monitor >= state.count) self.selected_monitor = 0;
    }

    pub fn focusNext(self: *Form, reverse: bool) void {
        const current = controlIndex(self.focus);
        const next = if (reverse)
            (current + control_count - 1) % control_count
        else
            (current + 1) % control_count;
        self.focus = controlFromIndex(next);
    }

    pub fn focusedControlChangesSavedState(self: *const Form) bool {
        return switch (self.focus) {
            .monitor => false,
            .red_blue_toggle, .red_blue_slider, .dim_toggle, .dim_slider => true,
        };
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
            else => return false,
        }
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
            else => return false,
        }
    }

    pub fn click(self: *Form, state: *sunglasses_state.State, layout: picker_viewport.ResultLayout, x: f32, y: f32) !bool {
        try self.ensureReady(state);
        const hit = controlAt(layout, x, y) orelse return false;
        self.focus = hit.control;
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

        try drawText(text, renderer, layout, .monitor, surface_scale, "Monitor");
        const monitor_row = controlRow(layout, .monitor);
        try text.draw(renderer, valueX(monitor_row), textY(layout, .monitor), monitor.name(), .{
            .color = .{ .r = 218, .g = 226, .b = 236 },
            .max_bytes = sunglasses_state.max_monitor_name_bytes,
            .font_size_px = 15,
            .surface_scale = surface_scale,
        });

        try drawText(text, renderer, layout, .red_blue_toggle, surface_scale, "Red/Blue");
        try drawToggle(renderer, controlRow(layout, .red_blue_toggle), monitor.red_blue_enabled);
        try drawText(text, renderer, layout, .red_blue_slider, surface_scale, "Blue to red");
        try drawSignedSlider(renderer, controlRow(layout, .red_blue_slider), monitor.red_blue_value);
        try drawSignedValue(text, renderer, layout, .red_blue_slider, surface_scale, monitor.red_blue_value);

        try drawText(text, renderer, layout, .dim_toggle, surface_scale, "Dim");
        try drawToggle(renderer, controlRow(layout, .dim_toggle), monitor.dim_enabled);
        try drawText(text, renderer, layout, .dim_slider, surface_scale, "Dim amount");
        try drawUnsignedSlider(renderer, controlRow(layout, .dim_slider), monitor.dim_value);
        try drawUnsignedValue(text, renderer, layout, .dim_slider, surface_scale, monitor.dim_value);
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
    };
}

fn controlFromIndex(index: u32) Control {
    std.debug.assert(index < control_count);
    return switch (index) {
        0 => .monitor,
        1 => .red_blue_toggle,
        2 => .red_blue_slider,
        3 => .dim_toggle,
        else => .dim_slider,
    };
}

fn controlRow(layout: picker_viewport.ResultLayout, control: Control) picker_viewport.Rect {
    const index = controlIndex(control);
    const y = layout.result_top + @as(f32, @floatFromInt(index)) * (row_height + row_gap);
    return .{ .x = layout.row_x, .y = y, .w = layout.row_width, .h = row_height };
}

fn textY(layout: picker_viewport.ResultLayout, control: Control) f32 {
    const row = controlRow(layout, control);
    return row.y + (row.h - form_text_line_height) / 2;
}

fn controlAt(layout: picker_viewport.ResultLayout, x: f32, y: f32) ?Hit {
    var index: u32 = 0;
    while (index < control_count) : (index += 1) {
        const control = controlFromIndex(index);
        const row = controlRow(layout, control);
        if (x >= row.x and x < row.x + row.w and y >= row.y and y < row.y + row.h) {
            return .{ .control = control, .row = row };
        }
    }
    return null;
}

fn drawControlBackground(renderer: *c.SDL_Renderer, row: picker_viewport.Rect, focused: bool) !void {
    const shade: u8 = if (focused) 64 else 31;
    const color = c.SDL_SetRenderDrawColor(renderer, shade, shade, if (focused) 82 else 38, 255);
    const rect = c.SDL_FRect{ .x = row.x, .y = row.y, .w = row.w, .h = row.h };
    const filled = c.SDL_RenderFillRect(renderer, &rect);
    if (!color or !filled) return error.SdlRenderFailed;
}

fn drawText(
    text: *sdl_text.TextEngine,
    renderer: *c.SDL_Renderer,
    layout: picker_viewport.ResultLayout,
    control: Control,
    surface_scale: f32,
    value: []const u8,
) !void {
    const row = controlRow(layout, control);
    try text.draw(renderer, row.x + label_x_offset, textY(layout, control), value, .{
        .color = .{ .r = 216, .g = 222, .b = 230 },
        .max_bytes = 32,
        .font_size_px = 15,
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
    try text.draw(renderer, valueX(row), textY(layout, control), rendered, .{
        .color = .{ .r = 186, .g = 202, .b = 224 },
        .max_bytes = 16,
        .font_size_px = 15,
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
    try text.draw(renderer, valueX(row), textY(layout, control), rendered, .{
        .color = .{ .r = 186, .g = 202, .b = 224 },
        .max_bytes = 16,
        .font_size_px = 15,
        .surface_scale = surface_scale,
    });
}

fn toggleRect(row: picker_viewport.Rect) picker_viewport.Rect {
    return .{
        .x = valueX(row),
        .y = row.y + (row.h - toggle_size) / 2,
        .w = toggle_size,
        .h = toggle_size,
    };
}

fn sliderTrack(row: picker_viewport.Rect) picker_viewport.Rect {
    const track_x = valueX(row) + value_column_width;
    const track_right = row.x + row.w - control_right_inset;
    return .{
        .x = track_x,
        .y = row.y + (row.h - slider_height) / 2,
        .w = @max(1, track_right - track_x),
        .h = slider_height,
    };
}

fn valueX(row: picker_viewport.Rect) f32 {
    return row.x + @max(132, row.w * 0.32);
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
}

test "form focus wraps in both directions" {
    var form = Form{};

    form.focusNext(false);
    try std.testing.expectEqual(Control.red_blue_toggle, form.focus);
    form.focusNext(true);
    try std.testing.expectEqual(Control.monitor, form.focus);
    form.focusNext(true);
    try std.testing.expectEqual(Control.dim_slider, form.focus);
}

test "monitor row activation and click cycle monitors" {
    var state = sunglasses_state.defaultState();
    try state.append(try sunglasses_state.MonitorState.init("HDMI-A-1"));
    try state.append(try sunglasses_state.MonitorState.init("DP-1"));
    var form = Form{};

    form.focus = .monitor;
    try std.testing.expect(try form.activateFocused(&state));
    try std.testing.expectEqual(@as(u32, 1), form.selected_monitor);

    const layout = picker_viewport.ResultLayout.default(5);
    try std.testing.expect(try form.click(&state, layout, layout.row_x + 20, layout.result_top + 20));
    try std.testing.expectEqual(@as(u32, 0), form.selected_monitor);
}
