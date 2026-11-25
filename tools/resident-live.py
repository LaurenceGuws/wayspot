#!/usr/bin/env python3
"""Real isolated Snowman resident, protocol and resource acceptance gate."""

from pathlib import Path
import json, os, re, shutil, statistics, struct, subprocess, tempfile, time, zlib, signal

# Explicit opt-in gate. Candidate and compositor must be source-built;
# baseline is an optional explicit comparison executable.
import sys

candidate = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parent.parent
snow = Path(os.environ["SNOWMAN_COMPOSITOR"]).resolve()
cli = Path(os.environ["SNOWMAN_CLI"]).resolve()
baseline = Path(os.environ.get("WAYSPOT_BASELINE", str(candidate))).resolve()
actor_path = os.environ.get("SNOWMAN_SIM_CLIENT")
actor = Path(actor_path).resolve() if actor_path else None
if actor:
    assert (
        actor.name == "snowman-sim-client"
        and actor.is_file()
        and os.access(actor, os.X_OK)
    )
    assert actor.parent == cli.parent == snow.parent
assert cli.name == "snowman"
assert candidate.is_relative_to(repo / ".zig-cache") or candidate.is_relative_to(
    repo / "zig-out"
)
assert all(
    x.is_file() and os.access(x, os.X_OK) for x in (candidate, snow, cli, baseline)
)
assert not snow.is_relative_to("/usr/local/bin") and not cli.is_relative_to(
    "/usr/local/bin"
)
scratch = Path(os.environ["WAYSPOT_TEST_SCRATCH"]).resolve()
assert scratch.is_dir()
out = Path(os.environ["WAYSPOT_PROOF_DIR"]).resolve()
assert out.is_dir() and not (out / "receipt.json").exists()
root = Path(tempfile.mkdtemp(prefix="wr.", dir=scratch))
root.chmod(0o700)
children = []
handles = []
for name in ("r", "h", "c", "d", "cache", "state", "wallpapers"):
    (root / name).mkdir(mode=0o700)
runtime = root / "r"
assert len(str(runtime / "snowman-command-wayland-0.sock")) < 108
# Private bus has no activation directories and no reference to the login bus.
bus_address = "unix:path=" + str(root / "bus")
(root / "bus.conf").write_text(
    "<busconfig><type>session</type><listen>"
    + bus_address
    + '</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>'
)
env = {
    "PATH": str(cli.parent) + ":/usr/bin:/bin",
    "HOME": str(root / "h"),
    "XDG_CONFIG_HOME": str(root / "c"),
    "XDG_DATA_HOME": str(root / "d"),
    "XDG_DATA_DIRS": "/usr/share",
    "XDG_CACHE_HOME": str(root / "cache"),
    "XDG_STATE_HOME": str(root / "state"),
    "XDG_RUNTIME_DIR": str(runtime),
    "WAYLAND_DISPLAY": "wayland-0",
    "XDG_SESSION_DESKTOP": "Snowman",
    "XDG_CURRENT_DESKTOP": "Snowman",
    "SDL_VIDEODRIVER": "wayland",
    "DBUS_SESSION_BUS_ADDRESS": bus_address,
    "LANG": "C.UTF-8",
    "GIO_USE_VFS": "local",
    "NO_AT_BRIDGE": "1",
    "GTK_A11Y": "none",
    "GSETTINGS_BACKEND": "memory",
}
colors = {(20, 50, 90), (70, 30, 130)}


def chunk(n, b):
    return (
        struct.pack(">I", len(b))
        + n
        + b
        + struct.pack(">I", zlib.crc32(n + b) & 0xFFFFFFFF)
    )


for i, color in enumerate(sorted(colors)):
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress((b"\0" + bytes(color) * 16) * 16))
        + chunk(b"IEND", b"")
    )
    (root / "wallpapers" / f"{i}.png").write_bytes(data)
