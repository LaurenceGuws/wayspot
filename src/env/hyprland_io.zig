//! Hyprland owns the plain client socket contract and its bounded transcript.

const std = @import("std");

/// max_socket_records bounds live request and event socket identities.
pub const max_socket_records: usize = 8;
/// max_transcript_operations bounds one ordered source transcript.
pub const max_transcript_operations: usize = 2048;
/// max_request_read_steps bounds request response chunks in one transcript.
pub const max_request_read_steps: usize = 256;
/// max_event_read_steps bounds event socket chunks in one transcript.
pub const max_event_read_steps: usize = 256;
/// max_write_steps bounds partial request writes in one transcript.
pub const max_write_steps: usize = 64;
/// max_poll_steps bounds poll results in one transcript.
pub const max_poll_steps: usize = 256;
/// max_request_chunk_bytes bounds one request response read.
pub const max_request_chunk_bytes: usize = 4096;
/// max_event_chunk_bytes bounds one socket2 read.
pub const max_event_chunk_bytes: usize = 1024;
/// max_native_socket_path_bytes is the Linux sockaddr_un path storage.
pub const max_native_socket_path_bytes: usize = 108;
/// max_socket_path_bytes is the largest non-NUL pathname accepted by the adapter.
pub const max_socket_path_bytes: usize = max_native_socket_path_bytes - 1;
/// max_poll_timeout_ms bounds finite poll deadlines.
pub const max_poll_timeout_ms: i32 = 60000;

/// SocketId is a nonzero identity local to one source owner.
pub const SocketId = struct {
    /// value is never zero and is not a native file descriptor.
    value: u32,

    /// init rejects the empty local identity.
    pub fn init(value: u32) SocketIdError!SocketId {
        if (value == 0) return error.SocketIdZero;
        return .{ .value = value };
    }
};

/// StopId is a borrowed, nonnegative lifecycle token; the source never closes it.
pub const StopId = struct {
    /// value stores the caller-provided nonnegative descriptor value.
    value: u32,

    /// fromFd rejects negative values and retains no ownership of the descriptor.
    pub fn fromFd(value: i32) StopIdError!StopId {
        if (value < 0) return error.StopIdNegative;
        return .{ .value = @intCast(value) };
    }
};

/// SocketKind identifies the synchronous request or socket2 event endpoint.
pub const SocketKind = enum {
    /// request selects the synchronous JSON endpoint.
    request,
    /// event selects the socket2 event endpoint.
    event,
};

