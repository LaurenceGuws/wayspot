// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");

/// Generates bindings for the core protocol, `xdg-shell`, and whatever
/// `extra` protocol files are given, and returns them as a module that
/// imports this package's `protocol` module. From a consumer's `build.zig`:
///
/// ```zig
/// const wayland = @import("wayland");
///
/// const wayland_dep = b.dependency("wayland", .{});
/// const protocols = wayland.addProtocols(b, wayland_dep, .{
///     .target = target,
///     .optimize = optimize,
///     .extra = &.{
///         wayland_dep.namedLazyPath("wayland-protocols").path(b, "staging/fractional-scale/fractional-scale-v1.xml"),
///     },
/// });
/// exe.root_module.addImport("wayland-protocols", protocols);
/// exe.root_module.addImport("wayland-client", wayland_dep.module("client"));
/// ```
///
/// The generated file ends with a test that analyses every declaration in
/// it, so `b.addTest(.{ .root_module = protocols })` checks that every
/// binding compiles, not only the ones the program calls. That needs the
/// module to have a target, which is what `target` is for; a module that is
/// only ever imported can leave it out and take its importer's.
///
/// The `wayland-protocols` release this package depends on is available as
/// that named lazy path, and the core protocol's directory as
/// `wayland-core`; a protocol file of the consumer's own is any `LazyPath`.
pub fn addProtocols(b: *std.Build, wayland_dep: *std.Build.Dependency, options: ProtocolOptions) *std.Build.Module {
    return generate(
        b,
        wayland_dep.artifact("wayland-scanner"),
        wayland_dep.module("protocol"),
        &.{
            wayland_dep.namedLazyPath("wayland-core").path(b, "wayland.xml"),
            wayland_dep.namedLazyPath("wayland-protocols").path(b, "stable/xdg-shell/xdg-shell.xml"),
        },
        options,
    );
}

pub const ProtocolOptions = struct {
    /// Protocol files to generate bindings for beside the default two.
    extra: []const std.Build.LazyPath = &.{},
    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
};

fn generate(
    b: *std.Build,
    scanner: *std.Build.Step.Compile,
    protocol: *std.Build.Module,
    base: []const std.Build.LazyPath,
    options: ProtocolOptions,
) *std.Build.Module {
    const run = b.addRunArtifact(scanner);
    const output = run.addOutputFileArg("wayland_protocols.zig");
    for (base) |path| run.addFileArg(path);
    for (options.extra) |path| run.addFileArg(path);
    return b.createModule(.{
        .root_source_file = output,
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{.{ .name = "protocol", .module = protocol }},
    });
}

/// The `present` module -- buffers in shared memory and a presenter for a
/// `wl_surface` -- wired to `protocols`, the bindings `addProtocols` made.
/// It has to be wired to the consumer's bindings rather than making its own,
/// or its `wl.Buffer` and `wl.Surface` would be different types from the
/// consumer's. It takes the target and optimize mode `protocols` was given.
///
/// ```zig
/// const present = wayland.addPresent(b, wayland_dep, protocols);
/// exe.root_module.addImport("wayland-present", present);
/// ```
pub fn addPresent(b: *std.Build, wayland_dep: *std.Build.Dependency, protocols: *std.Build.Module) *std.Build.Module {
    return presentModule(
        b,
        wayland_dep.path("src/present/root.zig"),
        wayland_dep.module("protocol"),
        wayland_dep.module("client"),
        protocols,
    );
}

