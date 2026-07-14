#!/usr/bin/env bash
set -euo pipefail

# This receipt runs the rerun PID policy against temporary pause processes.
# Its fake pgrep list excludes every process outside this receipt, so the live
# desktop residents and unrelated processes cannot be selected or signaled.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
notification_pids="$tmp_dir/notification-pids"
wallpaper_pids="$tmp_dir/wallpaper-pids"
wallpaper_pid_file="$tmp_dir/wallpaper.pid"
sentinel_pid=""
last_pid=""
declare -a helper_pids=()

cleanup() {
    local pid
    for pid in "${helper_pids[@]}"; do
        if pid_has_canonical_mode "$pid" notifications ||
            pid_has_legacy_mode "$pid" notifications ||
            pid_has_canonical_mode "$pid" wallpaper ||
            pid_has_legacy_mode "$pid" wallpaper; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
        wait "$pid" 2>/dev/null || true
    done
    if [[ -n "$sentinel_pid" ]]; then
        kill "$sentinel_pid" 2>/dev/null || true
        wait "$sentinel_pid" 2>/dev/null || true
    fi
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$fake_bin"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'case "$*" in' \
    '    *wayspot-notify*) cat "$RERUN_RECEIPT_NOTIFICATION_PIDS" ;;' \
    '    *wayspot-wall*) cat "$RERUN_RECEIPT_WALLPAPER_PIDS" ;;' \
    '    *) exit 1 ;;' \
    'esac' >"$fake_bin/pgrep"
chmod +x "$fake_bin/pgrep"
: >"$notification_pids"
: >"$wallpaper_pids"

cat >"$tmp_dir/helper.c" <<'EOF'
#include <signal.h>
#include <string.h>
#include <sys/prctl.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *comm;
    if (argc != 2) return 2;
    if (strcmp(argv[1], "notifications") == 0 ||
        strcmp(argv[1], "--notifications-daemon") == 0) {
        comm = "wayspot-notify";
    } else if (strcmp(argv[1], "wallpaper") == 0 ||
               strcmp(argv[1], "--wallpaper") == 0) {
        comm = "wayspot-wall";
    } else {
        return 3;
    }
    if (prctl(PR_SET_NAME, comm, 0, 0, 0) != 0) return 4;
    for (;;) pause();
}
EOF
cc -O0 -o "$tmp_dir/helper" "$tmp_dir/helper.c"

export RERUN_RECEIPT_NOTIFICATION_PIDS="$notification_pids"
export RERUN_RECEIPT_WALLPAPER_PIDS="$wallpaper_pids"
export PATH="$fake_bin:$PATH"
source <(sed '/^echo "\[re-run\] building:/,$d' "$root/re-run.sh")

start_helper() {
    local argument="$1"

    ((${#helper_pids[@]} < 8)) || exit 1
    bash -c 'exec -a wayspot "$1" "$2"' bash "$tmp_dir/helper" "$argument" >/dev/null 2>&1 &
    last_pid="$!"
    helper_pids+=("$last_pid")
}

assert_gone() {
    local pid="$1"
    wait "$pid" 2>/dev/null || true
    if kill -0 "$pid" 2>/dev/null; then
        echo "helper pid remains alive: $pid" >&2
        exit 1
    fi
}

start_helper --notifications-daemon
legacy_notification_pid="$last_pid"
printf '%s\n' "$legacy_notification_pid" >"$notification_pids"
stop_matching_mode_pids notifications legacy
assert_gone "$legacy_notification_pid"

start_helper --wallpaper
legacy_wallpaper_pid="$last_pid"
printf '%s\n' "$legacy_wallpaper_pid" >"$wallpaper_pids"
printf '%s\n' "$legacy_wallpaper_pid" >"$wallpaper_pid_file"
stop_matching_wallpaper_pids "$wallpaper_pid_file" legacy
assert_gone "$legacy_wallpaper_pid"

start_helper notifications
canonical_notification_pid="$last_pid"
printf '%s\n' "$canonical_notification_pid" >"$notification_pids"
stop_matching_mode_pids notifications canonical
assert_gone "$canonical_notification_pid"

start_helper wallpaper
canonical_wallpaper_pid="$last_pid"
printf '%s\n' "$canonical_wallpaper_pid" >"$wallpaper_pids"
printf '%s\n' "$canonical_wallpaper_pid" >"$wallpaper_pid_file"
stop_matching_wallpaper_pids "$wallpaper_pid_file" canonical
assert_gone "$canonical_wallpaper_pid"

/bin/sleep 60 &
sentinel_pid="$!"

printf '%s\n' malformed >"$notification_pids"
if collect_mode_pids notifications legacy; then
    echo "malformed PID record was accepted" >&2
    exit 1
fi

printf '%s\n' "$$" >"$notification_pids"
stale_records="$(collect_mode_pids notifications legacy)"
[[ -z "$stale_records" ]] || {
    echo "stale PID record was returned" >&2
    exit 1
}
kill -0 "$sentinel_pid"

start_helper --notifications-daemon
duplicate_pid="$last_pid"
printf '%s\n%s\n' "$duplicate_pid" "$duplicate_pid" >"$notification_pids"
if collect_mode_pids notifications legacy; then
    echo "duplicate PID records were accepted" >&2
    exit 1
fi

: >"$notification_pids"
for pid in 100000 100001 100002 100003 100004 100005 100006 100007 100008; do
    printf '%s\n' "$pid" >>"$notification_pids"
done
if collect_mode_pids notifications legacy; then
    echo "over-bound PID records were accepted" >&2
    exit 1
fi

printf '%s\n' malformed >"$wallpaper_pid_file"
: >"$wallpaper_pids"
collect_wallpaper_pids "$wallpaper_pid_file" legacy
[[ ! -e "$wallpaper_pid_file" ]] || {
    echo "malformed wallpaper PID file was retained" >&2
    exit 1
}

printf '%s\n' "isolated rerun PID receipt passed"
