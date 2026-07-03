//! TelemetrySink names the action event path without owning an event format.
pub const TelemetrySink = struct {
    path: []const u8,

    pub fn init(path: []const u8) TelemetrySink {
        return .{ .path = path };
    }
};
