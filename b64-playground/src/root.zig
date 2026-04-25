//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const std_alphabet_chars = b64_chars: {
            var chars: [64]u8 = undefined;
            for (0..64) |i| {
                const index: u8 = @intCast(i);
                if (i < 26) {
                    chars[i] = 'A' + index;
                } else if (i < 52) {
                    // loop thru 0..26 for lowercase
                    const lower_index: u8 = index - 26;
                    chars[i] = 'a' + lower_index;
                } else if (i < 62) {
                    // loop through 0..9 for digits
                    const num_index: u8 = index - 52;
                    chars[i] = '0' + num_index;
                } else if (i == 62) {
                    chars[i] = '+';
                } else if (i == 63) {
                    chars[i] = '/';
                } else @panic("control flow takes practice");
            }
            break :b64_chars chars;
        };
        const isEqual = std.mem.eql(u8, std_alphabet_chars[0..64], &std.base64.standard_alphabet_chars);
        if (!isEqual) {
            std.log.err("value of equality test:{}", .{isEqual});
        }
        const uppers = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        std.log.info("{s}", .{std_alphabet_chars});
        const lowers = "abcdefghijklmnopqrstuvwxyz";
        const numbers_and_symbols = "0123456789+/";
        std.log.debug("initializing B64 object", .{});

        return Base64{
            ._table = uppers ++ lowers ++ numbers_and_symbols,
        };
    }

    pub fn init_safe() Base64 {
        return Base64{
            ._table = std.base64.url_safe_alphabet_chars,
        };
    }

    pub fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }
};

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn convertImageToBase64(image: []const u8) !Base64 {
    _ = image;
    const bad_lookup_result = Base64{ ._table = "________________________________________________________________" };
    _ = bad_lookup_result;
    const result = Base64.init();
    return result;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
