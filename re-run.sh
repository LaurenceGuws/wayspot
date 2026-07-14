#!/usr/bin/env bash
set -euo pipefail

# Rebuild, install the local binary, and start only canonical Wayspot entries.
#
# The two old resident argv forms are accepted only during exact stop/cleanup
# before a canonical start. They are never launched and never treated as a
# resident identity after the transition.
#
# Optional overrides:
#   RERUN_BUILD_FLAGS="-Doptimize=ReleaseSafe"
#   RERUN_BIN="./zig-out/bin/wayspot"
#   RERUN_INSTALL_BIN="$HOME/.local/bin/wayspot"
#   RERUN_NOTIFICATIONS=true
#   RERUN_WALLPAPER=true
#   RERUN_UI=false

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

: "${RERUN_BUILD_FLAGS:=-Doptimize=ReleaseSafe}"
: "${RERUN_BIN:=./zig-out/bin/wayspot}"
: "${RERUN_INSTALL_BIN:=$HOME/.local/bin/wayspot}"
: "${RERUN_NOTIFICATIONS:=true}"
: "${RERUN_WALLPAPER:=true}"
: "${RERUN_UI:=true}"

readonly max_pid_candidates=8
readonly max_pid_argv=4
readonly max_pid_value=4194304
readonly max_wait_cycles=40

read -r -a build_flags <<<"$RERUN_BUILD_FLAGS"

sync_binary() {
    local src="$1"
    local dst="$2"
    local tmp="${dst}.tmp.$$"

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$tmp"
    chmod +x "$tmp"
    mv -f "$tmp" "$dst"
}

