const std = @import("std");
const default_lua = @import("../config/default_lua.zig");
const theme_registry = @import("theme_registry.zig");

pub fn getCurrentTheme(allocator: std.mem.Allocator) !?[]u8 {
    const path = try default_lua.resolvePath(allocator);
    defer allocator.free(path);
    const contents = std.fs.cwd().readFileAlloc(allocator, path, 256 * 1024) catch return null;
    defer allocator.free(contents);

    const marker = "current";
    const marker_idx = std.mem.indexOf(u8, contents, marker) orelse return null;
    const eq_idx_rel = std.mem.indexOfScalar(u8, contents[marker_idx..], '=') orelse return null;
    const eq_idx = marker_idx + eq_idx_rel;
    const after_eq = std.mem.trimLeft(u8, contents[eq_idx + 1 ..], " \t\r\n");
    if (after_eq.len < 2) return null;
    const quote = after_eq[0];
    if (quote != '"' and quote != '\'') return null;
    const end_idx = std.mem.indexOfScalarPos(u8, after_eq, 1, quote) orelse return null;
    const value = try allocator.dupe(u8, after_eq[1..end_idx]);
    return value;
}

pub fn setCurrentTheme(allocator: std.mem.Allocator, theme: []const u8) !void {
    _ = theme_registry.familyForThemeName(theme) orelse return error.UnknownTheme;

    const path = try default_lua.resolvePath(allocator);
    defer allocator.free(path);
    _ = try default_lua.ensureDefaultConfigAtPath(path);

    const contents = try std.fs.cwd().readFileAlloc(allocator, path, 256 * 1024);
    defer allocator.free(contents);

    const rendered = try renderUpdatedConfig(allocator, contents, theme);
    defer allocator.free(rendered);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = rendered });
}

fn renderUpdatedConfig(allocator: std.mem.Allocator, contents: []const u8, theme: []const u8) ![]u8 {
    const theme_block = try std.fmt.allocPrint(allocator,
        \\  theme = {{
        \\    current = "{s}",
        \\  }},
        \\
    , .{theme});
    defer allocator.free(theme_block);

    if (std.mem.indexOf(u8, contents, "theme = {")) |theme_idx| {
        const block_end_rel = std.mem.indexOfPos(u8, contents, theme_idx, "\n  },") orelse return allocator.dupe(u8, contents);
        const block_end = block_end_rel + "\n  },".len;
        return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
            contents[0..theme_idx],
            theme_block,
            contents[block_end..],
        });
    }

    const return_idx = std.mem.indexOf(u8, contents, "return {") orelse return allocator.dupe(u8, contents);
    const insert_idx = return_idx + "return {\n".len;
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        contents[0..insert_idx],
        theme_block,
        contents[insert_idx..],
    });
}

test "renderUpdatedConfig inserts theme block" {
    const input =
        \\return {
        \\  ui = {
        \\    show_nerd_stats = true,
        \\  },
        \\}
    ;
    const out = try renderUpdatedConfig(std.testing.allocator, input, "ayu");
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "theme = {") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "current = \"ayu\"") != null);
}

test "renderUpdatedConfig replaces theme block" {
    const input =
        \\return {
        \\  theme = {
        \\    current = "nordic",
        \\  },
        \\  ui = {
        \\    show_nerd_stats = true,
        \\  },
        \\}
    ;
    const out = try renderUpdatedConfig(std.testing.allocator, input, "ayu");
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "current = \"ayu\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "current = \"nordic\"") == null);
}
