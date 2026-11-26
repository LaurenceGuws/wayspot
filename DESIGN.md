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
summons with no UI connection and summons while a sibling surface retains it.

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
subsequent `hyprctl -j activewindow` verification. The native UI retires
its exclusive role and fences destruction before dispatch, as on Snowman.
Workspace/monitor remain
location metadata rather than nested navigation. Focus recency is read only
when the backend supplies it; workspace-local geometry may be rendered as
a deterministic position such as `2/5` without changing focus order.
No viewport-direction semantics are fabricated when unavailable.

Snowman discovery uses two bounded local CLI observations on entry to window
mode: the mapped window list and the local seat's MRU history. Scene
participation is not a claim of unobscured pixels. The picker retains exact
session-local IDs, including hidden and unpresented windows. Selecting a
Snowman row ends the picker lifetime; a bounded server sync on its original
native connection proves that the role and surface destruction were processed
before issuing the compositor's greedy focus command. Validate the exact ID
and both native focus flags. Failure produces a notification without waiting
for our own notification service, retrying, or guessing a different target.
The two observations need not have the same revision. Snowman still owns
presentation, pointer placement and the authority to reject a stale ID.
This remains part of the picker rather than becoming a resident taskbar.

That makes Wayspot useful as a small Hyprland desktop toolbox, but the toolbox
shape came after the original launcher problem. Adding another desktop tool does
not redefine the primary latency requirement or justify a generic framework.

The picker and notifications use native Wayland layer-shell rather than
XDG toplevel decorations or compositor-specific floating exceptions. The
picker is a centered keyboard-exclusive overlay, summoned on the target
output rather than dragged as a normal window. Notification banners use
noninteractive top-right surfaces and reserve no tile space. Wallpaper uses
the same protocol family for its per-output background surfaces.
Snowman is the intended sole product target once mature; Hyprland remains
supported during that transition. Prefer specialization at real compositor
boundaries such as window discovery and focus. Shared protocol behavior has
no reason to specialize.

Both standalone and resident invocation use native SHM. SDL remains the CPU
rasterizer and image decoder, with video initialization disabled and no
accelerated renderer or video driver exposed by the build. No backend
fallback, EGL vendor override or compositor plugin is introduced. One
on-demand visible-session connection
owns at most one picker and one notification, with at most three buffers per
surface across all extents. A frame callback permits presentation pacing;
only wl_buffer.release permits writing into an already-submitted buffer.
Invalidations coalesce while either fence is outstanding. Paint receives a
scoped writable borrow; failed paint cancels it before attachment. Surface
retirement abandons mappings without waiting for release and clears callback
contexts; an asynchronous display sync fence can establish dismissal before
native focus. The resident drains each role's own input without discarding
its sibling's events, and releases the connection only after both roles retire.

The native surface keeps layer configure dimensions in logical coordinates.
Fractional-scale v1 and viewporter are used together: round physical extents
in protocol 120ths, keep the wl_surface buffer scale at one, and commit the
logical viewport destination with the buffer. Until a fractional preference
arrives, use the core surface preferred integer scale, then the greatest
committed integer scale of entered outputs, then 1x. Output scale changes
become visible to this owner at wl_output.done; output removal releases its
object and membership. Each surface has its own effective scale. An initial
frame need not wait for a fractional preference that may follow mapping.
Invalidations and scale changes coalesce behind frame/release fences; no
more than three buffers of at most 16 MiB each are retained per surface,
including stale sizes. Reject invalid or oversized physical extents before
allocating. The supported scale numerators are positive and at most 960;
wl_output versions before 3 are not bound. Paint receives both logical and
physical extents and the exact scale, so text can be rasterized at native
pixel density without changing the widget or input coordinate space.
The mixed-density live gate changes a mapped picker through 1.5x, 1.75x, 2x,
1x and 1.5x while keeping an independent 1x banner alive. No role is remapped.
The native input owner selects the exact local seat for the session: `seat0`
on Snowman, `Hyprland` on Hyprland (verified on 0.57.2). Private/agent seats
are not merged; no arbitrary seat fallback. Seat capabilities create
and retire the corresponding keyboard and pointer objects. Keymap FDs are
owned, read with an exact 1 MiB maximum and closed even on error. XKB state
uses compositor modifier/group masks and the Wayland keycode offset; inherited
held keys do not produce presses. Key events carry symbols, modifiers and
bounded direct UTF-8. One optional monotonic repeat deadline belongs to the
visible event loop. Process real readiness and queued transitions first;
late wakes emit at most one repeat and schedule from now. Use the current
modifier state, cap the compositor rate at 100 Hz, never repeat Tab, Escape
or Enter, and cancel on release, focus loss, keymap/rate change or retirement.
The locale's XKB compose table is loaded on first editable keyboard focus,
not for a banner-only connection. Compose consumes its sequence and emits
one UTF-8 result; focus loss resets it. The pointer uses surface-local logical coordinates;
matched releases cannot cross focus or role lifetimes. Adjacent motion can
coalesce, but never across key, button, focus or scroll transitions. Scroll
frames prefer value120, then discrete detents, then continuous distance (ten
logical pixels per detent); each detent moves three rows, at most eighteen
per frame. The 128-event queue reports overflow rather than dropping a
transition. Retiring a surface discards its queued input and cancels its
focus without altering a sibling. The private real-input gate delivers
native key and pointer events to a 1.75x picker through Snowman's existing
virtual-input fixture, without initializing SDL video. The cursor uses the
latest pointer enter serial with cursor-shape v1 when available; otherwise
one immutable 48x48 ARGB SHM buffer represents a 24x24 logical arrow at 2x.
It is not repainted or animated, and retirement never waits for its release.
The real input fixture witnesses cursor-inclusive and cursor-free pixels.

