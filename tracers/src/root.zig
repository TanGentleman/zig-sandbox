//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const big_file_threshold: usize = 1024 * 1024;

pub const MapResult = struct {
    filepath: []const u8,
    size_in_bytes: usize,
};

pub const Stat = struct {
    label: []const u8,
    value: usize,
};

pub const FlaggedSignal = struct {
    type: []const u8,
    confidence: f32,
};

pub const FlaggedSession = struct {
    session_id: []const u8,
    raw_path: []const u8,
    started_at: []const u8,
    signals: []const FlaggedSignal,
};

pub const LooptapDigest = struct {
    db_path: ?[]const u8 = null,
    summary: []const Stat = &.{},
    sessions_by_source: []const Stat = &.{},
    signals_by_type: []const Stat = &.{},
    flagged: []const FlaggedSession = &.{},
};

const DigestBuilder = struct {
    arena: std.mem.Allocator,
    db_path: ?[]const u8 = null,
    summary: std.ArrayList(Stat) = .empty,
    sessions_by_source: std.ArrayList(Stat) = .empty,
    signals_by_type: std.ArrayList(Stat) = .empty,
    flagged: std.ArrayList(FlaggedSession) = .empty,

    fn append(b: *DigestBuilder, list: *std.ArrayList(Stat), label: []const u8, value: usize) !void {
        try list.append(b.arena, .{ .label = try b.arena.dupe(u8, label), .value = value });
    }

    fn finalize(b: *DigestBuilder) !LooptapDigest {
        return .{
            .db_path = b.db_path,
            .summary = try b.summary.toOwnedSlice(b.arena),
            .sessions_by_source = try b.sessions_by_source.toOwnedSlice(b.arena),
            .signals_by_type = try b.signals_by_type.toOwnedSlice(b.arena),
            .flagged = try b.flagged.toOwnedSlice(b.arena),
        };
    }
};

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

pub fn runLooptap(
    init: std.process.Init,
    w: *Io.Writer,
    signals: []const []const u8,
) !LooptapDigest {
    const a = init.arena.allocator();
    var builder: DigestBuilder = .{ .arena = a };

    try invokeLooptap(init, w, &.{ "looptap", "run" }, &builder, parseRunOutput);
    try invokeLooptap(init, w, &.{ "looptap", "info" }, &builder, parseInfoOutput);

    var query_argv: std.ArrayList([]const u8) = .empty;
    try query_argv.appendSlice(a, &.{ "looptap", "query", "--format", "jsonl" });
    for (signals) |s| try query_argv.appendSlice(a, &.{ "--signal", s });
    try invokeLooptap(init, w, query_argv.items, &builder, parseQueryOutput);

    return builder.finalize();
}

fn invokeLooptap(
    init: std.process.Init,
    w: *Io.Writer,
    argv: []const []const u8,
    builder: *DigestBuilder,
    parser: *const fn (*DigestBuilder, []const u8) anyerror!void,
) !void {
    const result = std.process.run(init.gpa, init.io, .{ .argv = argv }) catch |err| {
        try w.print("looptap invocation failed: {s}\n", .{@errorName(err)});
        return err;
    };
    defer init.gpa.free(result.stdout);
    defer init.gpa.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        try w.print("looptap failed (term={any}); stderr:\n{s}\n", .{ result.term, result.stderr });
        return error.LooptapFailed;
    }

    parser(builder, result.stdout) catch |err| {
        try w.print(
            "looptap output schema mismatch ({s}); captured stdout:\n{s}\n",
            .{ @errorName(err), result.stdout },
        );
        return err;
    };
}

