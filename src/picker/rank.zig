//! Ranking owns deterministic scoring for Apps and resident picker candidates.

const std = @import("std");
const query_mod = @import("wayspot_query");
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
    recent_selections: []const []const u8,
) ![]RankedCandidate {
    var scored = std.ArrayList(RankedCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query, candidate)) continue;
        const score = candidateScoreNewestFirst(query.route, query.term, candidate, recent_selections);
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
    history_selections: []const []u8,
) ![]RankedCandidate {
    var scored = std.ArrayList(RankedCandidate).empty;
    defer scored.deinit(allocator);

    for (candidates) |candidate| {
        if (!matchesRoute(query, candidate)) continue;
        const score = candidateScoreOldestFirst(query.route, query.term, candidate, history_selections);
        if (score <= 0) continue;
        try scored.append(allocator, .{ .candidate = candidate, .score = score });
    }

    std.mem.sort(RankedCandidate, scored.items, {}, lessThan);
    return scored.toOwnedSlice(allocator);
}

fn lessThan(_: void, a: RankedCandidate, b: RankedCandidate) bool {
    if (a.score != b.score) return a.score > b.score;

    const title_order = std.mem.order(u8, a.candidate.title(), b.candidate.title());
    if (title_order != .eq) return title_order == .lt;

    const subtitle_order = std.mem.order(u8, a.candidate.subtitle(), b.candidate.subtitle());
    if (subtitle_order != .eq) return subtitle_order == .lt;

    const selection_order = std.mem.order(u8, a.candidate.selection(), b.candidate.selection());
    if (selection_order != .eq) return selection_order == .lt;

    if (a.candidate.typeOf() != b.candidate.typeOf()) {
        return @intFromEnum(a.candidate.typeOf()) < @intFromEnum(b.candidate.typeOf());
    }

    const icon_order = std.mem.order(u8, a.candidate.iconName(), b.candidate.iconName());
    return icon_order == .lt;
}

fn matchesRoute(query: query_mod.Query, candidate: candidate_mod.Candidate) bool {
    if (!candidate_mod.Candidate.accepts(.query, candidate)) return false;
    return switch (query.route) {
        .blended, .apps => isAppsCandidate(candidate),
        .modes => matchesModeRoute(candidate),
        .notifications => matchesNotificationRoute(query.term, candidate),
        .wallpapers => matchesWallpaperRoute(candidate),
        .sunglasses => matchesSunglassesRoute(candidate),
        .run => true,
    };
}

/// isAppsCandidate is the complete Apps-mode composition policy.
fn isAppsCandidate(value: candidate_mod.Candidate) bool {
    return value.isApp() or value.isOpen();
}

fn matchesModeRoute(value: candidate_mod.Candidate) bool {
    return switch (value) {
        .sub_cmd => |route| switch (route) {
            .notifications => |child| switch (child) {
                .restart => true,
                .history => false,
            },
            .wallpaper => |child| switch (child) {
                .restart => true,
                .rotate => false,
            },
            .sunglasses => |child| switch (child) {
                .restart => true,
                .apply, .reconcile, .dim, .filter, .image => false,
            },
        },
        .concrete => false,
    };
}

fn candidateScoreNewestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: candidate_mod.Candidate,
    recent_selections: []const []const u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostNewestFirst(candidate.selection(), recent_selections);
}

fn candidateScoreOldestFirst(
    route: query_mod.Route,
    needle: []const u8,
    candidate: candidate_mod.Candidate,
    history_selections: []const []u8,
) i32 {
    const score = candidateScoreWithoutRecency(route, needle, candidate) orelse return 0;
    return score + recencyBoostOldestFirst(candidate.selection(), history_selections);
}

