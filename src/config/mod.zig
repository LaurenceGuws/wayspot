//! Builtin config owns Wayspot's local defaults without a runtime scripting VM.

const placement = @import("../ui/placement/mod.zig");
const surfaces = @import("../ui/surfaces/mod.zig");

pub const PackageManager = enum {
    yay,
    pacman,

    pub fn command(self: PackageManager) []const u8 {
        return switch (self) {
            .yay => "yay",
            .pacman => "pacman",
        };
    }
};

pub const TerminalTool = enum {
    kitty,

    pub fn command(_: TerminalTool) []const u8 {
        return "kitty";
    }
};

pub const ClipboardTool = enum {
    wl_copy,

    pub fn command(_: ClipboardTool) []const u8 {
        return "wl-copy";
    }
};

pub const EditorTool = enum {
    xdg_open,

    pub fn command(_: EditorTool) []const u8 {
        return "xdg-open";
    }
};

/// Settings is the built-in runtime policy used by the app launcher and banner windows.
pub const Settings = struct {
    pub const UiPolicy = struct {
        show_nerd_stats: bool = true,
    };

    pub const NotificationPolicy = struct {
        show_close_button: bool = true,
        show_dbus_actions: bool = true,
    };

    pub const ToolsPolicy = struct {
        package_manager: PackageManager = .yay,
        terminal: TerminalTool = .kitty,
        clipboard_tool: ClipboardTool = .wl_copy,
        editor_tool: EditorTool = .xdg_open,
    };

    surface_mode: surfaces.SurfaceMode = .toplevel,
    placement_policy: placement.RuntimePolicy = .{},
    ui: UiPolicy = .{},
    notifications: NotificationPolicy = .{},
    tools: ToolsPolicy = .{},

    /// defaults returns the single source of runtime defaults for the current shell.
    pub fn defaults() Settings {
        return .{};
    }
};

pub fn load() Settings {
    return Settings.defaults();
}
