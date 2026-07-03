const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const app_version = b.option([]const u8, "app_version", "Wayspot application version string") orelse "0.1.3-dev";
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_sdl", true);
    build_options.addOption([]const u8, "app_version", app_version);
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
    });
    const sdl_include = sdl_dep.path("include");
    const sdl_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c/sdl.h"),
        .target = target,
        .optimize = optimize,
    });
    sdl_c.addIncludePath(sdl_include);

    const mod = b.addModule("wayspot", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
        .imports = &.{
            .{ .name = "build_options", .module = build_options.createModule() },
        },
    });
    mod.addImport("sdl_c", sdl_c.createModule());
    mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "wayspot", .module = mod },
            .{ .name = "build_options", .module = build_options.createModule() },
        },
    });
    exe_mod.addImport("sdl_c", sdl_c.createModule());
    exe_mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });
    const exe = b.addExecutable(.{
        .name = "wayspot",
        .root_module = exe_mod,
    });
    // Zig 0.16 on Arch currently needs LLVM/LLD for this SDL executable.
    exe.use_llvm = true;
    exe.use_lld = true;
    exe.root_module.addIncludePath(sdl_include);
    exe.root_module.linkLibrary(sdl_dep.artifact("SDL3"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    // The test artifacts mirror the executable backend so SDL stays link-compatible.
    mod_tests.use_llvm = true;
    mod_tests.use_lld = true;
    mod_tests.root_module.addIncludePath(sdl_include);
    mod_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_tests.use_llvm = true;
    exe_tests.use_lld = true;
    exe_tests.root_module.addIncludePath(sdl_include);
    exe_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const regression_tests = b.step("regression_tests", "Run regression tests");
    regression_tests.dependOn(&run_mod_tests.step);
}
