//! Owns notification identity, newest-only presentation, retained history, DBus, and SDL.

const std = @import("std");
const builtin = @import("builtin");
const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const dbus = @cImport({
    @cInclude("dbus/dbus.h");
});

pub const app_name_capacity = 256;
pub const app_icon_capacity = 1024;
pub const summary_capacity = 1024;
pub const body_capacity = 16 * 1024;

pub const Request = struct {
    replaces_id: u32,
    app_name: []const u8,
    app_icon: []const u8,
    summary: []const u8,
    body: []const u8,
    expire_timeout: i32,
};

pub const CloseReason = enum(u32) {
    expired = 1,
    dismissed = 2,
    requested = 3,
};

const timeout_default_ms: u32 = 5_000;
const timeout_max_ms: u32 = 60_000;
const intake_batch_max = 64;
const Generation = u64;

const Key = struct {
    id: u32,
    generation: Generation,
};

const ReplyError = enum {
    unknown_method,
    invalid_signature,
    invalid_utf8,
    field_too_long,
    too_many_actions,
    too_many_hints,
    id_exhausted,
    out_of_memory,
};

const Method = union(enum) {
    get_capabilities,
    notify: Request,
    close: u32,
    get_server_information,
};

const Event = union(enum) {
    method: Method,
    reject: ReplyError,
    idle,
    stop,
    bus_lost,
    name_lost,
};

const Presentation = struct {
    id: u32,
    generation: Generation,
    storage: []u8,
    summary: []u8,
    body: []u8,
    timeout_ms: u32,

    fn init(allocator: std.mem.Allocator, source: *const Notification) error{OutOfMemory}!Presentation {
        const storage = try allocator.alloc(u8, source.summary.len + source.body.len);
        @memcpy(storage[0..source.summary.len], source.summary);
        @memcpy(storage[source.summary.len..], source.body);
        return .{
            .id = source.id,
            .generation = source.generation,
            .storage = storage,
            .summary = storage[0..source.summary.len],
            .body = storage[source.summary.len..],
            .timeout_ms = if (source.expire_timeout < 0)
                timeout_default_ms
            else if (source.expire_timeout == 0)
                timeout_max_ms
            else
                @min(@as(u32, @intCast(source.expire_timeout)), timeout_max_ms),
        };
    }

    fn deinit(value: *Presentation, allocator: std.mem.Allocator) void {
        allocator.free(value.storage);
        value.* = undefined;
    }
};

const Closed = struct { key: Key, reason: CloseReason };
const Desired = union(enum) {
    hidden: Key,
    shown: Presentation,

    fn deinit(desired: *Desired, allocator: std.mem.Allocator) void {
        switch (desired.*) {
            .shown => |*presentation| presentation.deinit(allocator),
            .hidden => {},
        }
        desired.* = undefined;
    }
};

const UiUpdate = union(enum) { none, desired: Desired, stop, failed: anyerror };

const Mailbox = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    changed: std.Io.Condition = .init,
    desired: ?Desired = null,
    closed: ?Closed = null,
    worker_stopped: bool = false,
    worker_error: ?anyerror = null,
    ui_error: ?anyerror = null,
    ui_ready: bool = false,

    fn init(io: std.Io, allocator: std.mem.Allocator) Mailbox {
        return .{ .io = io, .allocator = allocator };
    }

    fn deinit(mailbox: *Mailbox) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        const desired = mailbox.desired;
        mailbox.desired = null;
        mailbox.mutex.unlock(mailbox.io);
        if (desired) |value| {
            var owned = value;
            owned.deinit(mailbox.allocator);
        }
        mailbox.* = undefined;
    }

    fn publish(mailbox: *Mailbox, value: Presentation) !void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        const replaced = mailbox.desired;
        mailbox.desired = .{ .shown = value };
        mailbox.changed.signal(mailbox.io);
        const wake_failed = mailbox.ui_ready and !wakeUi();
        mailbox.mutex.unlock(mailbox.io);
        if (replaced) |old| {
            var owned = old;
            owned.deinit(mailbox.allocator);
        }
        if (wake_failed) return error.SdlWakeFailed;
    }

    fn hide(mailbox: *Mailbox, key: Key) !void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        const replaced = mailbox.desired;
        mailbox.desired = .{ .hidden = key };
        mailbox.changed.signal(mailbox.io);
        const wake_failed = mailbox.ui_ready and !wakeUi();
        mailbox.mutex.unlock(mailbox.io);
        if (replaced) |value| {
            var owned = value;
            owned.deinit(mailbox.allocator);
        }
        if (wake_failed) return error.SdlWakeFailed;
    }

    fn waitDesired(mailbox: *Mailbox) !?Desired {
        mailbox.mutex.lockUncancelable(mailbox.io);
        defer mailbox.mutex.unlock(mailbox.io);
        while ((mailbox.desired == null or mailbox.closed != null) and
            !mailbox.worker_stopped and mailbox.worker_error == null)
        {
            try mailbox.changed.wait(mailbox.io, &mailbox.mutex);
        }
        if (mailbox.worker_error) |err| return err;
        if (mailbox.worker_stopped) return null;
        const value = mailbox.desired;
        mailbox.desired = null;
        return value;
    }

    fn takeUiUpdate(mailbox: *Mailbox) UiUpdate {
        mailbox.mutex.lockUncancelable(mailbox.io);
        defer mailbox.mutex.unlock(mailbox.io);
        if (mailbox.worker_error) |err| return .{ .failed = err };
        if (mailbox.worker_stopped) return .stop;
        if (mailbox.desired) |value| {
            mailbox.desired = null;
            return .{ .desired = value };
        }
        return .none;
    }

    fn reportClosed(mailbox: *Mailbox, value: Closed) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        defer mailbox.mutex.unlock(mailbox.io);
        std.debug.assert(mailbox.closed == null);
        mailbox.closed = value;
    }

    fn takeClosed(mailbox: *Mailbox) ?Closed {
        mailbox.mutex.lockUncancelable(mailbox.io);
        defer mailbox.mutex.unlock(mailbox.io);
        const value = mailbox.closed;
        mailbox.closed = null;
        mailbox.changed.signal(mailbox.io);
        return value;
    }

    fn ready(mailbox: *Mailbox) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        mailbox.ui_ready = true;
        mailbox.mutex.unlock(mailbox.io);
    }

    fn pause(mailbox: *Mailbox) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        mailbox.ui_ready = false;
        mailbox.mutex.unlock(mailbox.io);
    }

    fn workerDone(mailbox: *Mailbox, failure: ?anyerror) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        std.debug.assert(!mailbox.worker_stopped);
        std.debug.assert(mailbox.worker_error == null);
        mailbox.worker_stopped = failure == null;
        mailbox.worker_error = failure;
        mailbox.changed.signal(mailbox.io);
        const wake_failed = mailbox.ui_ready and !wakeUi();
        if (wake_failed and mailbox.worker_error == null) mailbox.worker_error = error.SdlWakeFailed;
        mailbox.mutex.unlock(mailbox.io);
    }

    fn uiFailed(mailbox: *Mailbox, err: anyerror) void {
        mailbox.mutex.lockUncancelable(mailbox.io);
        std.debug.assert(mailbox.ui_error == null);
        mailbox.ui_error = err;
        mailbox.mutex.unlock(mailbox.io);
    }

    fn uiFailure(mailbox: *Mailbox) ?anyerror {
        mailbox.mutex.lockUncancelable(mailbox.io);
        defer mailbox.mutex.unlock(mailbox.io);
        return mailbox.ui_error;
    }
};

const font_bytes = @embedFile("NotoSans-Regular.ttf");
const banner_width = 420;
const banner_height = 120;
const banner_font_size = 16;
const wake_unset = std.math.maxInt(u32);
var wake_event: std.atomic.Value(u32) = .init(wake_unset);

const UiResource = enum(u8) { sdl, ttf, window, renderer, stream, font, engine, summary, body };

const UiResources = struct {
    count: u8 = 0,

    fn acquired(resources: *UiResources, resource: UiResource) void {
        std.debug.assert(resources.count == @intFromEnum(resource));
        resources.count += 1;
    }

    fn release(resources: *UiResources) ?UiResource {
        if (resources.count == 0) return null;
        resources.count -= 1;
        return @enumFromInt(resources.count);
    }
};

const Banner = struct {
    window: ?*sdl.SDL_Window = null,
    renderer: ?*sdl.SDL_Renderer = null,
    stream: ?*sdl.SDL_IOStream = null,
    font: ?*sdl.TTF_Font = null,
    engine: ?*sdl.TTF_TextEngine = null,
    summary: ?*sdl.TTF_Text = null,
    body: ?*sdl.TTF_Text = null,
    resources: UiResources = .{},

    fn init(banner: *Banner, mailbox: *Mailbox) !void {
        if (!sdl.SDL_SetAppMetadata("wayspot notification", "0.1.0", "wayspot-notification")) {
            return error.SdlMetadataFailed;
        }
        errdefer banner.deinit(mailbox);
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) return error.SdlInitFailed;
        banner.resources.acquired(.sdl);
        if (!sdl.TTF_Init()) return error.TtfInitFailed;
        banner.resources.acquired(.ttf);
        const event = sdl.SDL_RegisterEvents(1);
        if (event == wake_unset) return error.SdlEventRegistrationFailed;
        wake_event.store(event, .release);
        banner.window = sdl.SDL_CreateWindow(
            "wayspot notification",
            banner_width,
            banner_height,
            sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY |
                sdl.SDL_WINDOW_BORDERLESS |
                sdl.SDL_WINDOW_ALWAYS_ON_TOP |
                sdl.SDL_WINDOW_NOT_FOCUSABLE |
                sdl.SDL_WINDOW_HIDDEN,
        ) orelse return error.SdlCreateFailed;
        banner.resources.acquired(.window);
        banner.renderer = sdl.SDL_CreateRenderer(banner.window, null) orelse return error.SdlRendererCreateFailed;
        banner.resources.acquired(.renderer);
        if (!sdl.SDL_SetRenderLogicalPresentation(
            banner.renderer,
            banner_width,
            banner_height,
            sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
        )) return error.SdlLogicalPresentationFailed;
        banner.stream = sdl.SDL_IOFromConstMem(font_bytes.ptr, font_bytes.len) orelse
            return error.TtfFontStreamCreateFailed;
        banner.resources.acquired(.stream);
        banner.font = sdl.TTF_OpenFontIO(banner.stream, false, banner_font_size) orelse
            return error.TtfFontOpenFailed;
        banner.resources.acquired(.font);
        banner.engine = sdl.TTF_CreateRendererTextEngine(banner.renderer) orelse
            return error.TtfTextEngineCreateFailed;
        banner.resources.acquired(.engine);
        banner.summary = sdl.TTF_CreateText(banner.engine, banner.font, "", 0) orelse
            return error.TtfTextCreateFailed;
        banner.resources.acquired(.summary);
        banner.body = sdl.TTF_CreateText(banner.engine, banner.font, "", 0) orelse
            return error.TtfTextCreateFailed;
        banner.resources.acquired(.body);
        if (!sdl.TTF_SetTextWrapWidth(banner.body, banner_width - 32)) return error.TtfTextWrapFailed;
        mailbox.ready();
    }

    fn deinit(banner: *Banner, mailbox: *Mailbox) void {
        mailbox.pause();
        wake_event.store(wake_unset, .release);
        while (banner.resources.release()) |resource| switch (resource) {
            .body => sdl.TTF_DestroyText(banner.body.?),
            .summary => sdl.TTF_DestroyText(banner.summary.?),
            .engine => sdl.TTF_DestroyRendererTextEngine(banner.engine.?),
            .font => sdl.TTF_CloseFont(banner.font.?),
            .stream => std.debug.assert(sdl.SDL_CloseIO(banner.stream.?)),
            .renderer => sdl.SDL_DestroyRenderer(banner.renderer.?),
            .window => sdl.SDL_DestroyWindow(banner.window.?),
            .ttf => sdl.TTF_Quit(),
            .sdl => sdl.SDL_Quit(),
        };
        banner.* = .{};
    }

    fn draw(banner: *Banner, item: *const Presentation) !void {
        const renderer = banner.renderer orelse unreachable;
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        if (!sdl.TTF_SetTextString(banner.summary, item.summary.ptr, item.summary.len) or
            !sdl.TTF_SetTextString(banner.body, item.body.ptr, item.body.len)) return error.TtfTextSetFailed;
        if (!sdl.TTF_SetTextColor(banner.summary, 235, 235, 240, 255) or
            !sdl.TTF_SetTextColor(banner.body, 190, 192, 202, 255)) return error.TtfTextColorFailed;
        const summary_clip = sdl.SDL_Rect{ .x = 16, .y = 12, .w = banner_width - 32, .h = 24 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &summary_clip)) return error.SdlClipFailed;
        if (!sdl.TTF_DrawRendererText(banner.summary, 16, 14)) return error.TtfTextDrawFailed;
        const body_clip = sdl.SDL_Rect{ .x = 16, .y = 42, .w = banner_width - 32, .h = 60 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &body_clip)) return error.SdlClipFailed;
        if (!sdl.TTF_DrawRendererText(banner.body, 16, 44)) return error.TtfTextDrawFailed;
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlClipFailed;
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
        if (!sdl.SDL_ShowWindow(banner.window)) return error.SdlShowFailed;
    }
};

fn wakeUi() bool {
    const event_type = wake_event.load(.acquire);
    if (event_type == wake_unset) return false;
    var event: sdl.SDL_Event = @bitCast(@as([@sizeOf(sdl.SDL_Event)]u8, @splat(0)));
    event.type = event_type;
    return sdl.SDL_PushEvent(&event);
}

const UiPhase = enum { cold, initializing, visible };
const UiAction = enum { none, initialize, draw, hide };
const UiSignal = union(enum) { shown: Key, hidden: Key, stop, failed: anyerror };
const UiDecision = union(enum) { none, initialize, draw, hide, stop, failed: anyerror };

const UiState = struct {
    phase: UiPhase = .cold,
    key: ?Key = null,
    deadline: u64 = 0,
    reported: bool = false,

    fn show(state: *UiState, key: Key) UiAction {
        state.key = key;
        return switch (state.phase) {
            .cold => blk: {
                state.phase = .initializing;
                break :blk .initialize;
            },
            .initializing => .none,
            .visible => .draw,
        };
    }

    fn hide(state: *UiState, _: Key) UiAction {
        const action: UiAction = if (state.phase == .cold) .none else .hide;
        state.* = .{};
        return action;
    }

    fn drawn(state: *UiState, now: u64, timeout_ms: u32) UiAction {
        std.debug.assert(state.phase == .initializing or state.phase == .visible);
        std.debug.assert(state.key != null);
        state.phase = .visible;
        state.deadline = now +| timeout_ms;
        return .draw;
    }

    fn remaining(state: *const UiState, now: u64) i32 {
        std.debug.assert(state.phase == .visible);
        return @intCast(@min(state.deadline -| now, timeout_max_ms));
    }

    fn close(state: *UiState, reason: CloseReason) ?Closed {
        if (state.reported) return null;
        const key = state.key orelse return null;
        state.reported = true;
        return .{ .key = key, .reason = reason };
    }
};

