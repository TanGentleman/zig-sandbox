const std = @import("std");
const Io = std.Io;
const nl = "\n";

const STACK_BUFFER_SIZE = 21;
const MAX_HEAP_ALLOC = 50;
const MAX_FILE_SIZE_LIMIT = 50;
const TEST_FILE_PATH = "/tmp/zig-rocks.txt";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const path = TEST_FILE_PATH;

    const cwd = Io.Dir.cwd();
    const file = try cwd.openFile(io, path, .{});
    defer file.close(io);

    const file_stat = try file.stat(io);
    const filesize = file_stat.size;
    if (filesize > MAX_FILE_SIZE_LIMIT)
        return error.FileTooLarge;

    var contents: []u8 = undefined;
    var used_heap = false;

    if (filesize <= STACK_BUFFER_SIZE) {
        var buf: [STACK_BUFFER_SIZE]u8 = undefined;
        const bytes_read = try file.readPositionalAll(io, buf[0..filesize], 0);
        contents = buf[0..bytes_read];
    } else {
        if (filesize > MAX_HEAP_ALLOC)
            return error.FileTooLarge;
        contents = try cwd.readFileAlloc(io, path, gpa, std.Io.Limit.limited(filesize + 1));
        used_heap = true;
    }
    defer if (used_heap) gpa.free(contents);

    var out_buf: [STACK_BUFFER_SIZE]u8 = undefined;
    var out_fw = Io.File.Writer.init(.stdout(), io, &out_buf);
    const out = &out_fw.interface;
    try out.writeAll(contents);
    try out.writeAll(nl);
    try out.flush();
}
