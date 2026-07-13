# Lyrics hook

`scripts/lyrics-fetch.sh` is an rmpc `on_song_change` hook: on each song change it fetches synced
lyrics from LRCLIB and writes a `.lrc` beside the audio. The whole repo exists to ship this one
script plus its rmpc wiring (`examples/config.ron`) and docs (`README.md`).

## rmpc contract

- rmpc 0.11.0+ runs the hook with no CLI args — everything comes from the **child env**:
  `ARTIST`, `TITLE`, `ALBUM`, `DURATION`, `FILE` (uri), `LRC_FILE` (absolute target path,
  tilde-expanded by rmpc), `HAS_LRC`. The script reads these via `${VAR:-}` (see [shell-style.md](shell-style.md)).
- The hook is wired by three config keys (documented in `examples/config.ron` + README "Install"):
  `lyrics_dir` (= the MPD `music_directory` so `.lrc` lands beside audio), `on_song_change`
  (`Some(["sh","-c","sh \"$HOME/.config/rmpc/scripts/lyrics-fetch.sh\" &"])` — `$HOME` not `~`,
  trailing `&` so a slow fetch never blocks rmpc), and `exec_on_song_change_at_start: true`
  (**required** — without it the track playing at launch is never fetched).
- After writing the file the script **must** call `rmpc remote indexlrc --path "$LRC_FILE"` so the
  running rmpc re-reads it and the Lyrics pane populates for the *current* song (rmpc read
  `HAS_LRC=false` before the async fetch finished).

## How the fetch works

- Queries `$API/search` (`API='https://lrclib.net/api'`) first — it returns every variant; falls
  back to `$API/get` (adds `album_name` + `duration`). `/get` can return a plain record even when a
  synced one exists, so search is primary.
- Selection (`resp=` jq pipeline): drop `instrumental`, take the best match (first result after
  sorting by duration), and **only accept it if it has `syncedLyrics`**. rmpc's Lyrics pane renders
  **only** `[mm:ss]`-timestamped lines; plain-only tracks are skipped (no lyrics written, miss marker
  set for 30-day skip).
- Writes `[ar:]`, `[al:]` (only if `ALBUM` set), `[ti:]` headers then the lyric body to `$LRC_FILE`.
- Never overwrites an existing **synced** `.lrc` (the early `grep -qE '^\[[0-9]{2}:[0-9]{2}'` guard).
  Skips `http://`/`https://` streams.

## Miss cache

- `MISS_DIR="$HOME/.cache/rmpc/lyrics-misses"`; marker file keyed by `cksum` of `$LRC_FILE`.
- `miss_set` on a definitive negative (server answered but no match, only-plain available,
  empty/instrumental) → skip refetch for **30 days** (`find -mtime +30` gates the retry). `miss_clear`
  on any synced write (all writes are synced after this change).
- A **transport failure** (server unreachable) writes **no** marker (`reached` stays 0) so the next
  play retries immediately. `reached` is set when `curl` exits 0 (200) or 22 (HTTP ≥400).
- Force a full retry: delete `~/.cache/rmpc/lyrics-misses/`.

## Rules

- **Lockstep:** the install path, env-var names, and the three config keys appear in three places —
  `scripts/lyrics-fetch.sh`, `examples/config.ron`, and `README.md`. Change one, update all three.
- `lyrics-fetch.sh` must stay executable (`chmod +x`) and POSIX `sh` — see [shell-style.md](shell-style.md).
- Test a fetch by **polling** for `$LRC_FILE` (`while [ ! -f "$T" ]; do sleep 1; done`), not a fixed
  `sleep N` — the LRCLIB round-trip takes ~5-10s and a short sleep gives a false negative.
- Log lines append to `~/.cache/rmpc/lyrics-fetch.log` (`wrote synced:`, `no match:`,
  `lookup failed (net):`, `indexed:`).

## Reference

- LRCLIB API contract (endpoints, params, fields): [lrclib-api.md](lrclib-api.md)
- rmpc config docs: `https://mierak.github.io/rmpc/`
