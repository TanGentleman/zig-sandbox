# Next steps

## Open / deferred

- **`looptap run` always re-ingests.** A `--no-run` flag would let you iterate
  on queries without re-parsing. Skipped — re-ingest is fast enough at current
  corpus size.
- **Flagged path list defaults to top 5.** Most-recent first, with `... and N
  more` trailing. Add `--limit N` / `--all` if 5 turns out to be too short.

## 3. Ship the bundle

Tar up the flagged transcripts. Two paths:

- **A. Shell out (default).** Iterate `digest.flagged` in Zig, build argv `tar
  czf bundle.tgz path1 path2 ...`, spawn directly.
- **B. Native pipe.** Spawn `looptap query --format paths` and `tar czf - -T -`
  as two `std.process.Child`s, wire stdout→stdin. Good `std.Io` exercise — save
  for when you want the practice.

## 4. (Optional) HTTP UI

Only if shell-out becomes friction. `std.http.Server` direct:

- `GET /` → static HTML listing flagged sessions, rendered server-side from
  `[]FlaggedSession`.
- `GET /bundle?signal=failure&signal=loop` → run step 3 on the fly, stream the
  tarball back.
