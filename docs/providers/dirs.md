Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Dirs Provider

## What

Provides recent/frequent directory candidates, currently backed by system tools.

## Why

Directory jumping is a separate search concern from apps and files, with its own
tooling and health model.

## How

- implementation:
  [src/providers/dirs.zig](/home/home/personal/wayspot/src/providers/dirs.zig)
- tool checks:
  [src/providers/tool_check.zig](/home/home/personal/wayspot/src/providers/tool_check.zig)

The provider tracks runtime failure and tool availability separately from other
providers.

## When

Use this provider for recent/frequent directory results and related launcher
navigation flows.

## Where

- [src/providers/dirs.zig](/home/home/personal/wayspot/src/providers/dirs.zig)
