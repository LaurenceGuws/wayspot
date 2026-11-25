// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Writes Zig bindings for a set of protocols.
//!
//! Interfaces are grouped by the prefix before the first underscore of their
//! name, so `wl_surface` becomes `wl.Surface` and `xdg_toplevel` becomes
//! `xdg.Toplevel`, whichever protocol file they came from. Each one is a
//! struct holding an object id, with:
//!
//! - `interface`, the `protocol.Interface` describing it on the wire;
//! - a type for each of its enums -- an exhaustive-looking but open
//!   `enum(u32)`, or a `packed struct(u32)` of flags for a bitfield;
//! - `Event`, a tagged union of everything the compositor can send it, with
//!   a `decode` that makes one from a `protocol.Message`;
//! - a method per request, which queues it on a `protocol.Session`. One that
//!   creates an object returns it, typed.
//!
//! Nothing generated does any I/O, so the bindings import only `protocol`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const model = @import("model.zig");
const wire_max_args = 32;

pub const Error = Allocator.Error || error{
    /// The protocols cannot be rendered as given -- a `new_id` naming an
    /// interface none of them define, say. `Diagnostic.message` says what.
    InvalidProtocol,
};

pub const Diagnostic = @import("parse.zig").Diagnostic;

/// Renders `protocols` into one Zig source file, formatted as `zig fmt`
/// would. The result is allocated from `gpa`.
pub fn render(gpa: Allocator, protocols: []const model.Protocol, diagnostic: ?*Diagnostic) Error![:0]u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var out: Writer.Allocating = .init(arena);
    var r: Renderer = .{
        .arena = arena,
        .w = &out.writer,
        .diagnostic = diagnostic,
        .interfaces = .empty,
        .namespaces = .empty,
    };
    r.index(protocols) catch |e| return r.propagate(e);
    r.file(protocols) catch |e| return r.propagate(e);

    const source = try arena.dupeSentinel(u8, out.written(), 0);
    var tree = try std.zig.Ast.parse(gpa, source, .{});
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) {
        // The generator itself is wrong. Say where, so it can be fixed.
        var msg: Writer.Allocating = .init(arena);
        tree.renderError(tree.errors[0], &msg.writer) catch {};
        const loc = tree.tokenLocation(0, tree.errors[0].token);
        return r.fail("the generated code does not parse, at line {d}: {s}", .{ loc.line + 1, msg.written() });
    }
    const formatted = try tree.renderAlloc(gpa);
    defer gpa.free(formatted);
    return gpa.dupeSentinel(u8, formatted, 0);
}

/// Where one interface ended up.
const Placement = struct {
    interface: *const model.Interface,
    /// `wl`
    namespace: []const u8,
    /// `Surface`
    type_name: []const u8,
    /// `wl.Surface`
    path: []const u8,
};

