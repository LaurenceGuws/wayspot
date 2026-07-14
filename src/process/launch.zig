//! Process launch owns one resolved leaf intent from fork through wrapper wait.
//!
//! The input is already resolved by Cmd and is never parsed or rebuilt here.
//! This owner performs the existing detached /bin/sh handoff, keeps the child
//! lifecycle errors exact, and exposes no GUI, CLI, or Cmd types.

const std = @import("std");

/// max_intent_bytes bounds one resolved executable leaf intent.
pub const max_intent_bytes: usize = 4096;
/// max_wait_interrupts bounds EINTR retries while waiting for the launcher wrapper.
pub const max_wait_interrupts: u32 = 16;
const launch_child_fail_code: u8 = 127;

/// LaunchError is the exact process-boundary failure vocabulary.
pub const LaunchError = error{
    EmptyIntent,
    IntentTooLong,
    IntentContainsNul,
    CommandFailed,
    ForkFailed,
    WaitFailed,
    WaitInterruptedTooOften,
};

const Fork = *const fn () LaunchError!std.c.pid_t;
const WaitResult = enum {
    completed,
    interrupted,
    failed,
};
const WaitPid = *const fn (std.c.pid_t, *i32) WaitResult;

comptime {
    std.debug.assert(max_intent_bytes > 0);
    std.debug.assert(max_wait_interrupts > 0);
    std.debug.assert(launch_child_fail_code > 0);
}

/// runDetached validates one bounded resolved intent, constructs its sentinel
/// copy, starts the detached shell, and waits only for the launcher wrapper to
/// establish the child session. The caller retains ownership of `intent`.
pub fn runDetached(intent: []const u8) LaunchError!void {
    return runDetachedWithFork(intent, launchFork);
}

/// runDetachedWithFork keeps validation, sentinel construction, and the fork
/// failure path deterministic in unit tests.
fn runDetachedWithFork(intent: []const u8, fork: Fork) LaunchError!void {
    var intent_buf: [max_intent_bytes + 1]u8 = undefined;
    const intent_z = try copyIntent(&intent_buf, intent);

    const wrapper_pid = try fork();
    if (wrapper_pid == 0) launchChild(intent_z.ptr);
    try launchWait(wrapper_pid);
}

/// copyIntent rejects invalid resolved intent bytes and creates the only
/// sentinel representation used by the shell and child lifecycle.
fn copyIntent(intent_buf: *[max_intent_bytes + 1]u8, intent: []const u8) LaunchError![:0]const u8 {
    if (intent.len == 0) return error.EmptyIntent;
    if (intent.len > max_intent_bytes) return error.IntentTooLong;
    if (std.mem.indexOfScalar(u8, intent, 0) != null) return error.IntentContainsNul;

    @memcpy(intent_buf[0..intent.len], intent);
    intent_buf[intent.len] = 0;
    return intent_buf[0..intent.len :0];
}

/// launchChild creates a new session, forks the application shell, and exits
/// the short-lived wrapper so the caller never owns the detached application.
/// The sentinel pointer is owned and constructed by runDetachedWithFork.
fn launchChild(intent: [*:0]const u8) noreturn {
    if (!launchRedirectStdio()) std.c._exit(launch_child_fail_code);

    const session_id = std.c.setsid();
    if (session_id == -1) std.c._exit(launch_child_fail_code);

    const app_pid = launchFork() catch std.c._exit(launch_child_fail_code);
    if (app_pid == 0) launchExecShell(intent);

    std.c._exit(0);
}

/// launchExecShell executes the already-resolved intent without changing it.
fn launchExecShell(intent: [*:0]const u8) noreturn {
    const shell_path = "/bin/sh";
    const shell_name = "sh";
    const shell_arg = "-lc";
    const argv: [4:null]?[*:0]const u8 = .{
        shell_name,
        shell_arg,
        intent,
        null,
    };
    const exec_rc = std.c.execve(shell_path, &argv, std.c.environ);
    if (exec_rc == -1) std.c._exit(launch_child_fail_code);
    std.c._exit(launch_child_fail_code);
}

