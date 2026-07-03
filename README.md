# wayspot

Wayspot is a small Wayland launcher and notification daemon built in Zig.

## Commands

Run one bounded SDL picker lifecycle:

```bash
wayspot --ui
```

Own the freedesktop notification D-Bus name:

```bash
wayspot --notifications-daemon
```

For local development:

```bash
./re-run.sh
```

## Scope

- The launcher is CLI-summoned. It starts, accepts input, launches one detached command, and cleans up.
- The notification daemon is the only long-lived interface.
- GTK, resident launcher IPC, shell modules, wallpaper tools, provider registries, and runtime scripting VMs are out of scope.
