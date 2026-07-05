//! Sunglasses state owns bounded per-monitor red/blue and dim filter values.

const std = @import("std");

pub const max_monitors: u32 = 8;
pub const max_monitor_name_bytes: u32 = 96;
pub const max_file_bytes: u32 = 16384;
pub const max_image_path_bytes: u32 = 1024;
pub const red_blue_min: i32 = -100;
pub const red_blue_zero: i32 = 0;
pub const red_blue_max: i32 = 100;
pub const dim_min: i32 = 0;
pub const dim_zero: i32 = 0;
pub const dim_max: i32 = 100;
pub const image_opacity_min: i32 = 0;
pub const image_opacity_zero: i32 = 0;
pub const image_opacity_max: i32 = 100;

const state_relative_path = ".local/state/wayspot/sunglasses.conf";

pub const MonitorState = struct {
    name_buf: [max_monitor_name_bytes]u8 = undefined,
    name_len: u32 = 0,
    red_blue_enabled: bool = false,
    red_blue_value: i32 = red_blue_zero,
    dim_enabled: bool = false,
    dim_value: i32 = dim_zero,
    image_enabled: bool = false,
    image_opacity: i32 = image_opacity_zero,
    image_path_buf: [max_image_path_bytes]u8 = undefined,
    image_path_len: u32 = 0,

    pub fn init(name_text: []const u8) !MonitorState {
        var monitor = MonitorState{};
        try monitor.setName(name_text);
        return monitor;
    }

    pub fn name(self: *const MonitorState) []const u8 {
        return self.name_buf[0..self.name_len];
    }

    pub fn setName(self: *MonitorState, name_text: []const u8) !void {
        if (name_text.len == 0 or name_text.len > max_monitor_name_bytes) return error.InvalidMonitorName;
        @memcpy(self.name_buf[0..name_text.len], name_text);
        self.name_len = @intCast(name_text.len);
    }

    pub fn setRedBlueValue(self: *MonitorState, value: i32) void {
        self.red_blue_value = clampRedBlue(value);
    }

    pub fn setDimValue(self: *MonitorState, value: i32) void {
        self.dim_value = clampDim(value);
    }

    pub fn imagePath(self: *const MonitorState) []const u8 {
        return self.image_path_buf[0..self.image_path_len];
    }

    pub fn setImageOpacity(self: *MonitorState, value: i32) void {
        self.image_opacity = clampImageOpacity(value);
    }

    pub fn setImagePath(self: *MonitorState, path_text: []const u8) !void {
        if (path_text.len == 0 or path_text.len > max_image_path_bytes) return error.InvalidImagePath;
        if (!std.fs.path.isAbsolute(path_text)) return error.InvalidImagePath;
        if (hasInvalidPathByte(path_text)) return error.InvalidImagePath;
        @memcpy(self.image_path_buf[0..path_text.len], path_text);
        self.image_path_len = @intCast(path_text.len);
    }

    pub fn clearImagePath(self: *MonitorState) void {
        self.image_path_len = 0;
    }

    pub fn hasEffectiveFilter(self: *const MonitorState) bool {
        return (self.red_blue_enabled and self.red_blue_value != red_blue_zero) or
            (self.dim_enabled and self.dim_value != dim_zero);
    }

    pub fn hasEffectiveImageOverlay(self: *const MonitorState) bool {
        return self.image_enabled and
            self.image_opacity > image_opacity_zero and
            self.image_path_len > 0 and
            std.fs.path.isAbsolute(self.imagePath()) and
            !hasInvalidPathByte(self.imagePath());
    }
};

