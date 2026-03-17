const std = @import("std");
const providers_mod = @import("../../providers/mod.zig");
const search = @import("../../search/mod.zig");
const runtime_tools = @import("../../config/runtime_tools.zig");
const wm = @import("../../wm/mod.zig");
pub const kinds = @import("kinds.zig");

pub const NativeExecuteFn = *const fn (allocator: std.mem.Allocator, action: []const u8) anyerror!void;

pub const CommandPlan = struct {
    command: ?[]const u8 = null,
    owned_command: ?[]u8 = null,
    native_execute: ?NativeExecuteFn = null,
    telemetry_kind: []const u8 = "",
    telemetry_ok_detail: []const u8 = "",
    error_message: []const u8 = "",
    close_on_success: bool = false,
    detach_command: bool = false,
    unknown_action: bool = false,

    pub fn deinit(self: *CommandPlan, allocator: std.mem.Allocator) void {
        if (self.owned_command) |buf| allocator.free(buf);
        self.* = .{};
    }
};

pub fn shouldRecordSelection(kind: []const u8) bool {
    return shouldRecordSelectionKind(kinds.parse(kind));
}

pub fn shouldRecordSelectionKind(kind: kinds.UiKind) bool {
    return switch (kind) {
        .dir_option, .file_option, .module, .notification, .hint => false,
        else => true,
    };
}

pub fn shouldRecordCandidate(kind: search.CandidateKind) bool {
    return switch (kind) {
        .dir, .file, .grep, .notification, .hint => false,
        else => true,
    };
}

pub fn requiresConfirmation(kind: []const u8, action: []const u8) bool {
    return requiresConfirmationKind(kinds.parse(kind), action);
}

pub fn requiresConfirmationKind(kind: kinds.UiKind, action: []const u8) bool {
    return kind == .action and providers_mod.requiresConfirmation(action);
}

pub fn isDirMenuKind(kind: []const u8) bool {
    return isDirMenuKindEnum(kinds.parse(kind));
}

pub fn isDirMenuKindEnum(kind: kinds.UiKind) bool {
    return kind == .dir;
}

pub fn isFileMenuKind(kind: []const u8) bool {
    return isFileMenuKindEnum(kinds.parse(kind));
}

pub fn isFileMenuKindEnum(kind: kinds.UiKind) bool {
    return kind == .file or kind == .grep;
}

pub fn isModuleKind(kind: []const u8) bool {
    return isModuleKindEnum(kinds.parse(kind));
}

pub fn isModuleKindEnum(kind: kinds.UiKind) bool {
    return kind == .module;
}

pub fn planCommand(allocator: std.mem.Allocator, kind: []const u8, action: []const u8) !CommandPlan {
    return planCommandKind(allocator, kinds.parse(kind), action);
}

