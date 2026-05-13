# tracers

Drive [looptap](https://github.com/TanGentleman/looptap) over `~/.claude/projects` and surface the rough sessions. Zig 0.16; single static binary.

```
tracers/   # the shipping CLI — see tracers/README.md
sandbox/   # throwaway Zig 0.16 experiments
```

Looptap owns the SQLite schema; tracers is a process orchestrator and has no SQLite dependency of its own.

See [tracers/README.md](tracers/README.md) for install + usage and [TODO.md](TODO.md) for the open work.
