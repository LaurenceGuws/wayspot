const std = @import("std");

pub const Family = struct {
    name: []const u8,
    aliases: []const []const u8,
    anchors: []const Rgb,
};

pub const Rgb = struct {
    r: f64,
    g: f64,
    b: f64,
};

const ayu_anchors = [_]Rgb{
    rgb(0x0f, 0x14, 0x19),
    rgb(0x1f, 0x24, 0x30),
    rgb(0x27, 0x30, 0x3b),
    rgb(0xff, 0xb4, 0x54),
    rgb(0xff, 0xd1, 0x73),
    rgb(0xaa, 0xd9, 0x4c),
    rgb(0x95, 0xe6, 0xcb),
    rgb(0x39, 0xba, 0xe6),
    rgb(0xbf, 0xbd, 0xb6),
};

const nordic_anchors = [_]Rgb{
    rgb(0x2e, 0x34, 0x40),
    rgb(0x3b, 0x42, 0x52),
    rgb(0x43, 0x4c, 0x5e),
    rgb(0xd0, 0x87, 0x70),
    rgb(0xeb, 0xcb, 0x8b),
    rgb(0xa3, 0xbe, 0x8c),
    rgb(0x8f, 0xbc, 0xbb),
    rgb(0x88, 0xc0, 0xd0),
    rgb(0x81, 0xa1, 0xc1),
    rgb(0xec, 0xef, 0xf4),
};

const catppuccin_anchors = [_]Rgb{
    rgb(0x1e, 0x1e, 0x2e),
    rgb(0x31, 0x32, 0x44),
    rgb(0x45, 0x47, 0x5a),
    rgb(0xf5, 0xc2, 0xe7),
    rgb(0xf3, 0x8b, 0xa8),
    rgb(0xfa, 0xe3, 0xb0),
    rgb(0xa6, 0xe3, 0xa1),
    rgb(0x89, 0xdc, 0xeb),
    rgb(0xb4, 0xbe, 0xfe),
};

const dracula_anchors = [_]Rgb{
    rgb(0x28, 0x2a, 0x36),
    rgb(0x44, 0x47, 0x5a),
    rgb(0x62, 0x72, 0xa4),
    rgb(0xff, 0x79, 0xc6),
    rgb(0xff, 0xb8, 0x6c),
    rgb(0xf1, 0xfa, 0x8c),
    rgb(0x50, 0xfa, 0x7b),
    rgb(0x8b, 0xe9, 0xfd),
    rgb(0xbd, 0x93, 0xf9),
};

const gruvbox_anchors = [_]Rgb{
    rgb(0x28, 0x28, 0x28),
    rgb(0x3c, 0x38, 0x36),
    rgb(0x50, 0x49, 0x45),
    rgb(0xfb, 0x49, 0x34),
    rgb(0xfe, 0x80, 0x19),
    rgb(0xfa, 0xbd, 0x2f),
    rgb(0xb8, 0xbb, 0x26),
    rgb(0x8e, 0xc0, 0x7c),
    rgb(0x83, 0xa5, 0x98),
};

const rose_pine_anchors = [_]Rgb{
    rgb(0x19, 0x18, 0x24),
    rgb(0x26, 0x24, 0x33),
    rgb(0x40, 0x3d, 0x52),
    rgb(0xeb, 0x6f, 0x92),
    rgb(0xf6, 0xc1, 0x77),
    rgb(0xeb, 0xbc, 0xba),
    rgb(0x31, 0xd0, 0xaa),
    rgb(0x9c, 0xcf, 0xd8),
    rgb(0xc4, 0xa7, 0xe7),
};

const kanagawa_anchors = [_]Rgb{
    rgb(0x1f, 0x1f, 0x28),
    rgb(0x2a, 0x2a, 0x37),
    rgb(0x36, 0x37, 0x46),
    rgb(0xc3, 0x40, 0x43),
    rgb(0xff, 0xa0, 0x66),
    rgb(0xdc, 0xc1, 0x8a),
    rgb(0x98, 0xbb, 0x6c),
    rgb(0x7f, 0xbb, 0xc1),
    rgb(0x95, 0x7f, 0xb8),
};

