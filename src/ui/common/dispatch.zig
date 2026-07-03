const std = @import("std");
const providers_mod = @import("../../providers/mod.zig");
const search = @import("../../search/mod.zig");
pub const kinds = @import("kinds.zig");

pub const CommandPlan = struct {
    command: []const u8,
    owned_command: ?[]u8 = null,
    detach_command: bool = false,

    pub fn deinit(self: *CommandPlan, allocator: std.mem.Allocator) void {
        if (self.owned_command) |buf| allocator.free(buf);
    }
};

pub fn shouldRecordCandidate(kind: search.CandidateKind) bool {
    return switch (kind) {
        .notification, .hint => false,
        else => true,
    };
}

pub fn planCommandKind(allocator: std.mem.Allocator, kind: kinds.UiKind, action: []const u8) !CommandPlan {
    return switch (kind) {
        .app => planApp(action),
        .action => try planAction(allocator, action),
        .notification, .hint, .unknown => error.UnsupportedCommandKind,
    };
}

fn planApp(action: []const u8) !CommandPlan {
    if (action.len == 0) return error.EmptyCommand;
    return .{
        .command = action,
        .detach_command = true,
    };
}

fn planAction(allocator: std.mem.Allocator, action: []const u8) !CommandPlan {
    const spec = providers_mod.resolveActionSpec(action) orelse return error.UnknownAction;
    const cmd = try providers_mod.resolveExecutionCommand(allocator, spec.execution);
    return .{
        .command = cmd,
        .owned_command = cmd,
        .detach_command = true,
    };
}

test "app action launches detached command" {
    var plan = try planCommandKind(std.testing.allocator, .app, "kitty");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("kitty", plan.command);
    try std.testing.expect(plan.detach_command);
}

test "configured action resolves through action provider" {
    var plan = try planCommandKind(std.testing.allocator, .action, "settings");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("wlrlui", plan.command);
}

test "unknown action is rejected" {
    try std.testing.expectError(error.UnknownAction, planCommandKind(std.testing.allocator, .action, "cmd:echo hacked"));
}
