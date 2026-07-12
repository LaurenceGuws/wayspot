//! Picker candidates are the one tagged command vocabulary consumed by CLI and GUI.

const std = @import("std");

/// UserInput names the bounded input forms accepted by command consumers.
pub const UserInput = enum {
    query,
    selection,
    open,
    bash_completion,
};

/// user_input_types is the explicit DRY list shared by input validation and proof.
pub const user_input_types = [_]UserInput{ .query, .selection, .open, .bash_completion };

pub const max_candidates: u32 = 1024;

/// Row stores one bounded display and open record carried by a command candidate.
/// Every slice is borrowed; the producer retains and releases its backing bytes.
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

    /// List stores bounded candidates and borrows every string from its producer.
    /// Producers retain those strings until all consumers finish and then release them.
    pub const List = struct {
        items: [max_candidates]Candidate = undefined,
        count: u32 = 0,

        pub const empty = List{};

        /// append retains one candidate without allocating or copying its strings.
        pub fn append(self: *List, value: Candidate) !void {
            if (!isDeclaredType(value.typeOf())) return error.UnknownCandidateType;
            if (self.count >= max_candidates) return error.TooManyCandidates;
            self.items[self.count] = value;
            self.count += 1;
        }

        /// slice exposes only initialized candidates to a consumer.
        pub fn slice(self: *const List) []const Candidate {
            return self.items[0..self.count];
        }

        /// clearRetainingCapacity forgets records while retaining fixed storage.
        pub fn clearRetainingCapacity(self: *List) void {
            self.count = 0;
        }

        /// deinit clears borrowed records; the producers own and release their strings.
        pub fn deinit(self: *List) void {
            self.* = .empty;
        }
    };
    pub const Type = std.meta.Tag(Candidate);
    pub const types = [_]Type{ .app, .open, .mode, .lifecycle, .notification, .hint };

    /// accepts applies the one input policy used by query, selection, open, and Bash.
    pub fn accepts(input: UserInput, candidate_type: Type) bool {
        if (!isDeclaredInput(input) or !isDeclaredType(candidate_type)) return false;
        return switch (input) {
            .query, .selection => true,
            .open => switch (candidate_type) {
                .app, .open, .lifecycle => true,
                .mode, .notification, .hint => false,
            },
            .bash_completion => switch (candidate_type) {
                .app, .open, .mode, .lifecycle => true,
                .notification, .hint => false,
            },
        };
    }

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

fn isDeclaredInput(input: UserInput) bool {
    for (user_input_types) |declared| {
        if (declared == input) return true;
    }
    return false;
}

fn isDeclaredType(candidate_type: Candidate.Type) bool {
    for (Candidate.types) |declared| {
        if (declared == candidate_type) return true;
    }
    return false;
}

comptime {
    std.debug.assert(user_input_types.len == 4);
    std.debug.assert(Candidate.types.len == 6);
    std.debug.assert(max_candidates > 0);
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
    try std.testing.expectEqual(UserInput.bash_completion, user_input_types[user_input_types.len - 1]);
    try std.testing.expect(Candidate.accepts(.bash_completion, .mode));
    try std.testing.expect(!Candidate.accepts(.bash_completion, .notification));
}

test "candidate list rejects records beyond its fixed capacity" {
    var list = Candidate.List.empty;
    var index: u32 = 0;
    while (index < max_candidates) : (index += 1) {
        try list.append(Candidate.makeApp("App", "Utility", "app", ""));
    }
    try std.testing.expectError(error.TooManyCandidates, list.append(Candidate.makeApp("Overflow", "Utility", "overflow", "")));
    try std.testing.expectEqual(max_candidates, list.count);
}

test "candidate list cleanup does not claim producer string ownership" {
    var title = [_]u8{ 'A', 'p', 'p' };
    var list = Candidate.List.empty;
    try list.append(Candidate.makeApp(title[0..], "Utility", "app", ""));
    list.deinit();
    try std.testing.expectEqualStrings("App", title[0..]);
}
