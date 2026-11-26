//! Owns notification identity, newest-only presentation, retained history, DBus, and SDL.

const std = @import("std");
const builtin = @import("builtin");
const sdl = @import("sdl_c");
const sdl_layer = @import("../ui/layer.zig");
const text_draw = @import("../ui/text.zig");
const dbus = @import("dbus_c");
const Video = @import("../ui/video.zig");
const Stop = @import("../stop.zig");
const native_ui = Video.native_ui;
const shm = if (native_ui) @import("../ui/native_surface.zig") else struct {};

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
    ignored,
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

// At most one presentation is retained across a bounded D-Bus intake turn.
// No synchronization: intake, persistence and presentation have one owner.
const Pending = struct {
    allocator: std.mem.Allocator,
    desired: ?Desired = null,

    fn clear(self: *Pending) void {
        if (self.desired) |*value| value.deinit(self.allocator);
        self.desired = null;
    }

    fn publish(self: *Pending, value: Presentation) void {
        self.clear();
        self.desired = .{ .shown = value };
    }

    fn hide(self: *Pending, key: Key) void {
        self.clear();
        self.desired = .{ .hidden = key };
    }

    fn take(self: *Pending) ?Desired {
        const value = self.desired;
        self.desired = null;
        return value;
    }
};

const banner_width = 420;
const banner_height = 120;
const banner_font_size = 16;

const UiResource = enum(u8) { sdl, window, renderer, text };

const UiResources = struct {
    count: u8 = 0,

    fn acquired(resources: *UiResources, resource: UiResource) void {
        std.debug.assert(resources.count == @backingInt(resource));
        resources.count += 1;
    }

    fn release(resources: *UiResources) ?UiResource {
        if (resources.count == 0) return null;
        resources.count -= 1;
        return @fromBackingInt(@intCast(resources.count));
    }
};

