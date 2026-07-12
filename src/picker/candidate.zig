//! Candidate owns the bounded reachable-node union and typed terminal leaves.
//!
//! Input is a value contract carried by a Concrete leaf. GUI controls and CLI
//! parsing construct these values; neither owns resident sunglasses state.
//! Display strings remain borrowed from their producer and are not copied here.

const std = @import("std");
const sub_cmd = @import("picker_sub_cmd");

/// max_candidates bounds one published candidate collection.
pub const max_candidates: usize = 1024;
/// max_monitor_name_bytes bounds one copied monitor name in a typed leaf.
pub const max_monitor_name_bytes: usize = 96;
/// max_image_path_bytes bounds one copied image path in a typed leaf.
pub const max_image_path_bytes: usize = 1024;

/// InputError is the exact failure vocabulary for typed leaf construction.
pub const InputError = error{
    ScalarRangeInvalid,
    ScalarStepInvalid,
    ScalarOutOfBounds,
    ScalarValueMisaligned,
    ScalarRangeMismatch,
    MonitorEmpty,
    MonitorTooLong,
    MonitorByteInvalid,
    PathEmpty,
    PathTooLong,
    PathNotAbsolute,
    PathByteInvalid,
    InputNotAccepted,
};

/// ScalarInput owns one bounded scalar value and the range used to edit it.
pub const ScalarInput = struct {
    /// value is the selected scalar.
    value: i32,
    /// min is the inclusive lower bound used by the control.
    min: i32,
    /// max is the inclusive upper bound used by the control.
    max: i32,
    /// step is the positive keyboard and slider increment.
    step: i32,

    /// init validates one scalar value and its inclusive editing range.
    pub fn init(value: i32, min: i32, max: i32, step: i32) InputError!ScalarInput {
        const scalar = ScalarInput{ .value = value, .min = min, .max = max, .step = step };
        try scalar.validate();
        return scalar;
    }

    /// validate proves the scalar range, step, value bounds, and grid alignment.
    pub fn validate(self: ScalarInput) InputError!void {
        if (self.min > self.max) return error.ScalarRangeInvalid;
        const span: i64 = @as(i64, self.max) - @as(i64, self.min);
        if (self.step <= 0 or @as(i64, self.step) > span) return error.ScalarStepInvalid;
        if (self.value < self.min or self.value > self.max) return error.ScalarOutOfBounds;
        const offset: i64 = @as(i64, self.value) - @as(i64, self.min);
        if (@mod(offset, @as(i64, self.step)) != 0) return error.ScalarValueMisaligned;
    }

    /// validateFor requires the leaf-specific range and step.
    pub fn validateFor(self: ScalarInput, min: i32, max: i32, step: i32) InputError!void {
        try self.validate();
        if (self.min != min or self.max != max or self.step != step) return error.ScalarRangeMismatch;
    }
};

/// ToggleInput owns one exact enabled value for an on/off leaf.
pub const ToggleInput = struct {
    /// enabled is the exact on or off value.
    enabled: bool,
};

/// PathInput owns one bounded absolute path copy independent of argv or GUI text.
pub const PathInput = struct {
    /// bytes owns the fixed path storage.
    bytes: [max_image_path_bytes]u8 = undefined,
    /// length is the initialized byte count in bytes.
    length: usize = 0,

    /// init copies and validates one absolute image path.
    pub fn init(path: []const u8) InputError!PathInput {
        if (path.len == 0) return error.PathEmpty;
        if (path.len > max_image_path_bytes) return error.PathTooLong;
        if (!std.fs.path.isAbsolute(path)) return error.PathNotAbsolute;
        if (hasInvalidPathByte(path)) return error.PathByteInvalid;

        var result = PathInput{};
        @memcpy(result.bytes[0..path.len], path);
        result.length = path.len;
        return result;
    }

    /// validate proves the stored path still satisfies its boundary contract.
    pub fn validate(self: PathInput) InputError!void {
        if (self.length == 0) return error.PathEmpty;
        if (self.length > max_image_path_bytes) return error.PathTooLong;
        const path = self.slice();
        if (!std.fs.path.isAbsolute(path)) return error.PathNotAbsolute;
        if (hasInvalidPathByte(path)) return error.PathByteInvalid;
    }

    /// slice returns the owned path bytes.
    pub fn slice(self: *const PathInput) []const u8 {
        return self.bytes[0..self.length];
    }
};

