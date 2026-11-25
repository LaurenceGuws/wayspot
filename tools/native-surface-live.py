#!/usr/bin/env python3
"""Execute the source-owned native surface tests against one private head."""

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
    cfg.write_text(
        json.dumps(
            {
                "backend": {
                    "driver": "headless",
                    "input": "none",
                    "headless_outputs": 1,
                },
                "publish_session_environment": False,
                "children": [],
            }
        )
    )
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
        assert "NATIVE_SURFACE_LIVE_PASS" in report, (
            "native live test was not exercised"
        )
        assert server.poll() is None
        assert (out / "compositor.log").read_text().count("created layer surface") == 6
        assert (
            "error in client communication" not in (out / "compositor.log").read_text()
        )
        receipt = {
            "schema": "wayspot-native-surface-live/v1",
            "result": "pass",
            "tests_sha256": hashlib.sha256(tests.read_bytes()).hexdigest(),
            "compositor_sha256": hashlib.sha256(snowman.read_bytes()).hexdigest(),
            "shared_display_lifetimes": 3,
            "independent_roles": 6,
            "actual_glyphs_and_pixels": True,
            "sdl_video_initialized": False,
            "scale": 1,
            "logical_output": [1280, 720],
        }
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("NATIVE_SURFACE_LIVE_PASS", json.dumps(receipt), flush=True)
finally:
    if server is not None and server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=3)
    shutil.rmtree(root)