pub const State = struct {
    monitors: [max_monitors]MonitorState = undefined,
    count: u32 = 0,

    pub fn load(allocator: std.mem.Allocator) !State {
        const path = try statePath(allocator);
        defer allocator.free(path);
        return loadAtPath(allocator, path);
    }

    pub fn save(self: State, allocator: std.mem.Allocator) !void {
        const path = try statePath(allocator);
        defer allocator.free(path);
        try saveAtPath(self, path);
    }

    pub fn append(self: *State, monitor: MonitorState) !void {
        if (self.count >= max_monitors) return error.TooManyMonitors;
        self.monitors[self.count] = normalizedMonitor(monitor);
        self.count += 1;
    }

    pub fn get(self: *const State, name_text: []const u8) ?*const MonitorState {
        var index: u32 = 0;
        while (index < self.count) : (index += 1) {
            if (std.mem.eql(u8, self.monitors[index].name(), name_text)) return &self.monitors[index];
        }
        return null;
    }

    pub fn monitorAt(self: *const State, index: u32) ?*const MonitorState {
        if (index >= self.count) return null;
        return &self.monitors[index];
    }

    pub fn monitorAtMutable(self: *State, index: u32) ?*MonitorState {
        if (index >= self.count) return null;
        return &self.monitors[index];
    }

    pub fn getMutable(self: *State, name_text: []const u8) ?*MonitorState {
        var index: u32 = 0;
        while (index < self.count) : (index += 1) {
            if (std.mem.eql(u8, self.monitors[index].name(), name_text)) return &self.monitors[index];
        }
        return null;
    }

    /// Forms and daemons mutate retained monitor slots through this owner.
    pub fn ensureMonitor(self: *State, name_text: []const u8) !*MonitorState {
        if (self.getMutable(name_text)) |monitor| return monitor;
        if (self.count >= max_monitors) return error.TooManyMonitors;

        const index = self.count;
        self.monitors[index] = try MonitorState.init(name_text);
        self.count += 1;
        return &self.monitors[index];
    }

    pub fn serialize(self: State, out: *[max_file_bytes]u8) ![]const u8 {
        var offset: u32 = 0;
        var index: u32 = 0;
        while (index < self.count) : (index += 1) {
            const monitor = normalizedMonitor(self.monitors[index]);
            const segment = try std.fmt.bufPrint(out[offset..], "monitor={s}\nred_blue_enabled={d}\nred_blue_value={d}\ndim_enabled={d}\ndim_value={d}\nimage_enabled={d}\nimage_opacity={d}\nimage_path={s}\n", .{
                monitor.name(),
                boolInt(monitor.red_blue_enabled),
                monitor.red_blue_value,
                boolInt(monitor.dim_enabled),
                monitor.dim_value,
                boolInt(monitor.image_enabled),
                monitor.image_opacity,
                monitor.imagePath(),
            });
            offset += @intCast(segment.len);
        }
        return out[0..offset];
    }

    pub fn needsDaemon(self: *const State) bool {
        var index: u32 = 0;
        while (index < self.count) : (index += 1) {
            if (self.monitors[index].hasEffectiveFilter() or self.monitors[index].hasEffectiveImageOverlay()) return true;
        }
        return false;
    }
};

pub fn defaultState() State {
    return .{};
}

pub fn load(allocator: std.mem.Allocator) !State {
    return State.load(allocator);
}

pub fn save(state: State, allocator: std.mem.Allocator) !void {
    try state.save(allocator);
}

pub fn loadAtPath(allocator: std.mem.Allocator, path: []const u8) !State {
    const raw = readStateAnyPath(allocator, path) catch |err| switch (err) {
        error.FileNotFound => return defaultState(),
        error.StreamTooLong => return defaultState(),
        else => return err,
    };
    defer allocator.free(raw);

    return parse(raw) catch defaultState();
}

pub fn saveAtPath(state: State, path: []const u8) !void {
    var state_buf: [max_file_bytes]u8 = undefined;
    const serialized = try state.serialize(&state_buf);
    try writeStateAnyPath(path, serialized);
}

pub fn clampRedBlue(value: i32) i32 {
    return @min(red_blue_max, @max(red_blue_min, value));
}

pub fn clampDim(value: i32) i32 {
    return @min(dim_max, @max(dim_min, value));
}

pub fn clampImageOpacity(value: i32) i32 {
    return @min(image_opacity_max, @max(image_opacity_min, value));
}

