//! Explicit source-only Wayland output observation probe. Never binds a host
//! compositor implicitly; caller must provide WAYLAND_DISPLAY and XDG_RUNTIME_DIR.
const std = @import("std");
const outputs = @import("wayspot_wallpaper_outputs");

pub fn main(init: std.process.Init) !void {
    const env = init.environ_map;
    if (env.get("XDG_RUNTIME_DIR") == null or env.get("WAYLAND_DISPLAY") == null)
        return error.ExplicitWaylandSessionRequired;
    var watcher: outputs.Observer = .{};
    try watcher.connect();
    defer watcher.disconnect();
    const snapshot = try watcher.snapshot();
    const items = try init.gpa.alloc(struct {
        name: []const u8,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        scale: f64,
        transform: []const u8,
    }, snapshot.count);
    defer init.gpa.free(items);
    for (snapshot.monitors[0..snapshot.count], 0..) |*monitor, i| {
        items[i] = .{ .name = monitor.name(), .x = monitor.x, .y = monitor.y, .width = monitor.width, .height = monitor.height, .scale = monitor.scale, .transform = @tagName(monitor.transform) };
    }
    const encoded = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "wayspot-wallpaper-outputs/v1",
        .outputs = items,
    }, .{});
    defer init.gpa.free(encoded);
    try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
