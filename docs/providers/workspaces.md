Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Workspaces Provider

## What

Provides workspace candidates from the current WM backend.

## Why

Workspace switching is also WM runtime data and should follow the same backend
abstraction pattern as windows.

## How

- implementation:
  [src/providers/workspaces.zig](../../src/providers/workspaces.zig)
- backend contract:
  [src/wm/types.zig](../../src/wm/types.zig)

The provider maintains a snapshot, formats workspace subtitles with monitor and
window preview data, and emits `.workspace` candidates.

## When

Use this provider for workspace switching/search and any workspace metadata
presentation in the launcher.

## Where

- [src/providers/workspaces.zig](../../src/providers/workspaces.zig)
