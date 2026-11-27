# Zig 0.17.0: failed-spawn ownership correction

This is an opt-in, version-pinned correction to Zig's standard library, not a
second Wayspot launcher or a vendored compiler. The normal build and Arch
package still use stock Zig unless a patched library is explicitly selected.

## Defect and scope

In `std/Io/Threaded.zig`, `processSpawnPosix` returns the reported pre-exec
error without returning a Child handle or reaping its child. Parent-side stdio
pipes are also left open. Wayspot's long-lived resident can encounter this
when its existing detached helper fails to start, for example with an invalid
working directory. The same branch was present at upstream Codeberg HEAD
`12b7d895004c43591427b771f7c36f826fba6996` when inspected on 2026-11-27.

The patch closes the three optional parent pipe handles, then waits only for
the failed spawn's exact PID, without sending a signal or permitting
cancellation of the cleanup. EINTR retries; ECHILD allows automatic SIGCHLD
reaping. An unexpected wait error is diagnosed without replacing the original
spawn error. Successful spawning and the existing ambiguous error-pipe
handling are unchanged. Progress IPC remains owned by the progress node.

The source is Zig, distributed under its MIT license (LICENSE.zig).
The patch is qualified on Linux x86_64 with and without libc. Other OS and
architecture branches, progress IPC and unexpected wait errors have not been
independently exercised. This does not repair unrelated cancellation or
process lifecycle defects.

## Reproduce with an independent library copy

From the Wayspot repository, use the official pinned Zig 0.17.0.
Inspect the original library path with `env -u ZIG_LIB_DIR zig env`.
Set `stock_lib` to that reported directory and `scratch_root` to an existing
private scratch directory outside the installed compiler.

```bash
set -euo pipefail
test "$(zig version)" = 0.17.0
scratch=$(mktemp -d "$scratch_root/wayspot-zig.XXXXXX")
printf '%s  %s\n' \
    1a770001e309f24c8c58a9fdb3c095994c454cbfa9dba9d4f1dede2f134eeac7 \
    "$stock_lib/std/Io/Threaded.zig" | sha256sum -c -
cp -a --reflink=auto "$stock_lib" "$scratch/lib"
test ! -L "$scratch/lib/std/Io/Threaded.zig"
patch --batch --forward --fuzz=0 -p1 -d "$scratch" \
    < patches/zig-0.17.0/spawn-failure-cleanup.patch
printf '%s  %s\n' \
    b3c473598e524c572cfb286bc219d33485dfeb4ba9270e5f713d76080d90a7ea \
    "$scratch/lib/std/Io/Threaded.zig" | sha256sum -c -
export ZIG_LIB_DIR="$scratch/lib"
zig env
```

The exact preimage hash is mandatory: the small zero-context patch is specific
to these bytes, not a patch to apply blindly to another compiler release.

## Qualification

These opt-in tests must run in dedicated test processes; their ownership
probes deliberately wait for any leftover child after the known children
have been retired. No such broad wait is introduced into Wayspot or the patch.
The tests are included in the formatting and zig-audit scopes but not the
ordinary stock-library test graph, because stock Zig is expected to fail.

```bash
for mode in Debug ReleaseSafe ReleaseFast; do
    zig test tools/zig_spawn_regression.zig -lc -O "$mode" -fno-llvm -fno-lld
done
zig test tools/zig_spawn_regression.zig -O ReleaseSafe -fno-llvm -fno-lld
zig test -O ReleaseSafe -lc -fno-llvm -fno-lld \
    --dep launch -Mroot=tools/zig_spawn_detached_regression.zig \
    -Mlaunch=src/apps/launch.zig
zig build check -j2 --summary all
zig build -j2 --prefix "$scratch/candidate" --summary all
```

For deterministic wait interruption, the following test-only libc interposer
returns EINTR once on the first positive-PID wait4 and records its next retry.
It is not linked or loaded into the product.

```bash
cc -shared -fPIC -Wall -Wextra -Werror patches/zig-0.17.0/eintr.c \
    -ldl -o "$scratch/eintr.so"
zig test tools/zig_spawn_regression.zig -lc -O ReleaseSafe -fno-llvm -fno-lld \
    --test-filter 'missing executable' --test-no-exec \
    -femit-bin="$scratch/eintr-test"
LD_PRELOAD="$scratch/eintr.so" "$scratch/eintr-test"
```

The injected and retried PID lines must match and the test must pass.
On the original library the failure tests leave waitable children and/or
increased descriptor counts; the successful pipe test remains green.
Retire this local patch once a replacement Zig release passes the same
regression without it. Do not modify the shared compiler installation as a
side effect of this experiment.
