# Wayspot

Wayspot is a pragmatic Wayland desktop busybox built in Zig.

It gives the desktop a small set of direct surfaces:

- a CLI-summoned picker for opening one command;
- a freedesktop notification D-Bus interface with retained history;
- a still-image wallpaper loop;
- focused per-monitor sunglasses overlays.

The picker is transient. The notification, wallpaper, and overlay loops are
long-lived only where the desktop behavior requires them. Every retained list,
command, surface, and lifecycle is bounded and owned.

## Try it

```sh
wayspot --ui
wayspot commands
wayspot query settings
wayspot open settings
wayspot --notifications-daemon
wayspot --wallpaper
```

For local development:

```sh
./re-run.sh
```

## Mission

Wayspot keeps useful desktop actions close to the operator and keeps the core
path small: start, act, and clean up. It is not a resident launcher protocol,
GTK application framework, shell module, broad window inventory, scripting VM,
or generic UI toolkit.

The complete product contract is [`DOMAIN.yml`](DOMAIN.yml). Engineering rules
are in [`AGENTS.md`](AGENTS.md).