const std = @import("std");
const Io = std.Io;
const nl = "\n";

const tracers = @import("tracers");

// Requirements
// 1. walk ~/.claude/projects
// 2. return the bytes found in each .jsonl file
// 3. use subprocess with looptap and parse the output
pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try tracers.printAnotherMessage(stdout_writer);

    try stdout_writer.flush(); // Don't forget to flush!
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
    const result_count = tracers.getBigClaudeTranscriptCount();
    try std.testing.expect(result_count > 10);
    for (0..result_count) |i| {
        std.debug.print("{d}" ++ nl, .{i});
    }
}
// Getting
// failed command: ./.zig-cache/o/1d037555dfc9fa4e4fca3cfdc01a3146/test --cache-dir=./.zig-cache --seed=0xe003723e --listen=-
