# wayspot

Wayspot is a small Wayland launcher, command picker, notification DBus interface,
wallpaper loop, and focused surface set built in Zig.

## Commands

Run one bounded picker lifecycle:

```bash
wayspot --ui
```

List the picker command rows in the terminal:

```bash
wayspot commands
```

Query the same command rows used by the picker:

```bash
wayspot query settings
```

Open a command payload from the picker:

```bash
wayspot open settings
```

Print Nushell custom completion records:

```bash
wayspot complete nushell wayspot query set
```

Own the freedesktop notification D-Bus name:

```bash
wayspot --notifications-daemon
```

For local development:

```bash
./re-run.sh
```

## UI defaults

Wayspot embeds UI defaults from `assets/lua/defaults.lua`. A user override at
`$HOME/.config/wayspot/defaults.lua` may replace individual loaded values;
missing fields keep the embedded defaults.

Defaults loading is bounded: each Lua defaults file is capped at 32 KiB, runs
without Lua standard libraries, and stops after 100000 Lua instructions. Invalid
present user values are rejected instead of partially mutating the embedded
appearance state.

## Current features

- The picker is CLI-summoned. It starts, accepts input, launches one detached command, and cleans up.
- Picker modes include application rows, notification history rows, wallpaper lifecycle rows, and sunglasses runtime configuration.
- The notification D-Bus interface owns a long-lived freedesktop notification name and can show retained notification history through the picker.
- The wallpaper loop owns one background surface per monitor and uses configured still images.
- Sunglasses owns per-monitor overlay settings for the red/blue filter, dimming, and image opacity.

## Scope

- GTK, resident launcher IPC, shell modules, broad wallpaper toolkits, and script engines are out of scope.
