<!--
SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>

SPDX-License-Identifier: MIT
-->

# zig-wayland-native

A Wayland client for Zig 0.17 with no libwayland in it: a scanner that turns
protocol XML into Zig bindings at build time, the wire protocol with the I/O
taken out, and a client that speaks it over a Unix socket, file descriptors
and all.

The [API documentation][docs] is generated from the doc comments, which is
where most of the explanation lives, and is published from `main`.

[docs]: https://jeff.jcollie.page/zig-wayland-native/

## Modules

The package is named `wayland` and exports three modules: `scanner`, which
the build runs; `protocol`, which needs nothing but the standard library; and
`client`, which builds on `protocol`. A fourth, `present`, is built against
the consumer's own bindings.

| Module | Depends on | What it does |
| --- | --- | --- |
| `scanner` | [zxml][zxml] | Reads protocol XML into a model and renders Zig bindings from it |
| `protocol` | the standard library | Encodes requests and decodes events, tracks which object each id names, and handles `wl_display.error` and `delete_id` — with no I/O at all |
| `client` | `protocol` | Finds and connects the socket, sends and receives with `SCM_RIGHTS`, and dispatches events to listeners. Linux only |
| `present` | `client` and the consumer's bindings | Buffers — in shared memory, or dma-bufs from a GPU allocator — that are never handed out while the compositor holds them; a presenter that puts them on a `wl_surface` at the pace of its frame callbacks, with explicit sync if asked; and linux-dmabuf feedback. Linux only |

The bindings the scanner generates are one more module, built in the
consumer's own build, which imports only `protocol`. Each interface becomes a
struct holding an object id: `wl_surface` is `wl.Surface`, `xdg_toplevel` is
`xdg.Toplevel`. Each has its enums, as open `enum(u32)` types or, for a
bitfield, a `packed struct(u32)` of flags; an `Event` union with a `decode`;
and a method per request, which queues it on a `protocol.Session`. A request
that creates an object returns it, typed, and `wl_registry.bind` takes the
type to bind as a parameter.

## Usage

```console
$ zig fetch --save git+https://git.jcollie.dev/jeff/zig-wayland-native.git
```

In `build.zig`, `addProtocols` runs the scanner over the core protocol,
`xdg-shell`, and whatever else is asked for, and returns the bindings as a
module:

```zig
const wayland = @import("wayland");

const wayland_dep = b.dependency("wayland", .{});
const protocols = wayland.addProtocols(b, wayland_dep, .{
    .target = target,
    .optimize = optimize,
    .extra = &.{
        wayland_dep.namedLazyPath("wayland-protocols").path(b, "staging/fractional-scale/fractional-scale-v1.xml"),
    },
});
exe.root_module.addImport("wayland-protocols", protocols);
exe.root_module.addImport("wayland-client", wayland_dep.module("client"));
```

and, to draw into shared memory and present it, `addPresent` builds the
`present` module against those same bindings, so that its `wl.Buffer` and
`wl.Surface` are the consumer's types rather than a copy of them:

```zig
exe.root_module.addImport("wayland-present", wayland.addPresent(b, wayland_dep, protocols));
```

and then:

```zig
const std = @import("std");
const Connection = @import("wayland-client").Connection;
const wl = @import("wayland-protocols").wl;

pub fn main(init: std.process.Init) !void {
    var conn: Connection = try .connect(init.gpa, init.io, init.environ_map);
    defer conn.deinit();

    const display: wl.Display = .{ .id = .display };
    const registry = try display.getRegistry(&conn.session);
    try conn.setListener(registry, {}, onRegistryEvent);
    try conn.roundtrip();
}

fn onRegistryEvent(_: void, _: *Connection, _: wl.Registry, event: wl.Registry.Event) void {
    switch (event) {
        .global => |g| std.debug.print("{s} v{d}\n", .{ g.interface, g.version }),
        .global_remove => {},
    }
}
```

