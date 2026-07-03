//! ProviderRegistry owns the fixed app/action provider set used by the picker.

const std = @import("std");
const search = @import("../search/mod.zig");
const actions = @import("actions.zig");
const apps = @import("apps.zig");

/// Provider is the concrete provider admission list; it is intentionally not an open vtable.
pub const Provider = union(enum) {
    actions: *actions.ActionsProvider,
    apps: *apps.AppsProvider,

    /// collect appends candidates from exactly one retained provider owner.
    pub fn collect(
        self: Provider,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !void {
        return switch (self) {
            .actions => |provider| provider.collect(allocator, out),
            .apps => |provider| provider.collect(allocator, out),
        };
    }
};

/// ProviderRegistry owns collection order for retained providers.
pub const ProviderRegistry = struct {
    providers: []const Provider,

    pub fn init(providers: []const Provider) ProviderRegistry {
        return .{ .providers = providers };
    }

    pub fn collectAll(
        self: ProviderRegistry,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !void {
        for (self.providers) |provider| {
            try provider.collect(allocator, out);
        }
    }
};
