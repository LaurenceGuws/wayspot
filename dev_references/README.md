# Wayspot Local Reference Library

This directory is a local, searchable reference shelf for Wayspot work. It is
not runtime code and must not be imported by `build.zig`.

## Read Routes

- Zig 0.16 interface changes:
  - `zig/zig-0.16-release-notes.md`
  - `zig/zig-0.16-release-notes.html`
- SDL 3 docs:
  - `sdl/sdlwiki_md/SDL3/`
  - useful current pages: `SDL_CreateWindow.md`, `SDL_WaitEvent.md`,
    `SDL_WaitEventTimeout.md`, `SDL_PushEvent.md`, `SDL_RenderDebugText.md`
- Hyprland docs captured from the current wiki:
  - Markdown fast path: `hyprland/pages/`
  - `hyprland/wiki/wiki.hypr.land/IPC/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Basics/Window-Rules/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Basics/Dispatchers/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Basics/Binds/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Basics/Monitors/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Basics/Workspace-Rules/index.html`
  - `hyprland/wiki/wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/index.html`
- TigerBeetle style and source patterns:
  - `style/tigerbeetle/docs/TIGER_STYLE.md`
  - `style/tigerbeetle/src/queue.zig`
  - `style/tigerbeetle/src/message_bus.zig`
  - `style/tigerbeetle/src/stdx/bounded_array.zig`
  - `style/tigerbeetle/src/io.zig`
  - `style/tigerbeetle/src/io/linux.zig`
- Foot pragmatic Wayland/render/process reference:
  - `terminals/foot/wayland.c`
  - `terminals/foot/render.c`
  - `terminals/foot/spawn.c`
  - `terminals/foot/fdm.c`
  - `terminals/foot/reaper.c`

## Rules

- Prefer this library before web searches for SDL, Zig 0.16, TigerBeetle, and
  foot patterns.
- If current Hyprland behavior matters, verify against the live wiki or local
  `hyprctl` output because Hyprland docs move quickly.
- Do not vendor code from here into `src/` without a small owner and a concrete
  Wayspot use case.
- Do not add full upstream repos casually. Add curated references with source,
  date, and reason in `manifests/SOURCES.md`.
