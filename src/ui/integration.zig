//! Explicit opt-in real Wayland/D-Bus qualification of shared SDL ownership.
const std = @import("std");
const Video = @import("video.zig");
const navigator = @import("../picker/navigator.zig");
const notification = @import("../notifications/root.zig");
const picker = @import("../picker/root.zig");
const View = @import("../picker/view.zig").Native;
const sdl = @import("sdl_c");

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

fn busCall(argv: []const []const u8) !void {
    const allocator = std.heap.page_allocator;
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = argv,
        .stdout_limit = .limited(4096),
        .stderr_limit = .limited(4096),
        .timeout = .{ .duration = .{ .raw = .fromSeconds(3), .clock = .awake } },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.term != .exited or result.term.exited != 0) return error.PrivateBusCallFailed;
}

fn call(service: *notification.Service, argv: []const []const u8, shown: bool) !void {
    var future = try std.testing.io.concurrent(busCall, .{argv});
    var awaited = false;
    defer if (!awaited) future.await(std.testing.io) catch {};
    const start = std.Io.Clock.awake.now(std.testing.io);
    while (true) {
        _ = try service.advance();
        if ((service.deadline() != null) == shown) break;
        if (start.durationTo(std.Io.Clock.awake.now(std.testing.io)).toMilliseconds() >= 3000) return error.PrivateGuiDeadline;
        try std.Io.sleep(std.testing.io, .fromMilliseconds(2), .awake);
    }
    awaited = true;
    try future.await(std.testing.io);
}

const notify = [_][]const u8{
    "/usr/bin/gdbus", "call",     "--session", "--dest",     "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method",    "org.freedesktop.Notifications.Notify",
    "WayspotTest",    "uint32 0", "",          "Shared SDL", "Independent lifetimes",         "@as []",        "@a{sv} {}",                      "int32 60000",
};
const HistoryReader = struct {
    pub fn readHistory(_: @This()) !notification.History {
        return .{};
    }
};

test "private shared video routes two real layers and releases only the closing owner" {
    const requested = getenv("WAYSPOT_GUI_PRIVATE_TEST") orelse return;
    const runtime = std.mem.span(getenv("XDG_RUNTIME_DIR") orelse return error.PrivateRuntimeMissing);
    // Require the explicit private runtime identity, not a flag that could
    // accidentally bind the physical login's bus or display.
    if (!std.mem.eql(u8, std.mem.span(requested), runtime) or std.mem.startsWith(u8, runtime, "/run/user/")) return error.PrivateRuntimeRequired;
    const state_home = std.mem.span(getenv("XDG_STATE_HOME") orelse return error.PrivateStateMissing);
    const home = std.mem.span(getenv("HOME") orelse return error.PrivateHomeMissing);
    const bus = std.mem.span(getenv("DBUS_SESSION_BUS_ADDRESS") orelse return error.PrivateBusMissing);
    if (!std.mem.startsWith(u8, bus, "unix:") or std.mem.endsWith(u8, bus, "/bus")) return error.PrivateBusRequired;
    var video: Video = .{};
    var service = try notification.Service.init(std.testing.allocator, std.testing.io, state_home, home, &video);
    defer service.deinit();
    try service.connect();
    try std.testing.expectEqual(@as(u8, 0), video.users);
    try std.testing.expectEqual(@as(std.posix.fd_t, -1), try video.fd());
    var tray_event: ?u32 = null;
    for (0..3) |cycle| {
        var view: View = .{ .video = &video, .applications = &.{}, .allocator = std.testing.allocator, .io = std.testing.io, .home = home };
        try view.init();
        defer view.quit();
        try std.testing.expect(!sdl.SDL_GetHintBoolean(sdl.SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR, true));
        try view.create();
        defer view.destroy();
        try view.startText();
        defer view.stopText() catch unreachable;
        if (tray_event) |prior| try std.testing.expectEqual(prior, view.tray_event) else tray_event = view.tray_event;
        var state: picker.State = .{ .allocator = std.testing.allocator, .applications = &.{} };
        defer state.deinit();
        try state.begin();
        try view.draw(&state.frame());
        if (cycle == 0 or cycle == 2) try call(&service, &notify, true);
        try std.testing.expectEqual(@as(u8, 2), video.users);
        const banner = service.ui.banner.window orelse return error.PrivateBannerMissing;
        const picker_id = sdl.SDL_GetWindowID(view.window.?);
        const banner_id = sdl.SDL_GetWindowID(banner);
        try std.testing.expect(picker_id != banner_id);
        const deadline = service.deadline().?;
        var input = std.mem.zeroes(sdl.SDL_Event);
        input.type = sdl.SDL_EVENT_TEXT_INPUT;
        input.text.windowID = banner_id;
        input.text.text = "wrong window";
        try std.testing.expectEqual(picker.Event.ignored, try view.handleEvent(input));
        input.text.windowID = picker_id;
        input.text.text = "abc";
        var batch: picker.Events = .{};
        batch.items[0] = try view.handleEvent(input);
        batch.count = 1;
        try std.testing.expectEqual(picker.Action.draw, try state.advance(HistoryReader{}, navigator.Native{ .io = std.testing.io, .environ_map = null }, &batch));
        try std.testing.expectEqualStrings("abc", state.frame().query);
        try view.draw(&state.frame());
        input = std.mem.zeroes(sdl.SDL_Event);
        input.type = sdl.SDL_EVENT_MOUSE_BUTTON_DOWN;
        input.button.windowID = picker_id;
        input.button.button = sdl.SDL_BUTTON_LEFT;
        try service.handleEvent(&input);
        try std.testing.expectEqual(@as(?u64, deadline), service.deadline());
        if (cycle == 0) continue; // destroy only the picker, keep banner alive
        if (cycle == 1) {
            input.button.windowID = banner_id;
            try std.testing.expectEqual(picker.Event.ignored, try view.handleEvent(input));
            try service.handleEvent(&input); // dismissed (2), only the banner
        } else {
            try service.expire(deadline); // expired (1), only the banner
        }
        try std.testing.expect(service.deadline() == null);
        try std.testing.expectEqual(@as(u8, 1), video.users);
        try std.testing.expect(sdl.SDL_GetWindowFromID(picker_id) != null);
        try view.draw(&state.frame());
    }
    try std.testing.expectEqual(@as(u8, 0), video.users);
    try std.testing.expectEqual(@as(std.posix.fd_t, -1), try video.fd());
    try std.testing.expectEqual(@as(u32, 0), sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO));
    try service.flush();
}
