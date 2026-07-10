# Wayspot Agent Contract

## Source bibles

- Domain shape: [`DOMAIN.yml`](DOMAIN.yml)
- Domain implementation: [`src/`](src/)
- Build graph: [`build.zig`](build.zig)
- QAgent shape reference: `/home/home/personal/projects/qagent/DOMAIN.yml`
- QAgent engineering contract: `/home/home/personal/projects/qagent/AGENTS.md`
- QAgent implementation shape: `/home/home/personal/projects/qagent/qagent/src/`
- TigerBeetle defensive shape: `/home/home/personal/projects/dev_references/zig_maturity/tigerbeetle/docs/TIGER_STYLE.md`
- TigerBeetle source patterns: `/home/home/personal/projects/dev_references/zig_maturity/tigerbeetle/src/`
- Foot direct runtime shape: `/home/home/personal/projects/dev_references/terminals/foot/`
- Zig 0.16 official documentation: `/home/home/personal/projects/official_docs/ziglang.org/download/0.16.0/`
- Zig 0.16 source clone: `/home/home/personal/projects/dev_references/zig_maturity/zig/`
- Zig 0.16 standard library source: `/home/home/personal/projects/dev_references/zig_maturity/zig/lib/std/`
- SDL3 source clone: `/home/home/personal/projects/dev_references/backends/sdl/`
- SDL3 documentation reference: `/home/home/personal/projects/dev_references/sdlwiki_md/SDL3/`
- Local implementation references: `/home/home/personal/projects/dev_references/`

`DOMAIN.yml` is the exhaustive allowed shape. `src/` is the answer for
behavior, ownership, bounds, cleanup, and failure meaning. A new root, noun,
verb, field, relationship, or product surface is an operator decision.

Use the local bibles before browsing or inventing an API boundary. TigerBeetle,
Foot, and QAgent are the primary shape references, in that order of emphasis:
TigerBeetle for defensive invariants, Foot for direct systems/runtime code, and
QAgent for current domain and ownership shape. The Zig standard library source
is authoritative for Zig behavior and build mechanics; the SDL3 pages are
authoritative for SDL behavior. None of these references define Wayspot product
ownership.

## Four bars

1. Simplicity: direct data, direct control flow, small code.
2. Readability: domain code reads as English.
3. Capability: the desktop sees and controls Wayspot’s real useful surfaces.
4. Defensiveness: explicit ownership, cleanup, bounds, invariants, exact
   errors, and executable boundary checks.

## Comment source

Comments are source code and are maintained with the implementation.

- `///` documents an owned symbol: purpose, inputs, outputs, ownership, bounds,
  invariants, and failure meaning.
- `//!` documents an owned file or module: purpose, scope, boundary, and
  behavioral contract.
- `//` documents a local implementation decision or unusual platform branch.

The comment must describe code that exists now. Missing or stale comments are
unfinished implementation.

## Implementation

- Keep ownership, allocation, cleanup, and failure meaning visible.
- Bound every loop, queue, buffer, command, result page, wake slot,
  notification, monitor list, workspace list, window list, and media list.
- Every owner cleans up what it allocates or starts, exactly once.
- CPU sleeps unless input, notification work, or a scheduled deadline exists.
- Keep product vocabulary and ownership in `DOMAIN.yml`.
- Keep compositor facts under `src/env/`; product domains do not own Hyprland
  IPC or vendor types.
- Delete code with no owner, call path, or place in `DOMAIN.yml`.
- Do not use `_ =`, `usize`, `anytype`, or `anyopaque` in active Zig code.

## Progress

Read the request, domain, source, callers, and runtime path before changing
shape. Build exactly the requested slice, then challenge it against reality.
Complete its source, callers, tests, cleanup, and runtime path. Passing tests
are necessary evidence; acceptance requires conformance to `DOMAIN.yml`.

Before reporting completion:

```sh
zig build test --summary all
zig build
git diff --check
```

Exercise the real binary path whenever it exists. Do not commit without explicit
operator authorization.
