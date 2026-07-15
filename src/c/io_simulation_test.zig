//! Pure simulation tests for the paired SDL and Wayland typed transcripts.

const std = @import("std");
const sdl_io = @import("sdl_io");
const sunglasses_setup = @import("sunglasses_setup");
const wayland_io = @import("wayland_io");

test "sunglasses setup protocol consumes exact reverse cleanup" {
    const title = try sdl_io.WindowTitle.init("wayspot-sunglasses:DP-1");
    const size = try sdl_io.WindowSize.init(1920, 1080);
    const window_calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = title } },
        .{ .set_width = .{ .property_id = 1, .value = 1920 } },
        .{ .set_height = .{ .property_id = 1, .value = 1080 } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_resize = .{ .window_id = 1, .size = size } },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&window_calls);
    window_transcript.replies[0] = .{ .property_id = 1 };
    window_transcript.replies[7] = .{ .window_id = 1 };
    window_transcript.replies[9] = .{ .window_properties = 1 };
    window_transcript.replies[10] = .{ .wayland_handle = 1 };
    window_transcript.replies[11] = .{ .wayland_handle = 1 };

    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    layer_transcript.replies[1] = .{ .output_id = 1 };
    layer_transcript.replies[2] = .{ .layer_id = 1 };
    layer_transcript.replies[10] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
    layer_transcript.replies[13] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
    const plan = sunglasses_setup.SetupPlan.init(monitor_name, title, size);
    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    try expectComplete(&result);
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.window_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), window_transcript.property_destroy_count);
}

test "paired window transcript preserves cleanup after setup failure" {
    const title = try sdl_io.WindowTitle.init("title");
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = title } },
        .{ .property_destroy = 1 },
    };
    var transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    transcript.replies[0] = .{ .property_id = 1 };
    transcript.replies[1] = .{ .failure = error.SdlWindowFailed };
    var properties = try sdl_io.SdlWindowPropertyIo.create(&transcript);
    try std.testing.expectError(error.SdlWindowFailed, properties.setTitle(title));
    properties.deinit();
    try transcript.assertComplete();
}

test "paired layer transcript preserves globals cleanup after setup failure" {
    const monitor_name = try sdl_io.DisplayName.init("DP-1");
    const calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = .sunglasses(),
            .namespace = .sunglasses,
        } },
        .{ .globals_deinit = 1 },
    };
    var transcript = try wayland_io.WaylandTranscript.init(&calls);
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .failure = error.LayerShellSurfaceCreateFailed };
    var io = wayland_io.WaylandIo.fromTranscript(&transcript);
    try io.globalsInit(1);
    _ = try io.findOutput(monitor_name);
    try std.testing.expectError(
        error.LayerShellSurfaceCreateFailed,
        io.createLayerSurface(1, 1, .sunglasses(), .sunglasses),
    );
    try io.globalsDeinit(1);
    try transcript.assertComplete();
}

test "shared setup rolls back after a property setter failure" {
    const plan = try setupPlanForTest();
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .property_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    window_transcript.replies[0] = .{ .property_id = 1 };
    window_transcript.replies[1] = .{ .failure = error.SdlWindowFailed };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&[_]wayland_io.WaylandCall{});

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    try expectFailureAndCleanup(&result, error.SdlWindowFailed);
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.property_destroy_count);
    try std.testing.expectEqual(@as(usize, 0), window_transcript.window_destroy_count);
}

test "shared setup retries window cleanup without Wayland ids" {
    const plan = try setupPlanForTest();
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    setWindowSetupReplies(&window_transcript);
    window_transcript.replies[10] = .{ .failure = error.WaylandSurfaceUnavailable };
    window_transcript.replies[11] = .ok;
    var layer_transcript = try wayland_io.WaylandTranscript.init(&[_]wayland_io.WaylandCall{});

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    switch (result) {
        .complete => try std.testing.expect(false),
        .failure => |*failure| {
            try std.testing.expectEqual(error.WaylandSurfaceUnavailable, failure.reason);
            if (failure.cleanup) |*session| {
                try session.retryCleanup();
                try std.testing.expectError(error.WaylandIoDeinitialized, session.retryCleanup());
            } else {
                try std.testing.expect(false);
            }
        },
    }
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.window_destroy_count);
}

test "shared setup rolls back after an output failure" {
    const plan = try setupPlanForTest();
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    setWindowSetupReplies(&window_transcript);

    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    layer_transcript.replies[1] = .{ .failure = error.LayerShellOutputMissing };

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    try expectFailureAndCleanup(&result, error.LayerShellOutputMissing);
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.property_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), window_transcript.window_destroy_count);
    try std.testing.expectEqual(@as(usize, 0), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
}

