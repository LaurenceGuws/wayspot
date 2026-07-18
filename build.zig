const std = @import("std");
const libs = @import("build_libs.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sdl = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
    });
    const text = libs.text(b, target, optimize, sdl.artifact("SDL3"), sdl.path("include"));

    const wayspot_beta = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wayspot_beta.addIncludePath(sdl.path("include"));
    wayspot_beta.addIncludePath(text.include);
    wayspot_beta.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    wayspot_beta.linkLibrary(sdl.artifact("SDL3"));
    wayspot_beta.linkLibrary(text.library);
    wayspot_beta.linkSystemLibrary("dbus-1", .{});

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
    const cmd_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cmd.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_cmd_tests = b.addRunArtifact(cmd_tests);
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
    const notification_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_tests = b.addRunArtifact(notification_tests);
    const notification_dbus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_dbus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_dbus_tests = b.addRunArtifact(notification_dbus_tests);
    const notification_history_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_history.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_history_tests = b.addRunArtifact(notification_history_tests);
    const notification_banner_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_banner.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_banner_tests = b.addRunArtifact(notification_banner_tests);
    const notification_banner_run_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_banner_run.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_banner_run_tests = b.addRunArtifact(notification_banner_run_tests);
    const notification_bridge_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_notification_bridge_tests = b.addRunArtifact(notification_bridge_tests);
    const notification_banner_sdl_check = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_banner_sdl.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    notification_banner_sdl_check.root_module.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    notification_banner_sdl_check.root_module.addIncludePath(sdl.path("include"));
    notification_banner_sdl_check.root_module.addIncludePath(text.include);
    notification_banner_sdl_check.root_module.linkLibrary(sdl.artifact("SDL3"));
    notification_banner_sdl_check.root_module.linkLibrary(text.library);
    notification_banner_sdl_check.use_llvm = true;
    notification_banner_sdl_check.use_lld = true;
    const run_notification_banner_sdl_check = b.addRunArtifact(notification_banner_sdl_check);
    const notification_dbus_native_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/notification_dbus_native.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    notification_dbus_native_tests.root_module.linkSystemLibrary("dbus-1", .{});
    notification_dbus_native_tests.use_llvm = true;
    notification_dbus_native_tests.use_lld = true;
    const run_notification_dbus_native_tests = b.addRunArtifact(notification_dbus_native_tests);
    const test_step = b.step("test", "Run Wayspot beta tests");
    test_step.dependOn(&run_picker_tests.step);
    test_step.dependOn(&run_apps_tests.step);
    test_step.dependOn(&run_desktop_files_tests.step);
    test_step.dependOn(&run_transcript_tests.step);
    test_step.dependOn(&run_launch_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_cmd_tests.step);
    test_step.dependOn(&run_icon_tests.step);
    test_step.dependOn(&run_image_tests.step);
    test_step.dependOn(&run_sdl_event_tests.step);
    test_step.dependOn(&run_sdl_pixels_tests.step);
    test_step.dependOn(&run_notification_tests.step);
    test_step.dependOn(&run_notification_dbus_tests.step);
    test_step.dependOn(&run_notification_history_tests.step);
    test_step.dependOn(&run_notification_banner_tests.step);
    test_step.dependOn(&run_notification_banner_run_tests.step);
    test_step.dependOn(&run_notification_bridge_tests.step);
    test_step.dependOn(&run_notification_banner_sdl_check.step);
    test_step.dependOn(&run_notification_dbus_native_tests.step);

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    const run_step = b.step("run", "Run Wayspot beta");
    run_step.dependOn(&run.step);
}
