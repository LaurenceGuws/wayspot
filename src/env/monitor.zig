//! Monitor owns bounded screen-output facts from SDL or compositor sources.

const std = @import("std");
const c = @import("sdl_c");

pub const max_monitors: u32 = 8;
pub const max_monitor_name_bytes: u32 = 96;
pub const max_current_active_workspaces_per_monitor: u32 = 8;

/// MonitorId is an opaque source-provided monitor identity.
pub const MonitorId = struct {
    value: i32,
};

/// WorkspaceRef names one workspace currently active for a monitor source fact.
pub const WorkspaceRef = struct {
    id: i32,
};

/// MonitorSize stores pixel dimensions as plain source facts.
pub const MonitorSize = struct {
    width: i32,
    height: i32,

    /// init rejects empty or negative geometry so callers cannot retain nonsense.
    pub fn init(width: i32, height: i32) !MonitorSize {
        if (width <= 0 or height <= 0) return error.InvalidMonitorSize;
        return .{ .width = width, .height = height };
    }
};

/// MonitorScale stores optional source scale without deriving layout meaning.
pub const MonitorScale = struct {
    value: f64,

    /// init rejects non-positive scale values from external sources.
    pub fn init(value: f64) !MonitorScale {
        if (value <= 0) return error.InvalidMonitorScale;
        return .{ .value = value };
    }
};

/// MonitorName owns one bounded monitor name.
pub const MonitorName = struct {
    bytes: [max_monitor_name_bytes]u8 = undefined,
    len: u32 = 0,

    /// init copies a source name into bounded owned storage.
    pub fn init(text: []const u8) !MonitorName {
        var name = MonitorName{};
        try name.set(text);
        return name;
    }

    /// set rejects empty and overlong source names.
    pub fn set(self: *MonitorName, text: []const u8) !void {
        if (text.len == 0 or text.len > max_monitor_name_bytes) return error.InvalidMonitorName;
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
    }

    /// slice returns the retained name bytes.
    pub fn slice(self: *const MonitorName) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// WorkspaceRefs owns bounded current-active workspace references for one monitor.
pub const WorkspaceRefs = struct {
    items: [max_current_active_workspaces_per_monitor]WorkspaceRef = undefined,
    count: u32 = 0,

    /// append retains one workspace ref or rejects overflow.
    pub fn append(self: *WorkspaceRefs, ref: WorkspaceRef) !void {
        if (self.count >= max_current_active_workspaces_per_monitor) return error.TooManyCurrentActiveWorkspaces;
        self.items[self.count] = ref;
        self.count += 1;
    }

    /// at returns a retained ref when index is inside the bounded list.
    pub fn at(self: *const WorkspaceRefs, index: u32) ?WorkspaceRef {
        if (index >= self.count) return null;
        return self.items[index];
    }
};

/// Monitor owns one bounded source fact row for a screen output.
pub const Monitor = struct {
    id: MonitorId,
    name: MonitorName,
    size: MonitorSize,
    scale: ?MonitorScale = null,
    focused: bool = false,
    current_active: WorkspaceRefs = .{},

    /// init retains required source facts. SDL display APIs may feed these facts,
    /// but monitor remains the env domain noun.
    pub fn init(id: MonitorId, name_text: []const u8, size: MonitorSize) !Monitor {
        return .{
            .id = id,
            .name = try MonitorName.init(name_text),
            .size = size,
        };
    }

    /// addCurrentActiveWorkspace retains a source fact without deriving layout meaning.
    pub fn addCurrentActiveWorkspace(self: *Monitor, ref: WorkspaceRef) !void {
        try self.current_active.append(ref);
    }

    /// nameText returns the retained source name for compositor APIs.
    pub fn nameText(self: *const Monitor) []const u8 {
        return self.name.slice();
    }
};

/// MonitorList owns the bounded monitor fact set for a snapshot.
pub const MonitorList = struct {
    items: [max_monitors]Monitor = undefined,
    count: u32 = 0,

    /// append retains one monitor or rejects overflow.
    pub fn append(self: *MonitorList, item: Monitor) !void {
        if (self.count >= max_monitors) return error.TooManyMonitors;
        self.items[self.count] = item;
        self.count += 1;
    }

    /// at returns a retained monitor when index is inside the bounded list.
    pub fn at(self: *const MonitorList, index: u32) ?*const Monitor {
        if (index >= self.count) return null;
        return &self.items[index];
    }
};

/// WaylandHandles stores SDL-provided Wayland handles for one Wayspot window.
pub const WaylandHandles = struct {
    wl_display: *c.struct_wl_display,
    wl_surface: *c.struct_wl_surface,
};

/// queryMonitors loads monitor facts from SDL display APIs on the main thread.
pub fn queryMonitors() !MonitorList {
    var raw_count: c_int = 0;
    const ids = c.SDL_GetDisplays(&raw_count) orelse return error.SdlMonitorQueryFailed;
    defer c.SDL_free(ids);
    if (raw_count < 0) return error.SdlMonitorQueryFailed;
    const count: u32 = @intCast(raw_count);
    var list = MonitorList{};
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        const source_id = ids[index];
        const name = try monitorName(source_id);
        const size = try monitorSize(source_id);
        var monitor = try Monitor.init(.{ .value = @intCast(source_id) }, name.slice(), size);
        monitor.scale = monitorScale(source_id) catch null;
        try list.append(monitor);
    }
    return list;
}

