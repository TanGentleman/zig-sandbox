const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const nl = utils.nl;

const MAX_INPUT_CHARS = 100;

pub fn runTask(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [100]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;
    var stdin_buffer: [MAX_INPUT_CHARS]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buffer);
    const reader = &stdin_reader.interface;
    errdefer {
        // This avoids leaking input into the shell if user hits Ctrl+C or error occurs.
        while (true) {
            if (reader.takeByte()) |b| {
                if (b == '\n') break;
            } else |err| {
                utils.printError(err);
                break;
            }
        }
    }
    try utils.flushDelimiter(writer);
    var line: []u8 = undefined;
    line = try reader.takeDelimiterExclusive('\n');
    try writer.print("You submitted: {s}" ++ nl, .{line});
    try utils.repeat(*const fn (*std.Io.Writer) std.Io.Writer.Error!void, utils.flushDelimiter, 5, writer);
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
