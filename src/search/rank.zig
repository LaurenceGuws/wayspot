//! Ranking owns deterministic scoring for app and action launcher candidates.

const std = @import("std");
const query_mod = @import("query.zig");
const types = @import("types.zig");

pub const ScoredCandidate = struct {
    candidate: types.Candidate,
    score: i32,
};

pub fn rankCandidates(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const types.Candidate,
) ![]ScoredCandidate {
    return rankCandidatesWithHistory(allocator, query, candidates, &.{});
}

pub fn rankCandidatesWithHistory(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const types.Candidate,
    recent_actions: []const []const u8,
) ![]ScoredCandidate {
    var scored = std.ArrayList(ScoredCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query.route, candidate.kind)) continue;
        const score = candidateScoreNewestFirst(query.route, query.term, candidate, recent_actions);
        if (score <= 0) continue;
        try scored.append(allocator, .{ .candidate = candidate, .score = score });
    }

    std.mem.sort(ScoredCandidate, scored.items, {}, lessThan);
    return scored.toOwnedSlice(allocator);
}

pub fn rankCandidatesWithOldestFirstHistory(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const types.Candidate,
    history_actions: []const []u8,
) ![]ScoredCandidate {
    var scored = std.ArrayList(ScoredCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query.route, candidate.kind)) continue;
        const score = candidateScoreOldestFirst(query.route, query.term, candidate, history_actions);
        if (score <= 0) continue;
        try scored.append(allocator, .{ .candidate = candidate, .score = score });
    }

    std.mem.sort(ScoredCandidate, scored.items, {}, lessThan);
    return scored.toOwnedSlice(allocator);
}

fn lessThan(_: void, a: ScoredCandidate, b: ScoredCandidate) bool {
    if (a.score != b.score) return a.score > b.score;

    const title_order = std.mem.order(u8, a.candidate.title, b.candidate.title);
    if (title_order != .eq) return title_order == .lt;

    const subtitle_order = std.mem.order(u8, a.candidate.subtitle, b.candidate.subtitle);
    if (subtitle_order != .eq) return subtitle_order == .lt;

    const action_order = std.mem.order(u8, a.candidate.action, b.candidate.action);
    if (action_order != .eq) return action_order == .lt;

    if (a.candidate.kind != b.candidate.kind) {
        return @intFromEnum(a.candidate.kind) < @intFromEnum(b.candidate.kind);
    }

    const icon_order = std.mem.order(u8, a.candidate.icon, b.candidate.icon);
    return icon_order == .lt;
}

fn matchesRoute(route: query_mod.Route, kind: types.CandidateKind) bool {
    return switch (route) {
        .blended => true,
        .apps => kind == .app,
        .run => true,
    };
}

fn candidateScoreNewestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: types.Candidate,
    recent_actions: []const []const u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostNewestFirst(candidate.action, recent_actions);
}

fn candidateScoreOldestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: types.Candidate,
    history_actions: []const []u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostOldestFirst(candidate.action, history_actions);
}

fn candidateScoreWithoutRecency(route: query_mod.Route, needle: []const u8, candidate: types.Candidate) ?i32 {
    var score: i32 = baseWeight(route, candidate.kind);
    if (needle.len == 0) return score;

    const title_contains = indexOfAsciiFold(candidate.title, needle) != null;
    const subtitle_contains = candidate.subtitle.len > 0 and indexOfAsciiFold(candidate.subtitle, needle) != null;

    if (!title_contains and !subtitle_contains) return null;
    if (eqlAsciiFold(candidate.title, needle)) score += 100;
    if (startsWithAsciiFold(candidate.title, needle)) score += 60;
    if (title_contains) score += 30;
    if (subtitle_contains) score += 10;
    score += shortQueryBias(needle.len, candidate.kind);
    return score;
}

fn eqlAsciiFold(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len != needle.len) return false;
    var index: u32 = 0;
    while (index < needle.len) : (index += 1) {
        if (asciiFoldByte(haystack[index]) != asciiFoldByte(needle[index])) return false;
    }
    return true;
}

fn startsWithAsciiFold(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var index: u32 = 0;
    while (index < needle.len) : (index += 1) {
        if (asciiFoldByte(haystack[index]) != asciiFoldByte(needle[index])) return false;
    }
    return true;
}

fn indexOfAsciiFold(haystack: []const u8, needle: []const u8) ?u32 {
    if (needle.len == 0) return 0;
    if (needle.len > haystack.len) return null;
    var start: u32 = 0;
    const last_start: u32 = @intCast(haystack.len - needle.len);
    while (start <= last_start) : (start += 1) {
        var index: u32 = 0;
        while (index < needle.len) : (index += 1) {
            if (asciiFoldByte(haystack[start + index]) != asciiFoldByte(needle[index])) break;
        } else {
            return start;
        }
    }
    return null;
}

fn asciiFoldByte(ch: u8) u8 {
    return if (std.ascii.isAscii(ch)) std.ascii.toLower(ch) else ch;
}

fn shortQueryBias(needle_len: u64, kind: types.CandidateKind) i32 {
    if (needle_len == 0 or needle_len > 2) return 0;
    return switch (kind) {
        .action => 50,
        .app => 0,
        .notification => 0,
        .hint => 0,
    };
}

fn recencyBoostNewestFirst(action: []const u8, history_actions: []const []const u8) i32 {
    var index: u32 = 0;
    for (history_actions) |recent| {
        if (!std.mem.eql(u8, recent, action)) {
            index += 1;
            continue;
        }
        return recencyBonus(index);
    }
    return 0;
}

