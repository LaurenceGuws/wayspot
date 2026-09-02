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

## Local references

Primary source-shape references:

- TigerBeetle style:
  `/home/home/personal/dev_references/zig_maturity/tigerbeetle/docs/TIGER_STYLE.md`
- TigerBeetle source:
  `/home/home/personal/dev_references/zig_maturity/tigerbeetle/src/`
- Foot source:
  `/home/home/personal/dev_references/terminals/foot/`
- QAgent source:
  `/home/home/personal/qagent/qagent/src/`

External implementation references:

- Zig source: `/home/home/personal/dev_references/zig_maturity/zig/`
- SDL built source: `vendor/sdl/`
- SDL docs: `/home/home/personal/dev_references/sdlwiki_md/SDL3/`
- Hyprland source: `/home/home/personal/dev_references/backends/hyprland/`
- Hyprland IPC:
  `/home/home/personal/dev_references/backends/hyprland-wiki/content/IPC/_index.md`
- D-Bus source/spec:
  `/home/home/personal/dev_references/backends/dbus/`
- Desktop notification spec:
  `/home/home/personal/dev_references/backends/xdg-specs/notification/notification-spec.xml`

The current Home checkout uses Zig `0.17.0-dev.1454+5faa79730` through the
workspace-local `.zig/zig` link. The link is machine-local and ignored by Git;
check the live compiler before relying on it.

## Working loop

Implement the smallest complete useful change, exercise the real path, run the
relevant deterministic tests, and stop when the requested problem is solved.
Keep reviewer checkpoints small. Do not commit without operator authority.
