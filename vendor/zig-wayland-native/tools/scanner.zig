// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! The scanner as a command, for the build to run:
//!
//!     scanner OUTPUT.zig PROTOCOL.xml...
//!
//! Every protocol named goes into the one output file, so that interfaces can
//! refer to each other across them.

const std = @import("std");
const scanner = @import("scanner");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 3) {
        std.log.err("usage: {s} OUTPUT.zig PROTOCOL.xml...", .{if (args.len > 0) args[0] else "scanner"});
        std.process.exit(2);
    }

    var diagnostic: scanner.Diagnostic = .{};
    const protocols = try arena.alloc(scanner.model.Protocol, args.len - 2);
    for (args[2..], protocols) |path, *protocol| {
        const xml = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)) catch |e| {
            std.log.err("{s}: {t}", .{ path, e });
            std.process.exit(1);
        };
        protocol.* = scanner.parse(arena, xml, &diagnostic) catch |e| {
            if (e == error.InvalidProtocol)
                std.log.err("{s}: {s}", .{ path, diagnostic.message() })
            else
                std.log.err("{s}: {t}", .{ path, e });
            std.process.exit(1);
        };
    }

    const source = scanner.render(arena, protocols, &diagnostic) catch |e| {
        if (e == error.InvalidProtocol) std.log.err("{s}", .{diagnostic.message()}) else std.log.err("{t}", .{e});
        std.process.exit(1);
    };
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = args[1], .data = source });
}