fn presentModule(
    b: *std.Build,
    root: std.Build.LazyPath,
    protocol: *std.Build.Module,
    client: *std.Build.Module,
    protocols: *std.Build.Module,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = root,
        .target = protocols.resolved_target,
        .optimize = protocols.optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol },
            .{ .name = "client", .module = client },
            .{ .name = "wayland-protocols", .module = protocols },
        },
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zxml = b.dependency("zxml", .{ .target = b.graph.host, .optimize = .ReleaseSafe });
    const wayland_xml = b.dependency("wayland_xml", .{});
    const wayland_protocols = b.dependency("wayland_protocols", .{});
    b.addNamedLazyPath("wayland-core", wayland_xml.path("protocol"));
    b.addNamedLazyPath("wayland-protocols", wayland_protocols.path("."));

    // -- modules -------------------------------------------------------------
    //
    // Three, each depending only on the one before: the scanner knows XML and
    // nothing about the wire; `protocol` knows the wire and nothing about
    // sockets; `client` knows sockets and hands the wire to `protocol`. A
    // fourth, `present`, is built against whichever generated bindings it is
    // given; see `addPresent`.

    const scanner = b.addModule("scanner", .{
        .root_source_file = b.path("src/scanner/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zxml", .module = zxml.module("zxml") }},
    });

    const protocol = b.addModule("protocol", .{
        .root_source_file = b.path("src/protocol/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const client = b.addModule("client", .{
        .root_source_file = b.path("src/client/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "protocol", .module = protocol }},
    });

    // The scanner as a command, which is what the build runs. Always built
    // for the machine running the build, never for -Dtarget.
    const scanner_exe = b.addExecutable(.{
        .name = "wayland-scanner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/scanner.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
            .imports = &.{.{
                .name = "scanner",
                .module = b.createModule(.{
                    .root_source_file = b.path("src/scanner/root.zig"),
                    .target = b.graph.host,
                    .optimize = .ReleaseSafe,
                    .imports = &.{.{ .name = "zxml", .module = zxml.module("zxml") }},
                }),
            }},
        }),
    });
    b.installArtifact(scanner_exe);

    const default_xml: []const std.Build.LazyPath = &.{
        wayland_xml.path("protocol/wayland.xml"),
        wayland_protocols.path("stable/xdg-shell/xdg-shell.xml"),
    };
    // The bindings the tests and examples use: the default two, and the two
    // that `present`'s dma-buf and explicit sync support need.
    const bindings = generate(b, scanner_exe, protocol, default_xml, .{
        .target = target,
        .optimize = optimize,
        .extra = &.{
            wayland_protocols.path("stable/linux-dmabuf/linux-dmabuf-v1.xml"),
            wayland_protocols.path("staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml"),
        },
    });
    const present = presentModule(b, b.path("src/present/root.zig"), protocol, client, bindings);
    // And built against the default two alone, as a consumer who never asked
    // for dma-buf has it, so that nothing reaches for an interface that is not
    // there.
    const minimal_bindings = generate(b, scanner_exe, protocol, default_xml, .{ .target = target, .optimize = optimize });
    const present_minimal = presentModule(b, b.path("src/present/root.zig"), protocol, client, minimal_bindings);

    // -- tests ---------------------------------------------------------------

    const test_step = b.step("test", "Run tests");
    const check_step = b.step("check", "Compile everything without running it");

    for ([_]*std.Build.Module{ scanner, protocol, client, present, present_minimal }) |module| {
        const t = b.addTest(.{ .root_module = module });
        test_step.dependOn(&b.addRunArtifact(t).step);
        check_step.dependOn(&t.step);
    }

    // The generated bindings, exercised against a session with no socket.
    const bindings_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/bindings.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol },
            .{ .name = "wayland-protocols", .module = bindings },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(bindings_tests).step);

    // The client over a socketpair, with a fake compositor at the other end.
    const client_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol },
            .{ .name = "client", .module = client },
            .{ .name = "wayland-protocols", .module = bindings },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(client_tests).step);

    // Presentation, with the same fake compositor.
    const present_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/present.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol },
            .{ .name = "client", .module = client },
            .{ .name = "present", .module = present },
            .{ .name = "wayland-protocols", .module = bindings },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(present_tests).step);

    // dma-buf and explicit sync, with the same fake compositor.
    const dmabuf_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/dmabuf.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol },
            .{ .name = "client", .module = client },
            .{ .name = "present", .module = present },
            .{ .name = "wayland-protocols", .module = bindings },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(dmabuf_tests).step);

    // The generated bindings carry a test that analyses every declaration in
    // them, which runs when they are a test's root module. For the default
    // set, and for every protocol in the wayland-protocols release at once,
    // which is the real test of the scanner: several hundred interfaces
    // written by many hands, every one of which has to come out as Zig that
    // compiles.
    const everything = generate(b, scanner_exe, protocol, &.{wayland_xml.path("protocol/wayland.xml")}, .{
        .extra = allProtocols(b, wayland_protocols),
        .target = target,
        .optimize = optimize,
    });
    for ([_]*std.Build.Module{ bindings, everything }) |module| {
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    }

    // -- examples ------------------------------------------------------------

    for ([_][]const u8{ "globals", "window", "dmabuf" }) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "protocol", .module = protocol },
                    .{ .name = "client", .module = client },
                    .{ .name = "present", .module = present },
                    .{ .name = "wayland-protocols", .module = bindings },
                },
            }),
        });
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        run.addPassthruArgs();
        const run_step = b.step(b.fmt("run-{s}", .{name}), b.fmt("Run the {s} example", .{name}));
        run_step.dependOn(&run.step);
        check_step.dependOn(&exe.step);
    }

    // -- documentation -------------------------------------------------------
    //
    // Zig emits the API documentation as a side effect of compiling, so each
    // module is built as a library purely to get at it, one bundle per module
    // under zig-out/docs, with an index linking them.

    // The bundles and the index are gathered into one directory first, so
    // that the docs server can be handed it: 0.17 cannot name an install
    // path while configuring.
    const docs_tree = b.addWriteFiles();
    _ = docs_tree.addCopyFile(b.path("tools/docs_index.html"), "index.html");
    for ([_]struct { []const u8, *std.Build.Module }{
        .{ "scanner", scanner },
        .{ "protocol", protocol },
        .{ "client", client },
        .{ "present", present },
    }) |entry| {
        const name, const module = entry;
        const library = b.addLibrary(.{ .name = name, .root_module = module });
        _ = docs_tree.addCopyDirectory(library.getEmittedDocs(), name, .{});
    }
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_tree.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Build the API documentation into zig-out/docs");
    docs_step.dependOn(&install_docs.step);

    // That viewer fetches `sources.tar` and `main.wasm` at runtime, which a
    // browser refuses to do from a `file://` page, so reading the docs
    // locally means serving them.
    const docs_port = b.option(u16, "docs-port", "Port for `zig build docs-serve` (default 8000)") orelse 8000;

    const docs_server = b.addExecutable(.{
        .name = "docs-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/docs_server.zig"),
            // Always built for the machine running the build, never for
            // whatever -Dtarget the library is being built for.
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_docs_server = b.addRunArtifact(docs_server);
    run_docs_server.addDirectoryArg(docs_tree.getDirectory());
    run_docs_server.addArg(b.fmt("{d}", .{docs_port}));
    // The server runs until interrupted, so its output has to reach the
    // terminal rather than being captured by the build runner.
    run_docs_server.stdio = .inherit;

    const docs_serve_step = b.step("docs-serve", "Serve the API documentation over HTTP");
    docs_serve_step.dependOn(&run_docs_server.step);

    // The server has tests of its own; without this they would never run.
    test_step.dependOn(&b.addRunArtifact(
        b.addTest(.{ .root_module = docs_server.root_module }),
    ).step);
    check_step.dependOn(&docs_server.step);
}

