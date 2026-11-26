//! One sequential event owner for independently configured desktop capabilities.
const std = @import("std");
const posix = std.posix;
const Control = @import("control.zig");
const Stop = @import("stop.zig");
const Video = @import("ui/video.zig");
const Picker = @import("picker/session.zig");
const picker = @import("picker/root.zig");
const Notification = @import("notifications/root.zig").Service;
const Wallpaper = @import("wallpaper/wayland.zig").Service;
const Watcher = @import("tray/watcher.zig").Watcher;
const sdl = @import("sdl_c");

pub const Config = struct {
    picker: bool = true,
    notifications: bool = true,
    tray: bool = true,
    wallpaper: ?[]const u8 = null,
};

pub fn signature(init: std.process.Init) ![32]u8 {
    return @import("wallpaper/wayland.zig").sessionIdentifier(init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.RuntimeDirectoryMissing, init.environ_map.get("WAYLAND_DISPLAY") orelse return error.WaylandDisplayMissing);
}

pub fn request(init: std.process.Init, command: Control.Command) !void {
    var buffer: [1024]u8 = undefined;
    const reply = try Control.call(init.io, &(try signature(init)), command, &buffer);
    if (std.mem.startsWith(u8, reply, "error:")) {
        try std.Io.File.stderr().writeStreamingAll(init.io, reply);
        return error.ResidentCommandRejected;
    }
    if (command == .status) {
        try std.Io.File.stdout().writeStreamingAll(init.io, reply);
    } else if (!std.mem.eql(u8, reply, "ok\n")) return error.ControlReceiptInvalid;
}