test "shared setup rolls back after resize failure" {
    const plan = try setupPlanForTest();
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_resize = .{ .window_id = 1, .size = plan.size } },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    setWindowSetupReplies(&window_transcript);
    window_transcript.replies[12] = .{ .failure = error.SdlWindowSizeFailed };

    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = plan.layer,
            .namespace = plan.namespace,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = plan.size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    setLayerCreationReplies(&layer_transcript);
    setConfigureReply(&layer_transcript, 10);

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    try expectFailureAndCleanup(&result, error.SdlWindowSizeFailed);
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.property_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), window_transcript.window_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
}

test "shared setup rolls back after configure roundtrip failure" {
    const plan = try setupPlanForTest();
    const calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&calls);
    setWindowSetupReplies(&window_transcript);

    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = plan.layer,
            .namespace = plan.namespace,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = plan.size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    setLayerCreationReplies(&layer_transcript);
    layer_transcript.replies[10] = .{ .failure = error.LayerShellConfigureFailed };

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    try expectFailureAndCleanup(&result, error.LayerShellConfigureFailed);
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), window_transcript.property_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), window_transcript.window_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
}

test "shared setup retains pending layer cleanup after flush failure" {
    const plan = try setupPlanForTest();
    const window_calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_resize = .{ .window_id = 1, .size = plan.size } },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&window_calls);
    setWindowSetupReplies(&window_transcript);
    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = plan.layer,
            .namespace = plan.namespace,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = plan.size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    setLayerCreationReplies(&layer_transcript);
    setConfigureReply(&layer_transcript, 10);
    setConfigureReply(&layer_transcript, 13);
    layer_transcript.replies[15] = .{ .failure = error.WaylandCleanupOutOfOrder };

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    switch (result) {
        .complete => try std.testing.expect(false),
        .failure => |*failure| {
            try std.testing.expectEqual(error.WaylandCleanupOutOfOrder, failure.reason);
            if (failure.cleanup) |*session| {
                try std.testing.expectEqual(@as(usize, 16), layer_transcript.operation_count);
                try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
                try std.testing.expectEqual(@as(usize, 0), layer_transcript.globals_deinit_count);
                try session.retryCleanup();
                try std.testing.expectError(error.WaylandIoDeinitialized, session.retryCleanup());
            } else {
                try std.testing.expect(false);
            }
        },
    }
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
    try std.testing.expectEqual(@as(usize, 18), layer_transcript.operation_count);
}

test "shared setup retains pending globals cleanup after deinit failure" {
    const plan = try setupPlanForTest();
    const window_calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_resize = .{ .window_id = 1, .size = plan.size } },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&window_calls);
    setWindowSetupReplies(&window_transcript);
    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = plan.layer,
            .namespace = plan.namespace,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = plan.size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    setLayerCreationReplies(&layer_transcript);
    setConfigureReply(&layer_transcript, 10);
    setConfigureReply(&layer_transcript, 13);
    layer_transcript.replies[16] = .{ .failure = error.WaylandCleanupOutOfOrder };

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    switch (result) {
        .complete => try std.testing.expect(false),
        .failure => |*failure| {
            try std.testing.expectEqual(error.WaylandCleanupOutOfOrder, failure.reason);
            if (failure.cleanup) |*session| {
                try std.testing.expectEqual(@as(usize, 17), layer_transcript.operation_count);
                try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
                try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
                try session.retryCleanup();
                try std.testing.expectError(error.WaylandIoDeinitialized, session.retryCleanup());
            } else {
                try std.testing.expect(false);
            }
        },
    }
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 2), layer_transcript.globals_deinit_count);
    try std.testing.expectEqual(@as(usize, 18), layer_transcript.operation_count);
}