const tokyonight_anchors = [_]Rgb{
    rgb(0x1a, 0x1b, 0x26),
    rgb(0x24, 0x26, 0x3b),
    rgb(0x41, 0x4a, 0x6b),
    rgb(0xf7, 0x76, 0x8e),
    rgb(0xff, 0x9e, 0x64),
    rgb(0xe0, 0xaf, 0x68),
    rgb(0x9e, 0xce, 0x6a),
    rgb(0x7d, 0xcf, 0xff),
    rgb(0xbb, 0x9a, 0xf7),
};

const onedark_anchors = [_]Rgb{
    rgb(0x28, 0x2c, 0x34),
    rgb(0x35, 0x3b, 0x45),
    rgb(0x3e, 0x44, 0x51),
    rgb(0xe0, 0x6c, 0x75),
    rgb(0xd1, 0x9a, 0x66),
    rgb(0xe5, 0xc0, 0x7b),
    rgb(0x98, 0xc3, 0x79),
    rgb(0x56, 0xb6, 0xc2),
    rgb(0x61, 0xaf, 0xef),
};

const everforest_anchors = [_]Rgb{
    rgb(0x2d, 0x35, 0x39),
    rgb(0x37, 0x40, 0x47),
    rgb(0x49, 0x54, 0x56),
    rgb(0xe6, 0x7e, 0x80),
    rgb(0xe6, 0x98, 0x75),
    rgb(0xdb, 0xbc, 0x7f),
    rgb(0xa7, 0xc0, 0x80),
    rgb(0x83, 0xc0, 0x92),
    rgb(0x7f, 0xbb, 0xc1),
};

const material_anchors = [_]Rgb{
    rgb(0x26, 0x32, 0x38),
    rgb(0x2e, 0x3c, 0x43),
    rgb(0x31, 0x40, 0x49),
    rgb(0xf0, 0x71, 0x78),
    rgb(0xf7, 0x8c, 0x6c),
    rgb(0xff, 0xcb, 0x6b),
    rgb(0xc3, 0xe8, 0x8d),
    rgb(0x89, 0xdd, 0xff),
    rgb(0x82, 0xaa, 0xff),
};

const monokai_anchors = [_]Rgb{
    rgb(0x27, 0x28, 0x22),
    rgb(0x38, 0x3a, 0x3e),
    rgb(0x49, 0x48, 0x3e),
    rgb(0xf9, 0x26, 0x72),
    rgb(0xfd, 0x97, 0x1f),
    rgb(0xe6, 0xdb, 0x74),
    rgb(0xa6, 0xe2, 0x2e),
    rgb(0x66, 0xd9, 0xef),
    rgb(0xae, 0x81, 0xff),
};

const oxocarbon_anchors = [_]Rgb{
    rgb(0x16, 0x16, 0x16),
    rgb(0x26, 0x26, 0x26),
    rgb(0x39, 0x39, 0x39),
    rgb(0xee, 0x53, 0x90),
    rgb(0xff, 0x7e, 0x6b),
    rgb(0x42, 0xbe, 0x65),
    rgb(0x08, 0xbd, 0xba),
    rgb(0x33, 0xb1, 0xff),
    rgb(0xbe, 0x95, 0xff),
};

const poimandres_anchors = [_]Rgb{
    rgb(0x1b, 0x1e, 0x28),
    rgb(0x30, 0x35, 0x40),
    rgb(0x50, 0x60, 0x71),
    rgb(0xd0, 0x67, 0x9d),
    rgb(0xf0, 0x87, 0xbd),
    rgb(0xff, 0xe6, 0xb3),
    rgb(0x5d, 0xf2, 0xa7),
    rgb(0x89, 0xdd, 0xff),
    rgb(0x91, 0xb4, 0xd5),
};

