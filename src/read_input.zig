const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const nl = utils.nl;

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
                utils.printError(err);
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
        utils.printError(err);
    };
    const elapsed = start.untilNow(io, .awake);
    utils.printTimeTaken(elapsed);
}
