//! Picker appearance owns bounded visual values consumed by Wayspot surfaces.

const std = @import("std");

pub const max_font_candidates: u32 = 8;
pub const max_string_bytes: u32 = 240;
pub const min_font_px: u16 = 8;
pub const max_font_px: u16 = 48;
pub const min_chrome_px: f32 = 0;
pub const max_chrome_px: f32 = 96;
pub const max_layout_px: f32 = 240;
pub const min_opacity: f32 = 0;
pub const max_opacity: f32 = 1;

/// Rgba8 stores one bounded sRGB color with an explicit alpha byte.
pub const Rgba8 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    /// Builds a color only when every component is within the byte range.
    pub fn fromComponents(r: i64, g: i64, b: i64, a: i64) !Rgba8 {
        return .{
            .r = try byteComponent(r),
            .g = try byteComponent(g),
            .b = try byteComponent(b),
            .a = try byteComponent(a),
        };
    }
};

/// FontCandidate owns one zero-terminated path or family candidate.
pub const FontCandidate = struct {
    bytes: [max_string_bytes + 1]u8 = [_]u8{0} ** (max_string_bytes + 1),
    len: u16 = 0,

    /// Replaces the candidate text, rejecting overlong strings.
    pub fn set(self: *FontCandidate, value: []const u8) !void {
        if (value.len == 0) return error.EmptyString;
        if (value.len > max_string_bytes) return error.StringTooLong;
        @memset(&self.bytes, 0);
        @memcpy(self.bytes[0..value.len], value);
        self.len = @intCast(value.len);
    }

    /// Returns the candidate as a sentinel-terminated byte slice for C APIs.
    pub fn sliceZ(self: *const FontCandidate) [:0]const u8 {
        return self.bytes[0..self.len :0];
    }
};

/// FontCandidates keeps a fixed-size ordered fallback list.
pub const FontCandidates = struct {
    items: [max_font_candidates]FontCandidate = [_]FontCandidate{.{}} ** max_font_candidates,
    count: u32 = 0,

    /// Appends one candidate while enforcing the list and string bounds.
    pub fn append(self: *FontCandidates, value: []const u8) !void {
        if (self.count >= max_font_candidates) return error.TooManyFontCandidates;
        try self.items[self.count].set(value);
        self.count += 1;
    }

    /// Returns the candidate at `index`, or null when the index is outside the retained list.
    pub fn at(self: *const FontCandidates, index: u32) ?*const FontCandidate {
        if (index >= self.count) return null;
        return &self.items[index];
    }
};

/// TextAppearance couples a color with a bounded font size.
pub const TextAppearance = struct {
    color: Rgba8,
    font_px: u16,
};

/// FontAppearance owns the ordered fallback list consumed by the text engine.
pub const FontAppearance = struct {
    candidates: FontCandidates,
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

/// SunglassesFormAppearance names the picker-pane form values used by the sunglasses fields.
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
    var fonts = FontCandidates{};
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

/// Validates a text size in pixels.
pub fn fontPx(value: i64) !u16 {
    if (value < min_font_px or value > max_font_px) return error.FontSizeOutOfRange;
    return @intCast(value);
}

/// Validates a chrome scalar in base pixels.
pub fn chromePx(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.ChromeOutOfRange;
    if (value < min_chrome_px or value > max_chrome_px) return error.ChromeOutOfRange;
    return @floatCast(value);
}

/// Validates a base-coordinate layout scalar.
pub fn layoutPx(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.LayoutOutOfRange;
    if (value < min_chrome_px or value > max_layout_px) return error.LayoutOutOfRange;
    return @floatCast(value);
}

/// Validates a scalar intended to stay within the opacity range.
pub fn opacity(value: f64) !f32 {
    if (!std.math.isFinite(value)) return error.OpacityOutOfRange;
    if (value < min_opacity or value > max_opacity) return error.OpacityOutOfRange;
    return @floatCast(value);
}

fn byteComponent(value: i64) !u8 {
    if (value < 0 or value > 255) return error.ColorComponentOutOfRange;
    return @intCast(value);
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

test "appearance validators reject values outside accepted bounds" {
    try std.testing.expectError(error.FontSizeOutOfRange, fontPx(7));
    try std.testing.expectError(error.FontSizeOutOfRange, fontPx(49));
    try std.testing.expectEqual(@as(u16, 17), try fontPx(17));

    try std.testing.expectError(error.ChromeOutOfRange, chromePx(-1));
    try std.testing.expectError(error.ChromeOutOfRange, chromePx(97));
    try std.testing.expectEqual(@as(f32, 42), try chromePx(42));
    try std.testing.expectEqual(@as(f32, 122), try layoutPx(122));
    try std.testing.expectError(error.LayoutOutOfRange, layoutPx(241));

    try std.testing.expectError(error.OpacityOutOfRange, opacity(-0.1));
    try std.testing.expectError(error.OpacityOutOfRange, opacity(1.1));
    try std.testing.expectEqual(@as(f32, 0.28), try opacity(0.28));

    try std.testing.expectError(error.ColorComponentOutOfRange, Rgba8.fromComponents(256, 0, 0, 255));
}