fn parseRunOutput(b: *DigestBuilder, stdout: []const u8) anyerror!void {
    var saw_found = false;
    var saw_parsed = false;
    var saw_generated = false;

    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "Found ")) {
            const n = fieldAfter(line, "Found") orelse return error.MalformedFoundLine;
            try b.append(&b.summary, "found", n);
            saw_found = true;
        } else if (std.mem.startsWith(u8, line, "Parsed:")) {
            const p = fieldAfter(line, "Parsed:") orelse return error.MalformedParsedLine;
            const s = fieldAfter(line, "Skipped:") orelse return error.MalformedParsedLine;
            const e = fieldAfter(line, "Errors:") orelse return error.MalformedParsedLine;
            try b.append(&b.summary, "parsed", p);
            try b.append(&b.summary, "skipped", s);
            try b.append(&b.summary, "errors", e);
            saw_parsed = true;
        } else if (std.mem.startsWith(u8, line, "Generated ")) {
            const n = fieldAfter(line, "Generated") orelse return error.MalformedGeneratedLine;
            try b.append(&b.summary, "generated signals", n);
            saw_generated = true;
        }
    }

    if (!saw_found) return error.MissingFoundLine;
    if (!saw_parsed) return error.MissingParsedLine;
    if (!saw_generated) return error.MissingGeneratedLine;
}

fn parseInfoOutput(b: *DigestBuilder, stdout: []const u8) anyerror!void {
    const Section = enum { none, sources, signals };
    var section: Section = .none;

    var saw_database = false;
    var saw_sessions = false;
    var saw_turns = false;
    var saw_signals = false;
    var saw_sources_section = false;
    var saw_signals_section = false;

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
                if (rest.len == 0) return error.MalformedDatabaseLine;
                b.db_path = try b.arena.dupe(u8, rest);
                saw_database = true;
            } else if (std.mem.startsWith(u8, line, "Sessions by source:")) {
                section = .sources;
                saw_sources_section = true;
            } else if (std.mem.startsWith(u8, line, "Signals by type:")) {
                section = .signals;
                saw_signals_section = true;
            } else if (std.mem.startsWith(u8, line, "Sessions:")) {
                const n = fieldAfter(line, "Sessions:") orelse return error.MalformedSessionsLine;
                try b.append(&b.summary, "sessions", n);
                saw_sessions = true;
            } else if (std.mem.startsWith(u8, line, "Turns:")) {
                const n = fieldAfter(line, "Turns:") orelse return error.MalformedTurnsLine;
                try b.append(&b.summary, "turns", n);
                saw_turns = true;
            } else if (std.mem.startsWith(u8, line, "Signals:")) {
                const n = fieldAfter(line, "Signals:") orelse return error.MalformedSignalsLine;
                try b.append(&b.summary, "signals", n);
                saw_signals = true;
            }
        } else {
            const stat = parseStat(b.arena, line) catch return error.MalformedStatLine;
            switch (section) {
                .sources => try b.sessions_by_source.append(b.arena, stat),
                .signals => try b.signals_by_type.append(b.arena, stat),
                .none => return error.UnexpectedIndentedLine,
            }
        }
    }

    if (!saw_database) return error.MissingDatabaseLine;
    if (!saw_sessions) return error.MissingSessionsLine;
    if (!saw_turns) return error.MissingTurnsLine;
    if (!saw_signals) return error.MissingSignalsLine;
    if (!saw_sources_section) return error.MissingSessionsBySourceSection;
    if (!saw_signals_section) return error.MissingSignalsByTypeSection;
}

fn parseQueryOutput(b: *DigestBuilder, stdout: []const u8) anyerror!void {
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;

        const session = try std.json.parseFromSliceLeaky(
            FlaggedSession,
            b.arena,
            line,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
        try b.flagged.append(b.arena, session);
    }
}

fn parseStat(arena: std.mem.Allocator, line: []const u8) !Stat {
    var it = std.mem.tokenizeAny(u8, line, " \t");
    const label_tok = it.next() orelse return error.ParseFailed;
    const value_tok = it.next() orelse return error.ParseFailed;
    const value = try std.fmt.parseInt(usize, value_tok, 10);
    return .{ .label = try arena.dupe(u8, label_tok), .value = value };
}

fn fieldAfter(line: []const u8, label: []const u8) ?usize {
    const idx = std.mem.indexOf(u8, line, label) orelse return null;
    const tail = line[idx + label.len ..];
    var it = std.mem.tokenizeAny(u8, tail, " \t");
    const tok = it.next() orelse return null;
    return std.fmt.parseInt(usize, tok, 10) catch null;
}