/// Input is the exact typed value vocabulary carried by a Concrete leaf.
pub const Input = union(enum) {
    /// none marks an action leaf with no user value.
    none,
    /// scalar selects a reusable bounded scalar control.
    scalar: ScalarInput,
    /// toggle selects a reusable on/off control.
    toggle: ToggleInput,
    /// path selects a reusable bounded path control.
    path: PathInput,

    /// scalarInput constructs one validated scalar Input value.
    pub fn scalarInput(value: i32, min: i32, max: i32, step: i32) InputError!Input {
        return .{ .scalar = try ScalarInput.init(value, min, max, step) };
    }

    /// toggleInput constructs one exact toggle Input value.
    pub fn toggleInput(enabled: bool) Input {
        return .{ .toggle = .{ .enabled = enabled } };
    }

    /// pathInput constructs one owned absolute path Input value.
    pub fn pathInput(path: []const u8) InputError!Input {
        return .{ .path = try PathInput.init(path) };
    }

    /// validate proves the active Input arm's own storage contract.
    pub fn validate(self: Input) InputError!void {
        switch (self) {
            .none, .toggle => {},
            .scalar => |value| try value.validate(),
            .path => |value| try value.validate(),
        }
    }
};

/// MonitorName owns one bounded copied monitor name for a resident leaf.
pub const MonitorName = struct {
    /// bytes owns the fixed monitor-name storage.
    bytes: [max_monitor_name_bytes]u8 = undefined,
    /// length is the initialized byte count in bytes.
    length: usize = 0,

    /// init copies and validates one monitor name.
    pub fn init(name: []const u8) InputError!MonitorName {
        if (name.len == 0) return error.MonitorEmpty;
        if (name.len > max_monitor_name_bytes) return error.MonitorTooLong;
        if (hasInvalidPathByte(name)) return error.MonitorByteInvalid;

        var result = MonitorName{};
        @memcpy(result.bytes[0..name.len], name);
        result.length = name.len;
        return result;
    }

    /// validate proves the copied monitor name remains bounded and printable.
    pub fn validate(self: MonitorName) InputError!void {
        if (self.length == 0) return error.MonitorEmpty;
        if (self.length > max_monitor_name_bytes) return error.MonitorTooLong;
        if (hasInvalidPathByte(self.slice())) return error.MonitorByteInvalid;
    }

    /// slice returns the owned monitor name.
    pub fn slice(self: *const MonitorName) []const u8 {
        return self.bytes[0..self.length];
    }
};

/// Row stores one bounded display record and its terminal Input contract.
/// Display slices are borrowed from the producer; Input values are copied.
pub const Row = struct {
    /// title is a borrowed display string.
    title: []const u8,
    /// subtitle is a borrowed explanatory string.
    subtitle: []const u8,
    /// open is a borrowed stable route or executable payload.
    open: []const u8,
    /// icon is a borrowed optional application icon name.
    icon: []const u8 = "",
    /// input is the copied terminal value contract.
    input: Input = .none,
};

/// ActionLeaf carries Input.none for a resident action leaf.
pub const ActionLeaf = struct {
    /// input is Input.none for an action-only lifecycle leaf.
    input: Input,
};

/// MonitorLeaf owns one monitor name and one validated typed Input value.
pub const MonitorLeaf = struct {
    /// monitor owns the copied monitor selector.
    monitor: MonitorName,
    /// input owns the typed value accepted by the operation.
    input: Input,
};

/// Lifecycle is the exact nine-arm resident leaf vocabulary.
/// Action arms own Input.none; monitor arms own copied monitor and typed Input
/// values. Validation rejects a leaf before any process intent is produced.
pub const Lifecycle = union(enum) {
    /// notifications_restart selects the notification resident owner.
    notifications_restart: ActionLeaf,
    /// wallpaper_restart selects the wallpaper resident owner.
    wallpaper_restart: ActionLeaf,
    /// wallpaper_rotate selects one direct wallpaper rotation.
    wallpaper_rotate: ActionLeaf,
    /// sunglasses_restart selects the sunglasses resident owner.
    sunglasses_restart: ActionLeaf,
    /// sunglasses_apply applies persisted sunglasses state.
    sunglasses_apply: ActionLeaf,
    /// sunglasses_reconcile reconciles persisted state with current monitors.
    sunglasses_reconcile: ActionLeaf,
    /// sunglasses_dim carries a bounded monitor and scalar or toggle Input.
    sunglasses_dim: MonitorLeaf,
    /// sunglasses_filter carries a bounded monitor and scalar or toggle Input.
    sunglasses_filter: MonitorLeaf,
    /// sunglasses_image carries a bounded monitor and image Input.
    sunglasses_image: MonitorLeaf,

    /// input returns the typed value carried by the active leaf.
    pub fn input(self: Lifecycle) Input {
        return switch (self) {
            .notifications_restart => |value| value.input,
            .wallpaper_restart => |value| value.input,
            .wallpaper_rotate => |value| value.input,
            .sunglasses_restart => |value| value.input,
            .sunglasses_apply => |value| value.input,
            .sunglasses_reconcile => |value| value.input,
            .sunglasses_dim => |value| value.input,
            .sunglasses_filter => |value| value.input,
            .sunglasses_image => |value| value.input,
        };
    }

    /// validate proves the active resident leaf owns the accepted Input shape.
    pub fn validate(self: Lifecycle) InputError!void {
        switch (self) {
            .notifications_restart => |value| try requireNone(value.input),
            .wallpaper_restart => |value| try requireNone(value.input),
            .wallpaper_rotate => |value| try requireNone(value.input),
            .sunglasses_restart => |value| try requireNone(value.input),
            .sunglasses_apply => |value| try requireNone(value.input),
            .sunglasses_reconcile => |value| try requireNone(value.input),
            .sunglasses_dim => |value| {
                try value.monitor.validate();
                try validateScalarOrToggle(value.input, 0, 100, 1);
            },
            .sunglasses_filter => |value| {
                try value.monitor.validate();
                try validateScalarOrToggle(value.input, -100, 100, 1);
            },
            .sunglasses_image => |value| {
                try value.monitor.validate();
                try validateImageInput(value.input);
            },
        }
    }
};

