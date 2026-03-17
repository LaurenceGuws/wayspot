const std = @import("std");
const config = @import("mod.zig");
const default_lua = @import("default_lua.zig");
const SurfaceMode = @import("../ui/surfaces/mod.zig").SurfaceMode;
const placement = @import("../ui/placement/mod.zig");
const wm_adapter = @import("../wm/adapter.zig");

const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});

const log = std.log.scoped(.config);
var issue_lock: std.Thread.Mutex = .{};
var last_load_issue: ?[]u8 = null;

fn clearLastIssue() void {
    issue_lock.lock();
    defer issue_lock.unlock();
    if (last_load_issue) |msg| std.heap.page_allocator.free(msg);
    last_load_issue = null;
}

fn noteIssue(message: []const u8) void {
    issue_lock.lock();
    defer issue_lock.unlock();
    if (last_load_issue != null) return;
    last_load_issue = std.heap.page_allocator.dupe(u8, message) catch null;
}

pub fn consumeLastLoadIssue(allocator: std.mem.Allocator) ?[]u8 {
    issue_lock.lock();
    defer issue_lock.unlock();
    const msg = last_load_issue orelse return null;
    defer {
        std.heap.page_allocator.free(msg);
        last_load_issue = null;
    }
    return allocator.dupe(u8, msg) catch null;
}

pub fn save(allocator: std.mem.Allocator, settings: config.Settings) !void {
    const path = try default_lua.resolvePath(allocator);
    defer allocator.free(path);
    _ = try default_lua.ensureDefaultConfigAtPath(path);

    const rendered = try renderSettingsAlloc(allocator, settings);
    defer allocator.free(rendered);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = rendered });
}

pub fn load(allocator: std.mem.Allocator) config.Settings {
    clearLastIssue();
    return loadStrict(allocator) catch |err| {
        log.warn("config load fallback to defaults: {s}", .{@errorName(err)});
        noteIssue("Config load failed. Using defaults for this session.");
        return .{};
    };
}

pub fn loadStrict(allocator: std.mem.Allocator) !config.Settings {
    const path = default_lua.resolvePath(allocator) catch |err| {
        log.err("lua config path resolution failed: {s}", .{@errorName(err)});
        noteIssue("Failed to resolve config path. Using defaults.");
        return err;
    };
    defer allocator.free(path);

    std.fs.cwd().access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            _ = default_lua.ensureDefaultConfigAtPath(path) catch |write_err| {
                log.err("lua config missing and default bootstrap failed ({s}): {s}", .{ path, @errorName(write_err) });
                noteIssue("Config bootstrap failed. Using defaults.");
                return write_err;
            };
            log.info("created default lua config: {s}", .{path});
        },
        else => {
            log.err("lua config access failed ({s}): {s}", .{ path, @errorName(err) });
            noteIssue("Config file access failed. Using defaults.");
            return err;
        },
    };

    const path_z = allocator.dupeZ(u8, path) catch |err| {
        log.err("lua config path allocation failed ({s}): {s}", .{ path, @errorName(err) });
        noteIssue("Config path allocation failed. Using defaults.");
        return err;
    };
    defer allocator.free(path_z);

    const lua = c.luaL_newstate() orelse {
        log.err("lua state initialization failed", .{});
        noteIssue("Lua initialization failed. Using defaults.");
        return error.OutOfMemory;
    };
    defer c.lua_close(lua);
    c.luaL_openlibs(lua);

    const filename: [*c]const u8 = @ptrCast(path_z.ptr);
    if (c.luaL_loadfilex(lua, filename, null) != c.LUA_OK or
        c.lua_pcallk(lua, 0, c.LUA_MULTRET, 0, @as(c.lua_KContext, 0), null) != c.LUA_OK)
    {
        if (readLuaString(lua, -1)) |msg| {
            log.err("lua config load failed ({s}): {s}", .{ path, msg });
        }
        noteIssue("Config syntax/runtime error detected. Using defaults.");
        return error.InvalidConfig;
    }

    var settings = config.Settings{};
    errdefer settings.deinit(allocator);
    if (c.lua_gettop(lua) > 0 and c.lua_istable(lua, -1)) {
        settings = parseSettingsFromTop(lua, allocator, settings);
        settings.applyPlacementOverrides();
        c.lua_settop(lua, 0);
        return settings;
    }

    _ = c.lua_getglobal(lua, "wayspot");
    if (c.lua_istable(lua, -1)) {
        settings = parseSettingsFromTop(lua, allocator, settings);
    }
    settings.applyPlacementOverrides();
    c.lua_settop(lua, 0);
    return settings;
}