(root / "snowman.json").write_text(
    json.dumps(
        {
            "backend": {"driver": "headless", "input": "none", "headless_outputs": 2},
            "private": {"display_control": True, "second_seat": actor is not None},
            "initial_workspaces": 3,
            "layout": {"default_mode": "monocle"},
            "publish_session_environment": False,
            "children": [],
        }
    )
)
(root / "resident.json").write_text(
    json.dumps(
        {
            "picker": True,
            "notifications": True,
            "tray": True,
            "wallpaper": str(root / "wallpapers"),
        }
    )
)
(root / "disabled.json").write_text(
    json.dumps(
        {"picker": False, "notifications": False, "tray": False, "wallpaper": None}
    )
)


def start(argv, name, debug=False, control=False):
    e = dict(env)
    if debug:
        e["WAYLAND_DEBUG"] = "client"
    f = (out / f"{name}.log").open("wb")
    handles.append(f)
    q = subprocess.Popen(
        list(map(str, argv)),
        env=e,
        stdin=subprocess.PIPE if control else subprocess.DEVNULL,
        stdout=f,
        stderr=f,
    )
    children.append(q)
    return q


def stop(q):
    if q.poll() is None:
        q.terminate()
        try:
            q.wait(timeout=5)
        except subprocess.TimeoutExpired:
            q.kill()
            q.wait(timeout=4)
    return q.returncode


def run(*argv, check=True):
    return subprocess.run(
        list(map(str, argv)),
        env=env,
        capture_output=True,
        text=True,
        timeout=8,
        check=check,
    )


def log(name):
    return (out / f"{name}.log").read_text(errors="replace")


