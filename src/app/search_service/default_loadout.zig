const std = @import("std");
const search = @import("../../search/mod.zig");

pub fn collect(service: anytype, allocator: std.mem.Allocator) ![]search.ScoredCandidate {
    const apps = try service.searchQuery(allocator, "@ ");
    defer allocator.free(apps);

    const dirs = try service.searchQuery(allocator, "~ ");
    defer allocator.free(dirs);

    const theme = try service.searchQuery(allocator, ", ");
    defer allocator.free(theme);

    const history = try service.historySnapshotNewestFirstOwned(allocator);
    defer freeHistorySnapshot(allocator, history);

    var merged = std.ArrayList(search.ScoredCandidate).empty;
    defer merged.deinit(allocator);

    try appendScoredRows(&merged, allocator, apps, history);
    try appendScoredRows(&merged, allocator, dirs, history);
    try appendScoredRows(&merged, allocator, theme, history);

    std.mem.sort(search.ScoredCandidate, merged.items, {}, lessThan);
    return merged.toOwnedSlice(allocator);
}

fn appendScoredRows(
    merged: *std.ArrayList(search.ScoredCandidate),
    allocator: std.mem.Allocator,
    rows: []const search.ScoredCandidate,
    history: []const []const u8,
) !void {
    for (rows) |row| {
        try merged.append(allocator, .{
            .candidate = row.candidate,
            .score = @as(i32, @intCast(actionFrequency(row.candidate.action, history) * 1000)),
        });
    }
}

fn actionFrequency(action: []const u8, history: []const []const u8) u32 {
    var count: u32 = 0;
    for (history) |entry| {
        if (std.mem.eql(u8, entry, action)) count += 1;
    }
    return count;
}

fn lessThan(_: void, a: search.ScoredCandidate, b: search.ScoredCandidate) bool {
    if (a.score != b.score) return a.score > b.score;
    const title_order = std.mem.order(u8, a.candidate.title, b.candidate.title);
    if (title_order != .eq) return title_order == .lt;
    return std.mem.order(u8, a.candidate.action, b.candidate.action) == .lt;
}

fn freeHistorySnapshot(allocator: std.mem.Allocator, snapshot: []const []const u8) void {
    for (snapshot) |entry| allocator.free(entry);
    allocator.free(snapshot);
}

