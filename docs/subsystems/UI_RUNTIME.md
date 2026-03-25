Status: active
Owner: ui
Last-Reviewed: 2026-03-17
Canonical: yes

# UI Runtime

## What

The UI runtime is the surface implementation for launcher and notification
interaction.

## Why

It isolates GTK-specific rendering and interaction code from search/runtime
logic.

## How

- UI entrypoint:
  [src/ui/mod.zig](../../src/ui/mod.zig)
- GTK shell composition:
  [src/ui/gtk_shell.zig](../../src/ui/gtk_shell.zig)
- GTK implementation tree:
  [src/ui/gtk/](../../src/ui/gtk)
- placement:
  [src/ui/placement/](../../src/ui/placement)
- headless helpers:
  [src/ui/headless/](../../src/ui/headless)

## When

Use this subsystem for widgets, rendering, input handling, selection, preview,
placement adapters, and shell lifecycle from the surface point of view.

## Where

- [src/ui/](../../src/ui)