fn parseSettingsFromTop(lua: *c.lua_State, allocator: std.mem.Allocator, initial: config.Settings) config.Settings {
    var out = initial;

    _ = c.lua_getfield(lua, -1, "theme");
    if (c.lua_istable(lua, -1)) {
        out.theme = parseThemeTable(lua, allocator, -1, out.theme);
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, -1, "surface_mode");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (SurfaceMode.parse(raw)) |mode| {
                out.surface_mode = mode;
            } else {
                log.warn("ignoring invalid lua surface_mode: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, -1, "placement");
    if (c.lua_istable(lua, -1)) {
        out.placement_policy = parsePlacementTable(lua, allocator, -1, out.placement_policy, &out.launcher_monitor_name, &out.notifications_monitor_name);
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, -1, "notifications");
    if (c.lua_istable(lua, -1)) {
        out.notification_actions = parseNotificationsTable(lua, -1, out.notification_actions);
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, -1, "ui");
    if (c.lua_istable(lua, -1)) {
        out.ui = parseUiTable(lua, -1, out.ui);
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, -1, "tools");
    if (c.lua_istable(lua, -1)) {
        out.tools = parseToolsTable(lua, -1, out.tools);
    }
    c.lua_pop(lua, 1);

    return out;
}

fn parseThemeTable(
    lua: *c.lua_State,
    allocator: std.mem.Allocator,
    idx: c_int,
    initial: config.Settings.ThemePolicy,
) config.Settings.ThemePolicy {
    var out = initial;
    _ = c.lua_getfield(lua, idx, "current");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            const trimmed = std.mem.trim(u8, raw, " \t\r\n");
            if (trimmed.len > 0) {
                out.deinit(allocator);
                out.current = allocator.dupe(u8, trimmed) catch out.current;
            }
        }
    }
    c.lua_pop(lua, 1);
    return out;
}

fn parseNotificationsTable(
    lua: *c.lua_State,
    idx: c_int,
    initial: config.Settings.NotificationActionsPolicy,
) config.Settings.NotificationActionsPolicy {
    var out = initial;
    _ = c.lua_getfield(lua, idx, "actions");
    if (c.lua_istable(lua, -1)) {
        maybeBoolField(lua, -1, "show_close_button", &out.show_close_button);
        maybeBoolField(lua, -1, "show_dbus_actions", &out.show_dbus_actions);
    }
    c.lua_pop(lua, 1);
    return out;
}

fn parseUiTable(
    lua: *c.lua_State,
    idx: c_int,
    initial: config.Settings.UiPolicy,
) config.Settings.UiPolicy {
    var out = initial;
    maybeBoolField(lua, idx, "show_nerd_stats", &out.show_nerd_stats);
    return out;
}

