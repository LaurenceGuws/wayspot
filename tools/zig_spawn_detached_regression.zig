const std = @import("std");
const launch = @import("launch");
const linux = std.os.linux;

test "Wayspot detached adapter owns no failed helper child" {
    var env = std.process.Environ.Map.init(std.testing.allocator);
    defer env.deinit();
    var adapter: launch.Detached = .{ .io = std.testing.io, .environ_map = &env };
    try std.testing.expectError(error.FileNotFound, adapter.spawn(
        &.{"/usr/bin/true"},
        "/proc/self/wayspot-no-such-cwd",
    ));
    var status: i32 = undefined;
    // Only this dedicated process's single failed helper is eligible to wait.
    try std.testing.expectEqual(linux.E.CHILD, linux.errno(linux.waitpid(-1, &status, 0)));
}
