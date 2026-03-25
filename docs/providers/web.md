Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Web Route Provider

## What

The web subsystem emits route-scoped candidates for `?` queries.

## Why

Web search and bookmark lookup have query-time behavior and external I/O that do
not fit the normal static provider registry model.

## How

- implementation:
  [src/providers/web.zig](../../src/providers/web.zig)
- bookmark support:
  [src/providers/web_bookmarks.zig](../../src/providers/web_bookmarks.zig)
- favicon/cache support:
  [src/providers/web_favicons.zig](../../src/providers/web_favicons.zig),
  [src/providers/web_support.zig](../../src/providers/web_support.zig)

Current capabilities include:

- search-engine dispatch
- bookmark lookup
- scraped result candidates for some search paths
- favicon resolution/caching

## When

Use this subsystem for route-scoped web behavior only. It is intentionally not a
blended provider.

## Where

- [src/providers/web.zig](../../src/providers/web.zig)
