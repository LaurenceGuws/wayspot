//! Window owns bounded external window facts without layout rules.

const std = @import("std");

pub const max_windows: u32 = 256;
pub const max_window_class_bytes: u32 = 128;
pub const max_window_title_bytes: u32 = 512;

/// WindowId is the compositor-provided window address retained as identity.
pub const WindowId = struct {
    value: u64,
};

/// WorkspaceRef points at the workspace source fact for this window.
pub const WorkspaceRef = struct {
    id: i32,
};

/// WindowSize stores window dimensions as plain source facts.
pub const WindowSize = struct {
    width: i32,
    height: i32,

    /// init rejects negative dimensions while allowing zero for hidden source facts.
    pub fn init(width: i32, height: i32) !WindowSize {
        if (width < 0 or height < 0) return error.InvalidWindowSize;
        return .{ .width = width, .height = height };
    }
};

/// WindowClass owns one bounded class string.
pub const WindowClass = struct {
    bytes: [max_window_class_bytes]u8 = undefined,
    len: u32 = 0,

    /// init copies a source class into bounded owned storage.
    pub fn init(text: []const u8) !WindowClass {
        var class = WindowClass{};
        try class.set(text);
        return class;
    }

    /// set rejects empty and overlong source classes.
    pub fn set(self: *WindowClass, text: []const u8) !void {
        if (text.len == 0 or text.len > max_window_class_bytes) return error.InvalidWindowClass;
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
    }

    /// slice returns the retained class bytes.
    pub fn slice(self: *const WindowClass) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// WindowTitle owns one bounded title string. Empty titles are valid facts.
pub const WindowTitle = struct {
    bytes: [max_window_title_bytes]u8 = undefined,
    len: u32 = 0,

    /// init copies a source title into bounded owned storage.
    pub fn init(text: []const u8) !WindowTitle {
        var title = WindowTitle{};
        try title.set(text);
        return title;
    }

    /// set rejects overlong source titles.
    pub fn set(self: *WindowTitle, text: []const u8) !void {
        if (text.len > max_window_title_bytes) return error.InvalidWindowTitle;
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
    }

    /// slice returns the retained title bytes.
    pub fn slice(self: *const WindowTitle) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// Window owns one bounded external window fact row.
pub const Window = struct {
    id: WindowId,
    class: WindowClass,
    title: WindowTitle,
    size: WindowSize,
    visible: bool = false,
    focused: bool = false,
    workspace: ?WorkspaceRef = null,

    /// init retains required external window source facts.
    pub fn init(id: WindowId, class_text: []const u8, title_text: []const u8, size: WindowSize) !Window {
        return .{
            .id = id,
            .class = try WindowClass.init(class_text),
            .title = try WindowTitle.init(title_text),
            .size = size,
        };
    }
};

/// WindowList owns the bounded window fact set for a snapshot.
pub const WindowList = struct {
    items: [max_windows]Window = undefined,
    count: u32 = 0,

    /// append retains one window or rejects overflow.
    pub fn append(self: *WindowList, item: Window) !void {
        if (self.count >= max_windows) return error.TooManyWindows;
        self.items[self.count] = item;
        self.count += 1;
    }

    /// at returns a retained window when index is inside the bounded list.
    pub fn at(self: *const WindowList, index: u32) ?*const Window {
        if (index >= self.count) return null;
        return &self.items[index];
    }
};

test "window list is bounded and visibility facts stay plain" {
    var list = WindowList{};
    var index: u32 = 0;
    while (index < max_windows) : (index += 1) {
        var item = try Window.init(.{ .value = @intCast(index) }, "app", "", try WindowSize.init(800, 600));
        item.visible = index == 1;
        item.focused = index == 2;
        try list.append(item);
    }
    try std.testing.expectError(error.TooManyWindows, list.append(try Window.init(.{ .value = 999 }, "app", "", try WindowSize.init(1, 1))));
    try std.testing.expect(list.items[1].visible);
    try std.testing.expect(list.items[2].focused);
}

test "window strings and size reject invalid source facts" {
    try std.testing.expectError(error.InvalidWindowClass, WindowClass.init(""));
    const class_overlong = [_]u8{'c'} ** (max_window_class_bytes + 1);
    try std.testing.expectError(error.InvalidWindowClass, WindowClass.init(&class_overlong));
    const title_overlong = [_]u8{'t'} ** (max_window_title_bytes + 1);
    try std.testing.expectError(error.InvalidWindowTitle, WindowTitle.init(&title_overlong));
    try std.testing.expectError(error.InvalidWindowSize, WindowSize.init(-1, 1));
}
