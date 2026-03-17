const std = @import("std");
const search = @import("../search/mod.zig");
const theme_apply = @import("../tools/theme_apply.zig");
const theme_state = @import("../tools/theme_state.zig");

pub const ThemeProvider = struct {
    owned_strings_current: std.ArrayListUnmanaged([]u8) = .{},
    owned_strings_previous: std.ArrayListUnmanaged([]u8) = .{},
    had_runtime_failure: bool = false,
    get_theme_fn: *const fn (allocator: std.mem.Allocator) anyerror!?[]u8 = theme_state.getCurrentTheme,
    self_exe_path_fn: *const fn (allocator: std.mem.Allocator) anyerror![]u8 = std.fs.selfExePathAlloc,
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

        const exe_path = self.self_exe_path_fn(allocator) catch |err| {
            self.had_runtime_failure = true;
            std.log.warn("theme provider self exe lookup failed: {s}", .{@errorName(err)});
            return;
        };
        defer allocator.free(exe_path);

        try self.appendThemeFamilies(allocator, out, exe_path, current_theme_owned);
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
        exe_path: []const u8,
        current_theme_owned: ?[]u8,
    ) !void {
        inline for (theme_apply.supported_themes) |theme_name| {
            const title = try self.keepOwnedString(allocator, try std.fmt.allocPrint(allocator, "{s}", .{theme_name}));
            const subtitle = if (current_theme_owned != null and std.mem.eql(u8, current_theme_owned.?, theme_name))
                "Current theme"
            else
                "Enter applies";
            const cmd = try self.buildSetThemeCommand(allocator, exe_path, theme_name);
            const kept_cmd = try self.keepOwnedString(allocator, cmd);
            try out.append(allocator, search.Candidate.initWithIcon(
                .action,
                title,
                subtitle,
                kept_cmd,
                "preferences-desktop-theme-symbolic",
            ));
        }
    }

    fn buildSetThemeCommand(self: *ThemeProvider, allocator: std.mem.Allocator, exe_path: []const u8, theme_name: []const u8) ![]u8 {
        _ = self;
        _ = exe_path;
        return std.fmt.allocPrint(allocator, "theme-apply:{s}", .{theme_name});
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
