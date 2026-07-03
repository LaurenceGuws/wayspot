//! SDL shell owns the resident picker window and drains local IPC visibility commands.
//!
//! Approved happy path: one prebuilt SDL window, one local IPC slot, app/action
//! search, and typed notification rows. Rendering stays immediate-mode until
//! profiler evidence justifies a retained scene. Text currently uses SDL's
//! built-in debug font; copy Howl text internals only when shaping or glyph
//! atlas reuse becomes a product requirement.

const std = @import("std");
const app = @import("../app/mod.zig");
const common_dispatch = @import("common/dispatch.zig");
const ipc_control = @import("../ipc/control.zig");
const sdl_text = @import("sdl_text.zig");
const SurfaceMode = @import("surfaces/mod.zig").SurfaceMode;
const PlacementPolicy = @import("placement/mod.zig").RuntimePolicy;

const c = @import("sdl_c");

pub const Shell = struct {
    pub const RunOptions = struct {
        resident_mode: bool = false,
        start_hidden: bool = false,
        surface_mode: SurfaceMode = .layer_shell,
        placement_policy: PlacementPolicy = .{},
        show_nerd_stats: bool = true,
        notifications_show_close_button: bool = true,
        notifications_show_dbus_actions: bool = true,
    };

    pub fn run(
        allocator: std.mem.Allocator,
        service: *app.SearchService,
        telemetry: *app.TelemetrySink,
        options: RunOptions,
    ) !void {
        if (telemetry.path.len == 0) return error.TelemetryPathMissing;
        var shell = try SdlShell.init(allocator, service, options);
        defer shell.deinit();
        try shell.startControlServer(options.resident_mode);
        try shell.loop();
    }
};

const max_results = 8;
const max_command_bytes = 4096;
const row_height: f32 = 44;
const row_gap: f32 = 6;
const no_wake_timeout_ms: i32 = 1000;

comptime {
    std.debug.assert(max_results > 0);
    std.debug.assert(max_command_bytes > 0);
}

const PendingLaunch = struct {
    command_buf: [max_command_bytes]u8 = undefined,
    command_len: u32 = 0,
    detach: bool = false,
    active: bool = false,

    fn set(self: *PendingLaunch, command_bytes: []const u8, detach: bool) !void {
        if (command_bytes.len == 0) return error.EmptyCommand;
        if (command_bytes.len > max_command_bytes) return error.CommandTooLong;
        std.debug.assert(!self.active);
        @memcpy(self.command_buf[0..command_bytes.len], command_bytes);
        self.command_len = @intCast(command_bytes.len);
        self.detach = detach;
        self.active = true;
    }

    fn clear(self: *PendingLaunch) void {
        std.debug.assert(self.active);
        self.command_len = 0;
        self.detach = false;
        self.active = false;
    }

    fn bytes(self: *PendingLaunch) []const u8 {
        std.debug.assert(self.active);
        std.debug.assert(self.command_len > 0);
        std.debug.assert(self.command_len <= max_command_bytes);
        return self.command_buf[0..self.command_len];
    }
};