fn parse(raw: []const u8) !State {
    if (raw.len > max_file_bytes) return error.StateTooLarge;

    var state = State{};
    var lines = std.mem.splitScalar(u8, raw, '\n');
    var pending_line: ?[]const u8 = null;
    while (true) {
        const monitor_line_raw = if (pending_line) |line| line else lines.next() orelse break;
        pending_line = null;
        const monitor_line = trimmed(monitor_line_raw);
        if (monitor_line.len == 0) {
            if (onlyBlankLinesRemain(&lines)) break;
            return error.MalformedState;
        }

        var monitor = MonitorState{};
        try monitor.setName(try valueAfter(monitor_line, "monitor="));
        monitor.red_blue_enabled = try parseBool(try nextValue(&lines, "red_blue_enabled="));
        monitor.red_blue_value = clampRedBlue(try parseSigned(try nextValue(&lines, "red_blue_value=")));
        monitor.dim_enabled = try parseBool(try nextValue(&lines, "dim_enabled="));
        monitor.dim_value = clampDim(try parseUnsignedDim(try nextValue(&lines, "dim_value=")));
        if (lines.next()) |next_line_raw| {
            const next_line = trimmed(next_line_raw);
            if (std.mem.startsWith(u8, next_line, "image_enabled=")) {
                monitor.image_enabled = try parseBool(try valueAfter(next_line, "image_enabled="));
                monitor.image_opacity = clampImageOpacity(try parseUnsignedImageOpacity(try nextValue(&lines, "image_opacity=")));
                const image_path = try nextValueAllowEmpty(&lines, "image_path=");
                if (image_path.len > 0) try monitor.setImagePath(image_path);
            } else {
                pending_line = next_line_raw;
            }
        }
        try state.append(monitor);
    }
    return state;
}

fn nextValue(lines: *std.mem.SplitIterator(u8, .scalar), prefix: []const u8) ![]const u8 {
    const raw = lines.next() orelse return error.MalformedState;
    return valueAfter(trimmed(raw), prefix);
}

fn nextValueAllowEmpty(lines: *std.mem.SplitIterator(u8, .scalar), prefix: []const u8) ![]const u8 {
    const raw = lines.next() orelse return error.MalformedState;
    return valueAfterAllowEmpty(trimmed(raw), prefix);
}

fn valueAfter(line: []const u8, prefix: []const u8) ![]const u8 {
    if (!std.mem.startsWith(u8, line, prefix)) return error.MalformedState;
    const value = trimmed(line[prefix.len..]);
    if (value.len == 0) return error.MalformedState;
    return value;
}

fn valueAfterAllowEmpty(line: []const u8, prefix: []const u8) ![]const u8 {
    if (!std.mem.startsWith(u8, line, prefix)) return error.MalformedState;
    return trimmed(line[prefix.len..]);
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "0")) return false;
    if (std.mem.eql(u8, value, "1")) return true;
    return error.MalformedState;
}

fn parseSigned(value: []const u8) !i32 {
    return std.fmt.parseInt(i32, value, 10) catch error.MalformedState;
}

fn parseUnsignedDim(value: []const u8) !i32 {
    const parsed = try parseSigned(value);
    if (parsed < 0) return error.MalformedState;
    return parsed;
}

fn parseUnsignedImageOpacity(value: []const u8) !i32 {
    const parsed = try parseSigned(value);
    if (parsed < 0) return error.MalformedState;
    return parsed;
}

fn onlyBlankLinesRemain(lines: *std.mem.SplitIterator(u8, .scalar)) bool {
    while (lines.next()) |line| {
        if (trimmed(line).len != 0) return false;
    }
    return true;
}

fn normalizedMonitor(monitor: MonitorState) MonitorState {
    var normalized = monitor;
    normalized.red_blue_value = clampRedBlue(normalized.red_blue_value);
    normalized.dim_value = clampDim(normalized.dim_value);
    normalized.image_opacity = clampImageOpacity(normalized.image_opacity);
    if (normalized.image_path_len > max_image_path_bytes or !std.fs.path.isAbsolute(normalized.imagePath()) or hasInvalidPathByte(normalized.imagePath())) normalized.clearImagePath();
    return normalized;
}

