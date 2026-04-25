# zig-sandbox

A Zig learning repo converging on **tracers**: a fast CLI for reading and
parsing the `~/.claude` folder.

Current Zig version: **0.16.0**. The std library and build system change
meaningfully between releases — verify API shape against the version in use,
not from training-data memory.

## Project goals

Build a single Zig binary (`tracers`) that:

1. **Ingests Claude Code transcripts.** Walk `~/.claude/projects/**/*.jsonl`
   (append-only, one event per line) into an in-memory representation
   suitable for aggregate analysis. Target: thousands of files, fast.
2. **Serves static analyses.** Local HTTP server rendering aggregate views
   over the ingested data. May persist derived artifacts to disk for fast
   reload.

Prioritize clarity and correctness over peak throughput until the shape of
the data and the analyses stabilizes. I/O and parsing speed is the point —
don't add abstractions before the concrete code exists.

## Layout

```
src/root.zig            # sandbox/practice library
src/main.zig            # sandbox entry point
src/tracers/root.zig    # tracers library (ingest + analyses)
src/tracers/main.zig    # tracers CLI entry point
build.zig               # exposes `zig_sandbox` and `tracers` executables
```

`src/tracers/` is the scaffold for the real tool. `src/root.zig` is where
small `practiceXxx` functions live while learning idioms; they're invoked
from `src/main.zig`.

## Build & run

```sh
zig build                         # produces ./zig-out/bin/{zig_sandbox,tracers}
./zig-out/bin/tracers             # run the tracers CLI
zig build run-tracers -- <args>   # build + run tracers with args
zig build test                    # runs all unit tests
```

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
once here (`GeneralPurposeAllocator` → `DebugAllocator`, `ThreadSafeAllocator`
no longer standalone in `std.heap`).

For third-party libraries (HTTP frameworks, SQLite wrappers, etc.), use the
`context7` MCP before recommending APIs.

## Coding conventions

- Allocator discipline: pass `std.mem.Allocator` in; don't reach for globals.
  For ingest-style bulk work, an `ArenaAllocator` per file or per batch is
  usually the right default.
- Real code takes a `*std.Io.Writer` so it's testable. Reserve
  `std.debug.print` for sandbox/practice code.
- Keep comments minimal; let names carry the meaning. Add a comment only
  when the *why* isn't obvious from the code.
- Small, readable changes. Explain *why* when an API is non-obvious.

## Workflow

- One PR per concern. No stacks for solo work — they over-complicate the
  bookkeeping when there's no second reviewer.
- Repo is configured squash-only with auto-delete-branch on merge, so every
  merge becomes exactly one commit on `main` whose message is the PR title
  and body.
- Treat the **PR body** as the artifact, not the commit messages on the
  branch. Polish the body before merging — that's what'll show up on `main`
  and what's readable later (including on a phone). Local commits during the
  work can be `wip` / `fix test` and disappear into the squash.
- Reshape history *before* the first push: `git commit --amend`,
  `git rebase -i`, or `jj`. After push, only force-push to unmerged review
  branches — never to `main`.

## Open questions

- [ ] HTTP server: `std.http.Server` directly, or a library via `zig fetch`?
- [ ] On-disk format for derived artifacts: one big JSON, sharded JSONL, or
      something binary later?
- [ ] Concurrency model for ingest: single-threaded streaming, thread pool
      over files, or async?
- [ ] Schema handling for transcript events: typed structs via
      `std.json.parseFromSlice`, or `std.json.Value` tree?
