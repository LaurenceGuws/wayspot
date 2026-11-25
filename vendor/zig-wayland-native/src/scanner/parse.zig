// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! Reads a protocol description into a `model.Protocol`.
//!
//! The shape is `wayland.dtd`'s and only four levels deep, so a pull parser
//! walking it with one function per element is all it takes. Elements the DTD
//! does not know are skipped rather than refused, so that a newer protocol
//! file with some addition this scanner has not heard of still produces
//! bindings for everything it has.

const std = @import("std");
const Allocator = std.mem.Allocator;
const zxml = @import("zxml");
const model = @import("model.zig");

pub const Error = zxml.Error || Allocator.Error || error{
    /// The document is not a `<protocol>`, or an element lacks an attribute
    /// the DTD requires, or an attribute has a value it does not allow.
    /// `Diagnostic.message` says which.
    InvalidProtocol,
};

/// Where to put a sentence saying what was wrong, when parsing or rendering
/// fails with `error.InvalidProtocol`. It has its own storage, so that the
/// message outlives whatever the failed call allocated.
pub const Diagnostic = struct {
    buffer: [512]u8 = undefined,
    len: usize = 0,

    pub fn message(d: *const Diagnostic) []const u8 {
        return d.buffer[0..d.len];
    }

    /// Sets the message, cut short if it does not fit.
    pub fn set(d: *Diagnostic, comptime fmt: []const u8, args: anytype) void {
        var w: std.Io.Writer = .fixed(&d.buffer);
        w.print(fmt, args) catch {};
        d.len = w.end;
    }
};

/// Parses `xml`. Every string in the result is allocated from `arena`.
pub fn parse(arena: Allocator, xml: []const u8, diagnostic: ?*Diagnostic) Error!model.Protocol {
    var p: Parser = .{ .arena = arena, .reader = .init(xml), .diagnostic = diagnostic };
    while (true) {
        switch (try p.reader.next()) {
            .start_element => |el| {
                if (!std.mem.eql(u8, el.name, "protocol"))
                    return p.fail("the root element is <{s}>, not <protocol>", .{el.name});
                return p.protocol(el);
            },
            .eof => return p.fail("there is no <protocol> element", .{}),
            else => {},
        }
    }
}

