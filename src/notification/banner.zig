//! Notification banner owns one short notification surface from render to cleanup.
//!
//! The notification DBus owner asks for a banner; this file owns the copied text,
//! vendor objects, monitor placement action, and bounded display timeout.

const std = @import("std");
const config_defaults = @import("../config/defaults.zig");
const env = @import("../env/mod.zig");
const notification_preview = @import("../notification/preview.zig");
const appearance_owner = @import("../picker/appearance.zig");
const scale_owner = @import("../picker/scale.zig");
const text_owner = @import("../picker/text.zig");

const c = @import("sdl_c");

const log = std.log.scoped(.notification_banner);

const window_title = "Wayspot Notification";
const app_id = "wayspot-notification";
const base_window_width: i32 = 400;
const base_window_height: i32 = 88;
const default_timeout_ms: u32 = 4200;
const min_timeout_ms: u32 = 1200;
const max_timeout_ms: u32 = 10000;
const event_wait_ms: i32 = 250;
const placement_child_fail_code: i32 = 127;
const max_placement_wait_interrupts: u32 = 8;
const max_window_title_selector_bytes: u32 = 160;

pub const Request = struct {
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
    expire_timeout: i32,
    urgency: u8,
};

fn boundedTimeout(expire_timeout: i32) u32 {
    if (expire_timeout < 0) return default_timeout_ms;
    if (expire_timeout == 0) return max_timeout_ms;
    const requested: u32 = @intCast(expire_timeout);
    return @min(@max(requested, min_timeout_ms), max_timeout_ms);
}

pub fn spawn(request: Request) !void {
    const wrapper_pid = try forkChild();
    if (wrapper_pid == 0) wrapperChild(request);
    try waitChild(wrapper_pid);
}

fn wrapperChild(request: Request) noreturn {
    const banner_pid = forkChild() catch std.c._exit(placement_child_fail_code);
    if (banner_pid == 0) bannerChild(request);
    std.c._exit(0);
}

fn bannerChild(request: Request) noreturn {
    show(request) catch |err| {
        log.warn("banner failed err={s}", .{@errorName(err)});
    };
    std.c._exit(0);
}

fn show(request: Request) !void {
    var config = try scale_owner.SurfaceConfig.load(std.heap.c_allocator);
    const appearance_state = try config_defaults.loadFromEnvironment(std.heap.c_allocator);
    const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, app_id);
    if (!hint_set) log.debug("vendor app id hint rejected", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
    defer c.SDL_Quit();

    const window_size = config.scaledDimensions(base_window_width, base_window_height);
    const window = c.SDL_CreateWindow(
        window_title,
        @intCast(window_size.width),
        @intCast(window_size.height),
        c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP,
    ) orelse return error.SdlWindowFailed;
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SdlRendererFailed;
    defer c.SDL_DestroyRenderer(renderer);
    var text = try text_owner.TextEngine.init(std.heap.c_allocator, appearance_state.fonts.candidates);
    defer text.deinit();

    const shown = c.SDL_ShowWindow(window);
    const raised = c.SDL_RaiseWindow(window);
    if (!shown or !raised) return error.SdlShowFailed;

    try render(renderer, &text, request, &config, appearance_state.banner);

    placeOnFocusedMonitor();
    try eventLoop(boundedTimeout(request.expire_timeout), window, renderer, &text, request, &config, appearance_state.banner);
}

