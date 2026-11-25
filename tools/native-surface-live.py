#!/usr/bin/env python3
"""Execute the source-owned native surface or mixed-scale private fixture."""

from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

repo = Path(__file__).resolve().parent.parent
tests = Path(sys.argv[1]).resolve(strict=True)
assert sys.argv[2:] in ([], ["--mixed"], ["--input"])
mixed = sys.argv[2:] == ["--mixed"]
input_test = sys.argv[2:] == ["--input"]
snowman = Path(os.environ["SNOWMAN_COMPOSITOR"]).resolve(strict=True)
scratch = Path(os.environ["WAYSPOT_TEST_SCRATCH"]).resolve(strict=True)
out = Path(os.environ["WAYSPOT_PROOF_DIR"]).resolve(strict=True)
assert tests.is_relative_to(repo / ".zig-cache")
assert snowman.is_file() and snowman.name == "snowman-desktop-dev"
assert not snowman.is_relative_to("/usr/local/bin")
assert scratch.is_dir() and out.is_dir() and not (out / "receipt.json").exists()
root = Path(tempfile.mkdtemp(prefix="ns.", dir=scratch))
root.chmod(0o700)
server = None
try:
    for name in ("r", "h", "c", "d", "cache", "state"):
        (root / name).mkdir(mode=0o700)
    runtime = root / "r"
    assert len(str(runtime / "snowman-command-wayland-0.sock")) < 108
    cfg = root / "snowman.json"
    config = {
        "backend": {
            "driver": "headless",
            "input": "none",
            "headless_outputs": 2 if mixed else 1,
        },
        "publish_session_environment": False,
        "children": [],
    }
    if mixed:
        config["private"] = {"display_control": True}
        config["outputs"] = [
            {
                "name": "HEADLESS-2",
                "mode": {"width": 1280, "height": 720, "refresh_mhz": 60000},
                "scale": {"numerator": 1, "denominator": 1},
                "at": {"x": 0, "y": 0},
            },
            {
                "name": "HEADLESS-1",
                "mode": {"width": 1920, "height": 1080, "refresh_mhz": 60000},
                "scale": {"numerator": 3, "denominator": 2},
                "at": {"x": 1280, "y": 0},
            },
        ]
    if input_test:
        config["private"] = {"second_seat": True}
        config["outputs"] = [
            {
                "name": "HEADLESS-1",
                "mode": {"width": 2240, "height": 1260, "refresh_mhz": 60000},
                "scale": {"numerator": 7, "denominator": 4},
                "at": {"x": 0, "y": 0},
            }
        ]
    cfg.write_text(json.dumps(config))
    env = {
        "PATH": "/usr/bin:/bin",
        "LANG": "C.UTF-8",
        "HOME": str(root / "h"),
        "XDG_CONFIG_HOME": str(root / "c"),
        "XDG_DATA_HOME": str(root / "d"),
        "XDG_DATA_DIRS": "/usr/share",
        "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_STATE_HOME": str(root / "state"),
        "XDG_RUNTIME_DIR": str(runtime),
        "WAYLAND_DISPLAY": "wayland-0",
        "WAYSPOT_NATIVE_PRIVATE_TEST": str(runtime),
    }
    if mixed:
        cli = snowman.with_name("snowman").resolve(strict=True)
        assert cli.parent == snowman.parent and cli.is_file()
        env["WAYSPOT_NATIVE_MIXED_TEST"] = str(runtime)
        env["WAYSPOT_NATIVE_CLI"] = str(cli)
    if input_test:
        actor = snowman.with_name("snowman-sim-client").resolve(strict=True)
        assert actor.parent == snowman.parent and actor.is_file()
        env["WAYSPOT_NATIVE_INPUT_TEST"] = str(runtime)
        env["WAYSPOT_NATIVE_ACTOR"] = str(actor)
    with (out / "compositor.log").open("wb") as log:
        server = subprocess.Popen(
            [str(snowman), "--config", str(cfg)],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
        )
        deadline = time.monotonic() + 8
        while not (runtime / "snowman-command-wayland-0.sock").is_socket():
            assert server.poll() is None and time.monotonic() < deadline, (
                "private compositor readiness"
            )
            time.sleep(0.002)
        with (out / "tests.log").open("wb") as proof:
            result = subprocess.run(
                [str(tests)],
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=proof,
                stderr=proof,
                timeout=45,
            )
        report = (out / "tests.log").read_text(errors="replace")
        assert result.returncode == 0, report[-5000:]
        marker = (
            "NATIVE_INPUT_LIVE_PASS"
            if input_test
            else "NATIVE_SCALE_LIVE_PASS"
            if mixed
            else "NATIVE_SURFACE_LIVE_PASS"
        )
        assert marker in report, "native live test was not exercised"
        assert server.poll() is None
        assert (out / "compositor.log").read_text().count("created layer surface") == (
            1 if input_test else 2 if mixed else 6
        )
        assert (
            "error in client communication" not in (out / "compositor.log").read_text()
        )
        receipt = {
            "schema": "wayspot-native-surface-live/v1",
            "result": "pass",
            "tests_sha256": hashlib.sha256(tests.read_bytes()).hexdigest(),
            "compositor_sha256": hashlib.sha256(snowman.read_bytes()).hexdigest(),
            "shared_display_lifetimes": 1 if mixed or input_test else 3,
            "independent_roles": 1 if input_test else 2 if mixed else 6,
            "actual_glyphs_and_pixels": not input_test,
            "sdl_video_initialized": False,
            "scale": 1.75 if input_test else [1, 1.5, 1.75, 2] if mixed else 1,
            "logical_output": [1280, 720],
        }
        if input_test:
            receipt.update(
                {
                    "actual_wayland_input": True,
                    "local_seat_only": True,
                    "xkb_text_and_navigation": True,
                    "matched_button_release": True,
                    "logical_pointer_coordinates": True,
                    "focus_retired": True,
                    "actor_sha256": hashlib.sha256(actor.read_bytes()).hexdigest(),
                }
            )
        if mixed:
            receipt.update(
                {
                    "mixed_density": True,
                    "in_place_scale_transitions": 4,
                    "stable_surface_identity": True,
                    "frame_receipts": [
                        line.strip()
                        for line in report.splitlines()
                        if "NATIVE_SCALE_FRAME" in line
                    ],
                }
            )
            assert len(receipt["frame_receipts"]) == 6
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(marker, json.dumps(receipt), flush=True)
finally:
    if server is not None and server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=3)
    shutil.rmtree(root)
