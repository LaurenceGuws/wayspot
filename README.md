# wayspot

A Wayland shell daemon and launcher built in Zig.

`wayspot` is not just a one-shot app launcher anymore. The current shape is a
long-lived shell process with:

- a warm GTK launcher (`--ui-daemon`, `--ui-resident`)
- a local control plane (`--ctl ...`)
- provider-driven search and route handling
- Lua runtime config
- compositor-aware WM integration through `src/wm/`
- shell-facing theme and wallpaper runtime paths

## What It Is

Current emphasis:

- Wayland-first launcher and shell surfaces
- deterministic daemon summon/hide/toggle behavior
- provider/ranking pipeline instead of ad hoc menu assembly
- Lua-configured runtime behavior
- explicit WM integration boundaries
- Zig-owned shell runtime paths for theme and wallpaper behavior

## Quick Start

Build:

```bash
zig build
```

Run the warm daemon:

```bash
wayspot --ui-daemon
```

Summon from another shell:

```bash
wayspot --ctl summon
```

If you are working in this repo, use:

```bash
./re-run.sh
```

## Core Commands

Launcher lifecycle:

```bash
wayspot --ui
wayspot --ui-resident
wayspot --ui-daemon
```

Control plane:

```bash
wayspot --ctl ping
wayspot --ctl summon
wayspot --ctl hide
wayspot --ctl toggle
wayspot --ctl version
wayspot --ctl shell_health
wayspot --ctl wm_event_stats
```

Config/runtime:

```bash
wayspot --print-config
wayspot --print-outputs
wayspot --print-shell-health
```

Theme/wallpaper runtime:

```bash
wayspot --apply-theme ayu
wayspot --toggle-wallpaper-slideshow
wayspot --wallpaper-slideshow
wayspot --set-wallpaper /path/to/file.png
wayspot --sort-wallpapers --dry-run --verbose
```

## Routes

Current route prefixes:

- `@` apps
- `#` windows
- `!` workspaces
- `~` recent dirs
- `,` themes
- `%` files
- `&` grep
- `+` packages
- `^` icons
- `*` nerd icons
- `:` emoji
- `$` notifications
- `>` run
- `=` calculator
- `?` web

## Config

Runtime config lives at:

- `~/.config/wayspot/config.lua`

When missing, `wayspot` creates a default config automatically on startup paths
that load runtime config.

Theme state is now owned by Lua config, not shell env files.

## Documentation

Use these as the real entrypoints:

- [Docs Index](docs/INDEX.md)
- [Workflow](docs/WORKFLOW.md)
- [Agent Handoff](docs/AGENT_HANDOFF.md)
- [Architecture: App Shell Split](docs/architecture/APP_SHELL_SPLIT.md)
- [Architecture: App Layering](docs/architecture/APP_LAYERING.md)
- [Architecture: Daemon Architecture](docs/architecture/DAEMON_ARCHITECTURE.md)
- [Architecture: UI Architecture](docs/architecture/UI_ARCHITECTURE.md)
- [Architecture: Bootstrap](docs/architecture/BOOTSTRAP.md)
- [Architecture: Config](docs/architecture/CONFIG.md)
- [Architecture: Subsystem Inventory](docs/architecture/SUBSYSTEM_INVENTORY.md)
- [Architecture: Provider Inventory](docs/architecture/PROVIDER_INVENTORY.md)
- [Architecture: Providers And Routes](docs/architecture/PROVIDERS_AND_ROUTES.md)
- [Architecture: DE Shell Vision](docs/architecture/DE_SHELL_VISION.md)
- [Architecture: Control Plane](docs/architecture/WA1_CONTROL_PLANE_SPEC.md)
- [Architecture: Engineering](docs/architecture/ENGINEERING.md)

## Dev Loop

```bash
./re-run.sh
zig build
zig build test
scripts/dev.sh check
scripts/dev.sh fmt
scripts/dev.sh build
scripts/dev.sh test
```

## Packaging

- `packaging/arch/PKGBUILD`
- `packaging/systemd/wayspot.service`
- `packaging/desktop/wayspot.desktop`
