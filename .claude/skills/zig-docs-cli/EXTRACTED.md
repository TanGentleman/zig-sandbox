# Extracted

The canonical home of this skill is now a standalone repo:
**`zig-docs-cli`** (currently at `/home/user/zig-docs-cli`, to be pushed
to `https://github.com/<owner>/zig-docs-cli`).

Releases:

- `v0.1.0` — initial extraction of this directory.
- `v0.1.1` — packaging fix: `main.wasm` now ships inside the wheel at
  `zigdocs/_vendor/main.wasm` and is resolved via `importlib.resources`
  (so `uv tool install` works).

The copy in this repo is kept for now to avoid breaking
`uv run --directory .claude/skills/zig-docs-cli zigdocs ...`. Migration
options for this repo (pick later):

1. Replace this directory with a git submodule pointing at the new repo.
2. Drop this directory and rely on `uv tool install
   git+https://github.com/<owner>/zig-docs-cli` instead, then update
   `SKILL.md` invocations to bare `zigdocs ...`.
3. Pin a release tarball into `.claude/skills/` via a setup script.

The standalone repo's `vendor/main.wasm` was relocated to
`src/zigdocs/_vendor/main.wasm`. If syncing this in-tree copy with the
extracted one, mirror that layout and update `cli.py`'s path resolution.
