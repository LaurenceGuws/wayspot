Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Theme Provider

## What

Provides theme-switch rows for the dedicated `,` theme route.

## Why

Theme switching is app-native shell behavior and needs a route-isolated provider
instead of a generic action hack.

## How

- implementation:
  [src/providers/theme.zig](../../src/providers/theme.zig)
- state read:
  [src/tools/theme_state.zig](../../src/tools/theme_state.zig)
- supported-theme authority:
  [src/tools/theme_catalog.zig](../../src/tools/theme_catalog.zig)
- apply path:
  [src/tools/theme_apply.zig](../../src/tools/theme_apply.zig)

The provider:

- reads current theme from Lua-backed theme state
- discovers switchable themes at runtime from live wallpaper and theme assets
- emits namespaced `theme-apply:<theme>` actions
- does not expose generic fallback actions in the theme route

Theme authority rule:

- persisted theme state and applyable theme state use the same canonical alias
  map and runtime capability checks
- selecting a theme from the provider is an apply operation, not a
  persist-without-apply operation
- `--set-theme` is only a compatibility alias for `--apply-theme`

Correctness guard:

- a theme is only listed if it has a wallpaper directory with at least one image
- it must have a live Hypr theme file in `~/.config/hypr/modules`

This keeps provider refresh meaningful: syncing new live assets and refreshing
providers is enough to expose a new theme without restarting into a new binary.

Theme application is expected to target runtime-owned state and live runtime
files, not a separate dotfiles repo checkout.

## When

Use this provider only for theme discovery and switching. Theme-specific
subcommands should remain namespaced under the theme route design, not leak into
default search.

## Where

- [src/providers/theme.zig](../../src/providers/theme.zig)