`examples/globals.zig` is that, and `examples/window.zig` puts an
`xdg_toplevel` on the screen with a moving gradient, drawn by the CPU into
buffers from the `present` module. `examples/dmabuf.zig` does the same with
dma-bufs made from memfds through `/dev/udmabuf`, which needs a compositor
with a GPU renderer and access to that device. With `--explicit-sync` it
gives each buffer a DRM syncobj timeline, made with the kernel's syncobj
ioctls on the compositor's render node, signals acquire points from the CPU,
and waits on release points; still no GPU API anywhere:

```console
$ zig build run-globals
$ zig build run-window
$ zig build run-dmabuf
$ zig build run-dmabuf -- --explicit-sync
```

`window` and `dmabuf` run until the window is closed, or take `--frames N`
to exit once the compositor has N frames.

### Presenting frames

`present` does not care what drew the pixels. A CPU renderer draws straight
into the mapped memory; a GPU renderer that renders off-screen and reads back
copies what it read. The loop is:

```zig
const shm = try present.Shm.create(gpa, &conn, wl_shm);
try conn.roundtrip(); // wl_shm announces its formats
const pool = try present.BufferPool.create(gpa, &conn, shm, .{});
const presenter = try present.Presenter.create(gpa, &conn, surface);

while (running) {
    if (presenter.ready()) {
        if (try pool.acquire(width, height, .xrgb8888)) |buffer| {
            draw(buffer.pixels(), buffer.stride);
            try presenter.present(buffer, .{ .damage = &.{changed}, .scale = 2 });
        }
    }
    _ = try conn.dispatch();
}
```

- `BufferPool.acquire` hands out a buffer the compositor is not using, or
  null when every buffer is busy and `Options.max_buffers` (three) are made.
  Asking for another size or format is a resize: free buffers of the old
  shape are destroyed, busy ones when the compositor releases them.
- `Presenter.present` attaches, sets the buffer scale when it changes,
  damages with `damage_buffer` (or `damage` in surface coordinates before
  `wl_surface` version 4), commits, and flushes. `ready` is false until the
  compositor answers the frame callback, and `on_frame` is called when it
  does.
- Formats are DRM fourcc codes, as `present.Format`, the same values
  whether a buffer is in shared memory or a dma-buf.

### dma-buf and explicit sync

A GPU renderer that exports its images hands them to the compositor with no
copy through the same `acquire` and `present`. It needs two more protocols in
the bindings, passed to `addProtocols` in `extra`:
`stable/linux-dmabuf/linux-dmabuf-v1.xml` and
`staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml`, under the
`wayland-protocols` lazy path. Without them `present` still compiles, and
`present.has_dmabuf` and `present.has_syncobj` are false.

- `present.Dmabuf` takes over a bound `zwp_linux_dmabuf_v1`. From version 4
  it reads the default feedback: the main device, the format table, and the
  tranches of format and modifier pairs in the compositor's order of
  preference. `modifiers(gpa, format)` gives them in that order, in a slice
  the caller owns. At version 3 it reads the `modifier` events instead, and
  `mainDevice()` is null, because such a compositor never says.
- `present.Feedback` holds one answer: `feedback()` is the default one, and
  `surfaceFeedback` makes one surface's own. A new batch mid-session
  replaces the old one whole, sets `changed`, and calls `on_change`.
- `BufferPool.createDmabuf` takes a `Dmabuf.BufferAllocator`: `allocate` is
  offered the compositor's modifiers for the format and returns up to four
  planes, and `free` gets its handle back when the pool retires the buffer.
  The pool builds the `wl_buffer` with `zwp_linux_buffer_params_v1`'s
  asynchronous `create`, so a refusal is `error.BufferCreationFailed` rather
  than a protocol error. The plane descriptors stay the allocator's: sent
  and flushed before `acquire` returns, never closed by the pool.
- `present.Syncobj` imports DRM syncobj timelines, and
  `Presenter.enableExplicitSync` turns explicit sync on for a surface. From
  then on every `present` needs `.sync`, an acquire and a release point,
  and only a dma-buf may be presented — the protocol would end the
  connection over either, so `present` refuses first. The compositor no
  longer promises `wl_buffer.release` then, and the consumer calls
  `BufferPool.released` once the release point has signalled.

### Where the protocol XML comes from