fn decideUi(state: *UiState, signal: UiSignal) UiDecision {
    return switch (signal) {
        .shown => |key| switch (state.show(key)) {
            .none => .none,
            .initialize => .initialize,
            .draw => .draw,
            .hide => unreachable,
        },
        .hidden => |key| switch (state.hide(key)) {
            .none => .none,
            .hide => .hide,
            .initialize, .draw => unreachable,
        },
        .stop => .stop,
        .failed => |err| .{ .failed = err },
    };
}

fn runUi(mailbox: *Mailbox, allocator: std.mem.Allocator) !void {
    while (try mailbox.waitDesired()) |first| {
        var state: UiState = .{};
        var visible = switch (first) {
            .hidden => |key| {
                std.debug.assert(decideUi(&state, .{ .hidden = key }) == .none);
                continue;
            },
            .shown => |presentation| blk: {
                std.debug.assert(decideUi(&state, .{ .shown = .{
                    .id = presentation.id,
                    .generation = presentation.generation,
                } }) == .initialize);
                break :blk presentation;
            },
        };
        defer visible.deinit(allocator);
        var banner: Banner = .{};
        try banner.init(mailbox);
        defer banner.deinit(mailbox);

        switch (mailbox.takeUiUpdate()) {
            .desired => |desired| switch (desired) {
                .shown => |newest| {
                    visible.deinit(allocator);
                    visible = newest;
                    std.debug.assert(decideUi(&state, .{ .shown = .{
                        .id = newest.id,
                        .generation = newest.generation,
                    } }) == .none);
                },
                .hidden => |key| {
                    std.debug.assert(decideUi(&state, .{ .hidden = key }) == .hide);
                    continue;
                },
            },
            .stop => {
                std.debug.assert(decideUi(&state, .stop) == .stop);
                return;
            },
            .failed => |err| {
                const decision = decideUi(&state, .{ .failed = err });
                return decision.failed;
            },
            .none => {},
        }
        std.debug.assert(state.drawn(sdl.SDL_GetTicks(), visible.timeout_ms) == .draw);
        try banner.draw(&visible);
        session: while (true) {
            const now = sdl.SDL_GetTicks();
            var event: sdl.SDL_Event = undefined;
            if (!sdl.SDL_WaitEventTimeout(&event, state.remaining(now))) {
                if (sdl.SDL_GetTicks() >= state.deadline) {
                    mailbox.reportClosed(state.close(.expired).?);
                    break :session;
                }
                continue;
            }
            if (event.type == wake_event.load(.acquire)) {
                switch (mailbox.takeUiUpdate()) {
                    .desired => |desired| switch (desired) {
                        .shown => |newest| {
                            visible.deinit(allocator);
                            visible = newest;
                            std.debug.assert(decideUi(&state, .{ .shown = .{
                                .id = newest.id,
                                .generation = newest.generation,
                            } }) == .draw);
                            std.debug.assert(
                                state.drawn(sdl.SDL_GetTicks(), visible.timeout_ms) == .draw,
                            );
                            try banner.draw(&visible);
                        },
                        .hidden => |key| {
                            std.debug.assert(decideUi(&state, .{ .hidden = key }) == .hide);
                            break :session;
                        },
                    },
                    .stop => {
                        std.debug.assert(decideUi(&state, .stop) == .stop);
                        return;
                    },
                    .failed => |err| {
                        const decision = decideUi(&state, .{ .failed = err });
                        return decision.failed;
                    },
                    .none => {},
                }
            } else if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN and
                event.button.button == sdl.SDL_BUTTON_LEFT)
            {
                mailbox.reportClosed(state.close(.dismissed).?);
                break :session;
            } else switch (event.type) {
                sdl.SDL_EVENT_WINDOW_EXPOSED,
                sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
                sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
                sdl.SDL_EVENT_RENDER_TARGETS_RESET,
                => try banner.draw(&visible),
                sdl.SDL_EVENT_RENDER_DEVICE_LOST => return error.SdlDeviceLost,
                else => {},
            }
        }
    }
}

const Notification = struct {
    id: u32,
    generation: Generation,
    storage: []u8,
    app_name: []u8,
    summary: []u8,
    body: []u8,
    expire_timeout: i32,

    fn init(allocator: std.mem.Allocator, key: Key, request: Request) Error!Notification {
        try validateRequest(request);
        const size = request.app_name.len + request.summary.len + request.body.len;
        const storage = allocator.alloc(u8, size) catch return error.OutOfMemory;
        var offset: usize = 0;
        return .{
            .id = key.id,
            .generation = key.generation,
            .storage = storage,
            .app_name = copy(storage, &offset, request.app_name),
            .summary = copy(storage, &offset, request.summary),
            .body = copy(storage, &offset, request.body),
            .expire_timeout = request.expire_timeout,
        };
    }

    fn deinit(value: *Notification, allocator: std.mem.Allocator) void {
        allocator.free(value.storage);
        value.* = undefined;
    }
};

fn validateRequest(request: Request) Error!void {
    inline for (.{
        .{ request.app_name, app_name_capacity },
        .{ request.app_icon, app_icon_capacity },
        .{ request.summary, summary_capacity },
        .{ request.body, body_capacity },
    }) |field| {
        if (field[0].len > field[1]) return error.FieldTooLong;
        if (!std.unicode.utf8ValidateSlice(field[0])) return error.InvalidUtf8;
    }
}

pub const record_capacity = 4096;
pub const file_capacity = 32 * 1024 * 1024;
pub const line_capacity = 18_432;
pub const retention_seconds: i64 = 30 * 24 * 60 * 60;

pub const Error = error{
    OutOfMemory,
    InvalidUtf8,
    FieldTooLong,
    IdExhausted,
    GenerationExhausted,
    PathMissing,
    HistoryOpenFailed,
    HistoryReadFailed,
    HistoryCorrupt,
    HistoryTooLarge,
    LineTooLong,
    HistoryIdExhausted,
    HistoryWriteFailed,
    HistorySyncFailed,
    HistoryReplaceFailed,
    HistoryCleanupFailed,
    ClockInvalid,
};

/// Record owns exactly the retained text and its complete encoded line length.
pub const Record = struct {
    received_unix_seconds: i64,
    history_id: u64,
    storage: []u8,
    app_name: []u8,
    summary: []u8,
    body: []u8,
    line_bytes: usize,

    fn init(
        allocator: std.mem.Allocator,
        received_unix_seconds: i64,
        history_id: u64,
        app_name: []const u8,
        summary: []const u8,
        body: []const u8,
    ) Error!Record {
        if (received_unix_seconds < 0 or history_id == 0) return error.HistoryCorrupt;
        if (app_name.len > app_name_capacity or
            summary.len > summary_capacity or
            body.len > body_capacity or
            !std.unicode.utf8ValidateSlice(app_name) or
            !std.unicode.utf8ValidateSlice(summary) or
            !std.unicode.utf8ValidateSlice(body))
        {
            return error.HistoryCorrupt;
        }
        const storage = allocator.alloc(u8, app_name.len + summary.len + body.len) catch {
            return error.OutOfMemory;
        };
        errdefer allocator.free(storage);
        var offset: usize = 0;
        const record = Record{
            .received_unix_seconds = received_unix_seconds,
            .history_id = history_id,
            .storage = storage,
            .app_name = copy(storage, &offset, app_name),
            .summary = copy(storage, &offset, summary),
            .body = copy(storage, &offset, body),
            .line_bytes = 0,
        };
        var result = record;
        result.line_bytes = try lineLength(result);
        return result;
    }

    fn deinit(record: *Record, allocator: std.mem.Allocator) void {
        allocator.free(record.storage);
        record.* = undefined;
    }
};

const Active = struct {
    notification_id: u32,
    generation: Generation,
    history_id: u64,
};

/// History owns oldest-first retained records and runtime-only active-id associations.
pub const History = struct {
    records: [record_capacity]?Record = @splat(null),
    count: usize = 0,
    file_bytes: usize = 0,
    next_history_id: u64 = 1,
    active: ?Active = null,

    pub fn deinit(history: *History, allocator: std.mem.Allocator) void {
        history.assertValid();
        for (history.records[0..history.count]) |*slot| slot.*.?.deinit(allocator);
        history.* = .{};
    }

    /// Adds or replaces one accepted notification, then prunes oldest records.
    pub fn accepted(
        history: *History,
        allocator: std.mem.Allocator,
        now: i64,
        source: *const Notification,
        replaces: bool,
    ) Error!void {
        history.assertValid();
        const replacing = replaces and history.active != null and history.active.?.notification_id == source.id;
        const history_id = if (replacing)
            history.active.?.history_id
        else blk: {
            if (history.next_history_id == std.math.maxInt(u64)) {
                return error.HistoryIdExhausted;
            }
            break :blk history.next_history_id;
        };
        var record = try Record.init(
            allocator,
            now,
            history_id,
            source.app_name,
            source.summary,
            source.body,
        );
        errdefer record.deinit(allocator);

        if (history.findRecord(history_id)) |index| history.removeRecord(allocator, index);
        history.retain(allocator, record);
        history.active = .{
            .notification_id = source.id,
            .generation = source.generation,
            .history_id = history_id,
        };
        if (!replacing) history.next_history_id += 1;
        history.prune(allocator, now);
        history.assertValid();
    }

    /// Forgets the runtime-only association for one closed Freedesktop id.
    pub fn closed(history: *History, key: Key) void {
        if (history.active == null or
            history.active.?.notification_id != key.id or
            history.active.?.generation != key.generation) return;
        history.active = null;
        history.assertValid();
    }

    fn append(history: *History, record: Record) void {
        std.debug.assert(history.count < history.records.len);
        history.records[history.count] = record;
        history.count += 1;
        history.file_bytes += record.line_bytes;
    }

    fn retain(history: *History, allocator: std.mem.Allocator, record: Record) void {
        if (history.count == history.records.len) {
            if (record.received_unix_seconds <= history.records[0].?.received_unix_seconds) {
                var discarded = record;
                discarded.deinit(allocator);
                return;
            }
            history.removeRecord(allocator, 0);
        }
        var index = history.count;
        while (index > 0 and
            history.records[index - 1].?.received_unix_seconds > record.received_unix_seconds)
        {
            history.records[index] = history.records[index - 1];
            index -= 1;
        }
        history.records[index] = record;
        history.count += 1;
        history.file_bytes += record.line_bytes;
    }

    fn prune(history: *History, allocator: std.mem.Allocator, now: i64) void {
        const cutoff = if (now >= retention_seconds) now - retention_seconds else 0;
        while (history.count > 0 and history.records[0].?.received_unix_seconds < cutoff) {
            history.removeRecord(allocator, 0);
        }
        while (history.count > record_capacity or history.file_bytes > file_capacity) {
            history.removeRecord(allocator, 0);
        }
    }

    fn removeRecord(history: *History, allocator: std.mem.Allocator, index: usize) void {
        std.debug.assert(index < history.count);
        history.file_bytes -= history.records[index].?.line_bytes;
        history.records[index].?.deinit(allocator);
        var cursor = index;
        while (cursor + 1 < history.count) : (cursor += 1) {
            history.records[cursor] = history.records[cursor + 1];
        }
        history.count -= 1;
        history.records[history.count] = null;
    }

    fn findRecord(history: *const History, history_id: u64) ?usize {
        for (history.records[0..history.count], 0..) |slot, index| {
            if (slot.?.history_id == history_id) return index;
        }
        return null;
    }

    fn assertValid(history: *const History) void {
        std.debug.assert(history.count <= record_capacity);
        std.debug.assert(history.next_history_id != 0);
        if (history.active) |active| {
            std.debug.assert(active.notification_id != 0);
            std.debug.assert(active.generation != 0);
            std.debug.assert(history.findRecord(active.history_id) != null);
        }
        var bytes: usize = 0;
        for (history.records, 0..) |slot, index| {
            std.debug.assert((index < history.count) == (slot != null));
            const record = slot orelse continue;
            std.debug.assert(record.history_id != 0);
            std.debug.assert(record.line_bytes <= line_capacity);
            bytes += record.line_bytes;
            for (history.records[index + 1 .. history.count]) |other| {
                std.debug.assert(record.history_id != other.?.history_id);
            }
        }
        std.debug.assert(bytes == history.file_bytes);
        std.debug.assert(history.file_bytes <= file_capacity);
    }
};

const Wire = struct {
    received_unix_seconds: i64,
    history_id: u64,
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
};

const PublicRecord = struct {
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
};

/// Parses only a complete bounded JSONL file and publishes no partial history.
pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, now: i64) Error!History {
    if (bytes.len > file_capacity) return error.HistoryTooLarge;
    if (bytes.len > 0 and bytes[bytes.len - 1] != '\n') return error.HistoryCorrupt;
    var history: History = .{};
    errdefer history.deinit(allocator);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (lines.peek() == null) break;
            return error.HistoryCorrupt;
        }
        if (line.len + 1 > line_capacity) return error.LineTooLong;
        var parsed = std.json.parseFromSlice(Wire, allocator, line, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
            .max_value_len = line_capacity,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.HistoryCorrupt,
        };
        defer parsed.deinit();
        if (history.findRecord(parsed.value.history_id) != null) return error.HistoryCorrupt;
        var record = try Record.init(
            allocator,
            parsed.value.received_unix_seconds,
            parsed.value.history_id,
            parsed.value.app_name,
            parsed.value.summary,
            parsed.value.body,
        );
        errdefer record.deinit(allocator);
        history.retain(allocator, record);
    }
    history.prune(allocator, now);
    var greatest: u64 = 0;
    for (history.records[0..history.count]) |slot| greatest = @max(greatest, slot.?.history_id);
    if (greatest == std.math.maxInt(u64)) return error.HistoryIdExhausted;
    history.next_history_id = greatest + 1;
    history.assertValid();
    return history;
}

/// Reads one complete byte snapshot, then publishes only a complete parsed history.
pub fn load(source: anytype, allocator: std.mem.Allocator, now: i64) Error!History {
    const bytes = try source.read();
    defer allocator.free(bytes);
    return parse(allocator, bytes, now);
}

