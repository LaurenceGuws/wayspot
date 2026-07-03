//! Notification state owns the bounded D-Bus notification id store.

const std = @import("std");

const max_notifications: u32 = 256;
const max_app_name_bytes: u32 = 256;
const max_summary_bytes: u32 = 512;
const max_body_bytes: u32 = 4096;

comptime {
    std.debug.assert(max_notifications > 0);
    std.debug.assert(max_app_name_bytes > 0);
    std.debug.assert(max_summary_bytes > 0);
    std.debug.assert(max_body_bytes > 0);
}

pub const NotifyRequest = struct {
    app_name: []const u8,
    summary: []const u8,
    body: []const u8,
    replaces_id: u32 = 0,
    expire_timeout: i32 = -1,
    has_actions: bool = false,
};

pub const Notification = struct {
    app_name: []u8,
    summary: []u8,
    body: []u8,
    expire_timeout: i32,
    has_actions: bool,
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    map: std.AutoHashMap(u32, Notification),
    next_id: u32 = 1,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{
            .allocator = allocator,
            .map = std.AutoHashMap(u32, Notification).init(allocator),
        };
    }

    pub fn deinit(self: *Store) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            freeNotification(self.allocator, entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn len(self: *const Store) u32 {
        return @intCast(self.map.count());
    }

    pub fn notify(self: *Store, req: NotifyRequest) !u32 {
        if (req.replaces_id != 0 and self.map.getPtr(req.replaces_id) != null) {
            try self.replace(req.replaces_id, req);
            return req.replaces_id;
        }
        if (self.len() >= max_notifications) return error.NotificationStoreFull;

        const id = try self.allocateId();
        try self.map.put(id, try duplicateNotification(self.allocator, req));
        return id;
    }

    pub fn close(self: *Store, id: u32) bool {
        const owned = self.map.fetchRemove(id) orelse return false;
        freeNotification(self.allocator, owned.value);
        return true;
    }

    fn replace(self: *Store, id: u32, req: NotifyRequest) !void {
        const slot = self.map.getPtr(id) orelse return;
        freeNotification(self.allocator, slot.*);
        slot.* = try duplicateNotification(self.allocator, req);
    }

    fn allocateId(self: *Store) !u32 {
        var attempts: u32 = 0;
        var id = self.next_id;

        while (attempts < max_notifications) : (attempts += 1) {
            if (id == 0) id = 1;
            if (!self.map.contains(id)) {
                self.next_id = id +% 1;
                if (self.next_id == 0) self.next_id = 1;
                return id;
            }
            id +%= 1;
        }

        return error.NoFreeNotificationId;
    }
};

fn duplicateNotification(allocator: std.mem.Allocator, req: NotifyRequest) !Notification {
    return .{
        .app_name = try duplicateBounded(allocator, req.app_name, max_app_name_bytes),
        .summary = try duplicateBounded(allocator, req.summary, max_summary_bytes),
        .body = try duplicateBounded(allocator, req.body, max_body_bytes),
        .expire_timeout = req.expire_timeout,
        .has_actions = req.has_actions,
    };
}

fn duplicateBounded(allocator: std.mem.Allocator, text: []const u8, max_bytes: u32) ![]u8 {
    const out_len = @min(text.len, max_bytes);
    const out = try allocator.dupe(u8, text[0..out_len]);
    if (text.len > out_len and out_len > 0) out[out_len - 1] = '~';
    return out;
}

fn freeNotification(allocator: std.mem.Allocator, notification: Notification) void {
    allocator.free(notification.app_name);
    allocator.free(notification.summary);
    allocator.free(notification.body);
}

test "store notify allocates ids and close removes" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    const first = try store.notify(.{
        .app_name = "app-a",
        .summary = "hello",
        .body = "body-a",
    });
    const second = try store.notify(.{
        .app_name = "app-b",
        .summary = "world",
        .body = "body-b",
    });

    try std.testing.expectEqual(@as(u32, 1), first);
    try std.testing.expectEqual(@as(u32, 2), second);
    try std.testing.expectEqual(@as(u32, 2), store.len());

    try std.testing.expect(store.close(first));
    try std.testing.expectEqual(@as(u32, 1), store.len());
    try std.testing.expect(!store.close(first));
}

test "store notify replaces existing id" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    const id = try store.notify(.{
        .app_name = "app-a",
        .summary = "summary-1",
        .body = "body-1",
    });

    const replaced = try store.notify(.{
        .app_name = "app-a",
        .summary = "summary-2",
        .body = "body-2",
        .replaces_id = id,
        .has_actions = true,
        .expire_timeout = 5000,
    });

    try std.testing.expectEqual(id, replaced);
    try std.testing.expectEqual(@as(u32, 1), store.len());
    const entry = store.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("summary-2", entry.summary);
    try std.testing.expectEqualStrings("body-2", entry.body);
    try std.testing.expectEqual(@as(i32, 5000), entry.expire_timeout);
    try std.testing.expect(entry.has_actions);
}

test "store refuses more than retained notification bound" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    var id: u32 = 0;
    while (id < max_notifications) : (id += 1) {
        const stored = try store.notify(.{
            .app_name = "app",
            .summary = "summary",
            .body = "body",
        });
        try std.testing.expectEqual(id + 1, stored);
    }

    try std.testing.expectError(error.NotificationStoreFull, store.notify(.{
        .app_name = "app",
        .summary = "summary",
        .body = "body",
    }));
}

test "store bounds retained body bytes" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    const body = [_]u8{'x'} ** (max_body_bytes + 1);
    const id = try store.notify(.{
        .app_name = "app",
        .summary = "summary",
        .body = &body,
    });

    const entry = store.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u32, max_body_bytes), @as(u32, @intCast(entry.body.len)));
    try std.testing.expectEqual(@as(u8, '~'), entry.body[entry.body.len - 1]);
}
