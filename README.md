# rmpc-lrclib

Auto-fetch synced song lyrics from [LRCLIB](https://lrclib.net) into [rmpc](https://github.com/mierak/rmpc)'s
Lyrics pane. Drop in one POSIX `sh` script, wire it to rmpc's `on_song_change`, and every track you
play that lacks lyrics gets a timestamped `.lrc` written beside it — live, for the song currently playing.

## What it does

On each song change rmpc runs the `on-song-change` dispatcher, which backgrounds every hook in
`scripts/hooks/on-song-change.d/`. The core hook, `lyrics-fetch.sh`:

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

The hooks run under a small dispatcher: rmpc calls `scripts/hooks/on-song-change`, which backgrounds
every `*.sh` in `scripts/hooks/on-song-change.d/`. This lets lyrics fetching and notifications (and any
hook you add later) share the single `on_song_change` slot without blocking each other.

1. Copy the dispatcher and its hooks into your rmpc config dir and make them executable:

   ```sh
   mkdir -p ~/.config/rmpc/scripts/hooks/on-song-change.d
   cp scripts/hooks/on-song-change ~/.config/rmpc/scripts/hooks/on-song-change
   cp scripts/hooks/on-song-change.d/*.sh ~/.config/rmpc/scripts/hooks/on-song-change.d/
   chmod +x ~/.config/rmpc/scripts/hooks/on-song-change ~/.config/rmpc/scripts/hooks/on-song-change.d/*.sh
   ```

2. Merge the keys from [`examples/config.ron`](examples/config.ron) into your `~/.config/rmpc/config.ron`:
   - **`lyrics_dir`** — set to your MPD `music_directory` so `.lrc` files sit beside the audio.
   - **`on_song_change`** — point at the dispatcher; keep the trailing `&` so a slow fetch never blocks rmpc:

     ```ron
     on_song_change: Some(["sh", "-c", "sh \"$HOME/.config/rmpc/scripts/hooks/on-song-change\" &"]),
     ```

     > `$HOME` is required here — `~` does not expand inside an `on_song_change` argv.

   - **`exec_on_song_change_at_start: true`** — **required** so the track already playing when rmpc starts
     also gets fetched (rmpc's default is `false`).
   - **`Pane(Lyrics)`** — add a Lyrics pane to a tab layout so synced lyrics actually render.

3. Restart rmpc (or save the config if `enable_config_hot_reload` is on). Play a track and the `.lrc` appears
   within a few seconds.

Add more `on_song_change` behavior later by dropping another executable `*.sh` into
`~/.config/rmpc/scripts/hooks/on-song-change.d/` — each hook inherits rmpc's env.

## Troubleshooting

- **Log:** every run appends to `~/.cache/rmpc/lyrics-fetch.log` (`wrote synced:`, `no match:`,
  `lookup failed (net):`, `indexed:`).
- **Testing a fetch:** the LRCLIB round-trip takes ~5-10s. Poll for the file instead of a fixed sleep:
  `T="$LRC_FILE"; while [ ! -f "$T" ]; do sleep 1; done`. A too-short sleep reports a false negative.
- **Force a retry:** the miss cache lives in `~/.cache/rmpc/lyrics-misses/`. Delete the dir (or a single
  marker) to re-query LRCLIB immediately instead of waiting out the 30-day window.
- **Pane stays empty:** confirm `Pane(Lyrics)` is in a tab layout and the `.lrc` contains `[mm:ss]` lines —
  plain (untimestamped) lyrics render nothing in rmpc's pane.

## Notifications

Lyrics fetch events trigger desktop notifications via `notify-send`:

- **Fetching:** appears when a lookup starts.
- **Fetched:** appears when lyrics are saved successfully.
- **No lyrics found:** appears when the track has no synced lyrics; will not retry for 30 days.
- **Connection failed:** appears if LRCLIB is unreachable.

Notifications require `notify-send` (freedesktop.org standard). If you use a non-standard notification daemon (e.g. dunst), update `notify-send` in `scripts/hooks/on-song-change.d/notify-lyrics-status.sh` to your notification command.

Disable notifications by removing `scripts/hooks/on-song-change.d/notify-lyrics-status.sh` from `~/.config/rmpc/scripts/hooks/on-song-change.d/`.

## TODO

- add permanent failure for instrumental musics

## License

[MIT](LICENSE)
