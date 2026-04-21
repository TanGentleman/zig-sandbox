# zig-sandbox

## Context

Tanuj is **learning Zig** while building toward a real tool. Treat this as a
learning repo: prefer small, readable changes, explain *why* when APIs are
non-obvious, and don't reach for abstractions before the concrete code exists.

Current Zig version: **0.16.0**. The std library and build system change
meaningfully between Zig releases — always verify API shape against the
version in use, not from training-data memory.

## Using Zig documentation (IMPORTANT)

Zig's standard library moves fast. Before answering questions about std-lib
APIs, writing non-trivial std-lib code, or recommending an approach, use the
`mcp__zig-docs` MCP server to verify:

- `mcp__zig-docs__search_std_lib` — fuzzy search for items.
- `mcp__zig-docs__get_std_lib_item` — full signatures, fields, methods for a
  fully-qualified name (e.g. `std.heap.FixedBufferAllocator`).
- `mcp__zig-docs__list_builtin_functions` / `get_builtin_function` — for
  `@`-builtins.

Rule of thumb: if the answer names a specific std-lib type, function, or
field, check the docs first. Memory-based answers have already been wrong
once in this project (`GeneralPurposeAllocator` → `DebugAllocator`,
`ThreadSafeAllocator` no longer standalone in `std.heap`).

For third-party libraries (e.g. HTTP frameworks, SQLite wrappers), use the
`context7` MCP before recommending APIs.

## Build & run

```sh
zig build                    # produces ./zig-out/bin/zig_sandbox
./zig-out/bin/zig_sandbox    # note: underscore, not hyphen
zig build test               # runs unit tests in root.zig / main.zig
```

## Project goals

Near-term goal is a single Zig binary that can:

1. **Ingest Claude Code transcripts.** Efficiently parse 1000+ `.jsonl` files
   under `~/.claude/projects/**/` into an in-memory data structure suitable
   for aggregate analysis. Files are append-only JSONL where each line is
   one transcript event.
2. **Serve static analyses.** Local HTTP server that renders aggregate views
   over the ingested data. May persist derived artifacts to JSON/JSONL on
   disk for fast reload.
3. **(Later)** Port a Go indexer/querier over SQLite to Zig.

For (1) and (2), prioritize clarity and correctness over peak throughput
until the shape of the data and the analyses stabilizes.

## Coding conventions (this repo)

- Current code lives in `src/root.zig` (library) and `src/main.zig` (entry).
  New practice functions go in `root.zig` as `pub fn practiceXxx`, invoked
  from `main.zig`.
- Allocator discipline: pass `std.mem.Allocator` in; don't reach for globals.
  For ingest-style bulk work, an `ArenaAllocator` per file or per batch is
  usually the right default.
- Prefer `std.debug.print` only in practice code; real code should take a
  `*std.Io.Writer` so it's testable.
- Keep comments minimal; let names carry the meaning. Add a comment only
  when the *why* isn't obvious from the code.

## Open questions (to resolve as the project grows)

- [ ] HTTP server: `std.http.Server` directly, or a library via `zig fetch`?
- [ ] On-disk format for derived artifacts: one big JSON, sharded JSONL, or
      something binary later?
- [ ] Concurrency model for ingest: single-threaded streaming, thread pool
      over files, or async?
- [ ] Schema handling for transcript events: typed structs via
      `std.json.parseFromSlice`, or `std.json.Value` tree?