fn recencyBoostOldestFirst(action: []const u8, history_actions: []const []u8) i32 {
    var remaining: u32 = @intCast(history_actions.len);
    for (history_actions) |recent| {
        remaining -= 1;
        if (!std.mem.eql(u8, recent, action)) continue;
        return recencyBonus(remaining);
    }
    return 0;
}

fn recencyBonus(index: u32) i32 {
    const decay = @as(i32, @intCast(index)) * 5;
    const bonus = 40 - decay;
    return if (bonus > 0) bonus else 0;
}

fn baseWeight(route: query_mod.Route, kind: types.CandidateKind) i32 {
    if (route == .run) return 0;
    return switch (kind) {
        .app => 100,
        .action => 70,
        .notification => 60,
        .hint => 10,
    };
}

test "exact match outranks prefix match" {
    const candidates = [_]types.Candidate{
        .init(.app, "kitty", "Terminal", "kitty"),
        .init(.app, "kitty-manager", "Terminal", "km"),
    };

    const query = query_mod.parse("kitty");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("kitty", ranked[0].candidate.title);
}

test "route filter limits result kinds" {
    const candidates = [_]types.Candidate{
        .init(.app, "kitty", "Terminal", "kitty"),
        .init(.action, "Terminal", "kitty", "terminal-action"),
    };

    const query = query_mod.parse("@ term");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(types.CandidateKind.app, ranked[0].candidate.kind);
}

test "empty apps route keeps app-only scoring order" {
    const candidates = [_]types.Candidate{
        .init(.app, "Firefox", "Browser", "firefox"),
        .init(.action, "Focus Firefox", "Window action", "focus-firefox"),
        .init(.app, "Alacritty", "Terminal", "alacritty"),
    };

    const query = query_mod.parse("@ ");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(types.CandidateKind.app, ranked[0].candidate.kind);
    try std.testing.expectEqual(types.CandidateKind.app, ranked[1].candidate.kind);
    try std.testing.expectEqualStrings("Alacritty", ranked[0].candidate.title);
    try std.testing.expectEqualStrings("Firefox", ranked[1].candidate.title);
}

test "recency history boosts repeated action candidates" {
    const candidates = [_]types.Candidate{
        .init(.action, "Settings", "System", "settings"),
        .init(.action, "Power menu", "Session", "power"),
    };
    const history = [_][]const u8{"power"};
    const query = query_mod.parse("p");
    const ranked = try rankCandidatesWithHistory(std.testing.allocator, query, &candidates, &history);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("Power menu", ranked[0].candidate.title);
}

test "newest-first and oldest-first histories produce equivalent recency ranking" {
    const candidates = [_]types.Candidate{
        .init(.action, "Settings", "System", "settings"),
        .init(.action, "Power menu", "Session", "power"),
        .init(.action, "Terminal", "System", "terminal"),
    };
    const newest_first = [_][]const u8{ "power", "settings" };
    var settings = [_]u8{ 's', 'e', 't', 't', 'i', 'n', 'g', 's' };
    var power = [_]u8{ 'p', 'o', 'w', 'e', 'r' };
    const oldest_first = [_][]u8{ settings[0..], power[0..] };
    const query = query_mod.parse("");

    const ranked_newest = try rankCandidatesWithHistory(std.testing.allocator, query, &candidates, &newest_first);
    defer std.testing.allocator.free(ranked_newest);
    const ranked_oldest = try rankCandidatesWithOldestFirstHistory(std.testing.allocator, query, &candidates, &oldest_first);
    defer std.testing.allocator.free(ranked_oldest);

    try std.testing.expectEqual(@as(u32, @intCast(ranked_newest.len)), @as(u32, @intCast(ranked_oldest.len)));
    var index: u32 = 0;
    while (index < ranked_newest.len) : (index += 1) {
        try std.testing.expectEqualStrings(ranked_newest[index].candidate.action, ranked_oldest[index].candidate.action);
        try std.testing.expectEqual(ranked_newest[index].score, ranked_oldest[index].score);
    }
    try std.testing.expectEqualStrings("power", ranked_oldest[0].candidate.action);
}

test "short blended query prefers actions over broad app matches" {
    const candidates = [_]types.Candidate{
        .init(.app, "Redis Desktop Manager", "Database GUI", "redis-desktop"),
        .init(.action, "Settings", "System", "settings"),
    };

    const query = query_mod.parse("re");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(types.CandidateKind.action, ranked[0].candidate.kind);
    try std.testing.expectEqualStrings("Settings", ranked[0].candidate.title);
}

test "rankCandidates propagates scored result alloc failure" {
    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const candidates = [_]types.Candidate{
        .init(.app, "alpha", "subtitle", "alpha"),
    };

    const query = query_mod.parse("a");
    try std.testing.expectError(
        error.OutOfMemory,
        rankCandidates(fba.allocator(), query, &candidates),
    );
}

test "rankCandidates reports failing allocator on scored result alloc" {
    var failing_state = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 1,
    });
    const failing_allocator = failing_state.allocator();
    const candidates = [_]types.Candidate{
        .init(.app, "alpha", "subtitle", "alpha"),
    };

    const query = query_mod.parse("a");
    try std.testing.expectError(
        error.OutOfMemory,
        rankCandidates(failing_allocator, query, &candidates),
    );
    try std.testing.expect(failing_state.has_induced_failure);
}

test "equal score and title uses deterministic tie-breakers" {
    const candidates = [_]types.Candidate{
        .init(.app, "Alpha", "Same", "z-action"),
        .init(.app, "Alpha", "Same", "a-action"),
    };

    const query = query_mod.parse("");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("a-action", ranked[0].candidate.action);
    try std.testing.expectEqualStrings("z-action", ranked[1].candidate.action);
}
