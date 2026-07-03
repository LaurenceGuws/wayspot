const std = @import("std");
const search = @import("../../search/mod.zig");

pub const UiKind = enum {
    unknown,
    action,
    app,
    notification,
    hint,
};

pub fn parse(kind: []const u8) UiKind {
    if (std.mem.eql(u8, kind, "action")) return .action;
    if (std.mem.eql(u8, kind, "app")) return .app;
    if (std.mem.eql(u8, kind, "notification")) return .notification;
    if (std.mem.eql(u8, kind, "hint")) return .hint;
    return .unknown;
}

pub fn tag(kind: UiKind) []const u8 {
    return switch (kind) {
        .action => "action",
        .app => "app",
        .notification => "notification",
        .hint => "hint",
        .unknown => "unknown",
    };
}

pub fn statusLabel(kind: UiKind) []const u8 {
    return switch (kind) {
        .app => "app",
        .notification => "notification",
        .action => "action",
        .hint => "hint",
        else => "result",
    };
}

pub fn fromCandidateKind(kind: search.CandidateKind) UiKind {
    return switch (kind) {
        .app => .app,
        .notification => .notification,
        .action => .action,
        .hint => .hint,
    };
}
