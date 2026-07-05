#!/usr/bin/env bash
set -euo pipefail

# Rebuild, install the local binary, and run one picker lifecycle.
#
# Optional overrides:
#   RERUN_BUILD_FLAGS="-Doptimize=ReleaseFast"
#   RERUN_BIN="./zig-out/bin/wayspot"
#   RERUN_INSTALL_BIN="$HOME/.local/bin/wayspot"
#   RERUN_NOTIFICATIONS=true
#   RERUN_WALLPAPER=true
#   RERUN_UI=false

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

: "${RERUN_BUILD_FLAGS:=-Doptimize=ReleaseFast}"
: "${RERUN_BIN:=./zig-out/bin/wayspot}"
: "${RERUN_INSTALL_BIN:=$HOME/.local/bin/wayspot}"
: "${RERUN_NOTIFICATIONS:=true}"
: "${RERUN_WALLPAPER:=true}"
: "${RERUN_UI:=true}"

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

restart_notifications() {
    local bin_path="$1"
    local pid
    local waited
    local log_dir
    local -a daemon_pids

    if command -v systemctl >/dev/null 2>&1 && systemctl --user --quiet is-active wayspot.service; then
        echo "[re-run] restarting notification daemon: systemctl --user restart wayspot.service"
        systemctl --user restart wayspot.service
        return
    fi

    mapfile -t daemon_pids < <(pgrep -f "[w]ayspot .*--notifications-daemon|[w]ayspot --notifications-daemon" || true)
    for pid in "${daemon_pids[@]}"; do
        echo "[re-run] stopping notification daemon pid=$pid"
        kill -TERM "$pid" 2>/dev/null || true
    done

    waited=0
    while ((${#daemon_pids[@]} > 0 && waited < 20)); do
        local alive=0
        for pid in "${daemon_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                alive=1
            fi
        done
        if ((alive == 0)); then
            break
        fi
        sleep 0.05
        waited=$((waited + 1))
    done

    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wayspot"
    mkdir -p "$log_dir"
    echo "[re-run] starting notification daemon: $bin_path --notifications-daemon"
    setsid "$bin_path" --notifications-daemon >>"$log_dir/notifications.log" 2>&1 &
}

process_has_wayspot_arg() {
    local pid="$1"
    local expected_arg="$2"
    local -a argv=()
    local arg
    local binary
    local has_arg=false

    [[ -r "/proc/$pid/cmdline" ]] || return 1
    mapfile -d '' -t argv <"/proc/$pid/cmdline" || return 1
    ((${#argv[@]} > 0)) || return 1

    binary="$(basename "${argv[0]}")"
    [[ "$binary" == "wayspot" ]] || return 1

    for arg in "${argv[@]}"; do
        if [[ "$arg" == "$expected_arg" ]]; then
            has_arg=true
            break
        fi
    done

    [[ "$has_arg" == "true" ]]
}

collect_wallpaper_pids() {
    local pid_file="$1"
    local pid
    local -a found=()
    local -a candidates=()

    if [[ -r "$pid_file" ]]; then
        read -r pid <"$pid_file" || true
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            if process_has_wayspot_arg "$pid" "--wallpaper"; then
                found+=("$pid")
            else
                rm -f "$pid_file"
            fi
        fi
    fi

    mapfile -t candidates < <(pgrep -f "[w]ayspot .*--wallpaper|[w]ayspot --wallpaper" || true)
    for pid in "${candidates[@]}"; do
        process_has_wayspot_arg "$pid" "--wallpaper" || continue
        if [[ " ${found[*]} " != *" $pid "* ]]; then
            found+=("$pid")
        fi
    done

    if ((${#found[@]} > 0)); then
        printf '%s\n' "${found[@]}"
    fi
}

restart_wallpaper() {
    local bin_path="$1"
    local runtime_dir="${XDG_RUNTIME_DIR:-}"
    local pid_file
    local pid
    local waited
    local log_dir
    local -a daemon_pids
    local started_pid=""

    if [[ -z "$runtime_dir" ]]; then
        echo "[re-run] wallpaper daemon refresh skipped (XDG_RUNTIME_DIR is empty)"
        return
    fi

    pid_file="$runtime_dir/wayspot/wallpaper.pid"
    mapfile -t daemon_pids < <(collect_wallpaper_pids "$pid_file")

    for pid in "${daemon_pids[@]}"; do
        echo "[re-run] stopping wallpaper daemon pid=$pid"
        kill -TERM "$pid" 2>/dev/null || true
    done

    waited=0
    while ((${#daemon_pids[@]} > 0 && waited < 40)); do
        local alive=0
        for pid in "${daemon_pids[@]}"; do
            if process_has_wayspot_arg "$pid" "--wallpaper"; then
                alive=1
            fi
        done
        if ((alive == 0)); then
            break
        fi
        sleep 0.05
        waited=$((waited + 1))
    done

    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wayspot"
    mkdir -p "$log_dir"
    echo "[re-run] starting wallpaper daemon: $bin_path --wallpaper"
    setsid "$bin_path" --wallpaper >>"$log_dir/wallpaper.log" 2>&1 &

    waited=0
    while ((waited < 40)); do
        if [[ -r "$pid_file" ]]; then
            read -r started_pid <"$pid_file" || true
            if [[ "$started_pid" =~ ^[0-9]+$ ]] && process_has_wayspot_arg "$started_pid" "--wallpaper"; then
                echo "[re-run] wallpaper daemon pid=$started_pid"
                return
            fi
        fi
        sleep 0.05
        waited=$((waited + 1))
    done

    echo "[re-run] wallpaper daemon pid not published yet"
}

echo "[re-run] building: zig build ${build_flags[*]}"
zigup run 0.16.0 build "${build_flags[@]}"

if [[ -n "$RERUN_INSTALL_BIN" ]]; then
    echo "[re-run] syncing binary: $RERUN_BIN -> $RERUN_INSTALL_BIN"
    sync_binary "$RERUN_BIN" "$RERUN_INSTALL_BIN"
fi

if [[ "$RERUN_NOTIFICATIONS" == "true" && -n "$RERUN_INSTALL_BIN" ]]; then
    restart_notifications "$RERUN_INSTALL_BIN"
else
    echo "[re-run] notification daemon refresh skipped (RERUN_NOTIFICATIONS=false)"
fi

if [[ "$RERUN_WALLPAPER" == "true" && -n "$RERUN_INSTALL_BIN" ]]; then
    restart_wallpaper "$RERUN_INSTALL_BIN"
else
    echo "[re-run] wallpaper daemon refresh skipped (RERUN_WALLPAPER=false)"
fi

if [[ "$RERUN_UI" == "true" ]]; then
    echo "[re-run] running picker"
    "$RERUN_BIN" --ui
else
    echo "[re-run] picker skipped (RERUN_UI=false)"
fi
