const std = @import("std");
const Io = std.Io;
const nl = "\n";
const print = std.debug.print;
// Constants

// Requirements:
// 1. No ai generated code
// 2. Run the binary, prompted to "pick a file"
// 3. Supports "quit" or value 1-4 as valid.
// 4. If invalid answer, try again, otherwise submit
// 5. Display text from the chosen file (read dynamically)

pub fn runAllocateTask() !void {
    return;
}

const RaiseQuit: type = error{};
const InvalidInput: type = error{};
const Response = struct {
    value: []const u8,
};

fn input_to_response(line: []u8) error{ InvalidInput, RaiseQuit, DelimiterError }!Response {
    if (std.mem.eql(u8, line, "1")) {
        return Response{ .value = line };
    } else if (std.mem.eql(u8, line, "\n")) {
        // this clause should never occur, since delimiter is newline
        std.log.err("found newline. check delimiter!", .{});
        return error.DelimiterError;
    } else if (std.mem.eql(u8, line, "quit")) {
        return error.RaiseQuit;
    }
    return error.InvalidInput;
}

const Settings = struct {
    file_a: []const u8,
    file_b: []const u8,
    file_c: []const u8,
    file_d: []const u8,
    pub fn init() Settings {
        return Settings{
            .file_a = "a",
            .file_b = "b",
            .file_c = "c",
            .file_d = "d",
        };
    }
    fn format_choice_string(self: Settings, buf: []u8) ![]const u8 {
        const res = try std.fmt.bufPrint(buf, "A:{s}{s}B:{s}{s}C:{s}{s}D:{s}{s}", .{ self.file_a, nl, self.file_b, nl, self.file_c, nl, self.file_d, nl });
        return res;
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var temp_buf: [200]u8 = undefined;
    var stdin_buf: [100]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buf);
    const r = &stdin_reader.interface;
    var stdout_buf: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buf);
    const w = &stdout_file_writer.interface;

    // const settings = Settings.init();
    const settings = Settings{
        .file_a = "/tmp/a.txt",
        .file_b = "/tmp/b.txt",
        .file_c = "/tmp/c.txt",
        .file_d = "/tmp/d.txt",
    };
    try w.writeAll("Hi! pick a file:" ++ nl);
    const formatted_string = try settings.format_choice_string(&temp_buf);
    try w.writeAll(formatted_string);
    try w.flush();

    var line: []u8 = undefined;
    line = try r.takeDelimiterExclusive('\n');
    try w.print("You submitted: {s}" ++ nl, .{line});
    const response = input_to_response(line) catch |err| {
        print("Error: {s}" ++ nl, .{@errorName(err)});
        switch (err) {
            error.RaiseQuit => return,
            error.InvalidInput => return,
            else => return err,
        }
    };
    _ = response;
    try w.print("made it to the end!", .{});
    try w.flush();
}
