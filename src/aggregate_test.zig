//! Aggregate test root for the source tree.
//!
//! This root directly imports the test-bearing source files whose local
//! imports can share one `src/` module. Named owner roots remain separate
//! build checks for boundaries that intentionally use direct module imports.

const std = @import("std");

pub const identity_source = @import("identity.zig");
pub const env_source = @import("env/mod.zig");
pub const config_source = @import("config/defaults.zig");
pub const notification_source = @import("notification/dbus.zig");
pub const notification_history_list_source = @import("notification/history_list.zig");
pub const notification_history_source = @import("notification/history.zig");
pub const notification_preview_source = @import("notification/preview.zig");

pub const appearance_source = @import("picker/appearance.zig");
pub const query_source = @import("picker/query.zig");
pub const rank_source = @import("picker/rank.zig");
pub const scale_source = @import("picker/scale.zig");
pub const text_source = @import("picker/text.zig");
pub const cursor_blink_source = @import("picker/cursor_blink.zig");
pub const icon_cache_source = @import("picker/icon_cache.zig");
pub const icon_diag_source = @import("picker/icon_diag.zig");
pub const signal_source = @import("picker/signal.zig");
pub const slider_source = @import("picker/slider.zig");
pub const textbox_source = @import("picker/textbox.zig");
pub const viewport_source = @import("picker/viewport.zig");
pub const apps_mode_source = @import("picker/mode/apps.zig");
pub const notifications_mode_source = @import("picker/mode/notifications.zig");
pub const wallpaper_mode_source = @import("picker/mode/wallpaper.zig");

pub const process_source = @import("process/launch.zig");
pub const wallpaper_source = @import("wallpaper/loop.zig");
pub const sunglasses_source = @import("sunglasses/overlay.zig");

// wayspot_env
pub const env = env_source;
pub const monitor = env_source.monitor;
pub const workspace = env_source.workspace;
pub const window = env_source.window;
pub const state = env_source.state;
pub const hyprland = env_source.hyprland;
pub const Connection = env_source.Connection;
pub const fillState = env_source.fillState;
pub const MonitorFactWake = env_source.MonitorFactWake;
pub const MonitorSource = env_source.MonitorSource;
pub const MonitorFactStream = env_source.MonitorFactStream;

// wayspot_appearance
pub const appearance = appearance_source;
pub const max_font_candidates = appearance_source.max_font_candidates;
pub const max_string_bytes = appearance_source.max_string_bytes;
pub const min_font_px = appearance_source.min_font_px;
pub const max_font_px = appearance_source.max_font_px;
pub const min_chrome_px = appearance_source.min_chrome_px;
pub const max_chrome_px = appearance_source.max_chrome_px;
pub const max_layout_px = appearance_source.max_layout_px;
pub const min_opacity = appearance_source.min_opacity;
pub const max_opacity = appearance_source.max_opacity;
pub const Rgba8 = appearance_source.Rgba8;
pub const FontCandidate = appearance_source.FontCandidate;
pub const FontCandidates = appearance_source.FontCandidates;
pub const TextAppearance = appearance_source.TextAppearance;
pub const FontAppearance = appearance_source.FontAppearance;
pub const PickerAppearance = appearance_source.PickerAppearance;
pub const BannerAppearance = appearance_source.BannerAppearance;
pub const Appearance = appearance_source.Appearance;
pub const currentHardcodedDefaults = appearance_source.currentHardcodedDefaults;
pub const fontPx = appearance_source.fontPx;
pub const chromePx = appearance_source.chromePx;
pub const layoutPx = appearance_source.layoutPx;
pub const opacity = appearance_source.opacity;

// wayspot_config_defaults
pub const load = config_source.load;
pub const loadFromEnvironment = config_source.loadFromEnvironment;
pub const loadEmbedded = config_source.loadEmbedded;
pub const applyBuffer = config_source.applyBuffer;

