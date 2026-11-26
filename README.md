# Wayspot

Wayspot is a fast application picker and a small set of desktop tools
written in Zig. Snowman is its intended long-term desktop; Hyprland remains
supported during the transition.

It started for one reason: the launcher I was using took roughly four tenths of
a second to appear after its shortcut. That was slow enough to feel wrong. The
primary Wayspot requirement is still deliberately simple:

> Press the shortcut. The picker should already be there.

Wayspot later grew notifications and wallpaper ownership because a bare
Hyprland session still needs a few jobs normally supplied by a traditional
desktop environment. Those extra jobs are useful, but they are not permission
to turn the launcher into a desktop framework. The default picker remains the
most important path in the project.

## Why Wayspot feels different

Three constraints shape the project.

### Fast interaction

The default `wayspot` invocation remains a direct fresh-process compatibility
path. In a session using the unified resident, `wayspot picker` summons the
picker through a bounded command socket. Both paths discover applications fresh
and initialize graphical resources on demand.

The first useful frame is more important than decoration. Application icons are
resolved and decoded just in time for visible rows after presentation rather
than before the window can appear.

A startup-latency regression is a product regression even when every test still
passes.

### Disposable derived state

Wayspot does not keep a persistent application database or icon index.
Applications are discovered from the current XDG desktop files when they are
needed, and icon paths are resolved from the current filesystem.

This is intentional. The filesystem, desktop entries, Hyprland, Wayland, and
D-Bus already own their facts. Wayspot should not maintain a second historical
model merely to avoid inexpensive rediscovery.

Process-local memory is fine. Product-owned durable state is also fine when the
persistence is the feature itself. Notification history is the obvious example:
Wayspot promises to retain it, so Wayspot owns it.

### Cheap residency

Some desktop jobs genuinely need a resident process. Wayspot's notification and
wallpaper modes are examples. Resident features should earn that residency with
low idle CPU, bounded state, explicit ownership, and measured resource cost.

Replacing a heavyweight desktop utility with a tiny Zig process is a feature,
not just an implementation detail.

## Current tools

### Unified resident

Start one foreground process as a compositor-owned session child, with an
explicit JSON configuration file:

```json
{
  "picker": true,
  "notifications": true,
  "tray": true,
  "wallpaper": "/absolute/path/to/wallpapers"
}
```

```bash
wayspot resident /absolute/path/to/wayspot.json
wayspot resident status
wayspot picker
wayspot picker dismiss
wayspot wallpaper rotate
```

The first three capabilities default to enabled; set any to `false` to disable
it. Wallpaper defaults to `null` (disabled) and otherwise requires an absolute
image-directory path. Configuration is read at startup; unknown fields are
rejected. Disabling tray also disables picker tray discovery. A hidden picker
retains no application catalogue, window, renderer or tray textures. SDL is
initialized on the first graphical surface and retired on the last. Wallpaper
and D-Bus owners advance on their own readiness or deadlines; the only
application-owned worker is the bounded visible-picker tray fetcher.

Status reports the resident PID, enabled capabilities and currently owned
surfaces. Summon and dismiss are idempotent; disabled operations refuse with an
error. Rotation returns after publication requests are flushed, not after a
physical frame is observed. The session-scoped, same-UID command endpoint
refuses a second resident. Do not run standalone owners of enabled capabilities
alongside it; their existing D-Bus names and wallpaper identity prevent
competing ownership. Standalone commands remain available for migration.

The opt-in `zig build resident-live` gate uses explicit source-built
`SNOWMAN_COMPOSITOR` and `SNOWMAN_CLI` paths, `WAYSPOT_TEST_SCRATCH` and
`WAYSPOT_PROOF_DIR` directories, and optionally `WAYSPOT_BASELINE`. It owns a
private D-Bus session and two headless outputs; the fixture requires Python
with dbus-python and PyGObject, gdbus, grim, and a matching Snowman build.
Provide the matching source-built `SNOWMAN_SIM_CLIENT` to also exercise the
window finder using real private Wayland keyboard and pointer events.

