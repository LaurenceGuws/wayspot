Status: active
Owner: ui
Last-Reviewed: 2026-03-17
Canonical: yes

# UI Architecture

This document describes the `wayspot` UI layer.

## What

The UI layer renders and controls user-facing shell surfaces:

- launcher/search window
- results list, preview, and interaction flow
- notification surfaces and popup handling
- shell actions tied to visibility, placement, and lifecycle

The UI is an adapter over runtime services, not the source of application truth.

## Why

The UI layer exists to keep:

- rendering and input handling separate from provider/runtime logic
- GTK-specific code isolated from headless or future UI implementations
- summon/hide behavior consistent even as surfaces expand

## How

UI selection happens in [src/ui/mod.zig](/home/home/personal/wayspot/src/ui/mod.zig):

- GTK shell when compiled with GTK
- stub shell otherwise

The GTK implementation is organized as:

- shell composition:
  [src/ui/gtk_shell.zig](/home/home/personal/wayspot/src/ui/gtk_shell.zig)
- bootstrap/layout:
  [src/ui/gtk/bootstrap.zig](/home/home/personal/wayspot/src/ui/gtk/bootstrap.zig),
  [src/ui/gtk/bootstrap_layout.zig](/home/home/personal/wayspot/src/ui/gtk/bootstrap_layout.zig)
- controller/search orchestration:
  [src/ui/gtk/controller.zig](/home/home/personal/wayspot/src/ui/gtk/controller.zig),
  [src/ui/gtk/shell_controller.zig](/home/home/personal/wayspot/src/ui/gtk/shell_controller.zig),
  [src/ui/gtk/async_search.zig](/home/home/personal/wayspot/src/ui/gtk/async_search.zig)
- lifecycle/control glue:
  [src/ui/gtk/shell_control.zig](/home/home/personal/wayspot/src/ui/gtk/shell_control.zig),
  [src/ui/gtk/shell_lifecycle.zig](/home/home/personal/wayspot/src/ui/gtk/shell_lifecycle.zig),
  [src/ui/gtk/shell_actions.zig](/home/home/personal/wayspot/src/ui/gtk/shell_actions.zig)
- rendering helpers:
  [src/ui/gtk/render.zig](/home/home/personal/wayspot/src/ui/gtk/render.zig),
  [src/ui/gtk/results_flow.zig](/home/home/personal/wayspot/src/ui/gtk/results_flow.zig),
  [src/ui/gtk/preview.zig](/home/home/personal/wayspot/src/ui/gtk/preview.zig)
- route/query UX:
  [src/ui/gtk/query_helpers.zig](/home/home/personal/wayspot/src/ui/gtk/query_helpers.zig),
  [src/ui/gtk/default_loadout.zig](/home/home/personal/wayspot/src/ui/gtk/default_loadout.zig),
  [src/ui/gtk/help_panel.zig](/home/home/personal/wayspot/src/ui/gtk/help_panel.zig)

## When

UI files should own work when the behavior is about:

- rendering
- keybindings and pointer interaction
- selection/preview state
- layout and placement adapters
- shell lifecycle from the surface point of view

They should not own:

- provider collection logic
- config authority
- command planning semantics
- WM backend parsing

## Where

Primary folders:

- top-level UI abstraction:
  [src/ui/](/home/home/personal/wayspot/src/ui)
- GTK implementation:
  [src/ui/gtk/](/home/home/personal/wayspot/src/ui/gtk)
- placement:
  [src/ui/placement/](/home/home/personal/wayspot/src/ui/placement)
- surface mode contracts:
  [src/ui/surfaces/](/home/home/personal/wayspot/src/ui/surfaces)
- headless support:
  [src/ui/headless/](/home/home/personal/wayspot/src/ui/headless)

## Rules

- GTK widgets should consume runtime outputs, not create hidden app state.
- Route affordances belong in the query UX layer, not inside providers.
- UI defaults and help must reflect actual runtime behavior, not aspirations.
- Headless/stub paths should remain valid for diagnostics and test builds.