fn hasInvalidPathByte(value: []const u8) bool {
    for (value) |byte| {
        if (byte < ' ' or byte == 0x7f) return true;
    }
    return false;
}

fn boolInt(value: bool) u8 {
    return if (value) 1 else 0;
}

fn trimmed(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t\r");
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

test "defaults contain no retained monitors" {
    const state = defaultState();
    try std.testing.expectEqual(@as(u32, 0), state.count);

    const monitor = try MonitorState.init("DP-1");
    try std.testing.expectEqualStrings("DP-1", monitor.name());
    try std.testing.expect(!monitor.red_blue_enabled);
    try std.testing.expectEqual(red_blue_zero, monitor.red_blue_value);
    try std.testing.expect(!monitor.dim_enabled);
    try std.testing.expectEqual(dim_zero, monitor.dim_value);
    try std.testing.expect(!monitor.image_enabled);
    try std.testing.expectEqual(image_opacity_zero, monitor.image_opacity);
    try std.testing.expectEqualStrings("", monitor.imagePath());
}

test "clamp min max and zero semantics" {
    try std.testing.expectEqual(red_blue_min, clampRedBlue(-101));
    try std.testing.expectEqual(red_blue_zero, clampRedBlue(0));
    try std.testing.expectEqual(red_blue_max, clampRedBlue(101));
    try std.testing.expectEqual(dim_min, clampDim(-1));
    try std.testing.expectEqual(dim_zero, clampDim(0));
    try std.testing.expectEqual(dim_max, clampDim(101));
    try std.testing.expectEqual(image_opacity_min, clampImageOpacity(-1));
    try std.testing.expectEqual(image_opacity_zero, clampImageOpacity(0));
    try std.testing.expectEqual(image_opacity_max, clampImageOpacity(101));

    var monitor = try MonitorState.init("DP-1");
    monitor.setRedBlueValue(-250);
    monitor.setDimValue(250);
    monitor.setImageOpacity(250);
    try std.testing.expectEqual(red_blue_min, monitor.red_blue_value);
    try std.testing.expectEqual(dim_max, monitor.dim_value);
    try std.testing.expectEqual(image_opacity_max, monitor.image_opacity);
}

test "effective filter predicate ignores disabled and zero-value FormFields" {
    var state = defaultState();
    try std.testing.expect(!state.needsDaemon());

    var monitor = try MonitorState.init("DP-1");
    monitor.red_blue_enabled = true;
    monitor.red_blue_value = red_blue_zero;
    monitor.dim_enabled = true;
    monitor.dim_value = dim_zero;
    try state.append(monitor);
    try std.testing.expect(!state.monitors[0].hasEffectiveFilter());
    try std.testing.expect(!state.needsDaemon());

    state.monitors[0].red_blue_value = 20;
    try std.testing.expect(state.monitors[0].hasEffectiveFilter());
    try std.testing.expect(state.needsDaemon());

    state.monitors[0].red_blue_enabled = false;
    state.monitors[0].dim_enabled = false;
    state.monitors[0].dim_value = 50;
    try std.testing.expect(!state.monitors[0].hasEffectiveFilter());
    try std.testing.expect(!state.needsDaemon());
}

test "effective image overlay requires enabled opacity and absolute path" {
    var state = defaultState();
    var monitor = try MonitorState.init("DP-1");
    monitor.image_enabled = true;
    monitor.setImageOpacity(35);
    try state.append(monitor);
    try std.testing.expect(!state.monitors[0].hasEffectiveImageOverlay());
    try std.testing.expect(!state.needsDaemon());

    try state.monitors[0].setImagePath("/home/home/Pictures/overlay.png");
    try std.testing.expect(state.monitors[0].hasEffectiveImageOverlay());
    try std.testing.expect(state.needsDaemon());

    state.monitors[0].image_opacity = image_opacity_zero;
    try std.testing.expect(!state.monitors[0].hasEffectiveImageOverlay());
    try std.testing.expect(!state.needsDaemon());

    const invalid_path = "/home/home/Pictures/over\nlay.png";
    @memcpy(state.monitors[0].image_path_buf[0..invalid_path.len], invalid_path);
    state.monitors[0].image_path_len = @intCast(invalid_path.len);
    state.monitors[0].image_opacity = 35;
    try std.testing.expect(!state.monitors[0].hasEffectiveImageOverlay());
    try std.testing.expect(!state.needsDaemon());
}

test "image path setter accepts bounded absolute paths only" {
    var monitor = try MonitorState.init("DP-1");
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath(""));
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath("relative/image.png"));
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath("/tmp/a\nmonitor=DP-2"));
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath("/tmp/a\rbad"));
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath("/tmp/a\tbad"));

    var path_buf: [max_image_path_bytes + 1]u8 = undefined;
    @memset(&path_buf, 'a');
    path_buf[0] = '/';
    try std.testing.expectError(error.InvalidImagePath, monitor.setImagePath(&path_buf));

    try monitor.setImagePath("/tmp/wayspot-overlay.bmp");
    try std.testing.expectEqualStrings("/tmp/wayspot-overlay.bmp", monitor.imagePath());
    monitor.clearImagePath();
    try std.testing.expectEqualStrings("", monitor.imagePath());
}

