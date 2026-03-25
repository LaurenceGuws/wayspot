Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Windows Provider

## What

Provides window candidates from the current WM backend.

## Why

Window switching is runtime WM data, not static cache data, and needs backend
health/capability awareness.

## How

- implementation:
  [src/providers/windows.zig](../../src/providers/windows.zig)
- backend contract:
  [src/wm/types.zig](../../src/wm/types.zig)
- current backend:
  [src/wm/hyprland.zig](../../src/wm/hyprland.zig)

The provider maintains a snapshot protected by a mutex and refreshes from the WM
backend on demand.

## When

Use this provider for live window switching/search. Grow WM abstractions before
adding backend-specific hacks here.

## Where

- [src/providers/windows.zig](../../src/providers/windows.zig)
