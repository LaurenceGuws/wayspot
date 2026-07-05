//! Ranking owns deterministic scoring for app and picker rows.

const std = @import("std");
const query_mod = @import("query.zig");
const candidate_mod = @import("picker_candidate");

pub const RankedCandidate = struct {
    candidate: candidate_mod.Candidate,
    score: i32,
};

pub fn rankCandidates(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const candidate_mod.Candidate,
) ![]RankedCandidate {
    return rankCandidatesWithHistory(allocator, query, candidates, &.{});
}

pub fn rankCandidatesWithHistory(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const candidate_mod.Candidate,
    recent_opens: []const []const u8,
) ![]RankedCandidate {
    var scored = std.ArrayList(RankedCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query, candidate)) continue;
        const score = candidateScoreNewestFirst(query.route, query.term, candidate, recent_opens);
        if (score <= 0) continue;
        try scored.append(allocator, .{ .candidate = candidate, .score = score });
    }

    std.mem.sort(RankedCandidate, scored.items, {}, lessThan);
    return scored.toOwnedSlice(allocator);
}

pub fn rankCandidatesWithOldestFirstHistory(
    allocator: std.mem.Allocator,
    query: query_mod.Query,
    candidates: []const candidate_mod.Candidate,
    history_opens: []const []u8,
) ![]RankedCandidate {
    var scored = std.ArrayList(RankedCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query, candidate)) continue;
        const score = candidateScoreOldestFirst(query.route, query.term, candidate, history_opens);
        if (score <= 0) continue;
        try scored.append(allocator, .{ .candidate = candidate, .score = score });
    }

    std.mem.sort(RankedCandidate, scored.items, {}, lessThan);
    return scored.toOwnedSlice(allocator);
}

fn lessThan(_: void, a: RankedCandidate, b: RankedCandidate) bool {
    if (a.score != b.score) return a.score > b.score;

    const title_order = std.mem.order(u8, a.candidate.title, b.candidate.title);
    if (title_order != .eq) return title_order == .lt;

    const subtitle_order = std.mem.order(u8, a.candidate.subtitle, b.candidate.subtitle);
    if (subtitle_order != .eq) return subtitle_order == .lt;

    const open_order = std.mem.order(u8, a.candidate.open, b.candidate.open);
    if (open_order != .eq) return open_order == .lt;

    if (a.candidate.kind != b.candidate.kind) {
        return @intFromEnum(a.candidate.kind) < @intFromEnum(b.candidate.kind);
    }

    const icon_order = std.mem.order(u8, a.candidate.icon, b.candidate.icon);
    return icon_order == .lt;
}

fn matchesRoute(query: query_mod.Query, candidate: candidate_mod.Candidate) bool {
    return switch (query.route) {
        .blended => candidate.kind == .app,
        .apps => candidate.kind == .app,
        .modes => candidate.kind == .mode and !std.mem.eql(u8, candidate.open, "/notifications history"),
        .notifications => matchesNotificationRoute(query.term, candidate),
        .sunglasses => candidate.kind == .mode and std.mem.eql(u8, candidate.open, "/sunglasses"),
        .wallpapers => candidate.kind == .lifecycle and std.mem.eql(u8, candidate.open, "lifecycle:wallpapers:restart"),
        .run => true,
    };
}

fn candidateScoreNewestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: candidate_mod.Candidate,
    recent_opens: []const []const u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostNewestFirst(candidate.open, recent_opens);
}

fn candidateScoreOldestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: candidate_mod.Candidate,
    history_opens: []const []u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostOldestFirst(candidate.open, history_opens);
}

