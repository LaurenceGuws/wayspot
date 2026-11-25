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
        for report in compositor-state.json wallpaper.log snowman.log persistence.json fullscreen.log; do
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
    unset WAYLAND_DISPLAY WAYLAND_SOCKET DISPLAY WLR_BACKENDS WLR_HEADLESS_OUTPUTS WLR_RENDERER XDG_SESSION_TYPE XDG_SEAT XDG_VTNR XDG_CURRENT_DESKTOP LD_LIBRARY_PATH
    exec "$snow" --config "$runtime/headless.json"
) >"$runtime/snowman.log" 2>&1 & spid=$!
ready=0
for _ in {1..90}; do
    if [[ -S "$runtime/wayland-0" && -S "$runtime/snowman-command-wayland-0.sock" ]]; then ready=1; break; fi
    kill -0 "$spid" 2>/dev/null || break
    sleep .04
done
(( ready == 1 )) || { printf 'HOLD: disposable compositor did not become ready\n' >&2; exit 1; }
export XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY=wayland-0 XDG_STATE_HOME="$runtime/state"
mkdir -p -m 0700 "$XDG_STATE_HOME"
(
    unset HYPRLAND_INSTANCE_SIGNATURE
    export WAYLAND_DEBUG=client
    exec "$wayspot" wallpaper "$runtime/wallpapers"
) >"$runtime/wallpaper.log" 2>&1 & wpid=$!
published() { local expected="$1" count="$2"; [[ "$(grep -c "wallpaper published $expected output surfaces" "$runtime/wallpaper.log" || true)" -ge "$count" ]]; }
for _ in {1..100}; do
    published 2 1 && break
    kill -0 "$wpid" 2>/dev/null || break
    sleep .05
done
published 2 1 || { printf 'HOLD: two wallpaper surfaces not published\n' >&2; exit 1; }
# Real, unrelated layer-shell and toplevel churn must not republish wallpaper.
# Both processes are disposable private-session clients, never the live desktop.
attach_count() { grep -Ec 'wl_surface[@#][0-9]+\.attach\(' "$runtime/wallpaper.log" || true; }
initial_attach=$(attach_count)
(( initial_attach == 2 )) || { printf 'HOLD: expected exactly two initial attaches, got %s\n' "$initial_attach" >&2; exit 1; }
for _ in {1..20}; do
    foot --app-id=wayspot-test-churn sh -c 'sleep .08' >"$runtime/foot.log" 2>&1 || { tail -15 "$runtime/foot.log" >&2; exit 1; }
