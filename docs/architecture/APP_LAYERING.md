# App Layering

This file defines the current subsystem boundaries for `wayspot`.

The goal is simple: make launcher, daemon, config, providers, WM integration,
and shell runtime behavior composable instead of implicitly coupled.

## Layer Map

1. UI shell
- GTK/window lifecycle
- entry/input handling
- result rendering
- preview and popup UI

2. Search and providers
- query parsing
- route classification
- provider collection
- ranking
- action identifiers

3. Runtime services
- command planning/execution
- config loading
- async refresh
- cache ownership

4. Shell runtime tools
- theme apply
- wallpaper slideshow
- wallpaper sort/set

5. WM adapter
- output/workspace/window discovery
- focused-output resolution
- compositor-specific execution

## Boundary Rules

UI shell:
- may consume parsed/ranked results
- may not own provider-specific behavior
- may not embed shell/runtime hacks directly

Providers:
- should emit typed candidates
- should not parse hidden UI state
- should not depend on widget behavior
- should only surface capabilities the runtime can actually fulfill

Search/ranking:
- owns route filtering and route-scoped candidate eligibility
- should not rely on provider title conventions alone when route isolation matters

Runtime/config:
- owns user/runtime state
- should use Lua config for durable state
- should not use ad hoc env-file state for first-class features

Shell runtime tools:
- own theme/wallpaper operational behavior
- should not be split across stale shell-script sidecars unless explicitly documented as compatibility paths

WM layer:
- compositor-specific behavior belongs here or in runtime tools built on it
- UI and providers should not encode Hyprland-specific assumptions directly

## Provider Contract Notes

For new providers/routes:

- route parsing belongs in `src/search/query.zig`
- route filtering belongs in `src/search/rank.zig`
- provider collection belongs in `src/providers/*.zig`
- typed action execution belongs through `src/ui/common/dispatch.zig`

If a route needs strict isolation, do not depend on broad candidate kinds alone.
Use a dedicated action namespace or equivalent typed contract.