test "parse old multi-monitor state defaults image overlay fields" {
    const raw =
        \\monitor=DP-1
        \\red_blue_enabled=1
        \\red_blue_value=-25
        \\dim_enabled=1
        \\dim_value=40
        \\monitor=HDMI-A-1
        \\red_blue_enabled=0
        \\red_blue_value=75
        \\dim_enabled=0
        \\dim_value=0
        \\
    ;
    const state = try parse(raw);
    try std.testing.expectEqual(@as(u32, 2), state.count);
    try std.testing.expectEqualStrings("DP-1", state.monitors[0].name());
    try std.testing.expect(state.monitors[0].red_blue_enabled);
    try std.testing.expectEqual(@as(i32, -25), state.monitors[0].red_blue_value);
    try std.testing.expect(state.monitors[0].dim_enabled);
    try std.testing.expectEqual(@as(i32, 40), state.monitors[0].dim_value);
    try std.testing.expect(!state.monitors[0].image_enabled);
    try std.testing.expectEqual(image_opacity_zero, state.monitors[0].image_opacity);
    try std.testing.expectEqualStrings("", state.monitors[0].imagePath());
    try std.testing.expectEqualStrings("HDMI-A-1", state.monitors[1].name());
    try std.testing.expect(!state.monitors[1].red_blue_enabled);
    try std.testing.expectEqual(@as(i32, 75), state.monitors[1].red_blue_value);
    try std.testing.expect(!state.monitors[1].dim_enabled);
    try std.testing.expectEqual(dim_zero, state.monitors[1].dim_value);
    try std.testing.expect(!state.monitors[1].image_enabled);
    try std.testing.expectEqual(image_opacity_zero, state.monitors[1].image_opacity);
    try std.testing.expectEqualStrings("", state.monitors[1].imagePath());
}

test "parse valid state with image fields" {
    const raw =
        \\monitor=DP-1
        \\red_blue_enabled=1
        \\red_blue_value=-25
        \\dim_enabled=1
        \\dim_value=40
        \\image_enabled=1
        \\image_opacity=65
        \\image_path=/home/home/Pictures/overlay.png
        \\
    ;
    const state = try parse(raw);
    try std.testing.expectEqual(@as(u32, 1), state.count);
    try std.testing.expect(state.monitors[0].image_enabled);
    try std.testing.expectEqual(@as(i32, 65), state.monitors[0].image_opacity);
    try std.testing.expectEqualStrings("/home/home/Pictures/overlay.png", state.monitors[0].imagePath());
    try std.testing.expect(state.needsDaemon());
}

test "malformed state load falls back to default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "sunglasses.conf",
        .data = "monitor=DP-1\nred_blue_enabled=yes\n",
    });
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/sunglasses.conf", .{&tmp.sub_path});
    defer std.testing.allocator.free(path);

    const state = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(@as(u32, 0), state.count);
}

