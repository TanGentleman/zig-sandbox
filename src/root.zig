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
pub fn printAges(writer: *Io.Writer) Io.Writer.Error!void {
    const separator = "---\n";
    const start_age: u8 = 0;
    _ = start_age;
    const friends: [4][]const u8 = .{ "john", "jane", "jim", "jill" };
    const first_friend = friends[0];
    const f = friends;
    try writer.print(separator, .{});
    try writer.print("hi {s}", .{first_friend});
    try writer.print("\nalso hello to {s}, {s}, and {s}\n", .{ f[1], f[2], f[3] });
    try writer.print(separator, .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
