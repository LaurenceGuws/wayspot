//! Sunglasses mode owns the filter configuration row facts.

const std = @import("std");
const candidate = @import("picker_candidate");

/// collect appends sunglasses mode rows to the picker list.
pub fn collect(allocator: std.mem.Allocator, out: *candidate.Candidate.List) !void {
    try out.append(allocator, candidate.Candidate.init(.mode, "/sunglasses", "Filter form", "/sunglasses"));
}
