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
    \\Usage: tracers [--signal TYPE]... [--version | --help]
    \\
    \\Default behavior: walk ~/.claude/projects, run looptap (run → info → query
    \\--signal failure), and print a digest. Requires `looptap` on PATH.
    \\
    \\Options:
    \\  -s, --signal TYPE   signal type to surface; repeatable
    \\                      (default: failure)
    \\  -v, --version       print version and exit
    \\  -h, --help          print this help and exit
    \\
;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);

    var signals: std.ArrayList([]const u8) = .empty;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
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
        if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--signal")) {
            i += 1;
            if (i >= args.len) try fail(init, "tracers: --signal requires a value\n");
            try signals.append(arena, args[i]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--signal=")) {
            const v = arg["--signal=".len..];
            if (v.len == 0) try fail(init, "tracers: --signal requires a value\n");
            try signals.append(arena, v);
            continue;
        }
        var stderr_buffer: [256]u8 = undefined;
        var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
        const stderr_writer = &stderr_file_writer.interface;
        try stderr_writer.print("tracers: unknown argument: {s}\n\n", .{arg});
        try stderr_writer.writeAll(usage);
        try stderr_writer.flush();
        std.process.exit(2);
    }

    if (signals.items.len == 0) try signals.append(arena, "failure");

    const home_dir = try tracers.getHomeDir(init);

    _ = try tracers.mapClaudeTranscripts(init, stdout_writer);
    const digest = try tracers.runLooptap(init, stdout_writer, signals.items);
    try tracers.printDigest(
        init.gpa,
        digest,
        .{ .home_dir = home_dir },
        stdout_writer,
    );
    if (std_options.log_level == .debug) {
        try tracers.dumpDigest(digest, stdout_writer);
    }

    try stdout_writer.flush();
}

fn fail(init: std.process.Init, msg: []const u8) !noreturn {
    var stderr_buffer: [256]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), init.io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;
    try stderr_writer.writeAll(msg);
    try stderr_writer.writeAll(usage);
    try stderr_writer.flush();
    std.process.exit(2);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
