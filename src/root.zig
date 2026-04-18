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
pub fn printAge(writer: *Io.Writer) Io.Writer.Error!void {
    var age: u8 = 24;
    age += 231;
    age += 0; // this would break if over 255
    const new_age: i32 = age;
    try writer.print("You're either {d} or {d} years old.\n", .{ new_age, age });
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