fn candidateScoreWithoutRecency(route: query_mod.Route, needle: []const u8, candidate: candidate_mod.Candidate) ?i32 {
    var score: i32 = baseWeight(route, candidate.typeOf());
    if (route == .notifications and isNotification(candidate)) {
        const history_filter = notificationHistoryFilter(needle) orelse return null;
        if (history_filter.len == 0) return score + notificationHistoryOrderBoost(candidate.selection());
        if (indexOfAsciiFold(candidate.title(), history_filter) == null and
            (candidate.subtitle().len == 0 or indexOfAsciiFold(candidate.subtitle(), history_filter) == null))
        {
            return null;
        }
        return score + 30 + notificationHistoryOrderBoost(candidate.selection());
    }
    if (needle.len == 0) return score;

    const title_contains = indexOfAsciiFold(candidate.title(), needle) != null;
    const subtitle_contains = candidate.subtitle().len > 0 and indexOfAsciiFold(candidate.subtitle(), needle) != null;

    if (!title_contains and !subtitle_contains) return null;
    if (eqlAsciiFold(candidate.title(), needle)) score += 100;
    if (startsWithAsciiFold(candidate.title(), needle)) score += 60;
    if (title_contains) score += 30;
    if (subtitle_contains) score += 10;
    score += shortQueryBias(needle.len, candidate.typeOf());
    return score;
}

fn matchesNotificationRoute(term: []const u8, candidate: candidate_mod.Candidate) bool {
    const history_route = notificationHistoryFilter(term) != null;
    if (history_route) return isNotification(candidate);
    return switch (candidate) {
        .sub_cmd => |value| switch (value) {
            .notifications => |child| switch (child) {
                .history => term.len == 0,
                .restart => true,
            },
            else => false,
        },
        .concrete => |leaf| switch (leaf) {
            .lifecycle => |value| switch (value) {
                .notifications_restart => true,
                else => false,
            },
            else => false,
        },
    };
}

fn matchesWallpaperRoute(candidate: candidate_mod.Candidate) bool {
    return switch (candidate) {
        .sub_cmd => |value| switch (value) {
            .wallpaper => true,
            else => false,
        },
        .concrete => |leaf| switch (leaf) {
            .lifecycle => |value| switch (value) {
                .wallpaper_restart, .wallpaper_rotate => true,
                else => false,
            },
            else => false,
        },
    };
}

fn matchesSunglassesRoute(candidate: candidate_mod.Candidate) bool {
    return switch (candidate) {
        .sub_cmd => |value| switch (value) {
            .sunglasses => true,
            else => false,
        },
        .concrete => |leaf| switch (leaf) {
            .lifecycle => |value| switch (value) {
                .sunglasses_restart, .sunglasses_apply, .sunglasses_reconcile, .sunglasses_dim, .sunglasses_filter, .sunglasses_image => true,
                else => false,
            },
            else => false,
        },
    };
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

fn shortQueryBias(needle_len: u64, kind: std.meta.Tag(candidate_mod.Candidate)) i32 {
    if (needle_len == 0 or needle_len > 2) return 0;
    return switch (kind) {
        .sub_cmd => 0,
        .concrete => 50,
    };
}

fn recencyBoostNewestFirst(selection: []const u8, history_selections: []const []const u8) i32 {
    var index: u32 = 0;
    for (history_selections) |recent| {
        if (!std.mem.eql(u8, recent, selection)) {
            index += 1;
            continue;
        }
        return recencyBonus(index);
    }
    return 0;
}

fn recencyBoostOldestFirst(selection: []const u8, history_selections: []const []u8) i32 {
    var remaining: u32 = @intCast(history_selections.len);
    for (history_selections) |recent| {
        remaining -= 1;
        if (!std.mem.eql(u8, recent, selection)) continue;
        return recencyBonus(remaining);
    }
    return 0;
}

fn recencyBonus(index: u32) i32 {
    const decay = @as(i32, @intCast(index)) * 5;
    const bonus = 40 - decay;
    return if (bonus > 0) bonus else 0;
}

fn baseWeight(route: query_mod.Route, kind: std.meta.Tag(candidate_mod.Candidate)) i32 {
    if (route == .run) return 0;
    if (route == .notifications) {
        return switch (kind) {
            .sub_cmd => 80,
            .concrete => 100,
        };
    }
    return switch (kind) {
        .sub_cmd => 80,
        .concrete => 100,
    };
}

fn isNotification(value: candidate_mod.Candidate) bool {
    return switch (value) {
        .sub_cmd => false,
        .concrete => |leaf| switch (leaf) {
            .notification => true,
            .app, .open, .lifecycle => false,
        },
    };
}

test "exact match outranks prefix match" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("kitty", "Terminal", "kitty", ""),
        candidate_mod.Candidate.appLeaf("kitty-manager", "Terminal", "km", ""),
    };

    const query = try query_mod.parse("kitty");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("kitty", ranked[0].candidate.title());
}

