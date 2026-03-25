Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# IPC Control

## What

The IPC control subsystem is the local Unix-socket control plane used by the
resident daemon and CLI.

## Why

It provides stable summon/hide/toggle and health query semantics without
requiring D-Bus or spawning fresh UI processes.

## How

- implementation:
  [src/ipc/control.zig](../../src/ipc/control.zig)
- protocol spec:
  [WA1_CONTROL_PLANE_SPEC.md](../architecture/WA1_CONTROL_PLANE_SPEC.md)

Current commands:

- `ping`
- `summon`
- `hide`
- `toggle`
- `version`
- `shell_health`
- `wm_event_stats`

## When

Use this subsystem for local control/query operations against the resident
daemon.

## Where

- [src/ipc/](../../src/ipc)
