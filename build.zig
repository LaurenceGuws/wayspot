const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const app_version = b.option([]const u8, "app_version", "Wayspot application version string") orelse "0.1.3-dev";
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_sdl", true);
    build_options.addOption([]const u8, "app_version", app_version);
    const defaults_asset = b.addOptions();
    const defaults_lua = std.Io.Dir.cwd().readFileAlloc(std.Options.debug_io, "assets/lua/defaults.lua", b.allocator, .limited(32768)) catch @panic("failed to read assets/lua/defaults.lua");
    defaults_asset.addOption([]const u8, "lua", defaults_lua);
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
    });
    const lua_dep = b.dependency("howl_lua", .{
        .target = target,
        .optimize = optimize,
    });
    const lua_mod = lua_dep.module("howl_lua");
    const sdl_include = sdl_dep.path("include");
    const sdl_c_mod = translateCModule(b, b.path("src/c/sdl.h"), target, optimize, &.{sdl_include});
    const sdl_io_mod = b.createModule(.{
        .root_source_file = b.path("src/c/sdl_io.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sdl_io_mod.addImport("sdl_c", sdl_c_mod);
    const wayland_c_mod = translateCModule(b, b.path("src/c/wayland.h"), target, optimize, &.{});
    const text_c_mod = translateCModule(b, b.path("src/c/text.h"), target, optimize, &.{
        .{ .cwd_relative = "/usr/include/freetype2" },
        .{ .cwd_relative = "/usr/include/harfbuzz" },
    });
    const picker_candidate_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/candidate.zig"),
        .target = target,
        .optimize = optimize,
    });
    const picker_sub_cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/sub_cmd.zig"),
        .target = target,
        .optimize = optimize,
    });
    picker_candidate_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    const picker_sub_cmd_tests = b.addTest(.{
        .root_module = picker_sub_cmd_mod,
    });
    const run_picker_sub_cmd_tests = b.addRunArtifact(picker_sub_cmd_tests);
    const picker_candidate_tests = b.addTest(.{
        .root_module = picker_candidate_mod,
    });
    const run_picker_candidate_tests = b.addRunArtifact(picker_candidate_tests);
    const layer_shell_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    layer_shell_mod.addIncludePath(b.path("src/c"));
    layer_shell_mod.addCSourceFile(.{ .file = b.path("src/c/wayspot_layer_shell.c") });
    const layer_shell = b.addLibrary(.{
        .name = "wayspot_layer_shell",
        .root_module = layer_shell_mod,
    });

    const identity_mod = b.createModule(.{
        .root_source_file = b.path("src/identity.zig"),
        .target = target,
        .optimize = optimize,
    });
    const appearance_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/appearance.zig"),
        .target = target,
        .optimize = optimize,
    });
    const query_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/query.zig"),
        .target = target,
        .optimize = optimize,
    });
    const rank_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/rank.zig"),
        .target = target,
        .optimize = optimize,
    });
    rank_mod.addImport("picker_candidate", picker_candidate_mod);
    rank_mod.addImport("wayspot_query", query_mod);
    const history_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/history.zig"),
        .target = target,
        .optimize = optimize,
    });
    const notification_preview_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/preview.zig"),
        .target = target,
        .optimize = optimize,
    });
    const history_list_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/history_list.zig"),
        .target = target,
        .optimize = optimize,
    });
    history_list_mod.addImport("wayspot_history", history_mod);
    history_list_mod.addImport("wayspot_notification_preview", notification_preview_mod);
    history_list_mod.addImport("picker_candidate", picker_candidate_mod);

    const env_mod = b.createModule(.{
        .root_source_file = b.path("src/env/mod.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    env_mod.addImport("sdl_c", sdl_c_mod);
    env_mod.addImport("sdl_io", sdl_io_mod);

    const scale_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/scale.zig"),
        .target = target,
        .optimize = optimize,
    });
    scale_mod.addImport("sdl_c", sdl_c_mod);
    const text_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/text.zig"),
        .target = target,
        .optimize = optimize,
    });
    text_mod.addImport("sdl_c", sdl_c_mod);
    text_mod.addImport("text_c", text_c_mod);
    text_mod.addImport("wayspot_appearance", appearance_mod);
    const config_defaults_mod = b.createModule(.{
        .root_source_file = b.path("src/config/defaults.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "defaults_asset", .module = defaults_asset.createModule() },
            .{ .name = "howl_lua", .module = lua_mod },
            .{ .name = "wayspot_appearance", .module = appearance_mod },
        },
    });
    config_defaults_mod.linkSystemLibrary("lua5.4", .{ .use_pkg_config = .force });
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("wayspot_config_defaults", config_defaults_mod);

    const apps_mode_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/mode/apps.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    apps_mode_mod.addImport("picker_candidate", picker_candidate_mod);
    const notifications_mode_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/mode/notifications.zig"),
        .target = target,
        .optimize = optimize,
    });
    notifications_mode_mod.addImport("picker_candidate", picker_candidate_mod);
    notifications_mode_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    const wallpaper_mode_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/mode/wallpaper.zig"),
        .target = target,
        .optimize = optimize,
    });
    wallpaper_mode_mod.addImport("picker_candidate", picker_candidate_mod);
    wallpaper_mode_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    const sunglasses_mode_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/mode/sunglasses.zig"),
        .target = target,
        .optimize = optimize,
    });
    sunglasses_mode_mod.addImport("picker_candidate", picker_candidate_mod);
    sunglasses_mode_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);

    const cmd_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/cmd.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    cmd_mod.addImport("picker_candidate", picker_candidate_mod);
    cmd_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    cmd_mod.addImport("wayspot_apps_mode", apps_mode_mod);
    cmd_mod.addImport("wayspot_history_list", history_list_mod);
    cmd_mod.addImport("wayspot_notifications_mode", notifications_mode_mod);
    cmd_mod.addImport("wayspot_sunglasses_mode", sunglasses_mode_mod);
    cmd_mod.addImport("wayspot_wallpaper_mode", wallpaper_mode_mod);
    cmd_mod.addImport("wayspot_query", query_mod);
    cmd_mod.addImport("wayspot_rank", rank_mod);

    const picker_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/mod.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    picker_mod.addImport("picker_candidate", picker_candidate_mod);
    picker_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    picker_mod.addImport("wayspot_cmd", cmd_mod);
    picker_mod.addImport("wayspot_apps_mode", apps_mode_mod);
    picker_mod.addImport("wayspot_notifications_mode", notifications_mode_mod);
    picker_mod.addImport("wayspot_sunglasses_mode", sunglasses_mode_mod);
    picker_mod.addImport("wayspot_wallpaper_mode", wallpaper_mode_mod);
    picker_mod.addImport("wayspot_appearance", appearance_mod);
    picker_mod.addImport("wayspot_scale", scale_mod);
    picker_mod.addImport("wayspot_text", text_mod);
    picker_mod.addImport("wayspot_query", query_mod);
    picker_mod.addImport("wayspot_rank", rank_mod);
    picker_mod.addImport("sdl_c", sdl_c_mod);
    picker_mod.addImport("text_c", text_c_mod);

    // Direct owner roots keep the current CLI, GUI, process, Cmd, mode, and
    // resident imports visible to the build. Their test artifacts below make
    // each native backend link explicit instead of hiding coverage in root.zig.
    const process_mod = b.createModule(.{
        .root_source_file = b.path("src/process/launch.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/entry.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    cli_mod.addImport("wayspot_picker", picker_mod);
    cli_mod.addImport("wayspot_process", process_mod);
    cli_mod.addImport("wayspot_cmd", cmd_mod);
    cli_mod.addImport("sdl_c", sdl_c_mod);
    cli_mod.linkLibrary(sdl_dep.artifact("SDL3"));

    const bash_completion_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/bash_completion.zig"),
        .target = target,
        .optimize = optimize,
    });
    bash_completion_mod.addImport("wayspot_cmd", cmd_mod);

    const gui_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/surface.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gui_mod.addImport("wayspot_picker", picker_mod);
    gui_mod.addImport("wayspot_process", process_mod);
    gui_mod.addImport("wayspot_config_defaults", config_defaults_mod);
    gui_mod.addImport("sdl_c", sdl_c_mod);
    gui_mod.addImport("text_c", text_c_mod);
    gui_mod.addIncludePath(sdl_include);
    gui_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    gui_mod.linkSystemLibrary("freetype2", .{ .use_pkg_config = .yes });
    gui_mod.linkSystemLibrary("harfbuzz", .{ .use_pkg_config = .yes });

    const notification_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/mod.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    notification_mod.addImport("picker_candidate", picker_candidate_mod);
    notification_mod.addImport("wayspot_identity", identity_mod);
    notification_mod.addImport("wayspot_config_defaults", config_defaults_mod);
    notification_mod.addImport("wayspot_env", env_mod);
    notification_mod.addImport("wayspot_appearance", appearance_mod);
    notification_mod.addImport("wayspot_scale", scale_mod);
    notification_mod.addImport("wayspot_text", text_mod);
    notification_mod.addImport("wayspot_history", history_mod);
    notification_mod.addImport("wayspot_notification_preview", notification_preview_mod);
    notification_mod.addImport("wayspot_history_list", history_list_mod);
    notification_mod.addImport("sdl_c", sdl_c_mod);
    notification_mod.addIncludePath(sdl_include);
    notification_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    notification_mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    notification_mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    notification_mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });
    notification_mod.linkSystemLibrary("freetype2", .{ .use_pkg_config = .yes });
    notification_mod.linkSystemLibrary("harfbuzz", .{ .use_pkg_config = .yes });
    notification_mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });

    const wallpaper_mod = b.createModule(.{
        .root_source_file = b.path("src/wallpaper/mod.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    wallpaper_mod.addImport("wayspot_env", env_mod);
    wallpaper_mod.addImport("wayspot_identity", identity_mod);
    wallpaper_mod.addImport("sdl_c", sdl_c_mod);
    wallpaper_mod.addImport("wayland_c", wayland_c_mod);
    wallpaper_mod.addIncludePath(sdl_include);
    wallpaper_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    wallpaper_mod.linkLibrary(layer_shell);
    wallpaper_mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });

    const sunglasses_mod = b.createModule(.{
        .root_source_file = b.path("src/sunglasses/mod.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sunglasses_mod.addImport("picker_candidate", picker_candidate_mod);
    sunglasses_mod.addImport("wayspot_env", env_mod);
    sunglasses_mod.addImport("wayspot_identity", identity_mod);
    sunglasses_mod.addImport("sdl_c", sdl_c_mod);
    sunglasses_mod.addIncludePath(sdl_include);
    sunglasses_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    sunglasses_mod.linkLibrary(layer_shell);
    sunglasses_mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });

    // Aggregate source-tree tests stay in one src/ module so tests from
    // ordinary source imports execute together. Named owner roots below remain
    // separate checks for the direct module boundaries.
    const aggregate_test_mod = b.createModule(.{
        .root_source_file = b.path("src/aggregate_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "defaults_asset", .module = defaults_asset.createModule() },
            .{ .name = "howl_lua", .module = lua_mod },
        },
    });
    aggregate_test_mod.addImport("wayspot_env", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_appearance", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_config_defaults", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_query", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_rank", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_scale", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_text", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_history", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_notification_preview", aggregate_test_mod);
    aggregate_test_mod.addImport("wayspot_history_list", aggregate_test_mod);
    aggregate_test_mod.addImport("picker_candidate", picker_candidate_mod);
    aggregate_test_mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    aggregate_test_mod.addImport("sdl_c", sdl_c_mod);
    aggregate_test_mod.addImport("sdl_io", sdl_io_mod);
    aggregate_test_mod.addImport("text_c", text_c_mod);
    aggregate_test_mod.addImport("wayland_c", wayland_c_mod);
    aggregate_test_mod.addIncludePath(sdl_include);
    aggregate_test_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    aggregate_test_mod.linkLibrary(layer_shell);
    aggregate_test_mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    aggregate_test_mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    aggregate_test_mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });
    aggregate_test_mod.linkSystemLibrary("freetype2", .{ .use_pkg_config = .yes });
    aggregate_test_mod.linkSystemLibrary("harfbuzz", .{ .use_pkg_config = .yes });
    aggregate_test_mod.linkSystemLibrary("lua5.4", .{ .use_pkg_config = .force });
    aggregate_test_mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });

    const mod = b.addModule("wayspot", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
        .imports = &.{
            .{ .name = "build_options", .module = build_options.createModule() },
            .{ .name = "defaults_asset", .module = defaults_asset.createModule() },
            .{ .name = "howl_lua", .module = lua_mod },
        },
    });
    mod.addImport("sdl_c", sdl_c_mod);
    mod.addImport("wayland_c", wayland_c_mod);
    mod.addImport("text_c", text_c_mod);
    mod.addImport("picker_candidate", picker_candidate_mod);
    mod.addImport("picker_sub_cmd", picker_sub_cmd_mod);
    mod.addImport("wayspot_cli", cli_mod);
    mod.addImport("wayspot_config", config_mod);
    mod.addImport("wayspot_config_defaults", config_defaults_mod);
    mod.addImport("wayspot_env", env_mod);
    mod.addImport("wayspot_gui", gui_mod);
    mod.addImport("wayspot_identity", identity_mod);
    mod.addImport("wayspot_notification", notification_mod);
    mod.addImport("wayspot_picker", picker_mod);
    mod.addImport("wayspot_process", process_mod);
    mod.addImport("wayspot_sunglasses", sunglasses_mod);
    mod.addImport("wayspot_wallpaper", wallpaper_mod);
    mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("freetype2", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("harfbuzz", .{ .use_pkg_config = .yes });
    mod.linkSystemLibrary("lua5.4", .{ .use_pkg_config = .force });
    mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });
    mod.linkLibrary(layer_shell);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "wayspot", .module = mod },
            .{ .name = "build_options", .module = build_options.createModule() },
            .{ .name = "howl_lua", .module = lua_mod },
        },
    });
    exe_mod.addImport("sdl_c", sdl_c_mod);
    exe_mod.addImport("text_c", text_c_mod);
    exe_mod.linkSystemLibrary("gio-2.0", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("gobject-2.0", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("glib-2.0", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("freetype2", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("harfbuzz", .{ .use_pkg_config = .yes });
    exe_mod.linkSystemLibrary("lua5.4", .{ .use_pkg_config = .force });
    exe_mod.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });
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
    b.installFile("packaging/bash/wayspot.bash", "share/bash-completion/completions/wayspot");

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

    const sdl_io_tests = b.addTest(.{ .root_module = sdl_io_mod });
    sdl_io_tests.use_llvm = true;
    sdl_io_tests.use_lld = true;
    sdl_io_tests.root_module.addIncludePath(sdl_include);
    sdl_io_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_sdl_io_tests = b.addRunArtifact(sdl_io_tests);

    const aggregate_tests = b.addTest(.{ .root_module = aggregate_test_mod });
    aggregate_tests.use_llvm = true;
    aggregate_tests.use_lld = true;
    aggregate_tests.root_module.addIncludePath(sdl_include);
    aggregate_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_aggregate_tests = b.addRunArtifact(aggregate_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_tests.use_llvm = true;
    exe_tests.use_lld = true;
    exe_tests.root_module.addIncludePath(sdl_include);
    exe_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const picker_cmd_tests = b.addTest(.{ .root_module = cmd_mod });
    picker_cmd_tests.use_llvm = true;
    picker_cmd_tests.use_lld = true;
    const run_picker_cmd_tests = b.addRunArtifact(picker_cmd_tests);

    const picker_sunglasses_mode_tests = b.addTest(.{ .root_module = sunglasses_mode_mod });
    picker_sunglasses_mode_tests.use_llvm = true;
    picker_sunglasses_mode_tests.use_lld = true;
    const run_picker_sunglasses_mode_tests = b.addRunArtifact(picker_sunglasses_mode_tests);

    const cli_tests = b.addTest(.{ .root_module = cli_mod });
    cli_tests.use_llvm = true;
    cli_tests.use_lld = true;
    cli_tests.root_module.addIncludePath(sdl_include);
    cli_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_cli_tests = b.addRunArtifact(cli_tests);

    const bash_completion_tests = b.addTest(.{ .root_module = bash_completion_mod });
    bash_completion_tests.use_llvm = true;
    bash_completion_tests.use_lld = true;
    const run_bash_completion_tests = b.addRunArtifact(bash_completion_tests);

    const gui_tests = b.addTest(.{ .root_module = gui_mod });
    gui_tests.use_llvm = true;
    gui_tests.use_lld = true;
    gui_tests.root_module.addIncludePath(sdl_include);
    gui_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_gui_tests = b.addRunArtifact(gui_tests);

    const process_tests = b.addTest(.{ .root_module = process_mod });
    process_tests.use_llvm = true;
    process_tests.use_lld = true;
    const run_process_tests = b.addRunArtifact(process_tests);

    const notification_tests = b.addTest(.{ .root_module = notification_mod });
    notification_tests.use_llvm = true;
    notification_tests.use_lld = true;
    const run_notification_tests = b.addRunArtifact(notification_tests);

    const wallpaper_tests = b.addTest(.{ .root_module = wallpaper_mod });
    wallpaper_tests.use_llvm = true;
    wallpaper_tests.use_lld = true;
    wallpaper_tests.root_module.addIncludePath(sdl_include);
    wallpaper_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_wallpaper_tests = b.addRunArtifact(wallpaper_tests);

    const sunglasses_tests = b.addTest(.{ .root_module = sunglasses_mod });
    sunglasses_tests.use_llvm = true;
    sunglasses_tests.use_lld = true;
    sunglasses_tests.root_module.addIncludePath(sdl_include);
    sunglasses_tests.root_module.linkLibrary(sdl_dep.artifact("SDL3"));
    const run_sunglasses_tests = b.addRunArtifact(sunglasses_tests);

    const notification_preview_tests = b.addTest(.{ .root_module = notification_preview_mod });
    const run_notification_preview_tests = b.addRunArtifact(notification_preview_tests);

    const notification_history_tests = b.addTest(.{ .root_module = history_mod });
    const run_notification_history_tests = b.addRunArtifact(notification_history_tests);

    const notification_history_list_tests = b.addTest(.{ .root_module = history_list_mod });
    const run_notification_history_list_tests = b.addRunArtifact(notification_history_list_tests);

    const picker_appearance_tests = b.addTest(.{ .root_module = appearance_mod });
    const run_picker_appearance_tests = b.addRunArtifact(picker_appearance_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_sdl_io_tests.step);
    test_step.dependOn(&run_aggregate_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_notification_preview_tests.step);
    test_step.dependOn(&run_notification_history_tests.step);
    test_step.dependOn(&run_notification_history_list_tests.step);
    test_step.dependOn(&run_picker_appearance_tests.step);
    test_step.dependOn(&run_picker_sub_cmd_tests.step);
    test_step.dependOn(&run_picker_candidate_tests.step);
    test_step.dependOn(&run_picker_cmd_tests.step);
    test_step.dependOn(&run_picker_sunglasses_mode_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_bash_completion_tests.step);
    test_step.dependOn(&run_gui_tests.step);
    test_step.dependOn(&run_process_tests.step);
    test_step.dependOn(&run_notification_tests.step);
    test_step.dependOn(&run_wallpaper_tests.step);
    test_step.dependOn(&run_sunglasses_tests.step);

    const regression_tests = b.step("regression_tests", "Run regression tests");
    regression_tests.dependOn(&run_mod_tests.step);
}

fn translateCModule(
    b: *std.Build,
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    include_paths: []const std.Build.LazyPath,
) *std.Build.Module {
    const translated = b.addTranslateC(.{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });
    for (include_paths) |include_path| translated.addIncludePath(include_path);
    return translated.createModule();
}