pub const PrintOptions = struct {
    /// If set, paths that start with `home_dir + "/"` are rewritten with a `~/` prefix.
    home_dir: ?[]const u8 = null,
    /// Max number of flagged-session paths to print. Anything beyond this is
    /// summarised as `... and N more`. 0 means "show all".
    flagged_path_limit: usize = 5,
};

pub const ServeOptions = struct {
    /// Listen address, parsed by `std.Io.net.IpAddress.parseLiteral`
    /// (e.g. "127.0.0.1:8787" or "[::1]:8787").
    addr: []const u8 = "127.0.0.1:8787",
    /// Signal types passed through to `runLooptap`.
    signals: []const []const u8 = &.{"failure"},
    /// Used to collapse the user's home dir to `~` in rendered output.
    home_dir: ?[]const u8 = null,
};

pub fn serve(init: std.process.Init, log_writer: *Io.Writer, opts: ServeOptions) !void {
    const gpa = init.gpa;
    const io = init.io;

    // Build the digest once at startup. The HTTP endpoints serve this
    // snapshot until the process is restarted; on-demand refresh is TODO.
    _ = try mapClaudeTranscripts(init, log_writer);
    const digest = try runLooptap(init, log_writer, opts.signals);

    var digest_buf: std.ArrayList(u8) = .empty;
    defer digest_buf.deinit(gpa);
    var digest_aw: Io.Writer.Allocating = .fromArrayList(gpa, &digest_buf);
    try printDigest(
        gpa,
        digest,
        .{ .home_dir = opts.home_dir, .flagged_path_limit = 0 },
        &digest_aw.writer,
    );
    const digest_text = digest_aw.writer.buffered();

    var flagged_buf: std.ArrayList(u8) = .empty;
    defer flagged_buf.deinit(gpa);
    var flagged_aw: Io.Writer.Allocating = .fromArrayList(gpa, &flagged_buf);
    try renderFlaggedPaths(gpa, &flagged_aw.writer, digest.flagged, opts.home_dir);
    const flagged_text = flagged_aw.writer.buffered();

    const address = try std.Io.net.IpAddress.parseLiteral(opts.addr);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    try log_writer.print("tracers serve listening on http://{f}\n", .{address});
    try log_writer.flush();

    while (true) {
        var stream = server.accept(io) catch |err| {
            try log_writer.print("accept failed: {s}\n", .{@errorName(err)});
            try log_writer.flush();
            continue;
        };
        defer stream.close(io);

        var read_buf: [16 * 1024]u8 = undefined;
        var write_buf: [16 * 1024]u8 = undefined;
        var stream_reader = stream.reader(io, &read_buf);
        var stream_writer = stream.writer(io, &write_buf);
        var http_server = std.http.Server.init(&stream_reader.interface, &stream_writer.interface);

        while (true) {
            var request = http_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => break,
                else => {
                    try log_writer.print("receiveHead failed: {s}\n", .{@errorName(err)});
                    try log_writer.flush();
                    break;
                },
            };

            const route = routeFor(targetPath(request.head.target), digest_text, flagged_text);
            request.respond(route.body, .{
                .status = route.status,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "text/plain; charset=utf-8" },
                },
            }) catch |err| {
                try log_writer.print("respond failed: {s}\n", .{@errorName(err)});
                try log_writer.flush();
                break;
            };

            if (!request.head.keep_alive) break;
        }
    }
}

const Route = struct {
    status: std.http.Status,
    body: []const u8,
};

fn targetPath(target: []const u8) []const u8 {
    if (std.mem.indexOfScalar(u8, target, '?')) |i| return target[0..i];
    return target;
}

fn routeFor(path: []const u8, digest_text: []const u8, flagged_text: []const u8) Route {
    if (std.mem.eql(u8, path, "/")) return .{
        .status = .ok,
        .body =
            \\tracers HTTP server
            \\
            \\GET /digest    rendered digest snapshot (text)
            \\GET /flagged   flagged session paths, one per line, most recent first
            \\
            ,
    };
    if (std.mem.eql(u8, path, "/digest")) return .{ .status = .ok, .body = digest_text };
    if (std.mem.eql(u8, path, "/flagged")) return .{ .status = .ok, .body = flagged_text };
    return .{ .status = .not_found, .body = "not found\n" };
}