done
sleep .15
kill -0 "$wpid"
[[ $(grep -c '^info: mapped view ' "$runtime/snowman.log") == 20 ]] || { printf 'HOLD: expected 20 actual mapped toplevels\n' >&2; exit 1; }
[[ $(attach_count) == "$initial_attach" ]] || { printf 'HOLD: unrelated toplevel churn republished wallpaper\n' >&2; exit 1; }
printf 'PASS: 20 real toplevel cycles, zero additional wallpaper attachments\n'
python3 - "$runtime" "$wayspot" <<'PICKER'
import os, re, subprocess, sys, time
from pathlib import Path
root = Path(sys.argv[1])
env = dict(os.environ, XDG_SESSION_DESKTOP='Snowman', XDG_CURRENT_DESKTOP='Snowman', SDL_VIDEODRIVER='wayland', WAYLAND_DEBUG='client')
for key, name in [('HOME','home'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache')]:
    directory = root / name
    directory.mkdir(exist_ok=True)
    env[key] = str(directory)
for index in range(20):
    log = root / 'picker.wire'
    with log.open('wb') as output:
        p = subprocess.Popen([sys.argv[2]], env=env, stdout=output, stderr=output)
        try:
            deadline = time.monotonic() + 6
            while time.monotonic() < deadline:
                text = log.read_text(errors='replace')
                if '"wayspot-picker"' in text and re.search(r'wl_surface[@#]\d+\.attach\(wl_buffer', text):
                    break
                assert p.poll() is None, 'picker exited before first buffer'
                time.sleep(.005)
            else:
                raise RuntimeError('picker did not attach a buffer')
        finally:
            if p.poll() is None:
                p.terminate()
                try: p.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    p.kill(); p.wait(timeout=4)
            assert p.returncode == 0, p.returncode
    text = log.read_text(errors='replace')
    assert not re.search(r'wl_display[@#]\d+\.error\(', text)
PICKER
kill -0 "$wpid"
[[ $(attach_count) == "$initial_attach" ]] || { printf 'HOLD: picker layer churn republished wallpaper\n' >&2; exit 1; }
printf 'PASS: 20 real picker layer cycles, zero additional wallpaper attachments\n'

python3 - "$runtime" "$wayspot" "$cli" "$wpid" <<'PERSISTENCE'
import json, os, re, subprocess, sys, time
from pathlib import Path
root, wayspot, cli, pid = Path(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
log = root / 'wallpaper.log'
colors = {(20, 50, 90), (70, 30, 130)}
def run(*args):
    return subprocess.run(args, capture_output=True, check=True, timeout=10).stdout
def query(*args):
    reply = json.loads(run(cli, *args))
    assert reply['ok'], reply
    return reply['data']
def wire():
    return log.read_text(errors='replace')
def counts():
    text = wire()
    assert not re.search(r'wl_display[@#]\d+\.error\(', text), 'wallpaper protocol error'
    assert not re.search(r'wl_surface[@#]\d+\.attach\((?:nil|null)', text), 'null wallpaper attach'
    return (text.count('.get_layer_surface('), len(re.findall(r'wl_surface[@#]\d+\.attach\(wl_buffer', text)), len(re.findall(r'zwlr_layer_surface_v1[@#]\d+\.destroy\(', text)))
def wait_for(predicate, description):
    end = time.monotonic() + 8
    while time.monotonic() < end:
        os.kill(pid, 0)
        if predicate(): return
        time.sleep(.025)
    raise AssertionError(f'{description}: counts={counts()}')
def expect(delta, before):
    expected = tuple(a+b for a,b in zip(before,delta))
    wait_for(lambda: counts() == expected, f'expected {expected}')
def pixel(name):
    ppm = run('grim', '-o', name, '-t', 'ppm', '-')
    magic, dimensions, maximum, pixels = ppm.split(b'\n', 3)
    assert magic == b'P6' and maximum == b'255', (magic, maximum)
    w, h = map(int, dimensions.split())
    assert len(pixels) == w*h*3
    at = ((h//2)*w+w//2)*3
    return tuple(pixels[at:at+3])
def await_color(names, color):
    wait_for(lambda: all(pixel(name) == color for name in names), f'{names} color {color}')
def change(enabled, scales):
    heads = query('monitor', 'list')
    rev = query('session', 'status')['display_revision']
    assert len(heads) == 2
    config = {'schema': 'snowman-display-config/v1', 'display_revision': rev, 'heads': [dict(id=h['id'], enabled=on, **({'at': {'x': 0 if i==0 else 1280, 'y': 0}, 'scale': scales[i]} if on else {})) for i,(h,on) in enumerate(zip(heads,enabled))]}
    (root/'change.json').write_text(json.dumps(config))
    assert query('display','test',str(root/'change.json'))['status'] == 'tested'
    assert query('display','apply',str(root/'change.json'))['status'] == 'applied'
def rotate(n, names, color, visible=True):
    for _ in range(n):
        before = counts()
        run(wayspot, 'wallpaper', 'rotate')
        expect((0,len(names),0), before)
        color = next(c for c in colors if c != color)
        if visible: await_color(names, color)
    return color
def memory():
    data = Path(f'/proc/{pid}/smaps_rollup').read_text()
    return {k:int(v) for k,v in re.findall(r'^(Rss|Pss|Private_Dirty):\s+(\d+) kB',data,re.M)}
def cpu_ticks():
    fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
    return int(fields[11])+int(fields[12])
names = [h['name'] for h in query('monitor','list')]
assert len(names) == 2 and counts() == (2,2,0), counts()
color = pixel(names[0]); assert color in colors, color
await_color(names,color)
initial_memory = memory()
color = rotate(12,names,color)
print('PASS: 12 two-output rotations, same roles and correct alternating pixels',flush=True)
rotated_memory = memory()
# A corrupt alternative must not disturb the published image or surface.
other = root/'wallpapers'/('second.png' if color==(20,50,90) else 'first.png')
original = other.read_bytes(); before=counts()
try:
    other.write_bytes(b'not an image')
    refused=subprocess.run([wayspot,'wallpaper','rotate'],capture_output=True,timeout=5)
    assert refused.returncode != 0
    assert counts()==before
    await_color(names,color)
finally: other.write_bytes(original)
print('PASS: invalid rotation candidate preserves every existing pixel',flush=True)
before = counts(); change([True,False],[1,1]); expect((0,0,1),before); await_color(names[:1],color)
before = counts(); change([True,False],[1.5,1]); expect((0,1,0),before); await_color(names[:1],color)
print('PASS: remove one output and fractional-scale survivor, no survivor role recreation',flush=True)
# Rotate an actually hidden wallpaper, then expose it by closing a real fullscreen client.
with (root/'fullscreen.log').open('wb') as output:
    foot = subprocess.Popen(['foot','--fullscreen','--app-id=wayspot-fullscreen-test','sh','-c','sleep 60'],stdout=output,stderr=output)
    try:
        wait_for(lambda:any(w['app_id']=='wayspot-fullscreen-test' and w['fullscreen'] for w in query('window','list','--mapped')), 'fullscreen toplevel')
        wait_for(lambda:pixel(names[0]) not in colors, 'wallpaper actually occluded')
        color = rotate(5,names[:1],color,False)
        assert foot.poll() is None
    finally:
        if foot.poll() is None: foot.terminate()
        try: foot.wait(timeout=4)
        except subprocess.TimeoutExpired: foot.kill();foot.wait(timeout=4)
await_color(names[:1],color)
print('PASS: five rotations behind fullscreen, latest wallpaper pixels visible after exit',flush=True)
# The retained encoded image must also survive deletion of its source file.
selected_path = root/'wallpapers'/('first.png' if color==(20,50,90) else 'second.png')
backup = selected_path.read_bytes(); selected_path.unlink()
try:
    before = counts(); change([True,True],[1.5,1]); expect((1,1,0),before); await_color(names,color)
finally: selected_path.write_bytes(backup)
print('PASS: add one output, survivor unchanged, selected image retained',flush=True)
before = counts(); change([False,False],[1,1]); expect((0,0,2),before)
time.sleep(.2)
zero_counts = counts(); zero_memory = memory(); ticks = cpu_ticks(); time.sleep(3); delta = cpu_ticks()-ticks
assert counts()==zero_counts and delta<=1, (counts(),zero_counts,delta)
refused = subprocess.run([wayspot,'wallpaper','rotate'],capture_output=True,timeout=5)
assert refused.returncode != 0, 'rotation claimed publication without an output'
assert counts()==zero_counts
before=counts(); change([True,True],[1.5,1]); expect((2,2,0),before); await_color(names,color)
assert wire().count('.get_registry(')==1, 'wallpaper reconnected on topology or rotation'
print('PASS: zero outputs idle, direct rotation refused, both outputs restored on same connection',flush=True)
receipt={'initial_kib':initial_memory,'after_12_rotations_kib':rotated_memory,'zero_outputs_kib':zero_memory,'zero_outputs_cpu_ticks_3s':delta,'restored_kib':memory(),'wire_counts':counts(),'registry_connections':1}
(root/'persistence.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PERSISTENCE',json.dumps(receipt),flush=True)
PERSISTENCE
kill -TERM "$wpid"
for _ in {1..75}; do kill -0 "$wpid" 2>/dev/null || break; sleep .035; done
if kill -0 "$wpid" 2>/dev/null; then printf 'HOLD: wallpaper did not stop\n' >&2; exit 1; fi
wait "$wpid"; wpid=''
kill -TERM "$spid"; wait "$spid"; spid=''
printf 'PASS: persistent wallpaper roles, rotation, fullscreen, topology and cleanup\n'
