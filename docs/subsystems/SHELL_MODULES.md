Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Shell Modules

## What

The shell subsystem defines module lifecycle, event bus wiring, and health
reporting for long-lived shell components.

## Why

It gives the daemon a composable structure instead of one monolithic GTK
application blob.

## How

- exports:
  [src/shell/mod.zig](../../src/shell/mod.zig)
- registry:
  [src/shell/registry.zig](../../src/shell/registry.zig)
- module contract:
  [src/shell/module.zig](../../src/shell/module.zig)
- event bus:
  [src/shell/event_bus.zig](../../src/shell/event_bus.zig)
- health:
  [src/shell/health.zig](../../src/shell/health.zig)

## When

Add to this subsystem when introducing a new daemon-owned shell module with its
own lifecycle and health semantics.

## Where

- [src/shell/](../../src/shell)
