Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Apps Provider

## What

Provides application launch candidates from a cache or desktop-file scan.

## Why

App launch is the core launcher behavior and must remain available even if a
cache is stale or missing.

## How

- implementation:
  [src/providers/apps.zig](../../src/providers/apps.zig)
- cached source:
  `~/.cache/waybar/wofi-app-launcher.tsv`
- fallback:
  desktop-file scan across application roots

It owns short-lived copied strings across collections so result candidates do not
reference invalid buffers.

## When

Use this provider for application discovery and launch rows. Do not reuse it as
a generic file or package search provider.

## Where

- [src/providers/apps.zig](../../src/providers/apps.zig)