The opt-in `zig build native-surface-live` gate exercises the candidate
native SHM surface owner on a disposable single-output Snowman session. Set
`SNOWMAN_COMPOSITOR`, `WAYSPOT_TEST_SCRATCH`, and `WAYSPOT_PROOF_DIR` as above.
It witnesses actual CPU-rendered glyphs and independent picker/banner
retirement; ordinary tests exercise delayed buffer release and failed wire
operations on real socketpairs. `zig build native-scale-live` uses the same
explicit private fixture paths (and the matching `snowman` CLI next to the
compositor) to check a 1x banner and a picker whose output changes between
1x, 1.5x, 1.75x and 2x. It checks actual buffer sizes, native-density text and
composed pixels without recreating the surfaces. `zig build native-input-live`
uses the matching `snowman-sim-client` next to the private compositor to
exercise real Wayland keymap, key and matched pointer events on a 1.75x layer,
including the rendered fallback cursor. The source-test graph links
libxkbcommon for native keyboard decoding and compose. Socketpair tests also
exercise repeat deadlines, compose, cursor-shape and text-input-v3 done
transactions. The actual picker edit adapter is covered by source tests;
real IME remains outstanding. The installed default remains the SDL build
until native UI physical acceptance.

### Application picker

Build the opt-in native SHM graphical UI with:

```sh
zig build -Dnative_ui=true
```

Both standalone and resident picker/notification roles use this backend.
`-Dnative_picker=true` remains an alias for the new option, enabling both
roles; the transitional mixed SDL/SHM build is retired. The native build
never initializes SDL video and ignores EGL manifest specialization. SDL's
CPU drawing primitives remain. The portable default build remains the
accepted SDL UI until physical acceptance. The resident-live fixture checks
actual role pixels, independent retirement, original application launch
environment and window focus. With an explicit installed accelerated
baseline it also compares the picker-only and full combined resident scopes.

Run the default graphical picker:

```bash
wayspot
```

The picker has a slim status bar above search, followed by the familiar
fourteen result rows. The bar displays the local date and 24-hour time, and
currently registered StatusNotifier application icons when a watcher is
available. The clock updates at the next minute while the window is open.
It uses the existing picker renderer and does not start a separate desktop bar.
On layer-shell-capable Wayland compositors (including Snowman), the picker is a
centered **overlay surface** with exclusive keyboard focus while visible: no
XDG toplevel, window decoration, or tile slot. SDL still handles its rendering,
input, and output scaling. Its first useful frame remains the latency target.

Applications are discovered directly from the current XDG application
directories. Ordinary typing filters the current list; selecting a row launches
the application and exits the picker.

The same picker can find current windows without becoming a resident taskbar.
On Hyprland, press `Tab` after the first frame to read one bounded
`hyprctl -j clients` snapshot. `Tab` returns to applications. Window rows span
current workspaces and monitors; they use Hyprland focus-history order when
available and show workspace as location metadata. `Up` and `Down` select,
typing filters, and `Enter` focuses the exact selected address using
the Hyprland 0.56+ Lua dispatcher `hl.dsp.focus({ window = "address:<id>" })`. Wayspot then checks that
`hyprctl -j activewindow` reports that same address. The native UI first
retires its exclusive layer and receives a bounded display sync; the
legacy SDL path retains its existing verify-before-close behavior.
On Snowman, `Tab` reads `snowman window list --mapped` and `snowman seat get 1`,
including mapped hidden and unpresented windows. The local seat supplies focus
recency. Selecting a window retains its exact numeric ID, retires the picker
surface and receives a bounded Wayland sync before `snowman window focus ID`.
Greedy is the compositor default; no membership changes or alternative-target
fallbacks are performed by Wayspot. A successful receipt must name that ID
and confirm both keyboard and pointer focus. A refusal is reported with a
notification (using the existing detached launcher, so the notification
service may be owned by this same resident). Row clicks select on matching
button release, not button-down. `Escape` closes either mode.