/// SocketPath owns one native-safe, NUL-terminated pathname copy.
pub const SocketPath = struct {
    /// bytes includes one terminator at bytes[len].
    bytes: [max_native_socket_path_bytes]u8 = [_]u8{0} ** max_native_socket_path_bytes,
    /// len counts non-NUL pathname bytes.
    len: u8 = 0,

    /// init accepts one to 107 non-NUL bytes and rejects embedded NULs.
    pub fn init(text: []const u8) SocketPathError!SocketPath {
        if (text.len == 0) return error.HyprlandSocketPathInvalid;
        if (text.len > max_socket_path_bytes) return error.HyprlandSocketPathTooLong;
        for (text) |byte| if (byte == 0) return error.HyprlandSocketPathInvalid;
        var path = SocketPath{};
        @memcpy(path.bytes[0..text.len], text);
        path.bytes[text.len] = 0;
        path.len = @intCast(text.len);
        return path;
    }

    /// slice returns the non-NUL pathname bytes.
    pub fn slice(self: *const SocketPath) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// RequestName is the closed request set exposed by Wayspot.
pub const RequestName = enum {
    /// monitors requests the bounded monitor JSON array.
    monitors,
    /// workspaces requests the bounded workspace JSON array.
    workspaces,
    /// clients requests the bounded client JSON array.
    clients,

    /// bytes returns the exact Hyprland JSON request.
    pub fn bytes(self: RequestName) []const u8 {
        return switch (self) {
            .monitors => "j/monitors",
            .workspaces => "j/workspaces",
            .clients => "j/clients",
        };
    }
};

/// RequestWrite owns the bounded bytes passed to one request write operation.
pub const RequestWrite = struct {
    /// bytes contains exactly one RequestName value.
    bytes: [13]u8 = [_]u8{0} ** 13,
    /// len is the initialized request byte count.
    len: u8 = 0,

    /// fromName constructs only the closed request vocabulary.
    pub fn fromName(name: RequestName) RequestWrite {
        const text = name.bytes();
        var request = RequestWrite{};
        @memcpy(request.bytes[0..text.len], text);
        request.len = @intCast(text.len);
        return request;
    }

    /// slice returns the request bytes without the spare terminator.
    pub fn slice(self: *const RequestWrite) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// RequestChunk owns one bounded response chunk.
pub const RequestChunk = struct {
    /// bytes owns the copied response data.
    bytes: [max_request_chunk_bytes]u8 = undefined,
    /// len is the initialized byte count.
    len: u16 = 0,
};

/// EventChunk owns one bounded socket2 read chunk.
pub const EventChunk = struct {
    /// bytes owns the copied socket2 data.
    bytes: [max_event_chunk_bytes]u8 = undefined,
    /// len is the initialized byte count.
    len: u16 = 0,
};

/// RequestRead distinguishes a data chunk from EOF without an invalid bytes+EOF state.
pub const RequestRead = union(enum) {
    /// chunk carries nonempty response bytes.
    chunk: RequestChunk,
    /// eof ends one synchronous response.
    eof,
};

/// EventRead distinguishes a data chunk from EOF without an invalid bytes+EOF state.
pub const EventRead = union(enum) {
    /// chunk carries nonempty socket2 bytes.
    chunk: EventChunk,
    /// eof closes the event stream.
    eof,
};

/// PollTimeout owns the one shared poll deadline representation.
pub const PollTimeout = struct {
    /// milliseconds is -1 for infinite, zero for immediate, or a bounded deadline.
    milliseconds: i32,

    /// fromMilliseconds validates the shared deadline bound.
    pub fn fromMilliseconds(milliseconds: i32) PollTimeoutError!PollTimeout {
        if (milliseconds < -1 or milliseconds > max_poll_timeout_ms) return error.PollTimeoutOutOfRange;
        return .{ .milliseconds = milliseconds };
    }

    /// infinite returns the blocking event wait deadline.
    pub fn infinite() PollTimeout {
        return .{ .milliseconds = -1 };
    }
};

/// PollState maps one native poll descriptor result without ignored bits.
pub const PollState = enum {
    /// idle means no requested descriptor is ready.
    idle,
    /// readable means input is available.
    readable,
    /// readable_hangup means input remains while the peer closed.
    readable_hangup,
    /// closed means the peer closed without readable input.
    closed,
    /// failed means an error or invalid native revents bit occurred.
    failed,
};

/// PollSet contains one optional event socket and one borrowed stop token.
pub const PollSet = struct {
    /// event is null for the reconnect stop-only poll.
    event: ?SocketId,
    /// stop is always supplied by the lifecycle owner and never closed here.
    stop: StopId,
    /// timeout is the shared bounded deadline.
    timeout: PollTimeout,
};

/// PollResult returns event state only when PollSet.event was present.
pub const PollResult = struct {
    /// event is null exactly for a stop-only poll.
    event: ?PollState,
    /// stop is always mapped from the borrowed stop token.
    stop: PollState,
};

/// Failure is the typed failure vocabulary stored by a transcript operation.
pub const Failure = enum {
    /// socket_open_failed maps a socket creation error.
    socket_open_failed,
    /// socket_connect_failed maps a connect error.
    socket_connect_failed,
    /// socket_write_failed maps a request write error.
    socket_write_failed,
    /// socket_read_failed maps a request or event read error.
    socket_read_failed,
    /// socket_close_failed maps a close error.
    socket_close_failed,
    /// socket_not_live maps use of a retired local id.
    socket_not_live,
    /// signal_interrupted maps EINTR.
    signal_interrupted,
    /// system_call_failed maps another native call failure.
    system_call_failed,
};

/// SocketOpenError is the exact source.socket error set.
pub const SocketOpenError = error{ HyprlandSocketOpenFailed, SystemCallFailed };
/// SocketConnectError is the exact source.connect error set.
pub const SocketConnectError = error{ HyprlandSocketConnectFailed, HyprlandSocketNotLive, SystemCallFailed };
/// SocketWriteError is the exact source.write error set.
pub const SocketWriteError = error{
    HyprlandSocketWriteFailed,
    HyprlandSocketNotLive,
    SignalInterrupted,
    SystemCallFailed,
};
/// SocketReadError is the exact source read error set.
pub const SocketReadError = error{
    HyprlandSocketReadFailed,
    HyprlandSocketNotLive,
    SignalInterrupted,
    SystemCallFailed,
};
/// PollError is the exact source.poll error set.
pub const PollError = error{ HyprlandSocketNotLive, SignalInterrupted, SystemCallFailed };
/// SocketCloseError is the exact source.close error set.
pub const SocketCloseError = error{ HyprlandSocketCloseFailed, HyprlandSocketNotLive, SystemCallFailed };
/// SocketIdError is the exact local identity error set.
pub const SocketIdError = error{SocketIdZero};
/// SocketPathError is the exact native pathname error set.
pub const SocketPathError = error{ HyprlandSocketPathInvalid, HyprlandSocketPathTooLong };
/// StopIdError is the exact stop token error set.
pub const StopIdError = error{StopIdNegative};
/// PollTimeoutError is the exact poll deadline error set.
pub const PollTimeoutError = error{PollTimeoutOutOfRange};
/// WriteCount is one bounded successful request write count.
pub const WriteCount = u8;

/// TranscriptError is test-harness configuration and cursor failure only.
pub const TranscriptError = error{
    TranscriptCapacityExceeded,
    TranscriptMismatch,
    TranscriptExhausted,
    TranscriptIncomplete,
    TranscriptInvalidResult,
};

/// OperationKind names every source call recorded by a transcript.
pub const OperationKind = enum {
    /// socket opens one local identity.
    socket,
    /// connect binds one local identity to a path.
    connect,
    /// write sends one canonical request.
    write,
    /// read_request reads one request response chunk.
    read_request,
    /// read_event reads one socket2 event chunk.
    read_event,
    /// poll maps event and stop readiness.
    poll,
    /// close retires one local identity.
    close,
};

/// OperationResult references one typed result slot or one injected failure.
pub const OperationResult = union(enum) {
    /// none is the successful void result.
    none,
    /// socket is the newly published local identity.
    socket: SocketId,
    /// write_count is one bounded successful write count.
    write_count: u8,
    /// request_read indexes a fixed request-read result.
    request_read: u16,
    /// event_read indexes a fixed event-read result.
    event_read: u16,
    /// poll_result indexes a fixed poll result.
    poll_result: u16,
    /// failure is the typed injected source error.
    failure: Failure,
};

/// ExpectedOperation describes one bounded source call and its typed result.
pub const ExpectedOperation = struct {
    /// kind is the exact next source operation.
    kind: OperationKind,
    /// socket_id identifies the input socket for non-open operations.
    socket_id: SocketId = .{ .value = 0 },
    /// socket_kind identifies a new request or event source.
    socket_kind: SocketKind = .request,
    /// path is checked for connect operations.
    path: SocketPath = .{},
    /// request is checked for write operations.
    request: RequestWrite = .{},
    /// poll_set is checked for poll operations.
    poll_set: PollSet = .{ .event = null, .stop = .{ .value = 0 }, .timeout = .{ .milliseconds = 0 } },
    /// result references the corresponding bounded result table.
    result: OperationResult = .none,
};

const SocketRecord = struct {
    id: SocketId = .{ .value = 0 },
    kind: SocketKind = .request,
    open: bool = false,
};

/// SocketTranscript is the C-free, exact, bounded Source realization.
pub const SocketTranscript = struct {
    /// expected is the fixed ordered source operation transcript.
    expected: [max_transcript_operations]ExpectedOperation = undefined,
    /// expected_count is the configured operation prefix length.
    expected_count: usize = 0,
    /// cursor is the next operation consumed by the source methods.
    cursor: usize = 0,
    /// request_reads owns fixed request chunk and EOF results.
    request_reads: [max_request_read_steps]RequestRead = undefined,
    /// request_read_count is the configured request result count.
    request_read_count: usize = 0,
    /// event_reads owns fixed event chunk and EOF results.
    event_reads: [max_event_read_steps]EventRead = undefined,
    /// event_read_count is the configured event result count.
    event_read_count: usize = 0,
    /// poll_results owns fixed event/stop readiness results.
    poll_results: [max_poll_steps]PollResult = undefined,
    /// poll_result_count is the configured poll result count.
    poll_result_count: usize = 0,
    /// records tracks each local identity until one close attempt retires it.
    records: [max_socket_records]SocketRecord = [_]SocketRecord{.{}} ** max_socket_records,

    /// init starts an empty transcript; fixed records require no allocation.
    pub fn init(_: std.mem.Allocator) SocketTranscript {
        return .{};
    }

    /// deinit asserts that every opened source record was retired.
    pub fn deinit(self: *SocketTranscript) void {
        for (self.records) |record| std.debug.assert(!record.open);
    }

    /// append adds one operation without allocating or mutating prior records.
    pub fn append(self: *SocketTranscript, operation: ExpectedOperation) TranscriptError!void {
        if (self.expected_count >= max_transcript_operations) return error.TranscriptCapacityExceeded;
        self.expected[self.expected_count] = operation;
        self.expected_count += 1;
    }

    /// addRequestRead stores one typed request result and returns its bounded index.
    pub fn addRequestRead(self: *SocketTranscript, result: RequestRead) TranscriptError!u16 {
        if (self.request_read_count >= max_request_read_steps) return error.TranscriptCapacityExceeded;
        const index = self.request_read_count;
        self.request_reads[index] = result;
        self.request_read_count += 1;
        return @intCast(index);
    }

    /// addEventRead stores one typed event result and returns its bounded index.
    pub fn addEventRead(self: *SocketTranscript, result: EventRead) TranscriptError!u16 {
        if (self.event_read_count >= max_event_read_steps) return error.TranscriptCapacityExceeded;
        const index = self.event_read_count;
        self.event_reads[index] = result;
        self.event_read_count += 1;
        return @intCast(index);
    }

    /// addPollResult stores one typed poll result and returns its bounded index.
    pub fn addPollResult(self: *SocketTranscript, result: PollResult) TranscriptError!u16 {
        if (self.poll_result_count >= max_poll_steps) return error.TranscriptCapacityExceeded;
        const index = self.poll_result_count;
        self.poll_results[index] = result;
        self.poll_result_count += 1;
        return @intCast(index);
    }

    /// assertComplete proves the declared operation prefix was consumed.
    pub fn assertComplete(self: *const SocketTranscript) TranscriptError!void {
        if (self.cursor != self.expected_count) return error.TranscriptIncomplete;
    }

    /// socket consumes one exact open operation and publishes its local id.
    pub fn socket(self: *SocketTranscript, kind: SocketKind) SocketOpenError!SocketId {
        const operation = self.next(.{ .kind = .socket, .socket_kind = kind });
        return switch (operation.result) {
            .socket => |id| self.openRecord(id, kind),
            .failure => |failure| mapOpenFailure(failure),
            else => @panic("socket transcript result is not socket or failure"),
        };
    }

    /// connect consumes one exact path operation for a live local id.
    pub fn connect(self: *SocketTranscript, id: SocketId, path: SocketPath) SocketConnectError!void {
        self.requireLive(id);
        const operation = self.next(.{ .kind = .connect, .socket_id = id, .path = path });
        switch (operation.result) {
            .none => {},
            .failure => |failure| return mapConnectFailure(failure),
            else => @panic("connect transcript result is not none or failure"),
        }
    }

    /// write consumes one exact request operation and returns a bounded count.
    pub fn write(self: *SocketTranscript, id: SocketId, request: RequestWrite) SocketWriteError!WriteCount {
        self.requireLive(id);
        const operation = self.next(.{ .kind = .write, .socket_id = id, .request = request });
        return switch (operation.result) {
            .write_count => |count| if (count == 0 or count > request.len)
                @panic("invalid transcript write count")
            else
                count,
            .failure => |failure| mapWriteFailure(failure),
            else => @panic("write transcript result is not count or failure"),
        };
    }

    /// readRequest consumes one exact request response chunk or EOF.
    pub fn readRequest(self: *SocketTranscript, id: SocketId) SocketReadError!RequestRead {
        self.requireLive(id);
        const operation = self.next(.{ .kind = .read_request, .socket_id = id });
        return switch (operation.result) {
            .request_read => |index| if (index < self.request_read_count)
                self.request_reads[index]
            else
                @panic("invalid request read transcript index"),
            .failure => |failure| mapReadFailure(failure),
            else => @panic("request read transcript result is not a read or failure"),
        };
    }

    /// readEvent consumes one exact socket2 chunk or EOF.
    pub fn readEvent(self: *SocketTranscript, id: SocketId) SocketReadError!EventRead {
        self.requireLive(id);
        const operation = self.next(.{ .kind = .read_event, .socket_id = id });
        return switch (operation.result) {
            .event_read => |index| if (index < self.event_read_count)
                self.event_reads[index]
            else
                @panic("invalid event read transcript index"),
            .failure => |failure| mapEventReadFailure(failure),
            else => @panic("event read transcript result is not a read or failure"),
        };
    }

    /// poll consumes one exact PollSet and publishes the typed result.
    pub fn poll(self: *SocketTranscript, set: PollSet) PollError!PollResult {
        if (set.event) |id| self.requireLive(id);
        const operation = self.next(.{ .kind = .poll, .poll_set = set });
        var result: PollResult = undefined;
        switch (operation.result) {
            .poll_result => |index| result = if (index < self.poll_result_count)
                self.poll_results[index]
            else
                @panic("invalid poll transcript index"),
            .failure => |failure| return mapPollFailure(failure),
            else => @panic("poll transcript result is not a poll or failure"),
        }
        if ((set.event == null) != (result.event == null)) @panic("poll transcript event state does not match PollSet");
        return result;
    }

    /// close consumes one close attempt and retires the id even on failure.
    pub fn close(self: *SocketTranscript, id: SocketId) SocketCloseError!void {
        self.requireLive(id);
        const operation = self.next(.{ .kind = .close, .socket_id = id });
        self.retire(id);
        switch (operation.result) {
            .none => {},
            .failure => |failure| return mapCloseFailure(failure),
            else => @panic("close transcript result is not none or failure"),
        }
    }

    fn next(self: *SocketTranscript, actual: ExpectedOperation) ExpectedOperation {
        if (self.cursor >= self.expected_count) @panic("transcript operation exhausted");
        const expected = self.expected[self.cursor];
        if (!operationMatches(expected, actual)) @panic("transcript operation mismatch");
        self.cursor += 1;
        return expected;
    }

    fn openRecord(self: *SocketTranscript, id: SocketId, kind: SocketKind) SocketId {
        if (id.value == 0) @panic("transcript socket identity is zero");
        for (&self.records) |*record| {
            if (record.open and record.id.value == id.value) @panic("transcript socket identity is duplicated");
            if (record.open) continue;
            record.* = .{ .id = id, .kind = kind, .open = true };
            return id;
        }
        @panic("transcript socket capacity exceeded");
    }

    fn requireLive(self: *const SocketTranscript, id: SocketId) void {
        for (self.records) |record| if (record.open and record.id.value == id.value) return;
        @panic("transcript socket is not live");
    }

    fn retire(self: *SocketTranscript, id: SocketId) void {
        for (&self.records) |*record| {
            if (record.open and record.id.value == id.value) {
                record.open = false;
                return;
            }
        }
        @panic("transcript socket is not live");
    }
};

fn operationMatches(expected: ExpectedOperation, actual: ExpectedOperation) bool {
    if (expected.kind != actual.kind) return false;
    switch (actual.kind) {
        .socket => return expected.socket_kind == actual.socket_kind,
        .connect => return expected.socket_id.value == actual.socket_id.value and
            pathsEqual(expected.path, actual.path),
        .write => return expected.socket_id.value == actual.socket_id.value and
            requestsEqual(expected.request, actual.request),
        .read_request, .read_event, .close => return expected.socket_id.value == actual.socket_id.value,
        .poll => return std.meta.eql(expected.poll_set, actual.poll_set),
    }
}

fn pathsEqual(left: SocketPath, right: SocketPath) bool {
    return left.len == right.len and std.mem.eql(u8, left.bytes[0..left.len], right.bytes[0..right.len]);
}

fn requestsEqual(left: RequestWrite, right: RequestWrite) bool {
    return left.len == right.len and std.mem.eql(u8, left.bytes[0..left.len], right.bytes[0..right.len]);
}

fn mapOpenFailure(failure: Failure) SocketOpenError!SocketId {
    return switch (failure) {
        .socket_open_failed => error.HyprlandSocketOpenFailed,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid socket open failure"),
    };
}

fn mapConnectFailure(failure: Failure) SocketConnectError!void {
    return switch (failure) {
        .socket_connect_failed => error.HyprlandSocketConnectFailed,
        .socket_not_live => error.HyprlandSocketNotLive,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid socket connect failure"),
    };
}

fn mapWriteFailure(failure: Failure) SocketWriteError!u8 {
    return switch (failure) {
        .socket_write_failed => error.HyprlandSocketWriteFailed,
        .socket_not_live => error.HyprlandSocketNotLive,
        .signal_interrupted => error.SignalInterrupted,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid socket write failure"),
    };
}

fn mapReadFailure(failure: Failure) SocketReadError!RequestRead {
    return switch (failure) {
        .socket_read_failed => error.HyprlandSocketReadFailed,
        .socket_not_live => error.HyprlandSocketNotLive,
        .signal_interrupted => error.SignalInterrupted,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid socket read failure"),
    };
}

fn mapEventReadFailure(failure: Failure) SocketReadError!EventRead {
    return switch (failure) {
        .socket_read_failed => error.HyprlandSocketReadFailed,
        .socket_not_live => error.HyprlandSocketNotLive,
        .signal_interrupted => error.SignalInterrupted,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid event read failure"),
    };
}

fn mapPollFailure(failure: Failure) PollError!PollResult {
    return switch (failure) {
        .socket_not_live => error.HyprlandSocketNotLive,
        .signal_interrupted => error.SignalInterrupted,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid poll failure"),
    };
}

fn mapCloseFailure(failure: Failure) SocketCloseError!void {
    return switch (failure) {
        .socket_close_failed => error.HyprlandSocketCloseFailed,
        .socket_not_live => error.HyprlandSocketNotLive,
        .system_call_failed => error.SystemCallFailed,
        else => @panic("invalid close failure"),
    };
}

test "Hyprland plain path, ids, and timeout bounds" {
    try std.testing.expectError(error.SocketIdZero, SocketId.init(0));
    try std.testing.expectEqual(@as(u32, 0), (try StopId.fromFd(0)).value);
    try std.testing.expectError(error.StopIdNegative, StopId.fromFd(-1));
    try std.testing.expectError(error.HyprlandSocketPathInvalid, SocketPath.init(""));
    try std.testing.expectError(error.HyprlandSocketPathInvalid, SocketPath.init("a\x00b"));
    try std.testing.expectError(error.HyprlandSocketPathTooLong, SocketPath.init(&([_]u8{'x'} ** 108)));
    try std.testing.expectEqual(@as(usize, 107), (try SocketPath.init(&([_]u8{'x'} ** 107))).slice().len);
    try std.testing.expectError(error.PollTimeoutOutOfRange, PollTimeout.fromMilliseconds(60001));
    try std.testing.expectEqual(@as(i32, -1), PollTimeout.infinite().milliseconds);
}

test "Hyprland transcript enforces ordered partial write and close retirement" {
    var transcript = SocketTranscript.init(std.testing.allocator);
    const id = try SocketId.init(1);
    const path = try SocketPath.init("/run/hypr/a/.socket.sock");
    const request = RequestWrite.fromName(.monitors);
    try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .socket = id } });
    try transcript.append(.{ .kind = .connect, .socket_id = id, .path = path });
    try transcript.append(.{ .kind = .write, .socket_id = id, .request = request, .result = .{ .write_count = 1 } });
    try transcript.append(.{ .kind = .close, .socket_id = id });
    try std.testing.expectEqual(id, try transcript.socket(.request));
    try transcript.connect(id, path);
    _ = try transcript.write(id, request);
    try transcript.close(id);
    try transcript.assertComplete();
    transcript.deinit();
}

