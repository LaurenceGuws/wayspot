//! SDL banner owns one short notification surface from render to cleanup.
//!
//! The notification daemon asks for a banner; this file owns the copied text,
//! SDL objects, Hyprland placement command, and bounded display timeout.

const std = @import("std");
const config_defaults = @import("../config/defaults.zig");
const notification_preview = @import("../notifications/preview.zig");
const ui_appearance = @import("appearance.zig");
const surface_config = @import("surface_config.zig");
const sdl_text = @import("sdl_text.zig");

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
const placement_command: [:0]const u8 =
    \\mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n1)
    \\if [ -n "$mon" ]; then
    \\  hyprctl dispatch "hl.dsp.window.move({ monitor = \"$mon\", window = \"title:^Wayspot Notification$\" })" >/dev/null 2>&1
    \\fi
;

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
    const wrapper_pid = try forkProcess();
    if (wrapper_pid == 0) wrapperChild(request);
    try waitProcess(wrapper_pid);
}

fn wrapperChild(request: Request) noreturn {
    const banner_pid = forkProcess() catch std.c._exit(placement_child_fail_code);
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
    var config = try surface_config.load(std.heap.c_allocator);
    const appearance = try config_defaults.loadFromEnvironment(std.heap.c_allocator);
    const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, app_id);
    if (!hint_set) log.debug("SDL app id hint rejected", .{});

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
    var text = try sdl_text.TextEngine.init(std.heap.c_allocator, appearance.fonts.candidates);
    defer text.deinit();

    const shown = c.SDL_ShowWindow(window);
    const raised = c.SDL_RaiseWindow(window);
    if (!shown or !raised) return error.SdlShowFailed;

    try render(renderer, &text, request, &config, appearance.banner);

    placeOnFocusedMonitor();
    try eventLoop(boundedTimeout(request.expire_timeout), window, renderer, &text, request, &config, appearance.banner);
}

fn render(
    renderer: *c.SDL_Renderer,
    text: *sdl_text.TextEngine,
    request: Request,
    config: *const surface_config.SurfaceConfig,
    appearance: ui_appearance.BannerAppearance,
) !void {
    const scale = config.scale();
    const scaled = c.SDL_SetRenderScale(renderer, scale, scale);
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
        .surface_scale = scale,
    });
    try text.draw(renderer, appearance.content_x, appearance.summary_top, summary_text.slice(), .{
        .color = appearance.summary_text.color,
        .max_bytes = notification_preview.banner_summary_max,
        .font_size_px = appearance.summary_text.font_px,
        .surface_scale = scale,
    });
    try text.draw(renderer, appearance.content_x, appearance.body_top, body_text.slice(), .{
        .color = appearance.body_text.color,
        .max_bytes = notification_preview.banner_body_max,
        .font_size_px = appearance.body_text.font_px,
        .surface_scale = scale,
    });

    const presented = c.SDL_RenderPresent(renderer);
    if (!presented) return error.SdlRenderFailed;
}

fn eventLoop(
    timeout_ms: u32,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    text: *sdl_text.TextEngine,
    request: Request,
    config: *surface_config.SurfaceConfig,
    appearance: ui_appearance.BannerAppearance,
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
                if (surface_config.zoomAction(event.key.key, event.key.mod)) |zoom_action| {
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
    config: *const surface_config.SurfaceConfig,
) !void {
    const size = config.scaledDimensions(base_window_width, base_window_height);
    const resized = c.SDL_SetWindowSize(window, @intCast(size.width), @intCast(size.height));
    if (!resized) return error.SdlResizeFailed;
    const synced = c.SDL_SyncWindow(window);
    if (!synced) return error.SdlResizeFailed;
    const scale = config.scale();
    const scaled = c.SDL_SetRenderScale(renderer, scale, scale);
    if (!scaled) return error.SdlScaleFailed;
}

fn setDrawColor(renderer: *c.SDL_Renderer, color: ui_appearance.Rgba8) bool {
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
    runPlacementCommand() catch |err| {
        log.debug("hypr placement command failed err={s}", .{@errorName(err)});
    };
}

fn runPlacementCommand() !void {
    const pid = try forkProcess();
    if (pid == 0) placementChild();
    try waitProcess(pid);
}

fn placementChild() noreturn {
    const shell_path = "/bin/sh";
    const shell_name = "sh";
    const shell_arg = "-lc";
    const argv: [4:null]?[*:0]const u8 = .{
        shell_name,
        shell_arg,
        placement_command.ptr,
        null,
    };
    const exec_rc = std.c.execve(shell_path, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(placement_child_fail_code);
    std.c._exit(placement_child_fail_code);
}

fn forkProcess() !std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

fn waitProcess(pid: std.c.pid_t) !void {
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
