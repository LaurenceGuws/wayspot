# Docs Index

Repo-local docs map for contributors, operators, and agents.

Use this file for repo workflow and architecture navigation, not as the public
project landing page.

## Start Here

- `AGENTS.md` — repo-local operating constraints.
- `docs/AGENT_HANDOFF.md` — current focus, constraints, and entrypoints.
- `docs/WORKFLOW.md` — workflow and doc-placement rules.
- `README.md` — top-level overview and command entrypoints.

## Core Architecture

- `docs/architecture/DE_SHELL_VISION.md` — product direction and long-lived daemon target.
- `docs/architecture/APP_SHELL_SPLIT.md` — app shell vs daemon vs UI split.
- `docs/architecture/APP_LAYERING.md` — module boundaries and ownership split.
- `docs/architecture/DAEMON_ARCHITECTURE.md` — resident runtime design and ownership.
- `docs/architecture/UI_ARCHITECTURE.md` — UI runtime and GTK boundary design.
- `docs/architecture/BOOTSTRAP.md` — build, run, test, and local dev entrypoints.
- `docs/architecture/CONFIG.md` — Lua config ownership, consumers, and runtime behavior.
- `docs/architecture/SUBSYSTEM_INVENTORY.md` — subsystem map with links to detailed docs.
- `docs/architecture/PROVIDER_INVENTORY.md` — provider and route-scoped search inventory.
- `docs/architecture/PROVIDERS_AND_ROUTES.md` — route/provider/action contract and isolation rules.
- `docs/architecture/WA1_CONTROL_PLANE_SPEC.md` — local control-plane authority.
- `docs/architecture/ENGINEERING.md` — memory, ownership, threading, and review rules.

## Subsystems

- `docs/subsystems/APP_RUNTIME.md` — app startup, mode selection, runtime assembly.
- `docs/subsystems/CONFIG_AND_LUA.md` — Lua config loading and config ownership.
- `docs/subsystems/IPC_CONTROL.md` — local control plane and daemon command path.
- `docs/subsystems/SEARCH_SERVICE.md` — provider collection, ranking, cache, and dynamic routes.
- `docs/subsystems/SHELL_MODULES.md` — shell module lifecycle and event bus.
- `docs/subsystems/UI_RUNTIME.md` — GTK/runtime UI implementation.
- `docs/subsystems/NOTIFICATIONS.md` — notification daemon/runtime and UI integration.
- `docs/subsystems/WM_INTEGRATION.md` — WM backend contracts and Hyprland integration.
- `docs/subsystems/THEME_AND_WALLPAPER_RUNTIME.md` — theme apply/state and wallpaper runtime.
- `docs/subsystems/OBSERVABILITY.md` — logging, metrics, telemetry, and health.

## Providers

- `docs/providers/actions.md` — static shell actions provider.
- `docs/providers/apps.md` — app launcher provider.
- `docs/providers/dirs.md` — directory/search-jump provider.
- `docs/providers/theme.md` — theme route provider.
- `docs/providers/windows.md` — WM-backed windows provider.
- `docs/providers/workspaces.md` — WM-backed workspaces provider.
- `docs/providers/web.md` — route-scoped web provider subsystem.
- `docs/providers/calc.md` — route-scoped calculator subsystem.

## Current Workflow

- `docs/WORKFLOW.md` — work loop and documentation rules.
- `docs/AGENT_HANDOFF.md` — current active focus.
- `workstreams/` — active work queues and cleanup items.

## Ownership Rules

- `README.md` is the public/project-facing overview.
- `docs/` is for workflow, navigation, and contributor/operator guidance.
- `docs/architecture/` is current architecture authority.
- `workstreams/` is the source of truth for active task tracking.
