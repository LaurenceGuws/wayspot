# Wayspot Working Contract

## Authority

`DOMAIN.yml` contains the accepted product scope. It does not prescribe source
architecture. The deleted source and deleted project documents are rejected
designs and must not be restored wholesale or treated as precedent. A hardened
implementation may be reincarnated only after its new owner, boundary,
invariants, and useful product path are approved. Picker rendering and other
proven mechanics may be reused without preserving their rejected architecture.
`rewrite-marathons.yml` owns rewrite sequence and closure; its per-marathon
scratchpads are temporary and cannot add product scope.

A source noun, file, folder, dependency direction, data structure, or runtime
boundary requires an explicit design reason and operator approval before code.

## Style bars

1. Simplicity: direct data, direct control flow, few files, few types, and
   little code.
2. Readability: names describe real product things and tasks; comments explain
   current ownership, bounds, invariants, and failure meaning.
3. Capability: every implemented slice completes one useful product path. A
   scaffold, abstraction, or passing test without working behavior is not a
   feature.
4. Defensiveness: ownership, cleanup, bounds, invariants, errors, cancellation,
   and external I/O behavior are explicit and executable.

TigerBeetle is the primary reference for design-first invariants and defensive
source shape. Foot is the primary reference for small, direct runtime code.
QAgent is a secondary reference for intentional file ownership. References do
not define Wayspot product scope.

## Local references

- TigerBeetle style:
  `/home/home/personal/projects/dev_references/zig_maturity/tigerbeetle/docs/TIGER_STYLE.md`
- TigerBeetle source:
  `/home/home/personal/projects/dev_references/zig_maturity/tigerbeetle/src/`
- Foot source:
  `/home/home/personal/projects/dev_references/terminals/foot/`
- QAgent source:
  `/home/home/personal/projects/qagent/qagent/src/`
- Zig 0.16 documentation:
  `/home/home/personal/projects/official_docs/ziglang.org/download/0.16.0/`
- Zig 0.16 source:
  `/home/home/personal/projects/dev_references/zig_maturity/zig/`
- Zig 0.16 release notes:
  `/home/home/personal/projects/qagent/zig-0.16-release-notes.txt`
- SDL built source:
  `vendor/sdl/` (official `release-3.4.12`, commit
  `f87239e71e42da91ca317a12eefb82cfbf3393eb`)
- SDL shared source clone:
  `/home/home/personal/projects/dev_references/backends/sdl/`
- SDL documentation:
  `/home/home/personal/projects/dev_references/sdlwiki_md/SDL3/` (wiki commit
  `a9d781e8c978681e5c8119c2accc11fc7c155028`)
- Hyprland source:
  `/home/home/personal/projects/dev_references/backends/hyprland/`
- Hyprland IPC:
  `/home/home/personal/projects/dev_references/backends/hyprland-wiki/content/IPC/_index.md`
- D-Bus source and specification:
  `/home/home/personal/projects/dev_references/backends/dbus/` (commit
  `f64ae3cafdcf31606401171bb0e8fe3fccc761c2`)
- Desktop notification specification:
  `/home/home/personal/projects/dev_references/backends/xdg-specs/notification/notification-spec.xml`
  (repository commit `d77a8e95d4a0ccf6f330a02b2a6e8e0085c39579`)

## Workflow

- Design one useful vertical slice before naming its files.
- State the owner, inputs, outputs, bounds, invariants, errors, cleanup, and
  negative space before implementation.
- Obtain operator approval for the design before creating source.
- Implement the smallest complete path and stop expansion when debt appears.
- Assertions cover expected and forbidden states.
- Comments are source code and describe behavior that exists now.
- Keep functions and files small enough to audit as complete units.
- Bound every buffer, list, loop, queue, wait, retry, and external record.
- Every allocation, file, socket, process, thread, and native object has one
  visible owner and exactly one cleanup path.
- External SDL, Hyprland, DBus, filesystem, and process behavior is tested with
  unit tests, fuzzing, and deterministic simulations over strict transcripts.
  Fixtures and a live desktop are not CI proof.
- Exercise the real product path after deterministic proof exists.
- Keep small reviewer checkpoints. Do not commit without operator authority.

## Design gate

Before adding source, present:

1. the product path being completed;
2. the minimum file tree;
3. one sentence of ownership per file;
4. dependency direction;
5. named bounds and failure meaning;
6. assertions and tests;
7. explicit exclusions.
