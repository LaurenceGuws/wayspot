//! ProviderRegistry owns the fixed app/action provider set used by the picker.

const std = @import("std");
const search = @import("../search/mod.zig");
const actions = @import("actions.zig");
const apps = @import("apps.zig");

/// Provider is the concrete provider admission list; it is intentionally not an open vtable.
pub const Provider = union(enum) {
    actions: *actions.ActionsProvider,
    apps: *apps.AppsProvider,

    /// name returns the provider label used in health and collection diagnostics.
    pub fn name(self: Provider) []const u8 {
        return switch (self) {
            .actions => "actions",
            .apps => "apps",
        };
    }

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

    /// health reports readiness from exactly one retained provider owner.
    pub fn health(self: Provider) search.ProviderHealth {
        return switch (self) {
            .actions => |provider| provider.health(),
            .apps => |provider| provider.health(),
        };
    }
};

pub const ProviderStatus = struct {
    name: []const u8,
    health: search.ProviderHealth,
};

pub const ProviderCollectFailure = struct {
    provider_name: []const u8,
    err: anyerror,
};

pub const CollectReport = struct {
    had_runtime_failure: bool = false,
    runtime_failure_count: u32 = 0,
    first_runtime_failure: ?ProviderCollectFailure = null,
};

/// ProviderRegistry owns collection order and failure isolation for retained providers.
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
        const report = try self.collectAllWithReport(allocator, out);
        if (report.runtime_failure_count == 0) return;
    }

    pub fn collectAllWithReport(
        self: ProviderRegistry,
        allocator: std.mem.Allocator,
        out: *search.CandidateList,
    ) !CollectReport {
        var report = CollectReport{};
        for (self.providers) |provider| {
            provider.collect(allocator, out) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => {
                    report.had_runtime_failure = true;
                    report.runtime_failure_count += 1;
                    if (report.first_runtime_failure == null) {
                        report.first_runtime_failure = .{
                            .provider_name = provider.name(),
                            .err = err,
                        };
                    }
                    std.log.warn(
                        "provider '{s}' collect failed: {s}",
                        .{ provider.name(), @errorName(err) },
                    );
                },
            };
        }
        return report;
    }

    pub fn healthSnapshot(self: ProviderRegistry, allocator: std.mem.Allocator) ![]ProviderStatus {
        var snapshot = std.ArrayList(ProviderStatus).empty;
        defer snapshot.deinit(allocator);

        for (self.providers) |provider| {
            try snapshot.append(allocator, .{
                .name = provider.name(),
                .health = provider.health(),
            });
        }

        return snapshot.toOwnedSlice(allocator);
    }
};
