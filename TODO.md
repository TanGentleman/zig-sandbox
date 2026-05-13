# TODO

Open work, roughly ordered by tie-together value.

## CLI ergonomics

- `--no-run` to skip the `looptap run` step and iterate on queries against the
  existing DB. Re-ingest is fast at current corpus size, so deferred.
- `--limit N` / `--all` for the flagged-paths section (currently hardcoded to 5).

## `tracers serve` next steps

The current server is a read-only snapshot built at startup. To make it
actually useful:

- **On-demand refresh.** `POST /refresh` (or a `GET /refresh` for now) reruns
  looptap and replaces the cached digest. Cheaper than restarting the process.
- **Per-request signals.** Honor `?signal=failure&signal=loop` on `/digest` and
  `/flagged` instead of locking the signal set at process start.
- **`GET /bundle`.** Stream a tarball of the flagged transcripts on the fly.
  Internally this is the "ship the bundle" workflow below.
- **HTML rendering.** Once the text endpoints settle, add a `text/html` view of
  `/` listing flagged sessions with links to `/bundle?...` and the raw paths.

## Ship the bundle

Tar up the flagged transcripts. Two paths, either works:

- **A. Shell out (default).** Iterate `digest.flagged` in Zig, build argv
  `tar czf bundle.tgz path1 path2 ...`, spawn directly.
- **B. Native pipe.** Spawn `looptap query --format paths` and `tar czf - -T -`
  as two `std.process.Child`s, wire stdout→stdin. Good `std.Io` exercise — save
  for when you want the practice.

Once `tracers --bundle FILE.tgz` exists, `GET /bundle` becomes a thin wrapper
that streams the same tarball.
