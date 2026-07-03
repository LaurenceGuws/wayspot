//! Placement primitives define persisted window anchors and margins.

pub const Anchor = enum {
    center,
    top_left,
    top_center,
    top_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const Geometry = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const Margins = struct {
    left: i32 = 0,
    right: i32 = 0,
    top: i32 = 0,
    bottom: i32 = 0,
};
