const std = @import("std");
const search = @import("../search/mod.zig");
const theme_catalog = @import("../tools/theme_catalog.zig");
const theme_state = @import("../tools/theme_state.zig");

pub const ThemeProvider = struct {
    owned_strings_current: std.ArrayListUnmanaged([]u8) = .{},
    owned_strings_previous: std.ArrayListUnmanaged([]u8) = .{},
    had_runtime_failure: bool = false,
    get_theme_fn: *const fn (allocator: std.mem.Allocator) anyerror!?[]u8 = theme_state.getCurrentTheme,
    pub fn deinit(self: *ThemeProvider, allocator: std.mem.Allocator) void {
        self.freeOwnedStrings(allocator, &self.owned_strings_current);
        self.freeOwnedStrings(allocator, &self.owned_strings_previous);
        self.owned_strings_current.deinit(allocator);
        self.owned_strings_previous.deinit(allocator);
    }

    pub fn provider(self: *ThemeProvider) search.Provider {
        return .{
            .name = "theme",
            .context = self,
            .vtable = &.{
                .collect = collect,
                .health = health,
            },
        };
    }

    fn collect(context: *anyopaque, allocator: std.mem.Allocator, out: *search.CandidateList) !void {
        const self: *ThemeProvider = @ptrCast(@alignCast(context));
        self.had_runtime_failure = false;
        self.rotateOwnedStringsForCollect(allocator);

        const current_theme_owned = self.get_theme_fn(allocator) catch |err| {
            self.had_runtime_failure = true;
            std.log.warn("theme provider lua theme lookup failed: {s}", .{@errorName(err)});
            return;
        };
        defer if (current_theme_owned) |value| allocator.free(value);

        try self.appendThemeFamilies(allocator, out, current_theme_owned);
    }

    fn health(context: *anyopaque) search.ProviderHealth {
        const self: *ThemeProvider = @ptrCast(@alignCast(context));
        if (self.had_runtime_failure) return .degraded;
        return .ready;
    }

    fn appendThemeFamilies(
        self: *ThemeProvider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
        current_theme_owned: ?[]u8,
    ) !void {
        const available = try theme_catalog.discoverAvailableThemes(allocator);
        defer {
            for (available) |item| allocator.free(item);
            allocator.free(available);
        }

        for (available) |theme_name| {
            const title = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "{s}", .{theme_name}));
            const subtitle = if (current_theme_owned != null and std.mem.eql(u8, current_theme_owned.?, theme_name))
                "Current theme"
            else
                "Enter applies";
            const apply_action = try self.buildThemeAction(allocator, "theme-apply", theme_name);
            const kept_apply_action = try self.keepOwnedString(allocator, apply_action);
            try out.append(allocator, search.Candidate.initWithIcon(
                .action,
                title,
                subtitle,
                kept_apply_action,
                "preferences-desktop-theme-symbolic",
            ));

            const wallpapers_title = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "{s} / wallpapers", .{theme_name}));
            const wallpapers_subtitle = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "Open wallpapers for {s}", .{theme_name}));
            const wallpapers_action = try self.buildThemeAction(allocator, "theme-open-dir", theme_name);
            const kept_wallpapers_action = try self.keepOwnedString(allocator, wallpapers_action);
            try out.append(allocator, search.Candidate.initWithIcon(
                .action,
                wallpapers_title,
                wallpapers_subtitle,
                kept_wallpapers_action,
                "folder-pictures-symbolic",
            ));

            const slideshow_title = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "{s} / slideshow", .{theme_name}));
            const slideshow_subtitle = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "Apply {s}, then toggle slideshow", .{theme_name}));
            const slideshow_action = try self.buildThemeAction(allocator, "theme-slideshow-toggle", theme_name);
            const kept_slideshow_action = try self.keepOwnedString(allocator, slideshow_action);
            try out.append(allocator, search.Candidate.initWithIcon(
                .action,
                slideshow_title,
                slideshow_subtitle,
                kept_slideshow_action,
                "preferences-desktop-wallpaper-symbolic",
            ));
        }
    }

    fn buildThemeAction(self: *ThemeProvider, allocator: std.mem.Allocator, namespace: []const u8, theme_name: []const u8) ![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "{s}:{s}", .{ namespace, theme_name });
    }

    fn keepOwnedString(self: *ThemeProvider, allocator: std.mem.Allocator, value: []u8) ![]const u8 {
        try self.owned_strings_current.append(allocator, value);
        return value;
    }

    fn rotateOwnedStringsForCollect(self: *ThemeProvider, allocator: std.mem.Allocator) void {
        self.freeOwnedStrings(allocator, &self.owned_strings_previous);
        std.mem.swap(std.ArrayListUnmanaged([]u8), &self.owned_strings_current, &self.owned_strings_previous);
        self.owned_strings_current.clearRetainingCapacity();
    }

    fn freeOwnedStrings(self: *ThemeProvider, allocator: std.mem.Allocator, strings: *std.ArrayListUnmanaged([]u8)) void {
        _ = self;
        for (strings.items) |item| allocator.free(item);
        strings.clearRetainingCapacity();
    }
};
