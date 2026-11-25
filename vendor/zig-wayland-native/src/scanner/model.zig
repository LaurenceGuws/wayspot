// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! A Wayland protocol description, as `wayland.dtd` lays it out: a protocol
//! holds interfaces, and an interface holds requests, events and enums.
//!
//! Everything is read-only once parsed, and every string belongs to the arena
//! the protocol was parsed into.

pub const Protocol = struct {
    name: []const u8,
    copyright: ?[]const u8 = null,
    description: Description = .{},
    interfaces: []const Interface,
};

/// The `summary` attribute and the text of a `<description>` element, either
/// of which may be missing. The text is kept as written, indentation and all;
/// the renderer decides what to do with it.
pub const Description = struct {
    summary: ?[]const u8 = null,
    text: ?[]const u8 = null,
};

pub const Interface = struct {
    name: []const u8,
    version: u32,
    description: Description = .{},
    requests: []const Message,
    events: []const Message,
    enums: []const Enum,

    pub fn findEnum(i: Interface, name: []const u8) ?*const Enum {
        for (i.enums) |*e| {
            if (std.mem.eql(u8, e.name, name)) return e;
        }
        return null;
    }
};

pub const Message = struct {
    name: []const u8,
    /// `type="destructor"`.
    destructor: bool = false,
    since: u32 = 1,
    deprecated_since: ?u32 = null,
    description: Description = .{},
    args: []const Arg,
};

pub const Arg = struct {
    name: []const u8,
    type: Type,
    description: Description = .{},
    /// For `object` and `new_id`: the interface the object has, if fixed.
    interface: ?[]const u8 = null,
    allow_null: bool = false,
    /// `enum="name"` for an enum of the same interface, or
    /// `enum="interface.name"` for one of another's.
    @"enum": ?[]const u8 = null,

    pub const Type = enum { int, uint, fixed, string, object, new_id, array, fd };
};

pub const Enum = struct {
    name: []const u8,
    since: u32 = 1,
    bitfield: bool = false,
    description: Description = .{},
    entries: []const Entry,
};

pub const Entry = struct {
    name: []const u8,
    value: u32,
    since: u32 = 1,
    deprecated_since: ?u32 = null,
    description: Description = .{},
};

const std = @import("std");
