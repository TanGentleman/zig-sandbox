const std = @import("std");
const Io = std.Io;
const nl = "\n";
const DELIMITER = "---";

pub fn debugPrintDelimiter() !void {
    std.debug.print("---" ++ nl, .{});
}

pub fn flushDelimiter(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll(DELIMITER ++ nl);
    try writer.flush();
}
