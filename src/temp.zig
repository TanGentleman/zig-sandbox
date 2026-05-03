const std = @import("std");
const nl = "\n";

fn setBool(val: *bool) bool {
    std.debug.print("val:{}" ++ nl, .{val.*});
    const number: u16 = undefined;
    std.debug.print("val:{d}. Does it equal 4? Answer: {}" ++ nl, .{ number, number == 4 });
    val.* = !val.*;
    return false;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    var bool_value: bool = undefined;
    if (setBool(&bool_value) or (bool_value == true)) try stdout_writer.print("valid!", .{});
    try stdout_writer.flush();
}