pub const families = [_]Family{
    .{
        .name = "ayu",
        .aliases = &.{
            "ayu",
            "ayu-dark",
            "ayu-light",
            "ayu-mirage",
            "neovim-ayu",
        },
        .anchors = &ayu_anchors,
    },
    .{
        .name = "nordic",
        .aliases = &.{
            "nord",
            "nordic",
            "nordic.nvim",
            "nord.nvim",
            "snow",
            "iceberg",
            "oceanic-next",
            "oceanicnext",
            "oceanicnextlight",
            "base16-nord",
            "base16-oceanicnext",
        },
        .anchors = &nordic_anchors,
    },
    .{
        .name = "catppuccin",
        .aliases = &.{
            "catppuccin",
            "catppuccin-frappe",
            "catppuccin-latte",
            "catppuccin-macchiato",
            "catppuccin-mocha",
            "base16-catppuccin",
            "base16-catppuccin-frappe",
            "base16-catppuccin-latte",
            "base16-catppuccin-macchiato",
            "base16-catppuccin-mocha",
            "base16-mocha",
        },
        .anchors = &catppuccin_anchors,
    },
    .{
        .name = "dracula",
        .aliases = &.{ "dracula", "base16-dracula" },
        .anchors = &dracula_anchors,
    },
    .{
        .name = "gruvbox",
        .aliases = &.{
            "gruvbox",
            "base16-gruvbox-dark",
            "base16-gruvbox-dark-hard",
            "base16-gruvbox-dark-medium",
            "base16-gruvbox-dark-soft",
            "base16-gruvbox-light",
            "base16-gruvbox-material-dark-hard",
            "base16-gruvbox-material-dark-medium",
            "base16-gruvbox-material-dark-soft",
        },
        .anchors = &gruvbox_anchors,
    },
    .{
        .name = "rose-pine",
        .aliases = &.{ "rose-pine", "rose-pine-main", "rose-pine-moon", "rose-pine-dawn" },
        .anchors = &rose_pine_anchors,
    },
    .{
        .name = "kanagawa",
        .aliases = &.{ "kanagawa", "kanagawa-dragon", "base16-kanagawa", "base16-kanagawa-dragon" },
        .anchors = &kanagawa_anchors,
    },
    .{
        .name = "tokyonight",
        .aliases = &.{ "tokyonight", "tokyonight-night", "tokyonight-storm", "tokyonight-moon", "tokyonight-day" },
        .anchors = &tokyonight_anchors,
    },
    .{
        .name = "onedark",
        .aliases = &.{ "onedark", "onedark-dark", "onedarkpro", "one-dark", "base16-onedark", "base16-onedark-dark" },
        .anchors = &onedark_anchors,
    },
    .{
        .name = "everforest",
        .aliases = &.{ "everforest", "base16-everforest", "base16-everforest-dark-hard", "base16-everforest-dark-medium", "base16-everforest-dark-soft" },
        .anchors = &everforest_anchors,
    },
    .{
        .name = "material",
        .aliases = &.{ "material", "material-darker", "material-lighter", "material-palenight", "material-vivid", "base16-material", "base16-material-darker", "base16-material-palenight", "base16-material-vivid" },
        .anchors = &material_anchors,
    },
    .{
        .name = "monokai",
        .aliases = &.{ "monokai", "monokai-pro", "monokai-soda", "monokai-ristretto", "base16-monokai" },
        .anchors = &monokai_anchors,
    },
    .{
        .name = "oxocarbon",
        .aliases = &.{ "oxocarbon", "base16-oxocarbon-dark", "base16-oxocarbon-light" },
        .anchors = &oxocarbon_anchors,
    },
    .{
        .name = "poimandres",
        .aliases = &.{ "poimandres" },
        .anchors = &poimandres_anchors,
    },
};

pub fn familyForThemeName(theme_name: []const u8) ?[]const u8 {
    for (families) |family| {
        if (matchesFamily(family, theme_name)) return family.name;
    }
    return null;
}

pub fn familyForName(name: []const u8) ?Family {
    for (families) |family| {
        if (std.mem.eql(u8, family.name, name)) return family;
    }
    return null;
}

