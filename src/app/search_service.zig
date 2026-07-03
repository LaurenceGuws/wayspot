const std = @import("std");
const providers = @import("../providers/mod.zig");
const search = @import("../search/mod.zig");
const history_access = @import("search_service/history_access.zig");

pub const SearchService = struct {
    registry: providers.ProviderRegistry,
    query_mu: std.Io.Mutex = .init,
    history_path: ?[]const u8 = null,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    max_history: u32 = 32,
    last_query_elapsed_ns: u64 = 0,
    last_query_had_provider_runtime_failure: bool = false,

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
        history_access.deinitHistory(&self.history, allocator);
    }

    pub fn searchQuery(self: *SearchService, allocator: std.mem.Allocator, raw_query: []const u8) ![]search.ScoredCandidate {
        const started_ns = nowNs();
        self.setProviderFailure(false);

        var candidates = search.CandidateList.empty;
        defer candidates.deinit(allocator);

        const report = try self.registry.collectAllWithReport(allocator, &candidates);
        self.setProviderFailure(report.had_runtime_failure);

        const recent = try self.historySnapshotNewestFirstOwned(allocator);
        defer history_access.freeSnapshot(allocator, recent);

        const ranked = try search.rankCandidatesWithHistory(
            allocator,
            search.parseQuery(raw_query),
            candidates.items,
            recent,
        );
        self.setElapsed(started_ns);
        return ranked;
    }

    pub fn defaultLoadout(self: *SearchService, allocator: std.mem.Allocator) ![]search.ScoredCandidate {
        return self.searchQuery(allocator, "");
    }

    pub fn prewarmProviders(self: *SearchService, allocator: std.mem.Allocator) !void {
        var candidates = search.CandidateList.empty;
        defer candidates.deinit(allocator);
        const report = try self.registry.collectAllWithReport(allocator, &candidates);
        self.setProviderFailure(report.had_runtime_failure);
    }

    pub fn recordSelection(self: *SearchService, allocator: std.mem.Allocator, action: []const u8) !void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        try history_access.recordLocked(&self.history, self.max_history, allocator, action);
    }

    pub fn historySnapshotNewestFirstOwned(self: *SearchService, allocator: std.mem.Allocator) ![]const []const u8 {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        return history_access.snapshotNewestFirstOwnedLocked(self.history.items, allocator);
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

    pub fn lastQueryElapsedNs(self: *SearchService) u64 {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        defer self.query_mu.unlock(std.Options.debug_io);
        return self.last_query_elapsed_ns;
    }

    fn setElapsed(self: *SearchService, started_ns: i96) void {
        const now = nowNs();
        const elapsed: u64 = if (now > started_ns) @intCast(now - started_ns) else 0;
        self.query_mu.lockUncancelable(std.Options.debug_io);
        self.last_query_elapsed_ns = elapsed;
        self.query_mu.unlock(std.Options.debug_io);
    }

    fn setProviderFailure(self: *SearchService, failed: bool) void {
        self.query_mu.lockUncancelable(std.Options.debug_io);
        self.last_query_had_provider_runtime_failure = failed;
        self.query_mu.unlock(std.Options.debug_io);
    }
};

fn nowNs() i96 {
    return std.Io.Clock.awake.now(std.Options.debug_io).toNanoseconds();
}
