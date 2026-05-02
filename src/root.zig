//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const Zprof = @import("zprof").Zprof;

// my fav constant
const nl = "\n";

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

// check size of pointer
pub fn printPointerSize(w: *Io.Writer) Io.Writer.Error!u8 {
    const val: u8 = 69;
    const ptr = &val;
    const result: u8 = @intCast(@sizeOf(@TypeOf(ptr)));
    try w.print("Pointer size: {d}" ++ nl, .{result});
    return result;
}

// const hi = "hi";

// apply a string modifying function twice
pub fn applyTwice(f: *const fn (*const []u8) *const []const u8, s: *const []u8) *const []u8 {
    _ = f;
    var arbitraryString: *const []u8 = undefined;
    // const ptr = arbitraryString;
    arbitraryString = &"hi";
    // const res = ptr.*;
    return s;
}

fn is_vowel(char: u8) bool {
    const vowels = "aeiouAEIOU";
    for (vowels) |vowel| {
        if (char == vowel) return true;
    }
    return false;
}

// replace vowels with asterisks in a string
pub fn censorString(allocator: std.mem.Allocator, input_string: []const u8) error{OutOfMemory}![]const u8 {
    var s = input_string;
    const max_chars = 10;
    // if (s.len < max_chars)
    const alloc_size = blk: {
        if (input_string.len < max_chars) break :blk input_string.len;
        std.log.err("CHOPPING STRING AT LENGTH: {d}" ++ nl, .{max_chars});
        s = input_string[0..max_chars];
        break :blk max_chars;
    };
    var res = try allocator.alloc(u8, alloc_size);
    var count: usize = 0;
    for (s) |char| {
        std.debug.print("char:{c}" ++ nl, .{char});
        if (is_vowel(char)) {
            std.debug.print("is vowel: {c}" ++ nl, .{char});
            res[count] = '*';
        } else {
            res[count] = char;
        }
        count += 1;
    }
    return res;
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

pub fn practiceFixedBuffer() !void {
    var buffer: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const nums = try allocator.alloc(i32, 4);
    defer allocator.free(nums);
    for (nums, 0..) |*n, i| n.* = @intCast(i * i);

    std.debug.print("fba nums={any} used={d}/{d} bytes\n", .{ nums, fba.end_index, buffer.len });

    // Allocating more than the buffer holds should fail gracefully.
    const too_big = allocator.alloc(u8, 1024) catch |err| {
        std.debug.print("expected failure: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(too_big);
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

// my fixed buffer allocator
// it should:
// 1. set a buffer of type [128]u8 set to undefined
// 2. create a const allocator from an fba
// 3. create a const nums with allocated memory for 4 i32 values
// 4. (remember to defer the free after declaring)
// 5. loop through and set the value of each item in the nums array to i*i (where i is its index)
// 6. debug print the nums and used bytes (fba.end_index/buffer.len)
// 7. set a const too_big with 1024 u8 items in the array. Catch err by printing the errorName and returning early
// 8. (remember to defer the free here too (i don't think this runs if allocation fails))

pub fn myFixedBufferAllocator() !void {
    // These are configurable, try it!
    const BUFFER_BYTES = 128;
    const BUFFER_FRACTION = 1.0 / 8.0;

    const i32_size = @sizeOf(i32); // 4 bytes
    const max_i32_items_in_buffer = BUFFER_BYTES / i32_size;
    const i32_items_to_allocate = @as(usize, @floor(max_i32_items_in_buffer * BUFFER_FRACTION));

    var buffer: [BUFFER_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const nums = try allocator.alloc(i32, i32_items_to_allocate);
    defer allocator.free(nums);
    for (nums, 0..) |*n, i| {
        n.* = @intCast(i * i);
        std.log.info("item {d}, value: {d}", .{ i, n.* });
    }
    try debugPrintDelimiter();
    std.debug.print("Nums: {any}" ++ nl ++ "Bytes used: {d}/{d}" ++ nl, .{ nums, fba.end_index, buffer.len });

    const sus_allocation_size = 113;
    const too_big = allocator.alloc(u8, sus_allocation_size) catch |err| {
        std.debug.print("Error: {s} (tried to allocate {d} bytes)" ++ nl, .{ @errorName(err), sus_allocation_size });
        return;
    };
    defer allocator.free(too_big);
}

pub fn practiceProfiling() !void {
    const BUFFER_BYTES = 100; // 10240 bytes

    var buffer: [BUFFER_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fba_allocator = fba.allocator();

    // 1. Create a profiler by wrapping your allocator with a Config
    var zprof: Zprof(.{}) = .init(fba_allocator, undefined);
    // .{} uses the default config (thread_safe = false, all metrics enabled)

    // 2. Use the profiler's allocator instead of your original one
    const allocator = zprof.allocator();

    // 3. Use the allocator as normal
    const data = try allocator.alloc(u8, 100);

    // Remember LIFO!
    defer std.debug.print("After freeing - Has leaks: {}\n", .{zprof.profiler.hasLeaks()});
    defer allocator.free(data);
    defer std.debug.print("Before freeing - Has leaks: {}\n", .{zprof.profiler.hasLeaks()});
}

pub fn testBufferOverflow() !void {
    const BUFFER_BYTES = 100;
    var buffer: [BUFFER_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var arena = std.heap.ArenaAllocator.init(fba.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const a = try allocator.alloc(u8, 23);
    const b = try allocator.alloc(u32, 3); // 12 bytes, 4-byte aligned

    // Paint everything fba handed out as '#', then stamp user slices on top.
    const base = @intFromPtr(&buffer);
    var map: [BUFFER_BYTES]u8 = undefined;
    for (&map) |*cell| cell.* = '.';
    @memset(map[0..fba.end_index], '#');
    @memset(map[@intFromPtr(a.ptr) - base ..][0..a.len], 'A');
    @memset(map[@intFromPtr(b.ptr) - base ..][0 .. b.len * @sizeOf(u32)], 'B');

    std.debug.print("a: {d} bytes at offset {d}\n", .{ a.len, @intFromPtr(a.ptr) - base });
    std.debug.print("b: {d} bytes at offset {d}\n", .{ b.len * @sizeOf(u32), @intFromPtr(b.ptr) - base });
    std.debug.print("map: {s}\n", .{&map});
    std.debug.print("used {d}/{d}  ('#' = arena bookkeeping, '.' = free)\n", .{ fba.end_index, buffer.len });
}
