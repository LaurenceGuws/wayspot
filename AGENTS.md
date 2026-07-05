# AGENTS.md

## Repository Map

This file summarizes `tree -L 2` and the Wayspot team workflow. Product-facing
behavior belongs in `README.md`. Runtime truth belongs in Zig doc comments and
the source itself.

- `.agent/history/`
  Wayspot-local project memory. Read it before non-trivial work. Planning and
  memory are production artifacts, not scratch notes.

- `.zig-global-cache/`
  Local Zig cache material. It exists because builds ran here. Do not treat it
  as source, planning, or product state.

- `AGENTS.md`
  Agent operating map and team protocol only.

- `README.md`
  User-facing product language: what Wayspot is, how to run it, and what the
  current user-visible features do.

- `assets/icons/`
  Static assets used by packaging or runtime surfaces.

- `build.zig`, `build.zig.zon`
  Zig 0.16 build graph and dependency pins. Arch Linux requires
  `exe.use_llvm = true`.

- `dev_references/`
  Local source-backed references before browsing: Zig 0.16 notes, SDL docs,
  Hyprland docs, TigerBeetle style, foot source, and manifests proving origin.

- `packaging/desktop/`
  Desktop integration files.

- `packaging/systemd/`
  Service integration files.

- `re-run.sh`
  Local rebuild/sync/run helper. Keep runtime/build knobs centralized here or
  in `.rerun.env`.

- `reference_repo/`
  Local reference material and vendored examples. It is not live Wayspot code.

- `src/`
  Product source. Every file must state its role with a top-level `//!` comment.

- `src/app/`
  Application-level service owners, including search service lifetime and
  history integration.

- `src/c/`
  Small C boundary helpers for SDL/Wayland integration.

- `src/main.zig`
  CLI mode selection, top-level runtime wiring, and cleanup order.

- `src/notifications/`
  Freedesktop notification daemon, bounded notification state, and runtime
  helpers.

- `src/providers/`
  Candidate providers for apps, actions, modes, and notification history.

- `src/search/`
  Query parsing, candidate types, and ranking.

- `src/sunglasses/`
  Monitor-glasses domain state and runtime overlay reconciliation.

- `src/ui/`
  SDL-owned UI surfaces, text rendering, viewport math, icon rendering, and
  future inert UI control models only when they are truly generic.

- `src/wallpaper/`
  Wallpaper daemon/domain code, Hyprland monitor facts, and still-image runtime.

- `tools/`
  Development probes and receipt helpers. Tools are not runtime architecture.

- `zig-pkg/`
  Local Zig package cache/vendor material for SDL dependencies.

## How We Work

Broad tasks run through the indexed sprint workflow.

1. The user gives a codebase task.
2. The coordinator writes a sprint artifact before implementation.
3. The artifact defines full scope, explicit stop conditions, files/folders,
   symbols, comments, tests, removals, receipts, non-goals, and what must not
   exist after completion.
4. The coordinator splits the sprint into slice layers that cover the entire
   ask. No slice may leave compatibility shims, stale paths, or fake progress.
5. A single long-lived planner/coder teammate fleshes out and implements only
   accepted work.
6. A strict reviewer teammate gates the plan and the code.
7. The coordinator delegates sequentially, waits, passes results between them,
   and does not implement sprint code directly.
8. The coordinator reports to the user only for a real user decision/blocker or
   full sprint completion.

Completion means nothing more and nothing less than the accepted sprint remains:
no skipped cleanup, no stale comments, no dead surfaces, no compatibility
wrappers, no broad architecture kept around for later.

## Authority

- Live memory is Wayspot-local: `.agent/history/README.md`,
  `.agent/history/current.yaml`, `.agent/history/sprint.yaml`, and
  `.agent/history/references.yaml`.
- The qagent project is provenance for the copied workflow, not live authority.
- Workers may propose memory edits. The user and coordinator own live memory
  writes unless explicitly delegated.
- Passing tests are not acceptance. Acceptance is conformance to the indexed
  sprint and the reviewer gate.

## Product Scope

Wayspot is a pragmatic DE busybox: CLI-summoned SDL app launcher, notification
daemon, wallpaper daemon, and focused runtime surfaces.

Keep the core path small: initialize SDL for one bounded picker lifecycle, load
app/action/mode candidates, launch the selected command, clean up once, render
typed notification rows, and keep long-lived daemons intentional.

Out of scope unless a fresh indexed sprint accepts it: GTK, shell modules, open
provider registries, broad WM abstractions, web/window/workspace providers,
runtime scripting VMs, resident launcher IPC, and generic UI frameworks.

## Code Rules

- Everything has a bound: loops, queues, buffers, command strings, result pages,
  wake slots, retained notifications, and discovered media.
- Everything is cleaned up once by the owner that allocated or started it.
- CPU sleeps unless there is input, notification work, daemon work, or a
  scheduled deadline.
- Do not use `_ =`, `usize`, `anytype`, or `anyopaque` in active Zig code. The
  only known `anyopaque` exception is the GLib D-Bus callback boundary in the
  notification daemon.
- DRY means remove duplicated intent. It does not mean moving product-specific
  vocabulary sideways into a shared folder.
- `src/ui/controls/`, if present, is only for inert, reusable UI control
  mechanics. No SDL, rendering, search, persistence, Hyprland, daemon, or
  product-domain imports.

## Documentation Rules

Documentation lives with the right audience.

- `README.md` is user-facing language.
- `AGENTS.md` is the repo map and team protocol.
- Zig source comments document what exists and how it works.

Zig comment law follows the standard library style:

- Every Zig file starts with `//!` explaining the file role and ownership.
- Almost every public or important private symbol has `///` explaining its
  contract, ownership, bounds, cleanup, or caller obligation.
- Use plain `//` only for obscure implementation commentary where the domain
  forces a non-obvious shape.
- Delete decorative, stale, roadmap, compatibility, TODO, legacy, and maybe-path
  comments.

Comments are production assertions. If a comment is not true enough to review,
fix the code or delete the comment.