fn parseToolsTable(
    lua: *c.lua_State,
    idx: c_int,
    initial: config.Settings.ToolsPolicy,
) config.Settings.ToolsPolicy {
    var out = initial;
    _ = c.lua_getfield(lua, idx, "package_manager");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parsePackageManager(raw)) |value| {
                out.package_manager = value;
            } else {
                log.warn("ignoring invalid lua tools.package_manager: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "terminal");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parseTerminalTool(raw)) |value| {
                out.terminal = value;
            } else {
                log.warn("ignoring invalid lua tools.terminal: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    maybeBoolField(lua, idx, "grep_include_hidden", &out.grep_include_hidden);

    _ = c.lua_getfield(lua, idx, "clipboard_tool");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parseClipboardTool(raw)) |value| {
                out.clipboard_tool = value;
            } else {
                log.warn("ignoring invalid lua tools.clipboard_tool: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "editor_tool");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parseEditorTool(raw)) |value| {
                out.editor_tool = value;
            } else {
                log.warn("ignoring invalid lua tools.editor_tool: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    return out;
}

fn parsePlacementTable(
    lua: *c.lua_State,
    allocator: std.mem.Allocator,
    idx: c_int,
    initial: placement.RuntimePolicy,
    launcher_monitor_name: *?[]u8,
    notifications_monitor_name: *?[]u8,
) placement.RuntimePolicy {
    var out = initial;

    _ = c.lua_getfield(lua, idx, "launcher");
    if (c.lua_istable(lua, -1)) {
        out.launcher = parseLauncherPolicy(lua, allocator, -1, out.launcher, launcher_monitor_name);
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "notifications");
    if (c.lua_istable(lua, -1)) {
        out.notifications = parseNotificationPolicy(lua, allocator, -1, out.notifications, notifications_monitor_name);
    }
    c.lua_pop(lua, 1);

    return out;
}

fn parseLauncherPolicy(
    lua: *c.lua_State,
    allocator: std.mem.Allocator,
    idx: c_int,
    initial: placement.LauncherPolicy,
    monitor_name_out: *?[]u8,
) placement.LauncherPolicy {
    var out = initial;
    parseWindowPolicy(lua, allocator, idx, &out.window, monitor_name_out);
    maybeIntField(lua, idx, "width_percent", &out.width_percent);
    maybeIntField(lua, idx, "height_percent", &out.height_percent);
    maybeIntField(lua, idx, "min_width_percent", &out.min_width_percent);
    maybeIntField(lua, idx, "min_height_percent", &out.min_height_percent);
    maybeIntField(lua, idx, "max_width_px", &out.max_width_px);
    maybeIntField(lua, idx, "max_height_px", &out.max_height_px);
    maybeIntField(lua, idx, "min_width_px", &out.min_width_px);
    maybeIntField(lua, idx, "min_height_px", &out.min_height_px);
    return out;
}

fn parseNotificationPolicy(
    lua: *c.lua_State,
    allocator: std.mem.Allocator,
    idx: c_int,
    initial: placement.NotificationPolicy,
    monitor_name_out: *?[]u8,
) placement.NotificationPolicy {
    var out = initial;
    parseWindowPolicy(lua, allocator, idx, &out.window, monitor_name_out);
    maybeIntField(lua, idx, "width_percent", &out.width_percent);
    maybeIntField(lua, idx, "height_percent", &out.height_percent);
    maybeIntField(lua, idx, "min_width_px", &out.min_width_px);
    maybeIntField(lua, idx, "min_height_px", &out.min_height_px);
    maybeIntField(lua, idx, "max_width_px", &out.max_width_px);
    maybeIntField(lua, idx, "max_height_px", &out.max_height_px);
    return out;
}

fn parseWindowPolicy(
    lua: *c.lua_State,
    allocator: std.mem.Allocator,
    idx: c_int,
    out: *placement.WindowPolicy,
    monitor_name_out: *?[]u8,
) void {
    _ = c.lua_getfield(lua, idx, "anchor");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parseAnchor(raw)) |anchor| {
                out.anchor = anchor;
            } else {
                log.warn("ignoring invalid lua anchor: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "monitor_policy");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            if (parseMonitorPolicy(raw)) |policy| {
                out.monitor.policy = policy;
            } else {
                log.warn("ignoring invalid lua monitor_policy: {s}", .{raw});
                noteIssue("Invalid config values detected. Defaults were applied for invalid fields.");
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "monitor_name");
    if (c.lua_type(lua, -1) == c.LUA_TSTRING) {
        if (readLuaString(lua, -1)) |raw| {
            const trimmed = std.mem.trim(u8, raw, " \t\r\n");
            if (trimmed.len > 0) {
                if (monitor_name_out.*) |old| allocator.free(old);
                monitor_name_out.* = allocator.dupe(u8, trimmed) catch null;
            }
        }
    }
    c.lua_pop(lua, 1);

    _ = c.lua_getfield(lua, idx, "margins");
    if (c.lua_istable(lua, -1)) {
        maybeIntField(lua, -1, "left", &out.margins.left);
        maybeIntField(lua, -1, "right", &out.margins.right);
        maybeIntField(lua, -1, "top", &out.margins.top);
        maybeIntField(lua, -1, "bottom", &out.margins.bottom);
    }
    c.lua_pop(lua, 1);
}

fn maybeIntField(lua: *c.lua_State, idx: c_int, field: [*:0]const u8, out: *i32) void {
    _ = c.lua_getfield(lua, idx, field);
    defer c.lua_settop(lua, -2);
    if (c.lua_type(lua, -1) != c.LUA_TNUMBER) return;
    const v = c.lua_tointegerx(lua, -1, null);
    const int_v: i64 = @intCast(v);
    out.* = std.math.cast(i32, int_v) orelse out.*;
}

fn maybeBoolField(lua: *c.lua_State, idx: c_int, field: [*:0]const u8, out: *bool) void {
    _ = c.lua_getfield(lua, idx, field);
    defer c.lua_settop(lua, -2);
    if (c.lua_type(lua, -1) != c.LUA_TBOOLEAN) return;
    out.* = c.lua_toboolean(lua, -1) != 0;
}

fn parseAnchor(raw: []const u8) ?placement.Anchor {
    if (std.ascii.eqlIgnoreCase(raw, "center")) return .center;
    if (std.ascii.eqlIgnoreCase(raw, "top_left") or std.ascii.eqlIgnoreCase(raw, "top-left")) return .top_left;
    if (std.ascii.eqlIgnoreCase(raw, "top_center") or std.ascii.eqlIgnoreCase(raw, "top-center")) return .top_center;
    if (std.ascii.eqlIgnoreCase(raw, "top_right") or std.ascii.eqlIgnoreCase(raw, "top-right")) return .top_right;
    if (std.ascii.eqlIgnoreCase(raw, "bottom_left") or std.ascii.eqlIgnoreCase(raw, "bottom-left")) return .bottom_left;
    if (std.ascii.eqlIgnoreCase(raw, "bottom_center") or std.ascii.eqlIgnoreCase(raw, "bottom-center")) return .bottom_center;
    if (std.ascii.eqlIgnoreCase(raw, "bottom_right") or std.ascii.eqlIgnoreCase(raw, "bottom-right")) return .bottom_right;
    return null;
}

fn parseMonitorPolicy(raw: []const u8) ?wm_adapter.MonitorPolicy {
    if (std.ascii.eqlIgnoreCase(raw, "focused")) return .focused;
    if (std.ascii.eqlIgnoreCase(raw, "primary")) return .primary;
    return null;
}

fn parsePackageManager(raw: []const u8) ?config.PackageManager {
    if (std.ascii.eqlIgnoreCase(raw, "yay")) return .yay;
    if (std.ascii.eqlIgnoreCase(raw, "pacman")) return .pacman;
    return null;
}

fn parseTerminalTool(raw: []const u8) ?config.TerminalTool {
    if (std.ascii.eqlIgnoreCase(raw, "kitty")) return .kitty;
    if (std.ascii.eqlIgnoreCase(raw, "zide-terminal") or std.ascii.eqlIgnoreCase(raw, "zide_terminal")) return .zide_terminal;
    if (std.ascii.eqlIgnoreCase(raw, "alacritty")) return .alacritty;
    if (std.ascii.eqlIgnoreCase(raw, "footclient")) return .footclient;
    if (std.ascii.eqlIgnoreCase(raw, "foot")) return .foot;
    if (std.ascii.eqlIgnoreCase(raw, "wezterm")) return .wezterm;
    if (std.ascii.eqlIgnoreCase(raw, "gnome-terminal") or std.ascii.eqlIgnoreCase(raw, "gnome_terminal")) return .gnome_terminal;
    if (std.ascii.eqlIgnoreCase(raw, "konsole")) return .konsole;
    if (std.ascii.eqlIgnoreCase(raw, "xfce4-terminal") or std.ascii.eqlIgnoreCase(raw, "xfce4_terminal")) return .xfce4_terminal;
    if (std.ascii.eqlIgnoreCase(raw, "tilix")) return .tilix;
    if (std.ascii.eqlIgnoreCase(raw, "xterm")) return .xterm;
    return null;
}

fn parseClipboardTool(raw: []const u8) ?config.ClipboardTool {
    if (std.ascii.eqlIgnoreCase(raw, "wl-copy") or std.ascii.eqlIgnoreCase(raw, "wl_copy")) return .wl_copy;
    if (std.ascii.eqlIgnoreCase(raw, "xclip")) return .xclip;
    return null;
}

fn parseEditorTool(raw: []const u8) ?config.EditorTool {
    if (std.ascii.eqlIgnoreCase(raw, "nvim")) return .nvim;
    if (std.ascii.eqlIgnoreCase(raw, "vim")) return .vim;
    if (std.ascii.eqlIgnoreCase(raw, "vi")) return .vi;
    if (std.ascii.eqlIgnoreCase(raw, "helix")) return .helix;
    if (std.ascii.eqlIgnoreCase(raw, "hx")) return .hx;
    if (std.ascii.eqlIgnoreCase(raw, "kak")) return .kak;
    if (std.ascii.eqlIgnoreCase(raw, "nano")) return .nano;
    if (std.ascii.eqlIgnoreCase(raw, "code")) return .code;
    if (std.ascii.eqlIgnoreCase(raw, "codium")) return .codium;
    if (std.ascii.eqlIgnoreCase(raw, "code-insiders") or std.ascii.eqlIgnoreCase(raw, "code_insiders")) return .code_insiders;
    if (std.ascii.eqlIgnoreCase(raw, "subl")) return .subl;
    if (std.ascii.eqlIgnoreCase(raw, "xdg-open") or std.ascii.eqlIgnoreCase(raw, "xdg_open")) return .xdg_open;
    return null;
}

fn renderSettingsAlloc(allocator: std.mem.Allocator, settings: config.Settings) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    const writer = out.writer(allocator);

    try writer.writeAll("return {\n");
    try writer.print("  theme = {{\n    current = \"{s}\",\n  }},\n", .{themeName(settings)});
    if (settings.surface_mode) |mode| {
        try writer.print("  surface_mode = \"{s}\",\n", .{surfaceModeName(mode)});
    } else {
        try writer.writeAll("  surface_mode = nil,\n");
    }
    try writer.writeAll("  placement = {\n");
    try renderLauncherPolicy(writer, settings.placement_policy.launcher);
    try renderNotificationPolicy(writer, settings.placement_policy.notifications);
    try writer.writeAll("  },\n");
    try writer.print(
        "  notifications = {{\n    actions = {{\n      show_close_button = {s},\n      show_dbus_actions = {s},\n    }},\n  }},\n",
        .{ boolName(settings.notification_actions.show_close_button), boolName(settings.notification_actions.show_dbus_actions) },
    );
    try writer.print(
        "  ui = {{\n    show_nerd_stats = {s},\n  }},\n",
        .{boolName(settings.ui.show_nerd_stats)},
    );
    try writer.print(
        "  tools = {{\n    package_manager = \"{s}\",\n    terminal = \"{s}\",\n    grep_include_hidden = {s},\n    clipboard_tool = \"{s}\",\n    editor_tool = \"{s}\",\n  }},\n",
        .{
            packageManagerName(settings.tools.package_manager),
            terminalToolName(settings.tools.terminal),
            boolName(settings.tools.grep_include_hidden),
            clipboardToolName(settings.tools.clipboard_tool),
            editorToolName(settings.tools.editor_tool),
        },
    );
    try writer.writeAll("}\n");
    return out.toOwnedSlice(allocator);
}

fn renderLauncherPolicy(writer: anytype, policy: placement.LauncherPolicy) !void {
    try writer.writeAll("    launcher = {\n");
    try renderWindowPolicy(writer, policy.window);
    try writer.print(
        "      width_percent = {d},\n      height_percent = {d},\n      min_width_percent = {d},\n      min_height_percent = {d},\n      min_width_px = {d},\n      min_height_px = {d},\n      max_width_px = {d},\n      max_height_px = {d},\n",
        .{
            policy.width_percent,
            policy.height_percent,
            policy.min_width_percent,
            policy.min_height_percent,
            policy.min_width_px,
            policy.min_height_px,
            policy.max_width_px,
            policy.max_height_px,
        },
    );
    try writer.writeAll("    },\n");
}

fn renderNotificationPolicy(writer: anytype, policy: placement.NotificationPolicy) !void {
    try writer.writeAll("    notifications = {\n");
    try renderWindowPolicy(writer, policy.window);
    try writer.print(
        "      width_percent = {d},\n      height_percent = {d},\n      min_width_px = {d},\n      min_height_px = {d},\n      max_width_px = {d},\n      max_height_px = {d},\n",
        .{
            policy.width_percent,
            policy.height_percent,
            policy.min_width_px,
            policy.min_height_px,
            policy.max_width_px,
            policy.max_height_px,
        },
    );
    try writer.writeAll("    },\n");
}

fn renderWindowPolicy(writer: anytype, policy: placement.WindowPolicy) !void {
    try writer.print("      anchor = \"{s}\",\n", .{anchorName(policy.anchor)});
    try writer.print("      monitor_policy = \"{s}\",\n", .{monitorPolicyName(policy.monitor.policy)});
    if (policy.monitor.output_name) |name| {
        try writer.print("      monitor_name = \"{s}\",\n", .{name});
    }
    try writer.print(
        "      margins = {{ top = {d}, right = {d}, bottom = {d}, left = {d} }},\n",
        .{ policy.margins.top, policy.margins.right, policy.margins.bottom, policy.margins.left },
    );
}

fn themeName(settings: config.Settings) []const u8 {
    return if (settings.theme.current.len > 0) settings.theme.current else "ayu";
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn surfaceModeName(mode: SurfaceMode) []const u8 {
    return switch (mode) {
        .toplevel => "toplevel",
        .layer_shell => "layer-shell",
    };
}

fn anchorName(anchor: placement.Anchor) []const u8 {
    return switch (anchor) {
        .center => "center",
        .top_left => "top_left",
        .top_center => "top_center",
        .top_right => "top_right",
        .bottom_left => "bottom_left",
        .bottom_center => "bottom_center",
        .bottom_right => "bottom_right",
    };
}

fn monitorPolicyName(policy: wm_adapter.MonitorPolicy) []const u8 {
    return switch (policy) {
        .focused => "focused",
        .primary => "primary",
        .by_name => "by_name",
    };
}

fn packageManagerName(value: config.PackageManager) []const u8 {
    return switch (value) {
        .yay => "yay",
        .pacman => "pacman",
    };
}

fn terminalToolName(value: config.TerminalTool) []const u8 {
    return switch (value) {
        .kitty => "kitty",
        .zide_terminal => "zide-terminal",
        .alacritty => "alacritty",
        .footclient => "footclient",
        .foot => "foot",
        .wezterm => "wezterm",
        .gnome_terminal => "gnome-terminal",
        .konsole => "konsole",
        .xfce4_terminal => "xfce4-terminal",
        .tilix => "tilix",
        .xterm => "xterm",
    };
}

fn clipboardToolName(value: config.ClipboardTool) []const u8 {
    return switch (value) {
        .wl_copy => "wl-copy",
        .xclip => "xclip",
    };
}

fn editorToolName(value: config.EditorTool) []const u8 {
    return switch (value) {
        .nvim => "nvim",
        .vim => "vim",
        .vi => "vi",
        .helix => "helix",
        .hx => "hx",
        .kak => "kak",
        .nano => "nano",
        .code => "code",
        .codium => "codium",
        .code_insiders => "code-insiders",
        .subl => "subl",
        .xdg_open => "xdg-open",
    };
}

test "loadStrict parses theme current field" {
    const dir = std.testing.tmpDir(.{});
    defer dir.cleanup();

    const cfg_path = try dir.dir.realpathAlloc(std.testing.allocator, "config.lua");
    defer std.testing.allocator.free(cfg_path);
    try dir.dir.writeFile(.{
        .sub_path = "config.lua",
        .data =
            \\return {
            \\  theme = {
            \\    current = "nordic",
            \\  },
            \\}
        ,
    });

    try std.posix.setenv("WAYSPOT_CONFIG_LUA", cfg_path, true);
    defer std.posix.unsetenv("WAYSPOT_CONFIG_LUA");

    var settings = try loadStrict(std.testing.allocator);
    defer settings.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("nordic", settings.theme.current);
}

test "save renders canonical settings with theme" {
    var settings = config.Settings{};
    defer settings.deinit(std.testing.allocator);
    settings.theme.current = try std.testing.allocator.dupe(u8, "mocha");

    const rendered = try renderSettingsAlloc(std.testing.allocator, settings);
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "theme = {") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "current = \"mocha\"") != null);
}

fn readLuaString(lua: *c.lua_State, idx: c_int) ?[]const u8 {
    var len: usize = 0;
    const ptr = c.lua_tolstring(lua, idx, &len) orelse return null;
    return ptr[0..@intCast(len)];
}
