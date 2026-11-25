#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

# Runs the examples against a headless weston, so that they meet a real
# compositor without a display: `globals` must list what weston advertises,
# and `window --frames 10` must get a toplevel configured and ten frames
# presented, paced by frame callbacks and drawn into buffers the compositor
# has released, without a protocol error.
#
# Then, where the machine allows it -- /dev/udmabuf readable and writable, and
# a render node for weston's GL renderer -- `dmabuf --frames 10` does the same
# with dma-bufs. Where it does not, as on a runner with no GPU, that stage says
# so and is skipped rather than failed.
#
# Last, on the same terms, a headless sway on the GLES renderer -- which,
# unlike weston's headless backend, offers wp_linux_drm_syncobj_manager_v1 --
# runs `dmabuf --explicit-sync --frames 60`. Two buffers cannot last sixty
# frames unless the compositor really signals the release points and the
# buffers really come back through them.
#
# Expects `zig build` to have run, and weston and sway on PATH, which the
# devshell provides.

set -euo pipefail

runtime_dir=$(mktemp -d)
compositor=
trap 'kill "$compositor" 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$runtime_dir"' EXIT
export XDG_RUNTIME_DIR=$runtime_dir
export WAYLAND_DISPLAY=wayland-headless

weston --backend=headless --renderer=pixman --shell=kiosk --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$runtime_dir/weston.log" &
compositor=$!

for _ in $(seq 100); do
  [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.1
done

./zig-out/bin/globals | tee "$runtime_dir/globals.txt"
grep -q ' wl_compositor ' "$runtime_dir/globals.txt"
grep -q ' xdg_wm_base ' "$runtime_dir/globals.txt"
timeout 30 ./zig-out/bin/window --frames 10

kill "$compositor"
wait "$compositor" 2>/dev/null || true

if ! [ -r /dev/udmabuf ] || ! [ -w /dev/udmabuf ]; then
  echo "skipping the dma-buf stage: /dev/udmabuf is not readable and writable here"
  exit 0
fi
if ! ls /dev/dri/renderD* >/dev/null 2>&1; then
  echo "skipping the dma-buf stage: there is no render node for weston's GL renderer"
  exit 0
fi

export WAYLAND_DISPLAY=wayland-headless-gl
weston --backend=headless --renderer=gl --shell=kiosk --idle-time=0 \
  --socket="$WAYLAND_DISPLAY" --log="$runtime_dir/weston-gl.log" &
compositor=$!
for _ in $(seq 100); do
  [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.1
done
if ! ./zig-out/bin/globals | grep -q ' zwp_linux_dmabuf_v1 '; then
  echo "skipping the dma-buf stage: weston's GL renderer did not start here"
  exit 0
fi
timeout 30 ./zig-out/bin/dmabuf --frames 10

kill "$compositor"
wait "$compositor" 2>/dev/null || true

# sway names its own socket, the first free wayland-N in XDG_RUNTIME_DIR, so
# it gets a runtime directory to itself and the socket is found afterwards.
sway_runtime_dir=$runtime_dir/sway
mkdir -m 700 "$sway_runtime_dir"
printf 'output HEADLESS-1 resolution 1024x640\n' >"$runtime_dir/sway.conf"
render_node=$(ls /dev/dri/renderD* | head -n 1)
XDG_RUNTIME_DIR=$sway_runtime_dir WLR_BACKENDS=headless WLR_RENDERER=gles2 \
  WLR_RENDER_DRM_DEVICE=$render_node WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$runtime_dir/sway.conf" >"$runtime_dir/sway.log" 2>&1 &
compositor=$!
socket=
for _ in $(seq 100); do
  socket=$(ls "$sway_runtime_dir" 2>/dev/null | grep -m 1 '^wayland-[0-9]*$' || true)
  [ -n "$socket" ] && [ -S "$sway_runtime_dir/$socket" ] && break
  sleep 0.1
done
if [ -z "$socket" ]; then
  echo "skipping the explicit sync stage: headless sway did not start here"
  exit 0
fi
export XDG_RUNTIME_DIR=$sway_runtime_dir WAYLAND_DISPLAY=$socket
if ! ./zig-out/bin/globals | grep -q ' wp_linux_drm_syncobj_manager_v1 '; then
  echo "skipping the explicit sync stage: sway does not offer explicit sync here"
  exit 0
fi
timeout 30 ./zig-out/bin/dmabuf --explicit-sync --frames 60
