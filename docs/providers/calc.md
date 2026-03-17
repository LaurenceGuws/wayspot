Status: active
Owner: search
Last-Reviewed: 2026-03-17
Canonical: yes

# Calculator Route

## What

The calculator subsystem evaluates `=` route expressions and formats results.

## Why

Calculator behavior is pure query-time evaluation and does not need a registry
provider.

## How

- implementation:
  [src/providers/calc.zig](/home/home/personal/wayspot/src/providers/calc.zig)

It currently supports:

- arithmetic precedence
- unary operators
- parentheses
- decimal and exponent notation

## When

Use this subsystem for route-scoped expression evaluation only.

## Where

- [src/providers/calc.zig](/home/home/personal/wayspot/src/providers/calc.zig)