Window rows reuse the icon of one unambiguous matching desktop application,
then show the current title and workspace. Where a workspace has multiple
windows, a deterministic geometry ordinal such as `2/5` is also displayed.
Hyprland's client snapshot does not supply viewport-direction classification,
so Wayspot does not invent offscreen/clip markers. Windows with no safe application
identity match retain their text labels.

The window finder selects its backend by an exact `XDG_SESSION_DESKTOP`
match (`Hyprland` or `Snowman`), not a desktop compatibility list or compositor
signature. The finder is lazy: opening the application picker does not start a
compositor CLI, cache windows, or run a persistent watcher. When Hyprland CLI
observation or focus fails, the window finder reports the failure without
focusing another target. On Snowman, discovery failure remains visible in
window mode; focus refusal after dismissal does not reopen the picker or
retry. The two on-demand observations are not a joint atomic snapshot. The
finder is bounded to 128 windows; oversized or malformed replies refuse
rather than silently dropping windows. No backend substitutions occur.

The same application data is available from the CLI:

```bash
wayspot apps
wayspot apps terminal
wayspot "Firefox"
```

The last form launches one exact application name or desktop id.

### System tray

The StatusNotifier watcher must remain available while the picker is closed,
because applications register their items over the session D-Bus. Start the
small, windowless resident alongside your Hyprland session:

```bash
wayspot tray
```

The picker reads tray items **after presenting its first frame**, loads their
bounded pixmaps or named icons, and refreshes the tray while it is open.
Left and middle click send standard activation methods. Right click, or an
item that primarily represents a menu, opens its D-BusMenu inside the picker
when available; otherwise Wayspot asks the application to show its context
menu. Menus support selection and submenus. No tray icon database is stored,
and an unavailable watcher never prevents the application picker from opening.

### Notifications

Own the freedesktop desktop-notification interface:

```bash
wayspot notifications
```

Wayspot presents the newest notification as a noninteractive **top-right
layer-shell surface**, never a tiled window, and retains notification history for
30 days. History is available from the picker at `/notifications` and from the
CLI:

```bash
wayspot notifications history
```

Notification history is durable product state. It is not a cache of an
external authority.

### Wallpaper

Run one wallpaper resident over a directory of PNG/JPEG images:

```bash
wayspot wallpaper ~/Pictures/wallpapers
```

Request an immediate rotation:

```bash
wayspot wallpaper rotate
```

Wallpaper discovery is fresh at process start. One Wayland connection owns
one persistent background layer per current output. Its physical buffer size
comes from committed `wl_output` mode/transform facts and the logical destination
comes from that layer's configure event. Output coordinates, workspace state,
window focus and input events are irrelevant. Unchanged configure events are
acknowledged without republishing. Rotation replaces immutable buffers, not
surfaces or connections; adding/removing an output affects only its layer.
An explicitly closed layer on a still-advertised output is retired and retried
after five seconds, or sooner on explicit rotation or changed output geometry.
A lost transport reconnects to the selected endpoint; protocol faults are not
treated as ordinary disconnects.
The selected encoded image is retained for output changes, even if the file
is removed. Failed image preparation preserves the current content.

The hourly deadline sleeps when no outputs are available. On return, a due
rotation runs once rather than catching up. A manual rotation without an
available output is refused. The authenticated per-display rotation socket
uses `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY`; no Hyprland IPC is required.

The opt-in real Wayland gate uses isolated Snowman, Foot and grim. It checks
actual background role/attachment identity, pixel colors across rotation and
fullscreen exit, fractional scale, output removal/re-add, zero-output idle
cost and cleanup. Long physical-session endurance is a separate acceptance
obligation. Wallpaper portability does not imply that the picker/window-finder
and tray workflows are compositor neutral.

### Bash completion

```bash
source <(wayspot completion bash)
```

## Installing on Arch Linux