pub fn encode(allocator: std.mem.Allocator, history: *const History) Error![]u8 {
    history.assertValid();
    const bytes = allocator.alloc(u8, history.file_bytes) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    for (history.records[0..history.count]) |slot| writeLine(&writer, slot.?) catch {
        return error.HistoryCorrupt;
    };
    std.debug.assert(writer.buffered().len == bytes.len);
    return bytes;
}

/// Formats one complete newest-first public view before any caller writes it.
pub fn format(allocator: std.mem.Allocator, history: *const History) Error![]u8 {
    history.assertValid();
    var length: usize = 0;
    var line: [line_capacity]u8 = undefined;
    for (history.records[0..history.count]) |slot| {
        var writer: std.Io.Writer = .fixed(&line);
        writePublicLine(&writer, slot.?) catch return error.LineTooLong;
        length = std.math.add(usize, length, writer.buffered().len) catch {
            return error.HistoryTooLarge;
        };
        if (length > file_capacity) return error.HistoryTooLarge;
    }
    const bytes = allocator.alloc(u8, length) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    var index = history.count;
    while (index > 0) {
        index -= 1;
        writePublicLine(&writer, history.records[index].?) catch return error.HistoryCorrupt;
    }
    std.debug.assert(writer.buffered().len == bytes.len);
    return bytes;
}

fn lineLength(record: Record) Error!usize {
    var bytes: [line_capacity]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    writeLine(&writer, record) catch return error.LineTooLong;
    return writer.buffered().len;
}

fn writeLine(writer: *std.Io.Writer, record: Record) !void {
    try std.json.Stringify.value(Wire{
        .received_unix_seconds = record.received_unix_seconds,
        .history_id = record.history_id,
        .app_name = record.app_name,
        .summary = record.summary,
        .body = record.body,
    }, .{}, writer);
    try writer.writeByte('\n');
}

fn writePublicLine(writer: *std.Io.Writer, record: Record) !void {
    try std.json.Stringify.value(PublicRecord{
        .app_name = record.app_name,
        .summary = record.summary,
        .body = record.body,
    }, .{}, writer);
    try writer.writeByte('\n');
}

fn copy(storage: []u8, offset: *usize, bytes: []const u8) []u8 {
    const result = storage[offset.*..][0..bytes.len];
    @memcpy(result, bytes);
    offset.* += bytes.len;
    return result;
}

/// Executes one exact temporary-write, sync, replace, and parent-sync history.
pub fn persist(source: anytype, bytes: []const u8) !void {
    try source.begin();
    source.write(bytes) catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    source.syncFile() catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    source.adopt() catch |err| {
        source.abort() catch return error.HistoryCleanupFailed;
        return err;
    };
    try source.syncParent();
}

/// Native owns the private state directory and at most one PID-qualified sibling file.
pub const Native = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    directory_path: []u8,
    directory: std.Io.Dir,
    temporary_name: [64]u8,
    temporary_name_length: usize,
    temporary: ?std.Io.File = null,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
    ) Error!Native {
        const owned_path = try directoryPath(allocator, state_home, home);
        errdefer allocator.free(owned_path);
        const directory = std.Io.Dir.cwd().createDirPathOpen(io, owned_path, .{
            .open_options = .{ .iterate = true },
            .permissions = .fromMode(0o700),
        }) catch return error.HistoryOpenFailed;
        errdefer directory.close(io);
        directory.setPermissions(io, .fromMode(0o700)) catch return error.HistoryOpenFailed;
        var temporary_name: [64]u8 = undefined;
        const name = std.fmt.bufPrint(
            &temporary_name,
            "notifications.{d}.tmp",
            .{std.os.linux.getpid()},
        ) catch unreachable;
        return .{
            .allocator = allocator,
            .io = io,
            .directory_path = owned_path,
            .directory = directory,
            .temporary_name = temporary_name,
            .temporary_name_length = name.len,
        };
    }

    pub fn deinit(native: *Native) void {
        std.debug.assert(native.temporary == null);
        native.directory.close(native.io);
        native.allocator.free(native.directory_path);
        native.* = undefined;
    }

    pub fn read(native: *Native) Error![]u8 {
        const file = native.directory.openFile(native.io, "notifications.jsonl", .{}) catch |err| switch (err) {
            error.FileNotFound => return native.allocator.alloc(u8, 0) catch error.OutOfMemory,
            else => return error.HistoryOpenFailed,
        };
        defer file.close(native.io);
        file.setPermissions(native.io, .fromMode(0o600)) catch return error.HistoryOpenFailed;
        const size = file.length(native.io) catch return error.HistoryReadFailed;
        if (size > file_capacity) return error.HistoryTooLarge;
        const bytes = native.allocator.alloc(u8, @intCast(size)) catch return error.OutOfMemory;
        errdefer native.allocator.free(bytes);
        const count = file.readPositionalAll(native.io, bytes, 0) catch return error.HistoryReadFailed;
        if (count != bytes.len) return error.HistoryReadFailed;
        return bytes;
    }

    pub fn begin(native: *Native) Error!void {
        std.debug.assert(native.temporary == null);
        const temporary_name = native.temporary_name[0..native.temporary_name_length];
        native.directory.deleteFile(native.io, temporary_name) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return error.HistoryCleanupFailed,
        };
        native.temporary = native.directory.createFile(native.io, temporary_name, .{
            .permissions = .fromMode(0o600),
            .exclusive = true,
        }) catch return error.HistoryOpenFailed;
    }

    pub fn write(native: *Native, bytes: []const u8) Error!void {
        const temporary = native.temporary orelse return error.HistoryWriteFailed;
        temporary.writeStreamingAll(native.io, bytes) catch return error.HistoryWriteFailed;
    }

    pub fn syncFile(native: *Native) Error!void {
        const temporary = native.temporary orelse return error.HistorySyncFailed;
        temporary.sync(native.io) catch return error.HistorySyncFailed;
    }

    pub fn adopt(native: *Native) Error!void {
        const temporary = native.temporary orelse return error.HistoryReplaceFailed;
        temporary.close(native.io);
        native.temporary = null;
        native.directory.rename(
            native.temporary_name[0..native.temporary_name_length],
            native.directory,
            "notifications.jsonl",
            native.io,
        ) catch return error.HistoryReplaceFailed;
    }

    pub fn syncParent(native: *Native) Error!void {
        const parent_file = std.Io.File{
            .handle = native.directory.handle,
            .flags = .{ .nonblocking = false },
        };
        parent_file.sync(native.io) catch return error.HistorySyncFailed;
    }

    pub fn abort(native: *Native) Error!void {
        if (native.temporary) |temporary| {
            temporary.close(native.io);
            native.temporary = null;
        }
        native.directory.deleteFile(
            native.io,
            native.temporary_name[0..native.temporary_name_length],
        ) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return error.HistoryCleanupFailed,
        };
    }
};

fn directoryPath(
    allocator: std.mem.Allocator,
    state_home: ?[]const u8,
    home: ?[]const u8,
) Error![]u8 {
    if (state_home) |path| {
        if (path.len > 0 and std.fs.path.isAbsolute(path)) {
            return std.fs.path.join(allocator, &.{ path, "wayspot" }) catch error.OutOfMemory;
        }
    }
    const path = home orelse return error.PathMissing;
    if (path.len == 0 or !std.fs.path.isAbsolute(path)) return error.PathMissing;
    return std.fs.path.join(allocator, &.{ path, ".local", "state", "wayspot" }) catch error.OutOfMemory;
}

const ReadStat = struct {
    kind: std.Io.File.Kind,
    mode: u16,
    size: u64,
};

/// Reads one complete retained byte snapshot and closes each opened handle once.
fn readRetained(source: anytype, allocator: std.mem.Allocator) Error!?[]u8 {
    if (!try source.openDirectory()) return null;
    defer source.closeDirectory();
    const directory = try source.statDirectory();
    if (directory.kind != .directory or directory.mode != 0o700) return error.HistoryOpenFailed;

    if (!try source.openFile()) return null;
    defer source.closeFile();
    const file = try source.statFile();
    if (file.kind != .file or file.mode != 0o600) return error.HistoryOpenFailed;
    if (file.size > file_capacity) return error.HistoryTooLarge;

    const bytes = allocator.alloc(u8, @intCast(file.size)) catch return error.OutOfMemory;
    errdefer allocator.free(bytes);
    if (try source.read(bytes) != bytes.len) return error.HistoryReadFailed;
    return bytes;
}

/// Owns read-only handles for the one retained notification file.
const ReadNative = struct {
    io: std.Io,
    path: []const u8,
    directory: ?std.Io.Dir = null,
    file: ?std.Io.File = null,

    fn openDirectory(native: *ReadNative) Error!bool {
        std.debug.assert(native.directory == null);
        native.directory = std.Io.Dir.cwd().openDir(native.io, native.path, .{
            .follow_symlinks = true,
        }) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return error.HistoryOpenFailed,
        };
        return true;
    }

    fn statDirectory(native: *ReadNative) Error!ReadStat {
        const stat = (native.directory orelse return error.HistoryOpenFailed).stat(native.io) catch {
            return error.HistoryOpenFailed;
        };
        return statValue(stat);
    }

    fn openFile(native: *ReadNative) Error!bool {
        std.debug.assert(native.file == null);
        const directory = native.directory orelse return error.HistoryOpenFailed;
        native.file = directory.openFile(native.io, "notifications.jsonl", .{
            .follow_symlinks = true,
        }) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return error.HistoryOpenFailed,
        };
        return true;
    }

    fn statFile(native: *ReadNative) Error!ReadStat {
        const stat = (native.file orelse return error.HistoryOpenFailed).stat(native.io) catch {
            return error.HistoryReadFailed;
        };
        return statValue(stat);
    }

    fn read(native: *ReadNative, bytes: []u8) Error!usize {
        const file = native.file orelse return error.HistoryReadFailed;
        return file.readPositionalAll(native.io, bytes, 0) catch error.HistoryReadFailed;
    }

    fn closeFile(native: *ReadNative) void {
        const file = native.file orelse unreachable;
        file.close(native.io);
        native.file = null;
    }

    fn closeDirectory(native: *ReadNative) void {
        std.debug.assert(native.file == null);
        const directory = native.directory orelse unreachable;
        directory.close(native.io);
        native.directory = null;
    }
};

fn statValue(stat: std.Io.File.Stat) ReadStat {
    return .{
        .kind = stat.kind,
        .mode = @intCast(stat.permissions.toMode() & 0o777),
        .size = stat.size,
    };
}

/// Reads and prunes retained records without creating or changing filesystem state.
///
/// std.Io follows path and file symlinks here. Privacy and regular-file checks
/// apply to the opened targets, avoiding a separate path-stat race.
pub fn inspect(
    allocator: std.mem.Allocator,
    io: std.Io,
    state_home: ?[]const u8,
    home: ?[]const u8,
) Error!History {
    const path = try directoryPath(allocator, state_home, home);
    defer allocator.free(path);
    var native = ReadNative{ .io = io, .path = path };
    const bytes = try readRetained(&native, allocator) orelse return .{};
    defer allocator.free(bytes);
    std.debug.assert(native.directory == null);
    std.debug.assert(native.file == null);
    return parse(allocator, bytes, try unixSeconds(io));
}

/// Owner keeps retained memory and its canonical file synchronized in the DBus worker.
const Durability = struct {
    dirty: bool = false,
    failure: ?Error = null,

    fn mark(durability: *Durability) void {
        durability.dirty = true;
    }

    fn begin(durability: *Durability) !bool {
        if (durability.failure) |err| return err;
        return durability.dirty;
    }

    fn succeeded(durability: *Durability) void {
        std.debug.assert(durability.dirty);
        std.debug.assert(durability.failure == null);
        durability.dirty = false;
    }

    fn failed(durability: *Durability, err: Error) void {
        std.debug.assert(durability.dirty);
        std.debug.assert(durability.failure == null);
        durability.failure = err;
    }
};

pub const Owner = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    history: History,
    native: Native,
    durability: Durability = .{},
    last_id: u32 = 0,
    next_generation: Generation = 1,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
    ) Error!Owner {
        return initAt(allocator, io, state_home, home, try unixSeconds(io));
    }

    fn initAt(
        allocator: std.mem.Allocator,
        io: std.Io,
        state_home: ?[]const u8,
        home: ?[]const u8,
        now: i64,
    ) Error!Owner {
        var native = try Native.init(allocator, io, state_home, home);
        errdefer native.deinit();
        var history = try load(&native, allocator, now);
        errdefer history.deinit(allocator);
        return .{
            .allocator = allocator,
            .io = io,
            .history = history,
            .native = native,
            .durability = .{ .dirty = true },
        };
    }

    pub fn deinit(owner: *Owner) void {
        owner.history.deinit(owner.allocator);
        owner.native.deinit();
        owner.* = undefined;
    }

    fn flush(owner: *Owner) Error!void {
        if (!try owner.durability.begin()) return;
        const bytes = encode(owner.allocator, &owner.history) catch |err| {
            owner.durability.failed(err);
            return err;
        };
        defer owner.allocator.free(bytes);
        persist(&owner.native, bytes) catch |err| {
            owner.durability.failed(err);
            return err;
        };
        owner.durability.succeeded();
    }

    fn accept(owner: *Owner, request: Request) Error!Accepted {
        return owner.acceptAt(request, try unixSeconds(owner.io));
    }

    fn acceptAt(owner: *Owner, request: Request, now: i64) Error!Accepted {
        try validateRequest(request);
        const current = owner.history.active;
        const replaces = request.replaces_id != 0 and current != null and
            request.replaces_id == current.?.notification_id;
        const id = if (replaces) request.replaces_id else try owner.nextId();
        const generation = owner.next_generation;
        if (generation == std.math.maxInt(Generation)) return error.GenerationExhausted;
        var value = try Notification.init(owner.allocator, .{ .id = id, .generation = generation }, request);
        defer value.deinit(owner.allocator);
        var presentation = try Presentation.init(owner.allocator, &value);
        errdefer presentation.deinit(owner.allocator);
        try owner.history.accepted(owner.allocator, now, &value, replaces);
        owner.durability.mark();
        owner.next_generation += 1;
        if (!replaces) owner.last_id = id;
        return .{
            .presentation = presentation,
            .displaced = if (!replaces and current != null) .{
                .id = current.?.notification_id,
                .generation = current.?.generation,
            } else null,
        };
    }

    fn nextId(owner: *Owner) Error!u32 {
        const active_id = if (owner.history.active) |active| active.notification_id else 0;
        var id = owner.last_id;
        for (0..2) |_| {
            id +%= 1;
            if (id == 0) id = 1;
            if (id != active_id) return id;
        }
        return error.IdExhausted;
    }

    fn close(owner: *Owner, key: Key) bool {
        const active = owner.history.active orelse return false;
        if (active.notification_id != key.id or active.generation != key.generation) return false;
        owner.history.closed(key);
        owner.durability.mark();
        return true;
    }
};

