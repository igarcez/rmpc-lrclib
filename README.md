# rmpc-lrclib

Auto-fetch synced song lyrics from [LRCLIB](https://lrclib.net) into [rmpc](https://github.com/mierak/rmpc)'s
Lyrics pane. Drop in one POSIX `sh` script, wire it to rmpc's `on_song_change`, and every track you
play that lacks lyrics gets a timestamped `.lrc` written beside it — live, for the song currently playing.

## What it does

On each song change rmpc runs `scripts/lyrics-fetch.sh`, which:

- Queries LRCLIB `/search` for the current `ARTIST` + `TITLE`, falling back to `/get` (with `ALBUM` + `DURATION`).
- **Prefers a `syncedLyrics` record** (closest `duration` to the playing track) — rmpc's Lyrics pane renders
  only `[mm:ss]`-timestamped lines, so plain lyrics are a last resort.
- Writes the best match to rmpc's `$LRC_FILE` with `[ar:]`, `[al:]`, `[ti:]` headers.
- Calls `rmpc remote indexlrc --path "$LRC_FILE"` so the running rmpc re-reads the file and the Lyrics pane
  populates for the **current** song (not just the next one).
- Never overwrites an existing **synced** `.lrc`; an existing **plain** `.lrc` is re-fetched and upgraded.
- Skips HTTP/radio streams.
- Keeps a 30-day **miss cache** so tracks with no (synced) lyrics aren't re-queried on every play.

## Requirements

- [`rmpc`](https://github.com/mierak/rmpc) **0.11.0+** (uses the `on_song_change` child env: `ARTIST`, `TITLE`,
  `ALBUM`, `DURATION`, `FILE`, `LRC_FILE`, `HAS_LRC`; and the `rmpc remote indexlrc` subcommand).
- [`curl`](https://curl.se/)
- [`jq`](https://jqlang.github.io/jq/)

## Install

1. Copy the script into your rmpc config dir and make it executable:

   ```sh
   mkdir -p ~/.config/rmpc/scripts
   cp scripts/lyrics-fetch.sh ~/.config/rmpc/scripts/lyrics-fetch.sh
   chmod +x ~/.config/rmpc/scripts/lyrics-fetch.sh
   ```

2. Merge the keys from [`examples/config.ron`](examples/config.ron) into your `~/.config/rmpc/config.ron`:

   - **`lyrics_dir`** — set to your MPD `music_directory` so `.lrc` files sit beside the audio.
   - **`on_song_change`** — point at the script; keep the trailing `&` so a slow fetch never blocks rmpc:

     ```ron
     on_song_change: Some(["sh", "-c", "sh \"$HOME/.config/rmpc/scripts/lyrics-fetch.sh\" &"]),
     ```

     > `$HOME` is required here — `~` does not expand inside an `on_song_change` argv.

   - **`exec_on_song_change_at_start: true`** — **required** so the track already playing when rmpc starts
     also gets fetched (rmpc's default is `false`).
   - **`Pane(Lyrics)`** — add a Lyrics pane to a tab layout so synced lyrics actually render.

3. Restart rmpc (or save the config if `enable_config_hot_reload` is on). Play a track and the `.lrc` appears
   within a few seconds.

## Running multiple hooks (optional dispatcher)

Want lyrics fetching *and* other `on_song_change` behavior (e.g. desktop notifications)? `on_song_change`
takes a single command, so use a small dispatcher that backgrounds every script in a directory. Each script
inherits rmpc's env.

Create `~/.config/rmpc/scripts/hooks/on-song-change`:

```sh
#!/bin/sh
# Runs every *.sh in on-song-change.d/ in the background so a slow hook never blocks rmpc.
set -u
DIR="$(dirname "$0")/on-song-change.d"
[ -d "$DIR" ] || exit 0
for h in "$DIR"/*.sh; do
    [ -f "$h" ] || continue
    sh "$h" &
done
exit 0
```

Then `chmod +x` it, move the lyrics script into the dispatcher dir, and point rmpc at the dispatcher:

```sh
chmod +x ~/.config/rmpc/scripts/hooks/on-song-change
mkdir -p ~/.config/rmpc/scripts/hooks/on-song-change.d
mv ~/.config/rmpc/scripts/lyrics-fetch.sh ~/.config/rmpc/scripts/hooks/on-song-change.d/
```

```ron
on_song_change: Some(["sh", "-c", "sh \"$HOME/.config/rmpc/scripts/hooks/on-song-change\" &"]),
```

Add behavior later by dropping another `*.sh` into `on-song-change.d/`.

## Troubleshooting

- **Log:** every run appends to `~/.cache/rmpc/lyrics-fetch.log` (`wrote synced:`, `no match:`,
  `lookup failed (net):`, `indexed:`).
- **Testing a fetch:** the LRCLIB round-trip takes ~5-10s. Poll for the file instead of a fixed sleep:
  `T="$LRC_FILE"; while [ ! -f "$T" ]; do sleep 1; done`. A too-short sleep reports a false negative.
- **Force a retry:** the miss cache lives in `~/.cache/rmpc/lyrics-misses/`. Delete the dir (or a single
  marker) to re-query LRCLIB immediately instead of waiting out the 30-day window.
- **Pane stays empty:** confirm `Pane(Lyrics)` is in a tab layout and the `.lrc` contains `[mm:ss]` lines —
  plain (untimestamped) lyrics render nothing in rmpc's pane.

## License

[MIT](LICENSE)
