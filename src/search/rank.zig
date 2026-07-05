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
        if (!matchesRoute(query, candidate)) continue;
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
        if (!matchesRoute(query, candidate)) continue;
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

fn matchesRoute(query: query_mod.Query, candidate: types.Candidate) bool {
    return switch (query.route) {
        .blended => candidate.kind == .app,
        .apps => candidate.kind == .app,
        .modes => candidate.kind == .mode and !std.mem.eql(u8, candidate.action, "/notifications history"),
        .notifications => matchesNotificationRoute(query.term, candidate),
        .sunglasses => false,
        .wallpapers => candidate.kind == .daemon and std.mem.eql(u8, candidate.action, "daemon:wallpapers:restart"),
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
    if (route == .notifications and candidate.kind == .notification) {
        const history_filter = notificationHistoryFilter(needle) orelse return null;
        if (history_filter.len == 0) return score + notificationHistoryOrderBoost(candidate.action);
        if (indexOfAsciiFold(candidate.title, history_filter) == null and
            (candidate.subtitle.len == 0 or indexOfAsciiFold(candidate.subtitle, history_filter) == null))
        {
            return null;
        }
        return score + 30 + notificationHistoryOrderBoost(candidate.action);
    }
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

fn matchesNotificationRoute(term: []const u8, candidate: types.Candidate) bool {
    if (notificationHistoryFilter(term) != null) return candidate.kind == .notification;
    if (candidate.kind == .daemon and std.mem.eql(u8, candidate.action, "daemon:notifications:restart")) return true;
    return candidate.kind == .mode and std.mem.eql(u8, candidate.action, "/notifications history");
}

fn notificationHistoryFilter(term: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, term, " \t");
    if (std.mem.eql(u8, trimmed, "history")) return "";
    if (!std.mem.startsWith(u8, trimmed, "history ")) return null;
    return std.mem.trim(u8, trimmed["history".len..], " \t");
}

fn notificationHistoryOrderBoost(action: []const u8) i32 {
    const prefix = "notification-history:";
    if (!std.mem.startsWith(u8, action, prefix)) return 0;
    const rest = action[prefix.len..];
    const end = std.mem.indexOfScalar(u8, rest, ':') orelse return 0;
    const rank = std.fmt.parseInt(u32, rest[0..end], 10) catch return 0;
    const bounded_rank = @min(rank, 900);
    return 1000 - @as(i32, @intCast(bounded_rank));
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
        .mode => 0,
        .daemon => 0,
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
    if (route == .notifications) {
        return switch (kind) {
            .app => 0,
            .action => 0,
            .mode => 70,
            .daemon => 100,
            .notification => 60,
            .hint => 0,
        };
    }
    return switch (kind) {
        .app => 100,
        .action => 70,
        .mode => 90,
        .daemon => 80,
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

test "slash routes expose modes and daemon commands only" {
    const candidates = [_]types.Candidate{
        .init(.mode, "/notifications", "Runtime mode", "/notifications"),
        .init(.mode, "/sunglasses", "Filter form", "/sunglasses"),
        .init(.mode, "/wallpapers", "Runtime mode", "/wallpapers"),
        .init(.daemon, "Restart notifications daemon", "Runtime", "daemon:notifications:restart"),
        .init(.mode, "Notification history", "Runtime", "/notifications history"),
        .init(.notification, "New message", "Mail: body", "notification-history:0:2"),
        .init(.notification, "Older message", "Mail: body", "notification-history:1:1"),
        .init(.daemon, "Restart wallpaper daemon", "Runtime", "daemon:wallpapers:restart"),
        .init(.app, "Kitty", "Terminal", "kitty"),
    };

    const modes = try rankCandidates(std.testing.allocator, query_mod.parse("/"), &candidates);
    defer std.testing.allocator.free(modes);
    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(modes.len)));
    try std.testing.expectEqual(types.CandidateKind.mode, modes[0].candidate.kind);

    const sunglasses = try rankCandidates(std.testing.allocator, query_mod.parse("/sunglasses"), &candidates);
    defer std.testing.allocator.free(sunglasses);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @intCast(sunglasses.len)));

    const notifications = try rankCandidates(std.testing.allocator, query_mod.parse("/notifications"), &candidates);
    defer std.testing.allocator.free(notifications);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(notifications.len)));
    try std.testing.expectEqualStrings("daemon:notifications:restart", notifications[0].candidate.action);

    const history = try rankCandidates(std.testing.allocator, query_mod.parse("/notifications history"), &candidates);
    defer std.testing.allocator.free(history);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(history.len)));
    try std.testing.expectEqual(types.CandidateKind.notification, history[0].candidate.kind);
    try std.testing.expectEqualStrings("notification-history:0:2", history[0].candidate.action);
}

test "default route is apps only" {
    const candidates = [_]types.Candidate{
        .init(.mode, "/notifications", "Daemon mode", "/notifications"),
        .init(.daemon, "Restart wallpaper daemon", "Runtime", "daemon:wallpapers:restart"),
        .init(.action, "Settings", "System", "settings"),
        .init(.app, "Kitty", "Terminal", "kitty"),
    };

    const ranked = try rankCandidates(std.testing.allocator, query_mod.parse(""), &candidates);
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
    const query = query_mod.parse("> p");
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
    const query = query_mod.parse("> e");

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

test "default route ignores action rows" {
    const candidates = [_]types.Candidate{
        .init(.app, "Redis Desktop Manager", "Database GUI", "redis-desktop"),
        .init(.action, "Settings", "System", "settings"),
    };

    const query = query_mod.parse("re");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(types.CandidateKind.app, ranked[0].candidate.kind);
    try std.testing.expectEqualStrings("Redis Desktop Manager", ranked[0].candidate.title);
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