const Banner = struct {
    native_display: if (native_ui) ?*shm.Display else void = if (native_ui) null else {},
    native_surface: if (native_ui) ?*shm.Surface else void = if (native_ui) null else {},
    presented: ?Key = null,
    window: ?*sdl.SDL_Window = null,
    layer: sdl_layer = .{},
    renderer: ?*sdl.SDL_Renderer = null,
    text: ?text_draw.Painter = null,
    resources: UiResources = .{},

    fn init(banner: *Banner, video: *Video, allocator: std.mem.Allocator, io: std.Io) !void {
        errdefer banner.deinit(video);
        if (native_ui) {
            banner.native_display = try video.acquireNative(allocator, io);
            banner.native_surface = try shm.Surface.create(banner.native_display.?, .notification, .{ .width = banner_width, .height = banner_height }, null);
            return;
        }
        try video.acquire();
        banner.resources.acquired(.sdl);
        banner.window = try sdl_layer.createWindow("wayspot notification", banner_width, banner_height);
        banner.resources.acquired(.window);
        // A noninteractive top-right layer never enters the tiling set.
        try banner.layer.init(banner.window.?, .notification, banner_width, banner_height);
        banner.renderer = sdl.SDL_CreateRenderer(banner.window, null) orelse return error.SdlRendererCreateFailed;
        banner.resources.acquired(.renderer);
        if (!sdl.SDL_SetRenderLogicalPresentation(
            banner.renderer,
            banner_width,
            banner_height,
            sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
        )) return error.SdlLogicalPresentationFailed;
        banner.text = try text_draw.Painter.init(allocator, banner.renderer.?, banner_font_size);
        banner.resources.acquired(.text);
    }

    fn deinit(banner: *Banner, video: *Video) void {
        if (native_ui) {
            if (banner.native_surface) |surface| {
                surface.destroy() catch |err| std.log.warn("native notification retirement failed: {s}", .{@errorName(err)});
                std.log.info("native notification retired", .{});
            }
            if (banner.native_display != null) video.releaseNative();
            banner.* = .{};
            return;
        }
        while (banner.resources.release()) |resource| switch (resource) {
            .text => {
                if (banner.text) |*painter| painter.deinit();
            },
            .renderer => sdl.SDL_DestroyRenderer(banner.renderer.?),
            .window => {
                banner.layer.deinit();
                sdl.SDL_DestroyWindow(banner.window.?);
            },
            .sdl => video.release(),
        };
        banner.* = .{};
    }

    fn exists(banner: *const Banner) bool {
        if (native_ui) return banner.native_surface != null;
        return banner.window != null;
    }

    fn visibleNow(banner: *const Banner) bool {
        if (native_ui) return banner.presented != null and banner.native_surface != null;
        return banner.window != null;
    }

    fn closed(banner: *const Banner) bool {
        if (native_ui) return if (banner.native_surface) |surface| surface.closed or surface.display.failed else false;
        return banner.layer.closed;
    }

    fn draw(banner: *Banner, allocator: std.mem.Allocator, item: *const Presentation) !void {
        if (native_ui) {
            banner.native_surface.?.invalidate();
            try banner.drawNative(allocator, item);
            return;
        }
        try banner.layer.update(banner.window.?);
        const renderer = banner.renderer orelse unreachable;
        const painter = if (banner.text) |*value| value else return error.TextNotInitialized;
        try drawContents(renderer, painter, item);
        if (!sdl.SDL_RenderPresent(renderer)) return error.SdlDrawFailed;
        if (!sdl.SDL_ShowWindow(banner.window)) return error.SdlShowFailed;
    }

    fn drawNative(banner: *Banner, allocator: std.mem.Allocator, item: *const Presentation) !void {
        const surface = banner.native_surface orelse return;
        const result = try surface.draw(.{ .allocator = allocator, .item = item }, paintNative);
        if (result == .presented) {
            if (banner.presented == null) std.log.info("native notification first attach", .{});
            banner.presented = .{ .id = item.id, .generation = item.generation };
        }
    }

    fn paintNative(context: anytype, frame: shm.Frame) !void {
        // Banner redraws are infrequent. Render into the admitted buffer
        // directly, retiring the renderer before returning its pixel borrow.
        if (sdl.SDL_WasInit(sdl.SDL_INIT_VIDEO) != 0) return error.NativeBannerUnexpectedVideo;
        const canvas = sdl.SDL_CreateSurfaceFrom(@intCast(frame.extent.width), @intCast(frame.extent.height), sdl.SDL_PIXELFORMAT_XRGB8888, frame.pixels.ptr, @intCast(frame.stride)) orelse return error.NativeBannerCanvas;
        defer sdl.SDL_DestroySurface(canvas);
        const renderer = sdl.SDL_CreateSoftwareRenderer(canvas) orelse return error.NativeBannerRenderer;
        defer sdl.SDL_DestroyRenderer(renderer);
        if (!sdl.SDL_SetRenderLogicalPresentation(renderer, banner_width, banner_height, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX)) return error.SdlLogicalPresentationFailed;
        const scale = @min(@as(f32, @floatFromInt(frame.extent.width)) / banner_width, @as(f32, @floatFromInt(frame.extent.height)) / banner_height);
        var painter = try text_draw.Painter.initScaled(context.allocator, renderer, banner_font_size, scale);
        defer painter.deinit();
        try drawContents(renderer, &painter, context.item);
        if (!sdl.SDL_FlushRenderer(renderer)) return error.NativeBannerFlush;
    }

    fn drawContents(renderer: *sdl.SDL_Renderer, painter: *text_draw.Painter, item: *const Presentation) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer, 18, 18, 24, 255)) return error.SdlDrawFailed;
        if (!sdl.SDL_RenderClear(renderer)) return error.SdlDrawFailed;
        const summary_clip = sdl.SDL_Rect{ .x = 16, .y = 12, .w = banner_width - 32, .h = 24 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &summary_clip)) return error.SdlClipFailed;
        const summary_result = painter.draw(item.summary, .{ 235, 235, 240 }, 16, 14);
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlClipFailed;
        try summary_result;
        const body_clip = sdl.SDL_Rect{ .x = 16, .y = 42, .w = banner_width - 32, .h = 60 };
        if (!sdl.SDL_SetRenderClipRect(renderer, &body_clip)) return error.SdlClipFailed;
        const body_result = painter.drawWrapped(
            item.body,
            .{ 190, 192, 202 },
            16,
            44,
            banner_width - 32,
            body_clip.h,
        );
        if (!sdl.SDL_SetRenderClipRect(renderer, null)) return error.SdlClipFailed;
        try body_result;
    }
};

