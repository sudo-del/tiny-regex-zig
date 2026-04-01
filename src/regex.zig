//
// Tiny regex engine — a minimal regex implementation in Zig.
//
// Inspired by Rob Pike's regex code described in:
// http://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html
//
// Supports:
//   '.'        Dot, matches any character
//   '^'        Start anchor, matches beginning of string
//   '$'        End anchor, matches end of string
//   '*'        Asterisk, match zero or more (greedy)
//   '+'        Plus, match one or more (greedy)
//   '?'        Question, match zero or one (non-greedy)
//   '[abc]'    Character class, match if one of {'a', 'b', 'c'}
//   '[^abc]'   Inverted class, match if NOT one of {'a', 'b', 'c'}
//   '[a-zA-Z]' Character ranges, the character set of the ranges { a-z | A-Z }
//   '\s'       Whitespace, \t \f \r \n \v and spaces
//   '\S'       Non-whitespace
//   '\w'       Alphanumeric, [a-zA-Z0-9_]
//   '\W'       Non-alphanumeric
//   '\d'       Digits, [0-9]
//   '\D'       Non-digits
//

const std = @import("std");

pub const max_regexp_objects: usize = 30;
pub const max_char_class_len: usize = 40;
pub const dot_matches_newline: bool = true;

const OpType = enum(u8) {
    unused,
    dot,
    begin,
    end,
    questionmark,
    star,
    plus,
    char_literal,
    char_class,
    inv_char_class,
    digit,
    not_digit,
    alpha,
    not_alpha,
    whitespace,
    not_whitespace,
};

// Stores a single compiled regex node. Character classes reference a
// region of the external ccl_buf via start offset + length rather than
// a pointer, so the struct stays valid across copies.
const RegexNode = struct {
    op: OpType = .unused,
    ch: u8 = 0,
    ccl_start: u8 = 0,
    ccl_len: u8 = 0,
};

pub const MatchResult = struct {
    index: usize,
    length: usize,
};

