# Cloud zig-docs skill — design

**Date:** 2026-05-02
**Status:** approved (pending implementation plan)

## Problem

The `zig-docs` MCP server gives this repo first-class lookup of Zig 0.16
stdlib APIs and `@`-prefixed builtins. It's invaluable when writing
non-trivial stdlib code — `CLAUDE.md` already mandates checking it first.

Cloud agents (Anthropic-hosted Claude agents running outside Claude Code)
have no MCP support, so they fall back to guessing or scraping ziglang.org
ad hoc. The result is wrong stdlib calls — exactly the failure mode the MCP
exists to prevent.

## Goal

Ship a self-contained skill in this repo that gives cloud agents the same
four lookups the MCP provides, with the same markdown output and the same
data source.

The skill must:

1. Be invokable from a hosted Claude agent with bash + file I/O + `ziglang.org`
   allowlisted.
2. Replicate all four MCP tools at full parity:
   `search_std_lib`, `get_std_lib_item`, `list_builtin_functions`,
   `get_builtin_function`.
3. Require zero external services, zero secrets, and only one outbound
   domain (`ziglang.org`).
4. Defer to the local MCP when both are available — no double-coverage.

Non-goals:

- Local-mode parity (using `zig std` from an installed compiler). Cloud
  agents won't have Zig installed; remote-mode-only is enough.
- HTTP server interface. Agents shell out to a CLI, get markdown, done.
- A separate Python implementation of Zig's autodoc. We vendor the same
  WASM the official docs use.

## Approach

The MCP works by driving Zig's official autodoc WASM module against a
`sources.tar` of stdlib source files, then composing markdown from the
WASM's HTML-producing exports. Re-implementing that parser in Python would
be enormous work and would never reach output parity.

So we **port the MCP's remote mode to Python**. Same WASM, same
`sources.tar`, same rendering algorithm — just translated from TypeScript
to Python with `wasmtime-py` instead of Node's `WebAssembly` API.

The result is byte-equivalent (modulo trivial whitespace) markdown output
for the same inputs.

## Architecture

```
.claude/skills/zig-docs-cli/
├── SKILL.md                       # frontmatter + agent instructions
├── README.md                      # human docs: what this is, how to update WASM
├── pyproject.toml                 # uv project: wasmtime, httpx, beautifulsoup4
├── uv.lock
├── .python-version                # 3.12+
├── src/zigdocs/
│   ├── __init__.py
│   ├── cli.py                     # `zigdocs` entrypoint (argparse subcommands)
│   ├── fetch.py                   # download + cache sources.tar and langref HTML
│   ├── wasm.py                    # wasmtime driver: typed Python API around exports
│   ├── stdlib.py                  # markdown rendering (port of mcp/std.ts)
│   ├── builtins.py                # langref HTML → builtins (port of extract-builtin-functions.ts)
│   └── version.py                 # default Zig version + override resolution
├── vendor/
│   ├── main.wasm                  # vendored from zig-mcp; ~1 MB
│   └── PROVENANCE.md              # SHA, build date, rebuild instructions
└── tests/
    ├── fixtures/
    │   ├── tiny-langref.html      # one builtin section, for parser tests
    │   └── tiny-sources.tar       # 1-2 small Zig files, real format
    ├── test_builtins.py
    ├── test_stdlib.py             # smoke: hits ziglang.org once, gated by env
    └── test_cli.py
```

### Data sources at runtime

| Tool                       | Source                                                          | Cache path                                  |
| -------------------------- | --------------------------------------------------------------- | ------------------------------------------- |
| `search_std_lib`           | `https://ziglang.org/documentation/<v>/std/sources.tar` + WASM | `/tmp/zigdocs-cache/<v>/sources.tar`        |
| `get_std_lib_item`         | (same)                                                          | (same)                                      |
| `list_builtin_functions`   | `https://ziglang.org/documentation/<v>/` (single HTML page)    | `/tmp/zigdocs-cache/<v>/builtins.json`      |
| `get_builtin_function`     | (same as above; cached parsed JSON)                             | (same)                                      |

The WASM is vendored, not fetched — single binary, ~1 MB, doesn't need to
change unless we bump Zig versions.

