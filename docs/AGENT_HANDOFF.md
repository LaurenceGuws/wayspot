# Agent Handoff

## Current Baseline

- GTK daemon summon/hide/toggle flow is the primary launcher lifecycle.
- Provider-driven search is the current launcher model.
- Lua config is the active runtime state authority.
- WM integration currently targets Hyprland through `src/wm/`.
- Theme and wallpaper runtime paths now exist, but still need architectural cleanup.

## Current Constraints

- Keep changes aligned with `docs/architecture/APP_LAYERING.md`.
- Keep shell/runtime behavior routed through app subsystems, not temporary shell glue.
- Keep route/provider behavior deterministic and narrow.
- Update the owning architecture doc when behavior changes materially.

## Next

1. Clean up theme/wallpaper integration against the documented subsystem boundaries.
2. Remove remaining hacked-on behavior that bypasses config, action planning, or WM/runtime ownership.
3. Keep workstream notes and architecture docs aligned as each cleanup slice lands.