pub fn planCommandKind(allocator: std.mem.Allocator, kind: kinds.UiKind, action: []const u8) !CommandPlan {
    switch (kind) {
        .action => {
            if (std.mem.startsWith(u8, action, "theme-apply:")) {
                const theme = action["theme-apply:".len..];
                if (theme.len == 0) {
                    return .{
                        .telemetry_kind = "theme",
                        .error_message = "Theme apply failed: invalid theme",
                        .unknown_action = true,
                    };
                }
                const exe_path = try std.fs.selfExePathAlloc(allocator);
                defer allocator.free(exe_path);
                const exe_q = try shellSingleQuote(allocator, exe_path);
                defer allocator.free(exe_q);
                const theme_q = try shellSingleQuote(allocator, theme);
                defer allocator.free(theme_q);
                const cmd = try std.fmt.allocPrint(allocator, "{s} --apply-theme {s}", .{ exe_q, theme_q });
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "theme",
                    .telemetry_ok_detail = theme,
                    .error_message = "Theme apply failed",
                    .close_on_success = true,
                };
            }
            if (std.mem.startsWith(u8, action, "theme-open-dir:")) {
                const theme = action["theme-open-dir:".len..];
                const home = try std.process.getEnvVarOwned(allocator, "HOME");
                defer allocator.free(home);
                const theme_dir = try std.fs.path.join(allocator, &.{ home, "Pictures", "wallpapers", theme });
                defer allocator.free(theme_dir);
                const dir_q = try shellSingleQuote(allocator, theme_dir);
                defer allocator.free(dir_q);
                const cmd = try std.fmt.allocPrint(allocator, "xdg-open {s}", .{dir_q});
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "theme",
                    .telemetry_ok_detail = theme,
                    .error_message = "Theme wallpapers failed to open",
                    .close_on_success = true,
                    .detach_command = true,
                };
            }
            if (std.mem.startsWith(u8, action, "theme-slideshow-toggle:")) {
                const theme = action["theme-slideshow-toggle:".len..];
                if (theme.len == 0) {
                    return .{
                        .telemetry_kind = "theme",
                        .error_message = "Theme slideshow failed: invalid theme",
                        .unknown_action = true,
                    };
                }
                const exe_path = try std.fs.selfExePathAlloc(allocator);
                defer allocator.free(exe_path);
                const exe_q = try shellSingleQuote(allocator, exe_path);
                defer allocator.free(exe_q);
                const theme_q = try shellSingleQuote(allocator, theme);
                defer allocator.free(theme_q);
                const cmd = try std.fmt.allocPrint(
                    allocator,
                    "sh -lc '{s} --apply-theme {s} && {s} --toggle-wallpaper-slideshow'",
                    .{ exe_q, theme_q, exe_q },
                );
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "theme",
                    .telemetry_ok_detail = theme,
                    .error_message = "Theme slideshow toggle failed",
                    .close_on_success = true,
                };
            }
            if (std.mem.startsWith(u8, action, "pkg-install:") or
                std.mem.startsWith(u8, action, "pkg-update:") or
                std.mem.startsWith(u8, action, "pkg-remove:"))
            {
                const op: enum { install, update, remove } = if (std.mem.startsWith(u8, action, "pkg-remove:"))
                    .remove
                else if (std.mem.startsWith(u8, action, "pkg-update:"))
                    .update
                else
                    .install;
                const pkg = switch (op) {
                    .install => action["pkg-install:".len..],
                    .update => action["pkg-update:".len..],
                    .remove => action["pkg-remove:".len..],
                };
                if (pkg.len == 0) {
                    return .{
                        .telemetry_kind = "package",
                        .error_message = "Package action failed: invalid package",
                        .unknown_action = true,
                    };
                }
                const pkg_q = try shellSingleQuote(allocator, pkg);
                defer allocator.free(pkg_q);
                const pkg_tool = runtime_tools.packageManager();
                const pkg_cmd = switch (pkg_tool) {
                    .yay => switch (op) {
                        .install, .update => "yay -S --needed -- \"$pkg\"",
                        .remove => "yay -Rns -- \"$pkg\"",
                    },
                    .pacman => switch (op) {
                        .install, .update => "sudo pacman -S --needed -- \"$pkg\"",
                        .remove => "sudo pacman -Rns -- \"$pkg\"",
                    },
                };
                const term_cmd = runtime_tools.terminalTool().command();
                const launch_expr = switch (runtime_tools.terminalTool()) {
                    .kitty, .zide_terminal, .alacritty, .footclient, .foot, .wezterm, .xterm => "exec \"$term\" -e sh -lc \"$install_cmd\"",
                    .gnome_terminal, .konsole, .xfce4_terminal, .tilix => "exec \"$term\" -- sh -lc \"$install_cmd\"",
                };
                const cmd = try std.fmt.allocPrint(
                    allocator,
                    "sh -lc 'pkg=\"$1\"; term=\"{s}\"; install_cmd=\"{s}\"; {s}' _ {s}",
                    .{ term_cmd, pkg_cmd, launch_expr, pkg_q },
                );
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "package",
                    .telemetry_ok_detail = pkg,
                    .error_message = "Package install failed to launch",
                    .close_on_success = true,
                    .detach_command = true,
                };
            }
            const spec = providers_mod.resolveActionSpec(action) orelse {
                return .{
                    .telemetry_kind = "action",
                    .error_message = "Action failed: unknown action",
                    .unknown_action = true,
                };
            };
            const cmd = try providers_mod.resolveExecutionCommand(allocator, spec.execution);
            return .{
                .command = cmd,
                .owned_command = cmd,
                .telemetry_kind = "action",
                .telemetry_ok_detail = action,
                .error_message = "Action failed to launch",
                .close_on_success = true,
                .detach_command = true,
            };
        },
        .dir_option => {
            return .{
                .command = action,
                .telemetry_kind = "dir",
                .telemetry_ok_detail = "option-command",
                .error_message = "Directory action failed",
                .close_on_success = true,
                .detach_command = true,
            };
        },
        .file_option => {
            return .{
                .command = action,
                .telemetry_kind = "file",
                .telemetry_ok_detail = "option-command",
                .error_message = "File action failed",
                .close_on_success = true,
                .detach_command = true,
            };
        },
        .app => {
            if (std.mem.eql(u8, action, "__drun__")) return .{};
            return .{
                .command = action,
                .telemetry_kind = "app",
                .telemetry_ok_detail = action,
                .error_message = "App failed to launch",
                .close_on_success = true,
                .detach_command = true,
            };
        },
        .window => {
            return .{
                .native_execute = executeFocusWindow,
                .telemetry_kind = "window",
                .telemetry_ok_detail = action,
                .error_message = "Window focus failed",
                .close_on_success = true,
            };
        },
        .workspace => {
            return .{
                .native_execute = executeSwitchWorkspace,
                .telemetry_kind = "workspace",
                .telemetry_ok_detail = action,
                .error_message = "Workspace switch failed",
                .close_on_success = true,
            };
        },
        .web => {
            if (std.mem.startsWith(u8, action, "http://") or std.mem.startsWith(u8, action, "https://")) {
                const url_q = try shellSingleQuote(allocator, action);
                defer allocator.free(url_q);
                const cmd = try std.fmt.allocPrint(allocator, "xdg-open {s}", .{url_q});
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "web",
                    .telemetry_ok_detail = "Bookmark",
                    .error_message = "Bookmark failed to launch",
                    .close_on_success = true,
                    .detach_command = true,
                };
            }
            const parsed_cmd = providers_mod.parseWebCommand(action) orelse return .{};
            switch (parsed_cmd) {
                .search => |parsed_web| {
                    const url = try providers_mod.buildWebSearchUrl(allocator, parsed_web);
                    defer allocator.free(url);
                    const url_q = try shellSingleQuote(allocator, url);
                    defer allocator.free(url_q);
                    const cmd = try std.fmt.allocPrint(allocator, "xdg-open {s}", .{url_q});
                    return .{
                        .command = cmd,
                        .owned_command = cmd,
                        .telemetry_kind = "web",
                        .telemetry_ok_detail = providers_mod.engineLabelForWeb(parsed_web.engine),
                        .error_message = "Web search failed to launch",
                        .close_on_success = true,
                        .detach_command = true,
                    };
                },
                .bookmark => |b| {
                    const url = (try providers_mod.resolveBookmarkUrl(allocator, b.query)) orelse {
                        return .{
                            .telemetry_kind = "web",
                            .telemetry_ok_detail = "bookmark-miss",
                            .error_message = "Bookmark not found",
                            .unknown_action = true,
                        };
                    };
                    defer allocator.free(url);
                    const url_q = try shellSingleQuote(allocator, url);
                    defer allocator.free(url_q);
                    const cmd = try std.fmt.allocPrint(allocator, "xdg-open {s}", .{url_q});
                    return .{
                        .command = cmd,
                        .owned_command = cmd,
                        .telemetry_kind = "web",
                        .telemetry_ok_detail = "Bookmark",
                        .error_message = "Bookmark failed to launch",
                        .close_on_success = true,
                        .detach_command = true,
                    };
                },
            }
        },
        .hint => {
            if (std.mem.startsWith(u8, action, "calc-copy:")) {
                const value = action["calc-copy:".len..];
                const value_q = try shellSingleQuote(allocator, value);
                defer allocator.free(value_q);
                const cmd = try buildClipboardCopyCommand(allocator, value_q);
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "calc",
                    .telemetry_ok_detail = "copy-result",
                    .error_message = "Calculator copy failed",
                    .close_on_success = true,
                };
            }
            if (std.mem.startsWith(u8, action, "nerd-copy:")) {
                const value = action["nerd-copy:".len..];
                const value_q = try shellSingleQuote(allocator, value);
                defer allocator.free(value_q);
                const cmd = try buildClipboardCopyCommand(allocator, value_q);
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "nerd-icon",
                    .telemetry_ok_detail = "copy-glyph",
                    .error_message = "Nerd icon copy failed",
                    .close_on_success = true,
                };
            }
            if (std.mem.startsWith(u8, action, "emoji-copy:")) {
                const value = action["emoji-copy:".len..];
                const value_q = try shellSingleQuote(allocator, value);
                defer allocator.free(value_q);
                const cmd = try buildClipboardCopyCommand(allocator, value_q);
                return .{
                    .command = cmd,
                    .owned_command = cmd,
                    .telemetry_kind = "emoji",
                    .telemetry_ok_detail = "copy-emoji",
                    .error_message = "Emoji copy failed",
                    .close_on_success = true,
                };
            }
        },
        else => {},
    }
    return .{};
}