const Accepted = struct {
    presentation: Presentation,
    displaced: ?Key,
};

fn testOwner(allocator: std.mem.Allocator) Owner {
    return .{
        .allocator = allocator,
        .io = std.testing.io,
        .history = .{},
        .native = undefined,
    };
}

test "one active identity replaces in place and a new identity displaces once" {
    var owner = testOwner(std.testing.allocator);
    defer owner.history.deinit(std.testing.allocator);
    var first = try owner.acceptAt(sampleRequestValue(0, "first"), 1);
    defer first.presentation.deinit(std.testing.allocator);
    try std.testing.expect(owner.durability.dirty);
    try std.testing.expectEqual(@as(u32, 1), first.presentation.id);
    try std.testing.expectEqual(@as(Generation, 1), first.presentation.generation);
    try std.testing.expectEqual(@as(?Key, null), first.displaced);

    owner.durability.dirty = false;
    var replacement = try owner.acceptAt(sampleRequestValue(1, "replacement"), 2);
    defer replacement.presentation.deinit(std.testing.allocator);
    try std.testing.expect(owner.durability.dirty);
    try std.testing.expectEqual(@as(u32, 1), replacement.presentation.id);
    try std.testing.expectEqual(@as(Generation, 2), replacement.presentation.generation);
    try std.testing.expectEqual(@as(?Key, null), replacement.displaced);
    try std.testing.expectEqual(@as(usize, 1), owner.history.count);

    var newest = try owner.acceptAt(sampleRequestValue(0, "newest"), 3);
    defer newest.presentation.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 2), newest.presentation.id);
    try std.testing.expectEqual(Key{ .id = 1, .generation = 2 }, newest.displaced.?);
    try std.testing.expectEqual(@as(u32, 2), owner.history.active.?.notification_id);
}

test "stale replacement generation cannot close the current same id" {
    var owner = testOwner(std.testing.allocator);
    defer owner.history.deinit(std.testing.allocator);
    var first = try owner.acceptAt(sampleRequestValue(0, "first"), 1);
    defer first.presentation.deinit(std.testing.allocator);
    var replacement = try owner.acceptAt(sampleRequestValue(1, "replacement"), 2);
    defer replacement.presentation.deinit(std.testing.allocator);
    owner.durability.dirty = false;
    try std.testing.expect(!owner.close(.{ .id = 1, .generation = first.presentation.generation }));
    try std.testing.expect(!owner.durability.dirty);
    try std.testing.expectEqual(replacement.presentation.generation, owner.history.active.?.generation);
    try std.testing.expect(owner.close(.{ .id = 1, .generation = replacement.presentation.generation }));
    try std.testing.expect(owner.durability.dirty);
    try std.testing.expect(owner.history.active == null);
}

test "generation never wraps and exhaustion changes no state" {
    var owner = testOwner(std.testing.allocator);
    defer owner.history.deinit(std.testing.allocator);
    owner.next_generation = std.math.maxInt(Generation) - 1;
    var last = try owner.acceptAt(sampleRequestValue(0, "last"), 1);
    defer last.presentation.deinit(std.testing.allocator);
    try std.testing.expectEqual(std.math.maxInt(Generation) - 1, last.presentation.generation);
    const count = owner.history.count;
    try std.testing.expectError(
        error.GenerationExhausted,
        owner.acceptAt(sampleRequestValue(last.presentation.id, "rejected"), 2),
    );
    try std.testing.expectEqual(count, owner.history.count);
    try std.testing.expectEqual(last.presentation.generation, owner.history.active.?.generation);
}

const UiOperation = union(enum) {
    decision: std.meta.Tag(UiDecision),
    acquire: UiResource,
    release: UiResource,
    draw: Key,
    wait: i32,
    closed: Closed,
    failure: anyerror,
};

const UiTranscript = struct {
    expected: []const UiOperation,
    index: usize = 0,

    fn observe(transcript: *UiTranscript, actual: UiOperation) !void {
        if (transcript.index == transcript.expected.len) return error.ExtraOperation;
        if (!std.meta.eql(transcript.expected[transcript.index], actual)) return error.UnexpectedOperation;
        transcript.index += 1;
    }

    fn done(transcript: *const UiTranscript) !void {
        if (transcript.index != transcript.expected.len) return error.MissingOperation;
    }
};

fn uiDecisionTag(decision: UiDecision) std.meta.Tag(UiDecision) {
    return std.meta.activeTag(decision);
}

test "strict UI transcript follows newest draw deadline close and cleanup policy" {
    const one = Key{ .id = 1, .generation = 1 };
    const two = Key{ .id = 1, .generation = 2 };
    const three = Key{ .id = 2, .generation = 3 };
    var transcript = UiTranscript{ .expected = &.{
        .{ .decision = .none },
        .{ .decision = .initialize },
        .{ .acquire = .sdl },
        .{ .acquire = .ttf },
        .{ .acquire = .window },
        .{ .acquire = .renderer },
        .{ .acquire = .stream },
        .{ .acquire = .font },
        .{ .acquire = .engine },
        .{ .acquire = .summary },
        .{ .acquire = .body },
        .{ .decision = .none },
        .{ .draw = two },
        .{ .wait = 100 },
        .{ .decision = .draw },
        .{ .draw = three },
        .{ .wait = 200 },
        .{ .closed = .{ .key = three, .reason = .expired } },
        .{ .release = .body },
        .{ .release = .summary },
        .{ .release = .engine },
        .{ .release = .font },
        .{ .release = .stream },
        .{ .release = .renderer },
        .{ .release = .window },
        .{ .release = .ttf },
        .{ .release = .sdl },
        .{ .decision = .stop },
        .{ .decision = .failed },
        .{ .failure = error.SdlDeviceLost },
        .{ .decision = .initialize },
        .{ .draw = one },
        .{ .closed = .{ .key = one, .reason = .dismissed } },
        .{ .decision = .initialize },
        .{ .draw = one },
        .{ .decision = .hide },
    } };
    var state: UiState = .{};
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&state, .{ .hidden = one })) });
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&state, .{ .shown = one })) });
    var resources: UiResources = .{};
    inline for (std.meta.tags(UiResource)) |resource| {
        resources.acquired(resource);
        try transcript.observe(.{ .acquire = resource });
    }
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&state, .{ .shown = two })) });
    try std.testing.expectEqual(UiAction.draw, state.drawn(10, 100));
    try transcript.observe(.{ .draw = state.key.? });
    try transcript.observe(.{ .wait = state.remaining(10) });
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&state, .{ .shown = three })) });
    try std.testing.expectEqual(UiAction.draw, state.drawn(20, 200));
    try transcript.observe(.{ .draw = state.key.? });
    try transcript.observe(.{ .wait = state.remaining(20) });
    try transcript.observe(.{ .closed = state.close(.expired).? });
    try std.testing.expect(state.close(.dismissed) == null);
    while (resources.release()) |resource| try transcript.observe(.{ .release = resource });
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&state, .stop)) });
    const failure = decideUi(&state, .{ .failed = error.SdlDeviceLost });
    try transcript.observe(.{ .decision = uiDecisionTag(failure) });
    try transcript.observe(.{ .failure = failure.failed });
    var dismissed: UiState = .{};
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&dismissed, .{ .shown = one })) });
    try std.testing.expectEqual(UiAction.draw, dismissed.drawn(0, 100));
    try transcript.observe(.{ .draw = dismissed.key.? });
    try transcript.observe(.{ .closed = dismissed.close(.dismissed).? });
    try std.testing.expect(dismissed.close(.dismissed) == null);
    var hidden: UiState = .{};
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&hidden, .{ .shown = one })) });
    try std.testing.expectEqual(UiAction.draw, hidden.drawn(0, 100));
    try transcript.observe(.{ .draw = hidden.key.? });
    try transcript.observe(.{ .decision = uiDecisionTag(decideUi(&hidden, .{ .hidden = one })) });
    try transcript.done();
}

test "strict UI cleanup transcript reverses every partial acquisition" {
    const resources = std.meta.tags(UiResource);
    for (0..resources.len + 1) |acquired| {
        var expected: [resources.len * 2]UiOperation = undefined;
        var count: usize = 0;
        for (resources[0..acquired]) |resource| {
            expected[count] = .{ .acquire = resource };
            count += 1;
        }
        var remaining = acquired;
        while (remaining > 0) {
            remaining -= 1;
            expected[count] = .{ .release = resources[remaining] };
            count += 1;
        }
        var transcript = UiTranscript{ .expected = expected[0..count] };
        var owned: UiResources = .{};
        for (resources[0..acquired]) |resource| {
            owned.acquired(resource);
            try transcript.observe(.{ .acquire = resource });
        }
        while (owned.release()) |resource| try transcript.observe(.{ .release = resource });
        try transcript.done();
    }
}

test "strict UI transcript cleans every resource after draw and wait failures" {
    const resources = std.meta.tags(UiResource);
    inline for (.{ error.SdlDrawFailed, error.SdlDeviceLost }) |failure| {
        var expected: [resources.len * 2 + 1]UiOperation = undefined;
        var count: usize = 0;
        for (resources) |resource| {
            expected[count] = .{ .acquire = resource };
            count += 1;
        }
        expected[count] = .{ .failure = failure };
        count += 1;
        var remaining = resources.len;
        while (remaining > 0) {
            remaining -= 1;
            expected[count] = .{ .release = resources[remaining] };
            count += 1;
        }
        var transcript = UiTranscript{ .expected = expected[0..count] };
        var owned: UiResources = .{};
        for (resources) |resource| {
            owned.acquired(resource);
            try transcript.observe(.{ .acquire = resource });
        }
        try transcript.observe(.{ .failure = failure });
        while (owned.release()) |resource| try transcript.observe(.{ .release = resource });
        try transcript.done();
    }
}

test "strict UI transcript rejects unexpected missing and extra operations" {
    var unexpected = UiTranscript{ .expected = &.{.{ .decision = .draw }} };
    try std.testing.expectError(error.UnexpectedOperation, unexpected.observe(.{ .decision = .hide }));
    var missing = UiTranscript{ .expected = &.{.{ .decision = .draw }} };
    try std.testing.expectError(error.MissingOperation, missing.done());
    var extra = UiTranscript{ .expected = &.{} };
    try std.testing.expectError(error.ExtraOperation, extra.observe(.{ .decision = .draw }));
}

test "accept allocation failures publish no partial identity or history" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, acceptAllocationFailure, .{});
}

fn acceptAllocationFailure(allocator: std.mem.Allocator) !void {
    var owner = testOwner(allocator);
    defer owner.history.deinit(allocator);
    var accepted = owner.acceptAt(sampleRequestValue(0, "complete"), 1) catch |err| {
        try std.testing.expectEqual(@as(usize, 0), owner.history.count);
        try std.testing.expect(owner.history.active == null);
        try std.testing.expect(!owner.durability.dirty);
        return err;
    };
    defer accepted.presentation.deinit(allocator);
}

test "mailbox keeps only newest before init during init and while visible" {
    var mailbox = Mailbox.init(std.testing.io, std.testing.allocator);
    defer mailbox.deinit();
    var one = try sampleNotification(std.testing.allocator, 1, "one");
    defer one.deinit(std.testing.allocator);
    var two = try sampleNotification(std.testing.allocator, 2, "two");
    defer two.deinit(std.testing.allocator);
    var three = try sampleNotification(std.testing.allocator, 3, "three");
    defer three.deinit(std.testing.allocator);

    try mailbox.publish(try Presentation.init(std.testing.allocator, &one));
    try mailbox.publish(try Presentation.init(std.testing.allocator, &two));
    var before = switch ((try mailbox.waitDesired()).?) {
        .shown => |value| value,
        .hidden => return error.ExpectedPresentation,
    };
    defer before.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 2), before.id);

    try mailbox.publish(try Presentation.init(std.testing.allocator, &two));
    try mailbox.publish(try Presentation.init(std.testing.allocator, &three));
    var during = switch (mailbox.takeUiUpdate()) {
        .desired => |desired| switch (desired) {
            .shown => |value| value,
            .hidden => return error.ExpectedPresentation,
        },
        else => return error.ExpectedPresentation,
    };
    defer during.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 3), during.id);

    try mailbox.hide(.{ .id = 2, .generation = 2 });
    const hidden = mailbox.takeUiUpdate().desired.hidden;
    try std.testing.expectEqual(@as(u32, 2), hidden.id);
    mailbox.reportClosed(.{ .key = .{ .id = 3, .generation = 3 }, .reason = .dismissed });
    try std.testing.expectEqual(@as(u32, 3), mailbox.takeClosed().?.key.id);
}

test "latest desired state converges show close show and close show close" {
    var mailbox = Mailbox.init(std.testing.io, std.testing.allocator);
    defer mailbox.deinit();
    var one = try sampleNotification(std.testing.allocator, 1, "one");
    defer one.deinit(std.testing.allocator);
    var two = try sampleNotification(std.testing.allocator, 2, "two");
    defer two.deinit(std.testing.allocator);
    const one_key = Key{ .id = one.id, .generation = one.generation };
    const two_key = Key{ .id = two.id, .generation = two.generation };

    try mailbox.publish(try Presentation.init(std.testing.allocator, &one));
    try mailbox.hide(one_key);
    try mailbox.publish(try Presentation.init(std.testing.allocator, &two));
    var shown = switch (mailbox.takeUiUpdate().desired) {
        .shown => |value| value,
        .hidden => return error.ExpectedPresentation,
    };
    defer shown.deinit(std.testing.allocator);
    try std.testing.expectEqual(two_key, Key{ .id = shown.id, .generation = shown.generation });

    try mailbox.hide(two_key);
    try mailbox.publish(try Presentation.init(std.testing.allocator, &one));
    try mailbox.hide(one_key);
    try std.testing.expectEqual(one_key, mailbox.takeUiUpdate().desired.hidden);
}

test "mailbox returns exact worker and UI failures" {
    var mailbox = Mailbox.init(std.testing.io, std.testing.allocator);
    defer mailbox.deinit();
    mailbox.workerDone(error.BusLost);
    try std.testing.expectError(error.BusLost, mailbox.waitDesired());
    mailbox.uiFailed(error.SdlDrawFailed);
    try std.testing.expectEqual(error.SdlDrawFailed, mailbox.uiFailure().?);
}