pub const Regex = struct {
    nodes: [max_regexp_objects]RegexNode,
    ccl_buf: [max_char_class_len]u8,
    node_count: usize,

    pub fn compile(pattern: []const u8) ?Regex {
        var self: Regex = undefined;
        @memset(&self.nodes, RegexNode{});
        @memset(&self.ccl_buf, 0);
        self.node_count = 0;

        var ccl_idx: usize = 1;
        var i: usize = 0;
        var j: usize = 0;

        while (i < pattern.len and (j + 1) < max_regexp_objects) {
            const c = pattern[i];

            switch (c) {
                '^' => self.nodes[j].op = .begin,
                '$' => self.nodes[j].op = .end,
                '.' => self.nodes[j].op = .dot,
                '*' => self.nodes[j].op = .star,
                '+' => self.nodes[j].op = .plus,
                '?' => self.nodes[j].op = .questionmark,

                '\\' => {
                    if (i + 1 >= pattern.len) return null;
                    i += 1;
                    switch (pattern[i]) {
                        'd' => self.nodes[j].op = .digit,
                        'D' => self.nodes[j].op = .not_digit,
                        'w' => self.nodes[j].op = .alpha,
                        'W' => self.nodes[j].op = .not_alpha,
                        's' => self.nodes[j].op = .whitespace,
                        'S' => self.nodes[j].op = .not_whitespace,
                        else => {
                            self.nodes[j].op = .char_literal;
                            self.nodes[j].ch = pattern[i];
                        },
                    }
                },

                '[' => {
                    const buf_begin = ccl_idx;

                    if (i + 1 < pattern.len and pattern[i + 1] == '^') {
                        self.nodes[j].op = .inv_char_class;
                        i += 1;
                        if (i + 1 >= pattern.len) return null;
                    } else {
                        self.nodes[j].op = .char_class;
                    }

                    i += 1;
                    while (i < pattern.len and pattern[i] != ']') : (i += 1) {
                        if (pattern[i] == '\\') {
                            if (ccl_idx >= max_char_class_len - 1) return null;
                            if (i + 1 >= pattern.len) return null;
                            self.ccl_buf[ccl_idx] = pattern[i];
                            ccl_idx += 1;
                            i += 1;
                        } else if (ccl_idx >= max_char_class_len) {
                            return null;
                        }
                        self.ccl_buf[ccl_idx] = pattern[i];
                        ccl_idx += 1;
                    }

                    if (ccl_idx >= max_char_class_len) return null;

                    // null-terminate the class buffer
                    self.ccl_buf[ccl_idx] = 0;
                    ccl_idx += 1;

                    self.nodes[j].ccl_start = @intCast(buf_begin);
                    self.nodes[j].ccl_len = @intCast(ccl_idx - buf_begin);
                },

                else => {
                    self.nodes[j].op = .char_literal;
                    self.nodes[j].ch = c;
                },
            }

            if (i >= pattern.len) return null;

            i += 1;
            j += 1;
        }

        self.nodes[j].op = .unused;
        self.node_count = j;
        return self;
    }

    pub fn match(self: *const Regex, text: []const u8) ?MatchResult {
        var length: usize = 0;

        if (self.node_count == 0) return null;

        if (self.nodes[0].op == .begin) {
            if (matchPattern(self.nodes[1..], &self.ccl_buf, text, &length)) {
                return MatchResult{ .index = 0, .length = length };
            }
            return null;
        }

        var idx: usize = 0;
        while (idx <= text.len) : (idx += 1) {
            length = 0;
            if (matchPattern(self.nodes[0..], &self.ccl_buf, text[idx..], &length)) {
                if (idx == text.len and length == 0) return null;
                return MatchResult{ .index = idx, .length = length };
            }
        }
        return null;
    }

    pub fn run(pattern: []const u8, text: []const u8) ?MatchResult {
        var re = Regex.compile(pattern) orelse return null;
        return re.match(text);
    }

    pub fn debugPrint(self: *const Regex) void {
        const type_names = [_][]const u8{
            "UNUSED", "DOT",       "BEGIN",      "END",            "QUESTIONMARK", "STAR",
            "PLUS",   "CHAR",      "CHAR_CLASS", "INV_CHAR_CLASS", "DIGIT",        "NOT_DIGIT",
            "ALPHA",  "NOT_ALPHA", "WHITESPACE", "NOT_WHITESPACE",
        };
        for (self.nodes[0..self.node_count]) |node| {
            if (node.op == .unused) break;
            std.debug.print("type: {s}", .{type_names[@intFromEnum(node.op)]});
            if (node.op == .char_class or node.op == .inv_char_class) {
                std.debug.print(" [", .{});
                const ccl = getCcl(node, &self.ccl_buf);
                for (ccl) |ch| {
                    if (ch == 0) break;
                    std.debug.print("{c}", .{ch});
                }
                std.debug.print("]", .{});
            } else if (node.op == .char_literal) {
                std.debug.print(" '{c}'", .{node.ch});
            }
            std.debug.print("\n", .{});
        }
    }
};

// ---------------------------------------------------------------------------
// matching internals
// ---------------------------------------------------------------------------

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isAlphaNum(c: u8) bool {
    return c == '_' or isAlpha(c) or isDigit(c);
}

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
        else => false,
    };
}

fn matchDot(_: u8) bool {
    if (comptime dot_matches_newline) {
        return true;
    }
    // unreachable when dot_matches_newline is true, but kept
    // here so the logic is complete if the const is toggled.
    return false;
}

fn isMetaChar(c: u8) bool {
    return switch (c) {
        's', 'S', 'w', 'W', 'd', 'D' => true,
        else => false,
    };
}

fn matchMetaChar(c: u8, meta: u8) bool {
    return switch (meta) {
        'd' => isDigit(c),
        'D' => !isDigit(c),
        'w' => isAlphaNum(c),
        'W' => !isAlphaNum(c),
        's' => isWhitespace(c),
        'S' => !isWhitespace(c),
        else => c == meta,
    };
}

fn matchRange(c: u8, str: []const u8) bool {
    if (c == '-') return false;
    if (str.len < 3) return false;
    if (str[0] == 0 or str[0] == '-') return false;
    if (str[1] != '-') return false;
    if (str[2] == 0) return false;
    return c >= str[0] and c <= str[2];
}

