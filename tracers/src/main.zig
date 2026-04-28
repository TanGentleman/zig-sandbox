const std = @import("std");
const Io = std.Io;

const tracers = @import("tracers");

// change this to .debug for troubleshooting
pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try tracers.printAnotherMessage(stdout_writer);
    _ = try tracers.mapClaudeTranscripts(init, stdout_writer);
    const digest = try tracers.runLooptap(init, stdout_writer);
    try tracers.printDigest(digest, stdout_writer);

    try stdout_writer.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// Requirements:
// 1. Scan ~/.claude/projects for every jsonl file > 10KB. result_count > 1
// 2. Fill the list with size of the 10 biggest
test "project walk works" {
    const gpa = std.testing.allocator;
    var results_list: std.ArrayList(i32) = .empty;
    defer results_list.deinit(gpa);
    // const result_count = tracers.getBigClaudeTranscriptCount();
    // try std.testing.expect(result_count > 10);
    // for (0..result_count) |i| {
    //     _ = i;
    // }
}
