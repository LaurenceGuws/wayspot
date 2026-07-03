//! Search result facts shared by the picker, ranker, and app/action providers.

const std = @import("std");

pub const CandidateKind = enum {
    app,
    action,
    notification,
    hint,
};

/// Candidate is one renderable launcher result with an owned action contract supplied by its provider.
pub const Candidate = struct {
    kind: CandidateKind,
    title: []const u8,
    subtitle: []const u8,
    action: []const u8,
    icon: []const u8,

    pub fn init(
        kind: CandidateKind,
        title: []const u8,
        subtitle: []const u8,
        action: []const u8,
    ) Candidate {
        return .{
            .kind = kind,
            .title = title,
            .subtitle = subtitle,
            .action = action,
            .icon = "",
        };
    }

    pub fn initWithIcon(
        kind: CandidateKind,
        title: []const u8,
        subtitle: []const u8,
        action: []const u8,
        icon: []const u8,
    ) Candidate {
        return .{
            .kind = kind,
            .title = title,
            .subtitle = subtitle,
            .action = action,
            .icon = icon,
        };
    }
};

pub const CandidateList = std.ArrayList(Candidate);
