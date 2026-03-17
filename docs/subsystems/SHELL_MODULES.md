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
  [src/shell/mod.zig](/home/home/personal/wayspot/src/shell/mod.zig)
- registry:
  [src/shell/registry.zig](/home/home/personal/wayspot/src/shell/registry.zig)
- module contract:
  [src/shell/module.zig](/home/home/personal/wayspot/src/shell/module.zig)
- event bus:
  [src/shell/event_bus.zig](/home/home/personal/wayspot/src/shell/event_bus.zig)
- health:
  [src/shell/health.zig](/home/home/personal/wayspot/src/shell/health.zig)

## When

Add to this subsystem when introducing a new daemon-owned shell module with its
own lifecycle and health semantics.

## Where

- [src/shell/](/home/home/personal/wayspot/src/shell)