const Renderer = struct {
    arena: Allocator,
    w: *Writer,
    diagnostic: ?*Diagnostic,
    interfaces: std.StringArrayHashMapUnmanaged(Placement),
    /// Namespace name to the interfaces in it, in the order met.
    namespaces: std.StringArrayHashMapUnmanaged(std.ArrayList(*const Placement)),

    fn fail(r: *Renderer, comptime fmt: []const u8, args: anytype) Error {
        if (r.diagnostic) |d| d.set(fmt, args);
        return error.InvalidProtocol;
    }

    /// Writing to an allocating writer fails only when allocation does.
    fn propagate(r: *Renderer, e: anyerror) Error {
        _ = r;
        return switch (e) {
            error.InvalidProtocol => error.InvalidProtocol,
            else => error.OutOfMemory,
        };
    }

    fn index(r: *Renderer, protocols: []const model.Protocol) !void {
        for (protocols) |*p| {
            for (p.interfaces) |*i| {
                const namespace, const rest = splitPrefix(i.name);
                const type_name = try camel(r.arena, rest, true);
                const gop = try r.interfaces.getOrPut(r.arena, i.name);
                if (gop.found_existing) return r.fail("interface {s} is defined twice", .{i.name});
                gop.value_ptr.* = .{
                    .interface = i,
                    .namespace = namespace,
                    .type_name = type_name,
                    .path = try std.fmt.allocPrint(r.arena, "{f}.{f}", .{ std.zig.fmtId(namespace), std.zig.fmtId(type_name) }),
                };
            }
        }
        for (r.interfaces.values()) |*placement| {
            const gop = try r.namespaces.getOrPut(r.arena, placement.namespace);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            for (gop.value_ptr.items) |other| {
                if (std.mem.eql(u8, other.type_name, placement.type_name))
                    return r.fail("interfaces {s} and {s} would both be {s}", .{ other.interface.name, placement.interface.name, placement.path });
            }
            try gop.value_ptr.append(r.arena, placement);
        }
        for (reserved_top) |name| {
            if (r.namespaces.contains(name)) return r.fail("an interface prefix is \"{s}\", which the generated file needs for itself", .{name});
        }
    }

    const reserved_top = [_][]const u8{"protocol"};

    fn file(r: *Renderer, protocols: []const model.Protocol) !void {
        const w = r.w;
        try w.writeAll("// Generated by the zig-wayland-native scanner. Do not edit.\n//\n// From:\n");
        for (protocols) |p| {
            try w.print("//   {s}", .{p.name});
            if (p.description.summary) |s| try w.print(" -- {s}", .{oneLine(s)});
            try w.writeAll("\n");
        }
        try w.writeAll("\nconst protocol = @import(\"protocol\");\n\n");
        for (r.namespaces.keys(), r.namespaces.values()) |namespace, members| {
            try w.print("pub const {f} = struct {{\n", .{std.zig.fmtId(namespace)});
            for (members.items) |placement| try r.interface(placement, members.items);
            try w.writeAll("};\n\n");
        }
        try w.writeAll(analyze_everything);
    }

    /// Zig analyses only what is referenced, so a binding nobody calls could
    /// fail to compile and nothing would say so. This walks every
    /// declaration, recursively, which is what a test binary built with the
    /// bindings as its root module runs. Everything it needs is local to the
    /// test, so it adds no name that a protocol's prefix could collide with.
    const analyze_everything =
        \\test "every binding is analyzed" {
        \\    const walk = struct {
        \\        fn walk(comptime T: type) void {
        \\            inline for (comptime @import("std").meta.declarations(T)) |name| {
        \\                if (@TypeOf(@field(T, name)) == type) {
        \\                    switch (@typeInfo(@field(T, name))) {
        \\                        .@"struct", .@"union", .@"enum" => walk(@field(T, name)),
        \\                        else => {},
        \\                    }
        \\                }
        \\                _ = &@field(T, name);
        \\            }
        \\        }
        \\    }.walk;
        \\    walk(@This());
        \\}
        \\
    ;

    /// The names a parameter or local may not take inside `placement`: every
    /// declaration in scope there, since Zig does not allow shadowing one.
    fn scopeNames(r: *Renderer, placement: *const Placement, siblings: []const *const Placement) !std.StringHashMapUnmanaged(void) {
        var names: std.StringHashMapUnmanaged(void) = .empty;
        for (reserved_top) |name| try names.put(r.arena, name, {});
        for (r.namespaces.keys()) |ns| try names.put(r.arena, ns, {});
        for (siblings) |s| try names.put(r.arena, s.type_name, {});
        for (placement.interface.requests) |m| try names.put(r.arena, try camel(r.arena, m.name, false), {});
        for (placement.interface.enums) |e| try names.put(r.arena, try r.enumTypeName(e), {});
        for ([_][]const u8{ "interface", "Event", "self", "session" }) |name| try names.put(r.arena, name, {});
        return names;
    }

    fn enumTypeName(r: *Renderer, e: model.Enum) ![]const u8 {
        const name = try camel(r.arena, e.name, true);
        if (std.mem.eql(u8, name, "Event")) return "EventEnum";
        return name;
    }

    fn interface(r: *Renderer, placement: *const Placement, siblings: []const *const Placement) !void {
        const w = r.w;
        const i = placement.interface;
        try writeDoc(w, i.description, .{});
        try w.print("pub const {f} = struct {{\n", .{std.zig.fmtId(placement.type_name)});
        try w.writeAll("id: protocol.ObjectId,\n\n");

        try w.print("pub const interface: protocol.Interface = .{{\n.name = \"{s}\",\n.version = {d},\n", .{ i.name, i.version });
        try w.writeAll(".requests = &.{\n");
        for (i.requests) |m| try r.signature(m, false);
        try w.writeAll("},\n.events = &.{\n");
        for (i.events) |m| try r.signature(m, true);
        try w.writeAll("},\n};\n\n");

        for (i.enums) |e| try r.@"enum"(e);

        const scope = try r.scopeNames(placement, siblings);
        try r.events(placement, i.*);
        for (i.requests, 0..) |m, opcode| try r.request(placement, m, @intCast(opcode), scope);

        try w.writeAll("};\n\n");
    }

    fn signature(r: *Renderer, m: model.Message, is_event: bool) !void {
        const w = r.w;
        try w.print(".{{ .name = \"{s}\"", .{m.name});
        if (m.since != 1) try w.print(", .since = {d}", .{m.since});
        if (m.destructor) try w.writeAll(", .destructor = true");
        var count: usize = 0;
        if (m.args.len > 0) {
            try w.writeAll(", .args = &.{ ");
            for (m.args) |a| {
                if (a.type == .new_id and a.interface == null) {
                    if (is_event) return r.fail("event {s} creates an object without saying of what interface", .{m.name});
                    try w.writeAll(".{ .kind = .string }, .{ .kind = .uint }, .{ .kind = .new_id }, ");
                    count += 3;
                    continue;
                }
                count += 1;
                try w.print(".{{ .kind = .{t}", .{a.type});
                if (a.allow_null) try w.writeAll(", .nullable = true");
                if (a.interface) |name| {
                    if (r.interfaces.get(name)) |target| {
                        try w.print(", .interface = &{s}.interface", .{target.path});
                    } else if (a.type == .new_id) {
                        return r.fail("{s} creates a {s}, which none of the protocols given defines", .{ m.name, name });
                    }
                }
                try w.writeAll(" }, ");
            }
            try w.writeAll("}");
        }
        if (count > wire_max_args) return r.fail("{s} has {d} arguments, more than the {d} a message may", .{ m.name, count, wire_max_args });
        try w.writeAll(" },\n");
    }

    fn @"enum"(r: *Renderer, e: model.Enum) !void {
        const w = r.w;
        const type_name = try r.enumTypeName(e);
        try writeDoc(w, e.description, .{});
        if (e.bitfield) {
            try w.print("pub const {f} = packed struct(u32) {{\n", .{std.zig.fmtId(type_name)});
            var bit: u6 = 0;
            var padding_from: ?u6 = null;
            var fields: [32]?usize = @splat(null);
            for (e.entries, 0..) |entry, n| {
                if (entry.value != 0 and std.math.isPowerOfTwo(entry.value)) {
                    const b = std.math.log2_int(u32, entry.value);
                    if (fields[b] == null) fields[b] = n;
                }
            }
            while (bit < 32) : (bit += 1) {
                if (fields[bit]) |n| {
                    if (padding_from) |from| try w.print("_padding{d}: u{d} = 0,\n", .{ from, bit - from });
                    padding_from = null;
                    const entry = e.entries[n];
                    try writeDoc(w, entry.description, .{});
                    try w.print("{f}: bool = false,\n", .{std.zig.fmtId(entry.name)});
                } else if (padding_from == null) padding_from = bit;
            }
            if (padding_from) |from| try w.print("_padding{d}: u{d} = 0,\n", .{ from, 32 - @as(u32, from) });
            for (e.entries, 0..) |entry, n| {
                const is_field = entry.value != 0 and std.math.isPowerOfTwo(entry.value) and
                    fields[std.math.log2_int(u32, entry.value)] == n;
                if (is_field) continue;
                try writeDoc(w, entry.description, .{});
                try w.print("pub const {f}: {f} = @bitCast(@as(u32, {d}));\n", .{ std.zig.fmtId(entry.name), std.zig.fmtId(type_name), entry.value });
            }
        } else {
            try w.print("pub const {f} = enum(u32) {{\n", .{std.zig.fmtId(type_name)});
            for (e.entries, 0..) |entry, n| {
                if (firstWithValue(e, entry.value) != n) continue;
                try writeDoc(w, entry.description, .{});
                try w.print("{f} = {d},\n", .{ std.zig.fmtId(entry.name), entry.value });
            }
            try w.writeAll("_,\n");
            for (e.entries, 0..) |entry, n| {
                const first = firstWithValue(e, entry.value);
                if (first == n) continue;
                try writeDoc(w, entry.description, .{});
                try w.print("pub const {f}: {f} = .{f};\n", .{ std.zig.fmtId(entry.name), std.zig.fmtId(type_name), std.zig.fmtIdPU(e.entries[first].name) });
            }
        }
        try w.writeAll("};\n\n");
    }

    fn firstWithValue(e: model.Enum, value: u32) usize {
        for (e.entries, 0..) |entry, n| {
            if (entry.value == value) return n;
        }
        unreachable;
    }

    /// How an argument that names an enum is typed, if it can be: the enum
    /// may belong to an interface none of the given protocols define, and
    /// then the argument is simply an integer.
    const EnumRef = struct { path: []const u8, bitfield: bool };

    fn enumRef(r: *Renderer, placement: *const Placement, arg: model.Arg) !?EnumRef {
        const spec = arg.@"enum" orelse return null;
        const owner, const enum_name = if (std.mem.lastIndexOfScalar(u8, spec, '.')) |dot|
            .{ r.interfaces.getPtr(spec[0..dot]) orelse return null, spec[dot + 1 ..] }
        else
            .{ placement, spec };
        const e = owner.interface.findEnum(enum_name) orelse return null;
        return .{
            .path = try std.fmt.allocPrint(r.arena, "{s}.{f}", .{ owner.path, std.zig.fmtId(try r.enumTypeName(e.*)) }),
            .bitfield = e.bitfield,
        };
    }

    fn objectPath(r: *Renderer, arg: model.Arg) ?[]const u8 {
        const name = arg.interface orelse return null;
        const target = r.interfaces.get(name) orelse return null;
        return target.path;
    }

    /// The Zig type an argument has in an event, or as a request parameter.
    fn argType(r: *Renderer, placement: *const Placement, arg: model.Arg) ![]const u8 {
        if (try r.enumRef(placement, arg)) |e| return e.path;
        return switch (arg.type) {
            .int => "i32",
            .uint => "u32",
            .fixed => "protocol.Fixed",
            .string => if (arg.allow_null) "?[:0]const u8" else "[:0]const u8",
            .object, .new_id => if (r.objectPath(arg)) |path|
                (if (arg.allow_null and arg.type == .object) try std.fmt.allocPrint(r.arena, "?{s}", .{path}) else path)
            else
                "protocol.ObjectId",
            .array => "[]const u8",
            .fd => "protocol.Fd",
        };
    }

    fn events(r: *Renderer, placement: *const Placement, i: model.Interface) !void {
        const w = r.w;
        try w.writeAll("/// Everything the compositor can send this object.\npub const Event = union(enum) {\n");
        for (i.events) |m| {
            try writeDoc(w, m.description, .{ .since = m.since, .deprecated_since = m.deprecated_since, .destructor = m.destructor, .args = m.args });
            try w.print("{f}: struct {{", .{std.zig.fmtId(m.name)});
            for (m.args) |a| {
                try w.print("{f}: {s},", .{ std.zig.fmtId(a.name), try r.argType(placement, a) });
            }
            try w.writeAll("},\n");
        }
        try w.writeAll(
            \\
            \\/// The typed form of an event the session has decoded for an
            \\/// object of this interface.
            \\pub fn decode(msg: protocol.Message) error{InvalidOpcode}!Event {
            \\return switch (msg.opcode) {
            \\
        );
        for (i.events, 0..) |m, opcode| {
            try w.print("{d} => .{{ .{f} = .{{", .{ opcode, std.zig.fmtId(m.name) });
            for (m.args, 0..) |a, n| {
                try w.print(" .{f} = ", .{std.zig.fmtId(a.name)});
                try r.decodeExpr(placement, a, n);
                try w.writeAll(",");
            }
            try w.writeAll(" } },\n");
        }
        try w.writeAll("else => error.InvalidOpcode,\n};\n}\n};\n\n");
    }

    fn decodeExpr(r: *Renderer, placement: *const Placement, a: model.Arg, n: usize) !void {
        const w = r.w;
        if (try r.enumRef(placement, a)) |e| {
            const raw = if (a.type == .int)
                try std.fmt.allocPrint(r.arena, "@as(u32, @bitCast(msg.args[{d}].int))", .{n})
            else
                try std.fmt.allocPrint(r.arena, "msg.args[{d}].uint", .{n});
            if (e.bitfield) {
                try w.print("@bitCast({s})", .{raw});
            } else {
                try w.print("@fromBackingInt({s})", .{raw});
            }
            return;
        }
        switch (a.type) {
            .int, .uint, .fixed, .array, .fd => try w.print("msg.args[{d}].{t}", .{ n, a.type }),
            .string => try w.print("msg.args[{d}].string{s}", .{ n, if (a.allow_null) "" else ".?" }),
            .object => if (r.objectPath(a) == null)
                try w.print("msg.args[{d}].object", .{n})
            else if (a.allow_null)
                try w.print("if (msg.args[{d}].object == .null) null else .{{ .id = msg.args[{d}].object }}", .{ n, n })
            else
                try w.print(".{{ .id = msg.args[{d}].object }}", .{n}),
            .new_id => try w.print(".{{ .id = msg.args[{d}].new_id }}", .{n}),
        }
    }

    fn request(r: *Renderer, placement: *const Placement, m: model.Message, opcode: u16, scope: std.StringHashMapUnmanaged(void)) !void {
        const w = r.w;
        var taken = try scope.clone(r.arena);

        // The object this request creates, if it creates one.
        var new_id: ?model.Arg = null;
        for (m.args) |a| {
            if (a.type != .new_id) continue;
            if (new_id != null) return r.fail("request {s}.{s} creates more than one object", .{ placement.interface.name, m.name });
            new_id = a;
        }

        // Parameter names, chosen so that none shadows a declaration.
        const names = try r.arena.alloc([]const u8, m.args.len);
        for (m.args, names) |a, *name| name.* = try uniqueName(r.arena, &taken, a.name);
        const bare_new_id = if (new_id) |a| a.interface == null else false;
        const type_param = if (bare_new_id) try uniqueName(r.arena, &taken, "T") else "";
        const version_param = if (bare_new_id) try uniqueName(r.arena, &taken, "version") else "";

        try writeDoc(w, m.description, .{ .since = m.since, .deprecated_since = m.deprecated_since, .destructor = m.destructor, .args = m.args });
        try w.print("pub fn {f}(self: {f}, session: *protocol.Session", .{ std.zig.fmtId(try camel(r.arena, m.name, false)), std.zig.fmtId(placement.type_name) });
        for (m.args, names) |a, name| {
            if (a.type == .new_id) {
                if (bare_new_id) try w.print(", comptime {s}: type, {s}: u32", .{ type_param, version_param });
                continue;
            }
            try w.print(", {f}: {s}", .{ std.zig.fmtId(name), try r.argType(placement, a) });
        }
        const return_type = if (new_id) |a|
            (if (bare_new_id) type_param else r.objectPath(a).?)
        else
            "void";
        try w.print(") protocol.Session.RequestError!{s} {{\n", .{return_type});

        if (new_id) |a| {
            const name = names[indexOfArg(m, a)];
            if (bare_new_id) {
                try w.print("const {f} = try session.newId(&{s}.interface, {s});\n", .{ std.zig.fmtId(name), type_param, version_param });
            } else {
                try w.print("const {f} = try session.newChild(self.id, &{s}.interface);\n", .{ std.zig.fmtId(name), r.objectPath(a).? });
            }
            try w.print("errdefer session.forget({f});\n", .{std.zig.fmtId(name)});
        }

        try w.print("try session.request(self.id, {d}, &.{{", .{opcode});
        for (m.args, names) |a, name| {
            const id = std.zig.fmtId(name);
            try w.writeAll(" ");
            if (try r.enumRef(placement, a)) |e| {
                const value = if (e.bitfield)
                    try std.fmt.allocPrint(r.arena, "@as(u32, @bitCast({f}))", .{id})
                else
                    try std.fmt.allocPrint(r.arena, "@backingInt({f})", .{id});
                if (a.type == .int) {
                    try w.print(".{{ .int = @bitCast({s}) }},", .{value});
                } else {
                    try w.print(".{{ .uint = {s} }},", .{value});
                }
                continue;
            }
            switch (a.type) {
                .int, .uint, .fixed, .string, .array, .fd => try w.print(".{{ .{t} = {f} }},", .{ a.type, id }),
                .object => if (r.objectPath(a) == null)
                    try w.print(".{{ .object = {f} }},", .{id})
                else
                    try w.print(".{{ .object = protocol.objectId({f}) }},", .{id}),
                .new_id => if (bare_new_id)
                    try w.print(".{{ .string = {s}.interface.name }}, .{{ .uint = {s} }}, .{{ .new_id = {f} }},", .{ type_param, version_param, id })
                else
                    try w.print(".{{ .new_id = {f} }},", .{id}),
            }
        }
        try w.writeAll(" });\n");
        if (new_id) |a| try w.print("return .{{ .id = {f} }};\n", .{std.zig.fmtId(names[indexOfArg(m, a)])});
        try w.writeAll("}\n\n");
    }

    fn indexOfArg(m: model.Message, a: model.Arg) usize {
        for (m.args, 0..) |candidate, n| {
            if (candidate.name.ptr == a.name.ptr) return n;
        }
        unreachable;
    }
};

fn uniqueName(arena: Allocator, taken: *std.StringHashMapUnmanaged(void), want: []const u8) ![]const u8 {
    var name = want;
    while (taken.contains(name)) name = try std.fmt.allocPrint(arena, "{s}_", .{name});
    try taken.put(arena, name, {});
    return name;
}

/// `xdg_toplevel` to `xdg` and `toplevel`. A name with no underscore is its
/// own namespace.
fn splitPrefix(name: []const u8) struct { []const u8, []const u8 } {
    const underscore = std.mem.findScalar(u8, name, '_') orelse return .{ name, name };
    return .{ name[0..underscore], name[underscore + 1 ..] };
}

/// `get_registry` to `getRegistry`, or with `upper` to `GetRegistry`.
fn camel(arena: Allocator, snake: []const u8, upper: bool) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var capitalize = upper;
    for (snake) |c| {
        if (c == '_') {
            capitalize = true;
            continue;
        }
        try out.append(arena, if (capitalize) std.ascii.toUpper(c) else c);
        capitalize = false;
    }
    return out.items;
}

fn oneLine(s: []const u8) []const u8 {
    return std.mem.trim(u8, s[0 .. std.mem.findScalar(u8, s, '\n') orelse s.len], " \t\r");
}

const DocExtra = struct {
    since: u32 = 1,
    deprecated_since: ?u32 = null,
    destructor: bool = false,
    args: []const model.Arg = &.{},
};

/// A doc comment from a description: the summary as its first line, then the
/// text with its common indentation taken off, then whatever `extra` has to
/// say that the description does not.
fn writeDoc(w: *Writer, d: model.Description, extra: DocExtra) !void {
    var wrote = false;
    if (d.summary) |s| {
        try w.print("/// {s}\n", .{oneLine(s)});
        wrote = true;
    }
    if (d.text) |text| {
        var indent: usize = std.math.maxInt(usize);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trimStart(u8, line, " \t");
            if (std.mem.trimEnd(u8, trimmed, " \t\r").len == 0) continue;
            indent = @min(indent, line.len - trimmed.len);
        }
        if (indent != std.math.maxInt(usize)) {
            if (wrote) try w.writeAll("///\n");
            wrote = true;
            // A run of blank lines becomes one, and only between two lines
            // that have something on them.
            var started = false;
            var blank = false;
            lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |line| {
                const body = std.mem.trimEnd(u8, if (line.len >= indent) line[indent..] else "", " \t\r");
                if (body.len == 0) {
                    blank = started;
                    continue;
                }
                if (blank) try w.writeAll("///\n");
                started = true;
                blank = false;
                try w.print("/// {s}\n", .{body});
            }
        }
    }
    var notes = false;
    for (extra.args) |a| {
        const summary = a.description.summary orelse continue;
        if (!notes) {
            if (wrote) try w.writeAll("///\n");
            notes = true;
            wrote = true;
        }
        try w.print("/// - `{s}`: {s}\n", .{ a.name, oneLine(summary) });
    }
    if (extra.since > 1 or extra.deprecated_since != null or extra.destructor) {
        if (wrote) try w.writeAll("///\n");
        if (extra.since > 1) try w.print("/// Since version {d}.\n", .{extra.since});
        if (extra.deprecated_since) |v| try w.print("/// Deprecated since version {d}.\n", .{v});
        if (extra.destructor) try w.writeAll("/// Destroys the object.\n");
    }
}

