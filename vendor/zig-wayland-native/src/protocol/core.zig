// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The three interfaces a session needs before any bindings exist.
//!
//! `wl_display` is object 1 from the moment the socket connects, and its
//! `error` and `delete_id` events are the session's own business rather than
//! the application's. `wl_callback` is what a round trip waits on, and
//! `wl_registry` is what `wl_display.get_registry` creates. All three have been
//! at version 1 since Wayland 1.0 and are frozen there, so writing them out by
//! hand costs nothing; the generated bindings describe the same interfaces
//! from `wayland.xml`, and a test holds the two to each other.

const Interface = @import("Interface.zig");

pub const display: Interface = .{
    .name = "wl_display",
    .version = 1,
    .requests = &.{
        .{ .name = "sync", .args = &.{.{ .kind = .new_id, .interface = &callback }} },
        .{ .name = "get_registry", .args = &.{.{ .kind = .new_id, .interface = &registry }} },
    },
    .events = &.{
        .{ .name = "error", .args = &.{ .{ .kind = .object }, .{ .kind = .uint }, .{ .kind = .string } } },
        .{ .name = "delete_id", .args = &.{.{ .kind = .uint }} },
    },
};

/// Opcodes of `wl_display`.
pub const display_request = struct {
    pub const sync = 0;
    pub const get_registry = 1;
};
pub const display_event = struct {
    pub const @"error" = 0;
    pub const delete_id = 1;
};

pub const callback: Interface = .{
    .name = "wl_callback",
    .version = 1,
    .requests = &.{},
    .events = &.{
        .{ .name = "done", .destructor = true, .args = &.{.{ .kind = .uint }} },
    },
};

pub const registry: Interface = .{
    .name = "wl_registry",
    .version = 1,
    .requests = &.{
        .{ .name = "bind", .args = &.{
            .{ .kind = .uint },
            .{ .kind = .string },
            .{ .kind = .uint },
            .{ .kind = .new_id },
        } },
    },
    .events = &.{
        .{ .name = "global", .args = &.{ .{ .kind = .uint }, .{ .kind = .string }, .{ .kind = .uint } } },
        .{ .name = "global_remove", .args = &.{.{ .kind = .uint }} },
    },
};
