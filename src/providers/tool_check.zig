const std = @import("std");

var cache_lock: std.Io.Mutex = .init;
var cache: std.StringHashMapUnmanaged(bool) = .empty;
var command_exists_runner: *const fn (name: []const u8) bool = commandExistsViaShell;

pub fn commandExists(name: []const u8) bool {
    return commandExistsCached(name);
}

pub fn commandExistsCached(name: []const u8) bool {
    cache_lock.lockUncancelable(std.Options.debug_io);
    if (cache.get(name)) |value| {
        cache_lock.unlock(std.Options.debug_io);
        return value;
    }
    cache_lock.unlock(std.Options.debug_io);

    const value = command_exists_runner(name);

    cache_lock.lockUncancelable(std.Options.debug_io);
    defer cache_lock.unlock(std.Options.debug_io);
    if (cache.get(name)) |existing| return existing;
    const key = std.heap.page_allocator.dupe(u8, name) catch return value;
    cache.put(std.heap.page_allocator, key, value) catch {
        std.heap.page_allocator.free(key);
        return value;
    };
    return value;
}

pub fn invalidateCache() void {
    clearCacheLocked();
}

fn commandExistsViaShell(name: []const u8) bool {
    var child = std.process.spawn(std.Options.debug_io, .{
        .argv = &.{ "sh", "-lc", "command -v \"$1\" >/dev/null 2>&1", "_", name },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch return false;
    const term = child.wait(std.Options.debug_io) catch return false;
    return term == .exited and term.exited == 0;
}

fn clearCacheForTests() void {
    invalidateCache();
}

fn clearCacheLocked() void {
    cache_lock.lockUncancelable(std.Options.debug_io);
    defer cache_lock.unlock(std.Options.debug_io);

    var it = cache.iterator();
    while (it.next()) |entry| {
        std.heap.page_allocator.free(entry.key_ptr.*);
    }
    cache.deinit(std.heap.page_allocator);
    cache = .empty;
}

test "commandExistsCached reuses prior command result for repeated checks" {
    const Fake = struct {
        var calls: u32 = 0;

        fn run(name: []const u8) bool {
            calls += 1;
            return std.mem.eql(u8, name, "present");
        }
    };

    clearCacheForTests();
    command_exists_runner = Fake.run;
    defer {
        command_exists_runner = commandExistsViaShell;
        clearCacheForTests();
    }

    try std.testing.expect(commandExistsCached("present"));
    try std.testing.expect(commandExistsCached("present"));
    try std.testing.expectEqual(@as(u32, 1), Fake.calls);
}

test "commandExistsCached tracks each command key independently" {
    const Fake = struct {
        var calls: u32 = 0;

        fn run(name: []const u8) bool {
            calls += 1;
            return std.mem.eql(u8, name, "alpha");
        }
    };

    clearCacheForTests();
    command_exists_runner = Fake.run;
    defer {
        command_exists_runner = commandExistsViaShell;
        clearCacheForTests();
    }

    try std.testing.expect(commandExistsCached("alpha"));
    try std.testing.expect(!commandExistsCached("beta"));
    try std.testing.expect(commandExistsCached("alpha"));
    try std.testing.expect(!commandExistsCached("beta"));
    try std.testing.expectEqual(@as(u32, 2), Fake.calls);
}
