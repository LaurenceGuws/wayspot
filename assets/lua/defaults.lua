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

---@class WayspotDefaults
---@field fonts WayspotFontDefaults Font fallback and default text size.
---@field picker WayspotPickerDefaults Launcher picker defaults.
---@field banner WayspotBannerDefaults Notification banner defaults.

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
}
