//! tracers: fast CLI for reading and parsing the `~/.claude` folder.
const std = @import("std");
const Io = std.Io;

const usage =
    \\usage: tracers <command> [args]
    \\
    \\commands:
    \\  ingest [dir]   walk dir (default: $HOME/.claude/projects) and count .jsonl files
    \\  serve          serve aggregate analyses over HTTP (todo)
    \\  help           show this message
    \\
;

pub const Summary = struct {
    files: usize = 0,
    bytes: u64 = 0,
};

pub fn run(init: std.process.Init, writer: *Io.Writer) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 2) {
        try writer.writeAll(usage);
        return;
    }

    const cmd = args[1];
    if (eq(cmd, "help") or eq(cmd, "-h") or eq(cmd, "--help")) {
        try writer.writeAll(usage);
        return;
    }
    if (eq(cmd, "ingest")) return cmdIngest(init, args[2..], writer);
    if (eq(cmd, "serve")) {
        try writer.writeAll("tracers serve: not yet implemented\n");
        return;
    }

    try writer.print("tracers: unknown command '{s}'\n\n", .{cmd});
    try writer.writeAll(usage);
    return error.UnknownCommand;
}

fn cmdIngest(init: std.process.Init, extra: []const []const u8, writer: *Io.Writer) !void {
    const arena = init.arena.allocator();
    const root_path = if (extra.len > 0)
        extra[0]
    else
        try defaultProjectsPath(arena, init.environ_map.*);

    var dir = Io.Dir.openDirAbsolute(init.io, root_path, .{ .iterate = true }) catch |err| {
        try writer.print("tracers ingest: cannot open '{s}': {s}\n", .{ root_path, @errorName(err) });
        return err;
    };
    defer dir.close(init.io);

    const summary = try ingestDir(init.gpa, init.io, &dir);
    try writer.print("ingested {d} .jsonl file(s), {d} bytes under {s}\n", .{
        summary.files, summary.bytes, root_path,
    });
}

/// Recursively walk `dir`, counting `.jsonl` files and their total size.
pub fn ingestDir(gpa: std.mem.Allocator, io: Io, dir: *Io.Dir) !Summary {
    var summary: Summary = .{};

    var walker = try dir.walk(gpa);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".jsonl")) continue;

        var file = try entry.dir.openFile(io, entry.basename, .{});
        defer file.close(io);
        const stat = try file.stat(io);

        summary.files += 1;
        summary.bytes += stat.size;
    }

    return summary;
}

fn defaultProjectsPath(arena: std.mem.Allocator, environ: std.process.Environ.Map) ![]u8 {
    const home = environ.get("HOME") orelse return error.HomeNotSet;
    return std.fs.path.join(arena, &.{ home, ".claude", "projects" });
}

fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

test "ingestDir counts only .jsonl files" {
    const testing = std.testing;
    const io = std.testing.io;

    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "a.jsonl", .data = "x\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b.jsonl", .data = "yy\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "ignore.txt", .data = "zzzz" });

    var sub = try tmp.dir.createDirPathOpen(io, "proj", .{ .open_options = .{ .iterate = true } });
    defer sub.close(io);
    try sub.writeFile(io, .{ .sub_path = "c.jsonl", .data = "hi\n" });

    const summary = try ingestDir(testing.allocator, io, &tmp.dir);
    try testing.expectEqual(@as(usize, 3), summary.files);
    try testing.expectEqual(@as(u64, 2 + 3 + 3), summary.bytes);
}

test "defaultProjectsPath joins HOME" {
    const testing = std.testing;
    var map = std.process.Environ.Map.init(testing.allocator);
    defer map.deinit();
    try map.put("HOME", "/home/zig");

    const p = try defaultProjectsPath(testing.allocator, map);
    defer testing.allocator.free(p);
    try testing.expectEqualStrings("/home/zig/.claude/projects", p);
}

test "defaultProjectsPath errors without HOME" {
    const testing = std.testing;
    var map = std.process.Environ.Map.init(testing.allocator);
    defer map.deinit();
    try testing.expectError(error.HomeNotSet, defaultProjectsPath(testing.allocator, map));
}
