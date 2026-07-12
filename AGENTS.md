# Wayspot Agent Contract

## Source bibles

- Domain shape: [`DOMAIN.yml`](DOMAIN.yml)
- Project design: [`project_design.yml`](project_design.yml)
- Project rules: [`project_rules.yml`](project_rules.yml)
- Active scope and bounds: [`project_version_scope.yml`](project_version_scope.yml)
- Reviewed design debt: [`debt_offenders.yml`](debt_offenders.yml)
- Domain implementation: [`src/`](src/)
- Build graph: [`build.zig`](build.zig)
- QAgent domain shape: `/home/home/personal/projects/qagent/qagent/schema.yml`
- QAgent engineering contract: `/home/home/personal/projects/qagent/AGENTS.md`
- QAgent project design: `/home/home/personal/projects/qagent/project_design.yml`
- QAgent project rules: `/home/home/personal/projects/qagent/project_rules.yml`
- QAgent active scope: `/home/home/personal/projects/qagent/project_version_scope.yml`
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

`DOMAIN.yml` is the exhaustive Wayspot product shape. `project_design.yml`
defines the dependency graph, `project_rules.yml` defines cross-cutting
engineering rules, and `project_version_scope.yml` defines the active scope
and named bounds. `src/` is the answer for behavior, ownership, cleanup, and
failure meaning. A new root, noun, verb, field, relationship, or product
surface is an operator decision.

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

## Cmd tree

- `Cmd` is the top-level tagged union with the four arms `apps`,
  `notifications`, `wallpaper`, and `sunglasses`.
- The bounded ordered mode array places `apps` first and makes it the default
  picker mode.
- Resident `Cmd` arms own their concrete child-union route behavior, carried by
  one shared closed `SubCmd` union; `apps` has no child union.
- `src/picker/sub_cmd.zig` is the sole declaration owner for `SubCmd`, the
  resident child unions, and the nested `DimSubCmd`, `FilterSubCmd`, and
  `ImageSubCmd` route unions.
- `Candidate` is the next reachable node: either `sub_cmd: SubCmd` or
  `concrete: Concrete`.
- `Concrete` is the closed terminal union with `app`, `open`, `lifecycle`, and
  `notification` arms. `notification` is display-only and must be explicitly
  rejected at selection and launch boundaries.
- Every `Concrete` leaf carries an explicit `Input` contract. `Input` is the
  exact tagged union `none`, `scalar: ScalarInput`, `toggle: ToggleInput`, and
  `path: PathInput`.
- `ScalarInput` selects a reusable GUI slider, `ToggleInput` selects an on/off
  control, and `PathInput` selects a bounded textbox. GUI draft state is not
  resident state; a committed control constructs the typed `Concrete` leaf.
- CLI argv and GUI control commits construct equal `Input` and `Concrete`
  values and reject the same scalar, toggle, path, and monitor bounds.
- GUI and CLI consume the same `Cmd`, `SubCmd`, `Candidate`, and `Input`
  values. No `CandidateType`, `Candidate.types`, or parallel input tag exists.
- `command` and `commands` are deprecated implementation terms; use `Cmd`,
  `SubCmd`, and `Candidate`.

## Comment source

Comments are source code and are maintained with the implementation.

- `///` documents an owned symbol: purpose, inputs, outputs, ownership, bounds,
  invariants, and failure meaning.
- `//!` documents an owned file or module: purpose, scope, boundary, and
  behavioral contract.
- `//` documents a local implementation decision or unusual platform branch.

The comment must describe code that exists now. Missing or stale comments are
unfinished implementation.

## Workflow

- Read the active scope, project rules, domain, design, source, callers, and
  runtime path before changing shape.
- Write or update the design and invariant before implementation.
- Pass the design and debt register through reviewer approval before expanding
  a boundary slice.
- Build the smallest direct slice, then complete its callers, tests, cleanup,
  and real runtime path.
- Keep small commits as reviewer checkpoints. Do not commit without operator
  authorization.

## Zig rules

- `usize` owns indexes, lengths, capacities, byte counts, and standard-library
  boundaries. Domain quantities use a type sized for their meaning.
- Error sets are exact at each owner boundary. `anyerror` earns its place when
  no better direct error shape handles the use case.
- `anytype`, `anyopaque`, erased ownership, and generic wrappers earn their
  place only when no better direct type handles the boundary.
- Every type, field, generic, and conversion must reduce domain ambiguity or
  make ownership, bounds, lifetime, or failure meaning explicit.
- Keep ownership, allocation, cleanup, and failure meaning visible.
- Bound every loop, queue, buffer, Cmd tree, result page, wake slot,
  notification, monitor list, workspace list, window list, and media list.
- Every owner cleans up what it allocates or starts, exactly once.
- CPU sleeps unless input, notification work, or a scheduled deadline exists.
- Keep product vocabulary and ownership in `DOMAIN.yml`.
- Keep compositor facts under `src/env/`; product domains do not own Hyprland
  IPC or vendor types.
- Delete code with no owner, call path, or place in `DOMAIN.yml`.

## Document roles

- `DOMAIN.yml` is product vocabulary, ownership, and allowed surface.
- `project_design.yml` is architecture, dependency, and ownership shape.
- `project_rules.yml` is cross-cutting workflow, ownership, and invariant law.
- `project_version_scope.yml` is active inclusion, exclusion, freeze behavior,
  and named capacity.
- `debt_offenders.yml` is the reviewed current debt register, not a second
  product contract.
- `README.md` is the operator-facing overview and must not override the above.

Before reporting completion:

```sh
zig build test --summary all
zig build
git diff --check
```

Exercise the real binary path whenever it exists. Do not commit without explicit
operator authorization.