fn render(
    renderer: *c.SDL_Renderer,
    text: *text_owner.TextEngine,
    request: Request,
    config: *const scale_owner.SurfaceConfig,
    appearance: appearance_owner.BannerAppearance,
) !void {
    const surface_scale = config.scale();
    const scaled = c.SDL_SetRenderScale(renderer, surface_scale, surface_scale);
    if (!scaled) return error.SdlRenderFailed;
    const background = switch (request.urgency) {
        2 => appearance.critical_background,
        0 => appearance.low_background,
        else => appearance.normal_background,
    };
    const background_set = setDrawColor(renderer, background);
    const cleared = c.SDL_RenderClear(renderer);
    if (!background_set or !cleared) return error.SdlRenderFailed;

    const accent = c.SDL_FRect{ .x = 0, .y = 0, .w = appearance.accent_w, .h = @floatFromInt(base_window_height) };
    const accent_color = setDrawColor(renderer, appearance.accent);
    const accent_drawn = c.SDL_RenderFillRect(renderer, &accent);
    if (!accent_color or !accent_drawn) return error.SdlRenderFailed;

    const app_text = notification_preview.bannerApp(request.app_name);
    const summary_text = notification_preview.bannerSummary(request.summary);
    const body_text = notification_preview.bannerBody(request.body);

    try text.draw(renderer, appearance.content_x, appearance.app_top, app_text.slice(), .{
        .color = appearance.app_text.color,
        .max_bytes = notification_preview.banner_app_max,
        .font_size_px = appearance.app_text.font_px,
        .surface_scale = surface_scale,
    });
    try text.draw(renderer, appearance.content_x, appearance.summary_top, summary_text.slice(), .{
        .color = appearance.summary_text.color,
        .max_bytes = notification_preview.banner_summary_max,
        .font_size_px = appearance.summary_text.font_px,
        .surface_scale = surface_scale,
    });
    try text.draw(renderer, appearance.content_x, appearance.body_top, body_text.slice(), .{
        .color = appearance.body_text.color,
        .max_bytes = notification_preview.banner_body_max,
        .font_size_px = appearance.body_text.font_px,
        .surface_scale = surface_scale,
    });

    const presented = c.SDL_RenderPresent(renderer);
    if (!presented) return error.SdlRenderFailed;
}

fn eventLoop(
    timeout_ms: u32,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    text: *text_owner.TextEngine,
    request: Request,
    config: *scale_owner.SurfaceConfig,
    appearance: appearance_owner.BannerAppearance,
) !void {
    const start = monotonicMs();
    while (elapsedMs(start) < timeout_ms) {
        var event: c.SDL_Event = undefined;
        if (!c.SDL_WaitEventTimeout(&event, event_wait_ms)) continue;
        switch (event.type) {
            c.SDL_EVENT_QUIT,
            c.SDL_EVENT_TERMINATING,
            c.SDL_EVENT_WINDOW_DESTROYED,
            c.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
            c.SDL_EVENT_MOUSE_BUTTON_DOWN,
            => return,
            c.SDL_EVENT_KEY_DOWN => {
                if (scale_owner.zoomAction(event.key.key, event.key.mod)) |zoom_action| {
                    config.applyZoomAction(zoom_action);
                    try applySurfaceScale(window, renderer, config);
                    try config.save(std.heap.c_allocator);
                    try render(renderer, text, request, config, appearance);
                    placeOnFocusedMonitor();
                    continue;
                }
                if (event.key.key == c.SDLK_ESCAPE) return;
            },
            else => {},
        }
    }
}

fn applySurfaceScale(
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    config: *const scale_owner.SurfaceConfig,
) !void {
    const size = config.scaledDimensions(base_window_width, base_window_height);
    const resized = c.SDL_SetWindowSize(window, @intCast(size.width), @intCast(size.height));
    if (!resized) return error.SdlResizeFailed;
    const synced = c.SDL_SyncWindow(window);
    if (!synced) return error.SdlResizeFailed;
    const surface_scale = config.scale();
    const scaled = c.SDL_SetRenderScale(renderer, surface_scale, surface_scale);
    if (!scaled) return error.SdlScaleFailed;
}

fn setDrawColor(renderer: *c.SDL_Renderer, color: appearance_owner.Rgba8) bool {
    return c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
}

fn elapsedMs(start: u64) u32 {
    const now = monotonicMs();
    if (now <= start) return 0;
    return @intCast(@min(now - start, max_timeout_ms));
}

fn monotonicMs() u64 {
    var ts: std.os.linux.timespec = undefined;
    const rc = std.os.linux.clock_gettime(.MONOTONIC, &ts);
    if (std.os.linux.errno(rc) != .SUCCESS) return 0;
    const seconds_ms: u64 = @intCast(ts.sec * std.time.ms_per_s);
    const nanos_ms: u64 = @intCast(@divTrunc(ts.nsec, std.time.ns_per_ms));
    return seconds_ms + nanos_ms;
}

