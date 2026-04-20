//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

// my fav constant
const nl = "\n";

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn debugPrintDelimiter() !void {
    std.debug.print("---" ++ nl, .{});
}

pub fn printDelimiter(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll("---" ++ nl);
}

// This is a custom message im playing around with
pub fn greetFriends(w: *Io.Writer) Io.Writer.Error!void {
    const separator = "---" ++ nl;
    const group_size = 4;
    const group_members = [_][]const u8{ "Tan", "Ash", "Carl", "Andy" };
    const my_name = group_members[0];
    // my friends are the other members of the group
    const f = group_members[1..];

    try w.writeAll(separator);
    try w.print("Greetings to {s}, {s}, and {s}!" ++ nl, .{ f[0], f[1], f[2] });
    try w.print("My name is {s} and today I'll try to be friendly.\n", .{my_name});

    // print the group members
    try w.print("Final attendance:" ++ nl, .{});
    var count: u8 = 0;
    for (group_members) |name| {
        count += 1;
        try w.print("{d}: {s}" ++ nl, .{ count, name });
    }
    try w.writeAll(separator);

    for (f) |name| {
        const val_type = @TypeOf(name);
        std.debug.print("type: {any}" ++ nl, .{val_type});
        // _ = val_type;
    }

    // std.log.info("my friends: {any}\n", .{f});
    // the number of friends must be correct
    std.debug.assert(f.len == group_size - 1);
    // my name must be Tan
    std.debug.assert(std.mem.eql(u8, my_name, "Tan"));
    std.debug.print("greetFriends ended!" ++ nl, .{});
}

pub fn practiceMemory() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const ptr = try allocator.create(i32);
    std.debug.print("ptr={*}\n", .{ptr});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
