// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! What the wire needs to know about one interface: its name, the newest
//! version this side understands, and the argument types of every request and
//! event, in opcode order.
//!
//! The wire format is not self-describing -- a message is an object id, an
//! opcode, and a run of 32-bit words -- so these signatures are the only way to
//! tell where one argument ends and the next begins, and how many file
//! descriptors a message carries out of band. The scanner writes one of these
//! for every interface it generates; `core` has the three that `Session`
//! itself cannot do without.

const Interface = @This();

/// The name the compositor advertises it under, such as `wl_surface`. It is
/// what `wl_registry.bind` sends, so it is kept with its terminator.
name: [:0]const u8,
/// The newest version described here. Binding a global at a newer version
/// than this would promise the compositor messages nothing here can decode.
version: u32,
/// Indexed by opcode.
requests: []const Signature,
/// Indexed by opcode.
events: []const Signature,

/// One request or event.
pub const Signature = struct {
    name: []const u8,
    /// The first version of the interface to have this message.
    since: u32 = 1,
    /// Sending (for a request) or receiving (for an event) this message ends
    /// the object's life.
    destructor: bool = false,
    /// In wire order. A `new_id` with no interface -- `wl_registry.bind` is
    /// the one everybody meets -- is already expanded here into the string,
    /// uint and new_id that the wire actually carries.
    args: []const Arg = &.{},

    /// How many file descriptors a message of this shape carries out of band.
    pub fn fdCount(sig: Signature) usize {
        var n: usize = 0;
        for (sig.args) |arg| {
            if (arg.kind == .fd) n += 1;
        }
        return n;
    }
};

/// The type of one argument.
pub const Arg = struct {
    kind: Kind,
    /// Only meaningful for `string`, `object` and `array`, the kinds whose
    /// wire form has a way to say "nothing".
    nullable: bool = false,
    /// For `object` and `new_id`, the interface the object is expected to
    /// have, when the protocol says. A `new_id` in an event must have one:
    /// the object it creates would otherwise be one nobody can decode.
    interface: ?*const Interface = null,
};

/// The eight wire types.
pub const Kind = enum {
    int,
    uint,
    fixed,
    string,
    object,
    new_id,
    array,
    fd,
};
