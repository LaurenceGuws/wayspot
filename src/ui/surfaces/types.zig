//! Surface settings define how the picker window should be presented.

const std = @import("std");

pub const SurfaceMode = enum {
    toplevel,
    layer_shell,

    /// parse accepts command/config spellings for the surface mode.
    pub fn parse(raw: []const u8) ?SurfaceMode {
        if (std.ascii.eqlIgnoreCase(raw, "toplevel")) return .toplevel;
        if (std.ascii.eqlIgnoreCase(raw, "layer-shell")) return .layer_shell;
        if (std.ascii.eqlIgnoreCase(raw, "layer_shell")) return .layer_shell;
        return null;
    }
};
