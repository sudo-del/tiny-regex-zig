const std = @import("std");
const Regex = @import("tiny-regex").Regex;

pub fn main() void {
    const text = "ahem.. 'hello world !' ..";
    const pattern = "[Hh]ello [Ww]orld\\s*[!]?";

    var re = Regex.compile(pattern) orelse {
        std.debug.print("failed to compile pattern: {s}\n", .{pattern});
        return;
    };

    if (re.match(text)) |m| {
        std.debug.print("match at index {d}, {d} chars long.\n", .{ m.index, m.length });
    } else {
        std.debug.print("no match.\n", .{});
    }
}