/// Concrete is the exact terminal union consumed after route selection.
/// Apps own app and open rows, resident modes own lifecycle leaves, and
/// notification history owns display-only rows. Every arm validates its Input
/// policy before resolution; notification has no launch failure path.
pub const Concrete = union(enum) {
    /// app is one launchable installed application leaf.
    app: Row,
    /// open is one launchable file, URL, or direct open leaf.
    open: Row,
    /// lifecycle is one typed resident leaf intent.
    lifecycle: Lifecycle,
    /// notification is display-only and rejected at selection and launch.
    notification: Row,

    /// input returns the typed value contract of the active leaf.
    pub fn input(self: Concrete) Input {
        return switch (self) {
            .app, .open, .notification => |value| value.input,
            .lifecycle => |value| value.input(),
        };
    }

    /// isLaunchable reports whether selection may produce a process intent.
    pub fn isLaunchable(self: Concrete) bool {
        return switch (self) {
            .app, .open, .lifecycle => true,
            .notification => false,
        };
    }

    /// validate proves the active terminal leaf's Input policy.
    pub fn validate(self: Concrete) InputError!void {
        switch (self) {
            .app => |value| try requireNone(value.input),
            .open => |value| try requireNone(value.input),
            .lifecycle => |value| try value.validate(),
            .notification => |value| try requireNone(value.input),
        }
    }
};