const Parser = struct {
    arena: Allocator,
    reader: zxml.Reader,
    diagnostic: ?*Diagnostic,
    /// What is being read, for the diagnostic.
    context: []const u8 = "the protocol",

    fn fail(p: *Parser, comptime fmt: []const u8, args: anytype) Error {
        if (p.diagnostic) |d| d.set("{s}: " ++ fmt, .{p.context} ++ args);
        return error.InvalidProtocol;
    }

    /// The next child element of the element whose start was the last thing
    /// read, or null at its end. Text, comments and the like between
    /// children are skipped.
    fn child(p: *Parser) Error!?zxml.Element {
        while (true) {
            switch (try p.reader.next()) {
                .start_element => |el| return el,
                .end_element => return null,
                .eof => return error.UnexpectedEndOfDocument,
                else => {},
            }
        }
    }

    fn optional(p: *Parser, el: zxml.Element, name: []const u8) Error!?[]const u8 {
        return el.attrAlloc(p.arena, name, .strict);
    }

    fn required(p: *Parser, el: zxml.Element, name: []const u8) Error![]const u8 {
        return try p.optional(el, name) orelse p.fail("<{s}> has no {s} attribute", .{ el.name, name });
    }

    fn number(p: *Parser, el: zxml.Element, name: []const u8) Error!?u32 {
        const text = try p.optional(el, name) orelse return null;
        return std.fmt.parseInt(u32, std.mem.trim(u8, text, " "), 0) catch
            p.fail("<{s}> has {s}=\"{s}\", which is not a number", .{ el.name, name, text });
    }

    fn boolean(p: *Parser, el: zxml.Element, name: []const u8) Error!bool {
        const text = try p.optional(el, name) orelse return false;
        if (std.mem.eql(u8, text, "true")) return true;
        if (std.mem.eql(u8, text, "false")) return false;
        return p.fail("<{s}> has {s}=\"{s}\", which is neither true nor false", .{ el.name, name, text });
    }

    /// Reads a `<description>` whose start was just returned.
    fn description(p: *Parser, el: zxml.Element) Error!model.Description {
        const summary = try p.optional(el, "summary");
        const text = try p.reader.textAlloc(p.arena, .strict);
        return .{ .summary = summary, .text = if (std.mem.trim(u8, text, " \t\r\n").len == 0) null else text };
    }

    fn protocol(p: *Parser, el: zxml.Element) Error!model.Protocol {
        const name = try p.required(el, "name");
        p.context = try std.fmt.allocPrint(p.arena, "protocol {s}", .{name});
        var result: model.Protocol = .{ .name = name, .interfaces = &.{} };
        var interfaces: std.ArrayList(model.Interface) = .empty;
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "copyright")) {
                result.copyright = try p.reader.textAlloc(p.arena, .strict);
            } else if (std.mem.eql(u8, c.name, "description")) {
                result.description = try p.description(c);
            } else if (std.mem.eql(u8, c.name, "interface")) {
                try interfaces.append(p.arena, try p.interface(c));
            } else try p.reader.skipElement();
        }
        result.interfaces = interfaces.items;
        return result;
    }

    fn interface(p: *Parser, el: zxml.Element) Error!model.Interface {
        const name = try p.required(el, "name");
        p.context = try std.fmt.allocPrint(p.arena, "interface {s}", .{name});
        const version = try p.number(el, "version") orelse return p.fail("<interface> has no version attribute", .{});
        if (version == 0) return p.fail("the version is 0", .{});
        var result: model.Interface = .{
            .name = name,
            .version = version,
            .requests = &.{},
            .events = &.{},
            .enums = &.{},
        };
        var requests: std.ArrayList(model.Message) = .empty;
        var events: std.ArrayList(model.Message) = .empty;
        var enums: std.ArrayList(model.Enum) = .empty;
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "description")) {
                result.description = try p.description(c);
            } else if (std.mem.eql(u8, c.name, "request")) {
                try requests.append(p.arena, try p.message(c, name));
            } else if (std.mem.eql(u8, c.name, "event")) {
                try events.append(p.arena, try p.message(c, name));
            } else if (std.mem.eql(u8, c.name, "enum")) {
                try enums.append(p.arena, try p.@"enum"(c, name));
            } else try p.reader.skipElement();
        }
        result.requests = requests.items;
        result.events = events.items;
        result.enums = enums.items;
        return result;
    }

    fn message(p: *Parser, el: zxml.Element, interface_name: []const u8) Error!model.Message {
        const name = try p.required(el, "name");
        p.context = try std.fmt.allocPrint(p.arena, "{s} {s}.{s}", .{ el.name, interface_name, name });
        var result: model.Message = .{ .name = name, .args = &.{} };
        if (try p.optional(el, "type")) |t| {
            if (!std.mem.eql(u8, t, "destructor")) return p.fail("the type is \"{s}\", and only \"destructor\" is known", .{t});
            result.destructor = true;
        }
        result.since = try p.number(el, "since") orelse 1;
        result.deprecated_since = try p.number(el, "deprecated-since");
        var args: std.ArrayList(model.Arg) = .empty;
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "description")) {
                result.description = try p.description(c);
            } else if (std.mem.eql(u8, c.name, "arg")) {
                try args.append(p.arena, try p.arg(c));
            } else try p.reader.skipElement();
        }
        result.args = args.items;
        return result;
    }

    fn arg(p: *Parser, el: zxml.Element) Error!model.Arg {
        const name = try p.required(el, "name");
        const type_name = try p.required(el, "type");
        var result: model.Arg = .{
            .name = name,
            .type = std.meta.stringToEnum(model.Arg.Type, type_name) orelse
                return p.fail("argument {s} has the unknown type \"{s}\"", .{ name, type_name }),
            .description = .{ .summary = try p.optional(el, "summary") },
            .interface = try p.optional(el, "interface"),
            .allow_null = try p.boolean(el, "allow-null"),
            .@"enum" = try p.optional(el, "enum"),
        };
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "description")) {
                const d = try p.description(c);
                result.description.text = d.text;
                if (result.description.summary == null) result.description.summary = d.summary;
            } else try p.reader.skipElement();
        }
        return result;
    }

    fn @"enum"(p: *Parser, el: zxml.Element, interface_name: []const u8) Error!model.Enum {
        const name = try p.required(el, "name");
        p.context = try std.fmt.allocPrint(p.arena, "enum {s}.{s}", .{ interface_name, name });
        var result: model.Enum = .{
            .name = name,
            .since = try p.number(el, "since") orelse 1,
            .bitfield = try p.boolean(el, "bitfield"),
            .entries = &.{},
        };
        var entries: std.ArrayList(model.Entry) = .empty;
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "description")) {
                result.description = try p.description(c);
            } else if (std.mem.eql(u8, c.name, "entry")) {
                try entries.append(p.arena, try p.entry(c));
            } else try p.reader.skipElement();
        }
        result.entries = entries.items;
        return result;
    }

    fn entry(p: *Parser, el: zxml.Element) Error!model.Entry {
        var result: model.Entry = .{
            .name = try p.required(el, "name"),
            .value = try p.number(el, "value") orelse return p.fail("<entry> has no value attribute", .{}),
            .since = try p.number(el, "since") orelse 1,
            .deprecated_since = try p.number(el, "deprecated-since"),
            .description = .{ .summary = try p.optional(el, "summary") },
        };
        while (try p.child()) |c| {
            if (std.mem.eql(u8, c.name, "description")) {
                const d = try p.description(c);
                result.description.text = d.text;
                if (result.description.summary == null) result.description.summary = d.summary;
            } else try p.reader.skipElement();
        }
        return result;
    }
};

