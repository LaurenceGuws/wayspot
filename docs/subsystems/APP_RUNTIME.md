Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# App Runtime

## What

The app runtime is the top-level startup and mode-selection layer for
`wayspot`.

## Why

It keeps one binary usable as:

- CLI tool
- control client
- resident shell runtime
- diagnostics entrypoint

## How

Primary entrypoint:

- [src/main.zig](../../src/main.zig)

It selects between:

- wallpaper/theme tools
- control plane commands
- diagnostics
- UI startup

Resident runtime assembly is done in `setupRuntime(...)` and the nested
`Runtime` struct in `src/main.zig`.

## When

Use this layer for:

- CLI argument ownership
- runtime construction
- provider registry assembly
- search service assembly

## Where

- [src/main.zig](../../src/main.zig)
- [src/app/bootstrap.zig](../../src/app/bootstrap.zig)
- [src/app/state.zig](../../src/app/state.zig)