const testing = std.testing;
const parse = @import("parse.zig").parse;

fn renderXml(xml: []const u8) ![:0]u8 {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var d: Diagnostic = .{};
    const p = try parse(arena.allocator(), xml, &d);
    return render(testing.allocator, &.{p}, &d) catch |e| {
        std.debug.print("{s}\n", .{d.message()});
        return e;
    };
}

test "names" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("getRegistry", try camel(arena.allocator(), "get_registry", false));
    try testing.expectEqualStrings("LinearDmabufV1", try camel(arena.allocator(), "linear_dmabuf_v1", true));
    try testing.expectEqualStrings("90", try camel(arena.allocator(), "90", true));
    const ns, const rest = splitPrefix("zwp_linear_dmabuf_v1");
    try testing.expectEqualStrings("zwp", ns);
    try testing.expectEqualStrings("linear_dmabuf_v1", rest);
}

test "a small protocol renders as expected" {
    const source = try renderXml(
        \\<protocol name="test">
        \\  <interface name="tst_thing" version="2">
        \\    <description summary="a thing">
        \\      First line.
        \\
        \\        Indented.
        \\    </description>
        \\    <request name="make_child">
        \\      <arg name="id" type="new_id" interface="tst_thing" summary="the new thing"/>
        \\      <arg name="mode" type="uint" enum="mode"/>
        \\      <arg name="other" type="object" interface="tst_thing" allow-null="true"/>
        \\    </request>
        \\    <request name="destroy" type="destructor" since="2"/>
        \\    <event name="error">
        \\      <arg name="flags" type="uint" enum="flags"/>
        \\      <arg name="make_child" type="string" allow-null="true"/>
        \\    </event>
        \\    <enum name="mode">
        \\      <entry name="90" value="0"/>
        \\      <entry name="also_90" value="0"/>
        \\    </enum>
        \\    <enum name="flags" bitfield="true">
        \\      <entry name="none" value="0"/>
        \\      <entry name="a" value="1"/>
        \\      <entry name="c" value="4"/>
        \\      <entry name="both" value="5"/>
        \\    </enum>
        \\  </interface>
        \\</protocol>
    );
    defer testing.allocator.free(source);
    try testing.expectEqualStrings(
        \\// Generated by the zig-wayland-native scanner. Do not edit.
        \\//
        \\// From:
        \\//   test
        \\
        \\const protocol = @import("protocol");
        \\
        \\pub const tst = struct {
        \\    /// a thing
        \\    ///
        \\    /// First line.
        \\    ///
        \\    ///   Indented.
        \\    pub const Thing = struct {
        \\        id: protocol.ObjectId,
        \\
        \\        pub const interface: protocol.Interface = .{
        \\            .name = "tst_thing",
        \\            .version = 2,
        \\            .requests = &.{
        \\                .{ .name = "make_child", .args = &.{
        \\                    .{ .kind = .new_id, .interface = &tst.Thing.interface },
        \\                    .{ .kind = .uint },
        \\                    .{ .kind = .object, .nullable = true, .interface = &tst.Thing.interface },
        \\                } },
        \\                .{ .name = "destroy", .since = 2, .destructor = true },
        \\            },
        \\            .events = &.{
        \\                .{ .name = "error", .args = &.{
        \\                    .{ .kind = .uint },
        \\                    .{ .kind = .string, .nullable = true },
        \\                } },
        \\            },
        \\        };
        \\
        \\        pub const Mode = enum(u32) {
        \\            @"90" = 0,
        \\            _,
        \\            pub const also_90: Mode = .@"90";
        \\        };
        \\
        \\        pub const Flags = packed struct(u32) {
        \\            a: bool = false,
        \\            _padding1: u1 = 0,
        \\            c: bool = false,
        \\            _padding3: u29 = 0,
        \\            pub const none: Flags = @bitCast(@as(u32, 0));
        \\            pub const both: Flags = @bitCast(@as(u32, 5));
        \\        };
        \\
        \\        /// Everything the compositor can send this object.
        \\        pub const Event = union(enum) {
        \\            @"error": struct {
        \\                flags: tst.Thing.Flags,
        \\                make_child: ?[:0]const u8,
        \\            },
        \\
        \\            /// The typed form of an event the session has decoded for an
        \\            /// object of this interface.
        \\            pub fn decode(msg: protocol.Message) error{InvalidOpcode}!Event {
        \\                return switch (msg.opcode) {
        \\                    0 => .{ .@"error" = .{
        \\                        .flags = @bitCast(msg.args[0].uint),
        \\                        .make_child = msg.args[1].string,
        \\                    } },
        \\                    else => error.InvalidOpcode,
        \\                };
        \\            }
        \\        };
        \\
        \\        /// - `id`: the new thing
        \\        pub fn makeChild(self: Thing, session: *protocol.Session, mode: tst.Thing.Mode, other: ?tst.Thing) protocol.Session.RequestError!tst.Thing {
        \\            const id = try session.newChild(self.id, &tst.Thing.interface);
        \\            errdefer session.forget(id);
        \\            try session.request(self.id, 0, &.{
        \\                .{ .new_id = id },
        \\                .{ .uint = @backingInt(mode) },
        \\                .{ .object = protocol.objectId(other) },
        \\            });
        \\            return .{ .id = id };
        \\        }
        \\
        \\        /// Since version 2.
        \\        /// Destroys the object.
        \\        pub fn destroy(self: Thing, session: *protocol.Session) protocol.Session.RequestError!void {
        \\            try session.request(self.id, 1, &.{});
        \\        }
        \\    };
        \\};
        \\
        \\test "every binding is analyzed" {
        \\    const walk = struct {
        \\        fn walk(comptime T: type) void {
        \\            inline for (comptime @import("std").meta.declarations(T)) |name| {
        \\                if (@TypeOf(@field(T, name)) == type) {
        \\                    switch (@typeInfo(@field(T, name))) {
        \\                        .@"struct", .@"union", .@"enum" => walk(@field(T, name)),
        \\                        else => {},
        \\                    }
        \\                }
        \\                _ = &@field(T, name);
        \\            }
        \\        }
        \\    }.walk;
        \\    walk(@This());
        \\}
        \\
    , source);
}

