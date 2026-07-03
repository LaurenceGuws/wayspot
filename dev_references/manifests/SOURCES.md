# Reference Sources

Captured on 2026-07-03 for the Wayspot SDL launcher and notification sprint.

## Zig

- Source: `/home/home/personal/projects/team/release-notes.html`
- Local copy:
  - `../zig/zig-0.16-release-notes.html`
  - `../zig/zig-0.16-release-notes.md`
- Reason: Zig 0.16 std and build API changes are project-critical.

## SDL

- Source: `/home/home/personal/projects/howl/utils/dev_references/sdlwiki_md`
- Local copy: `../sdl/sdlwiki_md`
- Reason: Wayspot UI is SDL 3. The copied wiki markdown covers window,
  renderer, event, timer, text, and platform APIs.

## Hyprland

- Source: official wiki pages under `https://wiki.hypr.land/`
- Captured with: `wget -p -k -E -H`
- Local copy:
  - `../hyprland/wiki`
  - `../hyprland/pages` converted from captured HTML with `pandoc -t gfm`
- Pages:
  - `https://wiki.hypr.land/IPC/`
  - `https://wiki.hypr.land/Configuring/Basics/Window-Rules/`
  - `https://wiki.hypr.land/Configuring/Basics/Dispatchers/`
  - `https://wiki.hypr.land/Configuring/Basics/Binds/`
  - `https://wiki.hypr.land/Configuring/Basics/Monitors/`
  - `https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/`
  - `https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/`
- Reason: Wayspot needs pragmatic Hyprland IPC/window behavior without reviving a
  broad WM framework.

## TigerBeetle

- Source: `/home/home/personal/projects/howl/utils/dev_references/zig_maturity/tigerbeetle`
- Local copy: `../style/tigerbeetle`
- Excluded: nested `.git`, Zig caches, build outputs.
- Reason: local style oracle for bounded runtime behavior, assertions, comments,
  explicit owners, and lifecycle cleanup.

## Foot

- Source: `/home/home/personal/projects/howl/utils/dev_references/terminals/foot`
- Local copy: `../terminals/foot`
- Excluded: nested `.git`, Zig caches, build outputs.
- Reason: pragmatic Wayland/render/process reference with small C owners and
  mature terminal lifecycle code.

## Sibling Reference Shelves

Not copied wholesale:

- `/home/home/personal/projects/howl/utils/dev_references`
- `/home/home/personal/projects/opentui/utils/dev_references`
- `/home/home/personal/projects/reader/dev_references`
- `/home/home/personal/projects/team/.agent/history`

Use these when a sprint needs a wider source comparison, then copy only the
small relevant slice here with provenance.
