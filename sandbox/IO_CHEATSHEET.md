# Zig 0.16 File I/O Cheat Sheet

For coming-from-Python brains. Companion to `std.Io` (new I/O) and `std.fs.path`.

---

## Mental model

Two independent layers. Don't mix them up.

| Layer | Module | Touches FS? | Needs `io`? | Allocates? |
|---|---|---|---|---|
| **Path strings** (pure byte-slicing) | `std.fs.path.*` | no | no | only `join`/`resolve`/`relative` |
| **Directory & file handles** (syscalls) | `Io.Dir`, `Io.File` | yes | yes | only the `Alloc` variants |

Three intuitions to keep in your head:

1. **`Io.Dir.cwd()` is a handle, not a string.** It's the POSIX `AT_FDCWD` sentinel. You rarely need it as text.
2. **Prefer handles over strings.** Open a `Dir` once; navigate from it. Fewer path traversals, no TOCTOU, matches the kernel.
3. **`io` is threaded explicitly.** Every syscall takes an `Io` parameter. Pure path math does not.

---

## The init dance (every program)

```zig
const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator(); // lives until process exit
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena); // argv as []const []const u8
    _ = args;
    _ = io;
}
```

---

## Python → Zig translation

| Python | Zig | Notes |
|---|---|---|
| `os.getcwd()` | `std.process.currentPath(io, &buf)` → `usize` | slice `buf[0..n]`; buf size: `Io.Dir.max_path_bytes` |
| `os.path.join(a, b)` | `std.fs.path.join(alloc, &.{a, b})` | naive glue; native separator |
| `os.path.abspath(p)` / `normpath` | `std.fs.path.resolve(alloc, &.{p})` | collapses `.` and `..` lexically |
| `os.path.relpath(to, from)` | `std.fs.path.relative(gpa, cwd_str, null, from, to)` | |
| `os.path.dirname(p)` | `std.fs.path.dirname(p)` | returns `?[]const u8`; **slice of `p`** |
| `os.path.basename(p)` | `std.fs.path.basename(p)` | slice of `p` |
| `os.path.isabs(p)` | `std.fs.path.isAbsolute(p)` | |
| `os.path.sep` | `std.fs.path.sep` | |
| `open("foo")` | `Io.Dir.cwd().openFile(io, "foo", .{})` | defer `file.close(io)` |
| `Path("foo").read_text()` | `Io.Dir.cwd().readFileAlloc(io, "foo", alloc, .unlimited)` | caller frees |
| `Path(__file__).parent` | `std.process.executableDirPath(io, &buf)` | |
| `os.scandir(".")` | `dir.iterate()` then `it.next(io)` | dir must be opened with `.{ .iterate = true }` |

---

## Path strings — pure functions, no `io`

```zig
const path = std.fs.path;

path.join(alloc, &.{ "a", "b/", "/c" })   // -> "a/b/c"  (allocates)
path.resolve(alloc, &.{ "a/b", "../c" })  // -> "a/c"    (allocates; lexical only)
path.dirname("/x/y/z.txt")                // -> "/x/y"   (slice of input)
path.basename("/x/y/z.txt")               // -> "z.txt"  (slice of input)
path.isAbsolute("/foo")                   // -> true
path.sep                                  // -> '/' or '\\'
```

Gotchas:
- `dirname` returns `?[]const u8`. `orelse "."` for the "current dir" case.
- `dirname`/`basename` slices die with their input string. `arena.dupe(u8, ...)` to keep.
- `resolve` does NOT follow symlinks. It's text-level only.
- `join` doesn't collapse `..`. Use `resolve` for that.

---

## Opening files

```zig
// Relative to cwd — most common
var file = try Io.Dir.cwd().openFile(io, "data/log.txt", .{});
defer file.close(io);

// Refuse directories
try Io.Dir.cwd().openFile(io, p, .{ .allow_directory = false });

// Refuse escaping via `..` (sandboxing user input)
try some_dir.openFile(io, user_path, .{ .resolve_beneath = true });

// `..` works — kernel resolves it
try Io.Dir.cwd().openFile(io, "../sibling/file", .{});

// Absolute paths work too
try Io.Dir.cwd().openFile(io, "/etc/hostname", .{});
```

`OpenFileOptions` defaults: `.read_only`, `allow_directory = true`, `follow_symlinks = true`.

---

## Reading files — two strategies

### A. Slurp everything (simple, bounded files)

```zig
const bytes = try Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited);
// or .limited(1 << 20) for a 1 MiB cap -> error.StreamTooLong if exceeded
```

### B. Stream (line-by-line, binary records, large files)

```zig
var file = try Io.Dir.cwd().openFile(io, path, .{ .allow_directory = false });
defer file.close(io);

var buf: [64 * 1024]u8 = undefined; // also caps max single record length
var fr: Io.File.Reader = .init(file, io, &buf);
const r: *Io.Reader = &fr.interface;

while (true) {
    const line = r.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => break,
        else => return err,
    };
    // `line` is a slice into `buf` — invalidated by next take*; dupe to keep.
}
```

