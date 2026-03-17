Status: active
Owner: config
Last-Reviewed: 2026-03-17
Canonical: yes

# Config And Lua

## What

The config subsystem loads runtime settings from `~/.config/wayspot/config.lua`.

## Why

Lua is the user-facing configuration source of truth. It avoids scattered env
files and keeps runtime settings explicit and inspectable.

## How

- config model:
  [src/config/mod.zig](/home/home/personal/wayspot/src/config/mod.zig)
- Lua load/bootstrap:
  [src/config/lua_config.zig](/home/home/personal/wayspot/src/config/lua_config.zig)
- default config generation:
  [src/config/default_lua.zig](/home/home/personal/wayspot/src/config/default_lua.zig)
- runtime tool overrides:
  [src/config/runtime_tools.zig](/home/home/personal/wayspot/src/config/runtime_tools.zig)
- issue surfacing:
  [src/config/issue_notice.zig](/home/home/personal/wayspot/src/config/issue_notice.zig)

Current config fields include:

- surface mode
- placement policy
- notification UI policy
- general UI toggles
- tool choices

Theme state is also persisted through the config-oriented theme state path, not
through ad hoc env files.

## When

Use this subsystem whenever a setting should survive process restarts or should
be user-editable.

## Where

- [src/config/](/home/home/personal/wayspot/src/config)
