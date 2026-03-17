# Configuration

Lua config is the runtime state authority for `wayspot`.

This doc describes the current config ownership model and the runtime consumers
that should read from it.

## Source Of Truth

- loader/parser: `src/config/lua_config.zig`
- default template: `src/config/default_lua.zig`
- theme state helper: `src/tools/theme_state.zig`

Default path:

- `~/.config/wayspot/config.lua`

Override path:

- `WAYSPOT_CONFIG_LUA`

## Current Ownership Rules

Durable runtime state belongs in Lua config.

That includes:

- surface mode
- placement policy
- UI/runtime tool settings
- current theme

This means first-class features should not create parallel state stores in:

- shell env files
- ad hoc repo-local state files
- UI-only memory without a config-backed source of truth

## Current Theme State

Current theme is stored in Lua as:

```lua
theme = {
  current = "ayu",
}
```

Theme switching should update Lua config first, then apply runtime side effects
like Hyprland/Waybar theme pointers and reload behavior.

## Runtime Consumers

Current config consumers include:

- launcher surface mode and placement
- runtime tool selection
- UI feature flags
- theme state

Theme/wallpaper code should treat Lua config as the state authority and
`hyprpaper.conf` as runtime execution input, not the primary truth source.

## Validation Direction

Config loading should prefer:

- parse
- validate
- warn and default invalid fields where safe
- keep one clear source of truth per feature

