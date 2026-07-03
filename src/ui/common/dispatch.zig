const std = @import("std");
const providers_mod = @import("../../providers/mod.zig");
const search = @import("../../search/mod.zig");
pub const kinds = @import("kinds.zig");

pub const NativeExecuteFn = *const fn (allocator: std.mem.Allocator, action: []const u8) anyerror!void;

pub const CommandPlan = struct {
    command: ?[]const u8 = null,
    owned_command: ?[]u8 = null,
    native_execute: ?NativeExecuteFn = null,
    telemetry_kind: []const u8 = "",
    telemetry_ok_detail: []const u8 = "",
    error_message: []const u8 = "",
    close_on_success: bool = false,
    detach_command: bool = false,
    unknown_action: bool = false,

    pub fn deinit(self: *CommandPlan, allocator: std.mem.Allocator) void {
        if (self.owned_command) |buf| allocator.free(buf);
        self.* = .{};
    }
};

pub fn shouldRecordSelection(kind: []const u8) bool {
    return shouldRecordSelectionKind(kinds.parse(kind));
}

pub fn shouldRecordSelectionKind(kind: kinds.UiKind) bool {
    return switch (kind) {
        .notification, .hint, .module => false,
        else => true,
    };
}

pub fn shouldRecordCandidate(kind: search.CandidateKind) bool {
    return switch (kind) {
        .notification, .hint => false,
        else => true,
    };
}

pub fn requiresConfirmation(kind: []const u8, action: []const u8) bool {
    return requiresConfirmationKind(kinds.parse(kind), action);
}

pub fn requiresConfirmationKind(kind: kinds.UiKind, action: []const u8) bool {
    return kind == .action and providers_mod.requiresConfirmation(action);
}

pub fn isDirMenuKind(kind: []const u8) bool {
    return isDirMenuKindEnum(kinds.parse(kind));
}

pub fn isDirMenuKindEnum(_: kinds.UiKind) bool {
    return false;
}

pub fn isFileMenuKind(kind: []const u8) bool {
    return isFileMenuKindEnum(kinds.parse(kind));
}

pub fn isFileMenuKindEnum(_: kinds.UiKind) bool {
    return false;
}

pub fn isModuleKind(kind: []const u8) bool {
    return isModuleKindEnum(kinds.parse(kind));
}

pub fn isModuleKindEnum(kind: kinds.UiKind) bool {
    return kind == .module;
}

pub fn planCommand(allocator: std.mem.Allocator, kind: []const u8, action: []const u8) !CommandPlan {
    return planCommandKind(allocator, kinds.parse(kind), action);
}

pub fn planCommandKind(allocator: std.mem.Allocator, kind: kinds.UiKind, action: []const u8) !CommandPlan {
    return switch (kind) {
        .app => planApp(action),
        .action => try planAction(allocator, action),
        else => .{
            .telemetry_kind = kinds.tag(kind),
            .error_message = "Unsupported result type",
            .unknown_action = true,
        },
    };
}

fn planApp(action: []const u8) CommandPlan {
    if (std.mem.eql(u8, action, "__drun__")) return .{};
    return .{
        .command = action,
        .telemetry_kind = "app",
        .telemetry_ok_detail = action,
        .error_message = "App failed to launch",
        .close_on_success = true,
        .detach_command = true,
    };
}

fn planAction(allocator: std.mem.Allocator, action: []const u8) !CommandPlan {
    const spec = providers_mod.resolveActionSpec(action) orelse {
        return .{
            .telemetry_kind = "action",
            .error_message = "Action failed: unknown action",
            .unknown_action = true,
        };
    };
    const cmd = try providers_mod.resolveExecutionCommand(allocator, spec.execution);
    return .{
        .command = cmd,
        .owned_command = cmd,
        .telemetry_kind = "action",
        .telemetry_ok_detail = action,
        .error_message = "Action failed to launch",
        .close_on_success = true,
        .detach_command = true,
    };
}

test "app action launches detached command" {
    var plan = try planCommandKind(std.testing.allocator, .app, "kitty");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("kitty", plan.command.?);
    try std.testing.expect(plan.detach_command);
    try std.testing.expect(plan.close_on_success);
}

test "configured action resolves through action provider" {
    var plan = try planCommandKind(std.testing.allocator, .action, "settings");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("wlrlui", plan.command.?);
    try std.testing.expectEqualStrings("action", plan.telemetry_kind);
}

test "unknown action is rejected" {
    var plan = try planCommandKind(std.testing.allocator, .action, "cmd:echo hacked");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.unknown_action);
    try std.testing.expect(plan.command == null);
}