pub fn run(init: std.process.Init, path: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.wallpaper) |root| if (!std.fs.path.isAbsolute(root)) return error.WallpaperRootInvalid;
    if ((config.picker and !@import("picker/view.zig").Native.native_picker) or config.notifications) try Video.prepareProcess(init.io);
    const stop = try Stop.open();
    defer stop.close();
    var control = try Control.open(&(try signature(init)));
    defer control.deinit();
    var video: Video = .{ .env = init.environ_map };
    // libdbus can also be used by the existing bounded picker tray worker.
    if ((config.notifications or config.tray) and @import("dbus_c").dbus_threads_init_default() == 0) return error.DbusThreadsUnavailable;
    var notifications: ?Notification = if (config.notifications) try Notification.init(init.gpa, init.io, init.environ_map.get("XDG_STATE_HOME"), init.environ_map.get("HOME"), &video) else null;
    defer if (notifications) |*service| {
        service.flush() catch |err| std.log.err("notification final flush failed: {s}", .{@errorName(err)});
        service.deinit();
    };
    var wallpaper: ?Wallpaper = if (config.wallpaper) |root| try Wallpaper.init(init, root) else null;
    defer if (wallpaper) |*service| service.deinit();
    if (wallpaper) |*service| try service.reserveStandalone(&(try signature(init)));
    var tray: ?Watcher = if (config.tray) .{} else null;
    defer if (tray) |*service| service.close();
    if (tray) |*service| try service.open();
    var current: ?*Picker = null;
    defer closePicker(&current, .dismiss);
    var rotating = false;
    var tray_retry: ?u64 = null;
    var notification_ready = true;
    var tray_ready = true;
    var wallpaper_ready = true;
    var control_ready = true;
    var wallpaper_deadline: ?u64 = null;
    std.log.info("wayspot resident ready", .{});
    while (true) {
        const tick = now(init.io);
        var more = false;
        video.pumpNative() catch |err| {
            std.log.warn("native UI display failed: {s}", .{@errorName(err)});
            closePicker(&current, .dismiss);
            if (notifications) |*service| service.displayLost();
        };
        if (notifications) |*service| {
            if (Video.native_ui) {
                try service.expire(tick);
                try service.nativeTurn();
            }
            if (notification_ready or due(service.wake(), tick)) notification_ready = try service.tick(tick);
            more = more or notification_ready;
        } else notification_ready = false;
        if (tray) |*service| {
            if (tray_retry) |end| {
                if (tick >= end) {
                    if (service.open()) |_| {
                        tray_retry = null;
                        tray_ready = true;
                    } else |err| switch (err) {
                        error.TrayBusUnavailable => tray_retry = tick + 1000,
                        else => return err,
                    }
                }
            }
            if (tray_retry == null and tray_ready) {
                const pending = service.advance() catch |err| switch (err) {
                    error.TrayBusDisconnected => blk: {
                        service.close();
                        tray_retry = tick + 1000;
                        break :blk false;
                    },
                    else => return err,
                };
                tray_ready = pending;
                more = more or pending;
            }
        }
        const command = if (control_ready or due(control.deadline, tick)) try control.advance(tick) else null;
        control_ready = false;
        if (command) |action| {
            if (rotating) {
                control.reject(error.RotationBusy);
            } else switch (action) {
                .summon => {
                    if (!config.picker) {
                        control.reject(error.PickerDisabled);
                    } else if (current != null) {
                        control.reply("ok\n");
                    } else if (Picker.open(init, &video, config.tray)) |session| {
                        current = session;
                        control.reply("ok\n");
                    } else |err| control.reject(err);
                },
                .dismiss => {
                    if (!config.picker) {
                        control.reject(error.PickerDisabled);
                    } else {
                        if (finishPicker(&current, .dismiss)) |_| control.reply("ok\n") else |err| control.reject(err);
                    }
                },
                .rotate => {
                    if (wallpaper) |*service| {
                        if (service.request()) |_| {
                            rotating = true;
                            wallpaper_ready = true;
                        } else |err| control.reject(err);
                    } else control.reject(error.WallpaperDisabled);
                },
                .status => {
                    var buffer: [512]u8 = undefined;
                    const reply = try std.fmt.bufPrint(&buffer, "{{\"schema\":\"wayspot-resident/v1\",\"pid\":{d},\"picker\":{s},\"picker_visible\":{s},\"notifications\":{s},\"notification_visible\":{s},\"wallpaper\":{s},\"wallpaper_outputs\":{d},\"tray\":{s},\"tray_items\":{d},\"video_users\":{d},\"native_ui_users\":{d}}}\n", .{
                        std.os.linux.getpid(), boolText(config.picker), boolText(current != null), boolText(config.notifications), boolText(if (notifications) |*service| service.visible() else false), boolText(wallpaper != null), if (wallpaper) |*service| service.count() else 0, boolText(config.tray), if (tray) |*service| service.count() else 0, video.users, video.native_users,
                    });
                    control.reply(reply);
                },
            }
        }
        if (wallpaper) |*service| {
            if (wallpaper_ready or due(wallpaper_deadline, now(init.io))) {
                service.advance(stop.fd) catch |err| switch (err) {
                    error.Stopped => {
                        if (notifications) |*owner| try owner.flush();
                        return;
                    },
                    else => return err,
                };
                wallpaper_ready = false;
                const current_time = now(init.io);
                wallpaper_deadline = if (service.wake(current_time)) |delay| current_time +| delay else null;
                if (service.takeResult()) |success| {
                    if (rotating) {
                        if (success) control.reply("ok\n") else control.reject(error.RotationRejected);
                    }
                    rotating = false;
                }
            }
        } else wallpaper_ready = false;
        const ui_more = try pump(&current, &notifications, &video, init.io);
        more = more or ui_more;
        if (notifications) |*service| {
            try service.expire(now(init.io));
            try service.nativeTurn();
        }
        const time = now(init.io);
        var timeout: ?u64 = if (more) 0 else null;
        if (notifications) |*service| if (service.wake()) |end| shorten(&timeout, end -| time);
        if (wallpaper_deadline) |end| shorten(&timeout, end -| time);
        if (tray_retry) |end| shorten(&timeout, end -| time);
        if (control.deadline) |end| shorten(&timeout, end -| time);
        if (current) |session| {
            shorten(&timeout, session.deadline -| time);
            if (session.view.hasPendingDraw()) shorten(&timeout, 0);
            if (session.repeatWake()) |delay| shorten(&timeout, delay);
        }
        var fds = [_]posix.pollfd{
            pollFd(stop.fd),
            pollFd(control.listener),
            pollFd(control.client),
            pollFd(if (notifications) |*service| try service.fd() else -1),
            pollFd(if (tray) |*service| try service.fd() else -1),
            if (wallpaper) |*service| service.pollFd() else pollFd(-1),
            pollFd(try video.fd()),
            pollFd(if (current) |session| session.view.tray_wake_fd else -1),
            pollFd(video.nativeFd()),
        };
        _ = try posix.poll(&fds, if (timeout) |delay| @intCast(@min(delay, std.math.maxInt(i32))) else -1);
        if (fds[0].revents != 0) {
            try Stop.consume(init.io, stop.fd);
            if (notifications) |*service| try service.flush();
            return;
        }
        control_ready = fds[1].revents != 0 or fds[2].revents != 0;
        notification_ready = notification_ready or fds[3].revents != 0;
        tray_ready = tray_ready or fds[4].revents != 0;
        wallpaper_ready = fds[5].revents != 0;
        if (fds[6].revents & (posix.POLL.HUP | posix.POLL.ERR | posix.POLL.NVAL) != 0) {
            if (!@import("picker/view.zig").Native.native_picker) closePicker(&current, .dismiss);
            if (notifications) |*service| service.displayLost();
        }
    }
}

