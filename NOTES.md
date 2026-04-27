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

Ways we can speedrun it:
1. walk ~/.claude/projects
2. return the bytes found in each .jsonl file
3. use subprocess with looptap and parse the output

Future work:
1. Query sqlite table that contains all transcript data + signals
2. Wire to subcommand to use Datasette when UI is needed.