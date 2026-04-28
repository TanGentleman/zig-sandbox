//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const big_file_threshold: usize = 1024 * 1024;

pub const MapResult = struct {
    filepath: []const u8,
    size_in_bytes: usize,
};

pub const KV = struct {
    name: []const u8,
    count: usize,
};

pub const LooptapDigest = struct {
    found: ?usize = null,
    parsed: ?usize = null,
    skipped: ?usize = null,
    errors: ?usize = null,
    generated_signals: ?usize = null,

    db_path: ?[]const u8 = null,
    sessions_total: ?usize = null,
    turns_total: ?usize = null,
    signals_total: ?usize = null,
    sessions_by_source: []const KV = &.{},
    signals_by_type: []const KV = &.{},
};

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

pub fn getHomeDir(init: std.process.Init) ![:0]const u8 {
    return init.minimal.environ.getPosix("HOME") orelse @panic("No HOME dir found");
}

pub fn mapClaudeTranscripts(init: std.process.Init, w: *Io.Writer) ![]MapResult {
    const a = init.arena.allocator();
    const gpa = init.gpa;
    const io = init.io;

    const home_dir = try getHomeDir(init);
    const claude_dir = try std.fs.path.join(a, &.{ home_dir, ".claude", "projects" });

    try w.print("mapping claude transcripts in {s}\n", .{claude_dir});

    var dir = try Io.Dir.openDirAbsolute(io, claude_dir, .{ .iterate = true });
    defer dir.close(io);

    var walker = try dir.walk(gpa);
    defer walker.deinit();

    var results: std.ArrayList(MapResult) = .empty;

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".jsonl")) continue;

        const stat = try entry.dir.statFile(io, entry.basename, .{});
        const size: usize = @intCast(stat.size);
        const filepath = try Io.Dir.path.join(a, &.{ claude_dir, entry.path });
        if (size > big_file_threshold) {
            std.log.debug("large transcript: {s} ({d} bytes)", .{ filepath, size });
        }
        try results.append(a, .{
            .filepath = filepath,
            .size_in_bytes = size,
        });
    }

    try w.print("mapped {d} transcripts\n", .{results.items.len});
    return try results.toOwnedSlice(a);
}

pub fn runLooptap(init: std.process.Init, w: *Io.Writer) !LooptapDigest {
    var digest: LooptapDigest = .{};
    const arena = init.arena.allocator();

    try invokeLooptap(init, w, &.{ "looptap", "run" }, &digest, parseRunOutput);
    try invokeLooptap(init, w, &.{ "looptap", "info" }, &digest, parseInfoOutput);

    _ = arena;
    return digest;
}

fn invokeLooptap(
    init: std.process.Init,
    w: *Io.Writer,
    argv: []const []const u8,
    digest: *LooptapDigest,
    parser: *const fn (std.mem.Allocator, []const u8, *LooptapDigest) anyerror!void,
) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const result = std.process.run(gpa, init.io, .{ .argv = argv }) catch |err| {
        try w.print("looptap invocation failed: {s}\n", .{@errorName(err)});
        return err;
    };
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) {
            try w.print("looptap exited with code {d}; stderr:\n{s}\n", .{ code, result.stderr });
            return error.LooptapFailed;
        },
        else => {
            try w.print("looptap terminated abnormally; stderr:\n{s}\n", .{result.stderr});
            return error.LooptapFailed;
        },
    }

    try parser(arena, result.stdout, digest);
}

fn parseRunOutput(arena: std.mem.Allocator, stdout: []const u8, digest: *LooptapDigest) anyerror!void {
    _ = arena;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "Found ")) {
            digest.found = parseFirstUsize(line);
        } else if (std.mem.startsWith(u8, line, "Parsed:")) {
            digest.parsed = fieldAfter(line, "Parsed:");
            digest.skipped = fieldAfter(line, "Skipped:");
            digest.errors = fieldAfter(line, "Errors:");
        } else if (std.mem.startsWith(u8, line, "Generated ")) {
            digest.generated_signals = parseFirstUsize(line);
        }
    }
}

fn parseInfoOutput(arena: std.mem.Allocator, stdout: []const u8, digest: *LooptapDigest) anyerror!void {
    var sources: std.ArrayList(KV) = .empty;
    var signals: std.ArrayList(KV) = .empty;

    const Section = enum { none, sources, signals };
    var section: Section = .none;

    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw_line| {
        const raw = std.mem.trimEnd(u8, raw_line, "\r");
        if (raw.len == 0) {
            section = .none;
            continue;
        }

        const indented = raw[0] == ' ' or raw[0] == '\t';
        const line = std.mem.trim(u8, raw, " \t");

        if (!indented) {
            section = .none;
            if (std.mem.startsWith(u8, line, "Database:")) {
                const rest = std.mem.trim(u8, line["Database:".len..], " \t");
                digest.db_path = try arena.dupe(u8, rest);
            } else if (std.mem.startsWith(u8, line, "Sessions by source:")) {
                section = .sources;
            } else if (std.mem.startsWith(u8, line, "Signals by type:")) {
                section = .signals;
            } else if (std.mem.startsWith(u8, line, "Sessions:")) {
                digest.sessions_total = fieldAfter(line, "Sessions:");
            } else if (std.mem.startsWith(u8, line, "Turns:")) {
                digest.turns_total = fieldAfter(line, "Turns:");
            } else if (std.mem.startsWith(u8, line, "Signals:")) {
                digest.signals_total = fieldAfter(line, "Signals:");
            }
        } else if (parseKV(arena, line)) |kv| {
            switch (section) {
                .sources => try sources.append(arena, kv),
                .signals => try signals.append(arena, kv),
                .none => {},
            }
        } else |_| {}
    }

    digest.sessions_by_source = try sources.toOwnedSlice(arena);
    digest.signals_by_type = try signals.toOwnedSlice(arena);
}

