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

- a fresh process is the normal picker lifecycle;
- unrelated modes do not add work before the app picker;
- application discovery has no dependency on notification or wallpaper state;
- input is enabled before the picker waits for user interaction;
- the first useful frame is presented before nonessential icon work;
- queued user input takes priority over decorative background work;
- startup latency is measured when the critical path changes.

A resident launcher, warm summon protocol, startup cache, or pre-indexer must
solve a measured problem large enough to justify the lifecycle and invalidation
cost it introduces. At present, none is required.

## 2. Rediscover external facts instead of persisting shadows

The default rule is:

> Own state that Wayspot creates. Rediscover state that somebody else owns.

Examples of external facts:

- installed applications and their desktop entries;
- icon files and themes;
- monitor topology and compositor facts;
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

Notifications and wallpaper are resident because their jobs require continuous
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

Wayspot currently contains three product modes:

1. `apps` - the default application picker and direct CLI app access;
2. `notifications` - freedesktop notification ownership and retained history;
3. `wallpaper` - per-monitor background surfaces and rotation.

That makes Wayspot useful as a small Hyprland desktop toolbox, but the toolbox
shape came after the original launcher problem. Adding another desktop tool does
not redefine the primary latency requirement or justify a generic framework.

Wayspot is currently Hyprland-only by choice. There is no planned compositor
plugin architecture.

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

The picker currently renders through a fixed `720x480` logical SDL geometry with
high-DPI support. On a 4K display at fractional scaling around `1.6x`, text and
other presentation can look softer than native-resolution rendering.

This is a known polish issue, not a reason to invent a DPI framework. Fix it
when the visual cost is worth the additional implementation, and measure the
change against the startup path.

## Review questions for future work

Before substantial work, ask:

1. What visible problem does this solve?
2. Does it add work to the default picker startup path?
3. Does it persist a derived copy of state owned elsewhere?
4. If it stays resident, what does it cost while idle?
5. Is a new abstraction simpler than the direct product path it replaces?
6. Which invariant belongs in code/comments/tests after the work is complete?

If those answers are crisp, the implementation process can stay lightweight.
