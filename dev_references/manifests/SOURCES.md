# Reference Sources

Captured on 2026-07-03 for the Wayspot SDL launcher and notification sprint.

## Zig

- Source: `/home/home/personal/projects/team/release-notes.html`
- Local copy:
  - `../zig/zig-0.16-release-notes.html`
  - `../zig/zig-0.16-release-notes.md`
- Reason: Zig 0.16 std and build API changes are project-critical.

### Zig std Build Source

- Source: `/home/home/personal/projects/dev_references/zig_maturity/zig/lib/std`
- Captured on: 2026-07-05
- Local copy:
  - `../zig_maturity/zig/lib/std/Build.zig`
  - `../zig_maturity/zig/lib/std/Build/Step/TranslateC.zig`
  - `../zig_maturity/zig/lib/std/Build/Module.zig`
  - `../zig_maturity/zig/lib/std/Build/Step/Compile.zig`
- Reason: ABI/reference-maturity planning needs exact Zig 0.16 build-system
  source for `addTranslateC`, translated module ingestion, include paths,
  system library linking, and C source ownership.
- Scope: exact files only; this is not a full Zig source checkout.

## SDL

- Source: `/home/home/personal/projects/howl/utils/dev_references/sdlwiki_md`
- Local copy: `../sdl/sdlwiki_md`
- Reason: Wayspot UI is SDL 3. The copied wiki markdown covers window,
  renderer, event, timer, text, and platform APIs.
- ABI/image boundary pages confirmed local for the ABI maturity sprint:
  - `../sdl/sdlwiki_md/SDL3/SDL_LoadPNG.md`
  - `../sdl/sdlwiki_md/SDL3/SDL_LoadBMP.md`
  - `../sdl/sdlwiki_md/SDL3/SDL_ConvertSurface.md`
  - `../sdl/sdlwiki_md/SDL3/SDL_CreateSurfaceFrom.md`
  - `../sdl/sdlwiki_md/SDL3/SDL_BlitSurfaceScaled.md`
  - `../sdl/sdlwiki_md/SDL3/SDL_GetError.md`

## Wayland and Layer Shell

- Source: `https://raw.githubusercontent.com/swaywm/wlr-protocols/master/unstable/wlr-layer-shell-unstable-v1.xml`
- Captured on: 2026-07-05
- Local copy: `../wayland/protocols/wlr/wlr-layer-shell-unstable-v1.xml`
- Reason: Wayspot wallpaper and sunglasses surfaces use wlr-layer-shell; the
  ABI sprint needs the protocol XML before deciding whether to consume a
  translated ABI directly or retain minimal C glue.

- Source: `https://gitlab.freedesktop.org/wayland/wayland/-/raw/main/protocol/wayland.xml`
- Captured on: 2026-07-05
- Local copy: `../wayland/protocols/core/wayland.xml`
- Reason: layer-shell requests build on core Wayland protocol objects such as
  `wl_surface`, `wl_output`, `wl_registry`, and `wl_compositor`.

- Source: `https://gitlab.freedesktop.org/wayland/wayland/-/raw/main/src/wayland-client.h`
- Captured on: 2026-07-05
- Local copy: `../wayland/client/wayland-client.h`
- Reason: Wayspot's ABI boundary currently calls Wayland client APIs from C;
  the sprint needs the client API source for shallow boundary decisions.

## Linux Memory Syscalls

- Source: `https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/plain/man/man2/memfd_create.2`
- Captured on: 2026-07-05
- Local copy: `../linux/man-pages/man2/memfd_create.2`
- Reason: current shm buffer creation uses `memfd_create`.

- Source: `https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/plain/man/man2/mmap.2`
- Captured on: 2026-07-05
- Local copy: `../linux/man-pages/man2/mmap.2`
- Reason: current shm buffer creation maps the memfd into process memory.

- Source: `https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/plain/man/man2/ftruncate.2`
- Captured on: 2026-07-05
- Local copy: `../linux/man-pages/man2/ftruncate.2`
- Reason: current shm buffer creation sizes the memfd with `ftruncate`.

- Source: `https://git.kernel.org/pub/scm/docs/man-pages/man-pages.git/plain/man/man2/truncate.2`
- Captured on: 2026-07-05
- Local copy: `../linux/man-pages/man2/truncate.2`
- Reason: `ftruncate.2` is a man-pages include stub for `truncate.2`.

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
