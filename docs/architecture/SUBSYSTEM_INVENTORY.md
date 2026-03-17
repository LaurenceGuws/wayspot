Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Subsystem Inventory

This inventory lists the major `wayspot` subsystems and links to the docs that
define each one.

## Runtime Core

- app/bootstrap/runtime assembly
  - doc: [APP_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/APP_RUNTIME.md)
  - code: [src/main.zig](/home/home/personal/wayspot/src/main.zig), [src/app/](/home/home/personal/wayspot/src/app)
- search service
  - doc: [SEARCH_SERVICE.md](/home/home/personal/wayspot/docs/subsystems/SEARCH_SERVICE.md)
  - code: [src/app/search_service.zig](/home/home/personal/wayspot/src/app/search_service.zig)

## Config And State

- Lua config
  - doc: [CONFIG_AND_LUA.md](/home/home/personal/wayspot/docs/subsystems/CONFIG_AND_LUA.md)
  - code: [src/config/lua_config.zig](/home/home/personal/wayspot/src/config/lua_config.zig)
- theme state/apply
  - doc: [THEME_AND_WALLPAPER_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
  - code: [src/tools/theme_state.zig](/home/home/personal/wayspot/src/tools/theme_state.zig), [src/tools/theme_apply.zig](/home/home/personal/wayspot/src/tools/theme_apply.zig)

## Control And Shell

- local IPC control plane
  - doc: [IPC_CONTROL.md](/home/home/personal/wayspot/docs/subsystems/IPC_CONTROL.md)
  - code: [src/ipc/control.zig](/home/home/personal/wayspot/src/ipc/control.zig)
- shell modules/event bus
  - doc: [SHELL_MODULES.md](/home/home/personal/wayspot/docs/subsystems/SHELL_MODULES.md)
  - code: [src/shell/](/home/home/personal/wayspot/src/shell)

## UI And Surfaces

- GTK/UI runtime
  - doc: [UI_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/UI_RUNTIME.md)
  - code: [src/ui/](/home/home/personal/wayspot/src/ui)
- notifications
  - doc: [NOTIFICATIONS.md](/home/home/personal/wayspot/docs/subsystems/NOTIFICATIONS.md)
  - code: [src/notifications/](/home/home/personal/wayspot/src/notifications)

## System Integration

- WM abstraction
  - doc: [WM_INTEGRATION.md](/home/home/personal/wayspot/docs/subsystems/WM_INTEGRATION.md)
  - code: [src/wm/](/home/home/personal/wayspot/src/wm)
- theme/wallpaper runtime
  - doc: [THEME_AND_WALLPAPER_RUNTIME.md](/home/home/personal/wayspot/docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md)
  - code: [src/tools/wallpaper_runtime.zig](/home/home/personal/wayspot/src/tools/wallpaper_runtime.zig), [src/tools/slideshow_control.zig](/home/home/personal/wayspot/src/tools/slideshow_control.zig)

## Observability

- logging, metrics, telemetry
  - doc: [OBSERVABILITY.md](/home/home/personal/wayspot/docs/subsystems/OBSERVABILITY.md)
  - code: [src/app/logger.zig](/home/home/personal/wayspot/src/app/logger.zig), [src/app/metrics.zig](/home/home/personal/wayspot/src/app/metrics.zig), [src/app/telemetry.zig](/home/home/personal/wayspot/src/app/telemetry.zig)

## Provider Layer

- provider inventory
  - doc: [PROVIDER_INVENTORY.md](/home/home/personal/wayspot/docs/architecture/PROVIDER_INVENTORY.md)
  - code: [src/providers/](/home/home/personal/wayspot/src/providers)

## What / Why / How / When / Where Rule

Each subsystem doc in `docs/subsystems/` should answer:

- what the subsystem is
- why it exists
- how it is structured
- when to use or extend it
- where the owning files live
