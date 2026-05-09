---
name: zig-docs-cli
description: Look up Zig 0.16 standard library APIs and builtin functions via a local CLI (replaces the zig-docs MCP server in environments without MCP support, e.g. cloud agents). Use before writing or reviewing Zig code that touches stdlib — critical for std.Io filesystem APIs (std.Io.Dir, std.Io.File), Reader/Writer interfaces, and std.process.Init. Triggers when answering "how do I X in Zig" or writing Zig that touches files, dirs, env, or process state. If the zig-docs MCP server is already connected, prefer it over this CLI.
---

# zig-docs-cli

A Python+wasmtime port of the four `zig-docs` MCP tools. Loads the same
autodoc WASM module the official Zig docs use, against the same
`sources.tar` from `ziglang.org`. Output is markdown, byte-equivalent
(modulo whitespace) to what the MCP returns.

## Setup (run once per agent session/sandbox)

```sh
cd .claude/skills/zig-docs-cli
uv sync
```

Requires outbound network access to `ziglang.org` on first use. Caches
downloads under `/tmp/zigdocs-cache/<version>/`.

## Usage

All commands runnable from any cwd via `uv run --directory`:

```sh
# Search the stdlib
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs search ArrayList --limit 10

# Get full docs for a stdlib item
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs get std.ArrayList

# Get the source file containing an item
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs get std.ArrayList --source-file

# List all builtin functions
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs builtins list

# Look up a builtin (by name or keyword)
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs builtins get atomic

# Pre-populate the cache (so later commands don't need network)
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs prefetch
```

## When to use which command

| Need                                              | Command                           |
| ------------------------------------------------- | --------------------------------- |
| Discover stdlib symbols matching a keyword        | `zigdocs search <q>`              |
| Read full docs + signature for a known FQN        | `zigdocs get <fqn>`               |
| Read the full source file (terse docstring; want invariants, internals, or per-field implementation) | `zigdocs get <fqn> --source-file` |
| Browse all `@`-builtins                           | `zigdocs builtins list`           |
| Look up a specific `@builtin` or fuzzy keyword    | `zigdocs builtins get <q>`        |
| Warm cache before going offline                   | `zigdocs prefetch`                |

**Reach for `--source-file` early** when:

- The docstring is one line or missing.
- The page lists a method signature but elides the body (e.g.
  `MultiArrayList.items` shows the prototype but the per-field pointer
  math from `ptrs[@intFromEnum(field)]` only lives in the source).
- You need invariants, error sets, or how a private field is computed.

## Finding nested types

Inner types live under the **defining module's path**, not the
re-export. `std.MultiArrayList` is a re-export from
`std.multi_array_list`; its inner `Slice` type only resolves at the
defining path:

```sh
zigdocs get std.multi_array_list.MultiArrayList.Slice   # works
zigdocs get std.MultiArrayList.Slice                    # not found
```

If `search` only surfaces a re-export and `get` 404s on the inner type,
re-run `get` with the module path.

## Version override

Defaults to Zig `0.16.0`. Override with:

```sh
zigdocs search ArrayList --version 0.15.1
ZIG_DOCS_VERSION=master zigdocs search ArrayList
```

## Offline mode

If the agent will run without internet, prefetch first while you still
have network:

```sh
# Default cache (/tmp/zigdocs-cache/<version>/)
uv run --directory .claude/skills/zig-docs-cli zigdocs prefetch

# Custom cache directory (persists outside /tmp)
uv run --directory .claude/skills/zig-docs-cli \
  zigdocs prefetch --cache-dir ~/.cache/zigdocs
```

After prefetch, every `search` / `get` / `builtins` call reads from disk
and never touches the network. Pass the same `--cache-dir` (or set
`ZIG_DOCS_CACHE_DIR`) on subsequent commands if you used a non-default
location.

If a bundled snapshot ships inside the package (`src/zigdocs/_data/<version>/`),
the read path uses it automatically and prefetch becomes a no-op.

## Exit codes

- `0` — success (markdown on stdout)
- `1` — bad input or "not found" (message on stderr)
- `2` — network/cache failure (message on stderr)

## Troubleshooting

- **`uv: command not found`** — install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- **`network/cache error`** — `ziglang.org` is blocked or unreachable.
  Run `zigdocs prefetch` from a network-enabled host first, or check
  your sandbox network policy.
- **`Declaration "..." not found`** — the FQN is wrong. Two things to
  try: (1) `zigdocs search` to discover the canonical name; (2) if you
  searched a re-export (e.g. `std.MultiArrayList`), retry `get` against
  the defining module path (e.g. `std.multi_array_list.MultiArrayList`).

See `README.md` for build/maintenance details.
