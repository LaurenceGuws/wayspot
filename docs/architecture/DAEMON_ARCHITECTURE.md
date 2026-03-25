Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Daemon Architecture

This document describes the resident `wayspot` runtime as a daemon.

## What

The daemon is the long-lived `wayspot` process started through:

- `wayspot --ui-daemon`
- `wayspot --ui-resident`

It is responsible for:

- owning the warm launcher/search runtime
- binding the local control socket
- keeping shell modules alive
- optionally bridging WM events into cache refresh
- keeping history, telemetry, and provider state in-process
- answering bounded request/response control-plane calls over a Unix stream socket
- owning resident slideshow lifecycle when wallpaper slideshow control is used

## Why

The daemon exists because summon-style shell tools should not pay full cold
startup cost each time. A resident process allows:

- low-latency summon/hide
- warm provider snapshots and caches
- module lifecycles with explicit health
- a single local control plane for in-house shell integrations

## How

Runtime assembly currently happens in
[src/main.zig](../../src/main.zig):

1. parse CLI mode
2. load Lua config and runtime tool overrides
3. build `Runtime`
4. construct provider registry
5. construct `SearchService`
6. optionally start WM event bridge
7. start `ui.Shell.run(...)`

The resident runtime currently owns:

- providers:
  [ActionsProvider](../../src/providers/actions.zig),
  [AppsProvider](../../src/providers/apps.zig),
  [WindowsProvider](../../src/providers/windows.zig),
  [WorkspacesProvider](../../src/providers/workspaces.zig),
  [DirsProvider](../../src/providers/dirs.zig),
  [ThemeProvider](../../src/providers/theme.zig)
- search/runtime service:
  [SearchService](../../src/app/search_service.zig)
- telemetry:
  [telemetry.zig](../../src/app/telemetry.zig)
- module/event plumbing:
  [src/shell/mod.zig](../../src/shell/mod.zig)
- control server:
  [src/ipc/control.zig](../../src/ipc/control.zig)

## When

The daemon exists only in resident UI modes.

It should own a concern when that concern needs one or more of:

- warm state across summons
- local command/control surface
- long-lived module health
- background refresh
- single-writer runtime ownership
- resident child-process lifecycle tied to shell behavior

It should not own:

- one-shot CLI tool behavior that can complete and exit cleanly
- pure rendering details
- provider-specific ranking semantics

## Where

Key files:

- runtime assembly:
  [src/main.zig](../../src/main.zig)
- search/runtime core:
  [src/app/search_service.zig](../../src/app/search_service.zig)
- control socket:
  [src/ipc/control.zig](../../src/ipc/control.zig)
- shell registry and event bus:
  [src/shell/registry.zig](../../src/shell/registry.zig),
  [src/shell/event_bus.zig](../../src/shell/event_bus.zig)
- GTK shell bootstrap:
  [src/ui/gtk_shell.zig](../../src/ui/gtk_shell.zig)

## Current Shape

Today the daemon is still UI-hosted rather than a standalone headless
`shelld`. That is acceptable as the current implementation, but the boundary
should still be treated as a shell-runtime boundary, not as "GTK owns
everything".

## Rules

- The control plane is daemon authority, not widget authority.
- Control-plane transport must obey stream-socket semantics, not single-read or single-write assumptions.
- Resident runtime state should be assembled once and reused.
- One-shot tools should not silently create partial daemon state.
- New module work should integrate through shell/module and IPC boundaries,
  not direct GTK-global state.
