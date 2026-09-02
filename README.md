# Wayspot

Wayspot is a fast application picker and a small set of Hyprland desktop tools
written in Zig.

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

The default `wayspot` invocation is a fresh process. There is no resident
launcher daemon or summon IPC path. SDL is fast enough to create the picker on
demand, so Wayspot keeps the shortest path instead of maintaining machinery to
hide startup cost.

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

### Application picker

Run the default graphical picker:

```bash
wayspot
```

Applications are discovered directly from the current XDG application
directories. Ordinary typing filters the current list; selecting a row launches
the application and exits the picker.

The same application data is available from the CLI:

```bash
wayspot apps
wayspot apps terminal
wayspot "Firefox"
```

The last form launches one exact application name or desktop id.

### Notifications

Own the freedesktop desktop-notification interface:

```bash
wayspot notifications
```

Wayspot presents the newest notification and retains notification history for
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

Wallpaper discovery is also fresh at process start. The resident owns one
background surface per current monitor and reconciles those surfaces when the
monitor topology changes. Merely moving focus between monitors, workspaces, or
windows does not change the current wallpaper round.

### Bash completion

```bash
source <(wayspot completion bash)
```

## Building

Wayspot is currently developed against Zig `0.17.0-dev.1454+5faa79730` on
Arch Linux. SDL is vendored; the build also uses the system Wayland and D-Bus
development interfaces.

Normal desktop build (`ReleaseSafe`):

```bash
zig build
```

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

## Scope

Wayspot is intentionally Hyprland- and Wayland-specific. It is not trying to be
a compositor abstraction, plugin platform, general search framework, or full
desktop environment.

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
SDL starts fast enough, a launcher daemon is a liability. If a resident utility
is cheap and pleasant, it can quietly disappear into the desktop and stop
asking for attention.