const UiPhase = enum { cold, initializing, visible };
const UiAction = enum { none, initialize, draw, hide };
const UiSignal = union(enum) { shown: Key, hidden: Key };
const UiDecision = enum { none, initialize, draw, hide };

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
    };
}

/// A banner can be absent while its accepted notification is still alive.
/// Rendering failure must not stop D-Bus service or extend the expiry deadline.
const Ui = struct {
    banner: Banner = .{},
    state: UiState = .{},
    visible: ?Presentation = null,

    fn clear(self: *Ui, video: *Video, allocator: std.mem.Allocator) void {
        self.banner.deinit(video);
        if (self.visible) |*value| value.deinit(allocator);
        self.* = .{};
    }

    fn apply(self: *Ui, video: *Video, allocator: std.mem.Allocator, io: std.Io, desired: Desired) !void {
        switch (desired) {
            .hidden => |key| {
                _ = decideUi(&self.state, .{ .hidden = key });
                self.clear(video, allocator);
            },
            .shown => |value| {
                _ = decideUi(&self.state, .{ .shown = .{ .id = value.id, .generation = value.generation } });
                if (self.visible) |*prior| prior.deinit(allocator);
                self.visible = value;
                // Establish an expiry even if video initialization or drawing fails.
                _ = self.state.drawn(nowMilliseconds(io), value.timeout_ms);
                if (!self.banner.exists()) try self.banner.init(video, allocator, io);
                try self.banner.draw(allocator, &self.visible.?);
                if (!native_ui) _ = self.state.drawn(nowMilliseconds(io), value.timeout_ms);
            },
        }
    }

    fn event(self: *Ui, allocator: std.mem.Allocator, input: *const sdl.SDL_Event) !?Closed {
        const window = self.banner.window orelse return null;
        if (sdl.SDL_GetWindowFromEvent(input) != window) return null;
        switch (input.type) {
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => if (input.button.button == sdl.SDL_BUTTON_LEFT) {
                return self.state.close(.dismissed);
            },
            sdl.SDL_EVENT_WINDOW_EXPOSED,
            sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
            sdl.SDL_EVENT_RENDER_TARGETS_RESET,
            => try self.banner.draw(allocator, &self.visible.?),
            sdl.SDL_EVENT_RENDER_DEVICE_RESET => {
                self.banner.text.?.reset();
                try self.banner.draw(allocator, &self.visible.?);
            },
            sdl.SDL_EVENT_RENDER_DEVICE_LOST => return error.SdlDeviceLost,
            else => {},
        }
        return null;
    }

    fn nativeTurn(self: *Ui, allocator: std.mem.Allocator) !?Closed {
        if (!native_ui) return null;
        const surface = self.banner.native_surface orelse return null;
        if (self.banner.closed()) return error.NativeBannerClosed;
        const input = &surface.display.input;
        while (input.popFor(surface.surface.?.id)) |native_event| {
            switch (native_event.value) {
                .button => |button| {
                    // Preserve click-down dismissal. Never apply input to a
                    // newer generation that has not yet been presented.
                    if (button.code == 272 and button.pressed and std.meta.eql(self.banner.presented, self.state.key)) return self.state.close(.dismissed);
                },
                else => {},
            }
        }
        try self.banner.drawNative(allocator, &self.visible.?);
        return null;
    }

    fn expired(self: *Ui, now: u64) ?Closed {
        if (self.visible == null or now < self.state.deadline) return null;
        return self.state.close(.expired);
    }
};

