//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
// my fav constant
const nl = "\n";
const DELIMITER = "---";

const GameConfig = struct {
    allocator: std.mem.Allocator,
    writer: *Io.Writer,
    phrase: []const u8,
    total_time: u32 = 10,
    debug_logging: bool = true,
};

// Lets make a game
// Input: A phrase (string) and a total time in seconds (integer)
// Output: Show the censored phrase, and decay it line by line until the user guesses it out loud

fn shouldLog(config: GameConfig) bool {
    return !config.debug_logging;
}

pub fn runGame(config: GameConfig) !void {
    const w = config.writer;
    try w.writeAll("Game starting..." ++ nl);
    try flushDelimiter(w);
    const visible_array = try config.allocator.dupe(u8, config.phrase);
    if (shouldLog(config)) try w.print("Secret phrase: {s}" ++ nl, .{visible_array});
    censorVowelsInPlace(visible_array);
    try w.print("{s}" ++ nl, .{visible_array});
    // try w.print("The phrase is: {s}" ++ nl, .{censored_phrase[0..]});
    try flushDelimiter(w);
    return;
}

// check size of pointer
pub fn printPointerSize(w: *Io.Writer) Io.Writer.Error!u8 {
    const val: u8 = 69;
    const ptr = &val;
    const result: u8 = @intCast(@sizeOf(@TypeOf(ptr)));
    try w.print("Pointer size: {d}" ++ nl, .{result});
    return result;
}

// apply a string modifying function twice
pub fn applyTwice(f: *const fn (*const []u8) *const []const u8, s: *const []u8) *const []u8 {
    _ = f;
    var arbitraryString: *const []u8 = undefined;
    // const ptr = arbitraryString;
    arbitraryString = &"hi";
    // const res = ptr.*;
    return s;
}

pub fn doubleString(allocator: std.mem.Allocator, input_string: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, input_string.len * 2);
    @memcpy(result[0..input_string.len], input_string);
    @memcpy(result[input_string.len..], input_string);
    return result;
}

fn is_vowel(char: u8) bool {
    const vowels = "aeiouAEIOU";
    for (vowels) |vowel| {
        if (char == vowel) return true;
    }
    return false;
}

/// given an array of bytes, replaces vowel chars with asterisks
pub fn censorVowelsInPlace(input_string: []u8) void {
    for (input_string, 0..) |char, i| {
        if (is_vowel(char)) input_string[i] = '*';
    }
}

test "censorVowelsInPlace" {
    var input = "hey there delilah".*;
    censorVowelsInPlace(input[0..]);
    try std.testing.expectEqualStrings("h*y th*r* d*l*l*h", input[0..]);
}

// Accepts an input string and an allocator with a buffer twice its size.
// Fills the allocator with an array combining the input string and a censored version.

test "censorStringTask" {
    const input_string = "hey there delilah";
    const expected_string = input_string ++ "h*y th*r* d*l*l*h";

    var buffer: [input_string.len * 2]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    var input_array = try allocator.alloc(u8, buffer.len);
    @memcpy(input_array[0..], input_string ++ input_string);
    censorVowelsInPlace(input_array[input_string.len..]);
    try std.testing.expectEqualSlices(u8, expected_string, buffer[0..]);
}

pub fn debugPrintDelimiter() !void {
    std.debug.print("---" ++ nl, .{});
}

pub fn flushDelimiter(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll(DELIMITER ++ nl);
    try writer.flush();
}
