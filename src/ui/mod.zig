const build_options = @import("build_options");
const std = @import("std");

pub const gtk_enabled = false;
pub const sdl_enabled = build_options.enable_sdl;
pub const placement = @import("placement/mod.zig");
pub const surfaces = @import("surfaces/mod.zig");
pub const Shell = @import("sdl_shell.zig").Shell;

pub const Diagnostics = struct {
    pub fn printOutputs(_: std.mem.Allocator) !void {
        var stdout_buffer: [64]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
        const out = &stdout_writer.interface;
        try out.print("[]\n", .{});
        try out.flush();
    }

    pub fn printShellHealth(_: std.mem.Allocator) !void {
        var stdout_buffer: [256]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
        const out = &stdout_writer.interface;
        try out.print("module=launcher status=ready detail=sdl-shell\n", .{});
        try out.print("module=notifications status=unknown detail=not-wired\n", .{});
        try out.flush();
    }
};
