const std = @import("std");
const regex = @import("regex.zig");
const Regex = regex.Regex;
const MatchResult = regex.MatchResult;

const OK = true;
const NOK = false;

const TestCase = struct {
    should_match: bool,
    pattern: []const u8,
    text: []const u8,
    expected_len: usize,
};

const test_vectors = [_]TestCase{
    .{ .should_match = OK, .pattern = "\\d", .text = "5", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "\\w+", .text = "hej", .expected_len = 3 },
    .{ .should_match = OK, .pattern = "\\s", .text = "\t \n", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "\\S", .text = "\t \n", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[\\s]", .text = "\t \n", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "[\\S]", .text = "\t \n", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\D", .text = "5", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\W+", .text = "hej", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[0-9]+", .text = "12345", .expected_len = 5 },
    .{ .should_match = OK, .pattern = "\\D", .text = "hej", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "\\d", .text = "hej", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[^\\w]", .text = "\\", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "[\\W]", .text = "\\", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "[\\w]", .text = "\\", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[^\\d]", .text = "d", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "[\\d]", .text = "d", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "[^\\D]", .text = "d", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[\\D]", .text = "d", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "^.*\\\\.*$", .text = "c:\\Tools", .expected_len = 8 },
    .{ .should_match = OK, .pattern = "^.*\\\\.*$", .text = "c:\\Tools", .expected_len = 8 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "Hello world !", .expected_len = 12 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "hello world !", .expected_len = 12 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "Hello World !", .expected_len = 12 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "Hello world!   ", .expected_len = 11 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "Hello world  !", .expected_len = 13 },
    .{ .should_match = OK, .pattern = "[Hh]ello [Ww]orld\\s*[!]?", .text = "hello World    !", .expected_len = 15 },
    .{ .should_match = OK, .pattern = "[abc]", .text = "1c2", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "[abc]", .text = "1C2", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[1-5]+", .text = "0123456789", .expected_len = 5 },
    .{ .should_match = OK, .pattern = "[.2]", .text = "1C2", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "a*$", .text = "Xaa", .expected_len = 2 },
    .{ .should_match = OK, .pattern = "[a-h]+", .text = "abcdefghxxx", .expected_len = 8 },
    .{ .should_match = NOK, .pattern = "[a-h]+", .text = "ABCDEFGH", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[A-H]+", .text = "ABCDEFGH", .expected_len = 8 },
    .{ .should_match = NOK, .pattern = "[A-H]+", .text = "abcdefgh", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[^\\s]+", .text = "abc def", .expected_len = 3 },
    .{ .should_match = OK, .pattern = "[^fc]+", .text = "abc def", .expected_len = 2 },
    .{ .should_match = OK, .pattern = "[^d\\sf]+", .text = "abc def", .expected_len = 3 },
    .{ .should_match = OK, .pattern = "\n", .text = "abc\ndef", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "b.\\s*\n", .text = "aa\r\nbb\r\ncc\r\n\r\n", .expected_len = 4 },
    .{ .should_match = OK, .pattern = ".*c", .text = "abcabc", .expected_len = 6 },
    .{ .should_match = OK, .pattern = ".+c", .text = "abcabc", .expected_len = 6 },
    .{ .should_match = OK, .pattern = "[b-z].*", .text = "ab", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "b[k-z]*", .text = "ab", .expected_len = 1 },
    .{ .should_match = NOK, .pattern = "[0-9]", .text = "  - ", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[^0-9]", .text = "  - ", .expected_len = 1 },
    .{ .should_match = OK, .pattern = "0|", .text = "0|", .expected_len = 2 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "0s:00:00", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "000:00", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "00:0000", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "100:0:00", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "00:100:00", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "\\d\\d:\\d\\d:\\d\\d", .text = "0:00:100", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "0:0:0", .expected_len = 5 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "0:00:0", .expected_len = 6 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "0:0:00", .expected_len = 5 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "00:0:0", .expected_len = 6 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "00:00:0", .expected_len = 7 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "00:0:00", .expected_len = 6 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "0:00:00", .expected_len = 6 },
    .{ .should_match = OK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "00:00:00", .expected_len = 7 },
    .{ .should_match = NOK, .pattern = "\\d\\d?:\\d\\d?:\\d\\d?", .text = "a:0", .expected_len = 0 },
    .{ .should_match = OK, .pattern = ".?bar", .text = "real_bar", .expected_len = 4 },
    .{ .should_match = NOK, .pattern = ".?bar", .text = "real_foo", .expected_len = 0 },
    .{ .should_match = NOK, .pattern = "X?Y", .text = "Z", .expected_len = 0 },
    .{ .should_match = OK, .pattern = "[a-z]+\nbreak", .text = "blahblah\nbreak", .expected_len = 14 },
    .{ .should_match = OK, .pattern = "[a-z\\s]+\nbreak", .text = "bla bla \nbreak", .expected_len = 14 },
    .{ .should_match = OK, .pattern = "^[\\+-]*[\\d]+$", .text = "+27", .expected_len = 3 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "%JxLLcVx8wxrjsj", .expected_len = 15 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "=KbvUQjsj", .expected_len = 9 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "^uDnoZjsj", .expected_len = 9 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "UzZbjsj", .expected_len = 7 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "\"wjsj", .expected_len = 5 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "zLa_FTEjsj", .expected_len = 10 },
    .{ .should_match = OK, .pattern = ".?\\w+jsj$", .text = "\"mw3p8_Ojsj", .expected_len = 11 },
};

test "hand-picked patterns" {
    var passed: usize = 0;
    var failed: usize = 0;
    const total = test_vectors.len;

    for (test_vectors, 0..) |tc, idx| {
        const result = Regex.run(tc.pattern, tc.text);

        if (tc.should_match) {
            if (result) |m| {
                if (m.length != tc.expected_len) {
                    std.debug.print("[{d}/{d}]: pattern '{s}' matched {d} chars of '{s}'; expected {d}.\n", .{ idx + 1, total, tc.pattern, m.length, tc.text, tc.expected_len });
                    failed += 1;
                } else {
                    passed += 1;
                }
            } else {
                std.debug.print("[{d}/{d}]: pattern '{s}' didn't match '{s}' as expected.\n", .{ idx + 1, total, tc.pattern, tc.text });
                failed += 1;
            }
        } else {
            if (result) |_| {
                std.debug.print("[{d}/{d}]: pattern '{s}' matched '{s}' unexpectedly.\n", .{ idx + 1, total, tc.pattern, tc.text });
                failed += 1;
            } else {
                passed += 1;
            }
        }
    }

    std.debug.print("{d}/{d} test vectors passed.\n", .{ passed, total });
    try std.testing.expect(failed == 0);
}

test "compile rejects invalid patterns" {
    // unterminated inverted class
    try std.testing.expect(Regex.compile("\\\x01[^\\\xff][^") == null);
    // incomplete escape at end of class
    try std.testing.expect(Regex.compile("\\\x01[^\\\xff][\\") == null);
}

test "basic digit match" {
    const m = Regex.run("\\d+", "abc 123 def").?;
    try std.testing.expectEqual(@as(usize, 4), m.index);
    try std.testing.expectEqual(@as(usize, 3), m.length);
}

test "anchored patterns" {
    // start anchor
    {
        const m = Regex.run("^hello", "hello world").?;
        try std.testing.expectEqual(@as(usize, 0), m.index);
        try std.testing.expectEqual(@as(usize, 5), m.length);
    }
    // start anchor with no match
    try std.testing.expect(Regex.run("^world", "hello world") == null);

    // end anchor
    {
        const m = Regex.run("world$", "hello world").?;
        try std.testing.expectEqual(@as(usize, 6), m.index);
        try std.testing.expectEqual(@as(usize, 5), m.length);
    }
}

test "dot matches" {
    const m = Regex.run("h.llo", "hello").?;
    try std.testing.expectEqual(@as(usize, 0), m.index);
    try std.testing.expectEqual(@as(usize, 5), m.length);
}

test "repetition operators" {
    // star
    {
        const m = Regex.run("ab*c", "abbbc").?;
        try std.testing.expectEqual(@as(usize, 5), m.length);
    }
    // plus
    {
        const m = Regex.run("ab+c", "abbbc").?;
        try std.testing.expectEqual(@as(usize, 5), m.length);
    }
    // plus: needs at least one
    try std.testing.expect(Regex.run("ab+c", "ac") == null);
    // question
    {
        const m = Regex.run("ab?c", "ac").?;
        try std.testing.expectEqual(@as(usize, 2), m.length);
    }
}

test "character ranges" {
    {
        const m = Regex.run("[a-z]+", "Hello World").?;
        try std.testing.expectEqual(@as(usize, 1), m.index);
        try std.testing.expectEqual(@as(usize, 4), m.length);
    }
}

test "no match returns null" {
    try std.testing.expect(Regex.run("xyz", "abc") == null);
}

// -- new api tests ---------------------------------------------------------

test "slice returns matched text" {
    const m = Regex.run("\\d+", "abc 42 def").?;
    try std.testing.expectEqualStrings("42", m.slice());
}

test "slice on anchored match" {
    const m = Regex.run("^hello", "hello world").?;
    try std.testing.expectEqualStrings("hello", m.slice());
}

test "findAll basic" {
    var re = Regex.compile("\\d+") orelse unreachable;
    var it = re.findAll("foo 12 bar 345 baz 6");

    const m1 = it.next().?;
    try std.testing.expectEqualStrings("12", m1.slice());
    try std.testing.expectEqual(@as(usize, 4), m1.index);

    const m2 = it.next().?;
    try std.testing.expectEqualStrings("345", m2.slice());

    const m3 = it.next().?;
    try std.testing.expectEqualStrings("6", m3.slice());

    try std.testing.expect(it.next() == null);
}

test "findAll no matches" {
    var re = Regex.compile("xyz") orelse unreachable;
    var it = re.findAll("hello world");
    try std.testing.expect(it.next() == null);
}

test "findAll collect" {
    var re = Regex.compile("[a-z]+") orelse unreachable;
    var it = re.findAll("foo BAR baz QUUX hello");
    var buf: [10]MatchResult = undefined;
    const n = it.collect(&buf);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualStrings("foo", buf[0].slice());
    try std.testing.expectEqualStrings("baz", buf[1].slice());
    try std.testing.expectEqualStrings("hello", buf[2].slice());
}

test "findAll with dot-star doesn't infinite loop" {
    // .* can match zero chars; make sure the iterator advances
    var re = Regex.compile("a*") orelse unreachable;
    var it = re.findAll("bab");
    var count: usize = 0;
    while (it.next()) |_| {
        count += 1;
        if (count > 20) break; // safety net
    }
    // should terminate reasonably
    try std.testing.expect(count <= 10);
}
