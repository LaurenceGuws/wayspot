const std = @import("std");
const search = @import("../../search/mod.zig");

pub const UiKind = enum {
    unknown,
    action,
    app,
    mode,
    daemon,
    notification,
    hint,
};

pub fn parse(kind: []const u8) UiKind {
    if (std.mem.eql(u8, kind, "action")) return .action;
    if (std.mem.eql(u8, kind, "app")) return .app;
    if (std.mem.eql(u8, kind, "mode")) return .mode;
    if (std.mem.eql(u8, kind, "daemon")) return .daemon;
    if (std.mem.eql(u8, kind, "notification")) return .notification;
    if (std.mem.eql(u8, kind, "hint")) return .hint;
    return .unknown;
}

pub fn tag(kind: UiKind) []const u8 {
    return switch (kind) {
        .action => "action",
        .app => "app",
        .mode => "mode",
        .daemon => "daemon",
        .notification => "notification",
        .hint => "hint",
        .unknown => "unknown",
    };
}

pub fn fromCandidateKind(kind: search.CandidateKind) UiKind {
    return switch (kind) {
        .app => .app,
        .mode => .mode,
        .daemon => .daemon,
        .notification => .notification,
        .action => .action,
        .hint => .hint,
    };
}