`Io.Reader` cookbook:
- `takeByte()`, `take(n)`, `takeArray(N)` — raw bytes
- `takeDelimiterExclusive(b)` / `Inclusive(b)` — text
- `takeInt(u32, .little)`, `takeStruct(T, .little)` — binary
- `peek*` — non-consuming variants
- `error.StreamTooLong` from a delimiter = record bigger than your buffer; grow it

---

## Writing files

```zig
var file = try Io.Dir.cwd().createFile(io, "out.txt", .{});
defer file.close(io);

var buf: [4096]u8 = undefined;
var fw: Io.File.Writer = .init(file, io, &buf);
const w: *Io.Writer = &fw.interface;

try w.print("hello {s}\n", .{"world"});
try w.flush(); // ALWAYS flush before close
```

Stdout/stderr are the same pattern with `.stdout()` / `.stderr()` instead of a file handle.

---

## Directory handles — the high-leverage pattern

Open a `Dir` once, navigate from it:

```zig
var dir = try Io.Dir.cwd().openDir(io, "logs", .{ .iterate = true });
defer dir.close(io);

const a = try dir.openFile(io, "a.log", .{}); // cheap relative open
const stat = try dir.statFile(io, "a.log", .{});

var it = dir.iterate();
while (try it.next(io)) |entry| switch (entry.kind) {
    .file => { /* entry.name */ },
    .directory => {},
    else => {},
}
```

Why this matters:
- No path string-building between operations
- Safer (no TOCTOU between stat and open)
- Faster (kernel doesn't re-walk the prefix)

`openDir` options: `.{ .iterate = true }` if you'll list, else `.{}`.

---

## "Where am I?" — three different questions

| Question | Answer |
|---|---|
| What's the current working directory? | `std.process.currentPath(io, &buf)` |
| Where does the executable live on disk? | `std.process.executableDirPath(io, &buf)` |
| What's the full path of the executable? | `std.process.executablePath(io, &buf)` |

All three write into `out_buffer` and return length. Use `Io.Dir.max_path_bytes` as the buffer size.

```zig
var buf: [Io.Dir.max_path_bytes]u8 = undefined;
const n = try std.process.executableDirPath(io, &buf);
const exe_dir = buf[0..n];
```

---

## "Relative to the script/executable" recipe

```zig
// 1. Find the exe directory
var ebuf: [Io.Dir.max_path_bytes]u8 = undefined;
const n = try std.process.executableDirPath(io, &ebuf);
const exe_dir = ebuf[0..n];

// 2a. String approach — build then open against cwd
const path = try std.fs.path.join(arena, &.{ exe_dir, "..", "share", "config.toml" });
const f = try Io.Dir.cwd().openFile(io, path, .{});

// 2b. Handle approach (preferred for >1 file)
var d = try Io.Dir.cwd().openDir(io, exe_dir, .{});
defer d.close(io);
const f2 = try d.openFile(io, "../share/config.toml", .{});
```

---

## Memory ownership cheats

| Returns | Who frees? |
|---|---|
| `*Alloc` variants (`readFileAlloc`, `join`, `resolve`, `relative`, `executableDirPathAlloc`) | caller frees with the allocator passed in |
| `dirname`, `basename` | nobody — they're slices into the input |
| `take*` from `Io.Reader` | nobody — slices into the reader buffer; copy to keep |
| `process.currentPath`, `executablePath`, `executableDirPath` | nobody — slice of your `out_buffer` |

Rule of thumb: if the function takes an `Allocator`, you free. Otherwise the slice borrows from input/buffer.

---

## Common errors & what they mean

| Error | Meaning |
|---|---|
| `error.FileNotFound` | path doesn't exist, or its parent doesn't, or cwd was deleted |
| `error.IsDir` | tried to open a directory as a file (turn off `allow_directory`) |
| `error.NotDir` | a component used as a directory wasn't one |
| `error.AccessDenied` | perms; or on WASI, capability not granted |
| `error.EndOfStream` | reader has no more bytes; normal loop terminator |
| `error.StreamTooLong` | a `take*` couldn't fit a record in the reader buffer |
| `error.NameTooLong` | bump your path buffer or use `Io.Dir.max_path_bytes` |

---

## Anti-patterns to avoid

- Stringifying `cwd` just to immediately re-join and `openFile` — use the cwd handle directly.
- Calling `join` then `openFile` repeatedly under one directory — open it as a `Dir` once.
- Storing slices from `dirname`/`basename`/`take*` past the lifetime of their backing buffer — copy with `dupe`.
- Forgetting `try writer.flush()` before close — output goes missing.
- Forgetting `defer file.close(io)` / `defer dir.close(io)` — leaked fds.
- Using `resolve` and expecting symlink resolution — it's lexical only. Open the path if you need real resolution.

---

## When in doubt

```sh
zigpeek search Io.Dir
zigpeek get std.Io.Dir.openFile
zigpeek get std.fs.path.join
```
