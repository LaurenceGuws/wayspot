//! C-free Hyprland wire simulation through the real parser boundary.

const std = @import("std");
const io = @import("hyprland_io");
const env = @import("wayspot_env");
const hyprland = @import("wayspot_env").hyprland;

fn requestChunk(text: []const u8) io.RequestRead {
    var chunk = io.RequestChunk{};
    @memcpy(chunk.bytes[0..text.len], text);
    chunk.len = @intCast(text.len);
    return .{ .chunk = chunk };
}

fn appendRequest(
    transcript: *io.SocketTranscript,
    id: io.SocketId,
    path: io.SocketPath,
    name: io.RequestName,
    response: []const u8,
) !void {
    const request = io.RequestWrite.fromName(name);
    const response_index = try transcript.addRequestRead(requestChunk(response));
    const eof_index = try transcript.addRequestRead(.eof);
    try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .socket = id } });
    try transcript.append(.{ .kind = .connect, .socket_id = id, .path = path });
    try transcript.append(.{
        .kind = .write,
        .socket_id = id,
        .request = request,
        .result = .{ .write_count = request.len },
    });
    try transcript.append(.{ .kind = .read_request, .socket_id = id, .result = .{ .request_read = response_index } });
    try transcript.append(.{ .kind = .read_request, .socket_id = id, .result = .{ .request_read = eof_index } });
    try transcript.append(.{ .kind = .close, .socket_id = id });
}

test "C-free transcript drives the Hyprland monitor request parser" {
    var transcript = io.SocketTranscript.init(std.testing.allocator);
    const id = try io.SocketId.init(1);
    const connection = hyprland.Connection{ .runtime_dir = "/run/user/1000", .signature = "instance" };
    const path = try io.SocketPath.init("/run/user/1000/hypr/instance/.socket.sock");
    const request = io.RequestWrite.fromName(.monitors);
    const response_index = try transcript.addRequestRead(requestChunk(
        "[{\"id\":1,\"name\":\"DP-1\",\"width\":1920,\"height\":1080}]",
    ));
    const eof_index = try transcript.addRequestRead(.eof);
    try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .socket = id } });
    try transcript.append(.{ .kind = .connect, .socket_id = id, .path = path });
    try transcript.append(.{
        .kind = .write,
        .socket_id = id,
        .request = request,
        .result = .{ .write_count = request.len },
    });
    try transcript.append(.{ .kind = .read_request, .socket_id = id, .result = .{ .request_read = response_index } });
    try transcript.append(.{ .kind = .read_request, .socket_id = id, .result = .{ .request_read = eof_index } });
    try transcript.append(.{ .kind = .close, .socket_id = id });

    const monitors = try hyprland.queryMonitorsWith(
        io.SocketTranscript,
        std.testing.allocator,
        &transcript,
        connection,
    );
    try transcript.assertComplete();
    transcript.deinit();
    try std.testing.expectEqual(@as(u32, 1), monitors.count);
    try std.testing.expectEqualStrings("DP-1", monitors.items[0].nameText());
}

test "pure roots expose only the two concrete source compositions" {
    _ = env.MonitorSourceWith(io.SocketTranscript);
    _ = env.MonitorFactStreamWith(io.SocketTranscript);
}

