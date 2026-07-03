# AGENTS.md

## Read This First
- Before non-trivial work, read `/home/home/personal/projects/team/AGENTS.md`.
- Then read the active project memory:
  - `/home/home/personal/projects/team/.agent/history/artifacts.jsonl`
  - `/home/home/personal/projects/team/.agent/history/external-review-bias-index.md`
  - `/home/home/personal/projects/team/.agent/history/tigerbeetle-overnight-bar.md`
  - `/home/home/personal/projects/team/.agent/history/qserver-zig-migration-map.yaml`
- Treat those files as the local engineering bible: exact owners, bounded runtime behavior, accountable comments, no stale vocabulary, and no compatibility-shaped code.
- Wayspot-local project memory lives in `.agent/history/`:
  - `.agent/history/README.md`
  - `.agent/history/artifacts.jsonl`
  - `.agent/history/wayspot-scope-map.yaml`
  - `.agent/history/wayspot-surface-scale-index.yaml`
- Treat the local memory surface as production artifacts. Comments are planned production code; planning and memory are production artifacts.
- Use `dev_references/` for local source-backed docs before browsing. It contains Zig 0.16 release notes, SDL wiki markdown, captured Hyprland docs, TigerBeetle, and foot references with provenance in `dev_references/manifests/SOURCES.md`.

## Wayspot Scope
- Wayspot is a CLI-summoned SDL app launcher plus a minimal freedesktop notification daemon.
- Keep the core path small: initialize SDL for one bounded picker lifecycle, load app/action candidates, launch the selected command, clean up once, and render typed notification rows.
- The notification daemon is the only long-lived interface. Do not restore resident launcher IPC without a fresh approved design.
- GTK, shell modules, open provider registries, broad WM abstractions, web/window/workspace providers, and runtime scripting VMs are out of scope.

## Code Rules
- Everything has a bound: loops, queues, buffers, command strings, result pages, wake slots, and retained notifications.
- Everything is cleaned up once by the owner that allocated or started it.
- CPU should sleep unless there is input, notification work, or a scheduled deadline.
- Do not use `_ =`, `usize`, `anytype`, or `anyopaque` in active Zig code. The only known `anyopaque` exception is the GLib D-Bus callback boundary in the notification daemon.
- Comments are production assertions. Keep `//!` file role comments and `///` important boundary comments; delete decorative, stale, roadmap, compatibility, TODO, legacy, and maybe-path text.

## Local Dev
- Use `./re-run.sh` to rebuild, install the binary, and run one picker lifecycle.
- Keep runtime/build flags centralized in `re-run.sh` or `.rerun.env`.
- Zig 0.16 on Arch needs `exe.use_llvm = true`.

## Commit Cadence
- Small commits are required at healthy checkpoints.
- When the user says "it looks good", "nice", or "it's working", commit the current working state before continuing.
