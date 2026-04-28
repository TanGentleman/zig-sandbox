//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const nl = "\n";

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

// 1. Scan ~/.claude/projects for every jsonl file > 10KB. result_count > 1
pub fn getBigClaudeTranscriptCount(init: std.process.Init, w: *Io.Writer) !usize {
    const gpa = init.gpa;
    const io = init.io;

    const home_dir = init.minimal.environ.getPosix("HOME") orelse return error.NoHome;
    const claude_dir = try std.fs.path.join(gpa, &.{ home_dir, ".claude", "projects" });
    defer gpa.free(claude_dir);

    try w.print("scanning {s}" ++ nl, .{claude_dir});

    var dir = try std.Io.Dir.openDirAbsolute(io, claude_dir, .{ .iterate = true });
    defer dir.close(io);

    var walker = try dir.walk(gpa);
    defer walker.deinit();

    var big_count: usize = 0;
    var total_count: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".jsonl")) continue;

        const stat = try entry.dir.statFile(io, entry.basename, .{});
        if (stat.size > 10 * 1024) {
            std.log.debug("size: {d}", .{stat.size});
            big_count += 1;
        }
        total_count += 1;
    }
    try w.print("found {d} big claude transcripts out of {d} total" ++ nl, .{ big_count, total_count });
    return big_count;
}