Cache is content-immutable per Zig version tag (release tarballs are
immutable). Cache lives in `/tmp` (cloud-agent-friendly: writable,
ephemeral, repo-clean). A `--refresh` flag forces re-download.

Default Zig version: `0.16.0` (matches `CLAUDE.md`). Overridable via
`--version` flag or `ZIG_DOCS_VERSION` env var.

## CLI

One entrypoint, four subcommands matching the four MCP tools 1:1.

```sh
uv run zigdocs search <query> [--limit N] [--version V] [--refresh]
uv run zigdocs get <fqn> [--source-file] [--version V] [--refresh]
uv run zigdocs builtins list [--version V] [--refresh]
uv run zigdocs builtins get <name_or_keyword> [--version V] [--refresh]
```

**Output contract:**

- Success → markdown on stdout, exit 0.
- Bad input or "not found" → message on stderr, exit 1.
- Network or cache failure → message on stderr, exit 2.

**Markdown shape:** byte-equivalent to the MCP for the same inputs. We
port the same renderer; smoke tests guard against drift.

**Defaults:** `--limit 20` (matches MCP), `--version 0.16.0`,
`--source-file` is a boolean flag (matches MCP's `get_source_file`).

**Why subcommands:** one `pyproject.toml`, one `uv sync`, one entrypoint
visible in transcripts. `argparse` with subparsers — no Click/Typer
dependency.

## WASM driver

`wasmtime-py` (mature, MIT, pip-installable) loads `vendor/main.wasm`. The
module imports a single function — `js.log` for autodoc-internal logging —
satisfied with a no-op (or a debug printer behind `--verbose`).

`src/zigdocs/wasm.py` exposes a typed `WasmStd` class wrapping the WASM
exports the renderer needs:

```
alloc, unpack, find_decl, find_file_root, categorize_decl, get_aliasee,
decl_fqn, decl_name, decl_parent, decl_file_path, decl_docs_html,
decl_fn_proto_html, decl_param_html, decl_doctest_html, decl_source_html,
decl_field_html, decl_type_html, decl_params, decl_fields,
decl_error_set, namespace_members, find_module_root, module_name,
type_fn_members, type_fn_fields, fn_error_set, fn_error_set_decl,
error_set_node_list, error_html, query_begin, query_exec,
set_input_string
```

Two ABI helpers handle the awkward parts:

- `_unwrap_string(packed)`: decodes the JS BigInt packing trick — low 32
  bits = ptr, high 32 = len. In Python: `(packed & 0xFFFFFFFF, packed >> 32)`.
- `_unwrap_slice32(packed)` and `_unwrap_slice64(packed)`: same packing,
  reads N elements from WASM linear memory.

These mirror `unwrapString`/`unwrapSlice32`/`unwrapSlice64` in
`mcp/std.ts` lines 719-781. Direct port.

Constructor signature:

```python
class WasmStd:
    def __init__(self, wasm_bytes: bytes, sources_tar: bytes):
        # 1. Instantiate wasmtime store/module/instance with js.log import.
        # 2. exports.alloc(len) → ptr; copy sources_tar into memory; exports.unpack(ptr, len).
        # State is now loaded; subsequent queries reuse this instance.
```

## Markdown rendering

`src/zigdocs/stdlib.py` ports the renderers in `mcp/std.ts` line-by-line.

| TS function (mcp/std.ts)        | Python equivalent              | Lines (TS) |
| ------------------------------- | ------------------------------ | ---------- |
| `searchStdLib`                  | `render_search`                | ~50        |
| `getStdLibItem`                 | `render_get_item`              | ~70        |
| `renderDecl`                    | `_render_decl` (dispatch)      | ~40        |
| `renderNamespacePage`           | `_render_namespace`            | ~30        |
| `renderFunction`                | `_render_function`             | ~70        |
| `renderGlobal`                  | `_render_global`               | ~25        |
| `renderTypeFunction`            | `_render_type_function`        | ~50        |
| `renderErrorSetPage`            | `_render_error_set`            | ~30        |
| `renderNamespaceMarkdown`       | `_render_namespace_md`         | ~150       |

Total: ~500 lines of mechanical translation. The TS is the port spec; we
follow it line-by-line so output stays byte-equivalent.

## Builtins parsing

`src/zigdocs/builtins.py` ports `parseBuiltinFunctionsHtml` from
`mcp/extract-builtin-functions.ts` (~100 lines) using BeautifulSoup. Same
algorithm:

1. Find `h2#Builtin-Functions`.
2. Walk siblings to next `h2`.
3. For each `h3[id]` collect signature (next `<pre>`) plus following
   paragraphs/lists/figures.
4. Rewrite `<a href>` and `<code>` tags into markdown inline.

The `get_builtin_function` ranking (lines 60-75 of `tools.ts`) ports too:
exact match 1000, prefix 500, contains 300, plus length tiebreaker.

## SKILL.md content

```yaml
---
name: zig-docs-cli
description: Look up Zig 0.16 standard library APIs and builtin functions via a local CLI (replaces the zig-docs MCP server in environments without MCP support, e.g. cloud agents). Use before writing or reviewing Zig code that touches stdlib — critical for std.Io filesystem APIs (std.Io.Dir, std.Io.File), Reader/Writer interfaces, and std.process.Init. Triggers when answering "how do I X in Zig" or writing Zig that touches files, dirs, env, or process state. If the zig-docs MCP server is already connected, prefer it over this CLI.
---
```

Single-line description (not YAML block scalar) — keeps loader behavior
predictable across skill harnesses.

The trailing "prefer the MCP if available" line stops the skill from
overriding the MCP locally.

Body structure:

1. One-paragraph "what this is" — Python+wasmtime port, same data, same
   output.
2. **Setup** (run once per agent session/sandbox):
   ```sh
   cd .claude/skills/zig-docs-cli
   uv sync
   ```
   Note: requires `ziglang.org` outbound network access.
3. **Usage** — one example per command, using
   `uv run --directory .claude/skills/zig-docs-cli zigdocs ...` so the
   agent can call from any cwd.
4. **When to use which command** — short rubric mapping situation to
   subcommand.
5. **Version override** — `--version 0.15.1` or
   `ZIG_DOCS_VERSION=master`.
6. **Troubleshooting** — three common failure modes (no `uv`,
   ziglang.org blocked, FQN typo).
7. Pointer to `README.md` for humans.

Target: under 80 lines.

## Risks & mitigations

1. **WASM ABI drift.** If zig-mcp rebuilds `main.wasm` with a different
   export signature, the driver breaks silently.
   *Mitigation:* a smoke test that calls a known-good query
   (e.g. `search ArrayList` should return non-empty) and fails CI.

2. **Markdown drift.** Byte-equivalence with the MCP is aspirational.
   *Mitigation:* snapshot a handful of MCP outputs in `tests/fixtures/`,
   diff in tests; small whitespace differences are acceptable, structural
   differences are bugs.

3. **wasmtime memory views.** Getting a writable view into linear memory
   in Python differs slightly from JS's `Uint8Array`.
   *Mitigation:* wasmtime-py docs are clear; this is implementation
   detail, not a design risk.

4. **WASM rebuild path.** Bumping Zig versions may require rebuilding the
   WASM from `~/Documents/GitHub/zig-mcp/docs/`.
   *Mitigation:* `vendor/PROVENANCE.md` records the Zig version, zig-mcp
   commit SHA, and `zig build` invocation used.

## Out of scope

- Local mode (using `zig std` from an installed Zig). Cloud agents are
  the audience; remote mode is sufficient.
- An HTTP server. CLI is enough for shell-out usage.
- Auto-update of the vendored WASM. Manual + documented in
  `PROVENANCE.md`.
- A schema layer (FastAPI / Pydantic) on top of the CLI. The MCP itself
  is a CLI-shaped protocol; matching that shape is the point.

## Reference

- zig-mcp repo: `~/Documents/GitHub/zig-mcp`
- `mcp/std.ts` — markdown renderer to port
- `mcp/extract-builtin-functions.ts` — HTML parser to port
- `mcp/tools.ts` — MCP tool definitions, ranking logic
- `mcp/docs.ts` — sources.tar download URL pattern
- `vendor source for main.wasm`: `~/Documents/GitHub/zig-mcp/mcp/main.wasm`
  (built from `~/Documents/GitHub/zig-mcp/docs/` via `zig build`)
