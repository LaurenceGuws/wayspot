//! No-runtime reference table for every Hyprland native adapter operation.

const native = @import("hyprland_native");
const env = @import("wayspot_env_native");

/// check reaches every SocketSource entry point without opening a socket.
pub fn check() void {
    const init_fn = native.SocketSource.init;
    const deinit_fn = native.SocketSource.deinit;
    const socket_fn = native.SocketSource.socket;
    const connect_fn = native.SocketSource.connect;
    const write_fn = native.SocketSource.write;
    const request_read_fn = native.SocketSource.readRequest;
    const event_read_fn = native.SocketSource.readEvent;
    const poll_fn = native.SocketSource.poll;
    const close_fn = native.SocketSource.close;
    const source_init = env.MonitorSource.init;
    const source_deinit = env.MonitorSource.deinit;
    const source_query = env.MonitorSource.queryMonitors;
    const source_stream = env.MonitorSource.monitorStream;
    const stream_deinit = env.MonitorFactStream.deinit;
    const stream_wait = env.MonitorFactStream.wait;
    _ = .{
        init_fn,
        deinit_fn,
        socket_fn,
        connect_fn,
        write_fn,
        request_read_fn,
        event_read_fn,
        poll_fn,
        close_fn,
        source_init,
        source_deinit,
        source_query,
        source_stream,
        stream_deinit,
        stream_wait,
    };
}

pub fn main() void {
    check();
}

test "native adapter reference table is reachable" {
    check();
}
