# Bootstrap

This doc owns practical build, run, test, and local dev entrypoints.

## Build

```bash
zig build
```

Headless-safe build:

```bash
zig build -Denable_headless=true
```

## Run

Direct run:

```bash
zig build run
```

Daemon path:

```bash
wayspot --ui-daemon
wayspot --ctl summon
```

Recommended local dev loop:

```bash
./re-run.sh
```

`re-run.sh` is the intended repo-local rebuild/restart/summon path.

## Test

```bash
zig build test
```

Headless-safe tests:

```bash
zig build test -Denable_headless=true
```

## Useful Runtime Commands

```bash
wayspot --print-config
wayspot --print-outputs
wayspot --print-shell-health
wayspot --ctl ping
wayspot --ctl wm_event_stats
```

## Theme + Wallpaper Runtime

```bash
wayspot --apply-theme ayu
wayspot --toggle-wallpaper-slideshow
wayspot --ctl slideshow_toggle
wayspot --ctl slideshow_status
wayspot --wallpaper-slideshow
wayspot --set-wallpaper /path/to/file.png
wayspot --sort-wallpapers --dry-run --verbose
```

## Notes

- Live Hypr/Waybar integration currently assumes the user-facing binary path is
  the installed `wayspot` binary, not only `zig-out/bin/wayspot`.
- If behavior differs between repo changes and session behavior, verify which
  binary Hyprland is launching.
