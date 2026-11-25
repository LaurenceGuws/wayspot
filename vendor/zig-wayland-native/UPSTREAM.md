# Vendored zig-wayland-native

Origin: `https://tangled.org/jcollie.dev/zig-wayland-native` at commit
`3348c3af77a09ea1352dc4d71647148a7c2ae5aa`.
Zig package hash: `wayland-0.2.0-cZMvVGnTBADxBjZ0pQy87Y0G28tXppXkOJTlLz75qxH7`.

Imported from the verified package snapshot already used by Snowman. Preserve
upstream MIT notices, package inputs and source. The only code difference is
six raw Linux syscall error checks in `src/client/Connection.zig`,
`src/present/BufferPool.zig` and `src/present/Feedback.zig`: use `linux.errno`
instead of `std.posix.errno`. Zig 0.17 selects libc's errno convention for
`std.posix` in a libc-linked executable. The raw syscall error representation
is not the libc convention, so this is required for Wayspot's linked process.

Retire the local delta when an exact reviewed upstream revision fixes these
checks and passes the libc-linked native-surface regressions. Do not modify
Zig's immutable package cache or depend on a sibling checkout.