/// launchRedirectStdio gives a detached child no inherited terminal streams.
fn launchRedirectStdio() bool {
    const dev_null = std.c.open("/dev/null", .{ .ACCMODE = .RDWR, .CLOEXEC = false });
    if (dev_null == -1) return false;

    const stdin_rc = std.c.dup2(dev_null, 0);
    const stdout_rc = std.c.dup2(dev_null, 1);
    const stderr_rc = std.c.dup2(dev_null, 2);
    const close_rc = std.c.close(dev_null);
    if (stdin_rc == -1) return false;
    if (stdout_rc == -1) return false;
    if (stderr_rc == -1) return false;
    if (close_rc == -1) return false;
    return true;
}

/// launchFork maps one OS fork failure into the process boundary error.
fn launchFork() LaunchError!std.c.pid_t {
    const pid = std.c.fork();
    if (pid == -1) return error.ForkFailed;
    return pid;
}

/// launchWait waits for the launcher wrapper with the named EINTR bound.
fn launchWait(pid: std.c.pid_t) LaunchError!void {
    return launchWaitWith(pid, waitPid);
}

/// launchWaitWith keeps retry accounting independent and directly testable.
fn launchWaitWith(pid: std.c.pid_t, wait_pid: WaitPid) LaunchError!void {
    std.debug.assert(pid > 0);
    var status: i32 = 0;
    var interrupts: u32 = 0;
    while (interrupts < max_wait_interrupts) {
        switch (wait_pid(pid, &status)) {
            .completed => break,
            .interrupted => interrupts += 1,
            .failed => return error.WaitFailed,
        }
    } else {
        return error.WaitInterruptedTooOften;
    }

    const status_bits: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(status_bits)) return error.CommandFailed;
    if (std.c.W.EXITSTATUS(status_bits) != 0) return error.CommandFailed;
}

/// waitPid maps one waitpid result to the bounded wait state machine.
fn waitPid(pid: std.c.pid_t, status: *i32) WaitResult {
    const waited = std.c.waitpid(pid, status, 0);
    if (waited == pid) return .completed;
    if (waited == -1) {
        const errno = std.c._errno().*;
        if (errno == @intFromEnum(std.c.E.INTR)) return .interrupted;
    }
    return .failed;
}

fn forkFailureForTest() LaunchError!std.c.pid_t {
    return error.ForkFailed;
}

fn waitInterruptedForTest(_: std.c.pid_t, _: *i32) WaitResult {
    return .interrupted;
}

fn waitFailedForTest(_: std.c.pid_t, _: *i32) WaitResult {
    return .failed;
}

test "runDetached launches a bounded resolved intent" {
    try runDetached(":");
}

test "runDetached rejects empty, NUL, and overlong intents before fork" {
    try std.testing.expectError(error.EmptyIntent, runDetachedWithFork("", forkFailureForTest));
    try std.testing.expectError(error.IntentContainsNul, runDetachedWithFork("echo\x00hidden", forkFailureForTest));

    var overlong: [max_intent_bytes + 2]u8 = undefined;
    @memset(overlong[0 .. max_intent_bytes + 1], 'x');
    overlong[max_intent_bytes + 1] = 0;
    try std.testing.expectError(error.IntentTooLong, runDetachedWithFork(overlong[0 .. max_intent_bytes + 1], forkFailureForTest));
}

test "runDetached accepts the exact maximum intent before fork" {
    var exact: [max_intent_bytes]u8 = undefined;
    @memset(&exact, 'x');
    try std.testing.expectError(error.ForkFailed, runDetachedWithFork(&exact, forkFailureForTest));
}

test "fork failure maps before child creation" {
    try std.testing.expectError(error.ForkFailed, runDetachedWithFork(":", forkFailureForTest));
}

test "wait reports successful child exit" {
    const pid = try launchFork();
    if (pid == 0) std.c._exit(0);
    try launchWait(pid);
}

test "wait reports child failure" {
    const pid = try launchFork();
    if (pid == 0) std.c._exit(1);
    try std.testing.expectError(error.CommandFailed, launchWait(pid));
}

test "wait interruption reaches its explicit bound" {
    try std.testing.expectError(error.WaitInterruptedTooOften, launchWaitWith(1, waitInterruptedForTest));
}

test "wait failure maps to the exact process error" {
    try std.testing.expectError(error.WaitFailed, launchWaitWith(1, waitFailedForTest));
}
