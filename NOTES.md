Looptap functionality:
- https://github.com/TanGentleman/looptap
- Walk filetree for ~/.claude/projects
- Parse transcript contents (efficiently)
- Generate signals to flag transcripts to analyze [see this paper](https://arxiv.org/abs/2604.00356)
```
((.venv) ) tanujvasudeva@Tan looptap % ./looptap run
Found 49 transcript files
Parsed: 17  Skipped: 32  Errors: 0
Processing 17 sessions
Generated 29 signals
((.venv) ) tanujvasudeva@Tan looptap % ./looptap info
Database: /Users/tanujvasudeva/.looptap/looptap.db

Sessions: 75
Turns:    4558
Signals:  255

Sessions by source:
  claude-code     75

Signals by type:
  disengagement   22
  exhaustion      61
  failure         127
  loop            28
  misalignment    15
  satisfaction    1
  stagnation      1
```

Before we overlap in Zig:
- We need a RWT w/ latency >5 seconds
- We want a strongly typed interface for transcripts. Surely an OS implementation out there makes it easy?

Done:
1. `mapClaudeTranscripts` walks `~/.claude/projects` once, returns `[]MapResult{filepath, size_in_bytes}`, and `std.log.debug`s any file >1MB.
2. `runLooptap` spawns `looptap run` then `looptap info` via `std.process.run` (PATH lookup), captures stdout, parses both into a `LooptapDigest`.
3. `printDigest` prints the merged digest from `tracers`' writer.

Future work:
1. Do something with `[]MapResult` beyond the >1MB log — feed into our own analyses or pass to looptap.
2. Query the sqlite table that contains all transcript data + signals.
3. Wire to subcommand to use Datasette when UI is needed.
4. Wire `tracers/` into the root `build.zig` so a single `zig build` builds everything.