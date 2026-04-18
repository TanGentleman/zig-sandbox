//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

// This is a custom message im playing around with
pub fn greetFriends(writer: *Io.Writer) Io.Writer.Error!void {
    const separator = "---\n";
    const group_size = 4;
    const group_members = [_][]const u8{ "Tan", "Ash", "Carl", "Andy" };
    const my_name = group_members[0];
    // my friends are the other members of the group
    const f = group_members[1..];

    try writer.print(separator, .{});
    try writer.print("Greetings to {s}, {s}, and {s}!\n", .{ f[0], f[1], f[2] });
    try writer.print("My name is {s} and today I'll try to be friendly.\n", .{my_name});
    try writer.print(separator, .{});

    // the number of friends must be correct
    std.debug.assert(f.len == group_size - 1);
    // my name must be Tan
    std.debug.assert(std.mem.eql(u8, my_name, "Tan"));
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
