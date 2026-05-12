# tracers

Drive [looptap](https://github.com/TanGentleman/looptap) over `~/.claude/projects` and surface the rough sessions. Zig 0.16; single static binary.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/TanGentleman/zig-sandbox/main/tracers/scripts/install.sh | bash
```

You also need `looptap` on PATH:

```bash
curl -fsSL https://raw.githubusercontent.com/TanGentleman/looptap/main/scripts/install.sh | bash
```

## Try it

```bash
looptap run && tracers
```

That walks `~/.claude/projects`, runs `looptap` (run → info → query --signal failure), and prints a digest: file counts, signal-type breakdown, and the paths of flagged sessions.

```text
Sessions: 75
Turns:    4558
Signals:  255

Signals by type:
  failure         127
  exhaustion      61
  loop            28
  disengagement   22
  misalignment    15

Flagged (12):
  /Users/.../-some-project-/abc.jsonl   (failure)
  ...
```

`tracers --help` shows the full flag list. The signal set is currently hardcoded to `failure` — see [../NEXT.md](../NEXT.md) for what's coming.

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
