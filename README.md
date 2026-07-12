# Wayspot

Wayspot is a pragmatic Wayland desktop busybox built in Zig.

It gives the desktop a small set of direct surfaces:

- a default apps picker mode for launching installed applications and available local desktop actions;
- a freedesktop notification D-Bus interface with retained history;
- a still-image wallpaper loop;
- focused per-monitor sunglasses overlays.

The picker is transient and opens the apps mode first. The notification,
wallpaper, and overlay loops are long-lived only where the desktop behavior
requires them. GUI and CLI consume the same bounded Cmd tree; scalar, toggle,
and path leaves use the same typed Input values, with GUI controls for
interactive tuning and raw values in the CLI.

## Try it

```sh
wayspot --ui
wayspot apps
wayspot notifications
wayspot wallpaper
wayspot wallpaper rotate
wayspot sunglasses
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
are in [`AGENTS.md`](AGENTS.md). The project design, rules, active scope, and
reviewed debt register are [`project_design.yml`](project_design.yml),
[`project_rules.yml`](project_rules.yml),
[`project_version_scope.yml`](project_version_scope.yml), and
[`debt_offenders.yml`](debt_offenders.yml).
