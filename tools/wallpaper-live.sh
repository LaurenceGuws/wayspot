#!/usr/bin/env bash
# Explicit real Wayland wallpaper proof against a disposable Snowman headless
# compositor. No host config, installed Wayspot, user bus or physical seat touched.
set -euo pipefail
if (( $# != 1 )) || [[ -z "${SNOWMAN_COMPOSITOR:-}" || -z "${SNOWMAN_CLI:-}" ]]; then
    printf 'usage: SNOWMAN_COMPOSITOR=EXACT_BUILD SNOWMAN_CLI=EXACT_BUILD zig build wallpaper-live\n' >&2
    exit 2
fi
root="$(pwd -P)"
wayspot="$(realpath -- "$1")"
snow="$(realpath -- "$SNOWMAN_COMPOSITOR")"
cli="$(realpath -- "$SNOWMAN_CLI")"
for binary in "$wayspot" "$snow" "$cli"; do
    [[ -f "$binary" && -x "$binary" && ! -L "$binary" ]] || {
        printf 'REFUSED: source-built regular executable required: %s\n' "$binary" >&2
        exit 2
    }
done
[[ "$wayspot" == "$root/.zig-cache/"* || "$wayspot" == "$root/zig-out/"* ]] || {
    printf 'REFUSED: Wayspot must be project-local source-built\n' >&2; exit 2;
}
[[ "$snow" != /usr/local/bin/* && "$cli" != /usr/local/bin/* ]] || {
    printf 'REFUSED: never run installed or seat-owned compositor entrypoints\n' >&2; exit 2;
}
scratch="${WAYSPOT_TEST_SCRATCH:?Set WAYSPOT_TEST_SCRATCH to an authorized workstream scratch directory}"
[[ -d "$scratch" && ! -L "$scratch" ]] || { printf 'REFUSED: scratch must exist and not be a symlink\n' >&2; exit 2; }
runtime="$(mktemp -d "$scratch/wl.XXXXXXXX")"
chmod 0700 "$runtime"
[[ ${#runtime} -lt 72 ]] || { printf 'REFUSED: Unix socket path too long\n' >&2; rmdir "$runtime"; exit 2; }
spid=''; wpid=''
cleanup() {
    local rc=$?
    trap - EXIT TERM INT
    if [[ -n "$wpid" ]]; then
        kill -TERM "$wpid" 2>/dev/null || true
        for _ in {1..50}; do kill -0 "$wpid" 2>/dev/null || break; sleep .04; done
        if kill -0 "$wpid" 2>/dev/null; then kill -KILL "$wpid" 2>/dev/null || true; rc=1; fi
        wait "$wpid" 2>/dev/null || true
    fi
    if [[ -n "$spid" ]]; then
        kill -TERM "$spid" 2>/dev/null || true
        for _ in {1..50}; do kill -0 "$spid" 2>/dev/null || break; sleep .04; done
        if kill -0 "$spid" 2>/dev/null; then kill -KILL "$spid" 2>/dev/null || true; rc=1; fi
        wait "$spid" 2>/dev/null || true
    fi
    if (( rc != 0 )); then
        printf 'HOLD: private Wayland wallpaper test failed\n' >&2
        tail -35 "$runtime/wallpaper.log" >&2 || true
        tail -35 "$runtime/snowman.log" >&2 || true
    fi
    if [[ -n "${WAYSPOT_PROOF_DIR:-}" && -d "$WAYSPOT_PROOF_DIR" ]]; then
        for report in compositor-state.json wallpaper.log snowman.log; do
            [[ ! -f "$runtime/$report" ]] || cp -- "$runtime/$report" "$WAYSPOT_PROOF_DIR/$report"
        done
    fi
    rm -rf -- "$runtime"
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
python3 - "$runtime" <<'PY'
import sys,struct,zlib,json
from pathlib import Path
root=Path(sys.argv[1]);(root/'wallpapers').mkdir()
def chunk(name,payload):
    return struct.pack('>I',len(payload))+name+payload+struct.pack('>I',zlib.crc32(name+payload)&0xffffffff)
for name,color in [('first.png',(20,50,90)),('second.png',(70,30,130))]:
    payload=b'\x00'+bytes(color)*16
    data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',16,16,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(payload*16))+chunk(b'IEND',b'')
    (root/'wallpapers'/name).write_bytes(data)
(root/'headless.json').write_text(json.dumps({'backend':{'driver':'headless','headless_outputs':2},'private':{'display_control':True},'children':[]}))
PY
(
    export XDG_RUNTIME_DIR="$runtime"
    unset WAYLAND_DISPLAY WAYLAND_SOCKET DISPLAY WLR_BACKENDS WLR_HEADLESS_OUTPUTS
    exec "$snow" --config "$runtime/headless.json"
) >"$runtime/snowman.log" 2>&1 & spid=$!
ready=0
for _ in {1..90}; do
    if [[ -S "$runtime/wayland-0" && -S "$runtime/snowman-observe-wayland-0.sock" ]]; then ready=1; break; fi
    kill -0 "$spid" 2>/dev/null || break
    sleep .04
done
(( ready == 1 )) || { printf 'HOLD: disposable compositor did not become ready\n' >&2; exit 1; }
export XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY=wayland-0 XDG_STATE_HOME="$runtime/state"
mkdir -p -m 0700 "$XDG_STATE_HOME"
(
    unset HYPRLAND_INSTANCE_SIGNATURE
    exec "$wayspot" wallpaper "$runtime/wallpapers"
) >"$runtime/wallpaper.log" 2>&1 & wpid=$!
published() { local expected="$1" count="$2"; [[ "$(grep -c "wallpaper published $expected output surfaces" "$runtime/wallpaper.log" || true)" -ge "$count" ]]; }
for _ in {1..100}; do
    published 2 1 && break
    kill -0 "$wpid" 2>/dev/null || break
    sleep .05
done
published 2 1 || { printf 'HOLD: two wallpaper surfaces not published\n' >&2; exit 1; }
"$cli" state >"$runtime/compositor-state.json"
python3 - "$runtime" initial <<'PY'
import sys,json
from pathlib import Path
p=Path(sys.argv[1]);data=json.loads((p/'compositor-state.json').read_text())['data'];h=data['display_heads'];assert len(h)==2
json.dump({'schema':'snowman-display-config/v1','display_revision':data['display_revision'],'heads':[
    {'id':h[0]['id'],'enabled':True,'at':{'x':0,'y':0},'scale':1.5},
    {'id':h[1]['id'],'enabled':False},
]},(p/'change.json').open('w'))
PY
"$cli" display test "$runtime/change.json" | jq -e '.ok and .data.status == "tested"' >/dev/null
"$cli" display apply "$runtime/change.json" | jq -e '.ok and .data.status == "applied"' >/dev/null
for _ in {1..100}; do
    published 1 1 && break
    kill -0 "$wpid" 2>/dev/null || break
    sleep .05
done
published 1 1 || { printf 'HOLD: wallpaper did not reconcile disabled output\n' >&2; exit 1; }
"$cli" state >"$runtime/compositor-state.json"
python3 - "$runtime" reenable <<'PY'
import sys,json
from pathlib import Path
p=Path(sys.argv[1]);data=json.loads((p/'compositor-state.json').read_text())['data'];h=data['display_heads'];assert len(h)==2
json.dump({'schema':'snowman-display-config/v1','display_revision':data['display_revision'],'heads':[
    {'id':h[0]['id'],'enabled':False}, {'id':h[1]['id'],'enabled':False}
]},(p/'change.json').open('w'))
PY
"$cli" display test "$runtime/change.json" | jq -e '.ok and .data.status == "tested"' >/dev/null
"$cli" display apply "$runtime/change.json" | jq -e '.ok and .data.status == "applied"' >/dev/null
sleep .25
kill -0 "$wpid" 2>/dev/null || { printf 'HOLD: wallpaper did not survive zero outputs\n' >&2; exit 1; }
"$cli" state >"$runtime/compositor-state.json"
python3 - "$runtime" reenable <<'PY'
import sys,json
from pathlib import Path
p=Path(sys.argv[1]);data=json.loads((p/'compositor-state.json').read_text())['data'];h=data['display_heads'];assert len(h)==2
json.dump({'schema':'snowman-display-config/v1','display_revision':data['display_revision'],'heads':[
    {'id':h[0]['id'],'enabled':True,'at':{'x':0,'y':0},'scale':1.5},
    {'id':h[1]['id'],'enabled':True,'at':{'x':900,'y':0},'scale':1},
]},(p/'change.json').open('w'))
PY
"$cli" display test "$runtime/change.json" | jq -e '.ok and .data.status == "tested"' >/dev/null
"$cli" display apply "$runtime/change.json" | jq -e '.ok and .data.status == "applied"' >/dev/null
for _ in {1..100}; do
    published 2 2 && break
    kill -0 "$wpid" 2>/dev/null || break
    sleep .05
done
published 2 2 || { printf 'HOLD: wallpaper did not republish after zero output and re-add\n' >&2; exit 1; }
timeout -s TERM -k 1s 12s "$wayspot" wallpaper rotate
kill -TERM "$wpid"
for _ in {1..75}; do kill -0 "$wpid" 2>/dev/null || break; sleep .035; done
if kill -0 "$wpid" 2>/dev/null; then printf 'HOLD: wallpaper did not stop\n' >&2; exit 1; fi
wait "$wpid"; wpid=''
kill -TERM "$spid"; wait "$spid"; spid=''
printf 'PASS: native Wayland wallpaper, two outputs, 1.5x, zero outputs, re-add, rotation and cleanup\n'
