const std = @import("std");
const Io = std.Io;
pub const nl = "\n";
const DELIMITER = "---";
pub const print = std.debug.print;

pub fn debugPrintDelimiter() !void {
    print("{s}" ++ nl, .{DELIMITER});
}

pub fn flushDelimiter(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll(DELIMITER ++ nl);
    try writer.flush();
}

pub fn printError(err: anyerror) void {
    print("error: {s}" ++ nl, .{@errorName(err)});
}

pub fn printTimeTaken(elapsed: std.Io.Duration) void {
    const nanos = elapsed.toNanoseconds();
    const million: f64 = 1_000_000.0;
    const billion: f64 = 1_000_000_000.0;
    if (nanos < 1_000_000) {
        print("time taken: {d} nanoseconds" ++ nl, .{nanos});
    } else if (nanos < 1_000_000_000) {
        // Show precise ms, including fraction
        const ms: f64 = @as(f64, @floatFromInt(nanos)) / million;
        print("time taken: {d:.1} milliseconds", .{ms});
    } else {
        // Don't truncate to whole seconds: print fraction
        const seconds: f64 = @as(f64, @floatFromInt(nanos)) / billion;
        print("time taken: {d:.2} seconds", .{seconds});
    }
}

/// repeat a function n times with the given arguments
pub fn repeat(comptime F: type, f: F, n: usize, args: anytype) !void {
    for (0..n) |_| {
        try f(args);
    }
}
