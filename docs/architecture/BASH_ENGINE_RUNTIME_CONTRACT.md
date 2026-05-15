# Bash Engine Runtime Contract

This document mirrors the `bash_engine` cross-repo contract from the `wayspot`
side.

## Boundary

`wayspot` owns runtime theme and wallpaper behavior. `bash_engine` owns tracked
dotfile payloads and shell/profile setup.

Because `bash_engine` links dot directories into `~/.config`, writes from
`wayspot` to live config may mutate tracked files in `../bash_engine`.

## Known Cross-Repo Write Targets

`wayspot` currently writes:

- `~/.config/hypr/modules/hypr_theme_current.lua`
- `~/.config/hypr/hyprpaper.conf`

When those paths are symlinked into `../bash_engine/dots`, the write is a
cross-repo mutation.

## Runtime Ownership

`wayspot` may own:

- current theme state in Lua config
- runtime selector files
- wallpaper assignment writes
- reload/restart behavior for Hyprland and Hyprpaper

`wayspot` must not silently own:

- static baseline dotfiles
- curated theme source assets
- repo installation/link behavior
- fallback paths into `~/personal/bash_engine` without an architecture ticket

## Policy Until BEM-GATE-10

- Existing writes may continue for behavior stability.
- Any change to these writes is cross-repo scope.
- Tickets must cite `../bash_engine/docs/CROSS_REPO_RUNTIME_CONTRACT.md`.
- The preferred direction is to split tracked baseline templates from generated
  runtime-current files.
