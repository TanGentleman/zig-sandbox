//! tracers: fast CLI for reading and parsing the `~/.claude` folder.
//!
//! Scaffold only — real ingest/serve logic lands in follow-ups. For now this
//! wires up argv dispatch and usage output so subcommands have a home.
const std = @import("std");
const Io = std.Io;

const usage =
    \\usage: tracers <command> [args]
    \\
    \\commands:
    \\  ingest   walk ~/.claude/projects and parse transcripts (todo)
    \\  serve    serve aggregate analyses over HTTP (todo)
    \\  help     show this message
    \\
;

pub fn run(allocator: std.mem.Allocator, args: []const []const u8, writer: *Io.Writer) !void {
    _ = allocator;

    if (args.len < 2) {
        try writer.writeAll(usage);
        return;
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
        try writer.writeAll(usage);
        return;
    }
    if (std.mem.eql(u8, cmd, "ingest")) {
        try writer.writeAll("tracers ingest: not yet implemented\n");
        return;
    }
    if (std.mem.eql(u8, cmd, "serve")) {
        try writer.writeAll("tracers serve: not yet implemented\n");
        return;
    }

    try writer.print("tracers: unknown command '{s}'\n\n", .{cmd});
    try writer.writeAll(usage);
    return error.UnknownCommand;
}

test "no args prints usage" {
    var buf: [256]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try run(std.testing.allocator, &.{"tracers"}, &w);
    try std.testing.expect(std.mem.startsWith(u8, w.buffered(), "usage: tracers"));
}

test "help prints usage" {
    var buf: [256]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try run(std.testing.allocator, &.{ "tracers", "help" }, &w);
    try std.testing.expect(std.mem.startsWith(u8, w.buffered(), "usage: tracers"));
}

test "ingest stub" {
    var buf: [128]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try run(std.testing.allocator, &.{ "tracers", "ingest" }, &w);
    try std.testing.expectEqualStrings("tracers ingest: not yet implemented\n", w.buffered());
}

test "unknown command errors" {
    var buf: [256]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    const res = run(std.testing.allocator, &.{ "tracers", "nope" }, &w);
    try std.testing.expectError(error.UnknownCommand, res);
}
