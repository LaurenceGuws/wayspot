//! Notification state owns the bounded D-Bus notification id store.

const std = @import("std");

const max_notifications: u32 = 256;
const max_app_name_bytes: u32 = 256;
const max_app_icon_bytes: u32 = 256;
const max_summary_bytes: u32 = 512;
const max_body_bytes: u32 = 4096;

comptime {
    std.debug.assert(max_notifications > 0);
    std.debug.assert(max_app_name_bytes > 0);
    std.debug.assert(max_app_icon_bytes > 0);
    std.debug.assert(max_summary_bytes > 0);
    std.debug.assert(max_body_bytes > 0);
}

/// NotifyRequest borrows bounded live notification fields for one transaction.
pub const NotifyRequest = struct {
    app_name: []const u8,
    app_icon: []const u8 = "",
    summary: []const u8,
    body: []const u8,
    replaces_id: u32 = 0,
    expire_timeout: i32 = -1,
    has_actions: bool = false,
    urgency: u8 = 1,
    transient: bool = false,
};

/// Notification owns the live fields stored under one map id.
pub const Notification = struct {
    app_name: []u8,
    app_icon: []u8,
    summary: []u8,
    body: []u8,
    expire_timeout: i32,
    has_actions: bool,
    urgency: u8,
    transient: bool,
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    map: std.AutoHashMap(u32, Notification),
    next_id: u32 = 1,
    change_active: bool = false,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{
            .allocator = allocator,
            .map = std.AutoHashMap(u32, Notification).init(allocator),
        };
    }

    pub fn deinit(self: *Store) void {
        std.debug.assert(!self.change_active);
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
        var change = try self.prepareNotify(req);
        change.commit();
        return change.id;
    }

    /// prepareNotify completes all fallible allocation and map-capacity work before
    /// changing Store. The returned change must be committed or rolled back once.
    pub fn prepareNotify(self: *Store, req: NotifyRequest) !NotifyChange {
        if (self.change_active) return error.NotificationChangePending;
        const previous_next_id = self.next_id;

        if (req.replaces_id != 0) {
            if (self.map.getPtr(req.replaces_id)) |slot| {
                const replacement = try duplicateNotification(self.allocator, req);
                self.change_active = true;
                const previous = slot.*;
                slot.* = replacement;
                return .{
                    .store = self,
                    .id = req.replaces_id,
                    .previous = previous,
                    .previous_next_id = previous_next_id,
                };
            }
        }

        if (self.len() >= max_notifications) return error.NotificationStoreFull;
        const id = try self.findFreeId();
        const replacement = try duplicateNotification(self.allocator, req);
        errdefer freeNotification(self.allocator, replacement);
        try self.map.ensureUnusedCapacity(1);

        self.change_active = true;
        self.map.putAssumeCapacity(id, replacement);
        self.next_id = nextIdAfter(id);
        return .{
            .store = self,
            .id = id,
            .previous = null,
            .previous_next_id = previous_next_id,
        };
    }

    /// close removes and frees one owned notification; false means unknown id.
    pub fn close(self: *Store, id: u32) bool {
        std.debug.assert(!self.change_active);
        const owned = self.map.fetchRemove(id) orelse return false;
        freeNotification(self.allocator, owned.value);
        return true;
    }

    fn findFreeId(self: *const Store) !u32 {
        var attempts: u32 = 0;
        var id = self.next_id;

        while (attempts < max_notifications) : (attempts += 1) {
            if (id == 0) id = 1;
            if (!self.map.contains(id)) {
                return id;
            }
            id +%= 1;
        }

        return error.NoFreeNotificationId;
    }
};