test "a request that binds whatever it is given" {
    const source = try renderXml(
        \\<protocol name="test">
        \\  <interface name="tst_registry" version="1">
        \\    <request name="bind">
        \\      <arg name="name" type="uint"/>
        \\      <arg name="id" type="new_id"/>
        \\      <arg name="version" type="uint"/>
        \\    </request>
        \\  </interface>
        \\</protocol>
    );
    defer testing.allocator.free(source);
    try testing.expect(std.mem.find(u8, source,
        \\pub fn bind(self: Registry, session: *protocol.Session, name: u32, comptime T: type, version_: u32, version: u32) protocol.Session.RequestError!T {
    ) != null);
    try testing.expect(std.mem.find(u8, source,
        \\                .{ .uint = name },
        \\                .{ .string = T.interface.name },
        \\                .{ .uint = version_ },
        \\                .{ .new_id = id },
        \\                .{ .uint = version },
    ) != null);
}

test "problems are reported rather than rendered" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var d: Diagnostic = .{};
    const p = try parse(arena.allocator(),
        \\<protocol name="test"><interface name="tst_a" version="1">
        \\<request name="r"><arg name="id" type="new_id" interface="tst_missing"/></request>
        \\</interface></protocol>
    , &d);
    try testing.expectError(error.InvalidProtocol, render(testing.allocator, &.{p}, &d));
    try testing.expectEqualStrings("r creates a tst_missing, which none of the protocols given defines", d.message());
}
