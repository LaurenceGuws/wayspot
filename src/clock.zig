//! Pure, bounded, 24-hour local clock label for Wayspot GUI headers.
const std = @import("std");

pub const Date = struct {
    weekday: u8,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
};

const weekdays = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// Formats one local time without global locale or persistent derived state.
pub fn format(date: Date, buffer: *[32]u8) ![]const u8 {
    if (date.weekday >= weekdays.len or date.month >= months.len or date.day < 1 or date.day > 31 or
        date.hour > 23 or date.minute > 59)
        return error.ClockDateInvalid;
    return std.fmt.bufPrint(buffer, "{s} {d:0>2} {s}  {d:0>2}:{d:0>2}", .{
        weekdays[date.weekday], date.day, months[date.month], date.hour, date.minute,
    });
}

/// Wait for the next wall-clock minute without polling the GUI every second.
/// Whole-second resolution may redraw up to one second after a minute changes.
pub fn nextMinuteMilliseconds(unix_seconds: i64) i32 {
    return @intCast((60 - @mod(unix_seconds, 60)) * 1000);
}

test "clock is 24-hour local text with exact weekday and minute bounds" {
    var bytes: [32]u8 = undefined;
    try std.testing.expectEqualStrings("Sun 18 Oct  21:04", try format(.{
        .weekday = 0,
        .month = 9,
        .day = 18,
        .hour = 21,
        .minute = 4,
    }, &bytes));
    try std.testing.expectEqualStrings("Sat 31 Dec  00:00", try format(.{
        .weekday = 6,
        .month = 11,
        .day = 31,
        .hour = 0,
        .minute = 0,
    }, &bytes));
    try std.testing.expectError(error.ClockDateInvalid, format(.{
        .weekday = 7,
        .month = 9,
        .day = 18,
        .hour = 21,
        .minute = 4,
    }, &bytes));
}

test "clock waits at most one minute and wakes at minute boundaries" {
    try std.testing.expectEqual(@as(i32, 60_000), nextMinuteMilliseconds(60));
    try std.testing.expectEqual(@as(i32, 1_000), nextMinuteMilliseconds(119));
    try std.testing.expectEqual(@as(i32, 32_000), nextMinuteMilliseconds(88));
    try std.testing.expectEqual(@as(i32, 1_000), nextMinuteMilliseconds(-1));
}
