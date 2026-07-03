//! SDL banner owns one short notification surface from render to cleanup.
//!
//! The notification daemon asks for a banner; this file owns the copied text,
//! SDL objects, Hyprland placement command, and bounded display timeout.

const std = @import("std");
const sdl_text = @import("sdl_text.zig");

const c = @import("sdl_c");

const log = std.log.scoped(.notification_banner);

const window_title = "Wayspot Notification";
const app_id = "wayspot-notification";
const window_width: c_int = 460;
const window_height: c_int = 118;
const banner_margin: i32 = 12;
const default_timeout_ms: u32 = 4200;
const min_timeout_ms: u32 = 1200;
const max_timeout_ms: u32 = 10000;
const event_wait_ms: i32 = 250;
const max_app_bytes: u32 = 80;
const max_summary_bytes: u32 = 160;
const max_body_bytes: u32 = 220;
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
    const hint_set = c.SDL_SetHint(c.SDL_HINT_APP_ID, app_id);
    if (!hint_set) log.debug("SDL app id hint rejected", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        window_title,
        window_width,
        window_height,
        c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP,
    ) orelse return error.SdlWindowFailed;
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SdlRendererFailed;
    defer c.SDL_DestroyRenderer(renderer);

    const shown = c.SDL_ShowWindow(window);
    const raised = c.SDL_RaiseWindow(window);
    if (!shown or !raised) return error.SdlShowFailed;

    try render(renderer, request);

    placeTopLeftFocusedMonitor();
    try eventLoop(boundedTimeout(request.expire_timeout));
}

fn render(renderer: *c.SDL_Renderer, request: Request) !void {
    const background = switch (request.urgency) {
        2 => sdl_text.Rgba8{ .r = 70, .g = 22, .b = 26 },
        0 => sdl_text.Rgba8{ .r = 20, .g = 24, .b = 27 },
        else => sdl_text.Rgba8{ .r = 24, .g = 28, .b = 34 },
    };
    const background_set = c.SDL_SetRenderDrawColor(renderer, background.r, background.g, background.b, 242);
    const cleared = c.SDL_RenderClear(renderer);
    if (!background_set or !cleared) return error.SdlRenderFailed;

    const accent = c.SDL_FRect{ .x = 0, .y = 0, .w = 4, .h = @floatFromInt(window_height) };
    const accent_color = c.SDL_SetRenderDrawColor(renderer, 105, 184, 150, 255);
    const accent_drawn = c.SDL_RenderFillRect(renderer, &accent);
    if (!accent_color or !accent_drawn) return error.SdlRenderFailed;

    try sdl_text.draw(renderer, 18, 14, request.app_name, .{
        .color = .{ .r = 150, .g = 166, .b = 184 },
        .max_bytes = max_app_bytes,
    });
    try sdl_text.draw(renderer, 18, 36, request.summary, .{
        .color = .{ .r = 238, .g = 242, .b = 247 },
        .max_bytes = max_summary_bytes,
    });
    try sdl_text.draw(renderer, 18, 64, request.body, .{
        .color = .{ .r = 188, .g = 198, .b = 210 },
        .max_bytes = max_body_bytes,
    });

    const presented = c.SDL_RenderPresent(renderer);
    if (!presented) return error.SdlRenderFailed;
}

fn eventLoop(timeout_ms: u32) !void {
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
                if (event.key.key == c.SDLK_ESCAPE) return;
            },
            else => {},
        }
    }
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

fn placeTopLeftFocusedMonitor() void {
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
