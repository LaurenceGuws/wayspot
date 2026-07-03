# wayspot

A Wayland launcher built in Zig.

`wayspot` is currently a bounded CLI-summoned SDL picker with:

- one picker lifecycle per summon
- app/action search
- detached command launch
- optional resident IPC for future evidence work
- minimal notification daemon scope

## What It Is

Current emphasis:

- CLI-driven SDL launcher
- deterministic create/show/input/launch/cleanup behavior
- provider/ranking pipeline for app and action candidates
- minimal runtime surface with no GTK dependency

## Quick Start

Build:

```bash
zig build
```

Run the picker:

```bash
wayspot --ui
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

Local docs explorer:

```bash
./scripts/open_docs_browser.sh
```

Project-owned docs browser config lives under `tools/docs_browser/`.

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
