//! Test root for the sunglasses runtime config form.

const std = @import("std");
const form = @import("sunglasses/form.zig");

test {
    std.testing.refAllDecls(form);
}
