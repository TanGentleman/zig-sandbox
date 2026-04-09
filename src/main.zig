const std = @import("std");

pub fn main() !void {
    var stdout_file = std.fs.File.stdout();
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    try stdout.print("Do you hear the voices too?!\n", .{});
    try stdout.flush(); // Don't forget to flush!
}

test "sanity" {
    try std.testing.expect(true);
}
