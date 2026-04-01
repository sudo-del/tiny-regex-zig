const std = @import("std");
const regex = @import("tiny-regex");
const Regex = regex.Regex;

pub fn main() void {
    // basic match
    const text = "ahem.. 'hello world !' ..";
    const pattern = "[Hh]ello [Ww]orld\\s*[!]?";

    var re = Regex.compile(pattern) orelse {
        std.debug.print("failed to compile: {s}\n", .{pattern});
        return;
    };

    if (re.match(text)) |m| {
        std.debug.print("matched \"{s}\" at offset {d}\n", .{ m.slice(), m.index });
    }

    // findAll: pull out all numbers from a string
    std.debug.print("\nnumbers in 'order #12, qty 5, total $149':\n", .{});
    var nums = Regex.compile("\\d+") orelse return;
    var it = nums.findAll("order #12, qty 5, total $149");
    while (it.next()) |m| {
        std.debug.print("  \"{s}\" at {d}\n", .{ m.slice(), m.index });
    }
}
