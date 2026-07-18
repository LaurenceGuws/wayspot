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

    const picker_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/picker.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_picker_tests = b.addRunArtifact(picker_tests);
    const apps_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/apps.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_apps_tests = b.addRunArtifact(apps_tests);
    const desktop_files_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/desktop_files.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_desktop_files_tests = b.addRunArtifact(desktop_files_tests);
    const transcript_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdl_transcript.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_transcript_tests = b.addRunArtifact(transcript_tests);
    const launch_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/launch.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_launch_tests = b.addRunArtifact(launch_tests);
    const cli_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_cli_tests = b.addRunArtifact(cli_tests);
    const icon_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/icon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_icon_tests = b.addRunArtifact(icon_tests);
    const image_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/image.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_image_tests = b.addRunArtifact(image_tests);
    const sdl_event_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdl_event.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_sdl_event_tests = b.addRunArtifact(sdl_event_tests);
    const sdl_pixels_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdl_pixels.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_sdl_pixels_tests = b.addRunArtifact(sdl_pixels_tests);
    const test_step = b.step("test", "Run Wayspot beta tests");
    test_step.dependOn(&run_picker_tests.step);
    test_step.dependOn(&run_apps_tests.step);
    test_step.dependOn(&run_desktop_files_tests.step);
    test_step.dependOn(&run_transcript_tests.step);
    test_step.dependOn(&run_launch_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_icon_tests.step);
    test_step.dependOn(&run_image_tests.step);
    test_step.dependOn(&run_sdl_event_tests.step);
    test_step.dependOn(&run_sdl_pixels_tests.step);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run Wayspot beta");
    run_step.dependOn(&run.step);
}