/// Candidate is one next reachable node: a SubCmd route or Concrete leaf.
pub const Candidate = union(enum) {
    /// sub_cmd is the next route node and is selected without launching.
    sub_cmd: sub_cmd.SubCmd,
    /// concrete is one terminal typed leaf.
    concrete: Concrete,

    /// List stores a fixed candidate collection and borrows display strings.
    pub const List = struct {
        /// items is fixed candidate storage.
        items: [max_candidates]Candidate = undefined,
        /// count is the initialized item count.
        count: usize = 0,

        pub const empty = List{};

        /// append publishes one candidate within the fixed bound.
        pub fn append(self: *List, value: Candidate) !void {
            if (self.count >= max_candidates) return error.TooManyCandidates;
            self.items[self.count] = value;
            self.count += 1;
        }

        /// slice exposes only initialized candidates.
        pub fn slice(self: *const List) []const Candidate {
            return self.items[0..self.count];
        }

        /// clearRetainingCapacity forgets records without releasing producers.
        pub fn clearRetainingCapacity(self: *List) void {
            self.count = 0;
        }

        /// deinit clears borrowed records; producers release their own strings.
        pub fn deinit(self: *List) void {
            self.* = .empty;
        }
    };

    /// accepts applies boundary policy without storing a parallel candidate tag.
    pub fn accepts(boundary: enum { query, selection, open, bash_completion }, value: Candidate) bool {
        return switch (boundary) {
            .query => true,
            .selection => switch (value) {
                .sub_cmd => true,
                .concrete => |leaf| leaf.isLaunchable(),
            },
            .open => switch (value) {
                .sub_cmd => false,
                .concrete => |leaf| leaf.isLaunchable(),
            },
            .bash_completion => switch (value) {
                .sub_cmd => true,
                .concrete => |leaf| leaf.isLaunchable(),
            },
        };
    }

    /// subCmd creates one reachable route node.
    pub fn subCmd(value: sub_cmd.SubCmd) Candidate {
        return .{ .sub_cmd = value };
    }

    /// appLeaf creates one launchable application leaf with Input.none.
    pub fn appLeaf(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8, icon: []const u8) Candidate {
        return .{ .concrete = .{ .app = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload, .icon = icon } } };
    }

    /// openLeaf creates one launchable direct-open leaf with Input.none.
    pub fn openLeaf(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8, icon: []const u8) Candidate {
        return .{ .concrete = .{ .open = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload, .icon = icon } } };
    }

    /// notificationLeaf creates one display-only history leaf.
    pub fn notificationLeaf(title_text: []const u8, subtitle_text: []const u8, open_payload: []const u8) Candidate {
        return .{ .concrete = .{ .notification = .{ .title = title_text, .subtitle = subtitle_text, .open = open_payload } } };
    }

    /// lifecycleLeaf creates one typed resident leaf.
    pub fn lifecycleLeaf(value: Lifecycle) Candidate {
        return .{ .concrete = .{ .lifecycle = value } };
    }

    /// typeOf returns the active union tag; no parallel tag is stored.
    pub fn typeOf(self: Candidate) std.meta.Tag(Candidate) {
        return std.meta.activeTag(self);
    }

    /// concreteValue returns the terminal value or null for a route node.
    pub fn concreteValue(self: Candidate) ?Concrete {
        return switch (self) {
            .sub_cmd => null,
            .concrete => |value| value,
        };
    }

    /// isApp reports whether the terminal leaf is an application.
    pub fn isApp(self: Candidate) bool {
        return switch (self) {
            .sub_cmd => false,
            .concrete => |value| switch (value) {
                .app => true,
                .open, .lifecycle, .notification => false,
            },
        };
    }

    /// isOpen reports whether the terminal leaf is a direct-open value.
    pub fn isOpen(self: Candidate) bool {
        return switch (self) {
            .sub_cmd => false,
            .concrete => |value| switch (value) {
                .open => true,
                .app, .lifecycle, .notification => false,
            },
        };
    }

    /// isSubCmd reports whether selection enters another route list.
    pub fn isSubCmd(self: Candidate) bool {
        return switch (self) {
            .sub_cmd => true,
            .concrete => false,
        };
    }

    /// isLaunchable reports whether the candidate can produce a process intent.
    pub fn isLaunchable(self: Candidate) bool {
        return switch (self) {
            .sub_cmd => false,
            .concrete => |value| value.isLaunchable(),
        };
    }

    /// validate proves a terminal leaf before resolution.
    pub fn validate(self: Candidate) InputError!void {
        switch (self) {
            .sub_cmd => {},
            .concrete => |value| try value.validate(),
        }
    }

    /// row returns the display record for either route or terminal value.
    pub fn row(self: Candidate) Row {
        return switch (self) {
            .sub_cmd => |value| subCmdRow(value),
            .concrete => |value| concreteRow(value),
        };
    }

    /// title returns the bounded display title.
    pub fn title(self: Candidate) []const u8 {
        return self.row().title;
    }

    /// subtitle returns the bounded display subtitle.
    pub fn subtitle(self: Candidate) []const u8 {
        return self.row().subtitle;
    }

    /// openPayload returns the stable route identity or executable payload.
    pub fn openPayload(self: Candidate) []const u8 {
        return self.row().open;
    }

    /// routeQuery returns the GUI query that reaches this SubCmd node.
    /// Concrete leaves have no child route and return null.
    pub fn routeQuery(self: Candidate) ?[]const u8 {
        return switch (self) {
            .sub_cmd => |value| subCmdQuery(value),
            .concrete => null,
        };
    }

    /// iconName returns the optional application icon name.
    pub fn iconName(self: Candidate) []const u8 {
        return self.row().icon;
    }

    /// input returns the selected terminal Input or none for a route node.
    pub fn input(self: Candidate) Input {
        return switch (self) {
            .sub_cmd => .none,
            .concrete => |value| value.input(),
        };
    }
};

/// notificationsRestart constructs the notification restart leaf.
pub fn notificationsRestart() Lifecycle {
    return .{ .notifications_restart = .{ .input = .none } };
}

/// wallpaperRestart constructs the wallpaper restart leaf.
pub fn wallpaperRestart() Lifecycle {
    return .{ .wallpaper_restart = .{ .input = .none } };
}

/// wallpaperRotate constructs the direct wallpaper rotation leaf.
pub fn wallpaperRotate() Lifecycle {
    return .{ .wallpaper_rotate = .{ .input = .none } };
}

/// sunglassesRestart constructs the sunglasses restart leaf.
pub fn sunglassesRestart() Lifecycle {
    return .{ .sunglasses_restart = .{ .input = .none } };
}

/// sunglassesApply constructs the persisted-state apply leaf.
pub fn sunglassesApply() Lifecycle {
    return .{ .sunglasses_apply = .{ .input = .none } };
}