The Zig build system fetches it. The `wayland` and `wayland-protocols`
release tarballs are dependencies in `build.zig.zon`, pinned by hash like any
other package, so nothing is read from the system and the build is the same
everywhere. A consumer reaches them through two named lazy paths:
`wayland-core`, the directory holding `wayland.xml`, and `wayland-protocols`,
the root of that release. A protocol file of the consumer's own is any
`LazyPath`.

## Design

**The protocol has no I/O in it.** `protocol.Session` takes bytes and file
descriptors in and hands events out; it queues requests as bytes and
descriptors for somebody else to send. It cannot even close a descriptor.
That is what lets every part of the protocol be tested with byte slices, and
it leaves `client` with nothing but the socket.

**Ownership of file descriptors is explicit.** A descriptor passed to a
request is borrowed until it has been sent — `Connection.flush` — and the
caller closes it afterwards. A descriptor in an event belongs to the listener
that receives it. One in an event nobody is listening for, or one addressed
to an object already destroyed, is closed by the connection.

**Ids are not reused early.** An object the client destroys stays a zombie
until the compositor confirms with `delete_id`, so that events already on
their way to it are recognized and dropped rather than delivered to whatever
took the id next. A listener lives in the object's entry and goes with it.

**The input is hostile.** Every length the compositor sends is checked
against what arrived before it is used; a server id out of sequence is
refused rather than allocated up to; a malformed message fails the session
with an error, never a panic.

**The standard library's `sendmsg` cannot be used.** `std.Io.net` can carry
ancillary data, but always names a destination address, and Linux refuses one
on a connected stream socket with `EISCONN`. The socket is connected through
`std.Io.net` and then read and written with `sendmsg(2)` and `recvmsg(2)`
directly, which is why `client` is Linux-only.

**libwayland's limits are kept.** A message is at most 4096 bytes, and one
`sendmsg` carries at most 28 descriptors, split at a message boundary when
more are queued, because a compositor built on libwayland accepts no more.

## Testing

```console
$ zig build test
$ ./tools/headless.sh
```

`zig build test` runs the modules' own tests and the suites beside them:

- `tests/bindings.zig` drives the generated core and `xdg-shell` bindings
  through a session with no socket, checking requests as the bytes they
  become.
- `tests/client.zig` plays the compositor at the other end of a socketpair:
  globals, a round trip, descriptors in both directions — including more than
  one `sendmsg` carries — protocol errors, and a compositor that goes away.
- `tests/present.zig` does the same for presentation: formats, the pixels
  the compositor maps, buffers held and released, resizing, damage and
  scale, and frame pacing.
- `tests/dmabuf.zig`: linux-dmabuf feedback read from a real format table
  and replaced mid-session, the version 3 fallback, the params requests
  byte for byte down to the modifier's split and the plane order, a refused
  buffer, and the rules of explicit sync.
- The generated bindings themselves, for the default set and for every
  protocol in the wayland-protocols release at once — the real test of the
  scanner.
- The documentation server in `tools/docs_server.zig`.

`present`'s own tests run twice, built against bindings with and without
linux-dmabuf and linux-drm-syncobj, so that neither configuration can stop
compiling unnoticed.

Zig analyses only what is referenced, so a binding nobody calls could fail
to compile unnoticed. Every generated file therefore ends with a test that
walks all of its declarations, and it runs whenever the bindings are a test's
root module. A consumer gets the same check for the protocols it generated:

```zig
const protocols_test = b.addTest(.{ .root_module = protocols });
test_step.dependOn(&b.addRunArtifact(protocols_test).step);
```

`tools/headless.sh` runs the examples against a headless weston, from the
devshell — the window for ten frames — so that the client meets a real
compositor without a display. Where `/dev/udmabuf` and a render node are
available it runs the dma-buf example under weston's GL renderer as well,
and then with explicit sync under a headless sway on GLES, which offers
`wp_linux_drm_syncobj_manager_v1` where headless weston does not: sixty
frames from two buffers, which only works if the compositor signals the
release points. Each of those stages says so when it is skipped, as it is on
a runner with no GPU.

