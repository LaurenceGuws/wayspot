# Wayspot design

This document records the durable product constraints behind the current source
shape. It is intentionally shorter and more stable than an implementation plan.

`README.md` explains the product. `DOMAIN.yml` lists the current accepted
surface. Source comments and tests own implementation-specific invariants.
Historical rewrite records under `rewrite/` explain how particular decisions
were reached, but they are not current product or workflow authority.

## 1. The picker latency is sacred

Wayspot exists because launcher latency was perceptible. The zero-argument app
picker is therefore the primary product path.

Changes touching startup should preserve these properties:

- the direct standalone path and resident summon both discover fresh applications;
- unrelated modes do not add work before the app picker;
- application discovery has no dependency on notification or wallpaper state;
- input is enabled before the picker waits for user interaction;
- the first useful frame is presented before nonessential icon work;
- optional window finding starts no compositor CLI and parses no window state
  until the person explicitly switches to it after the first frame;
- queued user input takes priority over decorative background work;
- startup latency is measured when the critical path changes.

The accepted shared resident avoids a second long-lived launcher owner. Its
summon endpoint does not justify a startup cache or pre-indexer. Measure both
summons with no video lease and summons while another surface owns SDL.

## 2. Rediscover external facts instead of persisting shadows

The default rule is:

> Own state that Wayspot creates. Rediscover state that somebody else owns.

Examples of external facts:

- installed applications and their desktop entries;
- icon files and themes;
- monitor, workspace, window, and focus facts exposed by the supported native compositor CLI;
- wallpaper files in a configured directory.

These should normally be read from their real authorities when needed. Wayspot
may build bounded process-local representations for the lifetime of an
invocation or resident process, but it should not persist a second derived index
merely to make cheap discovery cheaper.

This rule is valuable for more than simplicity. A fresh Wayspot process should
be correct against the machine as it exists now. Installing an application,
removing one, changing an icon, or changing monitor topology should not require
cache invalidation, schema migration, or repair of historical Wayspot state.

Persistent state is appropriate when persistence is itself part of the product.
Notification history is retained because Wayspot promises notification history.
If another feature eventually owns durable user choices, those choices may also
be persisted deliberately.

Migrations are therefore a strong signal to ask whether the persisted state is
actually Wayspot-owned product data or merely a cached copy of external facts.

## 3. Resident processes must be cheap

Notifications, wallpaper and the tray watcher are resident because their jobs require continuous
ownership. Residency is not a general optimization strategy.

For resident modes:

- idle CPU should approach zero;
- memory and mapped-resource cost should be measured, not guessed;
- waits, queues, buffers, retries, and retained data stay bounded;
- the process owns its own lifecycle and cleanup;
- external desktop churn must not silently kill the resident;
- replacement of an existing desktop utility should provide a meaningful
  resource or ownership win.

A low-level implementation can still have expensive platform mappings. For
example, SDL/Wayland/GPU presentation may make RSS look much larger than the
private working set. Use appropriate measurements such as PSS and private dirty
memory when evaluating a resident rather than optimizing a misleading number.

## 4. Scope does not define mission

Wayspot currently contains four product modes:

1. `apps` - the default application picker and direct CLI app access;
2. `notifications` - freedesktop notification ownership and retained history;
3. `wallpaper` - per-monitor background surfaces and rotation;
4. `tray` - a small windowless StatusNotifierWatcher capability. Icons, menus
   and user actions live in the on-demand picker, not a persistent panel.

The local clock is part of the picker header, not a separate resident. Tray
discovery follows the first useful frame and never blocks its presentation.

The application picker may switch on demand into a global window finder that
strengthens its original job without becoming a taskbar. On Hyprland, the
finder reads one bounded `hyprctl -j clients` snapshot only after explicit
activation, keeps no resident watcher or persistent window shadow, and
uses exact native window addresses with Hyprland's `hl.dsp.focus` Lua dispatcher and
subsequent `hyprctl -j activewindow` verification. Workspace/monitor remain
location metadata rather than nested navigation. Focus recency is read only
when the backend supplies it; workspace-local geometry may be rendered as
a deterministic position such as `2/5` without changing focus order.
No viewport-direction semantics are fabricated when unavailable.

Snowman discovery uses two bounded local CLI observations on entry to window
mode: the mapped window list and the local seat's MRU history. Scene
participation is not a claim of unobscured pixels. The picker retains exact
session-local IDs, including hidden and unpresented windows. Selecting a
Snowman row ends the picker lifetime; a bounded server sync on its original
SDL connection proves that the role and surface destruction were processed
before issuing the compositor's greedy focus command. Validate the exact ID
and both native focus flags. Failure produces a notification without waiting
for our own notification service, retrying, or guessing a different target.
The two observations need not have the same revision. Snowman still owns
presentation, pointer placement and the authority to reject a stale ID.
This remains part of the picker rather than becoming a resident taskbar.

