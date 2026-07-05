//! Workspace owns bounded workspace facts without monitor placement rules.

const std = @import("std");

pub const max_workspaces: u32 = 64;
pub const max_workspace_name_bytes: u32 = 96;
pub const max_workspace_monitor_refs: u32 = 8;
pub const max_workspace_window_refs: u32 = 128;

/// WorkspaceId is a source-provided workspace identity.
pub const WorkspaceId = struct {
    value: i32,
};

/// MonitorRef points at a monitor fact by source identity.
pub const MonitorRef = struct {
    id: i32,
};

/// WindowRef points at a window fact by source identity.
pub const WindowRef = struct {
    id: u64,
};

/// WorkspaceName owns one bounded workspace name.
pub const WorkspaceName = struct {
    bytes: [max_workspace_name_bytes]u8 = undefined,
    len: u32 = 0,

    /// init copies a source name into bounded owned storage.
    pub fn init(text: []const u8) !WorkspaceName {
        var name = WorkspaceName{};
        try name.set(text);
        return name;
    }

    /// set rejects empty and overlong source names.
    pub fn set(self: *WorkspaceName, text: []const u8) !void {
        if (text.len == 0 or text.len > max_workspace_name_bytes) return error.InvalidWorkspaceName;
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
    }

    /// slice returns the retained name bytes.
    pub fn slice(self: *const WorkspaceName) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// MonitorRefs owns bounded monitor refs where a workspace is visible.
pub const MonitorRefs = struct {
    items: [max_workspace_monitor_refs]MonitorRef = undefined,
    count: u32 = 0,

    /// append retains one monitor ref or rejects overflow.
    pub fn append(self: *MonitorRefs, ref: MonitorRef) !void {
        if (self.count >= max_workspace_monitor_refs) return error.TooManyWorkspaceMonitorRefs;
        self.items[self.count] = ref;
        self.count += 1;
    }
};

/// WindowRefs owns bounded window refs for one workspace fact.
pub const WindowRefs = struct {
    items: [max_workspace_window_refs]WindowRef = undefined,
    count: u32 = 0,

    /// append retains one window ref or rejects overflow.
    pub fn append(self: *WindowRefs, ref: WindowRef) !void {
        if (self.count >= max_workspace_window_refs) return error.TooManyWorkspaceWindowRefs;
        self.items[self.count] = ref;
        self.count += 1;
    }
};

/// Workspace owns one bounded workspace fact row.
pub const Workspace = struct {
    id: WorkspaceId,
    name: WorkspaceName,
    visible_on: MonitorRefs = .{},
    windows: WindowRefs = .{},

    /// init retains required workspace source facts.
    pub fn init(id: WorkspaceId, name_text: []const u8) !Workspace {
        return .{ .id = id, .name = try WorkspaceName.init(name_text) };
    }
};

/// WorkspaceList owns the bounded workspace fact set for a snapshot.
pub const WorkspaceList = struct {
    items: [max_workspaces]Workspace = undefined,
    count: u32 = 0,

    /// append retains one workspace or rejects overflow.
    pub fn append(self: *WorkspaceList, item: Workspace) !void {
        if (self.count >= max_workspaces) return error.TooManyWorkspaces;
        self.items[self.count] = item;
        self.count += 1;
    }

    /// at returns a retained workspace when index is inside the bounded list.
    pub fn at(self: *const WorkspaceList, index: u32) ?*const Workspace {
        if (index >= self.count) return null;
        return &self.items[index];
    }
};

test "workspace list and refs are bounded" {
    var list = WorkspaceList{};
    var index: u32 = 0;
    while (index < max_workspaces) : (index += 1) {
        var buf: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "ws-{d}", .{index});
        try list.append(try Workspace.init(.{ .value = @intCast(index) }, name));
    }
    try std.testing.expectError(error.TooManyWorkspaces, list.append(try Workspace.init(.{ .value = 99 }, "extra")));

    var workspace = try Workspace.init(.{ .value = 1 }, "main");
    index = 0;
    while (index < max_workspace_monitor_refs) : (index += 1) {
        try workspace.visible_on.append(.{ .id = @intCast(index) });
    }
    try std.testing.expectError(error.TooManyWorkspaceMonitorRefs, workspace.visible_on.append(.{ .id = 99 }));

    index = 0;
    while (index < max_workspace_window_refs) : (index += 1) {
        try workspace.windows.append(.{ .id = @intCast(index) });
    }
    try std.testing.expectError(error.TooManyWorkspaceWindowRefs, workspace.windows.append(.{ .id = 999 }));
}

test "workspace name rejects empty and overlong facts" {
    try std.testing.expectError(error.InvalidWorkspaceName, WorkspaceName.init(""));
    const overlong = [_]u8{'w'} ** (max_workspace_name_bytes + 1);
    try std.testing.expectError(error.InvalidWorkspaceName, WorkspaceName.init(&overlong));
}