/// sunglassesReconcile constructs the saved-state reconciliation leaf.
pub fn sunglassesReconcile() Lifecycle {
    return .{ .sunglasses_reconcile = .{ .input = .none } };
}

/// sunglassesDim constructs a bounded dim leaf from scalar or toggle Input.
pub fn sunglassesDim(monitor: []const u8, value: Input) InputError!Lifecycle {
    const bounded_monitor = try validateMonitorInput(monitor, value, .dim);
    return .{ .sunglasses_dim = .{ .monitor = bounded_monitor, .input = value } };
}

/// sunglassesFilter constructs a bounded filter leaf from scalar or toggle Input.
pub fn sunglassesFilter(monitor: []const u8, value: Input) InputError!Lifecycle {
    const bounded_monitor = try validateMonitorInput(monitor, value, .filter);
    return .{ .sunglasses_filter = .{ .monitor = bounded_monitor, .input = value } };
}

/// sunglassesImage constructs a bounded image leaf from none, scalar, toggle, or path Input.
pub fn sunglassesImage(monitor: []const u8, value: Input) InputError!Lifecycle {
    const bounded_monitor = try validateMonitorInput(monitor, value, .image);
    return .{ .sunglasses_image = .{ .monitor = bounded_monitor, .input = value } };
}

fn validateMonitorInput(monitor: []const u8, value: Input, policy: enum { dim, filter, image }) InputError!MonitorName {
    const bounded_monitor = try MonitorName.init(monitor);
    switch (policy) {
        .dim => try validateScalarOrToggle(value, 0, 100, 1),
        .filter => try validateScalarOrToggle(value, -100, 100, 1),
        .image => try validateImageInput(value),
    }
    return bounded_monitor;
}

fn validateScalarOrToggle(value: Input, min: i32, max: i32, step: i32) InputError!void {
    switch (value) {
        .scalar => |scalar| try scalar.validateFor(min, max, step),
        .toggle => {},
        .none, .path => return error.InputNotAccepted,
    }
}

fn validateImageInput(value: Input) InputError!void {
    switch (value) {
        .none, .toggle => {},
        .scalar => |scalar| try scalar.validateFor(0, 100, 1),
        .path => |path| try path.validate(),
    }
}

fn requireNone(value: Input) InputError!void {
    return switch (value) {
        .none => {},
        .scalar, .toggle, .path => error.InputNotAccepted,
    };
}

fn concreteRow(value: Concrete) Row {
    return switch (value) {
        .app, .open, .notification => |row| row,
        .lifecycle => |leaf| lifecycleRow(leaf),
    };
}

fn lifecycleRow(value: Lifecycle) Row {
    return switch (value) {
        .notifications_restart => .{ .title = "Restart notifications", .subtitle = "Lifecycle", .open = "lifecycle:notifications:restart" },
        .wallpaper_restart => .{ .title = "Restart wallpaper", .subtitle = "Lifecycle", .open = "lifecycle:wallpapers:restart" },
        .wallpaper_rotate => .{ .title = "Rotate wallpaper", .subtitle = "Lifecycle", .open = "wayspot wallpaper rotate" },
        .sunglasses_restart => .{ .title = "Restart sunglasses", .subtitle = "Lifecycle", .open = "lifecycle:sunglasses:restart" },
        .sunglasses_apply => .{ .title = "Apply sunglasses", .subtitle = "Lifecycle", .open = "wayspot sunglasses apply" },
        .sunglasses_reconcile => .{ .title = "Reconcile sunglasses", .subtitle = "Lifecycle", .open = "wayspot sunglasses reconcile" },
        .sunglasses_dim => |leaf| .{ .title = "Dim sunglasses", .subtitle = "Scalar or toggle", .open = "wayspot sunglasses dim", .input = leaf.input },
        .sunglasses_filter => |leaf| .{ .title = "Filter sunglasses", .subtitle = "Scalar or toggle", .open = "wayspot sunglasses filter", .input = leaf.input },
        .sunglasses_image => |leaf| .{ .title = "Image sunglasses", .subtitle = "Path, scalar, toggle, or none", .open = "wayspot sunglasses image", .input = leaf.input },
    };
}