const SdlShell = struct {
    allocator: std.mem.Allocator,
    service: *app.SearchService,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    control_server: ?ipc_control.Server = null,
    control_slot: ipc_control.ControlSlot = .{},
    wake_event_type: u32 = 0,
    visible: bool = false,
    resident_mode: bool = false,
    query: std.ArrayList(u8) = .empty,
    results: []@import("../search/mod.zig").ScoredCandidate = &.{},
    selected: u32 = 0,
    dirty: bool = true,
    pending_launch: PendingLaunch = .{},
    shutdown_after_launch: bool = false,

    fn init(allocator: std.mem.Allocator, service: *app.SearchService, options: Shell.RunOptions) !SdlShell {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        errdefer c.SDL_Quit();

        const window = c.SDL_CreateWindow(
            "Wayspot",
            760,
            420,
            c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_RESIZABLE,
        ) orelse return error.SdlWindowFailed;
        errdefer c.SDL_DestroyWindow(window);
        const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SdlRendererFailed;
        errdefer c.SDL_DestroyRenderer(renderer);
        const text_input_started = c.SDL_StartTextInput(window);
        if (!text_input_started) return error.SdlTextInputFailed;
        const wake_event_type = c.SDL_RegisterEvents(1);
        if (wake_event_type == 0) return error.SdlWakeUnavailable;

        var self = SdlShell{
            .allocator = allocator,
            .service = service,
            .window = window,
            .renderer = renderer,
            .wake_event_type = wake_event_type,
            .visible = !options.start_hidden,
            .resident_mode = options.resident_mode,
        };
        self.control_slot.setWakeEvent(wake_event_type);
        if (self.visible) {
            const shown = c.SDL_ShowWindow(window);
            const raised = c.SDL_RaiseWindow(window);
            if (!shown or !raised) return error.SdlShowFailed;
        }
        try self.refreshResults();
        return self;
    }

    fn startControlServer(self: *SdlShell, resident_mode: bool) !void {
        if (!resident_mode) return;
        self.control_server = try ipc_control.Server.init(self.allocator, &self.control_slot);
        try self.control_server.?.start();
    }

    fn deinit(self: *SdlShell) void {
        if (self.control_server) |*server| {
            server.deinit();
            self.control_server = null;
        }
        self.freeResults();
        self.query.deinit(self.allocator);
        const stopped_text_input = c.SDL_StopTextInput(self.window);
        if (!stopped_text_input) std.log.warn("sdl text input stop failed", .{});
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    fn loop(self: *SdlShell) !void {
        var running = true;
        while (running) {
            self.applyPendingControl();
            if (self.dirty) {
                try self.render();
                self.dirty = false;
            }
            try self.drainPendingLaunch();
            if (self.shutdown_after_launch) break;

            var event: c.SDL_Event = undefined;
            if (self.control_server == null and c.SDL_WaitEventTimeout(&event, no_wake_timeout_ms)) {
                running = try self.handleEvent(&event);
            }
            if (self.control_server != null and c.SDL_WaitEvent(&event)) {
                running = try self.handleEvent(&event);
            }
            while (c.SDL_PollEvent(&event)) {
                if (!try self.handleEvent(&event)) {
                    running = false;
                    break;
                }
            }
        }
    }

    fn handleEvent(self: *SdlShell, event: *const c.SDL_Event) !bool {
        if (event.type == self.wake_event_type) {
            self.applyPendingControl();
            return true;
        }
        switch (event.type) {
            c.SDL_EVENT_QUIT,
            c.SDL_EVENT_TERMINATING,
            c.SDL_EVENT_WINDOW_DESTROYED,
            => return false,
            c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
                if (self.resident_mode) {
                    self.hide();
                } else {
                    return false;
                }
            },
            c.SDL_EVENT_TEXT_INPUT => {
                const text = std.mem.span(event.text.text);
                try self.query.appendSlice(self.allocator, text);
                try self.refreshResults();
            },
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        if (self.resident_mode) {
                            self.hide();
                        } else {
                            return false;
                        }
                    },
                    c.SDLK_BACKSPACE => {
                        trimLastUtf8(&self.query);
                        try self.refreshResults();
                    },
                    c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                        try self.queueSelectedLaunch();
                    },
                    c.SDLK_UP => {
                        if (self.selected > 0) self.selected -= 1;
                        self.dirty = true;
                    },
                    c.SDLK_DOWN => {
                        if (self.selected + 1 < self.results.len) self.selected += 1;
                        self.dirty = true;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return true;
    }

    fn applyPendingControl(self: *SdlShell) void {
        const command = self.control_slot.take() orelse return;
        switch (command) {
            .summon => self.show(),
            .hide => self.hide(),
            .toggle => if (self.visible) self.hide() else self.show(),
            else => {},
        }
    }

    fn show(self: *SdlShell) void {
        self.visible = true;
        const shown = c.SDL_ShowWindow(self.window);
        const raised = c.SDL_RaiseWindow(self.window);
        if (!shown or !raised) std.log.warn("sdl show failed", .{});
        self.dirty = true;
    }

    fn hide(self: *SdlShell) void {
        self.visible = false;
        const hidden = c.SDL_HideWindow(self.window);
        if (!hidden) std.log.warn("sdl hide failed", .{});
    }

    fn refreshResults(self: *SdlShell) !void {
        self.freeResults();
        self.results = try self.service.searchQuery(self.allocator, self.query.items);
        if (self.selected >= self.results.len) {
            self.selected = if (self.results.len == 0) 0 else @intCast(self.results.len - 1);
        }
        self.dirty = true;
    }

    fn queueSelectedLaunch(self: *SdlShell) !void {
        if (self.results.len == 0) return;
        if (self.pending_launch.active) return error.LaunchAlreadyPending;
        const candidate = self.results[@intCast(self.selected)].candidate;
        var plan = try common_dispatch.planCommandKind(self.allocator, uiKind(candidate.kind), candidate.action);
        defer plan.deinit(self.allocator);
        if (common_dispatch.shouldRecordCandidate(candidate.kind)) {
            try self.service.recordSelection(self.allocator, candidate.action);
        }
        try self.pending_launch.set(plan.command, plan.detach_command);
        self.hide();
        self.shutdown_after_launch = !self.resident_mode;
    }

    fn drainPendingLaunch(self: *SdlShell) !void {
        if (!self.pending_launch.active) return;
        const command = self.pending_launch.bytes();
        const detach = self.pending_launch.detach;
        if (detach) {
            try runDetachedCommand(command);
        } else {
            try runCommand(command);
        }
        self.pending_launch.clear();
    }

    fn activeResult(self: *SdlShell) ?@import("../search/mod.zig").ScoredCandidate {
        if (self.results.len == 0) return null;
        std.debug.assert(self.selected < self.results.len);
        return self.results[@intCast(self.selected)];
    }

    fn setTitle(self: *SdlShell) !void {
        const result = self.activeResult();
        const title = try self.titleZ(if (result) |item| item.candidate.title else "no results");
        defer self.allocator.free(title);
        const title_set = c.SDL_SetWindowTitle(self.window, title.ptr);
        if (!title_set) return error.SdlRenderFailed;
    }

    fn titleZ(self: *SdlShell, top: []const u8) ![:0]u8 {
        std.debug.assert(top.len > 0);
        return std.fmt.allocPrintSentinel(
            self.allocator,
            "Wayspot | {s} | {s}",
            .{ self.query.items, top },
            0,
        );
    }

    fn render(self: *SdlShell) !void {
        const background_color = c.SDL_SetRenderDrawColor(self.renderer, 18, 18, 22, 255);
        const cleared = c.SDL_RenderClear(self.renderer);
        if (!background_color or !cleared) return error.SdlRenderFailed;

        try self.drawChrome();
        try self.drawResults();

        const presented = c.SDL_RenderPresent(self.renderer);
        if (!presented) return error.SdlRenderFailed;
    }

    fn drawChrome(self: *SdlShell) !void {
        try sdl_text.draw(self.allocator, self.renderer, 24, 18, "Wayspot", .{
            .color = .{ .r = 210, .g = 226, .b = 245 },
            .max_bytes = 64,
        });
        try sdl_text.draw(self.allocator, self.renderer, 24, 38, self.query.items, .{
            .color = .{ .r = 168, .g = 185, .b = 204 },
            .max_bytes = 84,
        });

        const query_rect = c.SDL_FRect{ .x = 20, .y = 58, .w = 720, .h = 1 };
        const line_color = c.SDL_SetRenderDrawColor(self.renderer, 64, 74, 84, 255);
        const line_drawn = c.SDL_RenderFillRect(self.renderer, &query_rect);
        if (!line_color or !line_drawn) return error.SdlRenderFailed;
    }

    fn drawResults(self: *SdlShell) !void {
        const visible = @min(self.results.len, max_results);
        var y: f32 = 72;
        var i: u32 = 0;
        while (i < visible) : (i += 1) {
            const result = self.results[i].candidate;
            const selected = i == self.selected;
            const shade: u8 = if (selected) 64 else 31;
            const row_color = c.SDL_SetRenderDrawColor(
                self.renderer,
                shade,
                shade,
                if (selected) 82 else 38,
                255,
            );
            const rect = c.SDL_FRect{ .x = 20, .y = y - 6, .w = 720, .h = row_height };
            const filled = c.SDL_RenderFillRect(self.renderer, &rect);
            if (!row_color or !filled) return error.SdlRenderFailed;

            try sdl_text.draw(self.allocator, self.renderer, 34, y, result.title, .{
                .color = if (selected)
                    .{ .r = 246, .g = 248, .b = 252 }
                else
                    .{ .r = 216, .g = 222, .b = 230 },
                .max_bytes = 72,
            });
            try sdl_text.draw(self.allocator, self.renderer, 34, y + 18, result.subtitle, .{
                .color = if (selected)
                    .{ .r = 186, .g = 202, .b = 224 }
                else
                    .{ .r = 140, .g = 152, .b = 166 },
                .max_bytes = 82,
            });
            try sdl_text.draw(self.allocator, self.renderer, 662, y, common_dispatch.kinds.statusLabel(uiKind(result.kind)), .{
                .color = .{ .r = 128, .g = 182, .b = 160 },
                .max_bytes = 12,
            });
            y += row_height + row_gap;
        }

        if (visible == 0) {
            try sdl_text.draw(self.allocator, self.renderer, 34, y, "No results", .{
                .color = .{ .r = 190, .g = 198, .b = 208 },
                .max_bytes = 32,
            });
        }

        try self.setTitle();
    }

    fn freeResults(self: *SdlShell) void {
        if (self.results.len != 0) {
            self.allocator.free(self.results);
            self.results = &.{};
        }
    }
};

fn trimLastUtf8(query: *std.ArrayList(u8)) void {
    if (query.items.len == 0) return;
    var idx = query.items.len - 1;
    while (idx > 0 and (query.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
    query.shrinkRetainingCapacity(idx);
}

fn uiKind(kind: @import("../search/mod.zig").CandidateKind) common_dispatch.kinds.UiKind {
    return switch (kind) {
        .app => .app,
        .action => .action,
        .notification => .notification,
        .hint => .hint,
    };
}

fn runCommand(command: []const u8) !void {
    var child = try std.process.spawn(std.Options.debug_io, .{
        .argv = &.{ "sh", "-lc", command },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });
    const term = try child.wait(std.Options.debug_io);
    if (term != .exited or term.exited != 0) return error.CommandFailed;
}

fn runDetachedCommand(command: []const u8) !void {
    const detach_script = "nohup sh -lc \"$1\" >/dev/null 2>&1 </dev/null &";
    var child = try std.process.spawn(std.Options.debug_io, .{
        .argv = &.{ "sh", "-lc", detach_script, "_", command },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });
    const term = try child.wait(std.Options.debug_io);
    if (term != .exited or term.exited != 0) return error.CommandFailed;
}
