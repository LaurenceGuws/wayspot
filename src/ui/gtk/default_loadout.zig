const std = @import("std");
const gtk_types = @import("types.zig");
const gtk_render = @import("render.zig");
const gtk_icons = @import("icons.zig");
const gtk_nav = @import("navigation.zig");
const gtk_widgets = @import("widgets.zig");
const gtk_status = @import("status.zig");

const UiContext = gtk_types.UiContext;
const c = gtk_types.c;
const GFALSE = gtk_types.GFALSE;

pub fn render(ctx: *UiContext, allocator: std.mem.Allocator, hot_render_rows: usize, on_refresh_pending: *const fn (*UiContext) void) void {
    switch (ctx.service.staticQueryExecution()) {
        .ready => {},
        .refreshing, .cache_cold => {
            _ = ctx.service.scheduleRefreshFromEvent();
            on_refresh_pending(ctx);
            return;
        },
    }

    const merged = ctx.service.defaultLoadout(allocator) catch {
        renderUnavailable(ctx);
        return;
    };
    defer allocator.free(merged);

    const had_selection = c.gtk_list_box_get_selected_row(@ptrCast(ctx.list)) != null;
    gtk_widgets.clearList(ctx.list);
    gtk_widgets.appendModuleFilterMenu(ctx.list, allocator);
    if (merged.len > 0) {
        gtk_widgets.appendSectionSeparatorRow(ctx.list);
        gtk_widgets.appendHeaderRow(ctx.list, "Suggested For You");
        gtk_render.appendOrderedRows(ctx, allocator, merged, "", .{
            .candidate_icon_widget = gtk_icons.candidateIconWidget,
        });
        ctx.last_render_hash = std.hash.Wyhash.hash(0x4dd8f0, "default-loadout-with-modules");
    } else {
        ctx.last_render_hash = std.hash.Wyhash.hash(0x4dd8f0, "default-loadout-modules-only");
    }
    if (!had_selection and ctx.result_window_limit <= hot_render_rows) {
        gtk_nav.selectFirstActionableRow(ctx);
    }
}

fn renderUnavailable(ctx: *UiContext) void {
    gtk_widgets.clearList(ctx.list);
    gtk_widgets.appendInfoRow(ctx.list, "Default loadout unavailable");
    ctx.last_render_hash = std.hash.Wyhash.hash(0x91f3aa, "default-loadout-unavailable");
    if (ctx.pending_power_confirm == GFALSE) {
        gtk_status.setStatus(ctx, "Type to search");
    }
}
