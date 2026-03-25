Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Observability

## What

The observability subsystem covers logging, timing metrics, telemetry files, and
health reporting.

## Why

A resident shell process needs enough diagnostics to understand startup,
refresh, IPC, and provider failures without turning the codebase into scattered
ad hoc prints.

## How

- logger:
  [src/app/logger.zig](../../src/app/logger.zig)
- stopwatch/metrics:
  [src/app/metrics.zig](../../src/app/metrics.zig)
- telemetry sink:
  [src/app/telemetry.zig](../../src/app/telemetry.zig)
- provider health snapshot:
  [src/providers/registry.zig](../../src/providers/registry.zig)
- shell health:
  [src/shell/health.zig](../../src/shell/health.zig)

## When

Use this subsystem when adding:

- startup timing
- provider/runtime failure reporting
- shell/module health outputs
- telemetry logs for query behavior

## Where

- [src/app/](../../src/app)
- [src/providers/registry.zig](../../src/providers/registry.zig)
- [src/shell/health.zig](../../src/shell/health.zig)