// wayspot_scale
pub const scale = scale_source;
pub const ZoomAction = scale_source.ZoomAction;
pub const Dimensions = scale_source.Dimensions;
pub const SurfaceConfig = scale_source.SurfaceConfig;
pub const zoomAction = scale_source.zoomAction;
pub const clampZoomStep = scale_source.clampZoomStep;
pub const scaleFromStep = scale_source.scaleFromStep;
pub const scaledLength = scale_source.scaledLength;

// wayspot_text
pub const text = text_source;
pub const TextStyle = text_source.TextStyle;
pub const TextRangeXOffsets = text_source.TextRangeXOffsets;
pub const TextEngine = text_source.TextEngine;

// wayspot_query and wayspot_rank
pub const query = query_source;
pub const max_query_bytes = query_source.max_query_bytes;
pub const QueryError = query_source.QueryError;
pub const Route = query_source.Route;
pub const Query = query_source.Query;
pub const parse = query_source.parse;
pub const rank = rank_source;
pub const RankedCandidate = rank_source.RankedCandidate;
pub const rankCandidates = rank_source.rankCandidates;
pub const rankCandidatesWithOldestFirstHistory = rank_source.rankCandidatesWithOldestFirstHistory;

// wayspot_history, wayspot_notification_preview, and wayspot_history_list
pub const history = notification_history_source;
pub const version = notification_history_source.version;
pub const max_file_bytes = notification_history_source.max_file_bytes;
pub const max_rows = notification_history_source.max_rows;
pub const max_app_name_bytes = notification_history_source.max_app_name_bytes;
pub const max_app_icon_bytes = notification_history_source.max_app_icon_bytes;
pub const max_summary_bytes = notification_history_source.max_summary_bytes;
pub const max_body_bytes = notification_history_source.max_body_bytes;
pub const retention_ns = notification_history_source.retention_ns;
pub const RowInput = notification_history_source.RowInput;
pub const Row = notification_history_source.Row;
pub const History = notification_history_source.History;
pub const ParentSyncError = notification_history_source.ParentSyncError;
pub const SaveResult = notification_history_source.SaveResult;
pub const path = notification_history_source.path;

pub const preview = notification_preview_source;
pub const banner_app_max = notification_preview_source.banner_app_max;
pub const banner_summary_max = notification_preview_source.banner_summary_max;
pub const banner_body_max = notification_preview_source.banner_body_max;
pub const history_title_max = notification_preview_source.history_title_max;
pub const history_subtitle_max = notification_preview_source.history_subtitle_max;
pub const max_preview_bytes = notification_preview_source.max_preview_bytes;
pub const Text = notification_preview_source.Text;
pub const bannerApp = notification_preview_source.bannerApp;
pub const bannerSummary = notification_preview_source.bannerSummary;
pub const bannerBody = notification_preview_source.bannerBody;
pub const historyTitle = notification_preview_source.historyTitle;
pub const historySubtitle = notification_preview_source.historySubtitle;
pub const collapse = notification_preview_source.collapse;

pub const history_list = notification_history_list_source;
pub const NotificationHistoryList = notification_history_list_source.NotificationHistoryList;

test "aggregate root reaches the source-tree test modules" {
    std.testing.refAllDecls(identity_source);
    std.testing.refAllDecls(env_source);
    std.testing.refAllDecls(config_source);
    std.testing.refAllDecls(notification_source);
    std.testing.refAllDecls(notification_history_source);
    std.testing.refAllDecls(notification_history_list_source);
    std.testing.refAllDecls(appearance_source);
    std.testing.refAllDecls(query_source);
    std.testing.refAllDecls(rank_source);
    std.testing.refAllDecls(scale_source);
    std.testing.refAllDecls(text_source);
    std.testing.refAllDecls(apps_mode_source);
    std.testing.refAllDecls(notifications_mode_source);
    std.testing.refAllDecls(wallpaper_mode_source);
    std.testing.refAllDecls(process_source);
    std.testing.refAllDecls(wallpaper_source);
    std.testing.refAllDecls(sunglasses_source);
}