fn renderFlaggedPaths(
    gpa: std.mem.Allocator,
    w: *Io.Writer,
    flagged: []const FlaggedSession,
    home_dir: ?[]const u8,
) !void {
    if (flagged.len == 0) return;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    const sorted = try a.dupe(FlaggedSession, flagged);
    std.mem.sort(FlaggedSession, sorted, {}, struct {
        fn lt(_: void, lhs: FlaggedSession, rhs: FlaggedSession) bool {
            return std.mem.order(u8, lhs.started_at, rhs.started_at) == .gt;
        }
    }.lt);

    for (sorted) |session| {
        const pretty = prettifyPath(session.raw_path, home_dir);
        try w.print("{s}{s}\n", .{ pretty.prefix, pretty.rest });
    }
}

pub fn dumpDigest(digest: LooptapDigest, w: *Io.Writer) !void {
    try w.writeAll("\n=== looptap digest (json) ===\n");
    try std.json.Stringify.value(digest, .{ .whitespace = .indent_2 }, w);
    try w.writeByte('\n');
}

pub fn printDigest(
    gpa: std.mem.Allocator,
    digest: LooptapDigest,
    opts: PrintOptions,
    w: *Io.Writer,
) !void {
    try w.writeAll("\n=== looptap digest ===\n");
    if (digest.db_path) |p| {
        const pretty = prettifyPath(p, opts.home_dir);
        try w.print("db: {s}{s}\n", .{ pretty.prefix, pretty.rest });
    }
    try w.writeByte('\n');
    try printStats(w, "summary", digest.summary);
    try printStats(w, "sessions by source", digest.sessions_by_source);
    try printStats(w, "signals by type", digest.signals_by_type);
    try printFlagged(gpa, w, digest.flagged, opts);
}

const PrettyPath = struct {
    prefix: []const u8,
    rest: []const u8,
};

fn prettifyPath(path: []const u8, home_dir: ?[]const u8) PrettyPath {
    const home = home_dir orelse return .{ .prefix = "", .rest = path };
    if (home.len == 0) return .{ .prefix = "", .rest = path };
    if (!std.mem.startsWith(u8, path, home)) return .{ .prefix = "", .rest = path };
    if (path.len == home.len) return .{ .prefix = "~", .rest = "" };
    if (path[home.len] != '/') return .{ .prefix = "", .rest = path };
    return .{ .prefix = "~", .rest = path[home.len..] };
}

fn printFlagged(
    gpa: std.mem.Allocator,
    w: *Io.Writer,
    flagged: []const FlaggedSession,
    opts: PrintOptions,
) !void {
    try w.print("flagged sessions: {d}\n", .{flagged.len});
    if (flagged.len == 0) return;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    var by_type: std.StringArrayHashMapUnmanaged(usize) = .empty;
    for (flagged) |session| {
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        for (session.signals) |sig| {
            if (seen.contains(sig.type)) continue;
            try seen.put(a, sig.type, {});
            const gop = try by_type.getOrPut(a, sig.type);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
        }
    }

    try w.writeAll("  by type\n");
    var label_w: usize = 0;
    var value_w: usize = 0;
    var it = by_type.iterator();
    while (it.next()) |e| {
        label_w = @max(label_w, e.key_ptr.len);
        value_w = @max(value_w, digitWidth(e.value_ptr.*));
    }
    it = by_type.iterator();
    while (it.next()) |e| {
        try w.print("    {s}", .{e.key_ptr.*});
        try writePad(w, label_w - e.key_ptr.len);
        try w.writeAll("  ");
        try writePad(w, value_w - digitWidth(e.value_ptr.*));
        try w.print("{d}\n", .{e.value_ptr.*});
    }

    const sorted = try a.dupe(FlaggedSession, flagged);
    std.mem.sort(FlaggedSession, sorted, {}, struct {
        fn lt(_: void, lhs: FlaggedSession, rhs: FlaggedSession) bool {
            return std.mem.order(u8, lhs.started_at, rhs.started_at) == .gt;
        }
    }.lt);

    const total = sorted.len;
    const limit = if (opts.flagged_path_limit == 0) total else @min(opts.flagged_path_limit, total);
    const hidden = total - limit;

    if (hidden == 0) {
        try w.writeAll("  paths (most recent first)\n");
    } else {
        try w.print("  paths (showing {d} of {d}, most recent first)\n", .{ limit, total });
    }

    for (sorted[0..limit]) |session| {
        const pretty = prettifyPath(session.raw_path, opts.home_dir);
        try w.print("    {s}{s}  (", .{ pretty.prefix, pretty.rest });
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        var first = true;
        for (session.signals) |sig| {
            if (seen.contains(sig.type)) continue;
            try seen.put(a, sig.type, {});
            if (!first) try w.writeAll(", ");
            try w.writeAll(sig.type);
            first = false;
        }
        try w.writeAll(")\n");
    }

    if (hidden > 0) try w.print("    ... and {d} more\n", .{hidden});
}

