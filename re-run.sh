#!/usr/bin/env bash
set -euo pipefail

# Rebuild, install the local binary, and run one picker lifecycle.
#
# Optional overrides:
#   RERUN_BUILD_FLAGS="-Doptimize=ReleaseFast"
#   RERUN_BIN="./zig-out/bin/wayspot"
#   RERUN_INSTALL_BIN="$HOME/.local/bin/wayspot"
#   RERUN_UI=false

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

: "${RERUN_BUILD_FLAGS:=-Doptimize=ReleaseFast}"
: "${RERUN_BIN:=./zig-out/bin/wayspot}"
: "${RERUN_INSTALL_BIN:=$HOME/.local/bin/wayspot}"
: "${RERUN_UI:=true}"

read -r -a build_flags <<<"$RERUN_BUILD_FLAGS"

echo "[re-run] building: zig build ${build_flags[*]}"
zigup run 0.16.0 build "${build_flags[@]}"

if [[ -n "$RERUN_INSTALL_BIN" ]]; then
    echo "[re-run] syncing binary: $RERUN_BIN -> $RERUN_INSTALL_BIN"
    mkdir -p "$(dirname "$RERUN_INSTALL_BIN")"
    cp "$RERUN_BIN" "$RERUN_INSTALL_BIN"
    chmod +x "$RERUN_INSTALL_BIN"
fi

if [[ "$RERUN_UI" == "true" ]]; then
    echo "[re-run] running picker"
    "$RERUN_BIN" --ui
else
    echo "[re-run] picker skipped (RERUN_UI=false)"
fi
