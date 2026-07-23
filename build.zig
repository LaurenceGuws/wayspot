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
    const headers = b.addWriteFiles();
    const sdl_header = headers.add(
        "wayspot-sdl.h",
        "#include <SDL3/SDL.h>\n#include <SDL3_ttf/SDL_ttf.h>\n",
    );
    const sdl_translate = b.addTranslateC(.{
        .root_source_file = sdl_header,
        .target = target,
        .optimize = optimize,
    });
    sdl_translate.addIncludePath(sdl.path("include"));
    sdl_translate.addIncludePath(text.include);
    const sdl_c = sdl_translate.createModule();

    const dbus_header = headers.add("wayspot-dbus.h", "#include <dbus/dbus.h>\n");
    const dbus_translate = b.addTranslateC(.{
        .root_source_file = dbus_header,
        .target = target,
        .optimize = optimize,
    });
    dbus_translate.linkSystemLibrary("dbus-1", .{});
    const dbus_c = dbus_translate.createModule();

    const wayspot = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wayspot.addIncludePath(sdl.path("include"));
    wayspot.addIncludePath(b.path("vendor/stb"));
    wayspot.addCSourceFile(.{ .file = b.path("src/wallpaper_jpeg.c") });
    wayspot.addIncludePath(text.include);
    wayspot.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    wayspot.linkLibrary(sdl.artifact("SDL3"));
    wayspot.linkLibrary(text.library);
    wayspot.linkSystemLibrary("dbus-1", .{});
    const layer_xml = b.path("protocols/wlr-layer-shell-unstable-v1.xml");
    const layer_header = waylandHeader(
        b,
        layer_xml,
        "wlr-layer-shell-unstable-v1",
    );
    const layer_code = waylandCode(b, layer_xml, "wlr-layer-shell-unstable-v1");
    const viewport_header = waylandHeader(b, b.path("protocols/viewporter.xml"), "viewporter");
    const wayland_protocol_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wayland_protocol_module.addIncludePath(layer_header.dirname());
    wayland_protocol_module.addIncludePath(layer_code.dirname());
    wayland_protocol_module.addIncludePath(viewport_header.dirname());
    wayland_protocol_module.addIncludePath(b.path("src"));
    wayland_protocol_module.addCSourceFile(.{ .file = b.path("src/wayland_protocol.c") });
    wayland_protocol_module.linkSystemLibrary("wayland-client", .{});
    const wayland_protocol = b.addLibrary(.{
        .name = "wayspot_wayland_protocol",
        .linkage = .static,
        .root_module = wayland_protocol_module,
    });
    wayspot.linkLibrary(wayland_protocol);
    const wayland_translate = b.addTranslateC(.{
        .root_source_file = b.path("src/wayland_protocol.h"),
        .target = target,
        .optimize = optimize,
    });
    wayland_translate.linkSystemLibrary("wayland-client", .{});
    const wayland_c = wayland_translate.createModule();
    wayspot.addImport("sdl_c", sdl_c);
    wayspot.addImport("dbus_c", dbus_c);
    wayspot.addImport("wayland_c", wayland_c);

    const executable = b.addExecutable(.{
        .name = "wayspot",
        .root_module = wayspot,
    });
    executable.use_llvm = false;
    executable.use_lld = false;
    b.installArtifact(executable);

    const picker_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/picker.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    addNotificationLibraries(b, picker_tests.root_module, sdl, text, sdl_c, dbus_c);
    picker_tests.use_llvm = false;
    picker_tests.use_lld = false;
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
            .link_libc = true,
        }),
    });
    addNotificationLibraries(b, transcript_tests.root_module, sdl, text, sdl_c, dbus_c);
    transcript_tests.use_llvm = false;
    transcript_tests.use_lld = false;
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
    const wallpaper_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wallpaper.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wallpaper_tests = b.addRunArtifact(wallpaper_tests);
    const wallpaper_transcript_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wallpaper_transcript.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wallpaper_transcript_tests = b.addRunArtifact(wallpaper_transcript_tests);
    const wallpaper_native_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wallpaper_native.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    wallpaper_native_tests.root_module.addIncludePath(sdl.path("include"));
    wallpaper_native_tests.root_module.addIncludePath(b.path("vendor/stb"));
    wallpaper_native_tests.root_module.addCSourceFile(.{ .file = b.path("src/wallpaper_jpeg.c") });
    wallpaper_native_tests.root_module.linkLibrary(sdl.artifact("SDL3"));
    wallpaper_native_tests.root_module.linkLibrary(wayland_protocol);
    wallpaper_native_tests.root_module.addImport("sdl_c", sdl_c);
    wallpaper_native_tests.root_module.addImport("wayland_c", wayland_c);
    wallpaper_native_tests.use_llvm = false;
    wallpaper_native_tests.use_lld = false;
    const run_wallpaper_native_tests = b.addRunArtifact(wallpaper_native_tests);
    const sdl_event_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdl_event.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_sdl_event_tests = b.addRunArtifact(sdl_event_tests);
    const sdl_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sdl.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    sdl_tests.root_module.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    sdl_tests.root_module.addIncludePath(sdl.path("include"));
    sdl_tests.root_module.addIncludePath(text.include);
    sdl_tests.root_module.linkLibrary(sdl.artifact("SDL3"));
    sdl_tests.root_module.linkLibrary(text.library);
    sdl_tests.root_module.linkSystemLibrary("dbus-1", .{});
    sdl_tests.root_module.addImport("sdl_c", sdl_c);
    sdl_tests.root_module.addImport("dbus_c", dbus_c);
    sdl_tests.use_llvm = false;
    sdl_tests.use_lld = false;
    const run_sdl_tests = b.addRunArtifact(sdl_tests);
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
            .link_libc = true,
        }),
    });
    notification_tests.root_module.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    notification_tests.root_module.addIncludePath(sdl.path("include"));
    notification_tests.root_module.addIncludePath(text.include);
    notification_tests.root_module.linkLibrary(sdl.artifact("SDL3"));
    notification_tests.root_module.linkLibrary(text.library);
    notification_tests.root_module.linkSystemLibrary("dbus-1", .{});
    notification_tests.root_module.addImport("sdl_c", sdl_c);
    notification_tests.root_module.addImport("dbus_c", dbus_c);
    notification_tests.use_llvm = false;
    notification_tests.use_lld = false;
    const run_notification_tests = b.addRunArtifact(notification_tests);
    const test_step = b.step("test", "Run Wayspot tests");
    test_step.dependOn(&run_picker_tests.step);
    test_step.dependOn(&run_apps_tests.step);
    test_step.dependOn(&run_desktop_files_tests.step);
    test_step.dependOn(&run_transcript_tests.step);
    test_step.dependOn(&run_launch_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_cmd_tests.step);
    test_step.dependOn(&run_icon_tests.step);
    test_step.dependOn(&run_image_tests.step);
    test_step.dependOn(&run_wallpaper_tests.step);
    test_step.dependOn(&run_wallpaper_transcript_tests.step);
    test_step.dependOn(&run_wallpaper_native_tests.step);
    test_step.dependOn(&run_sdl_event_tests.step);
    test_step.dependOn(&run_sdl_tests.step);
    test_step.dependOn(&run_sdl_pixels_tests.step);
    test_step.dependOn(&run_notification_tests.step);

    const run = b.addRunArtifact(executable);
    if (comptime @hasDecl(std.Build.Step.Run, "addPassthruArgs")) {
        run.addPassthruArgs();
    } else if (b.args) |args| {
        run.addArgs(args);
    }
    const run_step = b.step("run", "Run Wayspot");
    run_step.dependOn(&run.step);
}

fn waylandHeader(
    b: *std.Build,
    xml: std.Build.LazyPath,
    name: []const u8,
) std.Build.LazyPath {
    const command = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });
    command.addFileArg(xml);
    return command.addOutputFileArg(b.fmt("{s}-client.h", .{name}));
}

fn waylandCode(b: *std.Build, xml: std.Build.LazyPath, name: []const u8) std.Build.LazyPath {
    const command = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
    command.addFileArg(xml);
    return command.addOutputFileArg(b.fmt("{s}.c", .{name}));
}

fn addNotificationLibraries(
    b: *std.Build,
    module: *std.Build.Module,
    sdl: *std.Build.Dependency,
    text: libs.Text,
    sdl_c: *std.Build.Module,
    dbus_c: *std.Build.Module,
) void {
    module.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    module.addIncludePath(sdl.path("include"));
    module.addIncludePath(text.include);
    module.linkLibrary(sdl.artifact("SDL3"));
    module.linkLibrary(text.library);
    module.linkSystemLibrary("dbus-1", .{});
    module.addImport("sdl_c", sdl_c);
    module.addImport("dbus_c", dbus_c);
}
