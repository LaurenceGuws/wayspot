# Engineering

This file is the cross-cutting engineering baseline for `wayspot`.

## Design Rules

- Build first-class features through the app’s existing subsystems.
- Avoid one-off integration paths that bypass routing, config, or execution layers.
- Prefer typed actions over opaque shell strings when the action belongs to the app.
- Keep provider output narrow and deterministic.

## Ownership Rules

- The code that allocates owns the free path unless explicitly documented otherwise.
- `init`/`deinit` pairs must free all owned buffers and generations.
- Provider-owned strings must rotate cleanly across collects.
- Runtime helpers must document whether they mutate repo state, live config, or both.

## Threading Rules

- Do not hold locks across blocking subprocess or filesystem work.
- Long-running runtime work should copy needed state and release locks first.
- Background daemon/service behavior must remain deterministic under repeated summon/reload paths.

## Feature Integration Rules

For new shell-facing features:

1. define the durable state owner
2. define the route/provider contract
3. define the execution/action contract
4. define the WM/runtime boundary
5. document the owning files

If a feature cannot be described cleanly in those terms yet, it is probably
still being hacked on rather than integrated properly.

## Review Checklist

- Does the feature use Lua config for durable state if it needs durable state?
- Does the provider emit typed candidates instead of UI-coupled behavior?
- Does route isolation live in the route/rank layer instead of title matching?
- Does execution go through command planning instead of random shell glue?
- Does the feature expose only capabilities that the runtime can actually fulfill?
- Are repo docs and live behavior both updated?
