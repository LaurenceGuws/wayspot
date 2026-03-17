# Code Quality Review TODO

Status: active
Owner: shell
Last-Reviewed: 2026-03-17

This file tracks the architecture and code-quality cleanup backlog from the
docs-driven review. Work through these in order unless a blocking dependency
forces a reorder.

## Progress Rules

- Mark each item as `todo`, `in_progress`, `blocked`, or `done`.
- Do not mark an item `done` until code, tests, and docs are aligned.
- If an item changes architecture, update the owning doc in the same slice.
- Prefer fixing root ownership problems before cleanup-only polish.

## Priority Order

1. Unify theme state into the typed Lua config subsystem.
2. Remove runtime mutation of external dotfiles repo state.
3. Move WM-facing command behavior behind the WM abstraction.
4. Pull default-loadout policy out of GTK/UI code.
5. Repair control-plane protocol correctness.
6. Repair theme/wallpaper runtime ownership and lifecycle issues.
7. Remove stale tests, stale UX hints, and leftover scaffold/dead code.

## TODO

### 1. Typed Theme Config Ownership

Status: `todo`
Priority: `highest`

Problem:
- Theme state is documented as Lua-owned durable config, but `Settings` does not
  model it and the Lua loader does not parse it.
- Theme persistence currently bypasses config parsing entirely.

Files:
- [src/config/mod.zig](/home/home/personal/wayspot/src/config/mod.zig)
- [src/config/lua_config.zig](/home/home/personal/wayspot/src/config/lua_config.zig)
- [src/config/default_lua.zig](/home/home/personal/wayspot/src/config/default_lua.zig)
- [src/tools/theme_state.zig](/home/home/personal/wayspot/src/tools/theme_state.zig)
- [docs/architecture/CONFIG.md](/home/home/personal/wayspot/docs/architecture/CONFIG.md)
- [docs/subsystems/CONFIG_AND_LUA.md](/home/home/personal/wayspot/docs/subsystems/CONFIG_AND_LUA.md)

Acceptance:
- `Settings` has a typed theme section or equivalent first-class field.
- Lua load/save behavior for theme state goes through the config subsystem.
- `theme_state` no longer parses `config.lua` by brittle string matching.
- Docs describe the final authoritative path correctly.

Notes:
- This is the root fix for multiple later theme/runtime issues.

### 2. Remove Runtime Mutation Of External Dotfiles Repo

Status: `todo`
Priority: `highest`

Problem:
- `applyTheme` writes into `~/personal/bash_engine` during runtime.
- That is environment-specific and violates subsystem ownership.