pub fn discoverNvimThemeNames(allocator: std.mem.Allocator, lazy_root: []const u8) ![][]u8 {
    var root = try std.fs.cwd().openDir(lazy_root, .{ .iterate = true });
    defer root.close();

    var walker = try root.walk(allocator);
    defer walker.deinit();

    var out = std.ArrayList([]u8).empty;
    errdefer {
        for (out.items) |item| allocator.free(item);
        out.deinit(allocator);
    }
    var seen = std.StringHashMapUnmanaged(void){};
    defer seen.deinit(allocator);

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!isColorsFile(entry.path)) continue;

        const stem = std.fs.path.stem(entry.basename);
        if (stem.len == 0) continue;
        const normalized = try normalizeThemeName(allocator, stem);
        errdefer allocator.free(normalized);
        const gop = try seen.getOrPut(allocator, normalized);
        if (gop.found_existing) {
            allocator.free(normalized);
            continue;
        }
        gop.key_ptr.* = normalized;
        try out.append(allocator, try allocator.dupe(u8, normalized));
    }

    std.mem.sort([]u8, out.items, {}, struct {
        fn lessThan(_: void, a: []u8, b: []u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);
    return out.toOwnedSlice(allocator);
}

pub fn printDiscoveredNvimThemes(allocator: std.mem.Allocator, lazy_root: []const u8) !void {
    const names = try discoverNvimThemeNames(allocator, lazy_root);
    defer {
        for (names) |item| allocator.free(item);
        allocator.free(names);
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    for (names) |name| {
        const family = familyForThemeName(name) orelse "";
        if (family.len > 0) {
            try stdout.print("{s}\t{s}\n", .{ name, family });
        } else {
            try stdout.print("{s}\n", .{name});
        }
    }
    try stdout.flush();
}

pub fn printFamilies() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    for (families) |family| {
        try stdout.print("{s}", .{family.name});
        for (family.aliases) |alias| {
            try stdout.print("\t{s}", .{alias});
        }
        try stdout.print("\n", .{});
    }
    try stdout.flush();
}

fn matchesFamily(family: Family, theme_name: []const u8) bool {
    const lowered = std.ascii.allocLowerString(std.heap.page_allocator, theme_name) catch return false;
    defer std.heap.page_allocator.free(lowered);

    for (family.aliases) |alias| {
        if (std.mem.eql(u8, lowered, alias)) return true;
    }

    if (std.mem.indexOf(u8, lowered, family.name) != null) return true;
    return false;
}

fn rgb(r: u8, g: u8, b: u8) Rgb {
    return .{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };
}

fn normalizeThemeName(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    const lowered = try std.ascii.allocLowerString(allocator, raw);
    defer allocator.free(lowered);

    var i: usize = 0;
    while (i < lowered.len) : (i += 1) {
        const ch = lowered[i];
        if (std.ascii.isAlphanumeric(ch)) {
            try out.append(allocator, ch);
            continue;
        }
        if (ch == '-' or ch == '_' or ch == '.') {
            if (out.items.len == 0 or out.items[out.items.len - 1] == '-') continue;
            try out.append(allocator, '-');
        }
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == '-') {
        _ = out.pop();
    }

    if (std.mem.endsWith(u8, out.items, "-nvim")) {
        out.items.len -= "-nvim".len;
    } else if (std.mem.endsWith(u8, out.items, "-vim")) {
        out.items.len -= "-vim".len;
    }

    if (std.mem.startsWith(u8, out.items, "vim-")) {
        return allocator.dupe(u8, out.items["vim-".len..]);
    }
    return out.toOwnedSlice(allocator);
}

fn isColorsFile(path: []const u8) bool {
    if (std.mem.indexOf(u8, path, "/colors/") == null) return false;
    const ext = std.fs.path.extension(path);
    return std.mem.eql(u8, ext, ".lua") or std.mem.eql(u8, ext, ".vim");
}

test "familyForThemeName resolves aliases" {
    try std.testing.expectEqualStrings("ayu", familyForThemeName("ayu-mirage").?);
    try std.testing.expectEqualStrings("nordic", familyForThemeName("nord").?);
    try std.testing.expectEqualStrings("nordic", familyForThemeName("OceanicNext").?);
    try std.testing.expectEqualStrings("catppuccin", familyForThemeName("base16-catppuccin-mocha").?);
    try std.testing.expectEqualStrings("rose-pine", familyForThemeName("rose-pine-moon").?);
    try std.testing.expectEqualStrings("kanagawa", familyForThemeName("kanagawa-dragon").?);
}

test "normalizeThemeName normalizes common names" {
    const ayu = try normalizeThemeName(std.testing.allocator, "neovim-ayu");
    defer std.testing.allocator.free(ayu);
    try std.testing.expectEqualStrings("neovim-ayu", ayu);

    const palenight = try normalizeThemeName(std.testing.allocator, "palenight.vim");
    defer std.testing.allocator.free(palenight);
    try std.testing.expectEqualStrings("palenight", palenight);

    const firewatch = try normalizeThemeName(std.testing.allocator, "vim-two-firewatch");
    defer std.testing.allocator.free(firewatch);
    try std.testing.expectEqualStrings("two-firewatch", firewatch);
}