fn executeFocusWindow(allocator: std.mem.Allocator, action: []const u8) !void {
    var backend_impl = wm.HyprlandBackend{};
    return backend_impl.backend().focusWindow(allocator, action);
}

fn executeSwitchWorkspace(allocator: std.mem.Allocator, action: []const u8) !void {
    var backend_impl = wm.HyprlandBackend{};
    return backend_impl.backend().switchWorkspace(allocator, action);
}

fn shellSingleQuote(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    try out.append(allocator, '\'');
    for (value) |ch| {
        if (ch == '\'') {
            try out.appendSlice(allocator, "'\\''");
        } else {
            try out.append(allocator, ch);
        }
    }
    try out.append(allocator, '\'');
    return out.toOwnedSlice(allocator);
}

test "theme apply action resolves to current wayspot binary command" {
    var plan = try planCommandKind(std.testing.allocator, .action, "theme-apply:ayu");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.command != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "--apply-theme") != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "ayu") != null);
}

test "theme wallpaper dir action resolves to xdg-open" {
    var plan = try planCommandKind(std.testing.allocator, .action, "theme-open-dir:ayu");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.command != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "xdg-open") != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "/Pictures/wallpapers/ayu") != null);
}

test "literal cmd action escape hatch is rejected" {
    var plan = try planCommandKind(std.testing.allocator, .action, "cmd:echo hacked");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.command == null);
    try std.testing.expect(plan.unknown_action);
    try std.testing.expectEqualStrings("Action failed: unknown action", plan.error_message);
}

