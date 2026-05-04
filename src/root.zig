//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
// my fav constant
const nl = "\n";

const utils = @import("utils.zig");
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
    try utils.flushDelimiter(w);
    const visible_array = try config.allocator.dupe(u8, config.phrase);
    if (shouldLog(config)) try w.print("Secret phrase: {s}" ++ nl, .{visible_array});
    censorVowelsInPlace(visible_array);
    try w.print("{s}" ++ nl, .{visible_array});
    // try w.print("The phrase is: {s}" ++ nl, .{censored_phrase[0..]});
    try utils.flushDelimiter(w);
    return;
}

// apply a string modifying function twice
pub fn applyTwice(f: *const fn ([]const u8) []const u8, s: []const u8) []const u8 {
    return f(f(s));
}

// test "applyTwice" {
//     const result = applyTwice(doubleString, "hi");
//     try std.testing.expectEqualStrings("hihi", result);
// }

pub fn doubleString(allocator: std.mem.Allocator, input_string: []const u8) error{OutOfMemory}![]const u8 {
    const result = try allocator.alloc(u8, input_string.len * 2);
    @memcpy(result[0..input_string.len], input_string);
    @memcpy(result[input_string.len..], input_string);
    return result;
}

/// check if a character is a non-accented vowel
fn is_vowel(char: u8) bool {
    switch (char) {
        'a', 'e', 'i', 'o', 'u', 'A', 'E', 'I', 'O', 'U' => return true,
        else => return false,
    }
    // Option 2
    // const vowels = "aeiouAEIOU";
    // for (vowels) |vowel| {
    //     if (char == vowel) return true;
    // }
    // return false;
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

test "censorStringTask" {
    const input = "hey there delilah";
    const expected = input ++ "h*y th*r* d*l*l*h";

    var buf: [input.len * 2]u8 = undefined;
    @memcpy(buf[0..input.len], input);
    @memcpy(buf[input.len..][0..input.len], input);
    censorVowelsInPlace(buf[input.len..][0..input.len]);
    try std.testing.expectEqualSlices(u8, expected, buf[0..]);
}

test "doubleString" {
    const input = "born to be wild";
    const expected = "born to be wildborn to be wild";
    const result = try doubleString(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}
