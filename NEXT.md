# Next steps

Steps 1 + 2 from the previous draft are **done**:

- `runLooptapQuery` calls `looptap query --format jsonl --signal failure`
  and parses each line into `FlaggedSession` (with `ignore_unknown_fields`
  + `alloc_always` so slices don't alias freed stdout).
- `LooptapDigest.flagged` exists; `printDigest` shows count, by-type
  breakdown, and `path  (signal, signal)` lines.
- `runLooptap` now does `run` → `info` → `query` in sequence. Tests cover
  the parser (happy path, empty stdout, malformed json) and the renderer.

## Open / deferred

- **Signal set is hardcoded to `failure`.** Promote to a CLI arg when a
  second signal type earns its keep. `looptap query` accepts repeatable
  `--signal` flags so the flip is mechanical.
- **`looptap run` always re-ingests.** A `--no-run` flag would let you
  iterate on queries without re-parsing every transcript. Skipped for now
  — re-ingest is fast enough at current corpus size.

## 3. Ship the bundle

Two paths, same goal: tar up the flagged transcripts.

**A. Shell out (small, ships fast).** New tracers subcommand or flag.
Either:
- Spawn `sh -c "looptap query --format paths --signal failure | xargs tar
  czf bundle.tgz"` and print the output path, or
- Iterate `digest.flagged` in Zig, build an argv `tar czf bundle.tgz
  path1 path2 ...`, spawn it directly. Avoids the shell, still trivial.

**B. Native pipe (more learning).** Spawn `looptap query --format paths`
and `tar czf - -T -` as two `std.process.Child`s; connect the first's
stdout to the second's stdin. Good `std.Io` / `std.process.Child`
exercise.

Default to A. Save B for when you want the practice.

## 4. (Optional) HTTP UI

Only if shell-out isn't enough day-to-day. `std.http.Server` direct, no
fetched library:
- `GET /` → static HTML listing flagged sessions (rendered server-side
  from `[]FlaggedSession`).
- `GET /bundle?signal=failure&signal=loop` → run step 3 on the fly,
  stream the tarball back.

Skip until the CLI version starts feeling like friction.