/// Every protocol file in a wayland-protocols tree, sorted so the generated
/// file is the same from one run to the next.
///
/// Three files are left out because they define interfaces another file
/// defines under the same name, and one set of bindings cannot hold both:
/// `unstable/linux-dmabuf` and `unstable/tablet`'s v2 are the stable
/// protocols from before they were declared stable, and xdg-shell's
/// unstable v5 used the names the stable one later took.
fn allProtocols(b: *std.Build, dep: *std.Build.Dependency) []const std.Build.LazyPath {
    const io = b.graph.io;
    // Read while configuring, which needs no `dependOnDirectoryContents`:
    // the tree is a fetched package, named by the hash of its contents.
    var dir = dep.builder.root.root_dir.handle.openDir(io, ".", .{ .iterate = true }) catch |e|
        std.debug.panic("cannot open the wayland-protocols tree: {t}", .{e});
    defer dir.close(io);
    var walker = dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();

    var paths: std.ArrayList([]const u8) = .empty;
    while (walker.next(io) catch |e| std.debug.panic("cannot walk the wayland-protocols tree: {t}", .{e})) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".xml")) continue;
        if (!(std.mem.startsWith(u8, entry.path, "stable/") or
            std.mem.startsWith(u8, entry.path, "staging/") or
            std.mem.startsWith(u8, entry.path, "unstable/"))) continue;
        if (std.mem.startsWith(u8, entry.path, "unstable/linux-dmabuf/")) continue;
        if (std.mem.eql(u8, entry.path, "unstable/tablet/tablet-unstable-v2.xml")) continue;
        if (std.mem.eql(u8, entry.path, "unstable/xdg-shell/xdg-shell-unstable-v5.xml")) continue;
        paths.append(b.allocator, b.dupe(entry.path)) catch @panic("OOM");
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, a: []const u8, c: []const u8) bool {
            return std.mem.order(u8, a, c) == .lt;
        }
    }.lessThan);

    const result = b.allocator.alloc(std.Build.LazyPath, paths.items.len) catch @panic("OOM");
    for (paths.items, result) |path, *lp| lp.* = dep.path(path);
    return result;
}
