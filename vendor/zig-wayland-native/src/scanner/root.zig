// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Turns Wayland protocol descriptions into Zig bindings.
//!
//! `parse` reads one XML file into a `model.Protocol`; `render` writes Zig for
//! a set of them at once, so that an interface in one protocol can name one
//! in another -- `xdg_surface.get_toplevel` taking a `wl_surface`, say. The
//! output imports a module named `protocol`, which is this package's
//! `protocol` module, and nothing else.
//!
//! `tools/scanner.zig` is the command-line wrapper the build uses; see
//! `addProtocols` in `build.zig` for the usual way in.

const parse_ = @import("parse.zig");
const render_ = @import("render.zig");

pub const model = @import("model.zig");
pub const parse = parse_.parse;
pub const ParseError = parse_.Error;
pub const render = render_.render;
pub const RenderError = render_.Error;
pub const Diagnostic = parse_.Diagnostic;

test {
    _ = parse_;
    _ = render_;
}
