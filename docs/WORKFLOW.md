# Workflow + Docs Guide

This file explains how work and documentation are expected to flow in this
repository.

## Audience

- `README.md` is public/project-facing.
- This file is contributor/operator/agent-facing.

## Work Loop

1. Read `AGENTS.md`.
2. Read `docs/AGENT_HANDOFF.md`.
3. Read `docs/INDEX.md`.
4. Read the owning architecture doc for the slice.
5. Read the owning workstream item.
6. Implement one focused slice.
7. Update the owning docs in the same slice.
8. Validate locally.
9. Commit only at a healthy checkpoint.

## Workflow Rules

- Keep changes scoped to one real slice.
- Do not mix multiple invention lanes into one patch train.
- If behavior changes, update the owning doc in the same slice.
- If a doc contradicts code, fix the doc or remove the stale claim.
- Prefer one clear authority per topic.
- Keep `docs/AGENT_HANDOFF.md` short and current.

## Doc Placement

- `README.md`
  Public overview, quick start, and major command entrypoints.

- `scripts/open_docs_browser.sh`
  Local launcher for the standalone docs explorer against this repo's docs surface.

- `docs/`
  Workflow, navigation, and contributor/operator guidance.

- `docs/architecture/`
  Current architecture authority and subsystem boundary rules.

- `workstreams/`
  Active execution queues, cleanup lanes, and open follow-up items.

## Architecture Ownership

- Launcher/daemon/product direction:
  `docs/architecture/DE_SHELL_VISION.md`

- Module and subsystem boundaries:
  `docs/architecture/APP_LAYERING.md`

- Build/run/test and local bootstrap:
  `docs/architecture/BOOTSTRAP.md`

- Lua config ownership and runtime consumers:
  `docs/architecture/CONFIG.md`

- Providers, routes, and typed action integration:
  `docs/architecture/PROVIDERS_AND_ROUTES.md`

- Control socket and CLI daemon behavior:
  `docs/architecture/WA1_CONTROL_PLANE_SPEC.md`

- Memory/ownership/threading rules:
  `docs/architecture/ENGINEERING.md`