Text-input-v3 binds only the selected seat, enables the editable role on
text-input focus, and exposes bounded 256-byte preedit/commit strings,
deletion lengths and validated UTF-8 cursor offsets as a single done batch.
An unmatched done serial still carries edits but forbids a surrounding-state
update until a matching serial. Leave and retirement discard pending edits.
Ordinary compositor-forwarded keys remain authoritative: do not suppress
all keyboard text just because a text-input manager exists, and do not
synthesize a key from an IME commit. IME edits cancel repeat and local
compose. The picker consumes the edit batch atomically in its append-only query,
keeps preedit outside application matching, draws its cursor/underline, and
publishes surrounding text and logical cursor geometry after matching serials.
Snowman currently lacks the text-input manager, so this path has wire/editor
proof, not end-to-end IME acceptance.

The picker owns one CPU canvas at the current physical extent. SDL's
software renderer and Howl Text glyph/icon caches remain stable across
redraws, and the canvas is copied into an admitted SHM buffer after flushing
CPU draws. The infrequently redrawn banner instead draws directly into the
admitted buffer and retires its borrowed renderer and text resources before
submission. DPI changes use native font density without changing logical
geometry; wrapped banner line heights are logical too. No buffer is written
while the compositor owns it. Both roles share the on-demand native display;
all CPU renderers retire before final SDL cleanup, so no mixed-video shutdown
hook is needed. Newest notification content invalidates the existing role;
expiry is independent of configure, frame and release fences. A click-down
may dismiss the currently submitted generation, not an undisplayed newer
one. Banner failure does not terminate D-Bus service or extend the deadline.
The native connection and repeat wake join the resident's existing sequential
poll loop; frame/release backpressure, tray completion and deadlines drive
drawing. No extra renderer worker or periodic polling timer. Wayland does
not expose global layer coordinates; native SNI activation uses local
coordinates when no global position is available. Product fixture pixels,
application launch, window focus and independent role lifetimes qualify on
private Snowman; physical and Hyprland acceptance remain separate.

The pinned native Wayland snapshot carries a six-site raw Linux errno fix
for libc-linked executables, with its retirement criterion in UPSTREAM.md.

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

The picker retains a fixed `720x520` logical layout, with density-specific
CPU rasterization at the admitted physical extent. The staging canvas adds
one bounded copy so ordinary redraws retain glyph and icon textures. The
banner instead paints directly into the borrowed buffer. Native Wayland
input remains logical even at fractional scale. Measure before adding a
more general widget or renderer framework.

## 8. Shared resident ownership

The picker, notifications, wallpaper and tray watcher can now share one
individually configurable Zig resident. This supersedes the fresh-process-only
requirement; the standalone entrypoints remain for compatibility. Preserve fresh application discovery and
independent capability lifecycles. Prefer one sequential state owner, native
readiness and real deadlines; introduce bounded concurrency only for proven
blocking external work. Picker surfaces and transient resources may be
retired independently of the resident. Do not restore the discarded Rust UI
or create a general capability framework.

The shared main-thread UI owner acquires one native connection on its first
surface lease and releases it on the last. CPU drawing resources retire
before final SDL cleanup. Every external application and CLI receives the
original entrypoint environment. Picker input advances in bounded batches
with a draw/finish action. Notification D-Bus intake, newest-only presentation,
history and expiry share one sequential service owner; hidden notifications
need no UI lease or periodic bus polling. Standalone entrypoints drive the
same service turns; the combined loop routes actual readiness and deadlines,
not generic broadcasts to every capability. The `video_users` field in the
resident/v1 status stays zero for existing consumers; `native_ui_users`
reports the actual graphical leases.

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
Native key repeat supplies a single monotonic deadline while a repeatable
key is held; text-input-v3 and XKB compose do not require a polling fallback.
There is no hidden-picker polling. Application selection retires the surface
before an exact-argv short-lived helper launches the app and exits; the
resident waits only for the helper and does not retain application children.
The helper unblocks inherited termination signals before launch.

Private combined acceptance is available through `zig build resident-live`.
The promoted SHM backend passed physical standalone acceptance on Snowman
and Hyprland; live IME and physical tray placement remain separate gates. Some external
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