fn buildClipboardCopyCommand(allocator: std.mem.Allocator, value_q: []const u8) ![]u8 {
    const clip_cmd = runtime_tools.clipboardTool().command();
    return std.fmt.allocPrint(
        allocator,
        "sh -lc 'printf %s \"$1\" | {s}' _ {s}",
        .{ clip_cmd, value_q },
    );
}

test "window focus resolves to native wm execution" {
    var plan = try planCommandKind(std.testing.allocator, .window, "0xabc;touch /tmp/pwn $(id)");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.native_execute != null);
    try std.testing.expectEqualStrings("0xabc;touch /tmp/pwn $(id)", plan.telemetry_ok_detail);
}

test "window focus keeps raw identifier for backend execution" {
    var plan = try planCommandKind(std.testing.allocator, .window, "win'42");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.native_execute != null);
    try std.testing.expectEqualStrings("win'42", plan.telemetry_ok_detail);
}

test "workspace switch resolves to native wm execution" {
    var plan = try planCommandKind(std.testing.allocator, .workspace, "name with 'quote'");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.native_execute != null);
    try std.testing.expectEqualStrings("name with 'quote'", plan.telemetry_ok_detail);
}

test "calculator hint copy command builds clipboard shell command" {
    var plan = try planCommandKind(std.testing.allocator, .hint, "calc-copy:3.14");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.command != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "wl-copy") != null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "copyq add") == null);
    try std.testing.expect(std.mem.indexOf(u8, plan.command.?, "3.14") != null);
    try std.testing.expectEqualStrings("calc", plan.telemetry_kind);
}