valid_pid() {
    local pid="$1"

    [[ "$pid" =~ ^[1-9][0-9]{0,6}$ ]] || return 1
    ((10#$pid <= max_pid_value))
}

read_proc_argv() {
    local pid="$1"
    local array_name="$2"
    local -n output="$array_name"
    local arg

    output=()
    valid_pid "$pid" || return 1
    [[ -r "/proc/$pid/cmdline" ]] || return 1
    while IFS= read -r -d '' arg; do
        ((${#output[@]} < max_pid_argv)) || return 1
        output+=("$arg")
    done <"/proc/$pid/cmdline"
    ((${#output[@]} > 0))
}

mode_comm() {
    case "$1" in
        notifications) printf '%s\n' wayspot-notify ;;
        wallpaper) printf '%s\n' wayspot-wall ;;
        *) return 1 ;;
    esac
}

pid_comm_matches() {
    local pid="$1"
    local expected="$2"
    local comm

    valid_pid "$pid" || return 1
    IFS= read -r comm <"/proc/$pid/comm" || return 1
    [[ "$comm" == "$expected" ]]
}

pid_has_canonical_mode() {
    local pid="$1"
    local mode="$2"
    local expected_comm
    local -a argv=()

    expected_comm="$(mode_comm "$mode")" || return 1
    read_proc_argv "$pid" argv || return 1
    ((${#argv[@]} == 2)) || return 1
    pid_comm_matches "$pid" "$expected_comm" || return 1
    [[ "${argv[0]##*/}" == wayspot && "${argv[1]}" == "$mode" ]]
}

pid_has_legacy_mode() {
    local pid="$1"
    local mode="$2"
    local expected_comm
    local expected_arg
    local -a argv=()

    expected_comm="$(mode_comm "$mode")" || return 1
    case "$mode" in
        notifications) expected_arg=--notifications-daemon ;;
        wallpaper) expected_arg=--wallpaper ;;
        *) return 1 ;;
    esac
    read_proc_argv "$pid" argv || return 1
    ((${#argv[@]} == 2)) || return 1
    pid_comm_matches "$pid" "$expected_comm" || return 1
    [[ "${argv[0]##*/}" == wayspot && "${argv[1]}" == "$expected_arg" ]]
}

pid_matches_kind() {
    case "$2" in
        canonical) pid_has_canonical_mode "$1" "$3" ;;
        legacy) pid_has_legacy_mode "$1" "$3" ;;
        *) return 1 ;;
    esac
}

append_unique_pid() {
    local array_name="$1"
    local pid="$2"
    local -n output="$array_name"
    local existing

    valid_pid "$pid" || return 1
    for existing in "${output[@]}"; do
        [[ "$existing" == "$pid" ]] && return 0
    done
    ((${#output[@]} < max_pid_candidates)) || return 1
    output+=("$pid")
}

collect_mode_pids() {
    local mode="$1"
    local kind="$2"
    local comm
    local pid
    local existing
    local -a candidates=()
    local -a found=()

    comm="$(mode_comm "$mode")" || return 1
    mapfile -t candidates < <(pgrep -x "$comm" | head -n "$((max_pid_candidates + 1))" || true)
    ((${#candidates[@]} <= max_pid_candidates)) || {
        echo "[re-run] refusing more than $max_pid_candidates $mode pid records" >&2
        return 1
    }
    for pid in "${candidates[@]}"; do
        valid_pid "$pid" || {
            echo "[re-run] refusing malformed $mode pid record: $pid" >&2
            return 1
        }
        pid_matches_kind "$pid" "$kind" "$mode" || continue
        for existing in "${found[@]}"; do
            if [[ "$existing" == "$pid" ]]; then
                echo "[re-run] refusing duplicate $mode pid record: $pid" >&2
                return 1
            fi
        done
        append_unique_pid found "$pid" || {
            echo "[re-run] refusing unbounded $mode pid records" >&2
            return 1
        }
    done
    if ((${#found[@]} > 0)); then
        printf '%s\n' "${found[@]}"
    fi
}

read_pid_file() {
    local pid_file="$1"
    local pid
    local -a lines=()

    [[ -r "$pid_file" ]] || return 1
    mapfile -t lines < <(head -n 2 -- "$pid_file" || true)
    ((${#lines[@]} == 1)) || return 1
    pid="${lines[0]}"
    valid_pid "$pid" || return 1
    printf '%s\n' "$pid"
}

collect_wallpaper_pids() {
    local pid_file="$1"
    local kind="$2"
    local pid
    local -a candidates=()
    local -a found=()

    if pid="$(read_pid_file "$pid_file")"; then
        if pid_matches_kind "$pid" "$kind" wallpaper; then
            append_unique_pid found "$pid" || return 1
        elif ! pid_has_canonical_mode "$pid" wallpaper && ! pid_has_legacy_mode "$pid" wallpaper; then
            echo "[re-run] removing stale wallpaper pid file: $pid_file" >&2
            rm -f -- "$pid_file"
        fi
    elif [[ -e "$pid_file" ]]; then
        echo "[re-run] removing malformed wallpaper pid file: $pid_file" >&2
        rm -f -- "$pid_file"
    fi

    mapfile -t candidates < <(pgrep -x wayspot-wall | head -n "$((max_pid_candidates + 1))" || true)
    ((${#candidates[@]} <= max_pid_candidates)) || {
        echo "[re-run] refusing more than $max_pid_candidates wallpaper pid records" >&2
        return 1
    }
    for pid in "${candidates[@]}"; do
        valid_pid "$pid" || {
            echo "[re-run] refusing malformed wallpaper pid record: $pid" >&2
            return 1
        }
        pid_matches_kind "$pid" "$kind" wallpaper || continue
        append_unique_pid found "$pid" || {
            echo "[re-run] refusing unbounded wallpaper pid records" >&2
            return 1
        }
    done
    if ((${#found[@]} > 0)); then
        printf '%s\n' "${found[@]}"
    fi
}

stop_pid_list() {
    local mode="$1"
    local kind="$2"
    local array_name="$3"
    local -n pid_list="$array_name"
    local pid

    ((${#pid_list[@]} <= max_pid_candidates)) || return 1
    for pid in "${pid_list[@]}"; do
        valid_pid "$pid" || {
            echo "[re-run] refusing malformed $mode pid record: $pid" >&2
            return 1
        }
        if pid_matches_kind "$pid" "$kind" "$mode"; then
            echo "[re-run] stopping $kind $mode pid=$pid"
            kill -TERM "$pid" 2>/dev/null || true
        else
            echo "[re-run] ignoring stale $kind $mode pid=$pid" >&2
        fi
    done
}

wait_for_pid_list() {
    local mode="$1"
    local kind="$2"
    local array_name="$3"
    local -n pid_list="$array_name"
    local waited=0
    local pid

    while ((waited < max_wait_cycles)); do
        local alive=0
        for pid in "${pid_list[@]}"; do
            if pid_matches_kind "$pid" "$kind" "$mode"; then
                alive=1
                break
            fi
        done
        if ((alive == 0)); then
            return 0
        fi
        sleep 0.05
        ((waited += 1))
    done
    echo "[re-run] $kind $mode did not stop within $max_wait_cycles checks" >&2
    return 1
}

stop_matching_mode_pids() {
    local mode="$1"
    local kind="$2"
    local records
    local -a pids=()

    if ! records="$(collect_mode_pids "$mode" "$kind")"; then
        return 1
    fi
    if [[ -n "$records" ]]; then
        mapfile -t pids <<<"$records"
    fi
    ((${#pids[@]} == 0)) && return 0
    stop_pid_list "$mode" "$kind" pids
    wait_for_pid_list "$mode" "$kind" pids
}

stop_matching_wallpaper_pids() {
    local pid_file="$1"
    local kind="$2"
    local records
    local -a pids=()

    if ! records="$(collect_wallpaper_pids "$pid_file" "$kind")"; then
        return 1
    fi
    if [[ -n "$records" ]]; then
        mapfile -t pids <<<"$records"
    fi
    ((${#pids[@]} == 0)) && return 0
    stop_pid_list wallpaper "$kind" pids
    wait_for_pid_list wallpaper "$kind" pids
}

wait_for_canonical_mode() {
    local mode="$1"
    local waited=0
    local records
    local -a pids=()

    while ((waited < max_wait_cycles)); do
        if ! records="$(collect_mode_pids "$mode" canonical)"; then
            return 1
        fi
        pids=()
        if [[ -n "$records" ]]; then
            mapfile -t pids <<<"$records"
        fi
        if ((${#pids[@]} == 1)); then
            printf '%s\n' "${pids[0]}"
            return 0
        fi
        if ((${#pids[@]} > 1)); then
            echo "[re-run] refusing duplicate canonical $mode residents" >&2
            return 1
        fi
        sleep 0.05
        ((waited += 1))
    done
    echo "[re-run] canonical $mode resident did not publish within $max_wait_cycles checks" >&2
    return 1
}

wait_for_canonical_wallpaper() {
    local pid_file="$1"
    local waited=0
    local records
    local pid
    local file_pid
    local -a pids=()

    while ((waited < max_wait_cycles)); do
        if ! records="$(collect_wallpaper_pids "$pid_file" canonical)"; then
            return 1
        fi
        pids=()
        if [[ -n "$records" ]]; then
            mapfile -t pids <<<"$records"
        fi
        if ((${#pids[@]} > 1)); then
            echo "[re-run] refusing duplicate canonical wallpaper residents" >&2
            return 1
        fi
        if ((${#pids[@]} == 1)) && file_pid="$(read_pid_file "$pid_file")" && [[ "$file_pid" == "${pids[0]}" ]]; then
            pid="${pids[0]}"
            if pid_has_canonical_mode "$pid" wallpaper; then
                printf '%s\n' "$pid"
                return 0
            fi
        fi
        sleep 0.05
        ((waited += 1))
    done
    echo "[re-run] canonical wallpaper resident did not publish within $max_wait_cycles checks" >&2
    return 1
}

restart_notifications() {
    local bin_path="$1"
    local pid
    local log_dir
    local service_active=0

    # Exact legacy argv is a one-way cleanup bridge; it is never started.
    stop_matching_mode_pids notifications legacy
    if command -v systemctl >/dev/null 2>&1 && systemctl --user --quiet is-active wayspot.service; then
        service_active=1
        systemctl --user stop wayspot.service
    fi
    stop_matching_mode_pids notifications canonical

    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wayspot"
    mkdir -p "$log_dir"
    if ((service_active == 1)); then
        echo "[re-run] starting notification DBus interface: systemctl --user start wayspot.service"
        systemctl --user start wayspot.service
    else
        echo "[re-run] starting notification DBus interface: $bin_path notifications"
        setsid "$bin_path" notifications >>"$log_dir/notifications.log" 2>&1 &
    fi
    pid="$(wait_for_canonical_mode notifications)"
    echo "[re-run] notification DBus interface pid=$pid"
}

restart_wallpaper() {
    local bin_path="$1"
    local xdg_dir="${XDG_RUNTIME_DIR:-}"
    local pid_file
    local log_dir

    if [[ -z "$xdg_dir" ]]; then
        echo "[re-run] wallpaper loop refresh skipped (XDG_RUNTIME_DIR is empty)"
        return
    fi

    pid_file="$xdg_dir/wayspot/wallpaper.pid"
    stop_matching_wallpaper_pids "$pid_file" legacy
    stop_matching_wallpaper_pids "$pid_file" canonical

    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wayspot"
    mkdir -p "$log_dir"
    echo "[re-run] starting wallpaper loop: $bin_path wallpaper"
    setsid "$bin_path" wallpaper >>"$log_dir/wallpaper.log" 2>&1 &
    echo "[re-run] wallpaper loop pid=$(wait_for_canonical_wallpaper "$pid_file")"
}

echo "[re-run] building: zig build ${build_flags[*]}"
zigup run 0.16.0 build "${build_flags[@]}"

if [[ "$RERUN_INSTALL_BIN" != "" ]]; then
    echo "[re-run] syncing binary: $RERUN_BIN -> $RERUN_INSTALL_BIN"
    sync_binary "$RERUN_BIN" "$RERUN_INSTALL_BIN"
fi

if [[ "$RERUN_NOTIFICATIONS" == "true" && "$RERUN_INSTALL_BIN" != "" ]]; then
    restart_notifications "$RERUN_INSTALL_BIN"
else
    echo "[re-run] notification DBus interface refresh skipped (RERUN_NOTIFICATIONS=false)"
fi

if [[ "$RERUN_WALLPAPER" == "true" && "$RERUN_INSTALL_BIN" != "" ]]; then
    restart_wallpaper "$RERUN_INSTALL_BIN"
else
    echo "[re-run] wallpaper loop refresh skipped (RERUN_WALLPAPER=false)"
fi

if [[ "$RERUN_UI" == "true" ]]; then
    echo "[re-run] running picker"
    "$RERUN_BIN" --ui
else
    echo "[re-run] picker skipped (RERUN_UI=false)"
fi
