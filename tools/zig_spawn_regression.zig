//! Isolated Linux process regression. Run only as a dedicated test executable.
const std = @import("std");
const linux = std.os.linux;
const io = std.testing.io;

fn fdCount() !usize {
    var dir = try std.Io.Dir.openDirAbsolute(io, "/proc/self/fd", .{ .iterate = true });
    defer dir.close(io);
    var iter = dir.iterate();
    var count: usize = 0;
    while (try iter.next(io)) |_| count += 1;
    return count;
}

fn noChildren() !void {
    // The test executable has no unrelated children. Any successful wait
    // here witnesses a leaked failed-spawn child and also reaps it.
    var status: i32 = undefined;
    const result = linux.waitpid(-1, &status, 0);
    try std.testing.expectEqual(linux.E.CHILD, linux.errno(result));
}

fn expectFailed(
    expected: std.process.SpawnError,
    options: std.process.SpawnOptions,
) !void {
    const before = try fdCount();
    try std.testing.expectError(expected, std.process.spawn(io, options));
    const after = try fdCount();
    // Record both observations before asserting. The dedicated process
    // reaps any leaked child before returning a test failure.
    if (after != before) std.debug.print("fd count: {d} -> {d}\n", .{ before, after });
    try noChildren();
    try std.testing.expectEqual(before, after);
}

test "missing executable does not leak a child or pipes" {
    try expectFailed(error.FileNotFound, .{
        .argv = &.{"/proc/self/wayspot-no-such-executable"},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
}

test "invalid cwd does not leak a child or pipes" {
    try expectFailed(error.FileNotFound, .{
        .argv = &.{"/usr/bin/true"},
        .cwd = .{ .path = "/proc/self/wayspot-no-such-cwd" },
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
}

test "permission denied preserves the error without leaking resources" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    try fixture.dir.writeFile(io, .{
        .sub_path = "not-executable",
        .data = "#!/bin/sh\nexit 0\n",
        .flags = .{ .permissions = .fromMode(0o600) },
    });
    var root_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buf[0..try fixture.dir.realPath(io, &root_buf)];
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/not-executable", .{root});
    try expectFailed(error.AccessDenied, .{
        .argv = &.{path},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
}

test "invalid executable format preserves the error" {
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    try fixture.dir.writeFile(io, .{
        .sub_path = "bad-format",
        .data = "not an executable format\n",
        .flags = .{ .permissions = .fromMode(0o700) },
    });
    var root_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const root = root_buf[0..try fixture.dir.realPath(io, &root_buf)];
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/bad-format", .{root});
    try expectFailed(error.InvalidExe, .{
        .argv = &.{path},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
}

test "all eight pipe ownership combinations survive repeated failure" {
    for (0..8) |bits| {
        for (0..8) |_| {
            try expectFailed(error.FileNotFound, .{
                .argv = &.{"/proc/self/wayspot-no-such-executable"},
                .stdin = if (bits & 1 != 0) .pipe else .inherit,
                .stdout = if (bits & 2 != 0) .pipe else .inherit,
                .stderr = if (bits & 4 != 0) .pipe else .inherit,
            });
        }
    }
}

test "unrelated child and successful child remain caller-owned" {
    const before = try fdCount();
    var unrelated = try std.process.spawn(io, .{ .argv = &.{"/usr/bin/false"} });
    try std.testing.expectError(error.FileNotFound, std.process.spawn(io, .{
        .argv = &.{"/proc/self/wayspot-no-such-executable"},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    }));
    const result = try unrelated.wait(io);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 1 }, result);
    var success = try std.process.spawn(io, .{ .argv = &.{"/usr/bin/true"} });
    try std.testing.expect((try success.wait(io)).success());
    try noChildren();
    try std.testing.expectEqual(before, try fdCount());
}

test "successful spawn retains caller pipe ownership" {
    const before = try fdCount();
    var child = try std.process.spawn(io, .{
        .argv = &.{ "/usr/bin/printf", "exact-output" },
        .stdout = .pipe,
    });
    const stdout = child.stdout orelse return error.MissingPipe;
    var reader = stdout.reader(io, &.{});
    var output: [12]u8 = undefined;
    try reader.interface.readSliceAll(&output);
    try std.testing.expectEqualStrings("exact-output", &output);
    try std.testing.expect((try child.wait(io)).success());
    try noChildren();
    try std.testing.expectEqual(before, try fdCount());
}

test "automatic SIGCHLD reaping preserves the reported error" {
    const posix = std.posix;
    const action: posix.Sigaction = .{
        .handler = .{ .handler = posix.SIG.IGN },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    var prior: posix.Sigaction = undefined;
    posix.sigaction(.CHLD, &action, &prior);
    defer posix.sigaction(.CHLD, &prior, null);
    try expectFailed(error.FileNotFound, .{
        .argv = &.{"/proc/self/wayspot-no-such-executable"},
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
}
