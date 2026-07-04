const std = @import("std");
const providers = @import("../providers/mod.zig");
const search = @import("../search/mod.zig");
const history_access = @import("search_service/history_access.zig");

pub const SearchService = struct {
    registry: providers.ProviderRegistry,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    candidates: search.CandidateList = .empty,
    candidates_loaded: bool = false,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,

    pub fn init(registry: providers.ProviderRegistry) SearchService {
        return .{ .registry = registry };
    }

    pub fn initWithHistoryPath(registry: providers.ProviderRegistry, history_path: []const u8) SearchService {
        return .{
            .registry = registry,
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
        try self.registry.collectAll(allocator, &self.candidates);
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
    var provider_list = [_]providers.Provider{.{ .apps = &apps }};
    var service = SearchService.init(providers.ProviderRegistry.init(&provider_list));
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

test "search service ranks retained history without query history allocation" {
    var provider_list = [_]providers.Provider{};
    var service = SearchService.init(providers.ProviderRegistry.init(&provider_list));
    defer service.deinit(std.testing.allocator);
    service.candidates_loaded = true;
    try history_access.recordLocked(&service.history, service.max_history, std.testing.allocator, "power");

    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const ranked = try service.searchQuery(fba.allocator(), "p");
    defer fba.allocator().free(ranked);

    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(ranked.len)));
}
