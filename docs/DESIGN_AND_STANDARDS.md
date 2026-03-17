# Design And Coding Standards

## Design Focus

- Keep UI abstractions generic and composable.
- Keep providers simple and data-oriented.
- Keep route behavior deterministic.
- Keep control-plane behavior explicit and documented.
- Keep WM integration behind the WM/runtime layer, not scattered through UI code.
- Keep shell-facing behavior first-class instead of glued on through temporary scripts.

## Coding Standards

- Keep modules small and single-purpose.
- Avoid hidden coupling between UI widgets and provider/query contracts.
- Prefer typed actions over literal shell commands when the action belongs to the app.
- Do not route app execution through generic `cmd:`-style action payloads.
- Prefer config-backed state over transient env hacks.
- Do not expose runtime capabilities in a provider unless the runtime can actually fulfill them.
- Update docs when subsystem behavior changes.
- Do not revert unrelated user changes.
- Prefer small, reviewable commits.

## Active Design Docs

- `docs/architecture/DE_SHELL_VISION.md`
- `docs/architecture/APP_LAYERING.md`
- `docs/architecture/CONFIG.md`
- `docs/architecture/PROVIDERS_AND_ROUTES.md`
- `docs/architecture/WA1_CONTROL_PLANE_SPEC.md`
- `docs/architecture/ENGINEERING.md`