test "Apps route includes installed and fixed-local kinds" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("kitty", "Terminal", "kitty", ""),
        candidate_mod.Candidate.openLeaf("Terminal", "kitty", "terminal-open", ""),
    };

    const query = try query_mod.parse("@ term");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expect(ranked[0].candidate.isOpen());
    try std.testing.expect(ranked[1].candidate.isApp());
}

test "slash routes expose typed resident routes and notification history" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.lifecycleLeaf(candidate_mod.notificationsRestart()),
        candidate_mod.Candidate.subCmd(.{ .notifications = .{ .history = {} } }),
        candidate_mod.Candidate.subCmd(.{ .wallpaper = .{ .rotate = {} } }),
        candidate_mod.Candidate.subCmd(.{ .sunglasses = .{ .apply = {} } }),
        candidate_mod.Candidate.notificationLeaf("New message", "Mail: body", "notification-history:0:2"),
        candidate_mod.Candidate.notificationLeaf("Older message", "Mail: body", "notification-history:1:1"),
        candidate_mod.Candidate.lifecycleLeaf(candidate_mod.wallpaperRestart()),
        candidate_mod.Candidate.appLeaf("Kitty", "Terminal", "kitty", ""),
    };

    const notifications = try rankCandidates(std.testing.allocator, try query_mod.parse("/notifications"), &candidates);
    defer std.testing.allocator.free(notifications);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(notifications.len)));
    try std.testing.expectEqualStrings("lifecycle:notifications:restart", notifications[0].candidate.selection());

    const sunglasses = try rankCandidates(std.testing.allocator, try query_mod.parse("/sunglasses apply"), &candidates);
    defer std.testing.allocator.free(sunglasses);
    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(sunglasses.len)));
    try std.testing.expectEqualStrings("wayspot sunglasses apply", sunglasses[0].candidate.selection());

    const history = try rankCandidates(std.testing.allocator, try query_mod.parse("/notifications history"), &candidates);
    defer std.testing.allocator.free(history);
    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(history.len)));
    try std.testing.expectEqual(std.meta.Tag(candidate_mod.Candidate).concrete, history[0].candidate.typeOf());
    try std.testing.expectEqualStrings("notification-history:0:2", history[0].candidate.selection());
}

test "default route is Apps mode" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.lifecycleLeaf(candidate_mod.notificationsRestart()),
        candidate_mod.Candidate.lifecycleLeaf(candidate_mod.wallpaperRestart()),
        candidate_mod.Candidate.openLeaf("Settings", "System", "settings", ""),
        candidate_mod.Candidate.appLeaf("Kitty", "Terminal", "kitty", ""),
    };

    const ranked = try rankCandidates(std.testing.allocator, try query_mod.parse(""), &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expect(ranked[0].candidate.isApp());
    try std.testing.expect(ranked[1].candidate.isOpen());
}

test "empty apps route keeps installed and fixed-local scoring order" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("Firefox", "Browser", "firefox", ""),
        candidate_mod.Candidate.openLeaf("Focus Firefox", "Window open", "focus-firefox-open", ""),
        candidate_mod.Candidate.appLeaf("Alacritty", "Terminal", "alacritty", ""),
    };

    const query = try query_mod.parse("@ ");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 3), @as(u32, @intCast(ranked.len)));
    try std.testing.expect(ranked[0].candidate.isApp());
    try std.testing.expect(ranked[1].candidate.isApp());
    try std.testing.expect(ranked[2].candidate.isOpen());
    try std.testing.expectEqualStrings("Alacritty", ranked[0].candidate.title());
    try std.testing.expectEqualStrings("Firefox", ranked[1].candidate.title());
    try std.testing.expectEqualStrings("Focus Firefox", ranked[2].candidate.title());
}