fn subCmdRow(value: sub_cmd.SubCmd) Row {
    return switch (value) {
        .notifications => |child| switch (child) {
            .history => .{ .title = "Notification history", .subtitle = "Route", .open = "/notifications history" },
            .restart => .{ .title = "Notifications", .subtitle = "Mode", .open = "wayspot notifications" },
        },
        .wallpaper => |child| switch (child) {
            .restart => .{ .title = "Wallpaper", .subtitle = "Mode", .open = "wayspot wallpaper" },
            .rotate => .{ .title = "Rotate wallpaper", .subtitle = "Lifecycle", .open = "wayspot wallpaper rotate" },
        },
        .sunglasses => |child| switch (child) {
            .restart => .{ .title = "Sunglasses", .subtitle = "Mode", .open = "wayspot sunglasses" },
            .apply => .{ .title = "Apply sunglasses", .subtitle = "Lifecycle", .open = "wayspot sunglasses apply" },
            .reconcile => .{ .title = "Reconcile sunglasses", .subtitle = "Lifecycle", .open = "wayspot sunglasses reconcile" },
            .dim => |operation| switch (operation) {
                .set => .{ .title = "Set sunglasses dim", .subtitle = "Slider", .open = "wayspot sunglasses dim" },
                .on => .{ .title = "Enable sunglasses dim", .subtitle = "Toggle", .open = "wayspot sunglasses dim" },
                .off => .{ .title = "Disable sunglasses dim", .subtitle = "Toggle", .open = "wayspot sunglasses dim" },
            },
            .filter => |operation| switch (operation) {
                .set => .{ .title = "Set sunglasses filter", .subtitle = "Slider", .open = "wayspot sunglasses filter" },
                .on => .{ .title = "Enable sunglasses filter", .subtitle = "Toggle", .open = "wayspot sunglasses filter" },
                .off => .{ .title = "Disable sunglasses filter", .subtitle = "Toggle", .open = "wayspot sunglasses filter" },
            },
            .image => |operation| switch (operation) {
                .set => .{ .title = "Set sunglasses image", .subtitle = "Path", .open = "wayspot sunglasses image" },
                .opacity => .{ .title = "Set sunglasses image opacity", .subtitle = "Slider", .open = "wayspot sunglasses image" },
                .on => .{ .title = "Enable sunglasses image", .subtitle = "Toggle", .open = "wayspot sunglasses image" },
                .off => .{ .title = "Disable sunglasses image", .subtitle = "Toggle", .open = "wayspot sunglasses image" },
                .clear => .{ .title = "Clear sunglasses image", .subtitle = "Action", .open = "wayspot sunglasses image" },
            },
        },
    };
}

fn subCmdQuery(value: sub_cmd.SubCmd) []const u8 {
    return switch (value) {
        .notifications => |child| switch (child) {
            .history => "/notifications history",
            .restart => "/notifications",
        },
        .wallpaper => |child| switch (child) {
            .restart => "/wallpapers",
            .rotate => "/wallpapers rotate",
        },
        .sunglasses => |child| switch (child) {
            .restart => "/sunglasses",
            .apply => "/sunglasses apply",
            .reconcile => "/sunglasses reconcile",
            .dim => "/sunglasses dim",
            .filter => "/sunglasses filter",
            .image => "/sunglasses image",
        },
    };
}

fn hasInvalidPathByte(value: []const u8) bool {
    for (value) |byte| {
        if (byte < ' ' or byte == 0x7f) return true;
    }
    return false;
}

comptime {
    assertUnionFields(Input, &.{ "none", "scalar", "toggle", "path" });
    assertUnionFields(Lifecycle, &.{
        "notifications_restart",
        "wallpaper_restart",
        "wallpaper_rotate",
        "sunglasses_restart",
        "sunglasses_apply",
        "sunglasses_reconcile",
        "sunglasses_dim",
        "sunglasses_filter",
        "sunglasses_image",
    });
    assertUnionFields(Concrete, &.{ "app", "open", "lifecycle", "notification" });
    assertUnionFields(Candidate, &.{ "sub_cmd", "concrete" });
    std.debug.assert(max_candidates > 0);
}

fn assertUnionFields(comptime Union: type, comptime names: []const []const u8) void {
    const fields = std.meta.fields(Union);
    std.debug.assert(fields.len == names.len);
    inline for (names, 0..) |name, index| {
        std.debug.assert(std.mem.eql(u8, fields[index].name, name));
    }
}

test "Input and terminal union vocabulary is closed" {
    try std.testing.expectEqual(@as(usize, 4), std.meta.fields(Input).len);
    try std.testing.expectEqual(@as(usize, 9), std.meta.fields(Lifecycle).len);
    try std.testing.expectEqual(@as(usize, 4), std.meta.fields(Concrete).len);
    try std.testing.expectEqual(@as(usize, 2), std.meta.fields(Candidate).len);
}

test "scalar input enforces range and step" {
    const value = try ScalarInput.init(35, 0, 100, 1);
    try value.validateFor(0, 100, 1);
    try std.testing.expectError(error.ScalarOutOfBounds, ScalarInput.init(101, 0, 100, 1));
    try std.testing.expectError(error.ScalarStepInvalid, ScalarInput.init(35, 0, 100, 0));
    try std.testing.expectError(error.ScalarRangeMismatch, value.validateFor(-100, 100, 1));
}