test "failed SDL wake keeps the latest desired presentation" {
    var mailbox = Mailbox.init(std.testing.io, std.testing.allocator);
    defer mailbox.deinit();
    mailbox.ui_ready = true;
    var value = try sampleNotification(std.testing.allocator, 1, "owned");
    defer value.deinit(std.testing.allocator);
    try std.testing.expectError(
        error.SdlWakeFailed,
        mailbox.publish(try Presentation.init(std.testing.allocator, &value)),
    );
    try std.testing.expectEqualStrings("owned", mailbox.desired.?.shown.summary);
}

test "presentation timeout has exact default persistent and maximum bounds" {
    var value = try sampleNotification(std.testing.allocator, 1, "timeout");
    defer value.deinit(std.testing.allocator);
    inline for (.{
        .{ -1, timeout_default_ms },
        .{ 0, timeout_max_ms },
        .{ 1, 1 },
        .{ 60_000, timeout_max_ms },
        .{ std.math.maxInt(i32), timeout_max_ms },
    }) |case| {
        value.expire_timeout = case[0];
        var presentation = try Presentation.init(std.testing.allocator, &value);
        defer presentation.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(u32, case[1]), presentation.timeout_ms);
    }
}

test "request fields accept exact bounds and reject one extra atomically" {
    var app_name: [app_name_capacity]u8 = @splat('a');
    var app_icon: [app_icon_capacity]u8 = @splat('i');
    var summary: [summary_capacity]u8 = @splat('s');
    var body: [body_capacity]u8 = @splat('b');
    try validateRequest(.{
        .replaces_id = 0,
        .app_name = &app_name,
        .app_icon = &app_icon,
        .summary = &summary,
        .body = &body,
        .expire_timeout = -1,
    });
    var too_long: [summary_capacity + 1]u8 = @splat('x');
    try std.testing.expectError(
        error.FieldTooLong,
        validateRequest(sampleRequestValue(0, &too_long)),
    );
    try std.testing.expectError(
        error.InvalidUtf8,
        validateRequest(sampleRequestValue(0, &.{0xff})),
    );
}

test "generated intake histories preserve one active and one desired value" {
    if (builtin.fuzz) try std.testing.fuzz({}, fuzzIntake, .{});
    var empty = std.testing.Smith{ .in = "" };
    try fuzzIntake({}, &empty);
}

fn fuzzIntake(_: void, smith: *std.testing.Smith) !void {
    var owner = testOwner(std.testing.allocator);
    defer owner.history.deinit(std.testing.allocator);
    var mailbox = Mailbox.init(std.testing.io, std.testing.allocator);
    defer mailbox.deinit();
    var text: [128]u8 = undefined;
    for (0..256) |_| {
        if (smith.eosWeightedSimple(1, 7)) break;
        switch (smith.valueRangeLessThan(u8, 0, 3)) {
            0 => {
                const active_id = if (owner.history.active) |active| active.notification_id else 0;
                const replaces_id = if (smith.value(bool)) active_id else smith.value(u32);
                var accepted = owner.acceptAt(
                    sampleRequestValue(replaces_id, text[0..smith.slice(&text)]),
                    @as(i64, smith.value(u32)),
                ) catch continue;
                try mailbox.publish(accepted.presentation);
                accepted = undefined;
            },
            1 => {
                if (owner.history.active) |active| owner.history.closed(.{
                    .id = active.notification_id,
                    .generation = active.generation,
                });
            },
            2 => switch (mailbox.takeUiUpdate()) {
                .desired => |value| {
                    var owned = value;
                    owned.deinit(std.testing.allocator);
                },
                else => {},
            },
            else => unreachable,
        }
        owner.history.assertValid();
        try std.testing.expect(@intFromBool(owner.history.active != null) <= 1);
        try std.testing.expect(@intFromBool(mailbox.desired != null) <= 1);
    }
}

fn sampleRequestValue(replaces_id: u32, summary: []const u8) Request {
    return .{
        .replaces_id = replaces_id,
        .app_name = "app",
        .app_icon = "",
        .summary = summary,
        .body = "body",
        .expire_timeout = -1,
    };
}

fn unixSeconds(io: std.Io) Error!i64 {
    const nanoseconds = std.Io.Clock.real.now(io).nanoseconds;
    if (nanoseconds < 0) return error.ClockInvalid;
    const seconds = @divFloor(nanoseconds, std.time.ns_per_s);
    if (seconds > std.math.maxInt(i64)) return error.ClockInvalid;
    return @intCast(seconds);
}

fn sampleNotification(
    allocator: std.mem.Allocator,
    id: u32,
    summary: []const u8,
) !Notification {
    return Notification.init(allocator, .{ .id = id, .generation = id }, .{
        .replaces_id = 0,
        .app_name = "app",
        .app_icon = "",
        .summary = summary,
        .body = "body",
        .expire_timeout = -1,
    });
}

test "new records replace active identity and close ends replacement identity" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleNotification(std.testing.allocator, 7, "first");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 100, &first, false);
    try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
    var replacement = try sampleNotification(std.testing.allocator, 7, "replacement");
    defer replacement.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 200, &replacement, true);
    try std.testing.expectEqual(@as(usize, 1), history.count);
    try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
    try std.testing.expectEqualStrings("replacement", history.records[0].?.summary);
    history.closed(.{ .id = 7, .generation = replacement.generation });
    try history.accepted(std.testing.allocator, 300, &replacement, true);
    try std.testing.expectEqual(@as(u64, 2), history.records[1].?.history_id);
}

test "age is strict and JSONL round trips escaped private text" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleNotification(std.testing.allocator, 1, "quote \" slash \\\\");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 10, &first, false);
    const bytes = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    var retained = try parse(std.testing.allocator, bytes, 10 + retention_seconds);
    defer retained.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), retained.count);
    var pruned = try parse(std.testing.allocator, bytes, 11 + retention_seconds);
    defer pruned.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), pruned.count);
}

test "public JSONL is complete newest first and excludes retained identity" {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var first = try sampleNotification(std.testing.allocator, 1, "first\nline");
    defer first.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 10, &first, false);
    var second = try sampleNotification(std.testing.allocator, 2, "quote \" and $HOME");
    defer second.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 20, &second, false);
    const bytes = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings(
        "{\"app_name\":\"app\",\"summary\":\"quote \\\" and $HOME\",\"body\":\"body\"}\n" ++
            "{\"app_name\":\"app\",\"summary\":\"first\\nline\",\"body\":\"body\"}\n",
        bytes,
    );
    try std.testing.expect(std.mem.indexOf(u8, bytes, "history_id") == null);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "received_unix_seconds") == null);
}

test "empty public history is empty output" {
    const history: History = .{};
    const bytes = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "corrupt incomplete oversized and duplicate input publishes no history" {
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, "{}", 0));
    var oversized: [line_capacity + 1]u8 = @splat('x');
    oversized[oversized.len - 1] = '\n';
    try std.testing.expectError(error.LineTooLong, parse(std.testing.allocator, &oversized, 0));
    const line =
        \\{"received_unix_seconds":1,"history_id":1,"app_name":"a","summary":"s","body":"b"}
    ;
    const duplicate = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}\n", .{ line, line });
    defer std.testing.allocator.free(duplicate);
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, duplicate, 0));
}

test "greatest retained id allocates next and max never wraps" {
    const last_line =
        \\{"received_unix_seconds":1,"history_id":18446744073709551614,"app_name":"a","summary":"s","body":"b"}
        \\
    ;
    var last = try parse(std.testing.allocator, last_line, 1);
    defer last.deinit(std.testing.allocator);
    try std.testing.expectEqual(std.math.maxInt(u64), last.next_history_id);
    const max_line =
        \\{"received_unix_seconds":1,"history_id":18446744073709551615,"app_name":"a","summary":"s","body":"b"}
        \\
    ;
    try std.testing.expectError(error.HistoryIdExhausted, parse(std.testing.allocator, max_line, 1));
}

test "max minus one is last assignable id and reserved max fails atomically" {
    var history: History = .{ .next_history_id = std.math.maxInt(u64) - 1 };
    defer history.deinit(std.testing.allocator);
    var last = try sampleNotification(std.testing.allocator, 1, "last");
    defer last.deinit(std.testing.allocator);
    try history.accepted(std.testing.allocator, 1, &last, false);
    try std.testing.expectEqual(std.math.maxInt(u64) - 1, history.records[0].?.history_id);
    try std.testing.expectEqual(std.math.maxInt(u64), history.next_history_id);

    const count = history.count;
    const active = history.active;
    const file_bytes = history.file_bytes;
    var rejected = try sampleNotification(std.testing.allocator, 2, "rejected");
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expectError(
        error.HistoryIdExhausted,
        history.accepted(std.testing.allocator, 2, &rejected, false),
    );
    try std.testing.expectEqual(count, history.count);
    try std.testing.expectEqual(active, history.active);
    try std.testing.expectEqual(file_bytes, history.file_bytes);
    try std.testing.expectEqual(std.math.maxInt(u64), history.next_history_id);
    for (history.records[0..history.count]) |slot| {
        try std.testing.expect(slot.?.history_id != std.math.maxInt(u64));
    }
    const encoded = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(
        u8,
        encoded,
        "\"history_id\":18446744073709551615",
    ) == null);
}

test "state path uses absolute XDG state then absolute HOME fallback" {
    const xdg = try directoryPath(std.testing.allocator, "/state", "/home/user");
    defer std.testing.allocator.free(xdg);
    try std.testing.expectEqualStrings("/state/wayspot", xdg);
    const fallback = try directoryPath(std.testing.allocator, "", "/home/user");
    defer std.testing.allocator.free(fallback);
    try std.testing.expectEqualStrings("/home/user/.local/state/wayspot", fallback);
    const relative = try directoryPath(std.testing.allocator, "relative", "/home/user");
    defer std.testing.allocator.free(relative);
    try std.testing.expectEqualStrings("/home/user/.local/state/wayspot", relative);
    try std.testing.expectError(error.PathMissing, directoryPath(std.testing.allocator, null, null));
}

test "count and byte bounds remove oldest complete records" {
    var count_history: History = .{};
    defer count_history.deinit(std.testing.allocator);
    for (1..record_capacity + 2) |id| {
        if (count_history.count == record_capacity) {
            count_history.removeRecord(std.testing.allocator, 0);
        }
        count_history.append(try Record.init(
            std.testing.allocator,
            @intCast(id),
            @intCast(id),
            "app",
            "summary",
            "body",
        ));
    }
    count_history.assertValid();
    try std.testing.expectEqual(@as(usize, record_capacity), count_history.count);
    try std.testing.expectEqual(@as(u64, 2), count_history.records[0].?.history_id);

    var body: [body_capacity]u8 = @splat('b');
    var byte_history: History = .{};
    defer byte_history.deinit(std.testing.allocator);
    for (1..record_capacity + 1) |id| {
        byte_history.append(try Record.init(
            std.testing.allocator,
            @intCast(id),
            @intCast(id),
            "app",
            "summary",
            &body,
        ));
        byte_history.prune(std.testing.allocator, @intCast(id));
    }
    byte_history.assertValid();
    try std.testing.expect(byte_history.file_bytes <= file_capacity);
    try std.testing.expect(byte_history.records[0].?.history_id > 1);
}

test "replacement allocation failure preserves the prior complete record" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, replaceAllocationFailure, .{});
}

fn replaceAllocationFailure(allocator: std.mem.Allocator) !void {
    var history: History = .{};
    defer history.deinit(allocator);
    var first = try sampleNotification(allocator, 1, "first");
    defer first.deinit(allocator);
    try history.accepted(allocator, 1, &first, false);
    var replacement = try sampleNotification(allocator, 1, "replacement");
    defer replacement.deinit(allocator);
    history.accepted(allocator, 2, &replacement, true) catch |err| {
        try std.testing.expectEqualStrings("first", history.records[0].?.summary);
        try std.testing.expectEqual(@as(u64, 1), history.records[0].?.history_id);
        return err;
    };
}

const OpenRead = enum { opened, missing, failed };
const StatRead = union(enum) { value: ReadStat, failed };
const BytesRead = union(enum) {
    complete: []const u8,
    short: usize,
    failed,
};

const ReadStep = union(enum) {
    open_directory: OpenRead,
    stat_directory: StatRead,
    open_file: OpenRead,
    stat_file: StatRead,
    read: BytesRead,
    close_file,
    close_directory,
};

const HistoryReadTranscript = struct {
    steps: []const ReadStep,
    index: usize = 0,
    directory_open: bool = false,
    file_open: bool = false,

    fn openDirectory(transcript: *HistoryReadTranscript) Error!bool {
        const result = switch (try transcript.next()) {
            .open_directory => |value| value,
            else => return error.HistoryOpenFailed,
        };
        return switch (result) {
            .opened => blk: {
                transcript.directory_open = true;
                break :blk true;
            },
            .missing => false,
            .failed => error.HistoryOpenFailed,
        };
    }

    fn statDirectory(transcript: *HistoryReadTranscript) Error!ReadStat {
        std.debug.assert(transcript.directory_open);
        return switch (try transcript.next()) {
            .stat_directory => |result| switch (result) {
                .value => |value| value,
                .failed => error.HistoryOpenFailed,
            },
            else => error.HistoryOpenFailed,
        };
    }

    fn openFile(transcript: *HistoryReadTranscript) Error!bool {
        std.debug.assert(transcript.directory_open);
        const result = switch (try transcript.next()) {
            .open_file => |value| value,
            else => return error.HistoryOpenFailed,
        };
        return switch (result) {
            .opened => blk: {
                transcript.file_open = true;
                break :blk true;
            },
            .missing => false,
            .failed => error.HistoryOpenFailed,
        };
    }

    fn statFile(transcript: *HistoryReadTranscript) Error!ReadStat {
        std.debug.assert(transcript.file_open);
        return switch (try transcript.next()) {
            .stat_file => |result| switch (result) {
                .value => |value| value,
                .failed => error.HistoryReadFailed,
            },
            else => error.HistoryReadFailed,
        };
    }

    fn read(transcript: *HistoryReadTranscript, bytes: []u8) Error!usize {
        std.debug.assert(transcript.file_open);
        return switch (try transcript.next()) {
            .read => |result| switch (result) {
                .complete => |source| blk: {
                    if (source.len != bytes.len) return error.HistoryReadFailed;
                    @memcpy(bytes, source);
                    break :blk bytes.len;
                },
                .short => |count| blk: {
                    if (count >= bytes.len) return error.HistoryReadFailed;
                    @memset(bytes[0..count], 0);
                    break :blk count;
                },
                .failed => error.HistoryReadFailed,
            },
            else => error.HistoryReadFailed,
        };
    }

    fn closeFile(transcript: *HistoryReadTranscript) void {
        std.debug.assert(transcript.file_open);
        const step = transcript.next() catch unreachable;
        std.debug.assert(step == .close_file);
        transcript.file_open = false;
    }

    fn closeDirectory(transcript: *HistoryReadTranscript) void {
        std.debug.assert(transcript.directory_open);
        std.debug.assert(!transcript.file_open);
        const step = transcript.next() catch unreachable;
        std.debug.assert(step == .close_directory);
        transcript.directory_open = false;
    }

    fn done(transcript: *const HistoryReadTranscript) !void {
        try std.testing.expectEqual(transcript.steps.len, transcript.index);
        try std.testing.expect(!transcript.directory_open);
        try std.testing.expect(!transcript.file_open);
    }

    fn next(transcript: *HistoryReadTranscript) Error!ReadStep {
        if (transcript.index == transcript.steps.len) return error.HistoryReadFailed;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

const private_directory = ReadStat{ .kind = .directory, .mode = 0o700, .size = 0 };

fn privateFile(size: u64) ReadStat {
    return .{ .kind = .file, .mode = 0o600, .size = size };
}

fn expectReadFailure(expected: Error, steps: []const ReadStep) !void {
    var transcript = HistoryReadTranscript{ .steps = steps };
    try std.testing.expectError(expected, readRetained(&transcript, std.testing.allocator));
    try transcript.done();
}

test "history read transcript opens stats reads and closes in exact order" {
    const line =
        \\{"received_unix_seconds":1,"history_id":1,"app_name":"app","summary":"summary","body":"body"}
        \\
    ;
    var transcript = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(line.len) } },
        .{ .read = .{ .complete = line } },
        .close_file,
        .close_directory,
    } };
    const bytes = (try readRetained(&transcript, std.testing.allocator)).?;
    defer std.testing.allocator.free(bytes);
    try transcript.done();
    var history = try parse(std.testing.allocator, bytes, 1);
    defer history.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), history.count);
}

