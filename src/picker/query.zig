//! Query owns bounded picker input parsing for the reachable Cmd routes.

const std = @import("std");

/// max_query_bytes bounds one borrowed picker query before route parsing.
pub const max_query_bytes: usize = 256;

/// QueryError is the exact failure vocabulary for bounded query parsing.
pub const QueryError = error{
    QueryTooLong,
};

/// Route is the closed picker route grammar before a SubCmd is selected.
pub const Route = enum {
    blended,
    apps,
    modes,
    notifications,
    wallpapers,
    sunglasses,
    run,
};

/// Query borrows one bounded raw string and its parsed route term.
pub const Query = struct {
    /// raw is the trimmed query slice retained for interface use.
    raw: []const u8,
    /// route is the selected top-level picker route.
    route: Route,
    /// term is the route-local text used by ranking.
    term: []const u8,
};

/// parse maps the accepted query grammar to one reachable Cmd route.
/// The returned strings borrow raw_query; callers retain it while using Query.
pub fn parse(raw_query: []const u8) QueryError!Query {
    if (raw_query.len > max_query_bytes) return error.QueryTooLong;

    const raw = std.mem.trim(u8, raw_query, " \t\r\n");
    if (raw.len == 0) {
        return .{
            .raw = "",
            .route = .blended,
            .term = "",
        };
    }

    if (raw[0] == '/') return parseModeRoute(raw);

    const prefix = raw[0];
    const rest = std.mem.trim(u8, raw[1..], " \t");
    return switch (prefix) {
        '@' => .{ .raw = raw, .route = .apps, .term = rest },
        '>' => .{ .raw = raw, .route = .run, .term = rest },
        else => .{ .raw = raw, .route = .blended, .term = raw },
    };
}

fn parseModeRoute(raw: []const u8) Query {
    const body = std.mem.trim(u8, raw[1..], " \t");
    if (body.len == 0) return .{ .raw = raw, .route = .modes, .term = "" };
    if (modeTerm(body, "apps")) |term| return .{ .raw = raw, .route = .apps, .term = term };
    if (modeTerm(body, "notifications")) |term| return .{ .raw = raw, .route = .notifications, .term = term };
    if (modeTerm(body, "wallpapers")) |term| return .{ .raw = raw, .route = .wallpapers, .term = term };
    if (modeTerm(body, "sunglasses")) |term| return .{ .raw = raw, .route = .sunglasses, .term = term };
    return .{ .raw = raw, .route = .modes, .term = body };
}

fn modeTerm(body: []const u8, mode_name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, body, mode_name)) return null;
    if (body.len == mode_name.len) return "";
    if (body[mode_name.len] != ' ' and body[mode_name.len] != '\t') return null;
    return std.mem.trim(u8, body[mode_name.len + 1 ..], " \t");
}

test "parse empty query uses blended route" {
    const q = try parse("   ");
    try std.testing.expectEqual(Route.blended, q.route);
    try std.testing.expectEqualStrings("", q.term);
}

test "parse prefixed query routes correctly" {
    const q = try parse("@ kitty");
    try std.testing.expectEqual(Route.apps, q.route);
    try std.testing.expectEqualStrings("kitty", q.term);
}

test "parse slash modes and selected mode routes" {
    const modes = try parse("/");
    try std.testing.expectEqual(Route.modes, modes.route);
    try std.testing.expectEqualStrings("", modes.term);

    const filtered_modes = try parse("/not");
    try std.testing.expectEqual(Route.modes, filtered_modes.route);
    try std.testing.expectEqualStrings("not", filtered_modes.term);

    const notifications = try parse("/notifications");
    try std.testing.expectEqual(Route.notifications, notifications.route);
    try std.testing.expectEqualStrings("", notifications.term);

    const wallpapers = try parse("/wallpapers restart");
    try std.testing.expectEqual(Route.wallpapers, wallpapers.route);
    try std.testing.expectEqualStrings("restart", wallpapers.term);

    const sunglasses = try parse("/sunglasses apply");
    try std.testing.expectEqual(Route.sunglasses, sunglasses.route);
    try std.testing.expectEqualStrings("apply", sunglasses.term);

    const apps = try parse("/apps");
    try std.testing.expectEqual(Route.apps, apps.route);
    try std.testing.expectEqualStrings("", apps.term);
}

test "parse non-prefixed query stays blended" {
    const q = try parse("firefox");
    try std.testing.expectEqual(Route.blended, q.route);
    try std.testing.expectEqualStrings("firefox", q.term);
}

test "parse preserves every nested route term" {
    const notifications = try parse("/notifications history");
    try std.testing.expectEqual(Route.notifications, notifications.route);
    try std.testing.expectEqualStrings("history", notifications.term);

    const wallpapers = try parse("/wallpapers rotate");
    try std.testing.expectEqual(Route.wallpapers, wallpapers.route);
    try std.testing.expectEqualStrings("rotate", wallpapers.term);

    const sunglasses = try parse("/sunglasses image opacity");
    try std.testing.expectEqual(Route.sunglasses, sunglasses.route);
    try std.testing.expectEqualStrings("image opacity", sunglasses.term);
}

test "parse rejects one byte beyond the query bound" {
    var oversized: [max_query_bytes + 1]u8 = undefined;
    @memset(oversized[0..], 'x');
    try std.testing.expectError(error.QueryTooLong, parse(oversized[0..]));
}

test "parse accepts the exact query bound" {
    var exact: [max_query_bytes]u8 = undefined;
    @memset(exact[0..], 'x');
    const q = try parse(exact[0..]);
    try std.testing.expectEqual(Route.blended, q.route);
    try std.testing.expectEqual(max_query_bytes, q.term.len);
}
