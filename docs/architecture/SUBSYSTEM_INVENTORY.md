Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Subsystem Inventory

This inventory lists the major `wayspot` subsystems and links to the docs that
define each one.

## Runtime Core

- app/bootstrap/runtime assembly
  - doc: [APP_RUNTIME.md](../subsystems/APP_RUNTIME.md)
  - code: [src/main.zig](../../src/main.zig), [src/app/](../../src/app)
- search service
  - doc: [SEARCH_SERVICE.md](../subsystems/SEARCH_SERVICE.md)
  - code: [src/app/search_service.zig](../../src/app/search_service.zig)

## Config And State

- Lua config
  - doc: [CONFIG_AND_LUA.md](../subsystems/CONFIG_AND_LUA.md)
  - code: [src/config/lua_config.zig](../../src/config/lua_config.zig)
- theme state/apply
  - doc: [THEME_AND_WALLPAPER_RUNTIME.md](../subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
  - code: [src/tools/theme_state.zig](../../src/tools/theme_state.zig), [src/tools/theme_apply.zig](../../src/tools/theme_apply.zig)

## Control And Shell

- local IPC control plane
  - doc: [IPC_CONTROL.md](../subsystems/IPC_CONTROL.md)
  - code: [src/ipc/control.zig](../../src/ipc/control.zig)
- shell modules/event bus
  - doc: [SHELL_MODULES.md](../subsystems/SHELL_MODULES.md)
  - code: [src/shell/](../../src/shell)

## UI And Surfaces

- GTK/UI runtime
  - doc: [UI_RUNTIME.md](../subsystems/UI_RUNTIME.md)
  - code: [src/ui/](../../src/ui)
- notifications
  - doc: [NOTIFICATIONS.md](../subsystems/NOTIFICATIONS.md)
  - code: [src/notifications/](../../src/notifications)

## System Integration

- WM abstraction
  - doc: [WM_INTEGRATION.md](../subsystems/WM_INTEGRATION.md)
  - code: [src/wm/](../../src/wm)
- theme/wallpaper runtime
  - doc: [THEME_AND_WALLPAPER_RUNTIME.md](../subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
  - code: [src/tools/wallpaper_runtime.zig](../../src/tools/wallpaper_runtime.zig), [src/tools/slideshow_control.zig](../../src/tools/slideshow_control.zig)

## Observability

- logging, metrics, telemetry
  - doc: [OBSERVABILITY.md](../subsystems/OBSERVABILITY.md)
  - code: [src/app/logger.zig](../../src/app/logger.zig), [src/app/metrics.zig](../../src/app/metrics.zig), [src/app/telemetry.zig](../../src/app/telemetry.zig)

## Provider Layer

- provider inventory
  - doc: [PROVIDER_INVENTORY.md](PROVIDER_INVENTORY.md)
  - code: [src/providers/](../../src/providers)

## What / Why / How / When / Where Rule

Each subsystem doc in `docs/subsystems/` should answer:

- what the subsystem is
- why it exists
- how it is structured
- when to use or extend it
- where the owning files live
