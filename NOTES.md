# Notes

Tracers orchestrates [looptap](https://github.com/TanGentleman/looptap) over
`~/.claude/projects` and surfaces flagged transcripts.

Layout:

```
sandbox/   # zig idioms practice (root) + b64-playground/
tracers/   # the real tool
```

Looptap owns the SQLite schema. Tracers is a process orchestrator — no SQLite
Zig dep.

Done in tracers (see `tracers/src/root.zig`):

- `mapClaudeTranscripts` — walks `~/.claude/projects`, returns
  `[]MapResult{filepath, size_in_bytes}`, logs files >1MB.
- `runLooptap` — `looptap run` → `info` → `query --format jsonl --signal
  failure`, parses each line into `FlaggedSession`, returns a `LooptapDigest`
  that includes `flagged`.
- `printDigest` — renders the merged digest (counts, by-type breakdown,
  `path  (signal, signal)` lines).