test "missing history directory and file are empty success with exact cleanup" {
    var no_directory = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .missing },
    } };
    try std.testing.expectEqual(null, try readRetained(&no_directory, std.testing.allocator));
    try no_directory.done();

    var no_file = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .missing },
        .close_directory,
    } };
    try std.testing.expectEqual(null, try readRetained(&no_file, std.testing.allocator));
    try no_file.done();
}

test "history open stat kind and private-mode failures close exact handles" {
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .failed },
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .failed },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = .{ .kind = .file, .mode = 0o700, .size = 0 } } },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = .{ .kind = .directory, .mode = 0o755, .size = 0 } } },
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .failed },
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .failed },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = .{ .kind = .directory, .mode = 0o600, .size = 0 } } },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryOpenFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = .{ .kind = .file, .mode = 0o640, .size = 0 } } },
        .close_file,
        .close_directory,
    });
}

test "history size read short-read and malformed failures publish nothing" {
    try expectReadFailure(error.HistoryTooLarge, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(file_capacity + 1) } },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .{ .read = .failed },
        .close_file,
        .close_directory,
    });
    try expectReadFailure(error.HistoryReadFailed, &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .{ .read = .{ .short = 3 } },
        .close_file,
        .close_directory,
    });

    var malformed = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(2) } },
        .{ .read = .{ .complete = "{}" } },
        .close_file,
        .close_directory,
    } };
    const bytes = (try readRetained(&malformed, std.testing.allocator)).?;
    defer std.testing.allocator.free(bytes);
    try malformed.done();
    try std.testing.expectError(error.HistoryCorrupt, parse(std.testing.allocator, bytes, 1));
}

test "history read allocation failure closes file and directory" {
    var transcript = HistoryReadTranscript{ .steps = &.{
        .{ .open_directory = .opened },
        .{ .stat_directory = .{ .value = private_directory } },
        .{ .open_file = .opened },
        .{ .stat_file = .{ .value = privateFile(4) } },
        .close_file,
        .close_directory,
    } };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, readRetained(&transcript, failing.allocator()));
    try transcript.done();
}

const Step = union(enum) {
    begin: bool,
    write: struct { bytes: []const u8, ok: bool },
    sync_file: bool,
    adopt: bool,
    sync_parent: bool,
    abort: bool,
};

const Transcript = struct {
    steps: []const Step,
    index: usize = 0,
    canonical: []const u8 = "old\n",
    temporary: ?[]const u8 = null,

    fn begin(transcript: *Transcript) !void {
        if (!try transcript.boolean(.begin)) return error.BeginFailed;
        transcript.temporary = "";
    }

    fn write(transcript: *Transcript, bytes: []const u8) !void {
        const expected = switch (try transcript.next()) {
            .write => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (!std.mem.eql(u8, expected.bytes, bytes)) return error.TranscriptMismatch;
        if (!expected.ok) return error.WriteFailed;
        transcript.temporary = bytes;
    }

    fn syncFile(transcript: *Transcript) !void {
        if (!try transcript.boolean(.sync_file)) return error.SyncFailed;
    }

    fn adopt(transcript: *Transcript) !void {
        if (!try transcript.boolean(.adopt)) return error.AdoptFailed;
        transcript.canonical = transcript.temporary orelse return error.TranscriptMismatch;
        transcript.temporary = null;
    }

    fn syncParent(transcript: *Transcript) !void {
        if (!try transcript.boolean(.sync_parent)) return error.ParentSyncFailed;
    }

    fn abort(transcript: *Transcript) !void {
        const ok = switch (try transcript.next()) {
            .abort => |value| value,
            else => return error.TranscriptMismatch,
        };
        if (!ok) return error.AbortFailed;
        transcript.temporary = null;
    }

    fn boolean(transcript: *Transcript, tag: std.meta.Tag(Step)) !bool {
        const step = try transcript.next();
        if (std.meta.activeTag(step) != tag) return error.TranscriptMismatch;
        return switch (step) {
            .begin, .sync_file, .adopt, .sync_parent => |value| value,
            else => unreachable,
        };
    }

    fn next(transcript: *Transcript) !Step {
        if (transcript.index == transcript.steps.len) return error.TranscriptMismatch;
        defer transcript.index += 1;
        return transcript.steps[transcript.index];
    }
};

test "replacement transcript writes exact bytes and aborts every pre-adoption failure" {
    var success = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = true },
        .{ .sync_parent = true },
    } };
    try persist(&success, "complete\n");
    try std.testing.expectEqual(success.steps.len, success.index);
    try std.testing.expectEqualStrings("complete\n", success.canonical);

    var write_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = false } },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.WriteFailed, persist(&write_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", write_failed.canonical);

    var sync_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = false },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.SyncFailed, persist(&sync_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", sync_failed.canonical);

    var adopt_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = false },
        .{ .abort = true },
    } };
    try std.testing.expectError(error.AdoptFailed, persist(&adopt_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", adopt_failed.canonical);

    var cleanup_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = false } },
        .{ .abort = false },
    } };
    try std.testing.expectError(error.HistoryCleanupFailed, persist(&cleanup_failed, "complete\n"));
    try std.testing.expectEqualStrings("old\n", cleanup_failed.canonical);

    var parent_failed = Transcript{ .steps = &.{
        .{ .begin = true },
        .{ .write = .{ .bytes = "complete\n", .ok = true } },
        .{ .sync_file = true },
        .{ .adopt = true },
        .{ .sync_parent = false },
    } };
    try std.testing.expectError(error.ParentSyncFailed, persist(&parent_failed, "complete\n"));
    try std.testing.expectEqual(parent_failed.steps.len, parent_failed.index);
    try std.testing.expectEqualStrings("complete\n", parent_failed.canonical);
}

test "generated JSONL bytes and record histories remain bounded" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzHistory, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzHistory({}, &empty);
}

test "generated malformed JSONL publishes either one complete history or an exact error" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzBytes, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzBytes({}, &empty);
}

fn fuzzBytes(_: void, smith: *std.testing.Smith) !void {
    var bytes: [4096]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    var history = parse(std.testing.allocator, input, @as(i64, smith.value(u32))) catch |err| switch (err) {
        error.HistoryCorrupt, error.LineTooLong, error.HistoryIdExhausted => return,
        else => return err,
    };
    defer history.deinit(std.testing.allocator);
    history.assertValid();
}

fn fuzzHistory(_: void, smith: *std.testing.Smith) !void {
    var history: History = .{};
    defer history.deinit(std.testing.allocator);
    var bytes: [128]u8 = undefined;
    for (0..512) |_| {
        if (smith.eosWeightedSimple(1, 7)) break;
        const text = bytes[0..smith.slice(&bytes)];
        const id = @as(u32, smith.value(u8)) + 1;
        var source = sampleNotification(
            std.testing.allocator,
            id,
            text,
        ) catch continue;
        defer source.deinit(std.testing.allocator);
        history.accepted(
            std.testing.allocator,
            @as(i64, smith.value(u32)),
            &source,
            smith.value(bool),
        ) catch |err| switch (err) {
            error.HistoryCorrupt, error.LineTooLong => {},
            else => return err,
        };
        if (smith.value(bool)) history.closed(.{ .id = id, .generation = source.generation });
        history.assertValid();
    }
    const encoded = try encode(std.testing.allocator, &history);
    defer std.testing.allocator.free(encoded);
    const public = try format(std.testing.allocator, &history);
    defer std.testing.allocator.free(public);
    try std.testing.expect(public.len <= file_capacity);
    if (public.len > 0) try std.testing.expectEqual(@as(u8, '\n'), public[public.len - 1]);
    var parsed = try parse(std.testing.allocator, encoded, 0);
    defer parsed.deinit(std.testing.allocator);
}

const BatchAction = union(enum) { continue_intake, flush, flush_and_stop, fail: anyerror };

const NotifyOperation = enum { dirty, reply, publish, displaced, done };
const WorkerConnectionOperation = enum { open, own, close };

const WorkerConnection = struct {
    phase: enum { cold, open, owned, closed } = .cold,

    fn opened(connection: *WorkerConnection) WorkerConnectionOperation {
        std.debug.assert(connection.phase == .cold);
        connection.phase = .open;
        return .open;
    }

    fn owned(connection: *WorkerConnection) WorkerConnectionOperation {
        std.debug.assert(connection.phase == .open);
        connection.phase = .owned;
        return .own;
    }

    fn closed(connection: *WorkerConnection) WorkerConnectionOperation {
        std.debug.assert(connection.phase == .open or connection.phase == .owned);
        connection.phase = .closed;
        return .close;
    }
};

const WorkerFailureAction = enum { flush_once, return_error };

fn workerFailureAction(durability: *const Durability) WorkerFailureAction {
    return if (durability.failure == null) .flush_once else .return_error;
}

const NotifyOrder = struct {
    phase: NotifyOperation = .dirty,
    displaced: bool,

    fn marked(order: *NotifyOrder, dirty: bool) NotifyOperation {
        std.debug.assert(order.phase == .dirty);
        std.debug.assert(dirty);
        order.phase = .reply;
        return .dirty;
    }

    fn replied(order: *NotifyOrder) NotifyOperation {
        std.debug.assert(order.phase == .reply);
        order.phase = .publish;
        return .reply;
    }

    fn published(order: *NotifyOrder) NotifyOperation {
        std.debug.assert(order.phase == .publish);
        order.phase = if (order.displaced) .displaced else .done;
        return .publish;
    }

    fn signaled(order: *NotifyOrder) NotifyOperation {
        std.debug.assert(order.phase == .displaced);
        order.phase = .done;
        return .displaced;
    }

    fn finished(order: *const NotifyOrder) NotifyOperation {
        std.debug.assert(order.phase == .done);
        return .done;
    }
};

fn activeKey(active: ?Active, id: u32) ?Key {
    const value = active orelse return null;
    if (value.notification_id != id) return null;
    return .{ .id = id, .generation = value.generation };
}

fn currentClose(active: ?Active, closed: Closed) bool {
    const key = activeKey(active, closed.key.id) orelse return false;
    return std.meta.eql(key, closed.key);
}

const IntakeBatch = struct {
    count: u8 = 0,

    fn handled(batch: *IntakeBatch) BatchAction {
        std.debug.assert(batch.count < intake_batch_max);
        batch.count += 1;
        return if (batch.count == intake_batch_max) .flush else .continue_intake;
    }

    fn idle(_: *IntakeBatch) BatchAction {
        return .flush;
    }

    fn stop(_: *IntakeBatch) BatchAction {
        return .flush_and_stop;
    }

    fn external(_: *IntakeBatch, err: anyerror) BatchAction {
        return .{ .fail = err };
    }
};

const WorkerOperation = union(enum) {
    connection: WorkerConnectionOperation,
    notify: NotifyOperation,
    flush,
    reply_close,
    hide: Key,
    signal: Closed,
    stop,
    failure: anyerror,
};

const WorkerTranscript = struct {
    expected: []const WorkerOperation,
    index: usize = 0,

    fn observe(transcript: *WorkerTranscript, actual: WorkerOperation) !void {
        if (transcript.index == transcript.expected.len) return error.ExtraOperation;
        if (!std.meta.eql(transcript.expected[transcript.index], actual)) return error.UnexpectedOperation;
        transcript.index += 1;
    }

    fn done(transcript: *const WorkerTranscript) !void {
        if (transcript.index != transcript.expected.len) return error.MissingOperation;
    }
};

fn observeFlushes(transcript: *WorkerTranscript, method_count: usize, initially_dirty: bool) !void {
    var durability = Durability{ .dirty = initially_dirty };
    var batch: IntakeBatch = .{};
    for (0..method_count) |_| {
        durability.mark();
        if (batch.handled() == .flush) {
            if (try durability.begin()) {
                try transcript.observe(.flush);
                durability.succeeded();
            }
            batch = .{};
        }
    }
    std.debug.assert(batch.idle() == .flush);
    if (try durability.begin()) {
        try transcript.observe(.flush);
        durability.succeeded();
    }
}