fn printStats(w: *Io.Writer, header: []const u8, stats: []const Stat) !void {
    if (stats.len == 0) return;
    try w.print("{s}\n", .{header});

    var label_w: usize = 0;
    var value_w: usize = 0;
    for (stats) |s| {
        label_w = @max(label_w, s.label.len);
        value_w = @max(value_w, digitWidth(s.value));
    }

    for (stats) |s| {
        try w.print("  {s}", .{s.label});
        try writePad(w, label_w - s.label.len);
        try w.writeAll("  ");
        try writePad(w, value_w - digitWidth(s.value));
        try w.print("{d}\n", .{s.value});
    }
    try w.writeByte('\n');
}

fn writePad(w: *Io.Writer, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) try w.writeByte(' ');
}

fn digitWidth(n: usize) usize {
    if (n == 0) return 1;
    var x = n;
    var d: usize = 0;
    while (x != 0) : (x /= 10) d += 1;
    return d;
}

test "parseRunOutput extracts file and signal counts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    const stdout =
        \\Found 49 transcript files
        \\Parsed: 17  Skipped: 32  Errors: 0
        \\Processing 17 sessions
        \\Generated 29 signals
        \\
    ;
    try parseRunOutput(&b, stdout);
    const digest = try b.finalize();

    try std.testing.expectEqual(@as(usize, 5), digest.summary.len);
    try std.testing.expectEqualStrings("found", digest.summary[0].label);
    try std.testing.expectEqual(@as(usize, 49), digest.summary[0].value);
    try std.testing.expectEqualStrings("generated signals", digest.summary[4].label);
    try std.testing.expectEqual(@as(usize, 29), digest.summary[4].value);
}

test "parseRunOutput rejects missing Generated line" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    const stdout =
        \\Found 49 transcript files
        \\Parsed: 17  Skipped: 32  Errors: 0
        \\
    ;
    try std.testing.expectError(error.MissingGeneratedLine, parseRunOutput(&b, stdout));
}

test "parseInfoOutput extracts totals and breakdowns" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
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
    try parseInfoOutput(&b, stdout);
    const digest = try b.finalize();

    try std.testing.expectEqualStrings("/tmp/looptap.db", digest.db_path.?);
    try std.testing.expectEqual(@as(usize, 3), digest.summary.len);
    try std.testing.expectEqual(@as(usize, 1), digest.sessions_by_source.len);
    try std.testing.expectEqualStrings("claude-code", digest.sessions_by_source[0].label);
    try std.testing.expectEqual(@as(usize, 75), digest.sessions_by_source[0].value);
    try std.testing.expectEqual(@as(usize, 2), digest.signals_by_type.len);
    try std.testing.expectEqualStrings("failure", digest.signals_by_type[0].label);
    try std.testing.expectEqual(@as(usize, 127), digest.signals_by_type[0].value);
}