/// NotifyChange owns the previous Store row until commit or rollback.
/// Both completion paths are non-fallible and must run exactly once.
pub const NotifyChange = struct {
    store: *Store,
    id: u32,
    previous: ?Notification,
    previous_next_id: u32,
    completed: bool = false,

    /// commit releases retained previous fields after the new row is durable.
    pub fn commit(self: *NotifyChange) void {
        std.debug.assert(!self.completed);
        if (self.previous) |previous| {
            self.previous = null;
            freeNotification(self.store.allocator, previous);
        }
        self.store.change_active = false;
        self.completed = true;
    }

    /// rollback restores the old row or removes the prepared new row.
    pub fn rollback(self: *NotifyChange) void {
        std.debug.assert(!self.completed);
        if (self.previous) |previous| {
            self.previous = null;
            const slot = self.store.map.getPtr(self.id) orelse unreachable;
            const replacement = slot.*;
            slot.* = previous;
            freeNotification(self.store.allocator, replacement);
        } else {
            const removed = self.store.map.fetchRemove(self.id) orelse unreachable;
            freeNotification(self.store.allocator, removed.value);
        }
        self.store.next_id = self.previous_next_id;
        self.store.change_active = false;
        self.completed = true;
    }
};

fn nextIdAfter(id: u32) u32 {
    const next = id +% 1;
    return if (next == 0) 1 else next;
}

fn duplicateNotification(allocator: std.mem.Allocator, req: NotifyRequest) !Notification {
    const app_name = try duplicateBounded(allocator, req.app_name, max_app_name_bytes);
    errdefer allocator.free(app_name);
    const app_icon = try duplicateBounded(allocator, req.app_icon, max_app_icon_bytes);
    errdefer allocator.free(app_icon);
    const summary = try duplicateBounded(allocator, req.summary, max_summary_bytes);
    errdefer allocator.free(summary);
    const body = try duplicateBounded(allocator, req.body, max_body_bytes);
    errdefer allocator.free(body);
    return .{
        .app_name = app_name,
        .app_icon = app_icon,
        .summary = summary,
        .body = body,
        .expire_timeout = req.expire_timeout,
        .has_actions = req.has_actions,
        .urgency = req.urgency,
        .transient = req.transient,
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
    allocator.free(notification.app_icon);
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
        .app_icon = "app-icon-2",
        .summary = "summary-2",
        .body = "body-2",
        .replaces_id = id,
        .has_actions = true,
        .expire_timeout = 5000,
        .urgency = 2,
        .transient = true,
    });

    try std.testing.expectEqual(id, replaced);
    try std.testing.expectEqual(@as(u32, 1), store.len());
    const entry = store.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("app-icon-2", entry.app_icon);
    try std.testing.expectEqualStrings("summary-2", entry.summary);
    try std.testing.expectEqualStrings("body-2", entry.body);
    try std.testing.expectEqual(@as(i32, 5000), entry.expire_timeout);
    try std.testing.expect(entry.has_actions);
    try std.testing.expectEqual(@as(u8, 2), entry.urgency);
    try std.testing.expect(entry.transient);
}

test "Store replacement allocation failure preserves the previous row" {
    var failing_state = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = failing_state.allocator();
    var store = Store.init(allocator);

    const id = try store.notify(.{
        .app_name = "old-app",
        .app_icon = "old-icon",
        .summary = "old-summary",
        .body = "old-body",
        .expire_timeout = 4000,
        .has_actions = true,
        .urgency = 2,
        .transient = true,
    });
    const previous_next_id = store.next_id;
    failing_state.fail_index = failing_state.alloc_index + 1;

    try std.testing.expectError(error.OutOfMemory, store.prepareNotify(.{
        .app_name = "new-app",
        .summary = "new-summary",
        .body = "new-body",
        .replaces_id = id,
    }));
    try std.testing.expectEqual(previous_next_id, store.next_id);
    const entry = store.map.get(id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("old-app", entry.app_name);
    try std.testing.expectEqualStrings("old-icon", entry.app_icon);
    try std.testing.expectEqualStrings("old-summary", entry.summary);
    try std.testing.expectEqualStrings("old-body", entry.body);
    try std.testing.expectEqual(@as(i32, 4000), entry.expire_timeout);
    try std.testing.expect(entry.has_actions);
    try std.testing.expectEqual(@as(u8, 2), entry.urgency);
    try std.testing.expect(entry.transient);

    store.deinit();
    try std.testing.expectEqual(failing_state.allocated_bytes, failing_state.freed_bytes);
}

test "Store new allocation failure leaves id state unchanged" {
    var failing_state = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var store = Store.init(failing_state.allocator());

    try std.testing.expectError(error.OutOfMemory, store.prepareNotify(.{
        .app_name = "app",
        .summary = "summary",
        .body = "body",
    }));
    try std.testing.expectEqual(@as(u32, 0), store.len());
    try std.testing.expectEqual(@as(u32, 1), store.next_id);
    try std.testing.expect(!store.change_active);
    store.deinit();
    try std.testing.expectEqual(failing_state.allocated_bytes, failing_state.freed_bytes);
}

test "Store new capacity failure frees the prepared row" {
    var failing_state = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 4 });
    var store = Store.init(failing_state.allocator());

    try std.testing.expectError(error.OutOfMemory, store.prepareNotify(.{
        .app_name = "app",
        .app_icon = "icon",
        .summary = "summary",
        .body = "body",
    }));
    try std.testing.expectEqual(@as(u32, 0), store.len());
    try std.testing.expectEqual(@as(u32, 1), store.next_id);
    try std.testing.expect(!store.change_active);
    store.deinit();
    try std.testing.expectEqual(failing_state.allocated_bytes, failing_state.freed_bytes);
}

