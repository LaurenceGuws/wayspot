Status: active
Owner: wm
Last-Reviewed: 2026-03-17
Canonical: yes

# WM Integration

## What

The WM subsystem is the compositor/window-manager abstraction layer.

## Why

It lets providers and wallpaper/runtime tools depend on a backend contract
instead of hardcoding Hyprland shell scripts everywhere.

## How

- backend contracts:
  [src/wm/types.zig](/home/home/personal/wayspot/src/wm/types.zig)
- adapter exports:
  [src/wm/mod.zig](/home/home/personal/wayspot/src/wm/mod.zig)
- Hyprland backend:
  [src/wm/hyprland.zig](/home/home/personal/wayspot/src/wm/hyprland.zig)
- event refresh stats:
  [src/wm/event_stats.zig](/home/home/personal/wayspot/src/wm/event_stats.zig)

Current consumers include:

- windows/workspaces providers
- output diagnostics
- wallpaper runtime
- WM event refresh bridge

## When

If a feature needs window/workspace/output data or focused monitor semantics,
grow the backend contract here first.

## Where

- [src/wm/](/home/home/personal/wayspot/src/wm)
