---@meta

---Wayspot UI defaults loaded at startup.
---Edit `$HOME/.config/wayspot/defaults.lua` with the same table shape to
---override only the values you want to change. Missing user fields keep these
---embedded defaults.

---@alias WayspotColor { [1]: integer, [2]: integer, [3]: integer, [4]: integer }

---@class WayspotText
---@field color WayspotColor Text color as red, green, blue, alpha bytes.
---@field font_px integer Text size in base pixels.

---@class WayspotFontDefaults
---@field candidates string[] Ordered font file candidates; the first loadable face is used.
---@field default_px integer Default text size in base pixels when a renderer has no narrower size.

---@class WayspotPickerDefaults
---@field background WayspotColor Picker window background.
---@field query_placeholder WayspotText Search placeholder text.
---@field query_text WayspotText Typed query text.
---@field query_cursor WayspotColor Query cursor color.
---@field query_divider WayspotColor Divider under the query row.
---@field row_selected_fill WayspotColor Selected result row fill.
---@field row_normal_fill WayspotColor Normal result row fill.
---@field title_selected WayspotText Selected result title text.
---@field title_normal WayspotText Normal result title text.
---@field subtitle_selected WayspotText Selected result subtitle text.
---@field subtitle_normal WayspotText Normal result subtitle text.
---@field empty_text WayspotText Empty-result message text.
---@field scrollbar_track WayspotColor Result scrollbar track.
---@field scrollbar_thumb WayspotColor Result scrollbar thumb.

---@class WayspotBannerDefaults
---@field critical_background WayspotColor Critical notification background.
---@field low_background WayspotColor Low-urgency notification background.
---@field normal_background WayspotColor Normal notification background.
---@field accent WayspotColor Left accent stripe color.
---@field accent_width number Left accent stripe width in base pixels.
---@field app_text WayspotText App-name text.
---@field summary_text WayspotText Summary text.
---@field body_text WayspotText Body text.
---@field text_x number Text left edge in base pixels.
---@field app_y number App-name baseline top in base pixels.
---@field summary_y number Summary baseline top in base pixels.
---@field body_y number Body baseline top in base pixels.

---@class WayspotSunglassesFormDefaults
---@field value_column_width number Space reserved between values and sliders in base pixels.
---@field slider_height number Slider track height in base pixels.
---@field toggle_size number Toggle box size in base pixels.
---@field knob_width number Slider knob width in base pixels.
---@field knob_height number Slider knob height in base pixels.
---@field toggle_inset number Filled toggle inset in base pixels.
---@field value_column_min_x number Minimum value column offset in base pixels.
---@field value_column_fraction number Value column offset as a row-width fraction.
---@field text_font_px integer Label and monitor text size in base pixels.
---@field value_font_px integer Value text size in base pixels.
---@field monitor_value WayspotColor Monitor-name value text.
---@field path_error WayspotColor Invalid path value text.
---@field form_value WayspotColor Normal form value text.
---@field focused_row_fill WayspotColor Focused row fill.
---@field normal_row_fill WayspotColor Normal row fill.
---@field label WayspotColor Form label text.
---@field toggle_border WayspotColor Toggle border.
---@field toggle_fill WayspotColor Enabled toggle fill.
---@field slider_track WayspotColor Slider track.
---@field slider_knob WayspotColor Slider knob.

---@class WayspotDefaults
---@field fonts WayspotFontDefaults Font fallback and default text size.
---@field picker WayspotPickerDefaults Launcher picker defaults.
---@field banner WayspotBannerDefaults Notification banner defaults.
---@field sunglasses_form WayspotSunglassesFormDefaults Sunglasses picker-form defaults.

---@type WayspotDefaults
return {
  fonts = {
    candidates = {
      "/usr/share/fonts/TTF/IosevkaTermNerdFont-Regular.ttf",
      "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",
      "/usr/share/fonts/noto/NotoSans-Regular.ttf",
      "/usr/share/fonts/TTF/DejaVuSans.ttf",
    },
    default_px = 17,
  },
  picker = {
    background = { 18, 18, 22, 255 },
    query_placeholder = { color = { 96, 108, 124, 255 }, font_px = 17 },
    query_text = { color = { 168, 185, 204, 255 }, font_px = 17 },
    query_cursor = { 214, 226, 244, 255 },
    query_divider = { 64, 74, 84, 255 },
    row_selected_fill = { 64, 64, 82, 255 },
    row_normal_fill = { 31, 31, 38, 255 },
    title_selected = { color = { 246, 248, 252, 255 }, font_px = 17 },
    title_normal = { color = { 216, 222, 230, 255 }, font_px = 17 },
    subtitle_selected = { color = { 186, 202, 224, 255 }, font_px = 14 },
    subtitle_normal = { color = { 140, 152, 166, 255 }, font_px = 14 },
    empty_text = { color = { 190, 198, 208, 255 }, font_px = 17 },
    scrollbar_track = { 38, 44, 52, 255 },
    scrollbar_thumb = { 104, 118, 136, 255 },
  },
  banner = {
    critical_background = { 70, 22, 26, 242 },
    low_background = { 20, 24, 27, 242 },
    normal_background = { 24, 28, 34, 242 },
    accent = { 105, 184, 150, 255 },
    accent_width = 2,
    app_text = { color = { 150, 166, 184, 255 }, font_px = 13 },
    summary_text = { color = { 238, 242, 247, 255 }, font_px = 18 },
    body_text = { color = { 188, 198, 210, 255 }, font_px = 15 },
    text_x = 8,
    app_y = 6,
    summary_y = 24,
    body_y = 50,
  },
  sunglasses_form = {
    value_column_width = 42,
    slider_height = 4,
    toggle_size = 16,
    knob_width = 8,
    knob_height = 20,
    toggle_inset = 4,
    value_column_min_x = 122,
    value_column_fraction = 0.28,
    text_font_px = 15,
    value_font_px = 14,
    monitor_value = { 218, 226, 236, 255 },
    path_error = { 238, 142, 142, 255 },
    form_value = { 186, 202, 224, 255 },
    focused_row_fill = { 64, 64, 82, 255 },
    normal_row_fill = { 31, 31, 38, 255 },
    label = { 216, 222, 230, 255 },
    toggle_border = { 112, 126, 144, 255 },
    toggle_fill = { 222, 231, 242, 255 },
    slider_track = { 92, 104, 120, 255 },
    slider_knob = { 228, 235, 244, 255 },
  },
}
