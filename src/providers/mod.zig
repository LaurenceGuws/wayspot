const std = @import("std");

pub const AppsProvider = @import("apps.zig").AppsProvider;
pub const invalidateAppsCache = @import("apps.zig").invalidateDefaultCache;
pub const ActionsProvider = @import("actions.zig").ActionsProvider;
pub const ModesProvider = @import("modes.zig").ModesProvider;
const notification_history = @import("notification_history.zig");
pub const NotificationHistoryProvider = notification_history.NotificationHistoryProvider;
pub const executeAction = @import("actions.zig").executeAction;
pub const resolveDaemonCommand = @import("modes.zig").resolveDaemonCommand;
pub const resolveActionSpec = @import("actions.zig").resolveActionSpec;
pub const resolveExecutionCommand = @import("actions.zig").resolveExecutionCommand;

test "notification history provider is covered" {
    std.testing.refAllDecls(notification_history);
}
