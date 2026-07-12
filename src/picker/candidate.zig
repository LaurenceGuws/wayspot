//! Picker candidates are the one tagged command vocabulary consumed by CLI and GUI.

const std = @import("std");

/// UserInput names the bounded input forms accepted by command consumers.
pub const UserInput = enum {
    query,
    selection,
    open,
};

/// user_input_types is the explicit DRY list shared by input validation and proof.
pub const user_input_types = [_]UserInput{ .query, .selection, .open };

/// Row stores one bounded display and open record carried by a command candidate.
pub const Row = struct {
    title: []const u8,
    subtitle: []const u8,
    open: []const u8,
    icon: []const u8 = "",
};

/// Candidate is the complete tagged command vocabulary consumed by CLI and GUI.
pub const Candidate = union(enum) {
    app: Row,
    open: Row,
    mode: Row,
    lifecycle: Row,
    notification: Row,
    hint: Row,

    pub const List = std.ArrayList(Candidate);
    pub const Type = std.meta.Tag(Candidate);
    pub const types = [_]Type{ .app, .open, .mode, .lifecycle, .notification, .hint };

    /// makeApp creates one launchable desktop application candidate.
    pub fn makeApp(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8, icon: []const u8) Candidate {
        return .{ .app = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload, .icon = icon } };
    }

    /// open creates one file, URL, or direct open candidate.
    pub fn openRow(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8, icon: []const u8) Candidate {
        return .{ .open = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload, .icon = icon } };
    }

    /// mode creates one bounded query mode candidate.
    pub fn makeMode(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8) Candidate {
        return .{ .mode = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload } };
    }

    /// lifecycle creates one direct lifecycle command candidate.
    pub fn makeLifecycle(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8) Candidate {
        return .{ .lifecycle = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload } };
    }

    /// notification creates one retained notification candidate.
    pub fn makeNotification(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8) Candidate {
        return .{ .notification = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload } };
    }

    /// hint creates one non-launching explanatory candidate.
    pub fn makeHint(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8) Candidate {
        return .{ .hint = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload } };
    }

    /// typeOf returns the union tag without a parallel kind field.
    pub fn typeOf(self: Candidate) Type {
        return std.meta.activeTag(self);
    }

    /// row returns the display and open record owned by the active candidate tag.
    pub fn row(self: Candidate) Row {
        return switch (self) {
            inline else => |value| value,
        };
    }

    /// title returns the bounded display title consumed by interfaces.
    pub fn title(self: Candidate) []const u8 {
        return self.row().title;
    }

    /// subtitle returns the bounded display subtitle consumed by interfaces.
    pub fn subtitle(self: Candidate) []const u8 {
        return self.row().subtitle;
    }

    /// openPayload returns the command or query payload selected by an interface.
    pub fn openPayload(self: Candidate) []const u8 {
        return self.row().open;
    }

    /// iconName returns the optional icon name carried by an application candidate.
    pub fn iconName(self: Candidate) []const u8 {
        return self.row().icon;
    }
};

comptime {
    std.debug.assert(user_input_types.len == 3);
    std.debug.assert(Candidate.types.len == 6);
}

test "candidate is one explicit tagged union vocabulary" {
    const row = Candidate.makeApp("Foot", "Utilities", "foot", "foot");
    try std.testing.expectEqual(Candidate.Type.app, row.typeOf());
    try std.testing.expectEqualStrings("Foot", row.title());
    try std.testing.expectEqualStrings("foot", row.openPayload());
    try std.testing.expectEqual(@as(u32, @intCast(Candidate.types.len)), 6);
}

test "user input list is explicit and bounded" {
    try std.testing.expectEqual(UserInput.query, user_input_types[0]);
    try std.testing.expectEqual(UserInput.open, user_input_types[user_input_types.len - 1]);
}