fn candidateScoreWithoutRecency(route: query_mod.Route, needle: []const u8, candidate: candidate_mod.Candidate) ?i32 {
    var score: i32 = baseWeight(route, candidate.kind);
    if (route == .notifications and candidate.kind == .notification) {
        const history_filter = notificationHistoryFilter(needle) orelse return null;
        if (history_filter.len == 0) return score + notificationHistoryOrderBoost(candidate.open);
        if (indexOfAsciiFold(candidate.title, history_filter) == null and
            (candidate.subtitle.len == 0 or indexOfAsciiFold(candidate.subtitle, history_filter) == null))
        {
            return null;
        }
        return score + 30 + notificationHistoryOrderBoost(candidate.open);
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

fn matchesNotificationRoute(term: []const u8, candidate: candidate_mod.Candidate) bool {
    if (notificationHistoryFilter(term) != null) return candidate.kind == .notification;
    if (candidate.kind == .lifecycle and std.mem.eql(u8, candidate.open, "lifecycle:notifications:restart")) return true;
    return candidate.kind == .mode and std.mem.eql(u8, candidate.open, "/notifications history");
}

fn notificationHistoryFilter(term: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, term, " \t");
    if (std.mem.eql(u8, trimmed, "history")) return "";
    if (!std.mem.startsWith(u8, trimmed, "history ")) return null;
    return std.mem.trim(u8, trimmed["history".len..], " \t");
}

fn notificationHistoryOrderBoost(open: []const u8) i32 {
    const prefix = "notification-history:";
    if (!std.mem.startsWith(u8, open, prefix)) return 0;
    const rest = open[prefix.len..];
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

fn shortQueryBias(needle_len: u64, kind: candidate_mod.Candidate.Kind) i32 {
    if (needle_len == 0 or needle_len > 2) return 0;
    return switch (kind) {
        .open => 50,
        .app => 0,
        .mode => 0,
        .lifecycle => 0,
        .notification => 0,
        .hint => 0,
    };
}

fn recencyBoostNewestFirst(open: []const u8, history_opens: []const []const u8) i32 {
    var index: u32 = 0;
    for (history_opens) |recent| {
        if (!std.mem.eql(u8, recent, open)) {
            index += 1;
            continue;
        }
        return recencyBonus(index);
    }
    return 0;
}

fn recencyBoostOldestFirst(open: []const u8, history_opens: []const []u8) i32 {
    var remaining: u32 = @intCast(history_opens.len);
    for (history_opens) |recent| {
        remaining -= 1;
        if (!std.mem.eql(u8, recent, open)) continue;
        return recencyBonus(remaining);
    }
    return 0;
}

fn recencyBonus(index: u32) i32 {
    const decay = @as(i32, @intCast(index)) * 5;
    const bonus = 40 - decay;
    return if (bonus > 0) bonus else 0;
}

fn baseWeight(route: query_mod.Route, kind: candidate_mod.Candidate.Kind) i32 {
    if (route == .run) return 0;
    if (route == .notifications) {
        return switch (kind) {
            .app => 0,
            .open => 0,
            .mode => 70,
            .lifecycle => 100,
            .notification => 60,
            .hint => 0,
        };
    }
    return switch (kind) {
        .app => 100,
        .open => 70,
        .mode => 90,
        .lifecycle => 80,
        .notification => 60,
        .hint => 10,
    };
}

test "exact match outranks prefix match" {
    const candidates = [_]candidate_mod.Candidate{
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
    const candidates = [_]candidate_mod.Candidate{
        .init(.app, "kitty", "Terminal", "kitty"),
        .init(.open, "Terminal", "kitty", "terminal-open"),
    };

    const query = query_mod.parse("@ term");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.app, ranked[0].candidate.kind);
}

test "slash routes expose modes and lifecycle commands only" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.mode, "/notifications", "Lifecycle mode", "/notifications"),
        .init(.mode, "/sunglasses", "Filter form", "/sunglasses"),
        .init(.mode, "/wallpapers", "Lifecycle mode", "/wallpapers"),
        .init(.lifecycle, "Restart notifications", "Lifecycle", "lifecycle:notifications:restart"),
        .init(.mode, "Notification history", "Lifecycle", "/notifications history"),
        .init(.notification, "New message", "Mail: body", "notification-history:0:2"),
        .init(.notification, "Older message", "Mail: body", "notification-history:1:1"),
        .init(.lifecycle, "Restart wallpaper", "Lifecycle", "lifecycle:wallpapers:restart"),
        .init(.app, "Kitty", "Terminal", "kitty"),
    };

    const modes = try rankCandidates(std.testing.allocator, query_mod.parse("/"), &candidates);
    defer std.testing.allocator.free(modes);
    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(modes.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.mode, modes[0].candidate.kind);

    const sunglasses = try rankCandidates(std.testing.allocator, query_mod.parse("/sunglasses"), &candidates);
    defer std.testing.allocator.free(sunglasses);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(sunglasses.len)));
    try std.testing.expectEqualStrings("/sunglasses", sunglasses[0].candidate.open);

    const notifications = try rankCandidates(std.testing.allocator, query_mod.parse("/notifications"), &candidates);
    defer std.testing.allocator.free(notifications);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(notifications.len)));
    try std.testing.expectEqualStrings("lifecycle:notifications:restart", notifications[0].candidate.open);

    const history = try rankCandidates(std.testing.allocator, query_mod.parse("/notifications history"), &candidates);
    defer std.testing.allocator.free(history);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(history.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.notification, history[0].candidate.kind);
    try std.testing.expectEqualStrings("notification-history:0:2", history[0].candidate.open);
}

