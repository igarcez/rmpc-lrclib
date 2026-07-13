# Shell style

Conventions every `*.sh` in this repo follows. The hook runs under whatever `sh` rmpc's `on_song_change`
spawns (dash, busybox, bash-as-sh), so scripts must be **POSIX `sh`** — no bashisms.

## Commands

| Command | Purpose |
|---------|---------|
| `sh -n scripts/hooks/on-song-change.d/lyrics-fetch.sh` | Syntax-check a script without running it. Run before considering an edit done (swap the path for the dispatcher `scripts/hooks/on-song-change` or any other hook). |
| `shellcheck scripts/hooks/on-song-change.d/lyrics-fetch.sh` | Lint for portability/quoting bugs. Optional — not installed by default; run if available. |

## Rules

- **Shebang `#!/bin/sh`**, POSIX only. No `[[ ]]` (use `[ ]`), no arrays, no `local`, no `declare`,
  no `echo -e`, no `$'...'`, no `$(( ))`-only-in-bash features. Verify clean with
  `grep -nE '\[\[|local |declare |echo -e' <script>` returning nothing.
- **`set -u`** at the top (nounset). Because of it, every env var that may be unset is read with a
  default: `${ARTIST:-}`, `${FILE:-}`, `${DURATION:-}`. Never reference a maybe-unset var bare.
- **Quote every expansion**: `"$LRC_FILE"`, `"$ARTIST"`, `"$(dirname "$LOG")"`. Paths from rmpc can
  contain spaces.
- **`printf`, not `echo`, for data** — `echo` mangles backslashes/leading-`-` across shells.
  Data piped to other tools uses `printf '%s'`.
- **Pattern-match with `case`** (e.g. the `http://*|https://*` stream skip), not regex in `[ ]`.
- **Capture exit codes immediately**: `cmd ...; rc=$?` on its own, then branch on `$rc`
  (the `curl ...; rc=$?` / `reached` logic depends on this — see [lyrics-hook.md](lyrics-hook.md)).
- **Non-critical failures swallowed**: housekeeping like `mkdir -p ... 2>/dev/null || true` must never
  abort the script; only the lyric write itself matters.
- Keep scripts **executable** (`chmod +x`) — the dispatcher and rmpc invoke them as `sh "$path"`, but
  the bit should be set regardless.

## Reference

- The hook this style governs: [lyrics-hook.md](lyrics-hook.md)