An AUR-style VCS package is maintained in [`packaging/arch/PKGBUILD`](packaging/arch/PKGBUILD).
It installs the binary, desktop entry, icon, Bash completion, and MIT license.
Wayspot requires the official Zig `0.17.0` compiler. The VCS package downloads
that exact Linux x86_64 compiler as a checksum-verified build source, rather
than depending on an outdated distribution compiler or Zig's moving `master`.

For a manual package build, from the packaging directory:

```bash
makepkg -si
```

The package is named `wayspot-git` and provides/conflicts with `wayspot`, leaving
a clean path for a versioned `wayspot` package once the compiler baseline and a
release tag are stable.

## Building

Wayspot is developed and tested with official Zig `0.17.0` on Arch Linux, also
recorded in `.zigversion` and the Zig package manifest. SDL3 is vendored for
windowing and drawing. Text shaping and glyph rasterization come from an exact,
provenance-recorded snapshot of Howl Text in
`vendor/howl-text`, using system FreeType and HarfBuzz. Wayland and D-Bus are
also system dependencies.

Normal desktop build (`ReleaseSafe`):

```bash
zig build
```

An explicitly specialized build can restrict GUI EGL discovery to one
installed GLVND vendor manifest, for example on an NVIDIA-only workstation:

```bash
zig build -Degl_vendor_manifest=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
```

The option is absent by default. It selects a single absolute path, not a
GPU brand or runtime detector; the selected file must be readable at graphical
process startup. The GUI process uses the selected manifest, while application
launches, focus commands and notification helpers receive the original
session environment. No global EGL configuration or driver selection changes.

Wayspot deliberately defaults to an optimized build with runtime safety checks.
Use an explicit mode when debugging or measuring the fastest release shape:

```bash
zig build -Doptimize=Debug
zig build -Doptimize=ReleaseFast
```

Run the complete test suite with:

```bash
zig build test --summary all
```

Run the normal repository health gate with:

```bash
zig build check
```

It checks Zig formatting and runs the full tests (including the standalone
wallpaper-catalog tool and Bash completion). `zig build audit` is a separate
ruleset-3 gate for build logic and maintenance Zig tooling. Application source
still needs its own reviewed shared-audit migration; this gate deliberately
does not claim to audit the product's `src/` files yet.

## Scope

Wayspot's native window finder remains Hyprland-first; Snowman window discovery
and focus are not yet available. The picker, notifications and wallpaper use
Wayland layer-shell and do not require Hyprland. Wayspot is not a compositor
abstraction, plugin platform, general search framework, or full desktop
environment.

New tools are welcome when they solve a real desktop problem without damaging
the properties that make the existing tool pleasant to use: immediate
interaction, disposable derived state, and cheap residency.

See [`DESIGN.md`](DESIGN.md) for the durable engineering constraints behind
those properties. [`DOMAIN.yml`](DOMAIN.yml) records the current accepted
product surface.

## A short history

Wayspot began as a Spotlight-style launcher while I was learning Zig. The first
attempt tried to defeat launcher startup latency with the familiar toolkit:
resident GTK state, asynchronous refresh, caches, and an IPC summon path. SDL
made most of that unnecessary because a fresh native window could simply start
fast enough.

The project then grew arms and legs. Once a resident process existed, owning the
freedesktop notification bus was useful. Wallpaper and other desktop experiments
followed. Eventually the project approached the same complexity that had made
larger learning projects exhausting, including substantial derived state and
migration concerns.

The current implementation came from deliberately cutting that shape back. The
lesson was not that Wayspot must remain tiny at any cost. It was that complexity
has to buy something visible to the person using the desktop. If rediscovering
current reality is already fast enough, persistent indexes are a liability. If
SDL starts fast enough, an extra launcher daemon is a liability. Sharing the
already-required desktop utility resident is different: its ownership must
remain simpler and its cost measured.

## License

Wayspot is released under the [MIT License](LICENSE), a small gift to the Linux
ecosystem from Captain and crew.
