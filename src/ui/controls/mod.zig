//! Inert UI control mechanics shared by runtime surfaces.
//!
//! This package owns only reusable state transitions and geometry facts.

pub const cursor_blink = @import("cursor_blink.zig");
pub const appearance = @import("appearance.zig");
pub const slider = @import("slider.zig");
pub const textbox = @import("textbox.zig");
