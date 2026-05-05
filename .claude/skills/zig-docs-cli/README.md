# zig-docs-cli

A Claude skill that gives cloud-hosted agents Zig 0.16 stdlib + builtin
docs lookups, replacing the local `zig-docs` MCP server in environments
without MCP support.

For agent-facing usage instructions, see `SKILL.md`. This README covers
maintenance: how the skill is built, how to update it, and what each
piece does.

## Architecture

| File                              | Role                                                |
| --------------------------------- | --------------------------------------------------- |
| `src/zigdocs/cli.py`              | argparse entrypoint, exit-code contract             |
| `src/zigdocs/stdlib.py`           | markdown rendering (port of `zig-mcp/mcp/std.ts`)   |
| `src/zigdocs/wasm.py`             | wasmtime driver + typed wrapper around WASM exports |
| `src/zigdocs/builtins.py`         | langref HTML parser + ranking                       |
| `src/zigdocs/fetch.py`            | sources.tar / langref download + `/tmp` cache       |
| `src/zigdocs/version.py`          | default Zig version + override resolution           |
| `vendor/main.wasm`                | autodoc WASM, vendored from zig-mcp                 |
| `vendor/PROVENANCE.md`            | build instructions + SHA256 + upstream commit       |

## Updating the vendored WASM

Bumping the Zig version may need a fresh `main.wasm`. The build steps live
in `vendor/PROVENANCE.md`. Summary:

```sh
cd ~/Documents/GitHub/zig-mcp
git pull
zig build
cp zig-out/main.wasm <repo>/.claude/skills/zig-docs-cli/vendor/main.wasm
shasum -a 256 <repo>/.claude/skills/zig-docs-cli/vendor/main.wasm
# update SHA256 + commit + date in vendor/PROVENANCE.md
```

Run smoke tests after updating:

```sh
cd .claude/skills/zig-docs-cli
ZIGDOCS_SMOKE=1 uv run pytest -v
```

## Testing

- Pure unit tests run with `uv run pytest`.
- Smoke tests (requires network + vendored WASM) run with
  `ZIGDOCS_SMOKE=1 uv run pytest`.

## Why a port and not a wrapper?

The autodoc renderer lives inside the WASM as HTML-emitting exports.
Wrapping the MCP would mean shipping Node.js to every cloud agent.
Porting the ~700 lines of TS that drive the WASM gets us the same output
with only Python + a vendored binary.

## Reference

- Upstream: <https://github.com/loonghao/zig-mcp>
- Spec: `docs/superpowers/specs/2026-05-02-cloud-zig-docs-skill-design.md`
- Plan: `docs/superpowers/plans/2026-05-02-cloud-zig-docs-skill.md`