fn matchCharClass(c: u8, str: []const u8) bool {
    var i: usize = 0;
    while (i < str.len and str[i] != 0) {
        if (i + 2 < str.len and matchRange(c, str[i..])) return true;

        if (str[i] == '\\') {
            i += 1;
            if (i >= str.len) return false;
            if (matchMetaChar(c, str[i])) return true;
            if (c == str[i] and !isMetaChar(c)) return true;
        } else if (c == str[i]) {
            if (c == '-') {
                return (i == 0) or (i + 1 >= str.len) or (str[i + 1] == 0);
            }
            return true;
        }
        i += 1;
    }
    return false;
}

fn getCcl(node: RegexNode, ccl_buf: *const [max_char_class_len]u8) []const u8 {
    const start: usize = node.ccl_start;
    const len: usize = node.ccl_len;
    return ccl_buf[start .. start + len];
}

fn matchOne(node: RegexNode, c: u8, ccl_buf: *const [max_char_class_len]u8) bool {
    return switch (node.op) {
        .dot => matchDot(c),
        .char_class => matchCharClass(c, getCcl(node, ccl_buf)),
        .inv_char_class => !matchCharClass(c, getCcl(node, ccl_buf)),
        .digit => isDigit(c),
        .not_digit => !isDigit(c),
        .alpha => isAlphaNum(c),
        .not_alpha => !isAlphaNum(c),
        .whitespace => isWhitespace(c),
        .not_whitespace => !isWhitespace(c),
        else => node.ch == c,
    };
}

fn matchStar(p: RegexNode, pattern: []const RegexNode, ccl_buf: *const [max_char_class_len]u8, text: []const u8, length: *usize) bool {
    const prelen = length.*;
    var consumed: usize = 0;

    while (consumed < text.len and matchOne(p, text[consumed], ccl_buf)) {
        consumed += 1;
        length.* += 1;
    }

    while (true) {
        if (matchPattern(pattern, ccl_buf, text[consumed..], length)) return true;
        if (consumed == 0) break;
        consumed -= 1;
        length.* -= 1;
    }

    length.* = prelen;
    return false;
}

fn matchPlus(p: RegexNode, pattern: []const RegexNode, ccl_buf: *const [max_char_class_len]u8, text: []const u8, length: *usize) bool {
    var consumed: usize = 0;

    while (consumed < text.len and matchOne(p, text[consumed], ccl_buf)) {
        consumed += 1;
        length.* += 1;
    }

    while (consumed > 0) {
        if (matchPattern(pattern, ccl_buf, text[consumed..], length)) return true;
        consumed -= 1;
        length.* -= 1;
    }

    return false;
}

fn matchQuestion(p: RegexNode, pattern: []const RegexNode, ccl_buf: *const [max_char_class_len]u8, text: []const u8, length: *usize) bool {
    if (p.op == .unused) return true;

    if (matchPattern(pattern, ccl_buf, text, length)) return true;

    if (text.len > 0 and matchOne(p, text[0], ccl_buf)) {
        if (matchPattern(pattern, ccl_buf, text[1..], length)) {
            length.* += 1;
            return true;
        }
    }
    return false;
}

fn matchPattern(pattern: []const RegexNode, ccl_buf: *const [max_char_class_len]u8, text: []const u8, length: *usize) bool {
    const pre = length.*;
    var pat = pattern;
    var txt = text;

    while (true) {
        if (pat.len == 0 or pat[0].op == .unused) {
            return true;
        }

        if (pat.len > 1 and pat[1].op == .questionmark) {
            return matchQuestion(pat[0], if (pat.len > 2) pat[2..] else pat[0..0], ccl_buf, txt, length);
        }

        if (pat.len > 1 and pat[1].op == .star) {
            return matchStar(pat[0], if (pat.len > 2) pat[2..] else pat[0..0], ccl_buf, txt, length);
        }

        if (pat.len > 1 and pat[1].op == .plus) {
            return matchPlus(pat[0], if (pat.len > 2) pat[2..] else pat[0..0], ccl_buf, txt, length);
        }

        if (pat[0].op == .end and (pat.len < 2 or pat[1].op == .unused)) {
            return txt.len == 0;
        }

        if (txt.len == 0 or !matchOne(pat[0], txt[0], ccl_buf)) {
            length.* = pre;
            return false;
        }

        length.* += 1;
        pat = pat[1..];
        txt = txt[1..];
    }
}