const testing = std.testing;

test "a small protocol" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const p = try parse(arena.allocator(),
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<protocol name="test">
        \\  <copyright>Copyright &#169; somebody</copyright>
        \\  <interface name="test_thing" version="3">
        \\    <description summary="a thing">It &lt;does&gt; things.</description>
        \\    <request name="destroy" type="destructor"/>
        \\    <request name="set" since="2">
        \\      <arg name="value" type="uint" enum="mode" summary="the mode"/>
        \\      <arg name="other" type="object" interface="test_thing" allow-null="true"/>
        \\    </request>
        \\    <event name="done" deprecated-since="3">
        \\      <arg name="fd" type="fd">
        \\        <description summary="a file">Read it.</description>
        \\      </arg>
        \\    </event>
        \\    <enum name="mode" bitfield="true">
        \\      <entry name="a" value="0x1"/>
        \\      <entry name="b" value="2" since="3" summary="b"/>
        \\    </enum>
        \\    <future-element/>
        \\  </interface>
        \\</protocol>
    , null);
    try testing.expectEqualStrings("test", p.name);
    try testing.expectEqualStrings("Copyright \u{a9} somebody", p.copyright.?);
    const i = p.interfaces[0];
    try testing.expectEqualStrings("test_thing", i.name);
    try testing.expectEqual(@as(u32, 3), i.version);
    try testing.expectEqualStrings("It <does> things.", i.description.text.?);
    try testing.expect(i.requests[0].destructor);
    try testing.expectEqual(@as(u32, 2), i.requests[1].since);
    try testing.expectEqualStrings("mode", i.requests[1].args[0].@"enum".?);
    try testing.expect(i.requests[1].args[1].allow_null);
    try testing.expectEqual(@as(?u32, 3), i.events[0].deprecated_since);
    try testing.expectEqual(model.Arg.Type.fd, i.events[0].args[0].type);
    try testing.expectEqualStrings("Read it.", i.events[0].args[0].description.text.?);
    try testing.expect(i.enums[0].bitfield);
    try testing.expectEqual(@as(u32, 1), i.enums[0].entries[0].value);
    try testing.expectEqual(@as(u32, 3), i.enums[0].entries[1].since);
}

test "what is wrong is said" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var d: Diagnostic = .{};
    try testing.expectError(error.InvalidProtocol, parse(arena.allocator(),
        \\<protocol name="p"><interface name="i" version="1">
        \\<request name="r"><arg name="a" type="float"/></request>
        \\</interface></protocol>
    , &d));
    try testing.expectEqualStrings("request i.r: argument a has the unknown type \"float\"", d.message());

    try testing.expectError(error.InvalidProtocol, parse(arena.allocator(), "<nope/>", &d));
    try testing.expectError(error.InvalidProtocol, parse(arena.allocator(),
        \\<protocol name="p"><interface name="i"/></protocol>
    , &d));
    try testing.expectEqualStrings("interface i: <interface> has no version attribute", d.message());
}
