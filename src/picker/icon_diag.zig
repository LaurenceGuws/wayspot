//! App icon diagnostics report resolver and vendor texture upload results for local app rows.

const std = @import("std");
const candidate_mod = @import("picker_candidate");
const app_icons = @import("icons.zig");

const c = @import("sdl_c");

pub const report_path = ".zig-cache/wayspot/icon-diagnostic.tsv";
const max_report_rows: u32 = 768;

const Counts = struct {
    app_rows: u32 = 0,
    resolved: u32 = 0,
    iconless: u32 = 0,
    unsupported: u32 = 0,
    surface_ok: u32 = 0,
    surface_failed: u32 = 0,
    skipped: u32 = 0,
};

/// writeReport writes a bounded TSV icon diagnostic report and stdout summary.
pub fn writeReport(candidates: []const candidate_mod.Candidate) !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SdlInitFailed;
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "Wayspot icon diagnostic",
        64,
        64,
        c.SDL_WINDOW_HIDDEN,
    ) orelse return error.SdlWindowFailed;
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null) orelse return error.SdlRendererFailed;
    defer c.SDL_DestroyRenderer(renderer);

    try ensureReportParent();
    var file = try std.Io.Dir.cwd().createFile(std.Options.debug_io, report_path, .{ .truncate = true });
    defer file.close(std.Options.debug_io);

    var file_buffer: [8192]u8 = undefined;
    var writer = file.writer(std.Options.debug_io, &file_buffer);
    const out = &writer.interface;
    var counts = Counts{};
    try out.print("section\tapp\ticon\tresolved_path\tformat\tresolve_status\tsurface_status\n", .{});

    var path_buffer: [app_icons.max_icon_path_bytes + 1]u8 = undefined;
    const roots = app_icons.ResolveRoots.fromEnv();
    for (candidates) |candidate| {
        if (candidate.typeOf() != .app) continue;
        counts.app_rows += 1;
        if (counts.app_rows > max_report_rows) {
            counts.skipped += 1;
            continue;
        }

        const resolution = app_icons.diagnoseIcon(candidate.iconName(), roots, &path_buffer);
        if (resolution.status == .resolved) {
            const path_z = path_buffer[0..resolution.path.len :0];
            const texture_result = app_icons.loadTexturePath(renderer, path_z);
            counts.resolved += 1;
            if (texture_result.status == .loaded_texture) {
                counts.surface_ok += 1;
                c.SDL_DestroyTexture(texture_result.texture);
            } else {
                counts.surface_failed += 1;
            }
            try out.print(
                "resolved\t{s}\t{s}\t{s}\t{s}\t{s}\t{s}\n",
                .{
                    candidate.title(),
                    candidate.iconName(),
                    resolution.path,
                    resolution.format(),
                    @tagName(resolution.status),
                    @tagName(texture_result.status),
                },
            );
            continue;
        }

        const section = switch (resolution.status) {
            .unsupported, .symbolic, .relative_path, .name_too_long => unsupported_section: {
                counts.unsupported += 1;
                break :unsupported_section "unsupported";
            },
            .empty, .missing => iconless_section: {
                counts.iconless += 1;
                break :iconless_section "iconless";
            },
            .resolved => unreachable,
        };
        try out.print(
            "{s}\t{s}\t{s}\t\t\t{s}\tnot_loaded\n",
            .{ section, candidate.title(), candidate.iconName(), @tagName(resolution.status) },
        );
    }

    try out.print(
        "summary\tapp_rows={d}\tresolved={d}\ticonless={d}\tunsupported={d}\tsurface_ok={d}\tsurface_failed={d}\tskipped={d}\n",
        .{
            counts.app_rows,
            counts.resolved,
            counts.iconless,
            counts.unsupported,
            counts.surface_ok,
            counts.surface_failed,
            counts.skipped,
        },
    );
    try out.flush();
    try file.sync(std.Options.debug_io);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(std.Options.debug_io, &stdout_buffer);
    try stdout_writer.interface.print(
        "icon diagnostic report: {s}\napp_rows={d} resolved={d} surface_ok={d} surface_failed={d} iconless={d} unsupported={d} skipped={d}\n",
        .{
            report_path,
            counts.app_rows,
            counts.resolved,
            counts.surface_ok,
            counts.surface_failed,
            counts.iconless,
            counts.unsupported,
            counts.skipped,
        },
    );
    try stdout_writer.interface.flush();
}

fn ensureReportParent() !void {
    const parent = std.fs.path.dirname(report_path) orelse return;
    try std.Io.Dir.cwd().createDirPath(std.Options.debug_io, parent);
}