## Documentation

```console
$ zig build docs         # into zig-out/docs
$ zig build docs-serve   # and read it at http://127.0.0.1:8000
```

It has to be served rather than opened: the viewer fetches its sources and its
WebAssembly at runtime, which a browser refuses to do from a `file://` page.

## Repository

The repository's home is my Forgejo instance at
[git.jcollie.dev/jeff/zig-wayland-native](https://git.jcollie.dev/jeff/zig-wayland-native),
which is where CI runs.

```console
$ git clone https://git.jcollie.dev/jeff/zig-wayland-native.git
```

It is mirrored on Tangled at <https://tangled.org/jcollie.dev/zig-wayland-native>,
and it is also published on [Radicle][radicle], a peer-to-peer forge built on
git, where the copy needs no account and no server anyone has to keep running.
The repository's identifier there is

```
rad:z2YrD81MUHEHzo5WW2AZh9Kyo1TJH
```

and this fetches it:

```console
$ rad clone rad:z2YrD81MUHEHzo5WW2AZh9Kyo1TJH
```

Any of the three is the whole project, on the `main` branch, with the same
history.

`rad clone` finds seeds through your local node's routing table rather than
through a known host, so the node has to be running before it can find
anything:

```console
$ rad node start
```

If you already have the repository and only want to help host it, seeding it
tells your node to carry a copy for others:

```console
$ rad seed rad:z2YrD81MUHEHzo5WW2AZh9Kyo1TJH
```

[radicle]: https://radicle.xyz

## Issues and contributions

Report issues and send pull requests on the Tangled mirror,
<https://tangled.org/jcollie.dev/zig-wayland-native>.
[CONTRIBUTING.md](CONTRIBUTING.md) covers building, testing, and what a
change is expected to pass.

## License

MIT, and [REUSE](https://reuse.software/) compliant: `reuse lint` passes.

[zxml]: https://git.jcollie.dev/jeff/zxml

## References cited

- The Linux man-pages project. *cmsg(3) — access ancillary
  data*. Linux manual pages. <https://man7.org/linux/man-pages/man3/cmsg.3.html>
- The Linux man-pages project. *memfd_create(2) — create an anonymous file*.
  Linux manual pages. <https://man7.org/linux/man-pages/man2/memfd_create.2.html>
- The Linux man-pages project. *recvmsg(2) — receive a message from a
  socket*. Linux manual pages. <https://man7.org/linux/man-pages/man2/recvmsg.2.html>
- The Linux man-pages project. *sendmsg(2) — send a message on a socket*.
  Linux manual pages. <https://man7.org/linux/man-pages/man2/sendmsg.2.html>
- The Linux man-pages project. *unix(7) — sockets for local interprocess
  communication*. Linux manual pages. <https://man7.org/linux/man-pages/man7/unix.7.html>
- The Linux kernel developers. *Buffer Sharing and Synchronization
  (dma-buf)*. The Linux Kernel documentation.
  <https://docs.kernel.org/driver-api/dma-buf.html>
- The Linux kernel developers. *drm.h*. Linux kernel source.
  <https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/drm/drm.h>
- The Linux kernel developers. *drm_fourcc.h*. Linux kernel source.
  <https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/drm/drm_fourcc.h>
- The Linux kernel developers. *udmabuf.h*. Linux kernel source.
  <https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/udmabuf.h>
- Ollie, J. C. *zxml* [Computer software]. <https://git.jcollie.dev/jeff/zxml>
- The Wayland project. *The Wayland Protocol*. Wayland.
  <https://wayland.freedesktop.org/docs/book/>
- The Wayland project. *Wire Format*. In *The Wayland Protocol*.
  <https://wayland.freedesktop.org/docs/book/Protocol.html#wire-format>
- The Wayland project. *Wayland* (Version 1.26.0) [Computer software].
  freedesktop.org. <https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.26.0/downloads/wayland-1.26.0.tar.xz>
- The Wayland project. *wayland-protocols* (Version 1.49) [Computer software].
  freedesktop.org. <https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.49/downloads/wayland-protocols-1.49.tar.xz>