def wait(pred, why, timeout=8):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            if value := pred():
                return value
        except (subprocess.SubprocessError, FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(0.002)
    raise AssertionError(why)


def bus(*args):
    return run("gdbus", "call", "--session", *args).stdout


def owner(name):
    return "true" in bus(
        "--dest",
        "org.freedesktop.DBus",
        "--object-path",
        "/org/freedesktop/DBus",
        "--method",
        "org.freedesktop.DBus.NameHasOwner",
        name,
    )


def owner_pid(name):
    return int(
        re.search(
            r"uint32 (\d+)",
            bus(
                "--dest",
                "org.freedesktop.DBus",
                "--object-path",
                "/org/freedesktop/DBus",
                "--method",
                "org.freedesktop.DBus.GetConnectionUnixProcessID",
                name,
            ),
        ).group(1)
    )


def notify(summary, ms=60000, replaces=0):
    result = bus(
        "--dest",
        "org.freedesktop.Notifications",
        "--object-path",
        "/org/freedesktop/Notifications",
        "--method",
        "org.freedesktop.Notifications.Notify",
        "WayspotTest",
        f"uint32 {replaces}",
        "",
        "" + summary,
        "Body",
        "@as []",
        "@a{sv} {}",
        f"int32 {ms}",
    )
    return int(re.search(r"uint32 (\d+)", result).group(1))


def close(nid):
    return bus(
        "--dest",
        "org.freedesktop.Notifications",
        "--object-path",
        "/org/freedesktop/Notifications",
        "--method",
        "org.freedesktop.Notifications.CloseNotification",
        f"uint32 {nid}",
    )


def status():
    return json.loads(run(candidate, "resident", "status").stdout)


def mem(proc):
    b = Path(f"/proc/{proc.pid}")
    m = {
        k: int(v)
        for k, v in re.findall(
            r"^(Rss|Pss|Private_Dirty):\s+(\d+) kB",
            (b / "smaps_rollup").read_text(),
            re.M,
        )
    }
    stats = [
        int(
            re.search(
                r"^voluntary_ctxt_switches:\s+(\d+)", (t / "status").read_text(), re.M
            ).group(1)
        )
        for t in (b / "task").iterdir()
    ]
    fields = (b / "stat").read_text().rsplit(")", 1)[1].split()
    return dict(
        m,
        threads=len(stats),
        voluntary_switches=sum(stats),
        cpu_ticks=int(fields[11]) + int(fields[12]),
    )


def sample(procs):
    a = [mem(q) for q in procs]
    time.sleep(3)
    b = [mem(q) for q in procs]
    return {
        "before": a,
        "after": b,
        "pss_kib": sum(x["Pss"] for x in b),
        "threads": sum(x["threads"] for x in b),
        "cpu_ticks_delta": sum(y["cpu_ticks"] - x["cpu_ticks"] for x, y in zip(a, b)),
        "voluntary_switch_delta": sum(
            y["voluntary_switches"] - x["voluntary_switches"] for x, y in zip(a, b)
        ),
    }


def pixel(name):
    data = subprocess.check_output(
        ["grim", "-o", name, "-t", "ppm", "-"], env=env, timeout=5
    )
    magic, dims, maximum, raw = data.split(b"\n", 3)
    assert magic == b"P6" and maximum == b"255"
    w, h = map(int, dims.split())
    off = (h // 2 * w + w // 2) * 3
    return tuple(raw[off : off + 3])


def roles(name, role):
    return log(name).count(f'"wayspot-{role}")')


def new_attach(name, role, offset=0):
    text = log(name)[offset:]
    m = re.search(
        r'get_layer_surface\(new id zwlr_layer_surface_v1[#@](\d+), wl_surface[#@](\d+),[^\n]+"wayspot-'
        + role
        + r'"\)',
        text,
    )
    return m and re.search(
        r"wl_surface[#@]" + m.group(2) + r"\.attach\(wl_buffer", text[m.end() :]
    )


def verify_window_finder(resident):
    # Real native Wayland clients and a private virtual seat0 device pair.
    # No SDL event injection and no mutation of a physical seat.
    def resource(*args):
        return json.loads(run(cli, *args).stdout)["data"]

    def windows():
        return {w["title"]: w for w in resource("window", "list", "--mapped")}

    def seat():
        return resource("seat", "get", "1")

    def presentations():
        return {
            o["id"]: o["presented_workspace_id"] for o in resource("output", "list")
        }

    def new_actor(name, rgb):
        q = start([actor, name, rgb], name, control=True)
        wait(lambda: '"event":"frame_done"' in log(name), name + " frame")
        wait(lambda: name in windows(), name + " mapped")
        return q

    def send(q, name, command, event):
        marker = '"event":"' + event + '"'
        count = log(name).count(marker)
        assert q.poll() is None
        q.stdin.write((command + "\n").encode())
        q.stdin.flush()
        wait(lambda: log(name).count(marker) > count, name + " " + command)

    red = new_actor("red", "ff0000")
    send(red, "red", "input", "input_ready")
    green = new_actor("green", "00ff00")
    run(cli, "workspace", "focus", "2", "--sticky")
    blue = new_actor("blue", "0000ff")
    original = windows()
    assert original["red"]["workspace_id"] == original["green"]["workspace_id"] == 1
    assert original["blue"]["workspace_id"] == 2
    ids = {name: w["id"] for name, w in original.items()}
    run(cli, "window", "focus", str(ids["blue"]))
    assert presentations() == {1: 1, 2: 2}

    def key(name):
        send(red, "red", "key-" + name, "key_processed")

    def open_windows(target):
        offset = len(log("resident"))
        run(candidate, "picker")
        wait(lambda: new_attach("resident", "picker", offset), "picker mapped")
        wait(lambda: status()["picker_visible"], "picker visible")
        key("tab")
        wait(
            lambda: "window finder discovered " in log("resident")[offset:],
            "window discovery",
        )
        facts = seat()
        active = facts["focused_window"]
        history = facts["recent_window_ids"]
        live = windows()
        # Every fixture window has an actual compositor MRU entry. The UI's
        # order is active first then MRU, never a guessed title match.
        assert all(w["id"] in history for w in live.values())
        order = sorted(
            (w["id"] for w in live.values()),
            key=lambda i: (i != active, history.index(i)),
        )
        assert ids[target] in order
        for _ in order:
            key("up")
        for _ in range(order.index(ids[target])):
            key("down")
        return offset

    def expect_applied(target, offset):
        key("enter")
        wait(
            lambda: (
                f"window focus applied id={ids[target]}" in log("resident")[offset:]
            ),
            target + " verified receipt",
        )
        assert not status()["picker_visible"]
        assert seat()["focused_window"] == ids[target]
        wire = log("resident")[offset:]
        assert "wayspot-picker" in wire and re.search(
            r"zwlr_layer_surface_v1[#@]\d+\.destroy\(", wire
        )
        assert "wl_display#1.sync(" in wire or re.search(
            r"wl_display[#@]\d+\.sync\(", wire
        )
        assert "exclusive_layer" not in wire and "window selection failed" not in wire

    # Shared SDL display remains alive through the picker dismissal barrier.
    hold = notify("Selection with a live banner", ms=60000)
    wait(lambda: status()["notification_visible"], "banner before selection")
    offset = open_windows("red")
    assert status()["video_users"] == 2
    expect_applied("red", offset)
    assert presentations() == {1: 2, 2: 1}
    assert windows()["red"]["scene"]["status"] == "scene_enabled"
    assert windows()["green"]["scene"]["status"] == "layout_hidden"
    assert status()["video_users"] == 1 and status()["notification_visible"]
    close(hold)
    wait(lambda: status()["video_users"] == 0, "banner retired")

    run(cli, "window", "focus", str(ids["green"]))
    send(green, "green", "fullscreen", "request_fullscreen")
    wait(lambda: windows()["green"]["fullscreen"], "green fullscreen")
    offset = open_windows("red")
    expect_applied("red", offset)
    assert not windows()["green"]["fullscreen"]
    assert presentations() == {1: 2, 2: 1}

    run(cli, "workspace", "focus", "3")
    assert presentations() == {1: 2, 2: 3}
    assert windows()["red"]["scene"]["status"] == "workspace_unpresented"
    offset = open_windows("red")
    expect_applied("red", offset)
    assert presentations() == {1: 2, 2: 1}

    # Exact native pointer release, rather than selecting on button-down.
    offset = open_windows("red")
    send(red, "red", "move-first-row-right", "motion_processed")
    send(red, "red", "hold", "button_processed")
    assert status()["picker_visible"]
    send(red, "red", "release", "button_processed")
    wait(
        lambda: f"window focus applied id={ids['red']}" in log("resident")[offset:],
        "pointer selection",
    )
    assert not status()["picker_visible"] and seat()["focused_window"] == ids["red"]

    offset = open_windows("green")
    green.stdin.write(b"exit\n")
    green.stdin.flush()
    assert green.wait(timeout=5) == 0
    wait(lambda: "green" not in windows(), "selected window destroyed")
    key("enter")
    wait(
        lambda: (
            "window selection failed: SnowmanWindowGone" in log("resident")[offset:]
        ),
        "stale exact ID refused",
    )
    wait(lambda: status()["notification_visible"], "failure notification")
    assert not status()["picker_visible"] and status()["pid"] == resident.pid
    assert seat()["focused_window"] == ids["red"]
    assert "window focus applied" not in log("resident")[offset:]
    for name, window in windows().items():
        assert window["workspace_id"] == original[name]["workspace_id"]
    for q in (red, blue):
        q.stdin.write(b"exit\n")
        q.stdin.flush()
        assert q.wait(timeout=5) == 0
    print(
        "PASS: actual picker keyboard + pointer, monocle, greedy exchange, fullscreen, hidden workspace, stale-ID notification",
        flush=True,
    )
    return {
        "actual_wayland_input": True,
        "shared_display_barrier": True,
        "greedy_exchange": True,
        "monocle_reveal": True,
        "fullscreen_reveal": True,
        "hidden_workspace": True,
        "pointer_release": True,
        "stale_id_notification": True,
        "membership_preserved": True,
    }


try:
    private_bus = start(
        ["dbus-daemon", "--nofork", "--config-file=" + str(root / "bus.conf")],
        "private-bus",
    )
    wait(lambda: (root / "bus").is_socket(), "private bus ready")
    server = start([snow, "--config", root / "snowman.json"], "server")
    wait(
        lambda: (runtime / "snowman-command-wayland-0.sock").is_socket(),
        "private compositor ready",
    )
    names = [x["name"] for x in json.loads(run(cli, "monitor", "list").stdout)["data"]]
    print("PRIVATE_SNOWMAN_READY", names, flush=True)
    # Compare the existing deployed standalone architecture in the same fixture.
    oldn = start([baseline, "notifications"], "old-notification", True)
    oldw = start([baseline, "wallpaper", root / "wallpapers"], "old-wallpaper", True)
    oldt = start([baseline, "tray"], "old-tray")
    wait(
        lambda: (
            owner("org.freedesktop.Notifications")
            and owner("org.kde.StatusNotifierWatcher")
            and "wallpaper published 2" in log("old-wallpaper")
        ),
        "standalone owners",
    )
    old_cold = sample([oldn, oldw, oldt])
    old_notify = notify("old warm", ms=60000)
    wait(lambda: new_attach("old-notification", "notification"), "standalone banner")
    close(old_notify)
    time.sleep(0.25)
    old_warm = sample([oldn, oldw, oldt])
    old_hold = notify("old hold during picker", ms=60000)
    timings_old = []
    for i in range(5):
        t = time.monotonic_ns()
        q = start([baseline], f"old-picker-{i}", True)
        wait(lambda: new_attach(f"old-picker-{i}", "picker"), "standalone picker")
        timings_old.append((time.monotonic_ns() - t) / 1e6)
        assert stop(q) == 0
    close(old_hold)
    for q in (oldn, oldw, oldt):
        assert stop(q) == 0
    wait(
        lambda: (
            not owner("org.freedesktop.Notifications")
            and not owner("org.kde.StatusNotifierWatcher")
        ),
        "standalone released names",
    )
    resident = start([candidate, "resident", root / "resident.json"], "resident", True)
    wait(
        lambda: (
            status()["wallpaper_outputs"] == 2
            and owner("org.freedesktop.Notifications")
            and owner("org.kde.StatusNotifierWatcher")
        ),
        "combined ready",
    )
    assert (
        status()["pid"]
        == resident.pid
        == owner_pid("org.freedesktop.Notifications")
        == owner_pid("org.kde.StatusNotifierWatcher")
        == owner_pid("org.freedesktop.StatusNotifierWatcher")
    )
    assert status()["video_users"] == 0
    assert (
        run(candidate, "resident", root / "resident.json", check=False).returncode != 0
    )
    legacy = run(candidate, "wallpaper", root / "wallpapers", check=False)
    assert legacy.returncode != 0 and "RotationNameInUse" in legacy.stderr, (
        legacy.stderr
    )
    initial_color = pixel(names[0])
    assert initial_color in colors and pixel(names[1]) == initial_color
    cold = sample([resident])
    print("ALL_CAPABILITIES_SAME_PID", resident.pid, flush=True)
    mock = start(
        [Path("/usr/bin/python3"), repo / "tools/mock-sni.py", root / "action.txt"],
        "mock",
    )
    wait(lambda: status()["tray_items"] == 1, "mock tray registration")
    before_wall = roles("resident", "wallpaper")
    assert before_wall == 2
    hold = notify("hold during picker", ms=60000)
    wait(lambda: status()["notification_visible"], "notification visible")
    timings = []
    first_attach = []
    for i in range(20):
        offset = len(log("resident"))
        t = time.monotonic_ns()
        run(candidate, "picker")
        timings.append((time.monotonic_ns() - t) / 1e6)
        wait(lambda: new_attach("resident", "picker", offset), "picker role buffer")
        first_attach.append((time.monotonic_ns() - t) / 1e6)
        assert (
            status()["picker_visible"]
            and status()["video_users"] == 2
            and status()["notification_visible"]
        )
        if i == 0:
            wait(lambda: (root / "action.fetch").exists(), "actual SNI property fetch")
        run(candidate, "picker")
        assert roles("resident", "picker") == i + 1, (
            "idempotent summon created second picker"
        )
        run(candidate, "picker", "dismiss")
        assert (
            not status()["picker_visible"]
            and status()["video_users"] == 1
            and status()["notification_visible"]
        )
    assert roles("resident", "wallpaper") == before_wall
    close(hold)
    wait(lambda: status()["video_users"] == 0, "banner retired")
    cold_summon = []
    for i in range(5):
        offset = len(log("resident"))
        t = time.monotonic_ns()
        run(candidate, "picker")
        wait(
            lambda: new_attach("resident", "picker", offset),
            "picker with no video lease",
        )
        cold_summon.append((time.monotonic_ns() - t) / 1e6)
        run(candidate, "picker", "dismiss")
        assert status()["video_users"] == 0
    print("PASS: 20 shared picker lifetimes, notification and tray survive", flush=True)
    run(candidate, "picker")
    nid = notify("expiry alongside picker", ms=250)
    wait(lambda: status()["notification_visible"], "expiry banner")
    wait(
        lambda: not status()["notification_visible"] and status()["picker_visible"],
        "expiry kept picker",
    )
    run(candidate, "picker", "dismiss")
    for i in range(4):
        run(candidate, "wallpaper", "rotate")
        initial_color = next(c for c in colors if c != initial_color)
        wait(
            lambda: all(pixel(n) == initial_color for n in names),
            "actual rotated pixels",
        )
    assert roles("resident", "wallpaper") == before_wall
    stop(mock)
    wait(lambda: status()["tray_items"] == 0, "tray unregister")
    warm = sample([resident])
    assert warm["voluntary_switch_delta"] <= 2 and warm["cpu_ticks_delta"] <= 1, warm
    assert (
        resident.poll() is None
        and status()["pid"] == resident.pid
        and status()["video_users"] == 0
    )
    assert not re.search(r"wl_display[#@]\d+\.error\(", log("resident"))
    finder = verify_window_finder(resident) if actor else None
    assert stop(resident) == 0
    wait(
        lambda: (
            not owner("org.freedesktop.Notifications")
            and not owner("org.kde.StatusNotifierWatcher")
        ),
        "resident released names",
    )
    disabled = start([candidate, "resident", root / "disabled.json"], "disabled", True)
    wait(lambda: status()["pid"] == disabled.pid, "disabled owner")
    state = status()
    assert not any(
        state[k]
        for k in (
            "picker",
            "notifications",
            "tray",
            "wallpaper",
            "picker_visible",
            "notification_visible",
            "wallpaper_outputs",
            "video_users",
        )
    )
    assert not owner("org.freedesktop.Notifications") and not owner(
        "org.kde.StatusNotifierWatcher"
    )
    assert "PickerDisabled" in run(candidate, "picker", check=False).stderr
    assert (
        "WallpaperDisabled" in run(candidate, "wallpaper", "rotate", check=False).stderr
    )
    assert (
        roles("disabled", "wallpaper")
        == roles("disabled", "picker")
        == roles("disabled", "notification")
        == 0
    )
    assert stop(disabled) == 0
    marker = root / "launch.json"
    helper = subprocess.run(
        [
            str(candidate),
            "--launch-plan",
            "/usr/bin/python3",
            "-c",
            'import json,os,signal,sys;open(sys.argv[1],"w").write(json.dumps({"pid":os.getpid(),"blocked":[int(x) for x in signal.pthread_sigmask(signal.SIG_BLOCK,[]) ]}))',
            str(marker),
        ],
        env=env,
        capture_output=True,
        timeout=5,
        preexec_fn=lambda: signal.pthread_sigmask(
            signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM}
        ),
    )
    assert helper.returncode == 0, helper.stderr
    wait(lambda: marker.is_file() and marker.stat().st_size > 0, "detached app marker")
    launched = json.loads(marker.read_text())
    assert (
        int(signal.SIGINT) not in launched["blocked"]
        and int(signal.SIGTERM) not in launched["blocked"]
    ), launched
    assert "error in client communication" not in log("server")
    receipt = {
        "baseline_cold": old_cold,
        "baseline_warm": old_warm,
        "resident_cold": cold,
        "resident_warm": warm,
        "baseline_picker_first_attach_ms": timings_old,
        "resident_picker_command_ms": timings,
        "resident_picker_first_attach_ms": first_attach,
        "resident_picker_without_banner_ms": cold_summon,
        "resident_pid": resident.pid,
        "picker_cycles": 25,
        "wallpaper_rotations": 4,
        "disabled_pass": True,
        "tray_fetch_pass": True,
        "detached_launch_mask_pass": True,
        "window_finder": finder,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2))
    print("RESIDENT_PASS", json.dumps(receipt), flush=True)
finally:
    for q in reversed(children):
        stop(q)
    for f in handles:
        f.close()
    shutil.rmtree(root)
