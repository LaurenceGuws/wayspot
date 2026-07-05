const std = @import("std");

const notification_history = @import("providers/notification_history.zig");

test "notification history provider declarations are tested" {
    std.testing.refAllDecls(notification_history);
}
