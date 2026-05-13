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
    \\Usage:
    \\  tracers [--signal TYPE]...           print a digest to stdout
    \\  tracers serve [--addr HOST:PORT]     start an HTTP server (text endpoints)
    \\         [--signal TYPE]...
    \\  tracers --version | --help
    \\
    \\Default behavior: walk ~/.claude/projects, run looptap (run → info → query
    \\--signal failure), and print a digest. Requires `looptap` on PATH.
    \\
    \\Options:
    \\  -s, --signal TYPE   signal type to surface; repeatable
    \\                      (default: failure)
    \\      --addr HOST:PORT  listen address for `serve` (default: 127.0.0.1:8787)
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

    if (args.len > 1 and std.mem.eql(u8, args[1], "serve")) {
        return runServe(init, stdout_writer, args[2..]);
    }

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
        switch (matchValueFlag(arg, args, &i, "-s", "--signal")) {
            .matched => |v| {
                try signals.append(arena, v);
                continue;
            },
            .missing_value => try fail(init, "tracers: --signal requires a value\n"),
            .no_match => {},
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

fn runServe(init: std.process.Init, stdout_writer: *Io.Writer, args: []const []const u8) !void {
    const arena = init.arena.allocator();

    var signals: std.ArrayList([]const u8) = .empty;
    var addr: []const u8 = "127.0.0.1:8787";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try stdout_writer.writeAll(usage);
            try stdout_writer.flush();
            return;
        }
        switch (matchValueFlag(arg, args, &i, "-s", "--signal")) {
            .matched => |v| {
                try signals.append(arena, v);
                continue;
            },
            .missing_value => try fail(init, "tracers serve: --signal requires a value\n"),
            .no_match => {},
        }
        switch (matchValueFlag(arg, args, &i, null, "--addr")) {
            .matched => |v| {
                addr = v;
                continue;
            },
            .missing_value => try fail(init, "tracers serve: --addr requires a value\n"),
            .no_match => {},
        }
        try fail(init, "tracers serve: unknown argument\n");
    }

    if (signals.items.len == 0) try signals.append(arena, "failure");

    const parsed = std.Io.net.IpAddress.parseLiteral(addr) catch
        try failAddr(init, addr, "not a valid HOST:PORT");
    if (!tracers.isLoopback(parsed))
        try failAddr(init, addr, "not a loopback address; only 127.0.0.0/8 and [::1] are accepted (auth tracked in TODO.md)");

    const home_dir = try tracers.getHomeDir(init);
    try tracers.serve(init, stdout_writer, .{
        .addr = addr,
        .signals = signals.items,
        .home_dir = home_dir,
    });
}

fn failAddr(init: std.process.Init, addr: []const u8, reason: []const u8) !noreturn {
    var buf: [256]u8 = undefined;
    var fw: Io.File.Writer = .init(.stderr(), init.io, &buf);
    try fw.interface.print("tracers serve: --addr {s} is {s}.\n", .{ addr, reason });
    try fw.interface.flush();
    std.process.exit(2);
}

const ValueFlagResult = union(enum) {
    no_match,
    matched: []const u8,
    missing_value,
};

fn matchValueFlag(
    arg: []const u8,
    args: []const []const u8,
    i: *usize,
    short: ?[]const u8,
    long: []const u8,
) ValueFlagResult {
    const bare_match =
        std.mem.eql(u8, arg, long) or
        (short != null and std.mem.eql(u8, arg, short.?));
    if (bare_match) {
        if (i.* + 1 >= args.len) return .missing_value;
        i.* += 1;
        return .{ .matched = args[i.*] };
    }
    if (std.mem.startsWith(u8, arg, long) and arg.len > long.len and arg[long.len] == '=') {
        const v = arg[long.len + 1 ..];
        if (v.len == 0) return .missing_value;
        return .{ .matched = v };
    }
    return .no_match;
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
