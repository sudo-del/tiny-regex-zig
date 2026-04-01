# tiny-regex-zig

A small regex implementation in Zig — no allocations, no dependencies.

## About

Compact [regular expression](https://en.wikipedia.org/wiki/Regular_expression) engine written from scratch in Zig. The design takes heavy inspiration from Rob Pike's regex code for the book *"Beautiful Code"* ([available online here](http://www.cs.princeton.edu/courses/archive/spr09/cos333/beautiful.html)).

Supports a practical subset of regex syntax, roughly matching what Python's `re` module offers for simple patterns.

### Goals

- Tiny footprint: everything lives in a single file, compiles to a few kB.
- Zero heap allocations — all storage is stack-local or inline in the `Regex` struct.
- Clear, readable code. No magic.
- Iterative matching to avoid blowing the call stack on long inputs.

### What's supported

| Syntax       | Meaning                                      |
|:-------------|:---------------------------------------------|
| `.`          | Any character (configurable newline behavior) |
| `^`          | Start of string anchor                        |
| `$`          | End of string anchor                          |
| `*`          | Zero or more (greedy)                         |
| `+`          | One or more (greedy)                          |
| `?`          | Zero or one (non-greedy)                      |
| `[abc]`      | Character class                               |
| `[^abc]`     | Inverted character class                      |
| `[a-z]`      | Character range                               |
| `\d` `\D`   | Digit / non-digit                             |
| `\w` `\W`   | Word char / non-word char                     |
| `\s` `\S`   | Whitespace / non-whitespace                   |

### What's NOT supported

- Capture groups / backreferences
- Alternation (`|` as a branch operator)
- Lookahead / lookbehind
- Unicode — this operates on raw bytes

## Usage

### As a Zig dependency

Add this repo to your `build.zig.zon`:

```zig
.dependencies = .{
    .@"tiny-regex" = .{
        .url = "https://github.com/sudo-del/tiny-regex-zig/archive/refs/heads/main.tar.gz",
        // fill in the hash after first fetch
    },
},
```

Then in your `build.zig`:

```zig
const regex_dep = b.dependency("tiny-regex", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("tiny-regex", regex_dep.module("tiny-regex"));
```

And in your code:

```zig
const Regex = @import("tiny-regex").Regex;

const text = "ahem.. 'hello world !' ..";
var re = Regex.compile("[Hh]ello [Ww]orld\\s*[!]?") orelse unreachable;

if (re.match(text)) |m| {
    std.debug.print("match at {d}, length {d}\n", .{ m.index, m.length });
}
```

### Quick one-liner

```zig
if (Regex.run("\\d+", "order #4502")) |m| {
    // m.index == 7, m.length == 4
}
```

### Build & test locally

```bash
zig build test
```

### Run the demo

```bash
zig build run
```

## API

```zig
pub const Regex = struct {
    /// Compile a pattern string. Returns null if the pattern is invalid.
    pub fn compile(pattern: []const u8) ?Regex

    /// Search for the first match of the compiled pattern in `text`.
    pub fn match(self: *const Regex, text: []const u8) ?MatchResult

    /// Compile + match in one call.
    pub fn run(pattern: []const u8, text: []const u8) ?MatchResult

    /// Print compiled pattern nodes to stderr (debugging).
    pub fn debugPrint(self: *const Regex) void
};

pub const MatchResult = struct {
    index: usize,
    length: usize,
};
```

## License

Public domain — see [LICENSE](LICENSE).
