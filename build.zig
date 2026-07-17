const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sdl = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
    });

    const wayspot_beta = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wayspot_beta.addIncludePath(sdl.path("include"));
    wayspot_beta.linkLibrary(sdl.artifact("SDL3"));

    const executable = b.addExecutable(.{
        .name = "wayspot-beta",
        .root_module = wayspot_beta,
    });
    executable.use_llvm = true;
    executable.use_lld = true;
    b.installArtifact(executable);

    const tests = b.addTest(.{ .root_module = wayspot_beta });
    tests.use_llvm = true;
    tests.use_lld = true;
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Wayspot beta tests");
    test_step.dependOn(&run_tests.step);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run Wayspot beta");
    run_step.dependOn(&run.step);
}
