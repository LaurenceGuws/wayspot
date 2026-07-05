//! vendor surface zoom state owns one bounded session scale for picker and banner.
//!
//! The state file is tiny, session-local, and rewritten only by the active
//! surface that accepted a zoom key.

const std = @import("std");
const c = @import("sdl_c");

pub const min_zoom_step: i32 = -2;
pub const max_zoom_step: i32 = 5;
pub const default_zoom_step: i32 = 0;
pub const max_file_bytes: u32 = 64;

const state_relative_path = ".local/state/wayspot/surface.conf";
const zoom_step_percent: i32 = 15;

pub const ZoomAction = enum {
    zoom_in,
    zoom_out,
    reset,
};

pub const Dimensions = struct {
    width: i32,
    height: i32,
};

pub const SurfaceConfig = struct {
    zoom_step: i32 = default_zoom_step,

    pub fn load(allocator: std.mem.Allocator) !SurfaceConfig {
        const path = try statePath(allocator);
        defer allocator.free(path);
        return loadAtPath(allocator, path);
    }

    pub fn save(self: SurfaceConfig, allocator: std.mem.Allocator) !void {
        const path = try statePath(allocator);
        defer allocator.free(path);
        try saveAtPath(self, path);
    }

    pub fn scale(self: SurfaceConfig) f32 {
        return scaleFromStep(self.zoom_step);
    }

    pub fn applyZoomAction(self: *SurfaceConfig, action: ZoomAction) void {
        switch (action) {
            .zoom_in => self.zoom_step = clampZoomStep(self.zoom_step + 1),
            .zoom_out => self.zoom_step = clampZoomStep(self.zoom_step - 1),
            .reset => self.zoom_step = default_zoom_step,
        }
    }

    pub fn scaledDimensions(self: SurfaceConfig, width: i32, height: i32) Dimensions {
        return .{
            .width = scaledLength(self, width),
            .height = scaledLength(self, height),
        };
    }
};

pub fn load(allocator: std.mem.Allocator) !SurfaceConfig {
    return SurfaceConfig.load(allocator);
}

pub fn save(self: SurfaceConfig, allocator: std.mem.Allocator) !void {
    try self.save(allocator);
}

pub fn zoomAction(key: c.SDL_Keycode, modifiers: c.SDL_Keymod) ?ZoomAction {
    if ((modifiers & c.SDL_KMOD_CTRL) == 0) return null;
    return switch (key) {
        c.SDLK_EQUALS, c.SDLK_PLUS, c.SDLK_KP_PLUS => .zoom_in,
        c.SDLK_MINUS, c.SDLK_KP_MINUS => .zoom_out,
        c.SDLK_0, c.SDLK_KP_0 => .reset,
        else => null,
    };
}

pub fn clampZoomStep(step: i32) i32 {
    return @min(max_zoom_step, @max(min_zoom_step, step));
}

pub fn scaleFromStep(step: i32) f32 {
    const clamped_step = clampZoomStep(step);
    const percent = 100 + (clamped_step * zoom_step_percent);
    return @as(f32, @floatFromInt(percent)) / 100.0;
}

pub fn scaledLength(self: SurfaceConfig, value: i32) i32 {
    const scaled = @round(@as(f32, @floatFromInt(value)) * self.scale());
    return @intFromFloat(@max(scaled, 1.0));
}

pub fn loadAtPath(allocator: std.mem.Allocator, path: []const u8) !SurfaceConfig {
    const raw = readStateAnyPath(allocator, path) catch |err| switch (err) {
        error.FileNotFound => return .{},
        error.StreamTooLong => return .{},
        else => return err,
    };
    defer allocator.free(raw);

    return parseState(raw) catch .{};
}

pub fn saveAtPath(self: SurfaceConfig, path: []const u8) !void {
    var state_buf: [max_file_bytes]u8 = undefined;
    const state = try std.fmt.bufPrint(&state_buf, "zoom_step={d}\n", .{self.zoom_step});
    try writeStateAnyPath(path, state);
}

fn parseState(raw: []const u8) !SurfaceConfig {
    var lines = std.mem.splitScalar(u8, raw, '\n');
    const first = lines.next() orelse return error.MalformedState;
    const line = std.mem.trim(u8, first, " \t\r");
    if (line.len == 0) return error.MalformedState;

    if (!std.mem.startsWith(u8, line, "zoom_step=")) return error.MalformedState;
    const value_text = std.mem.trim(u8, line["zoom_step=".len..], " \t\r");
    if (value_text.len == 0) return error.MalformedState;
    if (lines.next()) |rest| {
        if (std.mem.trim(u8, rest, " \t\r").len != 0) return error.MalformedState;
    }

    return .{
        .zoom_step = clampZoomStep(try std.fmt.parseInt(i32, value_text, 10)),
    };
}

fn readStateAnyPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, path, allocator, .limited(max_file_bytes));
}

fn writeStateAnyPath(path: []const u8, data: []const u8) !void {
    try ensureParentDir(path);
    const io = std.Options.debug_io;

    if (std.fs.path.isAbsolute(path)) {
        var file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
        defer file.close(io);
        try file.writeStreamingAll(io, data);
        try file.sync(io);
        return;
    }

    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, data);
    try file.sync(io);
}

fn ensureParentDir(path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    if (std.fs.path.isAbsolute(parent)) {
        std.Io.Dir.createDirAbsolute(std.Options.debug_io, parent, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        return;
    }
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
}

fn statePath(allocator: std.mem.Allocator) ![]u8 {
    const home = if (std.c.getenv("HOME")) |home_z| std.mem.span(home_z) else ".";
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, state_relative_path });
}

test "default zoom state loads when file is missing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/surface.conf", .{base});
    defer std.testing.allocator.free(path);

    const config = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(default_zoom_step, config.zoom_step);
}

test "zoom step clamps to min and max bounds" {
    var config = SurfaceConfig{ .zoom_step = min_zoom_step };
    config.applyZoomAction(.zoom_out);
    try std.testing.expectEqual(min_zoom_step, config.zoom_step);

    config.zoom_step = max_zoom_step;
    config.applyZoomAction(.zoom_in);
    try std.testing.expectEqual(max_zoom_step, config.zoom_step);
}

test "valid persisted zoom loads" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "surface.conf",
        .data = "zoom_step=3\n",
    });
    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/surface.conf", .{base});
    defer std.testing.allocator.free(path);

    const config = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(@as(i32, 3), config.zoom_step);
}

test "oversized state file falls back to default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/surface.conf", .{base});
    defer std.testing.allocator.free(path);

    try tmp.dir.writeFile(.{
        .sub_path = "surface.conf",
        .data = "zoom_step=1234567890123456789012345678901234567890123456789012345678901234567890",
    });
    const config = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(default_zoom_step, config.zoom_step);
}

test "malformed state falls back to default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const base = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(base);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/surface.conf", .{base});
    defer std.testing.allocator.free(path);

    try tmp.dir.writeFile(.{
        .sub_path = "surface.conf",
        .data = "zoom=3\n",
    });
    const config = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(default_zoom_step, config.zoom_step);
}
