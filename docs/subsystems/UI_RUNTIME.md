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
  [src/ui/mod.zig](/home/home/personal/wayspot/src/ui/mod.zig)
- GTK shell composition:
  [src/ui/gtk_shell.zig](/home/home/personal/wayspot/src/ui/gtk_shell.zig)
- GTK implementation tree:
  [src/ui/gtk/](/home/home/personal/wayspot/src/ui/gtk)
- placement:
  [src/ui/placement/](/home/home/personal/wayspot/src/ui/placement)
- headless helpers:
  [src/ui/headless/](/home/home/personal/wayspot/src/ui/headless)

## When

Use this subsystem for widgets, rendering, input handling, selection, preview,
placement adapters, and shell lifecycle from the surface point of view.

## Where

- [src/ui/](/home/home/personal/wayspot/src/ui)
