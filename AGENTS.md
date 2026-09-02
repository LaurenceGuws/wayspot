# Wayspot agent guide

Wayspot is a product first. Read the product documents before treating old
rewrite records as instructions.

## Authority

1. `README.md` explains why Wayspot exists and how it is used.
2. `DESIGN.md` contains the durable design constraints.
3. `DOMAIN.yml` records the current accepted product surface.
4. Source, tests, and source comments own current implementation behavior.
5. `rewrite-marathons.yml` and `rewrite/` are historical rewrite records. They
   may contain useful evidence, but they are not current product or workflow
   authority and cannot add scope.

Deleted source and old project documents are also history, not architecture to
restore wholesale.

## Before changing code

- Inspect `git status` and preserve unrelated work.
- Name the visible product problem being solved.
- If the default picker path is touched, inspect and measure startup latency.
- Do not add persistent app/icon/desktop indexes without an explicit product
  decision backed by a measured problem.
- If a resident mode changes materially, measure idle CPU and memory/PSS.
- Put lasting implementation invariants beside the source and tests that enforce
  them rather than in temporary workflow documents.

## Source style

Prefer direct data and direct control flow. Keep ownership, cleanup, bounds,
errors, cancellation, and external-I/O behavior visible. Assertions should cover
important expected and forbidden states.

A new file, type, or abstraction should make a real product path or invariant
clearer. It does not need to exist merely to satisfy a preferred architecture
pattern.

External boundaries such as SDL, Hyprland, Wayland, D-Bus, the filesystem, and
process launch deserve deterministic tests where practical. The depth of a test
suite should remain proportional to the product behavior it protects.

## References

Upstream documentation and source are reference material, not Wayspot authority.
When a task needs low-level precedent, TigerBeetle is a useful defensive-design
reference and Foot is a useful small-runtime reference. Prefer repository-local
vendored sources where present, otherwise use an available upstream checkout or
the upstream project itself. Do not encode one developer machine's filesystem
layout into Wayspot's product or contributor contract.

SDL source used by the build is vendored under `vendor/sdl/`. Protocol XML used
by the Wayland resident lives under `protocols/`.

## Working loop

Implement the smallest complete useful change, exercise the real path, run the
relevant deterministic tests, and stop when the requested problem is solved.
Keep reviewer checkpoints small. Do not commit without operator authority.
