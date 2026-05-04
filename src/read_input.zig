const std = @import("std");
const print = std.debug.print;
const nl = "\n";

fn printError(err: anyerror) void {
    print("error: {s}" ++ nl, .{@errorName(err)});
}

pub fn runTask(init: std.process.Init) !void {
    const io = init.io;
    var buf: [5]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &buf);
    const stdin = &stdin_reader.interface;

    var line: []u8 = undefined;
    errdefer {
        // This avoids leaking input into the shell if user hits Ctrl+C or error occurs.
        while (true) {
            if (stdin.takeByte()) |b| {
                if (b == '\n') break;
            } else |err| {
                printError(err);
                break;
            }
        }
    }

    line = try stdin.takeDelimiterExclusive('\n');
    print("line is: {s}" ++ nl, .{line});
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const start = std.Io.Clock.awake.now(io);
    // run task
    runTask(init) catch |err| {
        printError(err);
    };
    const elapsed = start.untilNow(io, .awake);
    printTimeTaken(elapsed);
}

fn printTimeTaken(elapsed: std.Io.Duration) void {
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
