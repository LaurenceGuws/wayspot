# Providers And Routes

This file defines the current contract for adding search routes and providers to
`wayspot`.

It exists because route/provider bugs are easy to create when route parsing,
provider collection, ranking, and execution planning are treated as the same
problem.

## Layer Responsibilities

### Query parsing

Owns:

- route prefix parsing
- raw term extraction
- no provider-specific behavior

Primary file:

- `src/search/query.zig`

### Provider collection

Owns:

- emitting candidates for one subsystem
- owning provider-local strings/generations
- reporting provider health

Primary files:

- `src/providers/*.zig`

Providers should not:

- parse hidden UI state
- depend on widget behavior
- assume route-specific ranking behavior will save an overly broad candidate set

### Ranking and route isolation

Owns:

- route-to-kind eligibility
- route-specific score shaping
- rejecting candidates that do not belong to a route

Primary file:

- `src/search/rank.zig`

If a route needs strict isolation, score shaping alone is not enough.
Use one of:

- a dedicated candidate kind
- a dedicated action namespace
- another explicit typed discriminator

### Action planning and execution

Owns:

- mapping candidate actions into runnable commands
- distinguishing typed actions from literal shell commands
- telemetry labels and failure behavior

Primary file:

- `src/ui/common/dispatch.zig`

If the action belongs to the app, prefer a typed action id over a raw `cmd:`.

## Recommended Pattern For New Routes

1. Add the route prefix in `src/search/query.zig`.
2. Decide the action namespace or typed discriminator.
3. Implement the provider with narrow candidate output.
4. Implement route isolation in `src/search/rank.zig`.
5. Implement execution in `src/ui/common/dispatch.zig`.
6. Update help/default-loadout/UI hints.
7. Add tests for:
   - route parsing
   - route isolation
   - action planning

## Theme Route Example

The theme route is a good example of the correct pattern now:

- route prefix: `,`
- provider emits typed actions: `theme-apply:<name>`
- ranker rejects non-`theme-apply:*` rows for the theme route
- dispatch resolves `theme-apply:*` into `wayspot --apply-theme <name>`

This prevents generic action candidates from leaking into the theme route.