That makes Wayspot useful as a small Hyprland desktop toolbox, but the toolbox
shape came after the original launcher problem. Adding another desktop tool does
not redefine the primary latency requirement or justify a generic framework.

The picker and notifications use SDL's custom Wayland surface role with
Wayland layer-shell, rather than XDG toplevel decorations or compositor-specific
floating exceptions. The picker uses a centered keyboard-exclusive overlay;
notification banners use noninteractive top-right surfaces and reserve no tile
space. SDL still owns rendering and input, not the role's Wayland lifetime.
Wallpaper uses the same protocol family for its per-output background surfaces.
These roles work on Snowman and other layer-shell-capable Wayland compositors,
without a separate compositor plugin architecture.

## 5. Direct code is a means, not the product

The current implementation favors direct data and control flow, explicit
resource ownership, bounded storage, and narrow native boundaries. Those are
good fits for a small desktop utility, but they are not ends in themselves.

Use abstractions when they make the real product easier to understand or make a
real invariant executable. Do not create them merely to satisfy a preferred
architecture vocabulary.

Likewise, defensive tests are valuable when they protect behavior that matters.
The most elaborate failure transcript is not more important than preserving an
instant picker, correct fresh discovery, or a cheap idle resident.

## 6. External events are facts, not invented user intent

Resident features should distinguish a change in external reality from an
unrelated desktop event.

The wallpaper resident is the clearest current example. Monitor add/remove and
configuration changes can require a new set of Wayland surfaces. Focusing a
monitor, changing workspace, or focusing a window does not mean "choose another
wallpaper". The current wallpaper round remains unchanged until its own rotation
policy or an explicit rotate request changes it.

Keep such subsystem invariants close to their source and tests. They belong in
this document only when they illustrate a durable product boundary.

## 7. Known tradeoffs are allowed to remain small

The picker currently renders through a fixed `720x520` logical SDL geometry with
high-DPI support. On a 4K display at fractional scaling around `1.6x`, text and
other presentation can look softer than native-resolution rendering.

This is a known polish issue, not a reason to invent a DPI framework. Fix it
when the visual cost is worth the additional implementation, and measure the
change against the startup path.

## 8. Shared resident ownership

The picker, notifications, wallpaper and tray watcher can now share one
individually configurable Zig resident. This supersedes the fresh-process-only
requirement; the standalone entrypoints remain for compatibility. Preserve fresh application discovery and
independent capability lifecycles. Prefer one sequential state owner, native
readiness and real deadlines; introduce bounded concurrency only for proven
blocking external work. Picker surfaces and transient resources may be
retired independently of the resident. Do not restore the discarded Rust UI
or create a general capability framework.

The shared main-thread video owner initializes SDL on its first surface lease
and quits on its last. Route window and renderer events to their actual
window, not the currently active capability. Picker input advances in bounded
batches with a draw/finish action. Notification D-Bus intake, newest-only
presentation, history and expiry share one sequential service owner; hidden
notifications need no video lease or periodic bus polling. Standalone entrypoints drive the same service turns; the combined loop routes
actual readiness and deadlines, not generic broadcasts to every capability.

Wallpaper now owns one persistent background surface per output on one Wayland
connection. Replace buffers only for rotation or meaningful geometry changes;
add/remove outputs locally, ignore unrelated window/input state, acknowledge
unchanged configure without republication, and distinguish protocol events
from redraw requests. Immutable SHM backing is never reused, so a retired
buffer proxy does not require a release wait. Bound work and retained
resources, not the lifetime count of valid events. The real Wayland gate
checks zero publications on unrelated toplevel and layer-shell churn,
continued surface identity and correct pixels after rotation/fullscreen exit.
The resident uses one authenticated seqpacket command listener, explicit
configuration and one primary thread. A legacy wallpaper identity reservation
prevents a competing standalone publisher. The existing tray fetch worker
returns completion through an eventfd; its lifetime is bounded by the picker.
SDL still owns key repeat: pump at most 8ms apart only while keys are held,
and preserve its 200ms IME fallback while focused without text-input-v3.
There is no hidden-picker polling. Application selection retires the surface
before an exact-argv short-lived helper launches the app and exits; the
resident waits only for the helper and does not retain application children.
The helper unblocks inherited termination signals before launch.

Private combined acceptance is available through `zig build resident-live`.
Physical deployment and key-repeat/IME acceptance are separate. Some external
effects (image decode/scale, native compositor calls, menu calls and launch)
remain synchronous. Measure responsiveness under those effects before adding
concurrency. No source/runtime cutover implies physical endurance acceptance.

## Review questions for future work

Before substantial work, ask:

1. What visible problem does this solve?
2. Does it add work to the default picker startup path?
3. Does it persist a derived copy of state owned elsewhere?
4. If it stays resident, what does it cost while idle?
5. Is a new abstraction simpler than the direct product path it replaces?
6. Which invariant belongs in code/comments/tests after the work is complete?

If those answers are crisp, the implementation process can stay lightweight.
