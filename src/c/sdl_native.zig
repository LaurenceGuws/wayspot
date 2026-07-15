//! Native SDL display and window ownership behind the plain sdl_io contract.

const std = @import("std");
const c = @import("sdl_c");
const sdl_io = @import("sdl_io");

/// NativeWaylandHandles is an adapter-internal borrowed SDL handle handoff.
pub const NativeWaylandHandles = struct {
    /// display is borrowed from the SDL window and never disconnected here.
    display: *c.struct_wl_display,
    /// surface is borrowed from the SDL window and never destroyed here.
    surface: *c.struct_wl_surface,
};

/// displaySource supplies native display facts to the env monitor owner.
pub fn displaySource() sdl_io.NativeDisplaySource {
    return .{
        .query_displays = queryDisplays,
        .query_name = queryName,
        .query_bounds = queryBounds,
        .query_scale = queryScale,
    };
}

fn queryDisplays() sdl_io.DisplayError!sdl_io.DisplayList {
    var raw_count: c_int = 0;
    const ids = c.SDL_GetDisplays(&raw_count) orelse return error.SdlMonitorQueryFailed;
    defer c.SDL_free(ids);
    const count = try sdl_io.mapDisplayCount(@as(i64, @intCast(raw_count)));
    var result = sdl_io.DisplayList{ .count = count };
    var index: u32 = 0;
    while (index < count) : (index += 1) result.items[index] = @intCast(ids[index]);
    return result;
}

fn queryName(id: sdl_io.DisplayId) sdl_io.DisplayError!sdl_io.DisplayName {
    const name_ptr = c.SDL_GetDisplayName(@intCast(id)) orelse return error.SdlMonitorNameMissing;
    return displayNameFromSentinel(name_ptr);
}

/// displayNameFromSentinel scans one SDL name only through its bounded terminator.
pub fn displayNameFromSentinel(name_ptr: [*]const u8) sdl_io.DisplayError!sdl_io.DisplayName {
    const max_len: usize = sdl_io.max_display_name_bytes;
    var length: usize = 0;
    while (length <= max_len) : (length += 1) {
        if (name_ptr[length] == 0) return sdl_io.DisplayName.init(name_ptr[0..length]);
    }
    return error.InvalidMonitorName;
}

fn queryBounds(id: sdl_io.DisplayId) sdl_io.DisplayError!sdl_io.DisplayBounds {
    var rect: c.SDL_Rect = undefined;
    if (!c.SDL_GetDisplayBounds(@intCast(id), &rect)) return error.SdlMonitorSizeMissing;
    return sdl_io.DisplayBounds.init(rect.w, rect.h);
}

fn queryScale(id: sdl_io.DisplayId) sdl_io.DisplayError!f64 {
    return sdl_io.mapDisplayScale(c.SDL_GetDisplayContentScale(@intCast(id)));
}

/// SdlWindowPropertyIo owns one native SDL property set until deinit.
pub const SdlWindowPropertyIo = struct {
    /// properties is the owned native SDL property set.
    properties: @TypeOf(c.SDL_CreateProperties()),
    /// id is the plain local property token paired with this native object.
    id: sdl_io.SdlPropertyId,
    /// live gates SDL setters and prevents duplicate native destruction.
    live: bool = true,

    /// create allocates one native property set and publishes local id one.
    pub fn create() sdl_io.WindowError!SdlWindowPropertyIo {
        const properties = c.SDL_CreateProperties();
        if (properties == 0) return error.SdlWindowFailed;
        return .{ .properties = properties, .id = 1 };
    }

    /// setTitle copies a bounded title into a temporary native sentinel.
    pub fn setTitle(self: *SdlWindowPropertyIo, title: sdl_io.WindowTitle) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        var title_buf: [sdl_io.max_window_title_bytes:0]u8 = undefined;
        const title_z = std.fmt.bufPrintZ(&title_buf, "{s}", .{title.slice()}) catch
            return error.SdlWindowFailed;
        if (!c.SDL_SetStringProperty(self.properties, c.SDL_PROP_WINDOW_CREATE_TITLE_STRING, title_z.ptr)) {
            return error.SdlWindowFailed;
        }
    }

    /// setWidth writes one positive window width property.
    pub fn setWidth(self: *SdlWindowPropertyIo, value: i32) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        if (value <= 0) return error.InvalidWindowSize;
        if (!c.SDL_SetNumberProperty(self.properties, c.SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, @intCast(value))) {
            return error.SdlWindowFailed;
        }
    }

    /// setHeight writes one positive window height property.
    pub fn setHeight(self: *SdlWindowPropertyIo, value: i32) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        if (value <= 0) return error.InvalidWindowSize;
        if (!c.SDL_SetNumberProperty(self.properties, c.SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, @intCast(value))) {
            return error.SdlWindowFailed;
        }
    }

    /// setHidden writes the SDL hidden property.
    pub fn setHidden(self: *SdlWindowPropertyIo, value: bool) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        if (!c.SDL_SetBooleanProperty(self.properties, c.SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, value)) {
            return error.SdlWindowFailed;
        }
    }

    /// setCustomSurfaceRole requests the custom Wayland surface role.
    pub fn setCustomSurfaceRole(self: *SdlWindowPropertyIo, value: bool) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        if (!c.SDL_SetBooleanProperty(
            self.properties,
            c.SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN,
            value,
        )) {
            return error.SdlWindowFailed;
        }
    }

    /// setCreateEglWindow requests SDL's Wayland EGL window creation.
    pub fn setCreateEglWindow(self: *SdlWindowPropertyIo, value: bool) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidPropertyId;
        if (!c.SDL_SetBooleanProperty(
            self.properties,
            c.SDL_PROP_WINDOW_CREATE_WAYLAND_CREATE_EGL_WINDOW_BOOLEAN,
            value,
        )) {
            return error.SdlWindowFailed;
        }
    }

    /// deinit destroys the property set exactly once.
    pub fn deinit(self: *SdlWindowPropertyIo) void {
        if (!self.live) return;
        c.SDL_DestroyProperties(self.properties);
        self.live = false;
    }
};

