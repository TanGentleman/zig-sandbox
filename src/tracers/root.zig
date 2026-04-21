//! tracers: ingest Claude Code transcripts and serve aggregate analyses.
//! This is a scaffold — real ingest/server logic will land in follow-ups.
const std = @import("std");
const Io = std.Io;

pub fn run(allocator: std.mem.Allocator, args: []const []const u8, writer: *Io.Writer) !void {
    _ = allocator;
    _ = args;
    try writer.writeAll("tracers: stub\n");
}

test "run writes stub line" {
    var buf: [64]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try run(std.testing.allocator, &.{}, &w);
    try std.testing.expectEqualStrings("tracers: stub\n", w.buffered());
}
