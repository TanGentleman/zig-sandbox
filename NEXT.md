# Next steps

Assumes `looptap query` (PR #22) is merged + the local binary supports it.
Verify with `looptap query --help`.

## 1. Wire `looptap query` into tracers

Add `runLooptapQuery(init, w) ![]FlaggedSession` to `tracers/src/root.zig`,
sibling to `runLooptap`.

- Argv: `looptap query --format jsonl --signal failure --signal loop --signal misalignment`
  (start with hardcoded signals; promote to CLI args later).
- Capture stdout via `std.process.run`.
- Parse with `std.json.parseFromSlice` into a typed struct:
  ```zig
  pub const FlaggedSession = struct {
      session_id: []const u8,
      raw_path: []const u8,
      started_at: []const u8,
      signals: []const FlaggedSignal,
  };
  pub const FlaggedSignal = struct {
      type: []const u8,
      confidence: f32,
      // turn_idx, evidence — add when needed
  };
  ```
- Each line of stdout is one JSON object (`jsonl`), so split on `\n` and
  parse each line.

Schema-enforce just like the existing parsers — empty stdout is fine,
malformed lines should error.

## 2. Add a "flagged" section to the digest

`LooptapDigest` gets a `flagged: []FlaggedSession` field. `printDigest`
shows:

```
flagged sessions: N
  by type:
    failure       3
    loop          2
  paths:
    /path/to/a.jsonl  (failure, loop)
    /path/to/b.jsonl  (failure)
```

`main.zig` flow becomes: `mapClaudeTranscripts` → `runLooptap` →
`runLooptapQuery` → `printDigest`.

Tests: feed canned `jsonl` stdout into the parser, check counts + paths.

## 3. Ship the bundle

Pick one:

**A. Shell out (small, ships fast).** New tracers subcommand or flag:
spawn `sh -c "looptap query --format paths --signal ... | xargs tar czf
bundle.tgz"`. Print the output path. Done.

**B. Native pipe (more learning).** Spawn `looptap query` and `tar czf -
-T -` as two `std.process.Child`s; connect the first's stdout to the
second's stdin. Good `std.Io` / `std.process.Child` exercise.

Default to A. Save B for when you want the practice.

## 4. (Optional) HTTP UI

Only if shell-out isn't enough day-to-day. `std.http.Server` direct, no
fetched library:
- `GET /` → static HTML listing flagged sessions (rendered server-side
  from `[]FlaggedSession`).
- `GET /bundle?signal=failure&signal=loop` → run step 3 on the fly,
  stream the tarball back.

Skip this until you've used the CLI version a few times and feel friction.

## Open

- Which signal set is the default? (`failure`, `loop`, `misalignment`?
  Pick from real usage, not a priori.)
- Should tracers re-run `looptap run` every time, or only on demand?
  Right now it always does. A `--no-run` flag would let you iterate on
  queries without re-ingesting.
