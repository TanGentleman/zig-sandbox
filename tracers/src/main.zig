const std = @import("std");
const Io = std.Io;

const tracers = @import("tracers");
const build_options = @import("build_options");

// change this to .debug for troubleshooting
pub const std_options: std.Options = .{
    .log_level = .info,
};

const usage =
    \\tracers — orchestrate looptap over your Claude transcripts
    \\
    \\Usage: tracers [--version | --help]
    \\
    \\Default behavior: walk ~/.claude/projects, run looptap (run → info → query
    \\--signal failure), and print a digest. Requires `looptap` on PATH.
    \\
    \\Options:
    \\  -v, --version    print version and exit
    \\  -h, --help       print this help and exit
    \\
;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    if (args.len > 1) {
        for (args[1..]) |arg| {
            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try stdout_writer.print("tracers {s}\n", .{build_options.version});
                try stdout_writer.flush();
                return;
            }
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try stdout_writer.writeAll(usage);
                try stdout_writer.flush();
                return;
            }
        }
    }

    _ = try tracers.mapClaudeTranscripts(init, stdout_writer);
    const digest = try tracers.runLooptap(init, stdout_writer);
    try tracers.printDigest(init.gpa, digest, stdout_writer);
    if (std_options.log_level == .debug) {
        try tracers.dumpDigest(digest, stdout_writer);
    }

    try stdout_writer.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
