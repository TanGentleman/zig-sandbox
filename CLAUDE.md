# zig-sandbox

A Zig learning repo converging on **tracers**: a Zig CLI that orchestrates
[looptap](https://github.com/TanGentleman/looptap) over `~/.claude/projects`
and surfaces flagged transcripts.

Zig version: **0.16.0**. Std library and build system change meaningfully
between releases — verify against the version in use.

## Goals

1. Walk `~/.claude/projects/**/*.jsonl` natively for basic stats. **done**
2. Drive `looptap` as a subprocess to ingest + signal-detect into SQLite.
   **done**
3. Surface the JSONL paths flagged with signals (via a future
   `looptap flagged --json` subcommand) for selection and download.
4. Maybe: serve a small HTTP UI to view, select, and download flagged
   transcripts.

Looptap owns the schema + SQLite. Tracers stays a process orchestrator —
no SQLite Zig dep.

## Layout

```
src/{root,main}.zig         # sandbox / practiceXxx idioms
build.zig                   # builds zig_sandbox

tracers/src/{root,main}.zig # the real tool
tracers/build.zig           # builds tracers
```

`zig build run` from `tracers/` runs the CLI. Tests: `zig build test` in
either tree.

## Coding conventions

- Pass `std.mem.Allocator` in; don't reach for globals. ArenaAllocator per
  batch is usually the right default for ingest-style work.
- Real code takes a `*std.Io.Writer`. Reserve `std.debug.print` for
  sandbox/practice code.
- Comments only when the *why* isn't obvious. Names carry the meaning.

## Resolved decisions

- **Concurrency:** single-threaded. Tracers orchestrates subprocesses; the
  hot loop isn't ours.
- **On-disk format:** looptap's SQLite is the persistence layer. Tracers
  writes nothing.
- **Transcript event schema:** N/A in tracers — looptap parses transcripts.
  When tracers parses JSON (looptap's stdout, future `flagged --json`),
  use typed structs via `std.json.parseFromSlice`.
- **HTTP server (when needed):** `std.http.Server` directly. No fetched
  library until concrete pain shows up.

## Using Zig documentation (IMPORTANT)

Zig's stdlib moves fast. Before writing non-trivial stdlib code, verify
the API. Two equivalent paths — pick whichever is available:

**Preferred: `mcp__zig-docs` MCP** (when connected, e.g. local dev):

- `search_std_lib` — fuzzy search.
- `get_std_lib_item` — signatures, fields, methods for a fully-qualified
  name (pass `get_source_file=true` for full source).
- `list_builtin_functions` / `get_builtin_function` — for `@`-builtins.

**Fallback: `zigdocs` CLI** (when MCP isn't available, e.g. cloud
agents). Same four operations, same output. Lives at
`.claude/skills/zig-docs-cli/`; see its `SKILL.md` for invocation.
Run `zigdocs prefetch` once per session to warm the cache; afterwards
every lookup is offline.

Rule: if the answer names a specific stdlib type, function, or field,
check the docs first. Reach for `--source-file` (CLI) /
`get_source_file=true` (MCP) when the docstring is terse or you need
invariants/internals — `MultiArrayList.items` is a typical case where
the signature alone isn't enough. Inner types live under the defining
module path, not the re-export (`std.multi_array_list.MultiArrayList.Slice`,
not `std.MultiArrayList.Slice`).

For third-party libraries, use `context7` MCP.

## Workflow

- One PR per concern. No stacks for solo work.
- Repo is squash-only with auto-delete-branch on merge — every merge is
  one commit on `main`.
- Treat the **PR body** as the artifact, not branch commits. Polish it
  before merging.
- Reshape history before the first push (`commit --amend`, `rebase -i`,
  `jj`). Never force-push to `main`.