test "shared setup retries pending layer destruction" {
    const plan = try setupPlanForTest();
    const window_calls = [_]sdl_io.SdlWindowCall{
        .property_create,
        .{ .set_title = .{ .property_id = 1, .title = plan.title } },
        .{ .set_width = .{ .property_id = 1, .value = plan.size.width } },
        .{ .set_height = .{ .property_id = 1, .value = plan.size.height } },
        .{ .set_hidden = .{ .property_id = 1, .value = true } },
        .{ .set_custom_surface_role = .{ .property_id = 1, .value = true } },
        .{ .set_create_egl_window = .{ .property_id = 1, .value = true } },
        .{ .window_create = 1 },
        .{ .property_destroy = 1 },
        .{ .window_properties = 1 },
        .{ .wayland_display_pointer = 1 },
        .{ .wayland_surface_pointer = 1 },
        .{ .window_resize = .{ .window_id = 1, .size = plan.size } },
        .{ .window_destroy = 1 },
    };
    var window_transcript = try sdl_io.SdlWindowTranscript.init(&window_calls);
    setWindowSetupReplies(&window_transcript);
    const layer_calls = [_]wayland_io.WaylandCall{
        .{ .globals_init = 1 },
        .{ .find_output = plan.monitor_name },
        .{ .create_layer_surface = .{
            .surface_id = 1,
            .output_id = 1,
            .layer = plan.layer,
            .namespace = plan.namespace,
        } },
        .{ .add_listener = 1 },
        .{ .set_size = .{ .layer_id = 1, .size = plan.size } },
        .{ .set_anchor = .{ .layer_id = 1, .anchor = 15 } },
        .{ .set_exclusive_zone = .{ .layer_id = 1, .zone = -1 } },
        .{ .set_keyboard_interactivity = .{ .layer_id = 1, .enabled = false } },
        .{ .set_empty_input_region = 1 },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .ack_configure = .{ .layer_id = 1, .serial = 7 } },
        .{ .commit = 1 },
        .{ .roundtrip = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .destroy_layer_surface = 1 },
        .{ .roundtrip_cleanup = 1 },
        .{ .globals_deinit = 1 },
    };
    var layer_transcript = try wayland_io.WaylandTranscript.init(&layer_calls);
    setLayerCreationReplies(&layer_transcript);
    setConfigureReply(&layer_transcript, 10);
    setConfigureReply(&layer_transcript, 13);
    layer_transcript.replies[14] = .{ .failure = error.WaylandCleanupOutOfOrder };

    var result = sunglasses_setup.runTranscript(plan, &window_transcript, &layer_transcript);
    switch (result) {
        .complete => try std.testing.expect(false),
        .failure => |*failure| {
            try std.testing.expectEqual(error.WaylandCleanupOutOfOrder, failure.reason);
            if (failure.cleanup) |*session| {
                try std.testing.expectEqual(@as(usize, 15), layer_transcript.operation_count);
                try std.testing.expectEqual(@as(usize, 1), layer_transcript.layer_destroy_count);
                try session.retryCleanup();
                try std.testing.expectError(error.WaylandIoDeinitialized, session.retryCleanup());
            } else {
                try std.testing.expect(false);
            }
        },
    }
    try window_transcript.assertComplete();
    try layer_transcript.assertComplete();
    try std.testing.expectEqual(@as(usize, 2), layer_transcript.layer_destroy_count);
    try std.testing.expectEqual(@as(usize, 1), layer_transcript.globals_deinit_count);
    try std.testing.expectEqual(@as(usize, 18), layer_transcript.operation_count);
}

fn expectComplete(result: *sunglasses_setup.SetupResult) !void {
    switch (result.*) {
        .complete => {},
        .failure => try std.testing.expect(false),
    }
}

fn expectFailureAndCleanup(
    result: *sunglasses_setup.SetupResult,
    expected: sunglasses_setup.SetupError,
) !void {
    switch (result.*) {
        .complete => try std.testing.expect(false),
        .failure => |*failure| {
            try std.testing.expectEqual(expected, failure.reason);
            if (failure.cleanup) |*session| try session.retryCleanup();
        },
    }
}

fn setupPlanForTest() !sunglasses_setup.SetupPlan {
    return sunglasses_setup.SetupPlan.init(
        try sdl_io.DisplayName.init("DP-1"),
        try sdl_io.WindowTitle.init("wayspot-sunglasses:DP-1"),
        try sdl_io.WindowSize.init(1920, 1080),
    );
}

fn setWindowSetupReplies(transcript: *sdl_io.SdlWindowTranscript) void {
    transcript.replies[0] = .{ .property_id = 1 };
    transcript.replies[7] = .{ .window_id = 1 };
    transcript.replies[9] = .{ .window_properties = 1 };
    transcript.replies[10] = .{ .wayland_handle = 1 };
    transcript.replies[11] = .{ .wayland_handle = 1 };
}

fn setLayerCreationReplies(transcript: *wayland_io.WaylandTranscript) void {
    transcript.replies[1] = .{ .output_id = 1 };
    transcript.replies[2] = .{ .layer_id = 1 };
}

fn setConfigureReply(transcript: *wayland_io.WaylandTranscript, index: usize) void {
    transcript.replies[index] = .{ .configure = .{
        .configured = true,
        .closed = false,
        .serial = 7,
        .width = 1920,
        .height = 1080,
    } };
}