fn parseKV(arena: std.mem.Allocator, line: []const u8) !KV {
    var it = std.mem.tokenizeAny(u8, line, " \t");
    const name_tok = it.next() orelse return error.ParseFailed;
    const count_tok = it.next() orelse return error.ParseFailed;
    const count = try std.fmt.parseInt(usize, count_tok, 10);
    return .{ .name = try arena.dupe(u8, name_tok), .count = count };
}

fn parseFirstUsize(line: []const u8) ?usize {
    var it = std.mem.tokenizeAny(u8, line, " \t");
    while (it.next()) |tok| {
        if (std.fmt.parseInt(usize, tok, 10)) |n| {
            return n;
        } else |_| {}
    }
    return null;
}

fn fieldAfter(line: []const u8, label: []const u8) ?usize {
    const idx = std.mem.indexOf(u8, line, label) orelse return null;
    const tail = line[idx + label.len ..];
    var it = std.mem.tokenizeAny(u8, tail, " \t");
    const tok = it.next() orelse return null;
    return std.fmt.parseInt(usize, tok, 10) catch null;
}

pub fn printDigest(digest: LooptapDigest, w: *Io.Writer) !void {
    try w.writeAll("\n=== looptap digest ===\n");

    try w.writeAll("run:\n");
    try printOptionalUsize(w, "  found            ", digest.found);
    try printOptionalUsize(w, "  parsed           ", digest.parsed);
    try printOptionalUsize(w, "  skipped          ", digest.skipped);
    try printOptionalUsize(w, "  errors           ", digest.errors);
    try printOptionalUsize(w, "  generated signals", digest.generated_signals);

    try w.writeAll("info:\n");
    if (digest.db_path) |p| {
        try w.print("  db path          {s}\n", .{p});
    } else {
        try w.writeAll("  db path          -\n");
    }
    try printOptionalUsize(w, "  sessions         ", digest.sessions_total);
    try printOptionalUsize(w, "  turns            ", digest.turns_total);
    try printOptionalUsize(w, "  signals          ", digest.signals_total);

    if (digest.sessions_by_source.len > 0) {
        try w.writeAll("  sessions by source:\n");
        for (digest.sessions_by_source) |kv| {
            try w.print("    {s:<14} {d}\n", .{ kv.name, kv.count });
        }
    }
    if (digest.signals_by_type.len > 0) {
        try w.writeAll("  signals by type:\n");
        for (digest.signals_by_type) |kv| {
            try w.print("    {s:<14} {d}\n", .{ kv.name, kv.count });
        }
    }
}

fn printOptionalUsize(w: *Io.Writer, label: []const u8, value: ?usize) !void {
    if (value) |v| {
        try w.print("{s} {d}\n", .{ label, v });
    } else {
        try w.print("{s} -\n", .{label});
    }
}

test "parseRunOutput extracts file and signal counts" {
    const stdout =
        \\Found 49 transcript files
        \\Parsed: 17  Skipped: 32  Errors: 0
        \\Processing 17 sessions
        \\Generated 29 signals
        \\
    ;
    var digest: LooptapDigest = .{};
    try parseRunOutput(std.testing.allocator, stdout, &digest);
    try std.testing.expectEqual(@as(?usize, 49), digest.found);
    try std.testing.expectEqual(@as(?usize, 17), digest.parsed);
    try std.testing.expectEqual(@as(?usize, 32), digest.skipped);
    try std.testing.expectEqual(@as(?usize, 0), digest.errors);
    try std.testing.expectEqual(@as(?usize, 29), digest.generated_signals);
}

test "parseInfoOutput extracts totals and breakdowns" {
    const stdout =
        \\Database: /tmp/looptap.db
        \\
        \\Sessions: 75
        \\Turns:    4558
        \\Signals:  255
        \\
        \\Sessions by source:
        \\  claude-code     75
        \\
        \\Signals by type:
        \\  failure         127
        \\  exhaustion      61
        \\
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var digest: LooptapDigest = .{};
    try parseInfoOutput(arena.allocator(), stdout, &digest);
    try std.testing.expectEqualStrings("/tmp/looptap.db", digest.db_path.?);
    try std.testing.expectEqual(@as(?usize, 75), digest.sessions_total);
    try std.testing.expectEqual(@as(?usize, 4558), digest.turns_total);
    try std.testing.expectEqual(@as(?usize, 255), digest.signals_total);
    try std.testing.expectEqual(@as(usize, 1), digest.sessions_by_source.len);
    try std.testing.expectEqualStrings("claude-code", digest.sessions_by_source[0].name);
    try std.testing.expectEqual(@as(usize, 75), digest.sessions_by_source[0].count);
    try std.testing.expectEqual(@as(usize, 2), digest.signals_by_type.len);
    try std.testing.expectEqualStrings("failure", digest.signals_by_type[0].name);
    try std.testing.expectEqual(@as(usize, 127), digest.signals_by_type[0].count);
}