test "web command defaults to duckduckgo and percent-encodes query" {
    var plan = try planCommandKind(std.testing.allocator, .web, "dota 2 + mmr");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://duckduckgo.com/?q=dota%202%20%2B%20mmr'",
        plan.command.?,
    );
    try std.testing.expectEqualStrings("web", plan.telemetry_kind);
    try std.testing.expectEqualStrings("DuckDuckGo", plan.telemetry_ok_detail);
}

test "web command supports google and wikipedia selectors" {
    var google_plan = try planCommandKind(std.testing.allocator, .web, "g dota 2");
    defer google_plan.deinit(std.testing.allocator);
    try std.testing.expect(google_plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://www.google.com/search?q=dota%202'",
        google_plan.command.?,
    );
    try std.testing.expectEqualStrings("Google", google_plan.telemetry_ok_detail);

    var wiki_plan = try planCommandKind(std.testing.allocator, .web, "w zig language");
    defer wiki_plan.deinit(std.testing.allocator);
    try std.testing.expect(wiki_plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://en.wikipedia.org/w/index.php?search=zig%20language'",
        wiki_plan.command.?,
    );
    try std.testing.expectEqualStrings("Wikipedia", wiki_plan.telemetry_ok_detail);
}

test "web command selectors are case-insensitive" {
    var google_plan = try planCommandKind(std.testing.allocator, .web, "G dota 2");
    defer google_plan.deinit(std.testing.allocator);
    try std.testing.expect(google_plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://www.google.com/search?q=dota%202'",
        google_plan.command.?,
    );
    try std.testing.expectEqualStrings("Google", google_plan.telemetry_ok_detail);

    var ddg_plan = try planCommandKind(std.testing.allocator, .web, "DDG arch linux");
    defer ddg_plan.deinit(std.testing.allocator);
    try std.testing.expect(ddg_plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://duckduckgo.com/?q=arch%20linux'",
        ddg_plan.command.?,
    );
    try std.testing.expectEqualStrings("DuckDuckGo", ddg_plan.telemetry_ok_detail);

    var wiki_plan = try planCommandKind(std.testing.allocator, .web, "W zig language");
    defer wiki_plan.deinit(std.testing.allocator);
    try std.testing.expect(wiki_plan.command != null);
    try std.testing.expectEqualStrings(
        "xdg-open 'https://en.wikipedia.org/w/index.php?search=zig%20language'",
        wiki_plan.command.?,
    );
    try std.testing.expectEqualStrings("Wikipedia", wiki_plan.telemetry_ok_detail);
}

test "web bookmark command returns unknown_action when bookmark is missing" {
    var plan = try planCommandKind(std.testing.allocator, .web, "b definitely-missing-bookmark-alias");
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.command == null);
    try std.testing.expect(plan.unknown_action);
    try std.testing.expectEqualStrings("Bookmark not found", plan.error_message);
}

test "package action uses configured terminal and package manager only" {
    runtime_tools.apply(.{
        .tools = .{
            .package_manager = .pacman,
            .terminal = .xterm,
        },
    });
    var plan = try planCommandKind(std.testing.allocator, .action, "pkg-install:ripgrep");
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.command != null);
    const cmd = plan.command.?;
    try std.testing.expect(std.mem.indexOf(u8, cmd, "sudo pacman -S --needed") != null);
    try std.testing.expect(std.mem.indexOf(u8, cmd, "term=\"xterm\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, cmd, "command -v") == null);
}

test "clipboard copy uses configured clipboard tool only" {
    runtime_tools.apply(.{
        .tools = .{
            .clipboard_tool = .xclip,
        },
    });
    var plan = try planCommandKind(std.testing.allocator, .hint, "emoji-copy:hi");
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.command != null);
    const cmd = plan.command.?;
    try std.testing.expect(std.mem.indexOf(u8, cmd, "xclip -selection clipboard") != null);
    try std.testing.expect(std.mem.indexOf(u8, cmd, "wl-copy") == null);
}