test "NotifyChange rollback restores and commit releases ownership" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    const id = try store.notify(.{
        .app_name = "old-app",
        .summary = "old-summary",
        .body = "old-body",
    });
    const previous_next_id = store.next_id;
    var replacement = try store.prepareNotify(.{
        .app_name = "new-app",
        .summary = "new-summary",
        .body = "new-body",
        .replaces_id = id,
    });
    try std.testing.expectEqualStrings("new-summary", store.map.get(id).?.summary);
    replacement.rollback();
    try std.testing.expectEqual(previous_next_id, store.next_id);
    try std.testing.expectEqualStrings("old-summary", store.map.get(id).?.summary);

    var new_change = try store.prepareNotify(.{
        .app_name = "second-app",
        .summary = "second-summary",
        .body = "second-body",
    });
    try std.testing.expectEqual(@as(u32, 2), new_change.id);
    new_change.commit();
    try std.testing.expectEqual(@as(u32, 2), store.len());
    try std.testing.expectEqualStrings("second-body", store.map.get(new_change.id).?.body);
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

test "store bounds retained app icon and body bytes" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();

    const exact_app_icon = [_]u8{'i'} ** max_app_icon_bytes;
    const exact_body = [_]u8{'x'} ** max_body_bytes;
    const exact_id = try store.notify(.{
        .app_name = "app",
        .app_icon = &exact_app_icon,
        .summary = "summary",
        .body = &exact_body,
    });
    const exact_entry = store.map.get(exact_id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u8, &exact_app_icon, exact_entry.app_icon);
    try std.testing.expectEqualSlices(u8, &exact_body, exact_entry.body);

    const over_app_icon = [_]u8{'j'} ** (max_app_icon_bytes + 1);
    const over_body = [_]u8{'y'} ** (max_body_bytes + 1);
    const over_id = try store.notify(.{
        .app_name = "app",
        .app_icon = &over_app_icon,
        .summary = "summary",
        .body = &over_body,
    });
    const over_entry = store.map.get(over_id) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u32, max_app_icon_bytes), @as(u32, @intCast(over_entry.app_icon.len)));
    try std.testing.expectEqualSlices(
        u8,
        over_app_icon[0 .. max_app_icon_bytes - 1],
        over_entry.app_icon[0 .. max_app_icon_bytes - 1],
    );
    try std.testing.expectEqual(@as(u8, '~'), over_entry.app_icon[max_app_icon_bytes - 1]);
    try std.testing.expectEqual(@as(u32, max_body_bytes), @as(u32, @intCast(over_entry.body.len)));
    try std.testing.expectEqualSlices(u8, over_body[0 .. max_body_bytes - 1], over_entry.body[0 .. max_body_bytes - 1]);
    try std.testing.expectEqual(@as(u8, '~'), over_entry.body[max_body_bytes - 1]);
}