fn pump(current: *?*Picker, notifications: *?Notification, video: *Video, io: std.Io) !bool {
    var batch: picker.Events = .{};
    var received: usize = 0;
    while (video.users != 0 and received < picker.event_capacity) : (received += 1) {
        var input: sdl.SDL_Event = undefined;
        if (!sdl.SDL_PollEvent(&input)) break;
        if (notifications.*) |*service| try service.handleEvent(&input);
        if (current.*) |session| {
            if (@import("picker/view.zig").Native.native_picker) continue;
            batch.items[batch.count] = session.view.handleEvent(input) catch |err| {
                std.log.warn("picker input failed: {s}", .{@errorName(err)});
                closePicker(current, .dismiss);
                continue;
            };
            batch.count += 1;
        }
    }
    var more = received == picker.event_capacity or (video.users != 0 and sdl.SDL_PollEvent(null));
    if (current.*) |session| {
        session.view.nativeEvents(&batch) catch |err| {
            std.log.warn("native picker input failed: {s}", .{@errorName(err)});
            closePicker(current, .dismiss);
            return more;
        };
        more = more or batch.more;
        if (session.view.closed()) {
            closePicker(current, .dismiss);
            return more;
        }
        batch.more = more;
        const ready = if (batch.count < batch.items.len) session.trayReady() catch |err| {
            std.log.warn("picker tray wake failed: {s}", .{@errorName(err)});
            closePicker(current, .dismiss);
            return more;
        } else false;
        const timer_due = now(io) >= session.deadline;
        if (batch.count < batch.items.len and (ready or timer_due)) {
            batch.items[batch.count] = if (ready) .redraw else session.view.onDeadline();
            batch.count += 1;
        }
        const action = session.advance(&batch) catch |err| {
            std.log.warn("picker transition failed: {s}", .{@errorName(err)});
            closePicker(current, .dismiss);
            return more;
        };
        switch (action) {
            .wait => if (timer_due) {
                session.deadline = now(io) + @as(u64, @intCast(session.view.waitTimeout()));
            },
            .draw => {},
            .dismiss => closePicker(current, .dismiss),
            .launch, .focus => closePicker(current, action),
        }
    }
    return more;
}

fn finishPicker(current: *?*Picker, selected: picker.Action) !void {
    const session = current.* orelse return;
    current.* = null;
    try session.finish(selected);
}

fn closePicker(current: *?*Picker, selected: picker.Action) void {
    const init = if (current.*) |session| session.process else return;
    finishPicker(current, selected) catch |err| {
        if (selected == .focus) @import("picker/navigator.zig").reportFailure(init, err) else std.log.err("picker finish failed: {s}", .{@errorName(err)});
    };
}

fn due(deadline: ?u64, tick: u64) bool {
    return if (deadline) |end| tick >= end else false;
}

fn boolText(value: bool) []const u8 {
    return if (value) "true" else "false";
}
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.awake.now(io).toMilliseconds());
}
fn pollFd(fd: posix.fd_t) posix.pollfd {
    return .{ .fd = fd, .events = posix.POLL.IN, .revents = 0 };
}
fn shorten(timeout: *?u64, delay: u64) void {
    timeout.* = if (timeout.*) |old| @min(old, delay) else delay;
}

test "capability configuration is strict and individually optional" {
    const value = try std.json.parseFromSlice(Config, std.testing.allocator, "{\"picker\":false,\"notifications\":false,\"tray\":false,\"wallpaper\":null}", .{});
    defer value.deinit();
    try std.testing.expect(!value.value.picker and !value.value.notifications and !value.value.tray and value.value.wallpaper == null);
    try std.testing.expectError(error.UnknownField, std.json.parseFromSlice(Config, std.testing.allocator, "{\"unknown\":true}", .{}));
}
