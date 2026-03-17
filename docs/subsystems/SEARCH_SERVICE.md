Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Search Service

## What

`SearchService` is the core search runtime that collects candidates, ranks
results, caches static providers, handles dynamic routes, and tracks query
history.

## Why

It centralizes provider collection and ranking so UI code does not directly
assemble or filter heterogeneous data sources.

## How

- main service:
  [src/app/search_service.zig](/home/home/personal/wayspot/src/app/search_service.zig)
- query engine pieces:
  [src/app/search_service/](/home/home/personal/wayspot/src/app/search_service)
- search contracts:
  [src/search/](/home/home/personal/wayspot/src/search)

Major responsibilities:

- registry-backed provider collection
- route parsing and dispatch
- cached static search snapshots
- dynamic route execution
- history weighting
- async refresh and WM-triggered refresh

## When

Any change to search semantics, ranking, provider assembly, history weighting,
or route dispatch should land here or in `src/search/`, not in GTK widgets.

## Where

- [src/app/search_service.zig](/home/home/personal/wayspot/src/app/search_service.zig)
- [src/search/mod.zig](/home/home/personal/wayspot/src/search/mod.zig)