fn nowMilliseconds(io: std.Io) u64 {
    return @intCast(std.Io.Clock.awake.now(io).toMilliseconds());
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

/// Owner keeps retained memory and its canonical file synchronized in the service.
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
    decision: UiDecision,
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

test "strict UI transcript follows newest draw deadline close and cleanup policy" {
    const one = Key{ .id = 1, .generation = 1 };
    const two = Key{ .id = 1, .generation = 2 };
    const three = Key{ .id = 2, .generation = 3 };
    var transcript = UiTranscript{ .expected = &.{
        .{ .decision = .none },
        .{ .decision = .initialize },
        .{ .acquire = .sdl },
        .{ .acquire = .window },
        .{ .acquire = .renderer },
        .{ .acquire = .text },
        .{ .decision = .none },
        .{ .draw = two },
        .{ .wait = 100 },
        .{ .decision = .draw },
        .{ .draw = three },
        .{ .wait = 200 },
        .{ .closed = .{ .key = three, .reason = .expired } },
        .{ .release = .text },
        .{ .release = .renderer },
        .{ .release = .window },
        .{ .release = .sdl },
        .{ .decision = .initialize },
        .{ .draw = one },
        .{ .closed = .{ .key = one, .reason = .dismissed } },
        .{ .decision = .initialize },
        .{ .draw = one },
        .{ .decision = .hide },
    } };
    var state: UiState = .{};
    try transcript.observe(.{ .decision = decideUi(&state, .{ .hidden = one }) });
    try transcript.observe(.{ .decision = decideUi(&state, .{ .shown = one }) });
    var resources: UiResources = .{};
    inline for (std.meta.tags(UiResource)) |resource| {
        resources.acquired(resource);
        try transcript.observe(.{ .acquire = resource });
    }
    try transcript.observe(.{ .decision = decideUi(&state, .{ .shown = two }) });
    try std.testing.expectEqual(UiAction.draw, state.drawn(10, 100));
    try transcript.observe(.{ .draw = state.key.? });
    try transcript.observe(.{ .wait = state.remaining(10) });
    try transcript.observe(.{ .decision = decideUi(&state, .{ .shown = three }) });
    try std.testing.expectEqual(UiAction.draw, state.drawn(20, 200));
    try transcript.observe(.{ .draw = state.key.? });
    try transcript.observe(.{ .wait = state.remaining(20) });
    try transcript.observe(.{ .closed = state.close(.expired).? });
    try std.testing.expect(state.close(.dismissed) == null);
    while (resources.release()) |resource| try transcript.observe(.{ .release = resource });
    var dismissed: UiState = .{};
    try transcript.observe(.{ .decision = decideUi(&dismissed, .{ .shown = one }) });
    try std.testing.expectEqual(UiAction.draw, dismissed.drawn(0, 100));
    try transcript.observe(.{ .draw = dismissed.key.? });
    try transcript.observe(.{ .closed = dismissed.close(.dismissed).? });
    try std.testing.expect(dismissed.close(.dismissed) == null);
    var hidden: UiState = .{};
    try transcript.observe(.{ .decision = decideUi(&hidden, .{ .shown = one }) });
    try std.testing.expectEqual(UiAction.draw, hidden.drawn(0, 100));
    try transcript.observe(.{ .draw = hidden.key.? });
    try transcript.observe(.{ .decision = decideUi(&hidden, .{ .hidden = one }) });
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

test "pending presentation retains only the latest owned value" {
    var pending: Pending = .{ .allocator = std.testing.allocator };
    defer pending.clear();
    var one = try sampleNotification(std.testing.allocator, 1, "one");
    defer one.deinit(std.testing.allocator);
    var two = try sampleNotification(std.testing.allocator, 2, "two");
    defer two.deinit(std.testing.allocator);
    const one_key = Key{ .id = one.id, .generation = one.generation };
    const two_key = Key{ .id = two.id, .generation = two.generation };
    pending.publish(try Presentation.init(std.testing.allocator, &one));
    pending.hide(one_key);
    pending.publish(try Presentation.init(std.testing.allocator, &two));
    var shown = pending.take().?;
    defer shown.deinit(std.testing.allocator);
    try std.testing.expectEqual(two_key, Key{ .id = shown.shown.id, .generation = shown.shown.generation });
    try std.testing.expect(pending.take() == null);
    pending.publish(try Presentation.init(std.testing.allocator, &one));
    pending.hide(one_key);
    try std.testing.expectEqual(one_key, pending.take().?.hidden);
    try std.testing.expect(pending.take() == null);
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
    var pending: Pending = .{ .allocator = std.testing.allocator };
    defer pending.clear();
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
                pending.publish(accepted.presentation);
                accepted = undefined;
            },
            1 => {
                if (owner.history.active) |active| owner.history.closed(.{
                    .id = active.notification_id,
                    .generation = active.generation,
                });
            },
            2 => if (pending.take()) |value| {
                var owned = value;
                owned.deinit(std.testing.allocator);
            },
            else => unreachable,
        }
        owner.history.assertValid();
        try std.testing.expect(@intFromBool(owner.history.active != null) <= 1);
        try std.testing.expect(@intFromBool(pending.desired != null) <= 1);
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

const NotifyOperation = enum { dirty, reply, publish, displaced, done };

fn finalFlushAllowed(durability: *const Durability) bool {
    return durability.failure == null;
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

test "notification publication order and displaced identity are exact" {
    for ([_]bool{ false, true }) |displaced| {
        var order: NotifyOrder = .{ .displaced = displaced };
        try std.testing.expectEqual(NotifyOperation.dirty, order.marked(true));
        try std.testing.expectEqual(NotifyOperation.reply, order.replied());
        try std.testing.expectEqual(NotifyOperation.publish, order.published());
        if (displaced) try std.testing.expectEqual(NotifyOperation.displaced, order.signaled());
        try std.testing.expectEqual(NotifyOperation.done, order.finished());
    }
    const active: Active = .{ .notification_id = 7, .generation = 9, .history_id = 1 };
    try std.testing.expect(!currentClose(active, .{ .key = .{ .id = 7, .generation = 8 }, .reason = .expired }));
    try std.testing.expect(currentClose(active, .{ .key = .{ .id = 7, .generation = 9 }, .reason = .expired }));
}

test "only external connection failures retry; persistence failures remain sticky" {
    for ([_]anyerror{ error.BusLost, error.NameLost, error.SessionBusUnavailable }) |err| {
        try std.testing.expectEqual(@as(?i64, reconnect_wait_milliseconds), reconnectWait(err));
    }
    try std.testing.expect(reconnectWait(error.NameOwned) == null);
    try std.testing.expect(reconnectWait(error.HistoryWriteFailed) == null);
    var durability: Durability = .{ .dirty = true };
    try std.testing.expect(finalFlushAllowed(&durability));
    durability.failed(error.HistoryWriteFailed);
    try std.testing.expect(!finalFlushAllowed(&durability));
    try std.testing.expectError(error.HistoryWriteFailed, durability.begin());
}

/// One notification service, advanced by the caller's event loop. Keep the
/// owner at a stable address after first showing a banner (Wayland callbacks).
pub const Service = struct {
    owner: Owner,
    video: *Video,
    dbus_owner: Dbus = .{},
    owns_history: bool = false,
    retry_at: u64 = 0,
    pending: Pending,
    ui: Ui = .{},

    pub fn init(allocator: std.mem.Allocator, io: std.Io, state_home: ?[]const u8, home: ?[]const u8, video: *Video) !Service {
        return .{
            .owner = try Owner.init(allocator, io, state_home, home),
            .video = video,
            .pending = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Service) void {
        self.ui.clear(self.video, self.owner.allocator);
        self.pending.clear();
        self.dbus_owner.close();
        self.owner.deinit();
    }

    pub fn connect(self: *Service) !void {
        try self.dbus_owner.open();
        errdefer self.dbus_owner.close();
        try self.dbus_owner.own();
        self.owns_history = true;
    }

    pub fn disconnect(self: *Service) !void {
        self.dbus_owner.close();
        if (self.owner.history.active) |active| {
            std.debug.assert(self.owner.close(.{ .id = active.notification_id, .generation = active.generation }));
        }
        self.pending.clear();
        self.ui.clear(self.video, self.owner.allocator);
        try self.flush();
    }

    pub fn fd(self: *const Service) !std.posix.fd_t {
        const connection = self.dbus_owner.connection orelse return -1;
        var value: c_int = -1;
        if (dbus.dbus_connection_get_unix_fd(connection, &value) == 0 or value < 0) return error.BusSocketUnavailable;
        return value;
    }

    pub fn flush(self: *Service) !void {
        // A duplicate-name refusal must not overwrite the real owner's history.
        if (self.owns_history) try self.owner.flush();
    }

    /// Advance connection recovery and intake without waiting for traffic.
    pub fn tick(self: *Service, now: u64) !bool {
        if (self.dbus_owner.connection == null) {
            if (now < self.retry_at) return false;
            self.connect() catch |err| {
                const delay = reconnectWait(err) orelse return err;
                self.retry_at = now + @as(u64, @intCast(delay));
                return false;
            };
        }
        return self.advance() catch |err| {
            const delay = reconnectWait(err) orelse return err;
            try self.disconnect();
            self.retry_at = now + @as(u64, @intCast(delay));
            return false;
        };
    }

    pub fn wake(self: *const Service) ?u64 {
        if (self.dbus_owner.connection == null) return self.retry_at;
        return self.deadline();
    }

    pub fn visible(self: *const Service) bool {
        return self.ui.banner.visibleNow();
    }

    pub fn deadline(self: *const Service) ?u64 {
        return if (self.ui.visible != null) self.ui.state.deadline else null;
    }

    pub fn advance(self: *Service) !bool {
        const more = try intake(&self.dbus_owner, self);
        try self.flush();
        if (self.pending.take()) |desired| {
            self.ui.apply(self.video, self.owner.allocator, self.owner.io, desired) catch |err| self.bannerFailed(err);
        }
        return more;
    }

    pub fn handleEvent(self: *Service, input: *const sdl.SDL_Event) !void {
        const closed = self.ui.event(self.owner.allocator, input) catch |err| {
            self.bannerFailed(err);
            return;
        };
        if (closed) |value| self.complete(value) catch |err| try self.recoverTurn(err);
    }

    pub fn nativeTurn(self: *Service) !void {
        if (!native_ui) return;
        const closed = self.ui.nativeTurn(self.owner.allocator) catch |err| {
            self.bannerFailed(err);
            return;
        };
        if (closed) |value| self.complete(value) catch |err| try self.recoverTurn(err);
    }

    pub fn expire(self: *Service, now: u64) !void {
        if (self.ui.banner.closed()) self.bannerFailed(error.LayerClosed);
        if (self.ui.expired(now)) |closed| self.complete(closed) catch |err| try self.recoverTurn(err);
    }

    fn recoverTurn(self: *Service, err: anyerror) !void {
        const delay = reconnectWait(err) orelse return err;
        try self.disconnect();
        self.retry_at = nowMilliseconds(self.owner.io) + @as(u64, @intCast(delay));
    }

    pub fn displayLost(self: *Service) void {
        self.bannerFailed(if (native_ui) error.NativeDisplayLost else error.SdlDisplayLost);
    }

    fn bannerFailed(self: *Service, err: anyerror) void {
        std.log.err("notification banner failed: {s}", .{@errorName(err)});
        self.ui.banner.deinit(self.video);
    }

    fn complete(self: *Service, closed: Closed) !void {
        if (!currentClose(self.owner.history.active, closed)) return;
        std.debug.assert(self.owner.close(closed.key));
        self.ui.clear(self.video, self.owner.allocator);
        try self.dbus_owner.signalClosed(closed.key.id, closed.reason);
        try self.flush();
    }

    fn notify(self: *Service, request: Request) !void {
        var accepted = self.owner.accept(request) catch |err| {
            try self.dbus_owner.replyError(switch (err) {
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
        std.debug.assert(order.marked(self.owner.durability.dirty) == .dirty);
        var owns_presentation = true;
        defer if (owns_presentation) accepted.presentation.deinit(self.owner.allocator);
        try self.dbus_owner.replyNotify(id);
        std.debug.assert(order.replied() == .reply);
        owns_presentation = false;
        self.pending.publish(accepted.presentation);
        std.debug.assert(order.published() == .publish);
        accepted = undefined;
        if (displaced) |closed| {
            try self.dbus_owner.signalClosed(closed.id, .expired);
            std.debug.assert(order.signaled() == .displaced);
        }
        std.debug.assert(order.finished() == .done);
    }

    fn close(self: *Service, id: u32) !void {
        if (activeKey(self.owner.history.active, id)) |key| {
            std.debug.assert(self.owner.close(key));
            self.pending.hide(key);
            try self.dbus_owner.signalClosed(id, .requested);
        }
        try self.dbus_owner.replyClose();
    }

    fn dispatch(self: *Service, method: Method) !void {
        switch (method) {
            .get_capabilities => try self.dbus_owner.replyCapabilities(),
            .notify => |request| try self.notify(request),
            .close => |id| try self.close(id),
            .get_server_information => try self.dbus_owner.replyServerInformation(),
        }
    }
};

// Return to the common event loop after a bounded portion of bus traffic,
// even if the socket still has more queued messages.
fn intake(bus: anytype, service: anytype) !bool {
    for (0..intake_batch_max) |_| {
        switch (try bus.next()) {
            .method => |method| try service.dispatch(method),
            .reject => |err| try bus.replyError(err),
            .ignored => {},
            .idle => return false,
            .bus_lost => return error.BusLost,
            .name_lost => return error.NameLost,
        }
    }
    return true;
}

test "bounded real intake yields after 64 messages, then drains the remainder" {
    const Bus = struct {
        remaining: usize = 65,
        dispatched: usize = 0,
        rejected: usize = 0,
        ignored_first: bool = true,

        fn next(self: *@This()) !Event {
            if (self.ignored_first) {
                self.ignored_first = false;
                return .ignored;
            }
            if (self.remaining == 0) return .idle;
            self.remaining -= 1;
            return if (self.remaining == 1) .{ .reject = .invalid_signature } else .{ .method = .get_capabilities };
        }
        fn dispatch(self: *@This(), method: Method) !void {
            try std.testing.expect(method == .get_capabilities);
            self.dispatched += 1;
        }
        fn replyError(self: *@This(), err: ReplyError) !void {
            try std.testing.expectEqual(ReplyError.invalid_signature, err);
            self.rejected += 1;
        }
    };
    var bus: Bus = .{};
    try std.testing.expect(try intake(&bus, &bus));
    try std.testing.expectEqual(@as(usize, 63), bus.dispatched);
    try std.testing.expectEqual(@as(usize, 2), bus.remaining);
    try std.testing.expect(!try intake(&bus, &bus));
    try std.testing.expectEqual(@as(usize, 64), bus.dispatched);
    try std.testing.expectEqual(@as(usize, 1), bus.rejected);
    try std.testing.expectEqual(@as(usize, 0), bus.remaining);
}

fn reconnectWait(err: anyerror) ?i64 {
    return switch (err) {
        error.BusLost, error.NameLost, error.SessionBusUnavailable => reconnect_wait_milliseconds,
        else => null,
    };
}

/// Standalone compatibility entrypoint, driven by the same sequential service
/// that the unified resident will own. When hidden, SDL is not initialized.
pub fn run(allocator: std.mem.Allocator, io: std.Io, state_home: ?[]const u8, home: ?[]const u8, env: *const std.process.Environ.Map) !void {
    const stop = try Stop.open();
    defer stop.close();
    var video: Video = .{ .env = env };
    var service = try Service.init(allocator, io, state_home, home, &video);
    defer service.deinit();
    const result = serve(&service, stop.fd);
    // Preserve the original error if a final durability attempt also fails.
    if (result) |_| {
        try service.flush();
    } else |err| {
        if (finalFlushAllowed(&service.owner.durability)) service.flush() catch |flush_error| {
            std.log.err("notification history final flush failed: {s}", .{@errorName(flush_error)});
        };
        return err;
    }
}

fn serve(service: *Service, stop_fd: std.posix.fd_t) !void {
    while (true) {
        var stopping = [_]std.posix.pollfd{.{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 }};
        if (try std.posix.poll(&stopping, 0) != 0) {
            try Stop.consume(service.owner.io, stop_fd);
            return;
        }
        service.video.pumpNative() catch |err| {
            std.log.warn("native notification display failed: {s}", .{@errorName(err)});
            service.displayLost();
        };
        try service.expire(nowMilliseconds(service.owner.io));
        try service.nativeTurn();
        const more_bus = try service.tick(nowMilliseconds(service.owner.io));
        var count: usize = 0;
        while (service.video.users != 0 and count < intake_batch_max) : (count += 1) {
            var input: sdl.SDL_Event = undefined;
            if (!sdl.SDL_PollEvent(&input)) break;
            try service.handleEvent(&input);
        }
        try service.expire(nowMilliseconds(service.owner.io));
        if (more_bus or count == intake_batch_max or (service.video.users != 0 and sdl.SDL_PollEvent(null))) continue;
        const current = nowMilliseconds(service.owner.io);
        const deadline = service.wake();
        var fds = [_]std.posix.pollfd{
            .{ .fd = stop_fd, .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = try service.fd(), .events = std.posix.POLL.IN, .revents = 0 },
            .{ .fd = if (native_ui) service.video.nativeFd() else try service.video.fd(), .events = std.posix.POLL.IN, .revents = 0 },
        };
        _ = try std.posix.poll(&fds, if (deadline) |end| @intCast(@min(end -| current, std.math.maxInt(i32))) else -1);
        if (fds[0].revents != 0) {
            try Stop.consume(service.owner.io, stop_fd);
            return;
        }
        if (fds[2].revents & (std.posix.POLL.HUP | std.posix.POLL.ERR | std.posix.POLL.NVAL) != 0) service.displayLost();
    }
}

// One private bounded session-bus connection.
const dbus_name = "org.freedesktop.Notifications";
const dbus_path = "/org/freedesktop/Notifications";
const dbus_interface = "org.freedesktop.Notifications";
const message_capacity = 64 * 1024;
const reconnect_wait_milliseconds: i64 = 250;
const send_turn_capacity = 8;
const send_wait_milliseconds = 25;

const Dbus = struct {
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

    pub fn next(native: *Dbus) !Event {
        std.debug.assert(native.connection != null);
        std.debug.assert(native.message == null);

        const connection = native.connection.?;
        if (dbus.dbus_connection_read_write(connection, 0) == 0) return .bus_lost;
        const message = dbus.dbus_connection_pop_message(connection) orelse return .idle;
        native.message = message;

        if (dbus.dbus_message_is_signal(message, dbus.DBUS_INTERFACE_DBUS, "NameLost") != 0) {
            const lost = readOneString(message) orelse {
                native.releaseMessage();
                return .ignored;
            };
            if (std.mem.eql(u8, lost, dbus_name)) return .name_lost;
            native.releaseMessage();
            return .ignored;
        }
        if (dbus.dbus_message_get_type(message) != dbus.DBUS_MESSAGE_TYPE_METHOD_CALL) {
            native.releaseMessage();
            return .ignored;
        }
        if (dbus.dbus_message_has_path(message, dbus_path) == 0 or
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
        var close_reason: dbus.dbus_uint32_t = @backingInt(reason);
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
        const terminated = try std.testing.allocator.dupeSentinel(u8, action, 0);
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
    const terminated = try std.testing.allocator.dupeSentinel(u8, key, 0);
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