Files:
- [src/tools/theme_apply.zig](/home/home/personal/wayspot/src/tools/theme_apply.zig)
- [docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
- [docs/architecture/APP_LAYERING.md](/home/home/personal/wayspot/docs/architecture/APP_LAYERING.md)

Acceptance:
- Runtime theme apply only mutates runtime-owned state/config.
- Any repo-sync workflow is explicit and outside the runtime hot path.
- No hardcoded `~/personal/bash_engine` dependency remains in runtime code.

Dependency:
- Prefer doing this after item 1 so config ownership is clear first.

### 3. Move WM Actions Behind WM Backend Contracts

Status: `todo`
Priority: `highest`

Problem:
- UI/common dispatch hardcodes `hyprctl dispatch ...` for windows/workspaces.
- Wallpaper runtime takes a generic backend but still hardcodes Hyprpaper
  behavior outside the backend contract.

Files:
- [src/ui/common/dispatch.zig](/home/home/personal/wayspot/src/ui/common/dispatch.zig)
- [src/wm/types.zig](/home/home/personal/wayspot/src/wm/types.zig)
- [src/wm/hyprland.zig](/home/home/personal/wayspot/src/wm/hyprland.zig)
- [src/tools/wallpaper_runtime.zig](/home/home/personal/wayspot/src/tools/wallpaper_runtime.zig)
- [docs/subsystems/WM_INTEGRATION.md](/home/home/personal/wayspot/docs/subsystems/WM_INTEGRATION.md)

Acceptance:
- Window/workspace actions route through WM backend methods, not shell command
  strings in UI/common code.
- Wallpaper support is either:
  - properly modeled as backend capability, or
  - explicitly documented as Hyprland-only runtime code with no fake generic API.
- UI/common no longer needs compositor-specific command construction.

### 4. Move Default Loadout Policy Out Of GTK

Status: `todo`
Priority: `high`

Problem:
- GTK default-loadout code runs hardcoded route queries, re-ranks rows locally,
  and contains repo-specific `zide` bias.

Files:
- [src/ui/gtk/default_loadout.zig](/home/home/personal/wayspot/src/ui/gtk/default_loadout.zig)
- [src/app/search_service.zig](/home/home/personal/wayspot/src/app/search_service.zig)
- [docs/architecture/UI_ARCHITECTURE.md](/home/home/personal/wayspot/docs/architecture/UI_ARCHITECTURE.md)
- [docs/subsystems/SEARCH_SERVICE.md](/home/home/personal/wayspot/docs/subsystems/SEARCH_SERVICE.md)

Acceptance:
- Default-loadout policy is owned by app/search/runtime, not GTK.
- No repo-specific `zide` bias remains in UI code.
- GTK consumes a runtime contract for suggested/default rows.

### 5. Strengthen Action Contracts

Status: `todo`
Priority: `high`

Problem:
- Action handling is still mostly opaque shell-command forwarding.
- `cmd:` remains as a weak literal escape hatch.

Files:
- [src/providers/actions.zig](/home/home/personal/wayspot/src/providers/actions.zig)
- [src/ui/common/dispatch.zig](/home/home/personal/wayspot/src/ui/common/dispatch.zig)
- [docs/architecture/PROVIDERS_AND_ROUTES.md](/home/home/personal/wayspot/docs/architecture/PROVIDERS_AND_ROUTES.md)
- [docs/DESIGN_AND_STANDARDS.md](/home/home/personal/wayspot/docs/DESIGN_AND_STANDARDS.md)

Acceptance:
- App-native behavior uses typed actions.
- Literal shell-command actions are either eliminated or tightly isolated and
  documented.
- Provider/action docs match the actual action model.

### 6. Fix Control-Plane Protocol Correctness

Status: `todo`
Priority: `high`

Problem:
- Server assumes one read contains a full request.
- Server assumes one write flushes a full response.
- `version` does not satisfy its documented contract.

Files:
- [src/ipc/control.zig](/home/home/personal/wayspot/src/ipc/control.zig)
- [docs/architecture/WA1_CONTROL_PLANE_SPEC.md](/home/home/personal/wayspot/docs/architecture/WA1_CONTROL_PLANE_SPEC.md)
- [docs/architecture/DAEMON_ARCHITECTURE.md](/home/home/personal/wayspot/docs/architecture/DAEMON_ARCHITECTURE.md)

Acceptance:
- Request handling tolerates stream fragmentation correctly.
- Response writing handles partial writes correctly.
- `version` returns meaningful daemon version data or the spec is revised.
- Tests cover the corrected behavior.

### 7. Remove Split Theme Authorities

Status: `todo`
Priority: `high`

Problem:
- `theme_state` can persist themes that `theme_apply` cannot fulfill.
- `--set-theme` and `--apply-theme` currently represent different authorities.

Files:
- [src/tools/theme_state.zig](/home/home/personal/wayspot/src/tools/theme_state.zig)
- [src/tools/theme_apply.zig](/home/home/personal/wayspot/src/tools/theme_apply.zig)
- [src/main.zig](/home/home/personal/wayspot/src/main.zig)
- [docs/providers/theme.md](/home/home/personal/wayspot/docs/providers/theme.md)

Acceptance:
- Persisted theme state and applyable theme state are the same authority.
- Unsupported persisted states are impossible.
- CLI semantics for set/apply are explicit and non-contradictory.

Dependency:
- Best handled after item 1.

### 8. Replace Slideshow Process Scraping With Owned Runtime Control

Status: `todo`
Priority: `medium`

Problem:
- Slideshow toggle uses `pgrep -f` and `kill`.
- That bypasses the app’s own control/runtime ownership model.

Files:
- [src/tools/slideshow_control.zig](/home/home/personal/wayspot/src/tools/slideshow_control.zig)
- [src/main.zig](/home/home/personal/wayspot/src/main.zig)
- [docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
- [docs/architecture/DAEMON_ARCHITECTURE.md](/home/home/personal/wayspot/docs/architecture/DAEMON_ARCHITECTURE.md)

Acceptance:
- Slideshow lifecycle is tracked through owned runtime state or a proper control
  interface.
- No broad process-name matching remains.
- Toggling cannot accidentally kill unrelated processes.

### 9. Fix Wallpaper Runtime Memory Ownership

Status: `todo`
Priority: `medium`

Problem:
- `setWallpaper` leaks owned `Assignment` entries.

Files:
- [src/tools/wallpaper_runtime.zig](/home/home/personal/wayspot/src/tools/wallpaper_runtime.zig)
- [docs/architecture/ENGINEERING.md](/home/home/personal/wayspot/docs/architecture/ENGINEERING.md)

Acceptance:
- All owned assignment buffers are released on every path.
- Tests cover the corrected ownership behavior where practical.

### 10. Repair Theme Route Tests

Status: `todo`
Priority: `medium`

Problem:
- The theme-route regression test is stale and currently failing.

Files:
- [src/search/rank.zig](/home/home/personal/wayspot/src/search/rank.zig)

Acceptance:
- Route tests reflect actual intended theme-route behavior.
- `zig test src/search/rank.zig` passes.
- Recent route-isolation behavior is covered by meaningful regression tests.

### 11. Align Theme Route UX With Actual Behavior

Status: `todo`
Priority: `medium`

Problem:
- UI hints still advertise theme subcommands that do not exist.

Files:
- [src/ui/gtk/query_helpers.zig](/home/home/personal/wayspot/src/ui/gtk/query_helpers.zig)
- [src/ui/gtk/widgets.zig](/home/home/personal/wayspot/src/ui/gtk/widgets.zig)
- [src/providers/theme.zig](/home/home/personal/wayspot/src/providers/theme.zig)
- [docs/providers/theme.md](/home/home/personal/wayspot/docs/providers/theme.md)

Acceptance:
- UI labels and hint text match actual runtime/provider behavior.
- No placeholder or aspirational theme-route UX remains in the shipped UI.

### 12. Remove Dead Theme Provider Plumbing

Status: `todo`
Priority: `low`

Problem:
- Theme provider still resolves and threads through `selfExePathAlloc` even
  though it no longer uses it.

Files:
- [src/providers/theme.zig](/home/home/personal/wayspot/src/providers/theme.zig)

Acceptance:
- Provider collect path contains only data needed to emit its typed candidates.
- Dead command-era plumbing is removed.

### 13. Remove Scaffold Leftovers

Status: `todo`
Priority: `low`

Problem:
- Public library surface still contains scaffold text and dummy sample code.

Files:
- [src/root.zig](/home/home/personal/wayspot/src/root.zig)

Acceptance:
- No scaffold-facing text remains in exported runtime code.
- Placeholder sample functions/tests are removed or replaced with meaningful
  coverage.

## Verification Checklist

Use this checklist as items close:

- `zig build`
- `zig build test`
- targeted tests for touched subsystem
- `./re-run.sh` when UI/daemon behavior changed
- docs updated in same slice
- no stale UX text or behavior/documentation mismatch

## Current Notes

- Verified during review: `zig test src/search/rank.zig` currently fails because
  the theme-route test is stale.
- The highest-risk cleanup lane is theme/config/runtime ownership, because it
  drives multiple downstream inconsistencies.