test "scalar input enforces signed grid alignment and exact endpoints" {
    const positive_aligned = try ScalarInput.init(30, 0, 100, 10);
    const positive_min = try ScalarInput.init(0, 0, 100, 10);
    const positive_max = try ScalarInput.init(100, 0, 100, 10);
    const negative_aligned = try ScalarInput.init(-90, -100, -10, 10);
    const negative_min = try ScalarInput.init(-100, -100, -10, 10);
    const negative_max = try ScalarInput.init(-10, -100, -10, 10);

    try positive_aligned.validate();
    try positive_min.validate();
    try positive_max.validate();
    try negative_aligned.validate();
    try negative_min.validate();
    try negative_max.validate();
    try std.testing.expectError(error.ScalarValueMisaligned, ScalarInput.init(35, 0, 100, 10));
    try std.testing.expectError(error.ScalarValueMisaligned, ScalarInput.init(-95, -100, -10, 10));
}

test "toggle input preserves exact on and off values" {
    const on = Input.toggleInput(true);
    const off = Input.toggleInput(false);
    try std.testing.expect(on.toggle.enabled);
    try std.testing.expect(!off.toggle.enabled);
}

test "path input owns a bounded absolute copy" {
    var source = [_]u8{ '/', 't', 'm', 'p', '/', 'a', '.', 'p', 'n', 'g' };
    const input = try PathInput.init(source[0..]);
    source[5] = 'x';
    try std.testing.expectEqualStrings("/tmp/a.png", input.slice());
    try std.testing.expectError(error.PathNotAbsolute, PathInput.init("relative.png"));
    try std.testing.expectError(error.PathByteInvalid, PathInput.init("/tmp/a\n.png"));

    var overlong: [max_image_path_bytes + 1]u8 = undefined;
    @memset(&overlong, 'a');
    overlong[0] = '/';
    try std.testing.expectError(error.PathTooLong, PathInput.init(&overlong));
}

test "typed sunglasses leaves validate operation-specific Input" {
    const dim_value = try Input.scalarInput(35, 0, 100, 1);
    const dim = try sunglassesDim("DP-1", dim_value);
    try std.testing.expectEqual(std.meta.Tag(Lifecycle).sunglasses_dim, std.meta.activeTag(dim));
    try std.testing.expectEqualStrings("DP-1", dim.sunglasses_dim.monitor.slice());

    const filter = try sunglassesFilter("DP-1", Input.toggleInput(true));
    try std.testing.expectEqual(std.meta.Tag(Lifecycle).sunglasses_filter, std.meta.activeTag(filter));

    const image_path = try Input.pathInput("/tmp/sunglasses.png");
    const image = try sunglassesImage("DP-1", image_path);
    try std.testing.expectEqual(std.meta.Tag(Lifecycle).sunglasses_image, std.meta.activeTag(image));

    try std.testing.expectError(error.InputNotAccepted, sunglassesDim("DP-1", image_path));
    try std.testing.expectError(error.ScalarRangeMismatch, sunglassesFilter("DP-1", dim_value));
    try std.testing.expectError(error.MonitorEmpty, sunglassesDim("", dim_value));
    try std.testing.expectError(error.MonitorByteInvalid, sunglassesDim("DP-1\n", dim_value));
}

test "action lifecycle leaves carry Input.none" {
    const leaves = [_]Lifecycle{
        notificationsRestart(),
        wallpaperRestart(),
        wallpaperRotate(),
        sunglassesRestart(),
        sunglassesApply(),
        sunglassesReconcile(),
    };
    for (leaves) |leaf| {
        try leaf.validate();
        try std.testing.expectEqual(std.meta.Tag(Input).none, std.meta.activeTag(leaf.input()));
    }
}

test "Concrete notification is display-only and lifecycle carries Input" {
    const leaf = Candidate.lifecycleLeaf(try sunglassesDim("DP-1", Input.toggleInput(false)));
    try std.testing.expectEqual(std.meta.Tag(Candidate).concrete, leaf.typeOf());
    try std.testing.expect(leaf.concreteValue().?.isLaunchable());
    try std.testing.expectEqual(std.meta.Tag(Input).toggle, std.meta.activeTag(leaf.input()));

    const notification = Candidate.notificationLeaf("Summary", "App", "notification-history:0:1");
    try std.testing.expect(!notification.concreteValue().?.isLaunchable());
    try std.testing.expect(!Candidate.accepts(.selection, notification));
}

