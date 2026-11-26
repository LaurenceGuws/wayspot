const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = optimizeOption(b);
    // The non-product Zig build/tooling source is fully covered here.
    // Application source has its own pending review, not a blanket baseline.
    const audit = b.step("audit", "Audit build and maintenance Zig source");
    const audit_command = b.addSystemCommand(&.{ "zig-audit", "check" });
    audit_command.setCwd(b.path("."));
    audit.dependOn(&audit_command.step);
    const sdl = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
        // Wayspot only needs SDL surfaces, image decoding and the software
        // rasterizer. No video subsystem or accelerated renderer is available.
        .build_config_h_overrides = @as([]const []const u8, &.{
            "-DSDL_VIDEO_DISABLED=1",
            "-DSDL_GPU_DISABLED=1",
            "-USDL_VIDEO_DRIVER_DUMMY",
            "-USDL_VIDEO_DRIVER_OFFSCREEN",
            "-USDL_VIDEO_DRIVER_WAYLAND",
            "-USDL_VIDEO_DRIVER_X11",
            "-USDL_VIDEO_DRIVER_KMSDRM",
            "-USDL_VIDEO_RENDER_GPU",
            "-USDL_VIDEO_RENDER_VULKAN",
            "-USDL_VIDEO_RENDER_OGL",
            "-USDL_VIDEO_RENDER_OGL_ES2",
            "-USDL_VIDEO_OPENGL",
            "-USDL_VIDEO_OPENGL_ES",
            "-USDL_VIDEO_OPENGL_ES2",
            "-USDL_VIDEO_OPENGL_GLX",
            "-USDL_VIDEO_OPENGL_EGL",
            "-USDL_VIDEO_VULKAN",
        }),
    });
    const howl_text = b.dependency("howl_text", .{ .target = target, .optimize = optimize });
    const headers = b.addWriteFiles();
    const sdl_header = headers.add(
        "wayspot-sdl.h",
        "#include <SDL3/SDL.h>\n",
    );
    const sdl_translate = b.addTranslateC(.{
        .root_source_file = sdl_header,
        .target = target,
        .optimize = optimize,
    });
    sdl_translate.addIncludePath(sdl.path("include"));
    const sdl_c = sdl_translate.createModule();

    const dbus_header = headers.add("wayspot-dbus.h", "#include <dbus/dbus.h>\n");
    const dbus_translate = b.addTranslateC(.{
        .root_source_file = dbus_header,
        .target = target,
        .optimize = optimize,
    });
    dbus_translate.linkSystemLibrary("dbus-1", .{});
    const dbus_c = dbus_translate.createModule();

    const time_header = headers.add("wayspot-time.h", "#include <time.h>\n");
    const time_translate = b.addTranslateC(.{
        .root_source_file = time_header,
        .target = target,
        .optimize = optimize,
    });
    const time_c = time_translate.createModule();

    const wayspot = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wayspot.addIncludePath(sdl.path("include"));
    wayspot.addIncludePath(b.path("vendor/stb"));
    wayspot.addCSourceFile(.{ .file = b.path("src/wallpaper/jpeg.c") });
    wayspot.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    wayspot.linkLibrary(sdl.artifact("SDL3"));
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
    wayland_protocol_module.addIncludePath(b.path("src/wayland"));
    wayland_protocol_module.addCSourceFile(.{ .file = b.path("src/wayland/protocol.c") });
    wayland_protocol_module.linkSystemLibrary("wayland-client", .{});
    const wayland_protocol = b.addLibrary(.{
        .name = "wayspot_wayland_protocol",
        .linkage = .static,
        .root_module = wayland_protocol_module,
    });
    wayspot.linkLibrary(wayland_protocol);
    const wayland_translate = b.addTranslateC(.{
        .root_source_file = b.path("src/wayland/protocol.h"),
        .target = target,
        .optimize = optimize,
    });
    wayland_translate.linkSystemLibrary("wayland-client", .{});
    const wayland_c = wayland_translate.createModule();
    wayspot.addImport("sdl_c", sdl_c);
    wayspot.addImport("howl_text", howl_text.module("howl_text"));
    wayspot.addImport("dbus_c", dbus_c);
    wayspot.addImport("wayland_c", wayland_c);
    wayspot.addImport("time_c", time_c);

    const executable = b.addExecutable(.{
        .name = "wayspot",
        .root_module = wayspot,
    });
    executable.use_llvm = false;
    executable.use_lld = false;
    b.installArtifact(executable);

    // Source tests share the product's module root. Import each source once;
    // colocated tests and simulator cases keep their original bodies.
    const source_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });
    source_tests.root_module.addIncludePath(b.path("vendor/stb"));
    source_tests.root_module.addCSourceFile(.{ .file = b.path("src/wallpaper/jpeg.c") });
    source_tests.root_module.addImport("time_c", time_c);
    addNotificationLibraries(b, source_tests.root_module, sdl, howl_text.module("howl_text"), sdl_c, dbus_c, wayland_c, wayland_protocol);
    // Both graphical roles use the native surface owner.
    // Use the exact pinned native Wayland package already used by Snowman's
    // simulator. No second compositor-specific protocol implementation.
    const native_wayland = b.dependency("wayland", .{ .target = target, .optimize = optimize });
    const native_protocols = @import("wayland").addProtocols(b, native_wayland, .{
        .target = target,
        .optimize = optimize,
        .extra = &.{
            layer_xml,
            b.path("protocols/viewporter.xml"),
            native_wayland.namedLazyPath("wayland-protocols").path(b, "staging/fractional-scale/fractional-scale-v1.xml"),
            native_wayland.namedLazyPath("wayland-protocols").path(b, "unstable/text-input/text-input-unstable-v3.xml"),
            native_wayland.namedLazyPath("wayland-protocols").path(b, "stable/tablet/tablet-v2.xml"),
            native_wayland.namedLazyPath("wayland-protocols").path(b, "staging/cursor-shape/cursor-shape-v1.xml"),
        },
    });
    const native_present = @import("wayland").addPresent(b, native_wayland, native_protocols);
    source_tests.root_module.addImport("wayland-client", native_wayland.module("client"));
    source_tests.root_module.addImport("wayland-protocols", native_protocols);
    source_tests.root_module.addImport("wayland-present", native_present);
    source_tests.root_module.addImport("wayland-wire", native_wayland.module("protocol"));
    const xkb_header = headers.add("wayspot-xkb.h", "#include <xkbcommon/xkbcommon.h>\n#include <xkbcommon/xkbcommon-names.h>\n#include <xkbcommon/xkbcommon-compose.h>\n");
    const xkb_translate = b.addTranslateC(.{ .root_source_file = xkb_header, .target = target, .optimize = optimize });
    xkb_translate.linkSystemLibrary("xkbcommon", .{});
    source_tests.root_module.addImport("xkb_c", xkb_translate.createModule());
    source_tests.root_module.linkSystemLibrary("xkbcommon", .{});
    wayspot.addImport("wayland-client", native_wayland.module("client"));
    wayspot.addImport("wayland-protocols", native_protocols);
    wayspot.addImport("wayland-present", native_present);
    wayspot.addImport("wayland-wire", native_wayland.module("protocol"));
    wayspot.addImport("xkb_c", xkb_translate.createModule());
    wayspot.linkSystemLibrary("xkbcommon", .{});
    source_tests.use_llvm = false;
    source_tests.use_lld = false;
    const live_native = b.addSystemCommand(&.{"python3"});
    live_native.addFileArg(b.path("tools/native-surface-live.py"));
    live_native.addFileArg(source_tests.getEmittedBin());
    live_native.setCwd(b.path("."));
    live_native.has_side_effects = true;
    b.step("native-surface-live", "Prove the native surface owner on an explicit private compositor")
        .dependOn(&live_native.step);
    const live_scale = b.addSystemCommand(&.{"python3"});
    live_scale.addFileArg(b.path("tools/native-surface-live.py"));
    live_scale.addFileArg(source_tests.getEmittedBin());
    live_scale.addArg("--mixed");
    live_scale.setCwd(b.path("."));
    live_scale.has_side_effects = true;
    b.step("native-scale-live", "Prove real mixed-density layers and in-place scale changes")
        .dependOn(&live_scale.step);
    const live_input = b.addSystemCommand(&.{"python3"});
    live_input.addFileArg(b.path("tools/native-surface-live.py"));
    live_input.addFileArg(source_tests.getEmittedBin());
    live_input.addArg("--input");
    live_input.setCwd(b.path("."));
    live_input.has_side_effects = true;
    b.step("native-input-live", "Prove actual native keyboard and pointer events on a private seat")
        .dependOn(&live_input.step);

    // Optional source-built integration; requires explicitly provided private
    // Snowman executable/CLI from a matching external test fixture.
    const live_wallpaper = b.addSystemCommand(&.{"bash"});
    live_wallpaper.addFileArg(b.path("tools/wallpaper-live.sh"));
    live_wallpaper.addFileArg(executable.getEmittedBin());
    live_wallpaper.setCwd(b.path("."));
    live_wallpaper.has_side_effects = true;
    b.step("wallpaper-live", "Prove Wayland-native wallpaper against explicit isolated compositor")
        .dependOn(&live_wallpaper.step);

    const live_resident = b.addSystemCommand(&.{"python3"});
    live_resident.addFileArg(b.path("tools/resident-live.py"));
    live_resident.addFileArg(executable.getEmittedBin());
    live_resident.setCwd(b.path("."));
    live_resident.has_side_effects = true;
    b.step("resident-live", "Prove all capabilities in an explicit isolated session")
        .dependOn(&live_resident.step);

    // The canary owns a real XDG surface and fixed SNI/DBusMenu endpoints.
    // It is a test artifact, not another installed desktop service.
    const canary_module = b.createModule(.{
        .root_source_file = b.path("tools/tray_canary.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    canary_module.addImport("wayland-client", native_wayland.module("client"));
    canary_module.addImport("wayland-protocols", native_protocols);
    canary_module.addImport("wayland-present", native_present);
    canary_module.addImport("dbus_c", dbus_c);
    canary_module.linkSystemLibrary("dbus-1", .{});
    const canary = b.addExecutable(.{ .name = "wayspot-tray-canary", .root_module = canary_module });
    canary.use_llvm = false;
    canary.use_lld = false;
    b.step("tray-canary", "Build the disposable native tray canary")
        .dependOn(&b.addInstallArtifact(canary, .{}).step);
    const live_tray = b.addSystemCommand(&.{"python3"});
    live_tray.addFileArg(b.path("tools/resident-live.py"));
    live_tray.addFileArg(executable.getEmittedBin());
    live_tray.addArg("--tray-canary");
    live_tray.addFileArg(canary.getEmittedBin());
    live_tray.setCwd(b.path("."));
    live_tray.has_side_effects = true;
    b.step("tray-live", "Prove native tray and menu actions in an isolated session")
        .dependOn(&live_tray.step);

    // The standalone wallpaper-catalog diagnostic is maintained Zig too.
    // Exercise its source-local tests without making it an installed product.
    const wallpaper_catalog_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/wallpaper_catalog.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_wallpaper_catalog_tests = b.addRunArtifact(wallpaper_catalog_tests);
    const test_step = b.step("test", "Run Wayspot tests");
    test_step.dependOn(&b.addRunArtifact(source_tests).step);
    test_step.dependOn(&canary.step);
    test_step.dependOn(&run_wallpaper_catalog_tests.step);
    const run_bash_completion_test = b.addSystemCommand(&.{ "bash", "tools/bash_completion_test.bash" });
    run_bash_completion_test.addArtifactArg2(executable, .{});
    test_step.dependOn(&run_bash_completion_test.step);

    const formatting = b.addFmt(.{
        .paths = &.{
            b.path("build.zig"),
            b.path("build.zig.zon"),
            b.path("src"),
            b.path("tools/wallpaper_catalog.zig"),
            b.path("tools/tray_canary.zig"),
        },
        .check = true,
    });
    const check = b.step("check", "Check formatting, audit build tools, and run regression tests");
    check.dependOn(&formatting.step);
    check.dependOn(audit);
    check.dependOn(test_step);

    const run = b.addRunArtifact(executable);
    run.addPassthruArgs();
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

fn optimizeOption(b: *std.Build) std.builtin.OptimizeMode {
    if (b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Prioritize performance, safety, or binary size (default: ReleaseSafe)",
    )) |mode| return mode;

    return switch (b.graph.release_mode) {
        .off, .any, .safe => .safe,
        .fast => .fast,
        .small => .small,
    };
}

fn addNotificationLibraries(
    b: *std.Build,
    module: *std.Build.Module,
    sdl: *std.Build.Dependency,
    howl_text: *std.Build.Module,
    sdl_c: *std.Build.Module,
    dbus_c: *std.Build.Module,
    wayland_c: *std.Build.Module,
    wayland_protocol: *std.Build.Step.Compile,
) void {
    module.addAnonymousImport("NotoSans-Regular.ttf", .{
        .root_source_file = b.path("assets/fonts/NotoSans-Regular.ttf"),
    });
    module.addIncludePath(sdl.path("include"));
    module.linkLibrary(sdl.artifact("SDL3"));
    module.linkSystemLibrary("dbus-1", .{});
    module.addImport("howl_text", howl_text);
    module.addImport("sdl_c", sdl_c);
    module.addImport("dbus_c", dbus_c);
    module.addImport("wayland_c", wayland_c);
    module.linkLibrary(wayland_protocol);
}