test "pure owner reconnects through one transcript and honors the borrowed stop" {
    var transcript = io.SocketTranscript.init(std.testing.allocator);
    const first_id = try io.SocketId.init(1);
    const second_id = try io.SocketId.init(2);
    const stop = try io.StopId.fromFd(0);
    const connection = env.Connection{
        .runtime_dir = "/run/user/1000",
        .signature = "instance",
    };
    const path = try io.SocketPath.init("/run/user/1000/hypr/instance/.socket2.sock");
    const first_poll = try transcript.addPollResult(.{ .event = .closed, .stop = .idle });
    const reconnect_poll = try transcript.addPollResult(.{ .event = null, .stop = .idle });
    const stop_poll = try transcript.addPollResult(.{ .event = .idle, .stop = .readable });
    const event_set = io.PollSet{ .event = first_id, .stop = stop, .timeout = io.PollTimeout.infinite() };
    const reconnect_set = io.PollSet{
        .event = null,
        .stop = stop,
        .timeout = try io.PollTimeout.fromMilliseconds(1000),
    };
    const stop_set = io.PollSet{ .event = second_id, .stop = stop, .timeout = io.PollTimeout.infinite() };

    try transcript.append(.{ .kind = .socket, .socket_kind = .event, .result = .{ .socket = first_id } });
    try transcript.append(.{ .kind = .connect, .socket_id = first_id, .path = path });
    try transcript.append(.{ .kind = .poll, .poll_set = event_set, .result = .{ .poll_result = first_poll } });
    try transcript.append(.{ .kind = .close, .socket_id = first_id });
    try transcript.append(.{ .kind = .poll, .poll_set = reconnect_set, .result = .{ .poll_result = reconnect_poll } });
    try transcript.append(.{ .kind = .socket, .socket_kind = .event, .result = .{ .socket = second_id } });
    try transcript.append(.{ .kind = .connect, .socket_id = second_id, .path = path });
    try transcript.append(.{ .kind = .poll, .poll_set = stop_set, .result = .{ .poll_result = stop_poll } });
    try transcript.append(.{ .kind = .close, .socket_id = second_id });

    var stream = try env.MonitorFactStreamWith(io.SocketTranscript).init(
        std.testing.allocator,
        &transcript,
        connection,
    );
    try std.testing.expectEqual(.stopped, try stream.wait(stop));
    try stream.deinit();
    try transcript.assertComplete();
    transcript.deinit();
}

test "pure event wait gives a ready stop priority over a ready event" {
    var transcript = io.SocketTranscript.init(std.testing.allocator);
    const event_id = try io.SocketId.init(1);
    const stop = try io.StopId.fromFd(0);
    const connection = env.Connection{ .runtime_dir = "/run/user/1000", .signature = "instance" };
    const path = try io.SocketPath.init("/run/user/1000/hypr/instance/.socket2.sock");
    const result_index = try transcript.addPollResult(.{ .event = .readable, .stop = .readable });

    try transcript.append(.{ .kind = .socket, .socket_kind = .event, .result = .{ .socket = event_id } });
    try transcript.append(.{ .kind = .connect, .socket_id = event_id, .path = path });
    try transcript.append(.{
        .kind = .poll,
        .poll_set = .{ .event = event_id, .stop = stop, .timeout = io.PollTimeout.infinite() },
        .result = .{ .poll_result = result_index },
    });
    try transcript.append(.{ .kind = .close, .socket_id = event_id });

    var stream = try hyprland.EventStream.initWith(io.SocketTranscript, std.testing.allocator, &transcript, connection);
    try std.testing.expectEqual(
        hyprland.FactEvent.stopped,
        try stream.waitWith(io.SocketTranscript, &transcript, stop),
    );
    try stream.deinit(io.SocketTranscript, &transcript);
    try transcript.assertComplete();
    transcript.deinit();
}

test "fillState publishes no partial snapshot after a later request failure" {
    var transcript = io.SocketTranscript.init(std.testing.allocator);
    const connection = env.Connection{ .runtime_dir = "/run/user/1000", .signature = "instance" };
    const path = try io.SocketPath.init("/run/user/1000/hypr/instance/.socket.sock");
    const first_id = try io.SocketId.init(1);
    try appendRequest(
        &transcript,
        first_id,
        path,
        .monitors,
        "[{\"id\":1,\"name\":\"DP-1\",\"width\":1920,\"height\":1080}]",
    );
    try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .failure = .socket_open_failed } });

    var environment_state = env.state.EnvState{};
    var prior_monitors = env.monitor.MonitorList{};
    try prior_monitors.append(try env.monitor.Monitor.init(
        .{ .value = 9 },
        "prior",
        try env.monitor.MonitorSize.init(1, 1),
    ));
    environment_state.refreshMonitors(prior_monitors);

    try std.testing.expectError(
        error.HyprlandSocketOpenFailed,
        hyprland.fillStateWith(io.SocketTranscript, std.testing.allocator, &transcript, connection, &environment_state),
    );
    try std.testing.expectEqual(@as(u32, 1), environment_state.snapshot.monitors.count);
    try std.testing.expectEqualStrings("prior", environment_state.snapshot.monitors.items[0].nameText());
    try transcript.assertComplete();
    transcript.deinit();
}
