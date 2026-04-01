# tiny-regex-zig

[![CI](https://github.com/sudo-del/tiny-regex-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/sudo-del/tiny-regex-zig/actions/workflows/ci.yml)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](LICENSE)

A small, fast regex engine for Zig — zero allocations, zero dependencies, single file.

## Why?

Zig's standard library doesn't ship a regex engine. Most alternatives pull in libc or require an allocator. This one doesn't. The entire thing compiles to ~3kB, runs without a heap, and is easy to drop into any project.

Inspired by Rob Pike's regex code from [*Beautiful Code*](http://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html).

## Features

- **~350 lines** of straightforward Zig — easy to read, audit, and modify
- **Zero heap allocations** — all state lives in a fixed-size struct on the stack
- **No dependencies** — not even libc
- **Iterative matching** — won't blow the stack on long inputs
- **Cross-platform** — tested on Linux, macOS, and Windows via CI
- **75 test vectors** covering edge cases, character classes, and anchoring

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

Not supported (yet): capture groups, alternation (`|`), lookahead/behind, unicode.

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
}

// compile once, match many times
var re = Regex.compile("[Hh]ello [Ww]orld\\s*[!]?") orelse unreachable;

if (re.match("hello world !")) |m| {
    std.debug.print("found at {d}, {d} chars\n", .{ m.index, m.length });
}

// returns null on no match — easy to handle
if (Regex.run("xyz", "abc")) |_| {
    // won't reach here
} else {
    std.debug.print("no match\n", .{});
}
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

    /// Dump compiled nodes to stderr (debugging).
    pub fn debugPrint(self: *const Regex) void
};

pub const MatchResult = struct {
    index: usize,  // byte offset of the match start
    length: usize, // number of bytes matched
};
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