test "missing state load falls back to default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/missing-sunglasses.conf", .{&tmp.sub_path});
    defer std.testing.allocator.free(path);

    const state = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(@as(u32, 0), state.count);
}

test "oversized state load falls back to default" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const oversized = try std.testing.allocator.alloc(u8, max_file_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');

    try tmp.dir.writeFile(std.Options.debug_io, .{
        .sub_path = "sunglasses.conf",
        .data = oversized,
    });
    const path = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/sunglasses.conf", .{&tmp.sub_path});
    defer std.testing.allocator.free(path);

    const state = try loadAtPath(std.testing.allocator, path);
    try std.testing.expectEqual(@as(u32, 0), state.count);
}

test "serialize roundtrip preserves bounded monitor values" {
    var state = State{};
    var first = try MonitorState.init("DP-1");
    first.red_blue_enabled = true;
    first.red_blue_value = 125;
    first.dim_enabled = true;
    first.dim_value = -10;
    first.image_enabled = true;
    first.image_opacity = 150;
    try first.setImagePath("/tmp/first.png");
    try state.append(first);

    var second = try MonitorState.init("HDMI-A-1");
    second.red_blue_enabled = false;
    second.red_blue_value = -75;
    second.dim_enabled = true;
    second.dim_value = 60;
    try state.append(second);

    var buf: [max_file_bytes]u8 = undefined;
    const serialized = try state.serialize(&buf);
    const parsed = try parse(serialized);
    try std.testing.expectEqual(@as(u32, 2), parsed.count);
    try std.testing.expectEqualStrings("DP-1", parsed.monitors[0].name());
    try std.testing.expectEqual(red_blue_max, parsed.monitors[0].red_blue_value);
    try std.testing.expectEqual(dim_min, parsed.monitors[0].dim_value);
    try std.testing.expect(parsed.monitors[0].image_enabled);
    try std.testing.expectEqual(image_opacity_max, parsed.monitors[0].image_opacity);
    try std.testing.expectEqualStrings("/tmp/first.png", parsed.monitors[0].imagePath());
    try std.testing.expectEqualStrings("HDMI-A-1", parsed.monitors[1].name());
    try std.testing.expectEqual(@as(i32, -75), parsed.monitors[1].red_blue_value);
    try std.testing.expectEqual(@as(i32, 60), parsed.monitors[1].dim_value);
    try std.testing.expect(!parsed.monitors[1].image_enabled);
    try std.testing.expectEqual(image_opacity_zero, parsed.monitors[1].image_opacity);
    try std.testing.expectEqualStrings("", parsed.monitors[1].imagePath());
}

test "max monitor bound rejects retained state beyond limit" {
    var state = State{};
    var index: u32 = 0;
    while (index < max_monitors) : (index += 1) {
        var name_buf: [max_monitor_name_bytes]u8 = undefined;
        const name_text = try std.fmt.bufPrint(&name_buf, "DP-{d}", .{index});
        try state.append(try MonitorState.init(name_text));
    }
    try std.testing.expectEqual(max_monitors, state.count);
    try std.testing.expectError(error.TooManyMonitors, state.append(try MonitorState.init("extra")));
}

test "ensure monitor returns existing slot and preserves bound" {
    var state = State{};
    const first = try state.ensureMonitor("DP-1");
    first.red_blue_enabled = true;
    first.setRedBlueValue(45);

    const second = try state.ensureMonitor("DP-1");
    try std.testing.expectEqual(@as(u32, 1), state.count);
    try std.testing.expect(second.red_blue_enabled);
    try std.testing.expectEqual(@as(i32, 45), second.red_blue_value);

    var index: u32 = 1;
    while (index < max_monitors) : (index += 1) {
        var name_buf: [max_monitor_name_bytes]u8 = undefined;
        const name_text = try std.fmt.bufPrint(&name_buf, "DP-{d}", .{index + 1});
        const monitor = try state.ensureMonitor(name_text);
        try std.testing.expectEqualStrings(name_text, monitor.name());
    }
    try std.testing.expectError(error.TooManyMonitors, state.ensureMonitor("extra"));
}
