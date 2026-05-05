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

Requires outbound network access to `ziglang.org`. Caches downloads under
`/tmp/zigdocs-cache/<version>/`.

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
```

## When to use which command

| Need                                              | Command                           |
| ------------------------------------------------- | --------------------------------- |
| Discover stdlib symbols matching a keyword        | `zigdocs search <q>`              |
| Read full docs + signature for a known FQN        | `zigdocs get <fqn>`               |
| Read the entire source file containing an item    | `zigdocs get <fqn> --source-file` |
| Browse all `@`-builtins                           | `zigdocs builtins list`           |
| Look up a specific `@builtin` or fuzzy keyword    | `zigdocs builtins get <q>`        |

## Version override

Defaults to Zig `0.16.0`. Override with:

```sh
zigdocs search ArrayList --version 0.15.1
ZIG_DOCS_VERSION=master zigdocs search ArrayList
```

## Exit codes

- `0` — success (markdown on stdout)
- `1` — bad input or "not found" (message on stderr)
- `2` — network/cache failure (message on stderr)

## Troubleshooting

- **`uv: command not found`** — install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- **`network/cache error`** — `ziglang.org` is blocked or unreachable.
  Check your sandbox network policy.
- **`Declaration "..." not found`** — the FQN is wrong. Try
  `zigdocs search` first to discover the correct name.

See `README.md` for build/maintenance details.
