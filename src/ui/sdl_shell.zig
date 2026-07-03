//! SDL shell owns the resident picker window and drains local IPC visibility commands.

const std = @import("std");
const app = @import("../app/mod.zig");
const common_dispatch = @import("common/dispatch.zig");
const ipc_control = @import("../ipc/control.zig");
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

const SdlShell = struct {
    allocator: std.mem.Allocator,
    service: *app.SearchService,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    control_server: ?ipc_control.Server = null,
    control_slot: ipc_control.ControlSlot = .{},
    visible: bool = false,
    resident_mode: bool = false,
    query: std.ArrayList(u8) = .empty,
    results: []@import("../search/mod.zig").ScoredCandidate = &.{},
    selected: u32 = 0,
    dirty: bool = true,

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

        var self = SdlShell{
            .allocator = allocator,
            .service = service,
            .window = window,
            .renderer = renderer,
            .visible = !options.start_hidden,
            .resident_mode = options.resident_mode,
        };
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

            var event: c.SDL_Event = undefined;
            if (c.SDL_WaitEventTimeout(&event, 50)) {
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
                    c.SDLK_ESCAPE => return false,
                    c.SDLK_BACKSPACE => {
                        trimLastUtf8(&self.query);
                        try self.refreshResults();
                    },
                    c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                        try self.activateSelected();
                        return false;
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

    fn activateSelected(self: *SdlShell) !void {
        if (self.results.len == 0) return;
        const candidate = self.results[@intCast(self.selected)].candidate;
        var plan = try common_dispatch.planCommandKind(self.allocator, uiKind(candidate.kind), candidate.action);
        defer plan.deinit(self.allocator);
        if (plan.command) |command| {
            if (common_dispatch.shouldRecordCandidate(candidate.kind)) {
                try self.service.recordSelection(self.allocator, candidate.action);
            }
            if (plan.detach_command) {
                try runDetachedCommand(command);
            } else {
                try runCommand(command);
            }
        }
    }

    fn render(self: *SdlShell) !void {
        const background_color = c.SDL_SetRenderDrawColor(self.renderer, 18, 18, 22, 255);
        const cleared = c.SDL_RenderClear(self.renderer);
        if (!background_color or !cleared) return error.SdlRenderFailed;

        const visible = @min(self.results.len, max_results);
        var y: f32 = 72;
        var i: u32 = 0;
        while (i < visible) : (i += 1) {
            const selected = i == self.selected;
            const shade: u8 = if (selected) 78 else 36;
            const row_color = c.SDL_SetRenderDrawColor(
                self.renderer,
                shade,
                shade,
                if (selected) 94 else 42,
                255,
            );
            const rect = c.SDL_FRect{ .x = 24, .y = y, .w = 712, .h = 34 };
            const filled = c.SDL_RenderFillRect(self.renderer, &rect);
            if (!row_color or !filled) return error.SdlRenderFailed;
            y += 42;
        }

        const title = try self.titleZ();
        defer self.allocator.free(title);
        const title_set = c.SDL_SetWindowTitle(self.window, title.ptr);
        const presented = c.SDL_RenderPresent(self.renderer);
        if (!title_set or !presented) return error.SdlRenderFailed;
    }

    fn titleZ(self: *SdlShell) ![:0]u8 {
        const top = if (self.results.len > 0)
            self.results[@intCast(self.selected)].candidate.title
        else
            "no results";
        return std.fmt.allocPrintSentinel(
            self.allocator,
            "Wayspot | {s} | {s}",
            .{ self.query.items, top },
            0,
        );
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
        else => .unknown,
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
