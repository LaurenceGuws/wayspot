Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Actions Provider

## What

Provides static shell action rows such as settings, power menu, restart waybar,
and notifications panel.

## Why

It exposes well-known shell operations as searchable results without hardcoding
them into UI widgets.

## How

- implementation:
  [src/providers/actions.zig](../../src/providers/actions.zig)
- static action table:
  `action_specs`
- dependency gating:
  command existence or home-relative path checks

It emits `.action` candidates whose `action` field is an internal action id such
as `restart-waybar`.

## When

Add to this provider only for globally available shell actions that do not
depend on query-time external data collection.

## Where

- [src/providers/actions.zig](../../src/providers/actions.zig)
