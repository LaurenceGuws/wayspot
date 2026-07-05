//! Product appearance maps bounded defaults onto current Wayspot UI surfaces.

const std = @import("std");
const control_values = @import("controls/appearance.zig");

pub const Rgba8 = control_values.Rgba8;

/// TextAppearance couples a color with a bounded font size.
pub const TextAppearance = struct {
    color: Rgba8,
    font_px: u16,
};

/// FontAppearance owns the ordered fallback list consumed by the text engine.
pub const FontAppearance = struct {
    candidates: control_values.FontCandidates,
    default_px: u16,
};

/// PickerAppearance names only the launcher picker appearance values used today.
pub const PickerAppearance = struct {
    background: Rgba8,
    query_placeholder: TextAppearance,
    query_text: TextAppearance,
    query_cursor: Rgba8,
    query_divider: Rgba8,
    row_selected_fill: Rgba8,
    row_normal_fill: Rgba8,
    title_selected: TextAppearance,
    title_normal: TextAppearance,
    subtitle_selected: TextAppearance,
    subtitle_normal: TextAppearance,
    empty_text: TextAppearance,
    scrollbar_track: Rgba8,
    scrollbar_thumb: Rgba8,
};

/// BannerAppearance names the notification banner colors, text, and small chrome.
pub const BannerAppearance = struct {
    critical_background: Rgba8,
    low_background: Rgba8,
    normal_background: Rgba8,
    accent: Rgba8,
    accent_w: f32,
    app_text: TextAppearance,
    summary_text: TextAppearance,
    body_text: TextAppearance,
    content_x: f32,
    app_top: f32,
    summary_top: f32,
    body_top: f32,
};

/// SunglassesFormAppearance names the picker-pane form values used by the sunglasses controls.
pub const SunglassesFormAppearance = struct {
    value_gap: f32,
    track_h: f32,
    toggle_box: f32,
    knob_w: f32,
    knob_h: f32,
    toggle_pad: f32,
    value_min_x: f32,
    value_fraction: f32,
    label_px: u16,
    value_px: u16,
    monitor_value: Rgba8,
    path_error: Rgba8,
    form_value: Rgba8,
    focused_row_fill: Rgba8,
    normal_row_fill: Rgba8,
    label: Rgba8,
    toggle_border: Rgba8,
    toggle_fill: Rgba8,
    slider_track: Rgba8,
    slider_knob: Rgba8,
};

/// Appearance is the complete bounded UI appearance state consumed by current renderers.
pub const Appearance = struct {
    fonts: FontAppearance,
    picker: PickerAppearance,
    banner: BannerAppearance,
    sunglasses_form: SunglassesFormAppearance,
};

/// currentHardcodedDefaults mirrors the pre-config renderer defaults for parser tests.
pub fn currentHardcodedDefaults() !Appearance {
    var fonts = control_values.FontCandidates{};
    try fonts.append("/usr/share/fonts/TTF/IosevkaTermNerdFont-Regular.ttf");
    try fonts.append("/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf");
    try fonts.append("/usr/share/fonts/noto/NotoSans-Regular.ttf");
    try fonts.append("/usr/share/fonts/TTF/DejaVuSans.ttf");

    return .{
        .fonts = .{
            .candidates = fonts,
            .default_px = 17,
        },
        .picker = .{
            .background = rgba(18, 18, 22, 255),
            .query_placeholder = text(rgba(96, 108, 124, 255), 17),
            .query_text = text(rgba(168, 185, 204, 255), 17),
            .query_cursor = rgba(214, 226, 244, 255),
            .query_divider = rgba(64, 74, 84, 255),
            .row_selected_fill = rgba(64, 64, 82, 255),
            .row_normal_fill = rgba(31, 31, 38, 255),
            .title_selected = text(rgba(246, 248, 252, 255), 17),
            .title_normal = text(rgba(216, 222, 230, 255), 17),
            .subtitle_selected = text(rgba(186, 202, 224, 255), 14),
            .subtitle_normal = text(rgba(140, 152, 166, 255), 14),
            .empty_text = text(rgba(190, 198, 208, 255), 17),
            .scrollbar_track = rgba(38, 44, 52, 255),
            .scrollbar_thumb = rgba(104, 118, 136, 255),
        },
        .banner = .{
            .critical_background = rgba(70, 22, 26, 242),
            .low_background = rgba(20, 24, 27, 242),
            .normal_background = rgba(24, 28, 34, 242),
            .accent = rgba(105, 184, 150, 255),
            .accent_w = 2,
            .app_text = text(rgba(150, 166, 184, 255), 13),
            .summary_text = text(rgba(238, 242, 247, 255), 18),
            .body_text = text(rgba(188, 198, 210, 255), 15),
            .content_x = 8,
            .app_top = 6,
            .summary_top = 24,
            .body_top = 50,
        },
        .sunglasses_form = .{
            .value_gap = 42,
            .track_h = 4,
            .toggle_box = 16,
            .knob_w = 8,
            .knob_h = 20,
            .toggle_pad = 4,
            .value_min_x = 122,
            .value_fraction = 0.28,
            .label_px = 15,
            .value_px = 14,
            .monitor_value = rgba(218, 226, 236, 255),
            .path_error = rgba(238, 142, 142, 255),
            .form_value = rgba(186, 202, 224, 255),
            .focused_row_fill = rgba(64, 64, 82, 255),
            .normal_row_fill = rgba(31, 31, 38, 255),
            .label = rgba(216, 222, 230, 255),
            .toggle_border = rgba(112, 126, 144, 255),
            .toggle_fill = rgba(222, 231, 242, 255),
            .slider_track = rgba(92, 104, 120, 255),
            .slider_knob = rgba(228, 235, 244, 255),
        },
    };
}

fn rgba(r: u8, g: u8, b: u8, a: u8) Rgba8 {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

fn text(color: Rgba8, font_px: u16) TextAppearance {
    return .{ .color = color, .font_px = font_px };
}

test "named product defaults preserve current picker appearance" {
    const defaults = try currentHardcodedDefaults();
    try std.testing.expectEqual(Rgba8{ .r = 18, .g = 18, .b = 22, .a = 255 }, defaults.picker.background);
    try std.testing.expectEqual(Rgba8{ .r = 246, .g = 248, .b = 252, .a = 255 }, defaults.picker.title_selected.color);
    try std.testing.expectEqual(@as(u16, 14), defaults.picker.subtitle_normal.font_px);
}

test "named product defaults preserve banner and form appearance" {
    const defaults = try currentHardcodedDefaults();
    try std.testing.expectEqual(Rgba8{ .r = 70, .g = 22, .b = 26, .a = 242 }, defaults.banner.critical_background);
    try std.testing.expectEqual(@as(f32, 2), defaults.banner.accent_w);
    try std.testing.expectEqual(Rgba8{ .r = 218, .g = 226, .b = 236, .a = 255 }, defaults.sunglasses_form.monitor_value);
    try std.testing.expectEqual(@as(f32, 0.28), defaults.sunglasses_form.value_fraction);
}
