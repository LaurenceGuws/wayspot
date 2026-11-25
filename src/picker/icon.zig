//! Builds the small set of PNG paths used by the application picker.

const std = @import("std");

pub const path_capacity = 1024;

const locations = [_][]const u8{
    ".local/share/icons/hicolor/48x48/apps/",
    ".local/share/icons/hicolor/64x64/apps/",
    ".local/share/icons/hicolor/128x128/apps/",
    ".local/share/icons/hicolor/256x256/apps/",
    ".local/share/icons/hicolor/512x512/apps/",
    ".local/share/pixmaps/",
    "/usr/share/icons/hicolor/48x48/apps/",
    "/usr/share/icons/hicolor/64x64/apps/",
    "/usr/share/icons/hicolor/128x128/apps/",
    "/usr/share/icons/hicolor/256x256/apps/",
    "/usr/share/icons/hicolor/512x512/apps/",
    "/usr/share/pixmaps/",
};

pub const Paths = struct {
    home: []const u8,
    icon: []const u8,
    next_location: usize = 0,
    absolute_done: bool = false,
    bytes: [path_capacity:0]u8 = @splat(0),

    /// Returns each bounded PNG candidate once in preferred-size order.
    pub fn next(paths: *Paths) !?[:0]const u8 {
        if (std.fs.path.isAbsolute(paths.icon)) {
            if (paths.absolute_done) return null;
            paths.absolute_done = true;
            return try paths.write(&.{paths.icon});
        }
        if (!validName(paths.icon)) return error.InvalidIconName;
        if (paths.next_location == locations.len) return null;
        const location = locations[paths.next_location];
        paths.next_location += 1;
        return if (location[0] == '/')
            try paths.write(&.{ location, paths.icon, ".png" })
        else
            try paths.write(&.{ paths.home, "/", location, paths.icon, ".png" });
    }

    fn write(paths: *Paths, parts: []const []const u8) ![:0]const u8 {
        var len: usize = 0;
        for (parts) |part| {
            if (part.len > path_capacity - len) return error.IconPathTooLong;
            @memcpy(paths.bytes[len..][0..part.len], part);
            len += part.len;
        }
        paths.bytes[len] = 0;
        return paths.bytes[0..len :0];
    }
};

fn validName(name: []const u8) bool {
    if (name.len == 0 or name.len > 256) return false;
    for (name) |byte| {
        if (byte == '/' or byte == 0) return false;
    }
    return true;
}

test "absolute icon path is returned once" {
    var paths: Paths = .{ .home = "/home/me", .icon = "/opt/app/icon.png" };
    try std.testing.expectEqualStrings("/opt/app/icon.png", (try paths.next()).?);
    try std.testing.expectEqual(null, try paths.next());
}

test "named icons produce bounded local then system paths" {
    var paths: Paths = .{ .home = "/home/me", .icon = "app" };
    try std.testing.expectEqualStrings(
        "/home/me/.local/share/icons/hicolor/48x48/apps/app.png",
        (try paths.next()).?,
    );
    for (1..6) |_| _ = try paths.next();
    try std.testing.expectEqualStrings("/usr/share/icons/hicolor/48x48/apps/app.png", (try paths.next()).?);
}

test "invalid icon names are rejected" {
    var empty: Paths = .{ .home = "/home/me", .icon = "" };
    try std.testing.expectError(error.InvalidIconName, empty.next());
    var nested: Paths = .{ .home = "/home/me", .icon = "../app" };
    try std.testing.expectError(error.InvalidIconName, nested.next());
}
