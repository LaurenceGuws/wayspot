//! Starts one native Wayspot beta picker process.

const picker = @import("picker.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    var native: sdl.Native = .{};
    try picker.run(&native);
}