test "strict worker transcript enforces connection notify close stop and cleanup order" {
    const old = Key{ .id = 7, .generation = 10 };
    const current = Key{ .id = 8, .generation = 11 };
    var transcript = WorkerTranscript{ .expected = &.{
        .{ .connection = .open },
        .{ .connection = .own },
        .{ .notify = .dirty },
        .{ .notify = .reply },
        .{ .notify = .publish },
        .{ .notify = .displaced },
        .{ .notify = .done },
        .reply_close,
        .{ .hide = current },
        .{ .signal = .{ .key = current, .reason = .requested } },
        .reply_close,
        .{ .signal = .{ .key = current, .reason = .dismissed } },
        .flush,
        .stop,
        .{ .connection = .close },
    } };
    var connection: WorkerConnection = .{};
    try transcript.observe(.{ .connection = connection.opened() });
    try transcript.observe(.{ .connection = connection.owned() });
    var order = NotifyOrder{ .displaced = true };
    try transcript.observe(.{ .notify = order.marked(true) });
    try transcript.observe(.{ .notify = order.replied() });
    try transcript.observe(.{ .notify = order.published() });
    try transcript.observe(.{ .notify = order.signaled() });
    try transcript.observe(.{ .notify = order.finished() });
    var owner = testOwner(std.testing.allocator);
    defer owner.history.deinit(std.testing.allocator);
    owner.history.active = .{
        .notification_id = current.id,
        .generation = current.generation,
        .history_id = 1,
    };
    try std.testing.expect(activeKey(owner.history.active, old.id) == null);
    try transcript.observe(.reply_close);
    const key = activeKey(owner.history.active, current.id).?;
    try std.testing.expect(owner.close(key));
    try std.testing.expect(owner.durability.dirty);
    try transcript.observe(.{ .hide = key });
    try transcript.observe(.{ .signal = .{ .key = key, .reason = .requested } });
    try transcript.observe(.reply_close);
    owner.history.active = .{
        .notification_id = current.id,
        .generation = current.generation,
        .history_id = 1,
    };
    owner.durability.dirty = false;
    const dismissed = Closed{ .key = current, .reason = .dismissed };
    try std.testing.expect(currentClose(owner.history.active, dismissed));
    try std.testing.expect(owner.close(dismissed.key));
    try std.testing.expect(owner.durability.dirty);
    try transcript.observe(.{ .signal = dismissed });
    var durability = Durability{ .dirty = true };
    var batch: IntakeBatch = .{};
    try std.testing.expect(batch.stop() == .flush_and_stop);
    try std.testing.expect(try durability.begin());
    try transcript.observe(.flush);
    durability.succeeded();
    try transcript.observe(.stop);
    try transcript.observe(.{ .connection = connection.closed() });
    try transcript.done();
}

test "strict worker intake transcript proves zero one sixty-four and sixty-five flush counts" {
    inline for (.{
        .{ 0, true, 1 },
        .{ 1, true, 1 },
        .{ 64, true, 1 },
        .{ 65, true, 2 },
    }) |case| {
        var expected: [2]WorkerOperation = undefined;
        for (expected[0..case[2]]) |*operation| operation.* = .flush;
        var transcript = WorkerTranscript{ .expected = expected[0..case[2]] };
        try observeFlushes(&transcript, case[0], case[1]);
        try transcript.done();
    }
}

test "strict worker transcript preserves external and sticky persistence failures" {
    inline for (.{ error.BusLost, error.NameLost }) |external| {
        var batch: IntakeBatch = .{};
        var transcript = WorkerTranscript{ .expected = &.{
            .{ .connection = .open },
            .{ .connection = .own },
            .{ .failure = external },
            .{ .connection = .close },
        } };
        var external_connection: WorkerConnection = .{};
        try transcript.observe(.{ .connection = external_connection.opened() });
        try transcript.observe(.{ .connection = external_connection.owned() });
        try transcript.observe(.{ .failure = batch.external(external).fail });
        try transcript.observe(.{ .connection = external_connection.closed() });
        try transcript.done();
    }
    var transcript = WorkerTranscript{ .expected = &.{
        .flush,
        .{ .failure = error.HistoryWriteFailed },
        .{ .connection = .close },
    } };
    var connection: WorkerConnection = .{};
    try std.testing.expect(connection.opened() == .open);
    try std.testing.expect(connection.owned() == .own);
    var durability = Durability{ .dirty = true };
    try std.testing.expect(workerFailureAction(&durability) == .flush_once);
    try transcript.observe(.flush);
    durability.failed(error.HistoryWriteFailed);
    try transcript.observe(.{ .failure = durability.failure.? });
    try std.testing.expect(workerFailureAction(&durability) == .return_error);
    try std.testing.expectError(error.HistoryWriteFailed, durability.begin());
    try transcript.observe(.{ .connection = connection.closed() });
    try transcript.done();
}

test "strict worker transcript closes only acquired DBus ownership on setup and reply failures" {
    var open_failed = WorkerTranscript{ .expected = &.{.{ .failure = error.SessionBusUnavailable }} };
    try open_failed.observe(.{ .failure = error.SessionBusUnavailable });
    try open_failed.done();

    var own_failed = WorkerTranscript{ .expected = &.{
        .{ .connection = .open },
        .{ .failure = error.NameOwned },
        .{ .connection = .close },
    } };
    var own_connection: WorkerConnection = .{};
    try own_failed.observe(.{ .connection = own_connection.opened() });
    try own_failed.observe(.{ .failure = error.NameOwned });
    try own_failed.observe(.{ .connection = own_connection.closed() });
    try own_failed.done();

    var reply_failed = WorkerTranscript{ .expected = &.{
        .{ .connection = .open },
        .{ .connection = .own },
        .{ .notify = .dirty },
        .{ .failure = error.OutOfMemory },
        .{ .connection = .close },
        .flush,
        .{ .failure = error.OutOfMemory },
    } };
    var reply_connection: WorkerConnection = .{};
    try reply_failed.observe(.{ .connection = reply_connection.opened() });
    try reply_failed.observe(.{ .connection = reply_connection.owned() });
    var order = NotifyOrder{ .displaced = false };
    try reply_failed.observe(.{ .notify = order.marked(true) });
    try reply_failed.observe(.{ .failure = error.OutOfMemory });
    try reply_failed.observe(.{ .connection = reply_connection.closed() });
    var durability = Durability{ .dirty = true };
    try std.testing.expect(workerFailureAction(&durability) == .flush_once);
    try reply_failed.observe(.flush);
    durability.succeeded();
    try reply_failed.observe(.{ .failure = error.OutOfMemory });
    try reply_failed.done();
}

test "strict worker transcript rejects unexpected missing and extra operations" {
    var unexpected = WorkerTranscript{ .expected = &.{.flush} };
    try std.testing.expectError(error.UnexpectedOperation, unexpected.observe(.reply_close));
    var missing = WorkerTranscript{ .expected = &.{.flush} };
    try std.testing.expectError(error.MissingOperation, missing.done());
    var extra = WorkerTranscript{ .expected = &.{} };
    try std.testing.expectError(error.ExtraOperation, extra.observe(.flush));
}

const Worker = struct {
    owner: *Owner,
    mailbox: *Mailbox,
    dbus_owner: *Dbus,
    fn notify(worker: *Worker, request: Request) !void {
        var accepted = worker.owner.accept(request) catch |err| {
            try worker.dbus_owner.replyError(switch (err) {
                error.OutOfMemory => .out_of_memory,
                error.InvalidUtf8 => .invalid_utf8,
                error.FieldTooLong => .field_too_long,
                error.IdExhausted, error.GenerationExhausted, error.HistoryIdExhausted => .id_exhausted,
                else => return err,
            });
            return;
        };
        const id = accepted.presentation.id;
        const displaced = accepted.displaced;
        var order = NotifyOrder{ .displaced = displaced != null };
        std.debug.assert(order.marked(worker.owner.durability.dirty) == .dirty);
        var owns_presentation = true;
        defer if (owns_presentation) accepted.presentation.deinit(worker.owner.allocator);
        try worker.dbus_owner.replyNotify(id);
        std.debug.assert(order.replied() == .reply);
        owns_presentation = false;
        try worker.mailbox.publish(accepted.presentation);
        std.debug.assert(order.published() == .publish);
        accepted = undefined;
        if (displaced) |closed| {
            try worker.dbus_owner.signalClosed(closed.id, .expired);
            std.debug.assert(order.signaled() == .displaced);
        }
        std.debug.assert(order.finished() == .done);
    }

    fn close(worker: *Worker, id: u32) !void {
        if (activeKey(worker.owner.history.active, id)) |key| {
            std.debug.assert(worker.owner.close(key));
            try worker.mailbox.hide(key);
            try worker.dbus_owner.signalClosed(id, .requested);
        }
        try worker.dbus_owner.replyClose();
    }

    fn drainUi(worker: *Worker) !void {
        const closed = worker.mailbox.takeClosed() orelse return;
        if (!currentClose(worker.owner.history.active, closed)) return;
        std.debug.assert(worker.owner.close(closed.key));
        try worker.dbus_owner.signalClosed(closed.key.id, closed.reason);
    }

    fn dispatch(worker: *Worker, method: Method) !void {
        switch (method) {
            .get_capabilities => try worker.dbus_owner.replyCapabilities(),
            .notify => |request| try worker.notify(request),
            .close => |id| try worker.close(id),
            .get_server_information => try worker.dbus_owner.replyServerInformation(),
        }
    }

    fn run(worker: *Worker) !void {
        var connection: WorkerConnection = .{};
        try worker.dbus_owner.open();
        std.debug.assert(connection.opened() == .open);
        defer {
            worker.dbus_owner.close();
            std.debug.assert(connection.closed() == .close);
        }
        try worker.dbus_owner.own();
        std.debug.assert(connection.owned() == .own);
        batches: while (true) {
            var batch: IntakeBatch = .{};
            while (true) {
                try worker.drainUi();
                if (worker.mailbox.uiFailure()) |err| return err;
                const action: BatchAction = switch (try worker.dbus_owner.next(
                    if (batch.count == 0) wait_milliseconds else 0,
                )) {
                    .method => |method| blk: {
                        try worker.dispatch(method);
                        break :blk batch.handled();
                    },
                    .reject => |err| blk: {
                        try worker.dbus_owner.replyError(err);
                        break :blk batch.handled();
                    },
                    .idle => batch.idle(),
                    .stop => batch.stop(),
                    .bus_lost => batch.external(error.BusLost),
                    .name_lost => batch.external(error.NameLost),
                };
                switch (action) {
                    .continue_intake => continue,
                    .flush => {
                        try worker.drainUi();
                        try worker.owner.flush();
                        continue :batches;
                    },
                    .flush_and_stop => {
                        try worker.drainUi();
                        try worker.owner.flush();
                        return;
                    },
                    .fail => |err| return err,
                }
            }
        }
    }
};

const WorkerArgs = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    state_home: ?[]const u8,
    home: ?[]const u8,
    stop: *const std.atomic.Value(bool),
    mailbox: *Mailbox,
};

fn runWorker(args: WorkerArgs) !void {
    var owner = Owner.init(args.allocator, args.io, args.state_home, args.home) catch |err| {
        args.mailbox.workerDone(err);
        return err;
    };
    defer owner.deinit();
    var native = Dbus{ .stop = args.stop };
    var worker = Worker{
        .owner = &owner,
        .mailbox = args.mailbox,
        .dbus_owner = &native,
    };
    worker.run() catch |err| {
        const final_error = switch (workerFailureAction(&owner.durability)) {
            .return_error => err,
            .flush_once => blk: {
                owner.flush() catch |flush_error| break :blk flush_error;
                break :blk err;
            },
        };
        args.mailbox.workerDone(final_error);
        return final_error;
    };
    args.mailbox.workerDone(null);
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    state_home: ?[]const u8,
    home: ?[]const u8,
    stop: *std.atomic.Value(bool),
) !void {
    var mailbox = Mailbox.init(io, allocator);
    defer mailbox.deinit();
    var thread = try io.concurrent(runWorker, .{WorkerArgs{
        .allocator = allocator,
        .io = io,
        .state_home = state_home,
        .home = home,
        .stop = stop,
        .mailbox = &mailbox,
    }});
    const ui_result = runUi(&mailbox, allocator);
    if (ui_result) {
        stop.store(true, .release);
    } else |err| {
        mailbox.uiFailed(err);
        stop.store(true, .release);
    }
    const worker_result = thread.await(io);
    try ui_result;
    try worker_result;
}

// The DBus worker owns one private bounded session-bus connection.
const dbus_name = "org.freedesktop.Notifications";
const dbus_path = "/org/freedesktop/Notifications";
const dbus_interface = "org.freedesktop.Notifications";
const message_capacity = 64 * 1024;
const wait_milliseconds: i32 = 100;
const send_turn_capacity = 8;
const send_wait_milliseconds = 25;

