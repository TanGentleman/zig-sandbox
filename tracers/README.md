# tracers

Drive [looptap](https://github.com/TanGentleman/looptap) over `~/.claude/projects` and surface the rough sessions. Zig 0.16; single static binary.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/TanGentleman/tracers/main/tracers/scripts/install.sh | bash
```

To remove it later:

```bash
curl -fsSL https://raw.githubusercontent.com/TanGentleman/tracers/main/tracers/scripts/uninstall.sh | bash
```

You also need `looptap` on PATH:

```bash
curl -fsSL https://raw.githubusercontent.com/TanGentleman/looptap/main/scripts/install.sh | bash
```

## Try it

```bash
looptap run && tracers
```

That walks `~/.claude/projects`, runs `looptap` (run → info → query), and prints a digest: file counts, signal-type breakdown, and the paths of flagged sessions (most recent first, top 5).

```text
=== looptap digest ===
db: ~/.looptap/looptap.db

summary
  found               53
  parsed               1
  skipped             52
  errors               0
  generated signals   10
  sessions           102
  turns             7772
  signals            404

sessions by source
  claude-code  102

signals by type
  failure        229
  exhaustion      80
  loop            34
  disengagement   32
  misalignment    25
  satisfaction     3
  stagnation       1

flagged sessions: 59
  by type
    failure  59
  paths (showing 5 of 59, most recent first)
    ~/.claude/projects/-Users-tan-Documents-GitHub-for-nelson/9ffb...jsonl  (failure)
    ~/.claude/projects/-Users-tan-Documents-GitHub-zigpeek/c8e2...jsonl    (failure)
    ...
    ... and 54 more
```

`tracers --help` shows the full flag list. Surface other signal types with `--signal <type>` (repeatable). See [../NEXT.md](../NEXT.md) for what's coming.

## Build from source

```bash
cd tracers
zig build           # produces ./zig-out/bin/tracers
zig build run -- --version
```

Zig 0.16.0 is required (`zig version`).

## Release

Cut a tag and push — GitHub Actions builds the matrix and publishes the release:

```bash
./scripts/cut-release.sh 0.1.0
```

See [../NOTES.md](../NOTES.md) for the project context and [../NEXT.md](../NEXT.md) for the open work.
