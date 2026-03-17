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
  [src/providers/theme.zig](/home/home/personal/wayspot/src/providers/theme.zig)
- state read:
  [src/tools/theme_state.zig](/home/home/personal/wayspot/src/tools/theme_state.zig)
- apply path:
  [src/tools/theme_apply.zig](/home/home/personal/wayspot/src/tools/theme_apply.zig)

The provider:

- reads current theme from Lua-backed theme state
- emits only supported, switchable themes
- emits namespaced `theme-apply:<theme>` actions
- does not expose generic fallback actions in the theme route

## When

Use this provider only for theme discovery and switching. Theme-specific
subcommands should remain namespaced under the theme route design, not leak into
default search.

## Where

- [src/providers/theme.zig](/home/home/personal/wayspot/src/providers/theme.zig)
