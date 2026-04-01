// tiny regex engine for zig
//
// based on:
//  http://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html
//
// supported syntax:
//   .        any character (newline behavior configurable)
//   ^        start anchor
//   $        end anchor
//   *        zero or more (greedy)
//   +        one or more (greedy)
//   ?        zero or one
//   [abc]    character class
//   [^abc]   inverted class
//   [a-z]    ranges
//   \s \S    whitespace / non-whitespace
//   \w \W    word char / non-word
//   \d \D    digit / non-digit

const std = @import("std");

pub const max_regexp_objects: usize = 30;
pub const max_char_class_len: usize = 40;

// flip this if you don't want '.' to match '\n'
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

// ccl uses offset+length into ccl_buf instead of pointers
// so the whole struct is safe to copy by value
const RegexNode = struct {
    op: OpType = .unused,
    ch: u8 = 0,
    ccl_start: u8 = 0,
    ccl_len: u8 = 0,
};

pub const MatchResult = struct {
    index: usize,
    length: usize,
    // keep a ref to the original text so we can slice it
    source: []const u8,

    /// returns the actual matched text
    pub fn slice(self: MatchResult) []const u8 {
        return self.source[self.index .. self.index + self.length];
    }
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
                return MatchResult{ .index = 0, .length = length, .source = text };
            }
            return null;
        }

        var idx: usize = 0;
        while (idx <= text.len) : (idx += 1) {
            length = 0;
            if (matchPattern(self.nodes[0..], &self.ccl_buf, text[idx..], &length)) {
                if (idx == text.len and length == 0) return null;
                return MatchResult{ .index = idx, .length = length, .source = text };
            }
        }
        return null;
    }

    /// convenience: compile + match in one shot
    pub fn run(pattern: []const u8, text: []const u8) ?MatchResult {
        var re = Regex.compile(pattern) orelse return null;
        return re.match(text);
    }

    /// iterate over all non-overlapping matches in text
    pub fn findAll(self: *const Regex, text: []const u8) MatchIterator {
        return MatchIterator{ .re = self, .text = text, .offset = 0 };
    }

    pub fn debugPrint(self: *const Regex) void {
        const names = [_][]const u8{
            "UNUSED", "DOT",       "BEGIN",      "END",            "QUESTIONMARK", "STAR",
            "PLUS",   "CHAR",      "CHAR_CLASS", "INV_CHAR_CLASS", "DIGIT",        "NOT_DIGIT",
            "ALPHA",  "NOT_ALPHA", "WHITESPACE", "NOT_WHITESPACE",
        };
        for (self.nodes[0..self.node_count]) |node| {
            if (node.op == .unused) break;
            std.debug.print("type: {s}", .{names[@intFromEnum(node.op)]});
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

// -- match iterator --------------------------------------------------------

pub const MatchIterator = struct {
    re: *const Regex,
    text: []const u8,
    offset: usize,

    /// returns next non-overlapping match, or null when done
    pub fn next(self: *MatchIterator) ?MatchResult {
        if (self.offset > self.text.len) return null;

        // try matching from current offset onwards
        if (self.re.match(self.text[self.offset..])) |m| {
            var result = m;
            result.index += self.offset;
            result.source = self.text;
            // advance past this match (at least 1 char to avoid infinite loops on zero-width)
            self.offset = result.index + @max(result.length, 1);
            return result;
        }
        self.offset = self.text.len + 1;
        return null;
    }

    /// collect all remaining matches into a fixed buffer.
    /// returns the number of matches written. if there are more
    /// matches than buf.len, the rest are silently dropped.
    pub fn collect(self: *MatchIterator, buf: []MatchResult) usize {
        var n: usize = 0;
        while (n < buf.len) {
            buf[n] = self.next() orelse break;
            n += 1;
        }
        return n;
    }
};

// -- matching internals ----------------------------------------------------
// these are all private; the public api is Regex + MatchResult + MatchIterator

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
    // comptime branch — if dot_matches_newline is on, dot matches everything
    if (comptime dot_matches_newline) return true;
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
            // literal dash only matches at start or end of class
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

    // eat as many as possible (greedy)
    while (consumed < text.len and matchOne(p, text[consumed], ccl_buf)) {
        consumed += 1;
        length.* += 1;
    }

    // then backtrack until the rest of the pattern matches
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
        if (pat.len == 0 or pat[0].op == .unused) return true;

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

// -- C ABI -----------------------------------------------------------------
// lets you use tiny-regex from C, C++, python ctypes, etc.
// TODO: maybe wrap this behind a build option so it doesn't bloat
//       the binary for people who don't need it

const CRegex = extern struct {
    // opaque blob — C code shouldn't poke at internals
    _data: [(@sizeOf(Regex) + 7) / 8]u64 align(@alignOf(Regex)),

    fn fromZig(re: Regex) CRegex {
        var out: CRegex = undefined;
        const dst: *Regex = @ptrCast(@alignCast(&out._data));
        dst.* = re;
        return out;
    }

    fn toZig(self: *const CRegex) *const Regex {
        return @ptrCast(@alignCast(&self._data));
    }
};

export fn tiny_re_compile(pat: [*]const u8, pat_len: usize) ?*CRegex {
    // can't heap-alloc (whole point is zero alloc), so this returns
    // a stack value — caller must copy it. for a more ergonomic C api
    // you'd want the caller to pass a pointer to write into.
    _ = pat;
    _ = pat_len;
    return null; // placeholder, see tiny_re_compile_into
}

/// compile a pattern into caller-provided storage
export fn tiny_re_compile_into(pat: [*]const u8, pat_len: usize, out: *CRegex) bool {
    const pattern = pat[0..pat_len];
    const re = Regex.compile(pattern) orelse return false;
    out.* = CRegex.fromZig(re);
    return true;
}

/// run a match against text. returns -1 on no match, otherwise the byte offset.
/// if out_len is non-null, writes the match length there.
export fn tiny_re_match(crefix: *const CRegex, text: [*]const u8, text_len: usize, out_len: ?*usize) isize {
    const re = crefix.toZig();
    const t = text[0..text_len];
    if (re.match(t)) |m| {
        if (out_len) |p| p.* = m.length;
        return @intCast(m.index);
    }
    return -1;
}
