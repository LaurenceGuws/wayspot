Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Provider Inventory

This document inventories the search/provider surface used by `SearchService`.

## Registry Providers

These are assembled into the resident `ProviderRegistry` in
[src/main.zig](../../src/main.zig).

| Provider | Route / Scope | Kind | Health Source | Detailed Doc |
| --- | --- | --- | --- | --- |
| actions | default search | registry provider | dependency probes | [actions.md](../providers/actions.md) |
| apps | `@` and blended search | registry provider | cache/file scan status | [apps.md](../providers/apps.md) |
| windows | `#` and blended search | registry provider | WM backend health | [windows.md](../providers/windows.md) |
| workspaces | `!` and blended search | registry provider | WM backend health | [workspaces.md](../providers/workspaces.md) |
| dirs | `~` and blended search | registry provider | tool/runtime status | [dirs.md](../providers/dirs.md) |
| theme | `,` route only | registry provider | Lua/self-exe lookup status | [theme.md](../providers/theme.md) |

## Route-Scoped Search Subsystems

These are not registered in `ProviderRegistry`, but they are still part of the
search/provider surface because they emit search candidates for specific routes.

| Subsystem | Route | Kind | Detailed Doc |
| --- | --- | --- | --- |
| web | `?` | route-scoped candidate source | [web.md](../providers/web.md) |
| calc | `=` | route-scoped evaluator | [calc.md](../providers/calc.md) |

## Shared Provider Infrastructure

- registry:
  [src/providers/registry.zig](../../src/providers/registry.zig)
- provider exports:
  [src/providers/mod.zig](../../src/providers/mod.zig)
- route/provider contract:
  [PROVIDERS_AND_ROUTES.md](PROVIDERS_AND_ROUTES.md)

## Rules

- If a feature participates in blended/static provider collection, it belongs in
  the registry inventory.
- If a feature only emits candidates for a dedicated route, document it as a
  route-scoped search subsystem instead of pretending it is a normal registry
  provider.
- Provider docs should describe dependencies, health model, ownership, and the
  action contract they emit.