test "parseInfoOutput rejects missing Database line" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    const stdout =
        \\Sessions: 75
        \\Turns:    4558
        \\Signals:  255
        \\
        \\Sessions by source:
        \\  claude-code     75
        \\
        \\Signals by type:
        \\  failure         127
        \\
    ;
    try std.testing.expectError(error.MissingDatabaseLine, parseInfoOutput(&b, stdout));
}

test "parseQueryOutput parses jsonl lines into FlaggedSession" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    const stdout =
        \\{"session_id":"a","raw_path":"/p/a.jsonl","started_at":"2026-04-28T03:44:54Z","signals":[{"type":"failure","category":"execution","confidence":0.9,"turn_idx":1,"evidence":"x"},{"type":"failure","confidence":0.6}]}
        \\{"session_id":"b","raw_path":"/p/b.jsonl","started_at":"2026-04-26T16:37:22Z","signals":[{"type":"failure","confidence":0.9},{"type":"loop","confidence":0.7}]}
        \\
    ;
    try parseQueryOutput(&b, stdout);
    const digest = try b.finalize();

    try std.testing.expectEqual(@as(usize, 2), digest.flagged.len);
    try std.testing.expectEqualStrings("a", digest.flagged[0].session_id);
    try std.testing.expectEqualStrings("/p/a.jsonl", digest.flagged[0].raw_path);
    try std.testing.expectEqual(@as(usize, 2), digest.flagged[0].signals.len);
    try std.testing.expectEqualStrings("failure", digest.flagged[0].signals[0].type);
    try std.testing.expectEqualStrings("loop", digest.flagged[1].signals[1].type);
}

test "parseQueryOutput accepts empty stdout" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    try parseQueryOutput(&b, "");
    const digest = try b.finalize();
    try std.testing.expectEqual(@as(usize, 0), digest.flagged.len);
}

test "parseQueryOutput rejects malformed json" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var b: DigestBuilder = .{ .arena = arena.allocator() };
    const stdout =
        \\{"session_id":"a","raw_path":"/p/a.jsonl"
        \\
    ;
    try std.testing.expectError(error.UnexpectedEndOfInput, parseQueryOutput(&b, stdout));
}

test "printFlagged renders by-type counts and paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const flagged = [_]FlaggedSession{
        .{
            .session_id = "a",
            .raw_path = "/p/a.jsonl",
            .started_at = "2026-04-28",
            .signals = &.{
                .{ .type = "failure", .confidence = 0.9 },
                .{ .type = "failure", .confidence = 0.6 },
                .{ .type = "loop", .confidence = 0.7 },
            },
        },
        .{
            .session_id = "b",
            .raw_path = "/p/b.jsonl",
            .started_at = "2026-04-26",
            .signals = &.{
                .{ .type = "failure", .confidence = 0.9 },
            },
        },
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(a);
    var aw: std.Io.Writer.Allocating = .fromArrayList(a, &buf);
    try printFlagged(std.testing.allocator, &aw.writer, &flagged, .{ .flagged_path_limit = 0 });

    const out = aw.writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, out, "flagged sessions: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/a.jsonl  (failure, loop)") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/b.jsonl  (failure)") != null);
}

test "printFlagged truncates beyond limit and notes hidden count" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const flagged = [_]FlaggedSession{
        .{ .session_id = "1", .raw_path = "/p/1.jsonl", .started_at = "2026-05-01", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
        .{ .session_id = "2", .raw_path = "/p/2.jsonl", .started_at = "2026-05-02", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
        .{ .session_id = "3", .raw_path = "/p/3.jsonl", .started_at = "2026-05-03", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
        .{ .session_id = "4", .raw_path = "/p/4.jsonl", .started_at = "2026-05-04", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(a);
    var aw: std.Io.Writer.Allocating = .fromArrayList(a, &buf);
    try printFlagged(std.testing.allocator, &aw.writer, &flagged, .{ .flagged_path_limit = 2 });

    const out = aw.writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, out, "showing 2 of 4, most recent first") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "... and 2 more") != null);
    // Most-recent first: /p/4 then /p/3, and /p/1, /p/2 are hidden.
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/4.jsonl") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/3.jsonl") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/2.jsonl") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/p/1.jsonl") == null);
    // Order check: 4 appears before 3.
    const idx4 = std.mem.indexOf(u8, out, "/p/4.jsonl").?;
    const idx3 = std.mem.indexOf(u8, out, "/p/3.jsonl").?;
    try std.testing.expect(idx4 < idx3);
}