test "default route is apps only" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.mode, "/notifications", "Lifecycle mode", "/notifications"),
        .init(.lifecycle, "Restart wallpaper", "Lifecycle", "lifecycle:wallpapers:restart"),
        .init(.open, "Settings", "System", "settings"),
        .init(.app, "Kitty", "Terminal", "kitty"),
    };

    const ranked = try rankCandidates(std.testing.allocator, query_mod.parse(""), &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.app, ranked[0].candidate.kind);
}

test "empty apps route keeps app-only scoring order" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.app, "Firefox", "Browser", "firefox"),
        .init(.open, "Focus Firefox", "Window open", "focus-firefox-open"),
        .init(.app, "Alacritty", "Terminal", "alacritty"),
    };

    const query = query_mod.parse("@ ");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.app, ranked[0].candidate.kind);
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.app, ranked[1].candidate.kind);
    try std.testing.expectEqualStrings("Alacritty", ranked[0].candidate.title);
    try std.testing.expectEqualStrings("Firefox", ranked[1].candidate.title);
}

test "recency history boosts repeated open rows" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.open, "Settings", "System", "settings"),
        .init(.open, "Power menu", "Session", "power"),
    };
    const history = [_][]const u8{"power"};
    const query = query_mod.parse("> p");
    const ranked = try rankCandidatesWithHistory(std.testing.allocator, query, &candidates, &history);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("Power menu", ranked[0].candidate.title);
}

test "newest-first and oldest-first histories produce equivalent recency ranking" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.open, "Settings", "System", "settings"),
        .init(.open, "Power menu", "Session", "power"),
        .init(.open, "Terminal", "System", "terminal"),
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
        try std.testing.expectEqualStrings(ranked_newest[index].candidate.open, ranked_oldest[index].candidate.open);
        try std.testing.expectEqual(ranked_newest[index].score, ranked_oldest[index].score);
    }
    try std.testing.expectEqualStrings("power", ranked_oldest[0].candidate.open);
}

test "default route ignores open rows" {
    const candidates = [_]candidate_mod.Candidate{
        .init(.app, "Redis Desktop Manager", "Database GUI", "redis-desktop"),
        .init(.open, "Settings", "System", "settings"),
    };

    const query = query_mod.parse("re");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqual(candidate_mod.Candidate.Kind.app, ranked[0].candidate.kind);
    try std.testing.expectEqualStrings("Redis Desktop Manager", ranked[0].candidate.title);
}

test "rankCandidates propagates scored result alloc failure" {
    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const candidates = [_]candidate_mod.Candidate{
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
    const candidates = [_]candidate_mod.Candidate{
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
    const candidates = [_]candidate_mod.Candidate{
        .init(.app, "Alpha", "Same", "z-open"),
        .init(.app, "Alpha", "Same", "a-open"),
    };

    const query = query_mod.parse("");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("a-open", ranked[0].candidate.open);
    try std.testing.expectEqualStrings("z-open", ranked[1].candidate.open);
}