test "Hyprland transcript maps stop-only poll and retires a failed close" {
    var transcript = SocketTranscript.init(std.testing.allocator);
    const stop = try StopId.fromFd(0);
    const poll_set = PollSet{
        .event = null,
        .stop = stop,
        .timeout = try PollTimeout.fromMilliseconds(1000),
    };
    const poll_index = try transcript.addPollResult(.{ .event = null, .stop = .readable });
    const id = try SocketId.init(1);
    try transcript.append(.{ .kind = .poll, .poll_set = poll_set, .result = .{ .poll_result = poll_index } });
    try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .socket = id } });
    try transcript.append(.{ .kind = .close, .socket_id = id, .result = .{ .failure = .socket_close_failed } });
    try std.testing.expectEqual(.readable, (try transcript.poll(poll_set)).stop);
    _ = try transcript.socket(.request);
    try std.testing.expectError(error.HyprlandSocketCloseFailed, transcript.close(id));
    try transcript.assertComplete();
    transcript.deinit();
}

test "operational history fuzz stays within the bounded transcript" {
    try std.testing.fuzz({}, fuzzTranscriptBytes, .{});
}

fn fuzzTranscriptBytes(_: void, smith: *std.testing.Smith) !void {
    var input: [64]u8 = undefined;
    smith.bytes(&input);
    var transcript = SocketTranscript.init(std.testing.allocator);
    defer transcript.deinit();
    const id = try SocketId.init(1);
    const path = try SocketPath.init("/run/hypr/a/.socket.sock");
    const request = RequestWrite.fromName(.monitors);

    switch (input[0] % 3) {
        0 => {
            try transcript.append(.{
                .kind = .socket,
                .socket_kind = .request,
                .result = .{ .failure = .socket_open_failed },
            });
            try std.testing.expectError(error.HyprlandSocketOpenFailed, transcript.socket(.request));
        },
        1 => {
            try transcript.append(.{ .kind = .socket, .socket_kind = .request, .result = .{ .socket = id } });
            try transcript.append(.{ .kind = .connect, .socket_id = id, .path = path });
            try transcript.append(.{
                .kind = .write,
                .socket_id = id,
                .request = request,
                .result = .{ .write_count = @intCast(input[1] % request.len + 1) },
            });
            const read_result: RequestRead = if (input[2] & 1 == 0)
                .eof
            else
                .{ .chunk = .{ .bytes = [_]u8{'x'} ** max_request_chunk_bytes, .len = 1 } };
            const read_index = try transcript.addRequestRead(read_result);
            try transcript.append(.{
                .kind = .read_request,
                .socket_id = id,
                .result = .{ .request_read = read_index },
            });
            try transcript.append(.{
                .kind = .close,
                .socket_id = id,
                .result = if (input[3] & 1 == 0) .none else .{ .failure = .socket_close_failed },
            });
            try std.testing.expectEqual(id, try transcript.socket(.request));
            try transcript.connect(id, path);
            _ = try transcript.write(id, request);
            _ = try transcript.readRequest(id);
            if (input[3] & 1 == 0) {
                try transcript.close(id);
            } else {
                try std.testing.expectError(error.HyprlandSocketCloseFailed, transcript.close(id));
            }
        },
        else => {
            const stop = try StopId.fromFd(0);
            const poll_set = PollSet{ .event = id, .stop = stop, .timeout = PollTimeout.infinite() };
            const poll_index = try transcript.addPollResult(.{ .event = .idle, .stop = .readable });
            try transcript.append(.{ .kind = .socket, .socket_kind = .event, .result = .{ .socket = id } });
            try transcript.append(.{
                .kind = .connect,
                .socket_id = id,
                .path = try SocketPath.init("/run/hypr/a/.socket2.sock"),
            });
            try transcript.append(.{ .kind = .poll, .poll_set = poll_set, .result = .{ .poll_result = poll_index } });
            try transcript.append(.{ .kind = .close, .socket_id = id });
            try std.testing.expectEqual(id, try transcript.socket(.event));
            try transcript.connect(id, try SocketPath.init("/run/hypr/a/.socket2.sock"));
            try std.testing.expectEqual(PollState.readable, (try transcript.poll(poll_set)).stop);
            try transcript.close(id);
        },
    }
    try transcript.assertComplete();
}
