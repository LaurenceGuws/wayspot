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

    const notification_preview_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/preview.zig"),
        .target = target,
        .optimize = optimize,
    });
    const notification_preview_tests = b.addTest(.{
        .root_module = notification_preview_mod,
    });
    const run_notification_preview_tests = b.addRunArtifact(notification_preview_tests);

    const notification_history_cache_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/history_cache.zig"),
        .target = target,
        .optimize = optimize,
    });
    const notification_history_cache_tests = b.addTest(.{
        .root_module = notification_history_cache_mod,
    });
    const run_notification_history_cache_tests = b.addRunArtifact(notification_history_cache_tests);

    const notification_history_list_mod = b.createModule(.{
        .root_source_file = b.path("src/notification/history_list.zig"),
        .target = target,
        .optimize = optimize,
    });
    notification_history_list_mod.addImport("picker_candidate", picker_candidate_mod);
    const notification_history_list_tests = b.addTest(.{
        .root_module = notification_history_list_mod,
    });
    const run_notification_history_list_tests = b.addRunArtifact(notification_history_list_tests);

    const picker_appearance_mod = b.createModule(.{
        .root_source_file = b.path("src/picker/appearance.zig"),
        .target = target,
        .optimize = optimize,
    });
    const picker_appearance_tests = b.addTest(.{
        .root_module = picker_appearance_mod,
    });
    const run_picker_appearance_tests = b.addRunArtifact(picker_appearance_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_notification_preview_tests.step);
    test_step.dependOn(&run_notification_history_cache_tests.step);
    test_step.dependOn(&run_notification_history_list_tests.step);
    test_step.dependOn(&run_picker_appearance_tests.step);
    test_step.dependOn(&run_picker_sub_cmd_tests.step);
    test_step.dependOn(&run_picker_candidate_tests.step);

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