test "Candidate boundary policy covers every Concrete arm" {
    const route = Candidate.subCmd(.{ .notifications = .{ .history = {} } });
    const app = Candidate.appLeaf("Kitty", "Terminal", "kitty", "");
    const open = Candidate.openLeaf("Settings", "System", "settings", "");
    const lifecycle = Candidate.lifecycleLeaf(sunglassesRestart());
    const notification = Candidate.notificationLeaf("Summary", "App", "notification-history:0:1");

    try std.testing.expect(Candidate.accepts(.query, route));
    try std.testing.expect(Candidate.accepts(.query, app));
    try std.testing.expect(Candidate.accepts(.query, open));
    try std.testing.expect(Candidate.accepts(.query, lifecycle));
    try std.testing.expect(Candidate.accepts(.query, notification));
    try std.testing.expect(Candidate.accepts(.selection, route));
    try std.testing.expect(Candidate.accepts(.selection, app));
    try std.testing.expect(Candidate.accepts(.selection, open));
    try std.testing.expect(Candidate.accepts(.selection, lifecycle));
    try std.testing.expect(!Candidate.accepts(.selection, notification));
    try std.testing.expect(!Candidate.accepts(.open, route));
    try std.testing.expect(Candidate.accepts(.open, app));
    try std.testing.expect(Candidate.accepts(.open, open));
    try std.testing.expect(Candidate.accepts(.open, lifecycle));
    try std.testing.expect(!Candidate.accepts(.open, notification));
    try std.testing.expect(Candidate.accepts(.bash_completion, route));
    try std.testing.expect(Candidate.accepts(.bash_completion, app));
    try std.testing.expect(Candidate.accepts(.bash_completion, open));
    try std.testing.expect(Candidate.accepts(.bash_completion, lifecycle));
    try std.testing.expect(!Candidate.accepts(.bash_completion, notification));
}

test "candidate route preserves nested SubCmd without embedding Input" {
    const route = Candidate.subCmd(.{ .sunglasses = .{ .dim = .{ .set = {} } } });
    try std.testing.expectEqual(std.meta.Tag(Candidate).sub_cmd, route.typeOf());
    try std.testing.expectEqualStrings("wayspot sunglasses dim", route.openPayload());
    try std.testing.expectEqualStrings("/sunglasses dim", route.routeQuery().?);
    const selected = switch (route) {
        .sub_cmd => |value| value.sunglasses,
        .concrete => unreachable,
    };
    try std.testing.expectEqual(std.meta.Tag(sub_cmd.SunglassesSubCmd).dim, std.meta.activeTag(selected));
}

test "resident mode SubCmd values expose typed route queries" {
    const routes = [_]Candidate{
        Candidate.subCmd(.{ .notifications = .{ .restart = {} } }),
        Candidate.subCmd(.{ .wallpaper = .{ .restart = {} } }),
        Candidate.subCmd(.{ .sunglasses = .{ .restart = {} } }),
    };
    const expected = [_][]const u8{ "/notifications", "/wallpapers", "/sunglasses" };
    for (routes, expected) |route, query| {
        try std.testing.expectEqualStrings(query, route.routeQuery().?);
    }
}

test "every declared SubCmd route is reachable by a query" {
    const routes = [_]Candidate{
        Candidate.subCmd(.{ .notifications = .{ .history = {} } }),
        Candidate.subCmd(.{ .notifications = .{ .restart = {} } }),
        Candidate.subCmd(.{ .wallpaper = .{ .restart = {} } }),
        Candidate.subCmd(.{ .wallpaper = .{ .rotate = {} } }),
        Candidate.subCmd(.{ .sunglasses = .{ .restart = {} } }),
        Candidate.subCmd(.{ .sunglasses = .{ .apply = {} } }),
        Candidate.subCmd(.{ .sunglasses = .{ .reconcile = {} } }),
        Candidate.subCmd(.{ .sunglasses = .{ .dim = .{ .set = {} } } }),
        Candidate.subCmd(.{ .sunglasses = .{ .filter = .{ .off = {} } } }),
        Candidate.subCmd(.{ .sunglasses = .{ .image = .{ .opacity = {} } } }),
    };
    for (routes) |route| {
        try std.testing.expect(route.routeQuery() != null);
    }
}

test "candidate list rejects records beyond its fixed capacity" {
    var list = Candidate.List.empty;
    var index: usize = 0;
    while (index < max_candidates) : (index += 1) {
        try list.append(Candidate.appLeaf("App", "Utility", "app", ""));
    }
    try std.testing.expectError(error.TooManyCandidates, list.append(Candidate.appLeaf("Overflow", "Utility", "overflow", "")));
    try std.testing.expectEqual(max_candidates, list.count);
}

test "candidate list cleanup does not claim producer string ownership" {
    var title = [_]u8{ 'A', 'p', 'p' };
    var list = Candidate.List.empty;
    try list.append(Candidate.appLeaf(title[0..], "Utility", "app", ""));
    list.deinit();
    try std.testing.expectEqualStrings("App", title[0..]);
}
