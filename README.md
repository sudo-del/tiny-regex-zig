# tiny-regex-zig

[![CI](https://github.com/sudo-del/tiny-regex-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/sudo-del/tiny-regex-zig/actions/workflows/ci.yml)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](LICENSE)

A small, fast regex engine for Zig — zero allocations, zero dependencies, single file.

## Why?

Zig's standard library doesn't ship a regex engine. Most alternatives pull in libc or require an allocator. This one doesn't. The entire thing compiles to ~3kB, runs without a heap, and is easy to drop into any project.

Inspired by Rob Pike's regex code from [*Beautiful Code*](http://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html).

## Features

- **~400 lines** of straightforward Zig — easy to read, audit, and modify
- **Zero heap allocations** — all state lives in a fixed-size struct on the stack
- **No dependencies** — not even libc
- **Iterative matching** — won't blow the stack on long inputs
- **`findAll()` iterator** — iterate over all matches without allocating
- **`slice()` on results** — get the matched text directly, no manual index math
- **C ABI exports** — use from C, C++, Python ctypes, etc.
- **Cross-platform** — tested on Linux, macOS, and Windows via CI
- **80+ tests** covering edge cases, character classes, and anchoring

## Supported syntax

| Pattern      | Description                                   |
|:-------------|:----------------------------------------------|
| `.`          | Any character (configurable newline behavior)  |
| `^`          | Start of string anchor                         |
| `$`          | End of string anchor                           |
| `*`          | Zero or more (greedy)                          |
| `+`          | One or more (greedy)                           |
| `?`          | Zero or one (non-greedy)                       |
| `[abc]`      | Character class                                |
| `[^abc]`     | Inverted character class                       |
| `[a-z]`      | Character range                                |
| `\d` `\D`   | Digit / non-digit                              |
| `\w` `\W`   | Word character / non-word character             |
| `\s` `\S`   | Whitespace / non-whitespace                    |

Not supported (yet): capture groups, alternation (`|`), backreferences, lookahead/behind, unicode. PRs welcome.

## Usage

### As a Zig dependency

## Quickstart

**Option A** — copy `src/regex.zig` into your project. It's a single file with no imports beyond `std`.

**Option B** — use the Zig package manager. Add to `build.zig.zon`:

```zig
.dependencies = .{
    .@"tiny-regex" = .{
        .url = "https://github.com/sudo-del/tiny-regex-zig/archive/refs/heads/main.tar.gz",
        // run `zig build` once, it'll tell you the hash to paste here
    },
},
```

Then in `build.zig`:

```zig
const regex_dep = b.dependency("tiny-regex", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("tiny-regex", regex_dep.module("tiny-regex"));
```

## Examples

```zig
const Regex = @import("tiny-regex").Regex;

// one-liner: compile + match in a single call
if (Regex.run("\\d+", "order #4502")) |m| {
    // m.index == 7, m.length == 4
    // m.slice() returns "4502"
}

// compile once, match many times
var re = Regex.compile("[Hh]ello [Ww]orld\\s*[!]?") orelse unreachable;

if (re.match("hello world !")) |m| {
    std.debug.print("found \"{s}\" at {d}\n", .{ m.slice(), m.index });
}

// find all matches in a string
var nums = Regex.compile("\\d+") orelse unreachable;
var it = nums.findAll("12 apples, 3 oranges, 100 grapes");
while (it.next()) |m| {
    std.debug.print("{s}\n", .{ m.slice() }); // prints "12", "3", "100"
}

// collect into a buffer
var buf: [16]@import("tiny-regex").MatchResult = undefined;
var it2 = nums.findAll("a1 b2 c3");
const n = it2.collect(&buf);
// n == 3, buf[0..3] contains the matches
```

## Build & test

```bash
zig build test     # run 75+ test vectors
zig build run      # run the demo
zig build          # just compile
```

## API

```zig
pub const Regex = struct {
    /// Compile a pattern string. Returns null if the pattern is invalid.
    pub fn compile(pattern: []const u8) ?Regex

    /// Search for the first match in `text`.
    pub fn match(self: *const Regex, text: []const u8) ?MatchResult

    /// Compile + match in one call.
    pub fn run(pattern: []const u8, text: []const u8) ?MatchResult

    /// Returns an iterator over all non-overlapping matches in text.
    pub fn findAll(self: *const Regex, text: []const u8) MatchIterator

    /// Dump compiled nodes to stderr (debugging).
    pub fn debugPrint(self: *const Regex) void
};

pub const MatchResult = struct {
    index: usize,          // byte offset of match start
    length: usize,         // number of bytes matched
    source: []const u8,    // the original text (for slicing)

    /// returns the matched substring
    pub fn slice(self: MatchResult) []const u8
};

pub const MatchIterator = struct {
    /// returns the next match, or null
    pub fn next(self: *MatchIterator) ?MatchResult

    /// collect matches into a caller-provided buffer
    pub fn collect(self: *MatchIterator, buf: []MatchResult) usize
};
```

### C ABI

The library also exports C-compatible functions for FFI usage:

```c
// compile a pattern into caller-provided storage
bool tiny_re_compile_into(const char *pat, size_t pat_len, tiny_re_t *out);

// match against text. returns byte offset or -1 on no match.
ssize_t tiny_re_match(const tiny_re_t *re, const char *text, size_t text_len, size_t *out_len);
```

## Contributing

Found a bug? Have a pattern that doesn't match correctly? PRs and issues are welcome.

```bash
# fork, clone, then:
zig build test        # make sure tests pass
# make your changes
zig fmt src/          # format before committing
zig build test        # verify nothing broke
```

## License

Public domain — see [LICENSE](LICENSE). Do whatever you want with it.