test "recency history boosts repeated selections" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.openLeaf("Settings", "System", "settings", ""),
        candidate_mod.Candidate.openLeaf("Power menu", "Session", "power", ""),
    };
    const history = [_][]const u8{"power"};
    const query = try query_mod.parse("> p");
    const ranked = try rankCandidatesWithHistory(std.testing.allocator, query, &candidates, &history);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("Power menu", ranked[0].candidate.title());
}

test "newest-first and oldest-first histories produce equivalent recency ranking" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.openLeaf("Settings", "System", "settings", ""),
        candidate_mod.Candidate.openLeaf("Power menu", "Session", "power", ""),
        candidate_mod.Candidate.openLeaf("Terminal", "System", "terminal", ""),
    };
    const newest_first = [_][]const u8{ "power", "settings" };
    var settings = [_]u8{ 's', 'e', 't', 't', 'i', 'n', 'g', 's' };
    var power = [_]u8{ 'p', 'o', 'w', 'e', 'r' };
    const oldest_first = [_][]u8{ settings[0..], power[0..] };
    const query = try query_mod.parse("> e");

    const ranked_newest = try rankCandidatesWithHistory(std.testing.allocator, query, &candidates, &newest_first);
    defer std.testing.allocator.free(ranked_newest);
    const ranked_oldest = try rankCandidatesWithOldestFirstHistory(std.testing.allocator, query, &candidates, &oldest_first);
    defer std.testing.allocator.free(ranked_oldest);

    try std.testing.expectEqual(@as(u32, @intCast(ranked_newest.len)), @as(u32, @intCast(ranked_oldest.len)));
    var index: u32 = 0;
    while (index < ranked_newest.len) : (index += 1) {
        try std.testing.expectEqualStrings(ranked_newest[index].candidate.selection(), ranked_oldest[index].candidate.selection());
        try std.testing.expectEqual(ranked_newest[index].score, ranked_oldest[index].score);
    }
    try std.testing.expectEqualStrings("power", ranked_oldest[0].candidate.selection());
}

test "Apps route filters fixed-local leaves by title" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("Redis Desktop Manager", "Database GUI", "redis-desktop", ""),
        candidate_mod.Candidate.openLeaf("Settings", "System", "settings", ""),
    };

    const query = try query_mod.parse("/apps set");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 1), @as(u32, @intCast(ranked.len)));
    try std.testing.expect(ranked[0].candidate.isOpen());
    try std.testing.expectEqualStrings("Settings", ranked[0].candidate.title());
}

test "rankCandidates propagates scored result alloc failure" {
    var zero_buf: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&zero_buf);
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("alpha", "subtitle", "alpha", ""),
    };

    const query = try query_mod.parse("a");
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
        candidate_mod.Candidate.appLeaf("alpha", "subtitle", "alpha", ""),
    };

    const query = try query_mod.parse("a");
    try std.testing.expectError(
        error.OutOfMemory,
        rankCandidates(failing_allocator, query, &candidates),
    );
    try std.testing.expect(failing_state.has_induced_failure);
}

test "equal score and title uses deterministic tie-breakers" {
    const candidates = [_]candidate_mod.Candidate{
        candidate_mod.Candidate.appLeaf("Alpha", "Same", "z-open", ""),
        candidate_mod.Candidate.appLeaf("Alpha", "Same", "a-open", ""),
    };

    const query = try query_mod.parse("");
    const ranked = try rankCandidates(std.testing.allocator, query, &candidates);
    defer std.testing.allocator.free(ranked);

    try std.testing.expectEqual(@as(u32, 2), @as(u32, @intCast(ranked.len)));
    try std.testing.expectEqualStrings("a-open", ranked[0].candidate.selection());
    try std.testing.expectEqualStrings("z-open", ranked[1].candidate.selection());
}