test "targetPath strips query string" {
    try std.testing.expectEqualStrings("/", targetPath("/"));
    try std.testing.expectEqualStrings("/flagged", targetPath("/flagged"));
    try std.testing.expectEqualStrings("/flagged", targetPath("/flagged?signal=failure"));
    try std.testing.expectEqualStrings("/digest", targetPath("/digest?"));
}

test "routeFor maps paths and 404s the rest" {
    const ok_root = routeFor("/", "DIGEST", "FLAGGED");
    try std.testing.expectEqual(std.http.Status.ok, ok_root.status);
    try std.testing.expect(std.mem.indexOf(u8, ok_root.body, "GET /digest") != null);

    const ok_digest = routeFor("/digest", "DIGEST", "FLAGGED");
    try std.testing.expectEqual(std.http.Status.ok, ok_digest.status);
    try std.testing.expectEqualStrings("DIGEST", ok_digest.body);

    const ok_flagged = routeFor("/flagged", "DIGEST", "FLAGGED");
    try std.testing.expectEqual(std.http.Status.ok, ok_flagged.status);
    try std.testing.expectEqualStrings("FLAGGED", ok_flagged.body);

    const missing = routeFor("/nope", "DIGEST", "FLAGGED");
    try std.testing.expectEqual(std.http.Status.not_found, missing.status);
}

test "renderFlaggedPaths sorts most-recent-first and collapses home" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const flagged = [_]FlaggedSession{
        .{ .session_id = "old", .raw_path = "/Users/tan/.claude/projects/old.jsonl", .started_at = "2026-04-01", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
        .{ .session_id = "new", .raw_path = "/Users/tan/.claude/projects/new.jsonl", .started_at = "2026-05-13", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
        .{ .session_id = "other", .raw_path = "/var/log/x.jsonl", .started_at = "2026-05-01", .signals = &.{.{ .type = "failure", .confidence = 0.9 }} },
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(a);
    var aw: Io.Writer.Allocating = .fromArrayList(a, &buf);
    try renderFlaggedPaths(std.testing.allocator, &aw.writer, &flagged, "/Users/tan");

    const out = aw.writer.buffered();
    const idx_new = std.mem.indexOf(u8, out, "~/.claude/projects/new.jsonl") orelse return error.MissingNew;
    const idx_other = std.mem.indexOf(u8, out, "/var/log/x.jsonl") orelse return error.MissingOther;
    const idx_old = std.mem.indexOf(u8, out, "~/.claude/projects/old.jsonl") orelse return error.MissingOld;
    try std.testing.expect(idx_new < idx_other);
    try std.testing.expect(idx_other < idx_old);
}

test "prettifyPath collapses home prefix" {
    const home = "/Users/tan";
    const got = prettifyPath("/Users/tan/.claude/projects/x.jsonl", home);
    try std.testing.expectEqualStrings("~", got.prefix);
    try std.testing.expectEqualStrings("/.claude/projects/x.jsonl", got.rest);

    const same = prettifyPath("/Users/tan", home);
    try std.testing.expectEqualStrings("~", same.prefix);
    try std.testing.expectEqualStrings("", same.rest);

    const other = prettifyPath("/var/log/x", home);
    try std.testing.expectEqualStrings("", other.prefix);
    try std.testing.expectEqualStrings("/var/log/x", other.rest);

    // Don't collapse a longer-named sibling like /Users/tango/...
    const sibling = prettifyPath("/Users/tango/x", home);
    try std.testing.expectEqualStrings("", sibling.prefix);
    try std.testing.expectEqualStrings("/Users/tango/x", sibling.rest);

    // No home given.
    const noop = prettifyPath("/Users/tan/x", null);
    try std.testing.expectEqualStrings("", noop.prefix);
    try std.testing.expectEqualStrings("/Users/tan/x", noop.rest);
}