const Dbus = struct {
    stop: *const std.atomic.Value(bool),
    connection: ?*dbus.DBusConnection = null,
    message: ?*dbus.DBusMessage = null,

    pub fn open(native: *Dbus) !void {
        std.debug.assert(native.connection == null);
        std.debug.assert(native.message == null);

        const connection = dbus.dbus_bus_get_private(dbus.DBUS_BUS_SESSION, null) orelse {
            return error.SessionBusUnavailable;
        };
        native.connection = connection;
        dbus.dbus_connection_set_exit_on_disconnect(connection, 0);
        dbus.dbus_connection_set_max_message_size(connection, message_capacity);
        dbus.dbus_connection_set_max_message_unix_fds(connection, 0);
        std.debug.assert(dbus.dbus_connection_get_max_message_size(connection) == message_capacity);
        std.debug.assert(dbus.dbus_connection_get_max_message_unix_fds(connection) == 0);
    }

    pub fn own(native: *Dbus) !void {
        const connection = native.connection orelse return error.ConnectionMissing;
        const result = dbus.dbus_bus_request_name(
            connection,
            dbus_name,
            dbus.DBUS_NAME_FLAG_DO_NOT_QUEUE,
            null,
        );
        if (result != dbus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER and
            result != dbus.DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER)
        {
            return error.NameOwned;
        }
    }

    pub fn next(native: *Dbus, wait: i32) !Event {
        std.debug.assert(native.connection != null);
        std.debug.assert(native.message == null);
        if (native.stop.load(.acquire)) return .stop;

        const connection = native.connection.?;
        if (dbus.dbus_connection_read_write(connection, wait) == 0) return .bus_lost;
        if (native.stop.load(.acquire)) return .stop;
        const message = dbus.dbus_connection_pop_message(connection) orelse return .idle;
        native.message = message;

        if (dbus.dbus_message_is_signal(message, dbus.DBUS_INTERFACE_DBUS, "NameLost") != 0) {
            const lost = readOneString(message) orelse {
                native.releaseMessage();
                return .idle;
            };
            if (std.mem.eql(u8, lost, dbus_name)) return .name_lost;
            native.releaseMessage();
            return .idle;
        }
        if (dbus.dbus_message_get_type(message) != dbus.DBUS_MESSAGE_TYPE_METHOD_CALL or
            dbus.dbus_message_has_path(message, dbus_path) == 0 or
            dbus.dbus_message_has_interface(message, dbus_interface) == 0)
        {
            return .{ .reject = .unknown_method };
        }

        const member_pointer = dbus.dbus_message_get_member(message) orelse {
            return .{ .reject = .unknown_method };
        };
        const member = std.mem.span(member_pointer);
        if (std.mem.eql(u8, member, "GetCapabilities")) {
            return noArguments(message, .get_capabilities);
        }
        if (std.mem.eql(u8, member, "Notify")) return parseNotify(message);
        if (std.mem.eql(u8, member, "CloseNotification")) return parseClose(message);
        if (std.mem.eql(u8, member, "GetServerInformation")) {
            return noArguments(message, .get_server_information);
        }
        return .{ .reject = .unknown_method };
    }

    pub fn replyCapabilities(native: *Dbus) !void {
        const reply = dbus.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer dbus.dbus_message_unref(reply);
        var root: dbus.DBusMessageIter = undefined;
        var array: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(reply, &root);
        if (dbus.dbus_message_iter_open_container(&root, dbus.DBUS_TYPE_ARRAY, "s", &array) == 0) {
            return error.OutOfMemory;
        }
        if (dbus.dbus_message_iter_close_container(&root, &array) == 0) {
            dbus.dbus_message_iter_abandon_container(&root, &array);
            return error.OutOfMemory;
        }
        try native.sendReply(reply);
    }

    pub fn replyNotify(native: *Dbus, id: u32) !void {
        std.debug.assert(id != 0);
        const reply = dbus.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(reply, &iter);
        var value: dbus.dbus_uint32_t = id;
        if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_UINT32, &value) == 0) {
            return error.OutOfMemory;
        }
        try native.sendReply(reply);
    }

    pub fn signalClosed(native: *Dbus, id: u32, reason: CloseReason) !void {
        std.debug.assert(id != 0);
        const signal = dbus.dbus_message_new_signal(dbus_path, dbus_interface, "NotificationClosed") orelse {
            return error.OutOfMemory;
        };
        defer dbus.dbus_message_unref(signal);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(signal, &iter);
        var notification_id: dbus.dbus_uint32_t = id;
        var close_reason: dbus.dbus_uint32_t = @intFromEnum(reason);
        if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_UINT32, &notification_id) == 0 or
            dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_UINT32, &close_reason) == 0)
        {
            return error.OutOfMemory;
        }
        try native.send(signal);
    }

    pub fn replyClose(native: *Dbus) !void {
        const reply = dbus.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer dbus.dbus_message_unref(reply);
        try native.sendReply(reply);
    }

    pub fn replyServerInformation(native: *Dbus) !void {
        const reply = dbus.dbus_message_new_method_return(native.message orelse return error.MessageMissing) orelse {
            return error.OutOfMemory;
        };
        defer dbus.dbus_message_unref(reply);
        var iter: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_init_append(reply, &iter);
        const values = [_][*:0]const u8{ "wayspot", "wayspot", "0.1.0", "1.3" };
        for (values) |value| {
            var pointer = value;
            if (dbus.dbus_message_iter_append_basic(&iter, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0) {
                return error.OutOfMemory;
            }
        }
        try native.sendReply(reply);
    }

    pub fn replyError(native: *Dbus, err: ReplyError) !void {
        const error_name: [*:0]const u8, const message: [*:0]const u8 = switch (err) {
            .unknown_method => .{ "org.freedesktop.DBus.Error.UnknownMethod", "Unknown method" },
            .invalid_signature => .{ "org.freedesktop.DBus.Error.InvalidArgs", "Invalid arguments" },
            .out_of_memory => .{ "org.freedesktop.DBus.Error.NoMemory", "Out of memory" },
            else => .{ "org.freedesktop.DBus.Error.LimitsExceeded", "Notification exceeds Wayspot bounds" },
        };
        const reply = dbus.dbus_message_new_error(
            native.message orelse return error.MessageMissing,
            error_name,
            message,
        ) orelse return error.OutOfMemory;
        defer dbus.dbus_message_unref(reply);
        try native.sendReply(reply);
    }

    pub fn close(native: *Dbus) void {
        native.releaseMessage();
        if (native.connection) |connection| {
            dbus.dbus_connection_close(connection);
            dbus.dbus_connection_unref(connection);
            native.connection = null;
        }
    }

    fn sendReply(native: *Dbus, reply: *dbus.DBusMessage) !void {
        defer native.releaseMessage();
        try native.send(reply);
    }

    fn send(native: *Dbus, message: *dbus.DBusMessage) !void {
        const connection = native.connection orelse return error.ConnectionMissing;
        if (dbus.dbus_connection_send(connection, message, null) == 0) return error.OutOfMemory;
        for (0..send_turn_capacity) |_| {
            if (dbus.dbus_connection_has_messages_to_send(connection) == 0) return;
            if (dbus.dbus_connection_read_write(connection, send_wait_milliseconds) == 0) return error.BusLost;
        }
        return error.SendTimedOut;
    }

    fn releaseMessage(native: *Dbus) void {
        if (native.message) |message| {
            dbus.dbus_message_unref(message);
            native.message = null;
        }
    }
};

fn noArguments(message: *dbus.DBusMessage, method: Method) Event {
    if (dbus.dbus_message_has_signature(message, "") == 0) return .{ .reject = .invalid_signature };
    return .{ .method = method };
}

fn parseClose(message: *dbus.DBusMessage) Event {
    if (dbus.dbus_message_has_signature(message, "u") == 0) return .{ .reject = .invalid_signature };
    var iter: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(message, &iter) == 0) return .{ .reject = .invalid_signature };
    var id: dbus.dbus_uint32_t = 0;
    dbus.dbus_message_iter_get_basic(&iter, &id);
    return .{ .method = .{ .close = id } };
}

fn parseNotify(message: *dbus.DBusMessage) Event {
    if (dbus.dbus_message_has_signature(message, "susssasa{sv}i") == 0) {
        return .{ .reject = .invalid_signature };
    }
    var iter: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(message, &iter) == 0) return .{ .reject = .invalid_signature };

    const app_name = readString(&iter);
    const replaces_id = readU32(&iter);
    const app_icon = readString(&iter);
    const summary = readString(&iter);
    const body = readString(&iter);
    const action_error = countActions(&iter);
    if (action_error) |err| return .{ .reject = err };
    const hint_error = countHints(&iter);
    if (hint_error) |err| return .{ .reject = err };
    const expire_timeout = readI32(&iter);
    return .{ .method = .{ .notify = .{
        .replaces_id = replaces_id,
        .app_name = app_name,
        .app_icon = app_icon,
        .summary = summary,
        .body = body,
        .expire_timeout = expire_timeout,
    } } };
}

fn readOneString(message: *dbus.DBusMessage) ?[]const u8 {
    if (dbus.dbus_message_has_signature(message, "s") == 0) return null;
    var iter: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_init(message, &iter) == 0) return null;
    return readString(&iter);
}

fn readString(iter: *dbus.DBusMessageIter) []const u8 {
    std.debug.assert(dbus.dbus_message_iter_get_arg_type(iter) == dbus.DBUS_TYPE_STRING);
    var pointer: [*:0]const u8 = undefined;
    dbus.dbus_message_iter_get_basic(iter, @ptrCast(&pointer));
    _ = dbus.dbus_message_iter_next(iter);
    return std.mem.span(pointer);
}

fn readU32(iter: *dbus.DBusMessageIter) u32 {
    std.debug.assert(dbus.dbus_message_iter_get_arg_type(iter) == dbus.DBUS_TYPE_UINT32);
    var value: dbus.dbus_uint32_t = 0;
    dbus.dbus_message_iter_get_basic(iter, &value);
    _ = dbus.dbus_message_iter_next(iter);
    return value;
}

fn readI32(iter: *dbus.DBusMessageIter) i32 {
    std.debug.assert(dbus.dbus_message_iter_get_arg_type(iter) == dbus.DBUS_TYPE_INT32);
    var value: dbus.dbus_int32_t = 0;
    dbus.dbus_message_iter_get_basic(iter, &value);
    _ = dbus.dbus_message_iter_next(iter);
    return value;
}

fn countActions(iter: *dbus.DBusMessageIter) ?ReplyError {
    std.debug.assert(dbus.dbus_message_iter_get_arg_type(iter) == dbus.DBUS_TYPE_ARRAY);
    var actions: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(iter, &actions);
    var count: usize = 0;
    while (dbus.dbus_message_iter_get_arg_type(&actions) != dbus.DBUS_TYPE_INVALID) {
        if (count == 64) return .too_many_actions;
        const action = readString(&actions);
        if (action.len > 256) return .too_many_actions;
        count += 1;
    }
    _ = dbus.dbus_message_iter_next(iter);
    if (count % 2 != 0) return .invalid_signature;
    return null;
}

fn countHints(iter: *dbus.DBusMessageIter) ?ReplyError {
    std.debug.assert(dbus.dbus_message_iter_get_arg_type(iter) == dbus.DBUS_TYPE_ARRAY);
    var hints: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_recurse(iter, &hints);
    var count: usize = 0;
    while (dbus.dbus_message_iter_get_arg_type(&hints) != dbus.DBUS_TYPE_INVALID) {
        if (count == 64) return .too_many_hints;
        var entry: dbus.DBusMessageIter = undefined;
        dbus.dbus_message_iter_recurse(&hints, &entry);
        const key = readString(&entry);
        if (key.len > 256) return .too_many_hints;
        count += 1;
        _ = dbus.dbus_message_iter_next(&hints);
    }
    _ = dbus.dbus_message_iter_next(iter);
    return null;
}

test "action arrays require bounded key label pairs" {
    try std.testing.expectEqual(null, try actionError(&.{ "open", "Open" }));
    try std.testing.expectEqual(ReplyError.invalid_signature, try actionError(&.{"open"}));

    var actions: [65][]const u8 = @splat("x");
    try std.testing.expectEqual(ReplyError.too_many_actions, try actionError(&actions));
    var long: [257]u8 = @splat('x');
    try std.testing.expectEqual(ReplyError.too_many_actions, try actionError(&.{&long}));
}

test "hint dictionaries bound count and key bytes" {
    try std.testing.expectEqual(null, try hintError(&.{"urgency"}));

    var keys: [65][]const u8 = @splat("x");
    try std.testing.expectEqual(ReplyError.too_many_hints, try hintError(&keys));
    var long: [257]u8 = @splat('x');
    try std.testing.expectEqual(ReplyError.too_many_hints, try hintError(&.{&long}));
}

test "generated action and hint bounds match native iterators" {
    if (builtin.fuzz) {
        try std.testing.fuzz({}, fuzzCollections, .{});
        return;
    }
    var empty = std.testing.Smith{ .in = "" };
    try fuzzCollections({}, &empty);
}

fn fuzzCollections(_: void, smith: *std.testing.Smith) !void {
    var bytes: [257]u8 = @splat('x');
    var values: [65][]const u8 = undefined;
    const count = smith.value(u8) % (values.len + 1);
    const length = smith.value(u16) % (bytes.len + 1);
    for (values[0..count]) |*value| value.* = bytes[0..length];

    const actions = try actionError(values[0..count]);
    if (count > 64 or length > 256) {
        try std.testing.expectEqual(ReplyError.too_many_actions, actions);
    } else if (count % 2 != 0) {
        try std.testing.expectEqual(ReplyError.invalid_signature, actions);
    } else {
        try std.testing.expectEqual(null, actions);
    }

    const hints = try hintError(values[0..count]);
    if (count > 64 or length > 256) {
        try std.testing.expectEqual(ReplyError.too_many_hints, hints);
    } else {
        try std.testing.expectEqual(null, hints);
    }
}

fn actionError(actions: []const []const u8) !?ReplyError {
    const message = dbus.dbus_message_new_signal(dbus_path, dbus_interface, "Test") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var root: dbus.DBusMessageIter = undefined;
    var array: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &root);
    if (dbus.dbus_message_iter_open_container(&root, dbus.DBUS_TYPE_ARRAY, "s", &array) == 0) {
        return error.OutOfMemory;
    }
    for (actions) |action| {
        const terminated = try std.testing.allocator.dupeZ(u8, action);
        defer std.testing.allocator.free(terminated);
        var pointer: [*:0]const u8 = terminated;
        if (dbus.dbus_message_iter_append_basic(&array, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0) {
            dbus.dbus_message_iter_abandon_container(&root, &array);
            return error.OutOfMemory;
        }
    }
    if (dbus.dbus_message_iter_close_container(&root, &array) == 0) {
        dbus.dbus_message_iter_abandon_container(&root, &array);
        return error.OutOfMemory;
    }
    var read: dbus.DBusMessageIter = undefined;
    std.debug.assert(dbus.dbus_message_iter_init(message, &read) != 0);
    return countActions(&read);
}

fn hintError(keys: []const []const u8) !?ReplyError {
    const message = dbus.dbus_message_new_signal(dbus_path, dbus_interface, "Test") orelse return error.OutOfMemory;
    defer dbus.dbus_message_unref(message);
    var root: dbus.DBusMessageIter = undefined;
    var array: dbus.DBusMessageIter = undefined;
    dbus.dbus_message_iter_init_append(message, &root);
    if (dbus.dbus_message_iter_open_container(&root, dbus.DBUS_TYPE_ARRAY, "{sv}", &array) == 0) {
        return error.OutOfMemory;
    }
    for (keys) |key| try appendHint(&array, key);
    if (dbus.dbus_message_iter_close_container(&root, &array) == 0) {
        dbus.dbus_message_iter_abandon_container(&root, &array);
        return error.OutOfMemory;
    }
    var read: dbus.DBusMessageIter = undefined;
    std.debug.assert(dbus.dbus_message_iter_init(message, &read) != 0);
    return countHints(&read);
}

fn appendHint(array: *dbus.DBusMessageIter, key: []const u8) !void {
    const terminated = try std.testing.allocator.dupeZ(u8, key);
    defer std.testing.allocator.free(terminated);
    var pointer: [*:0]const u8 = terminated;
    var entry: dbus.DBusMessageIter = undefined;
    var variant: dbus.DBusMessageIter = undefined;
    if (dbus.dbus_message_iter_open_container(array, dbus.DBUS_TYPE_DICT_ENTRY, null, &entry) == 0) {
        return error.OutOfMemory;
    }
    if (dbus.dbus_message_iter_append_basic(&entry, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0 or
        dbus.dbus_message_iter_open_container(&entry, dbus.DBUS_TYPE_VARIANT, "s", &variant) == 0)
    {
        dbus.dbus_message_iter_abandon_container(array, &entry);
        return error.OutOfMemory;
    }
    if (dbus.dbus_message_iter_append_basic(&variant, dbus.DBUS_TYPE_STRING, @ptrCast(&pointer)) == 0 or
        dbus.dbus_message_iter_close_container(&entry, &variant) == 0 or
        dbus.dbus_message_iter_close_container(array, &entry) == 0)
    {
        dbus.dbus_message_iter_abandon_container_if_open(&entry, &variant);
        dbus.dbus_message_iter_abandon_container_if_open(array, &entry);
        return error.OutOfMemory;
    }
}
