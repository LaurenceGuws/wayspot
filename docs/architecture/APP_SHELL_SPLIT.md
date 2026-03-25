Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# App Shell Split

This document defines the top-level split between the app shell, the daemon,
and the UI process model.

## What

`wayspot` is one executable with several operating modes:

- one-shot CLI commands
- a long-lived daemon-like UI process (`--ui-daemon`, `--ui-resident`)
- a summon-first launcher path (`--ui`)
- runtime tools for theme, wallpaper, diagnostics, and control

The important split is not "CLI vs GUI". It is:

- app shell and runtime orchestration in `src/main.zig`
- long-lived daemon responsibilities in the resident UI path
- GTK UI composition and interaction code in `src/ui/`

## Why

This split exists so `wayspot` can behave like a shell component instead of a
fresh process on every summon:

- startup cost is paid once
- control commands can target a warm process
- providers, caches, and WM state can stay hot
- shell modules can be added without collapsing everything into GTK glue

## How

### App shell

The app shell lives primarily in [src/main.zig](../../src/main.zig).
It is responsible for:

- parsing CLI mode
- deciding whether to take a one-shot tool path or UI path
- loading config and runtime flags
- constructing the provider registry and `SearchService`
- starting the resident shell path when UI mode is selected

### Daemon

The daemon is not a separate binary. It is the resident shell mode of the same
program:

- `wayspot --ui-daemon` starts hidden and binds the local control socket
- `wayspot --ui-resident` starts visible and keeps the control/socket lifecycle
- `wayspot --ui` first tries `--ctl summon`; if that fails it starts a local UI

### UI

The UI is an implementation selected by build options in
[src/ui/mod.zig](../../src/ui/mod.zig):

- GTK shell when `enable_gtk=true`
- stub shell for headless/test-oriented builds

The GTK shell composes launcher, notifications, control server integration, and
module startup in [src/ui/gtk_shell.zig](../../src/ui/gtk_shell.zig).

## When

Use this split when deciding where new functionality belongs:

- if it is mode selection, runtime wiring, or service assembly: app shell
- if it is lifetime, control socket, summon/hide behavior, or warm state: daemon
- if it is widgets, interaction, rendering, focus, or GTK state: UI

## Where

Primary ownership points:

- app shell: [src/main.zig](../../src/main.zig)
- app state/bootstrap: [src/app/bootstrap.zig](../../src/app/bootstrap.zig)
- UI abstraction: [src/ui/mod.zig](../../src/ui/mod.zig)
- GTK runtime shell: [src/ui/gtk_shell.zig](../../src/ui/gtk_shell.zig)
- shell modules/event bus: [src/shell/mod.zig](../../src/shell/mod.zig)
- local control plane: [src/ipc/control.zig](../../src/ipc/control.zig)

## Rules

- Do not treat the daemon as a separate app with duplicated startup logic.
- Do not put command routing or runtime orchestration into GTK-only files.
- Do not let UI widgets become the source of truth for daemon state.
- Do not introduce a second config or env state path when Lua config already
  owns the setting.
