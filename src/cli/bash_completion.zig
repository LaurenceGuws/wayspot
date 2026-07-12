//! Bash serialization owns shell quoting and complete-record byte accounting.
//!
//! Cmd supplies only position-aware next-argument values. This file owns the
//! Bash word representation and counts every emitted byte, including the
//! terminating newline.

const std = @import("std");
const cmd_owner = @import("../picker/cmd.zig");

/// max_completion_output_bytes bounds complete Bash records, including newlines.
pub const max_completion_output_bytes: usize = 64 * 1024;

/// write serializes Cmd-approved next arguments as one quoted Bash word per line.
pub fn write(out: *std.Io.Writer, values: []const cmd_owner.Completion) !void {
    var output_bytes: usize = 0;
    for (values) |value| {
        const escaped_bytes = escapedLength(value.argument);
        const record_bytes = escaped_bytes + 1;
        if (record_bytes > max_completion_output_bytes -| output_bytes) return error.CompletionOutputTooLong;
        try writeWord(out, value.argument);
        try out.writeByte('\n');
        output_bytes += record_bytes;
    }
}

/// writeWord emits one exact shell-quoted word without evaluating it.
pub fn writeWord(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('\'');
    for (value) |byte| {
        if (byte == '\'') try out.writeAll("'\\''") else try out.writeByte(byte);
    }
    try out.writeByte('\'');
}

fn escapedLength(value: []const u8) usize {
    var length: usize = 2;
    for (value) |byte| length += if (byte == '\'') 4 else 1;
    return length;
}

test "Bash writer quotes apostrophes exactly" {
    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    const value = [_]cmd_owner.Completion{.{ .argument = "quote'app" }};

    try write(&output.writer, &value);
    try std.testing.expectEqualStrings("'quote'\\''app'\n", output.written());
}

test "Bash writer accepts the exact newline-inclusive output bound" {
    var exact_value: [max_completion_output_bytes - 3]u8 = undefined;
    @memset(exact_value[0..], 'x');
    const values = [_]cmd_owner.Completion{.{ .argument = exact_value[0..] }};

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try write(&output.writer, &values);
    try std.testing.expectEqual(max_completion_output_bytes, output.written().len);
}

test "Bash writer rejects one byte beyond the output bound before writing" {
    var overlong_value: [max_completion_output_bytes - 2]u8 = undefined;
    @memset(overlong_value[0..], 'x');
    const values = [_]cmd_owner.Completion{.{ .argument = overlong_value[0..] }};

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try std.testing.expectError(error.CompletionOutputTooLong, write(&output.writer, &values));
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
}
