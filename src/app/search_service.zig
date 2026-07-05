const std = @import("std");
const providers = @import("../providers/mod.zig");
const search = @import("../search/mod.zig");
const history_access = @import("search_service/history_access.zig");

pub const SearchService = struct {
    actions: ?*providers.ActionsProvider = null,
    apps: ?*providers.AppsProvider = null,
    modes: ?*providers.ModesProvider = null,
    notification_history: ?*providers.NotificationHistoryProvider = null,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    candidates: search.CandidateList = .empty,
    candidates_loaded: bool = false,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,

    pub fn init(actions: ?*providers.ActionsProvider, apps: ?*providers.AppsProvider) SearchService {
        return .{
            .actions = actions,
            .apps = apps,
        };
    }

    pub fn initWithHistoryPath(
        actions: ?*providers.ActionsProvider,
        apps: ?*providers.AppsProvider,
        modes: ?*providers.ModesProvider,
        history_path: []const u8,
    ) SearchService {
        return .{
            .actions = actions,
            .apps = apps,
            .modes = modes,
            .history_path = history_path,
        };
    }

    pub fn deinit(self: *SearchService, allocator: std.mem.Allocator) void {
        self.candidates.deinit(allocator);
        history_access.deinitHistory(&self.history, allocator);
    }

    pub fn searchQuery(self: *SearchService, allocator: std.mem.Allocator, raw_query: []const u8) ![]search.ScoredCandidate {
        try self.loadCandidatesOnce(allocator);

        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        const ranked = try search.rankCandidatesWithOldestFirstHistory(
            allocator,
            search.parseQuery(raw_query),
            self.candidates.items,
            self.history.items,
        );
        return ranked;
    }

    pub fn recordSelection(self: *SearchService, allocator: std.mem.Allocator, action: []const u8) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try history_access.recordLocked(&self.history, self.max_history, allocator, action);
    }

    pub fn loadHistory(self: *SearchService, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try history_access.loadLocked(&self.history, self.max_history, self.history_path, allocator);
    }

    pub fn saveHistory(self: *SearchService, allocator: std.mem.Allocator) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try history_access.saveLocked(self.history.items, self.history_path, allocator);
    }

    fn loadCandidatesOnce(self: *SearchService, allocator: std.mem.Allocator) !void {
        if (self.candidates_loaded) return;
        if (self.modes) |provider| try provider.collect(allocator, &self.candidates);
        if (self.notification_history) |provider| try provider.collect(allocator, &self.candidates);
        if (self.actions) |provider| try provider.collect(allocator, &self.candidates);
        if (self.apps) |provider| try provider.collect(allocator, &self.candidates);
        self.candidates_loaded = true;
    }
};

test "search service collects candidates once per service lifetime" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "apps.tsv",
        .data =
        \\Utilities\tKitty\tkitty\tkitty
        \\Internet\tFirefox\tfirefox\tfirefox
        \\
        ,
    });

    const cache_path = try tmp.dir.realpathAlloc(std.testing.allocator, "apps.tsv");
    defer std.testing.allocator.free(cache_path);

    var apps = providers.AppsProvider.init(cache_path);
    defer apps.deinit(std.testing.allocator);
    var service = SearchService.init(null, &apps);
    defer service.deinit(std.testing.allocator);

    const first = try service.searchQuery(std.testing.allocator, "kit");
    defer std.testing.allocator.free(first);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));

    const second = try service.searchQuery(std.testing.allocator, "fire");
    defer std.testing.allocator.free(second);
    try std.testing.expect(apps.cache_data != null);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(apps.owned_strings.items.len)));
}

test "search service exposes modes without hiding default app search" {
    var modes = providers.ModesProvider{};
    var service = SearchService{
        .modes = &modes,
    };
    defer service.deinit(std.testing.allocator);

    const mode_results = try service.searchQuery(std.testing.allocator, "/");
    defer std.testing.allocator.free(mode_results);
    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(mode_results.len)));
    try std.testing.expectEqual(search.CandidateKind.mode, mode_results[0].candidate.kind);
}

test "search service ranks retained history without query history allocation" {
    var service = SearchService.init(null, null);
    defer service.deinit(std.testing.allocator);
    service.candidates_loaded = true;
    try history_access.recordLocked(&service.history, service.max_history, std.testing.allocator, "power");

    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const ranked = try service.searchQuery(fba.allocator(), "p");
    defer fba.allocator().free(ranked);

    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(ranked.len)));
}