/// monitorName converts one SDL display name into the monitor domain noun.
pub fn monitorName(source_id: c.SDL_DisplayID) !MonitorName {
    const name_ptr = c.SDL_GetDisplayName(source_id) orelse return error.SdlMonitorNameMissing;
    return MonitorName.init(std.mem.span(name_ptr));
}

/// monitorSize converts one SDL display bounds record into a monitor size fact.
pub fn monitorSize(source_id: c.SDL_DisplayID) !MonitorSize {
    var rect: c.SDL_Rect = undefined;
    if (!c.SDL_GetDisplayBounds(source_id, &rect)) return error.SdlMonitorSizeMissing;
    return MonitorSize.init(rect.w, rect.h);
}

/// monitorScale returns the optional SDL scale fact for one monitor source.
pub fn monitorScale(source_id: c.SDL_DisplayID) !MonitorScale {
    const scale = c.SDL_GetDisplayContentScale(source_id);
    if (scale <= 0) return error.SdlMonitorScaleMissing;
    return MonitorScale.init(scale);
}

/// waylandOutput returns SDL's wl_output implementation source for a monitor.
pub fn waylandOutput(source_id: c.SDL_DisplayID) !*c.struct_wl_output {
    const props = c.SDL_GetDisplayProperties(source_id);
    if (props == 0) return error.SdlMonitorPropertyMissing;
    const raw = c.SDL_GetPointerProperty(props, c.SDL_PROP_DISPLAY_WAYLAND_WL_OUTPUT_POINTER, null) orelse return error.SdlMonitorPropertyMissing;
    return @ptrCast(@alignCast(raw));
}

/// windowWaylandHandles returns SDL's Wayland handles for a Wayspot-owned window.
pub fn windowWaylandHandles(window: *c.SDL_Window) !WaylandHandles {
    const props = c.SDL_GetWindowProperties(window);
    if (props == 0) return error.SdlWindowPropertyMissing;
    const raw_display = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null) orelse return error.SdlWindowPropertyMissing;
    const raw_surface = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null) orelse return error.SdlWindowPropertyMissing;
    return .{
        .wl_display = @ptrCast(@alignCast(raw_display)),
        .wl_surface = @ptrCast(@alignCast(raw_surface)),
    };
}

test "monitor list and current active refs are bounded" {
    const size = try MonitorSize.init(1920, 1080);
    var list = MonitorList{};
    var index: u32 = 0;
    while (index < max_monitors) : (index += 1) {
        var buf: [16]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "MON-{d}", .{index});
        try list.append(try Monitor.init(.{ .value = @intCast(index) }, name, size));
    }
    try std.testing.expectError(error.TooManyMonitors, list.append(try Monitor.init(.{ .value = 99 }, "extra", size)));

    var monitor = try Monitor.init(.{ .value = 1 }, "DP-1", size);
    index = 0;
    while (index < max_current_active_workspaces_per_monitor) : (index += 1) {
        try monitor.addCurrentActiveWorkspace(.{ .id = @intCast(index) });
    }
    try std.testing.expectError(error.TooManyCurrentActiveWorkspaces, monitor.addCurrentActiveWorkspace(.{ .id = 99 }));
}

test "monitor name and geometry reject invalid source facts" {
    try std.testing.expectError(error.InvalidMonitorName, MonitorName.init(""));
    const overlong = [_]u8{'x'} ** (max_monitor_name_bytes + 1);
    try std.testing.expectError(error.InvalidMonitorName, MonitorName.init(&overlong));
    try std.testing.expectError(error.InvalidMonitorSize, MonitorSize.init(0, 1080));
    try std.testing.expectError(error.InvalidMonitorScale, MonitorScale.init(0));
}

test "missing SDL properties fail cleanly" {
    try std.testing.expectError(error.SdlMonitorPropertyMissing, waylandOutput(0));
}
