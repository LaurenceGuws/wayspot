#!/usr/bin/env python3
"""Probe Hyprland's direct-window wallpaper path.

This is a development receipt tool, not Wayspot runtime code. It proves the
event flow we would need before replacing hyprpaper with Wayspot-owned SDL
surfaces:

1. read monitor facts
2. launch one Wayland-native window with wallpaper-like one-shot rules
3. observe the window through the event socket and clients JSON
4. push the window to the bottom of the floating stack
5. close it once
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import threading
import time
from dataclasses import dataclass


APP_ID = "wayspot-wallpaper-probe"
EVENT_LIMIT = 64
READ_LIMIT = 1024 * 1024


@dataclass(frozen=True)
class Monitor:
    name: str
    width: int
    height: int
    x: int
    y: int
    focused: bool


def run(args: list[str]) -> str:
    result = subprocess.run(
        args,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if len(result.stdout) > READ_LIMIT:
        raise RuntimeError(f"{args[0]} output exceeded read limit")
    return result.stdout


def hypr_dispatch(expression: str) -> str:
    return run(["hyprctl", "dispatch", expression]).strip()


def monitors() -> list[Monitor]:
    raw = json.loads(run(["hyprctl", "monitors", "-j"]))
    result: list[Monitor] = []
    for entry in raw:
        result.append(
            Monitor(
                name=entry["name"],
                width=int(entry["width"]),
                height=int(entry["height"]),
                x=int(entry["x"]),
                y=int(entry["y"]),
                focused=bool(entry["focused"]),
            )
        )
    return result


def clients() -> list[dict[str, object]]:
    return json.loads(run(["hyprctl", "clients", "-j"]))


def find_client(title: str) -> dict[str, object] | None:
    for client in clients():
        if client.get("class") == APP_ID and client.get("title") == title:
            return client
    return None


def event_socket_path() -> str:
    runtime_dir = os.environ["XDG_RUNTIME_DIR"]
    signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    return f"{runtime_dir}/hypr/{signature}/.socket2.sock"


def collect_events(stop: threading.Event, out: list[str]) -> None:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(0.25)
    try:
        sock.connect(event_socket_path())
        pending = b""
        while not stop.is_set() and len(out) < EVENT_LIMIT:
            try:
                chunk = sock.recv(4096)
            except TimeoutError:
                continue
            if not chunk:
                break
            pending += chunk
            while b"\n" in pending and len(out) < EVENT_LIMIT:
                line, pending = pending.split(b"\n", 1)
                text = line.decode("utf-8", "replace")
                if APP_ID in text or text.startswith(("openwindow>>", "closewindow>>", "focusedmon>>", "focusedmonv2>>", "monitor")):
                    out.append(text)
    finally:
        sock.close()


def lua_string(value: str) -> str:
    return json.dumps(value)


def spawn_probe(title: str, seconds: int, monitor: Monitor) -> None:
    command = (
        "kitty "
        f"--class {APP_ID} "
        f"-T {title} "
        "--config NONE "
        "-o confirm_os_window_close=0 "
        "-o background=#202326 "
        "-o foreground=#f8f8f2 "
        "-o window_padding_width=24 "
        f"sh -c {lua_string(f'printf \"Wayspot wallpaper probe on {monitor.name}\\n\"; sleep {seconds + 4}')}"
    )
    expression = (
        "hl.dsp.exec_cmd("
        + lua_string(command)
        + ", { "
        + "float = true, "
        + f"monitor = {lua_string(monitor.name + ' silent')}, "
        + 'size = { "monitor_w", "monitor_h" }, '
        + "move = { 0, 0 }, "
        + "pin = true, "
        + "no_initial_focus = true, "
        + 'content = "photo", '
        + "border_size = 0, "
        + "decorate = false, "
        + "no_focus = true, "
        + "focus_on_activate = false, "
        + "no_anim = true, "
        + "no_shadow = true, "
        + "no_blur = true, "
        + "render_unfocused = true "
        + "})"
    )
    print(f"launch: {hypr_dispatch(expression)}")


def close_probe(address: str) -> None:
    selector = "address:" + address
    print(
        "close: "
        + hypr_dispatch(
            "hl.dsp.window.close({ window = " + lua_string(selector) + " })"
        )
    )


def push_bottom(address: str) -> None:
    selector = "address:" + address
    print(
        "bottom: "
        + hypr_dispatch(
            'hl.dsp.window.alter_zorder({ mode = "bottom", window = '
            + lua_string(selector)
            + " })"
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=int, default=12)
    parser.add_argument("--monitor", default="focused")
    parser.add_argument("--zorder", choices=("bottom", "top", "none"), default="bottom")
    args = parser.parse_args()

    if args.seconds < 2 or args.seconds > 60:
        raise SystemExit("--seconds must be between 2 and 60")

    known_monitors = monitors()
    if args.monitor == "focused":
        monitor = next((item for item in known_monitors if item.focused), None)
    else:
        monitor = next((item for item in known_monitors if item.name == args.monitor), None)
    if monitor is None:
        names = ", ".join(item.name for item in known_monitors)
        raise SystemExit(f"monitor not found: {args.monitor}; available: {names}")

    title = f"{APP_ID}-{int(time.time())}"
    stop = threading.Event()
    events: list[str] = []
    thread = threading.Thread(target=collect_events, args=(stop, events), daemon=True)
    thread.start()

    print(
        f"target_monitor: {monitor.name} physical={monitor.width}x{monitor.height}"
        f" at={monitor.x},{monitor.y} focused={monitor.focused}"
    )
    print(f"title: {title}")

    address = ""
    try:
        spawn_probe(title, args.seconds, monitor)
        for _ in range(40):
            client = find_client(title)
            if client is not None:
                address = str(client["address"])
                print(
                    "client: "
                    + json.dumps(
                        {
                            "address": client.get("address"),
                            "class": client.get("class"),
                            "title": client.get("title"),
                            "at": client.get("at"),
                            "size": client.get("size"),
                            "floating": client.get("floating"),
                            "pinned": client.get("pinned"),
                            "monitor": client.get("monitor"),
                            "contentType": client.get("contentType"),
                            "acceptsInput": client.get("acceptsInput"),
                            "fullscreen": client.get("fullscreen"),
                            "fullscreenClient": client.get("fullscreenClient"),
                        },
                        sort_keys=True,
                    )
                )
                break
            time.sleep(0.1)
        if not address:
            raise RuntimeError("probe window did not appear in hyprctl clients")

        if args.zorder == "bottom":
            push_bottom(address)
        elif args.zorder == "top":
            selector = "address:" + address
            print(
                "top: "
                + hypr_dispatch(
                    'hl.dsp.window.alter_zorder({ mode = "top", window = '
                    + lua_string(selector)
                    + " })"
                )
            )
        print(f"visible_for_seconds: {args.seconds}")
        time.sleep(args.seconds)
    finally:
        stop.set()
        thread.join(timeout=1.0)
        if address:
            try:
                close_probe(address)
            except Exception as error:
                print(f"close_error: {error}", file=sys.stderr)

    print("events:")
    for event in events:
        print("  " + event)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
