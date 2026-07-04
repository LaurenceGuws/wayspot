//! Query parsing owns the small route prefix grammar for the launcher.

const std = @import("std");

pub const Route = enum {
    blended,
    apps,
    modes,
    notifications,
    sunglasses,
    wallpapers,
    run,
};

pub const Query = struct {
    raw: []const u8,
    route: Route,
    term: []const u8,
};

pub fn parse(raw_query: []const u8) Query {
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
    if (modeTerm(body, "notifications")) |term| return .{ .raw = raw, .route = .notifications, .term = term };
    if (modeTerm(body, "sunglasses")) |term| return .{ .raw = raw, .route = .sunglasses, .term = term };
    if (modeTerm(body, "wallpapers")) |term| return .{ .raw = raw, .route = .wallpapers, .term = term };
    return .{ .raw = raw, .route = .modes, .term = body };
}

fn modeTerm(body: []const u8, mode_name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, body, mode_name)) return null;
    if (body.len == mode_name.len) return "";
    if (body[mode_name.len] != ' ' and body[mode_name.len] != '\t') return null;
    return std.mem.trim(u8, body[mode_name.len + 1 ..], " \t");
}

test "parse empty query uses blended route" {
    const q = parse("   ");
    try std.testing.expectEqual(Route.blended, q.route);
    try std.testing.expectEqualStrings("", q.term);
}

test "parse prefixed query routes correctly" {
    const q = parse("@ kitty");
    try std.testing.expectEqual(Route.apps, q.route);
    try std.testing.expectEqualStrings("kitty", q.term);
}

test "parse slash modes and selected mode routes" {
    const modes = parse("/");
    try std.testing.expectEqual(Route.modes, modes.route);
    try std.testing.expectEqualStrings("", modes.term);

    const filtered_modes = parse("/not");
    try std.testing.expectEqual(Route.modes, filtered_modes.route);
    try std.testing.expectEqualStrings("not", filtered_modes.term);

    const notifications = parse("/notifications");
    try std.testing.expectEqual(Route.notifications, notifications.route);
    try std.testing.expectEqualStrings("", notifications.term);

    const sunglasses = parse("/sunglasses");
    try std.testing.expectEqual(Route.sunglasses, sunglasses.route);
    try std.testing.expectEqualStrings("", sunglasses.term);

    const wallpapers = parse("/wallpapers restart");
    try std.testing.expectEqual(Route.wallpapers, wallpapers.route);
    try std.testing.expectEqualStrings("restart", wallpapers.term);
}

test "parse non-prefixed query stays blended" {
    const q = parse("firefox");
    try std.testing.expectEqual(Route.blended, q.route);
    try std.testing.expectEqualStrings("firefox", q.term);
}