/// SdlWindowIo owns one SDL window and exposes only plain ids to WaylandIo.
pub const SdlWindowIo = struct {
    /// window is the owned native SDL window.
    window: *c.SDL_Window,
    /// id is the plain local window token paired with this native object.
    id: sdl_io.SdlWindowId,
    /// live gates SDL calls and prevents duplicate native destruction.
    live: bool = true,

    /// create consumes configured properties and publishes local id one.
    pub fn create(properties: *const SdlWindowPropertyIo) sdl_io.WindowError!SdlWindowIo {
        if (!properties.live) return error.InvalidPropertyId;
        const window = c.SDL_CreateWindowWithProperties(properties.properties) orelse return error.SdlWindowFailed;
        return .{ .window = window, .id = 1 };
    }

    /// nativeWaylandHandles returns borrowed handles only to WaylandIo.
    pub fn nativeWaylandHandles(self: *const SdlWindowIo) sdl_io.WindowError!NativeWaylandHandles {
        if (!self.live) return error.InvalidWindowId;
        const properties = c.SDL_GetWindowProperties(self.window);
        if (properties == 0) return error.SdlWindowPropertyMissing;
        const raw_display = c.SDL_GetPointerProperty(
            properties,
            c.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER,
            null,
        ) orelse return error.WaylandSurfaceUnavailable;
        const raw_surface = c.SDL_GetPointerProperty(
            properties,
            c.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER,
            null,
        ) orelse return error.WaylandSurfaceUnavailable;
        return .{
            .display = @ptrCast(@alignCast(raw_display)),
            .surface = @ptrCast(@alignCast(raw_surface)),
        };
    }

    /// resize changes one native window size while retaining window ownership.
    pub fn resize(self: *SdlWindowIo, size: sdl_io.WindowSize) sdl_io.WindowError!void {
        if (!self.live) return error.InvalidWindowId;
        if (size.width <= 0 or size.height <= 0) return error.InvalidWindowSize;
        if (!c.SDL_SetWindowSize(self.window, size.width, size.height)) return error.SdlWindowSizeFailed;
    }

    /// deinit destroys the native window exactly once.
    pub fn deinit(self: *SdlWindowIo) void {
        if (!self.live) return;
        c.SDL_DestroyWindow(self.window);
        self.live = false;
    }
};

test "native SDL display names use a bounded sentinel scan" {
    const max_len: usize = sdl_io.max_display_name_bytes;
    var exact: [max_len + 1]u8 = undefined;
    @memset(exact[0..max_len], 'x');
    exact[max_len] = 0;
    const name = try displayNameFromSentinel(exact[0..].ptr);
    try std.testing.expectEqual(max_len, name.slice().len);

    var missing: [max_len + 1]u8 = undefined;
    @memset(&missing, 'x');
    try std.testing.expectError(error.InvalidMonitorName, displayNameFromSentinel(missing[0..].ptr));
}

test "native SDL owners reject every operation after deinit" {
    var properties = SdlWindowPropertyIo{
        .properties = undefined,
        .id = 1,
        .live = false,
    };
    const title = try sdl_io.WindowTitle.init("title");
    try std.testing.expectError(error.InvalidPropertyId, properties.setTitle(title));
    try std.testing.expectError(error.InvalidPropertyId, properties.setWidth(1));
    try std.testing.expectError(error.InvalidPropertyId, properties.setHeight(1));
    try std.testing.expectError(error.InvalidPropertyId, properties.setHidden(true));
    try std.testing.expectError(error.InvalidPropertyId, properties.setCustomSurfaceRole(true));
    try std.testing.expectError(error.InvalidPropertyId, properties.setCreateEglWindow(true));
    try std.testing.expectError(error.InvalidPropertyId, SdlWindowIo.create(&properties));

    var window = SdlWindowIo{
        .window = undefined,
        .id = 1,
        .live = false,
    };
    try std.testing.expectError(error.InvalidWindowId, window.nativeWaylandHandles());
    try std.testing.expectError(
        error.InvalidWindowId,
        window.resize(try sdl_io.WindowSize.init(1, 1)),
    );
}

test "native SDL resize rejects non-positive size before C" {
    var window = SdlWindowIo{
        .window = undefined,
        .id = 1,
    };
    try std.testing.expectError(
        error.InvalidWindowSize,
        window.resize(.{ .width = 0, .height = 1 }),
    );
    try std.testing.expectError(
        error.InvalidWindowSize,
        window.resize(.{ .width = 1, .height = -1 }),
    );
}