fn placeOnFocusedMonitor() void {
    const monitor_source = env.MonitorSource.fromProcessEnv() orelse return;
    runPlacementAction(std.heap.c_allocator, monitor_source, window_title) catch |err| {
        log.debug("notification placement action failed err={s}", .{@errorName(err)});
    };
}

fn runPlacementAction(allocator: std.mem.Allocator, monitor_source: env.MonitorSource, title: []const u8) !void {
    const monitors = try monitor_source.queryMonitors(allocator);
    const monitor_name = focusedMonitorName(&monitors) orelse return error.NoFocusedEnvMonitor;
    const command = try placementActionCommand(allocator, monitor_name, title);
    defer allocator.free(command);
    const pid = try forkChild();
    if (pid == 0) placementActionChild(command);
    try waitChild(pid);
}

fn focusedMonitorName(monitors: *const env.monitor.MonitorList) ?[]const u8 {
    var index: u32 = 0;
    while (index < monitors.count) : (index += 1) {
        if (monitors.items[index].focused) return monitors.items[index].nameText();
    }
    return null;
}

fn placementActionCommand(allocator: std.mem.Allocator, monitor_name: []const u8, title: []const u8) ![]u8 {
    if (title.len == 0 or title.len > max_window_title_selector_bytes) return error.InvalidWindowTitle;
    return std.fmt.allocPrint(
        allocator,
        "hyprctl dispatch 'hl.dsp.window.move({{ monitor = \"{s}\", window = \"title:^{s}$\" }})' >/dev/null 2>&1",
        .{ monitor_name, title },
    );
}

fn placementActionChild(command: []const u8) noreturn {
    var command_buf: [512:0]u8 = undefined;
    if (command.len >= command_buf.len) std.c._exit(placement_child_fail_code);
    @memcpy(command_buf[0..command.len], command);
    command_buf[command.len] = 0;
    const shell_path = "/bin/sh";
    const shell_name = "sh";
    const shell_arg = "-lc";
    const argv: [4:null]?[*:0]const u8 = .{
        shell_name,
        shell_arg,
        command_buf[0..command.len :0].ptr,
        null,
    };
    const exec_rc = std.c.execve(shell_path, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(placement_child_fail_code);
    std.c._exit(placement_child_fail_code);
}

fn forkChild() !std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn waitChild(pid: std.c.pid_t) !void {
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_placement_wait_interrupts) {
        const waited = std.c.waitpid(pid, &status, 0);
        if (waited == pid) break;
        if (waited == -1) {
            const errno = std.c._errno().*;
            if (errno == @intFromEnum(std.c.E.INTR)) {
                interrupts += 1;
                continue;
            }
            return error.WaitFailed;
        }
        return error.WaitFailed;
    } else {
        return error.WaitInterruptedTooOften;
    }
    const status_bits: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(status_bits)) return error.CommandFailed;
    if (std.c.W.EXITSTATUS(status_bits) != 0) return error.CommandFailed;
}

test "boundedTimeout clamps notification expiry" {
    try std.testing.expectEqual(default_timeout_ms, boundedTimeout(-1));
    try std.testing.expectEqual(max_timeout_ms, boundedTimeout(0));
    try std.testing.expectEqual(min_timeout_ms, boundedTimeout(1));
    try std.testing.expectEqual(@as(u32, 2500), boundedTimeout(2500));
    try std.testing.expectEqual(max_timeout_ms, boundedTimeout(60000));
}

test "notification placement action uses monitor fact only" {
    var monitors = env.monitor.MonitorList{};
    var first = try env.monitor.Monitor.init(.{ .value = 1 }, "DP-1", try env.monitor.MonitorSize.init(1920, 1080));
    first.focused = false;
    try monitors.append(first);
    var second = try env.monitor.Monitor.init(.{ .value = 2 }, "HDMI-A-1", try env.monitor.MonitorSize.init(1280, 720));
    second.focused = true;
    try monitors.append(second);

    const monitor_name = focusedMonitorName(&monitors) orelse return error.NoFocusedEnvMonitor;
    const command = try placementActionCommand(std.testing.allocator, monitor_name, window_title);
    defer std.testing.allocator.free(command);

    try std.testing.expect(std.mem.indexOf(u8, command, "monitor = \"HDMI-A-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "title:^Wayspot Notification$") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "workspace") == null);
}
