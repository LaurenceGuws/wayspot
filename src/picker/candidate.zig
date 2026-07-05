//! Picker candidate rows shared by query routing, ranking, and mode owners.

const std = @import("std");

/// Candidate is one renderable picker row with the payload opened on selection.
pub const Candidate = struct {
    pub const Kind = enum {
        app,
        open,
        mode,
        lifecycle,
        notification,
        hint,
    };

    pub const List = std.ArrayList(Candidate);

    kind: Kind,
    title: []const u8,
    subtitle: []const u8,
    open: []const u8,
    icon: []const u8,

    /// Builds a candidate row without an icon name.
    pub fn init(
        kind: Kind,
        title: []const u8,
        subtitle: []const u8,
        open: []const u8,
    ) Candidate {
        return .{
            .kind = kind,
            .title = title,
            .subtitle = subtitle,
            .open = open,
            .icon = "",
        };
    }

    /// Builds a candidate row with an icon name resolved later by the picker surface.
    pub fn initWithIcon(
        kind: Kind,
        title: []const u8,
        subtitle: []const u8,
        open: []const u8,
        icon: []const u8,
    ) Candidate {
        return .{
            .kind = kind,
            .title = title,
            .subtitle = subtitle,
            .open = open,
            .icon = icon,
        };
    }
};
