#!/bin/sh
# rmpc on_song_change hook: fetch synced lyrics from LRCLIB into $LRC_FILE.
# Behavior, env contract and miss-cache rules: README.md / intelligence/lyrics-hook.md.
set -u

LOG="$HOME/.cache/rmpc/lyrics-fetch.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null; }

# Skip HTTP/radio streams.
case "${FILE:-}" in
    http://*|https://*) exit 0 ;;
esac

# Need artist + title + target path.
[ -n "${ARTIST:-}" ] && [ -n "${TITLE:-}" ] && [ -n "${LRC_FILE:-}" ] || exit 0

# Keep an existing *synced* .lrc; a plain one is re-fetched for upgrade.
if [ -f "$LRC_FILE" ] && grep -qE '^\[[0-9]{2}:[0-9]{2}' "$LRC_FILE" 2>/dev/null; then
    exit 0
fi

# Miss marker keyed by target path.
MISS_DIR="$HOME/.cache/rmpc/lyrics-misses"
MARKER="$MISS_DIR/$(printf '%s' "$LRC_FILE" | cksum | cut -d' ' -f1)"
miss_set() { mkdir -p "$MISS_DIR" 2>/dev/null || true; touch "$MARKER" 2>/dev/null || true; }
miss_clear() { rm -f "$MARKER" 2>/dev/null || true; }

# Within the 30-day miss window? skip.
if [ -f "$MARKER" ] && [ -z "$(find "$MARKER" -mtime +30 2>/dev/null)" ]; then
    exit 0
fi

enc() { printf '%s' "$1" | jq -sRr @uri; }
DUR=$(printf '%s' "${DURATION:-}" | grep -oE '[0-9]+' | head -n1)
API='https://lrclib.net/api'

# Search (all variants) then /get fallback. reached=1 when the server answered
# (curl exit 0/22) -> distinguishes "no lyrics" from "unreachable".
reached=0
arr=$(curl -fsS "$API/search?artist_name=$(enc "$ARTIST")&track_name=$(enc "$TITLE")" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] || arr=""
{ [ "$rc" -eq 0 ] || [ "$rc" -eq 22 ]; } && reached=1
if [ -z "$arr" ] || [ "$arr" = "[]" ]; then
    url="$API/get?artist_name=$(enc "$ARTIST")&track_name=$(enc "$TITLE")"
    [ -n "${ALBUM:-}" ] && url="$url&album_name=$(enc "$ALBUM")"
    [ -n "$DUR" ] && url="$url&duration=$DUR"
    one=$(curl -fsS "$url" 2>/dev/null); grc=$?
    { [ "$grc" -eq 0 ] || [ "$grc" -eq 22 ]; } && reached=1
    [ "$grc" -eq 0 ] && [ -n "$one" ] && arr="[$one]"
fi
# Definitive miss only if the server answered; transport failure leaves no marker.
if [ -z "$arr" ] || [ "$arr" = "[]" ]; then
    if [ "$reached" -eq 1 ]; then log "no match: $ARTIST - $TITLE"; miss_set
    else log "lookup failed (net): $ARTIST - $TITLE"; fi
    exit 0
fi

# Drop instrumentals; prefer synced records; nearest duration. Pane renders only synced.
resp=$(printf '%s' "$arr" | jq -c --argjson d "${DUR:-0}" '
    map(select(.instrumental != true))
    | ([ .[] | select((.syncedLyrics // "") != "") ]) as $s
    | (if ($s | length) > 0 then $s else . end)
    | (if $d > 0 then sort_by(((.duration // 0) - $d) | if . < 0 then -. else . end) else . end)
    | .[0] // empty' 2>/dev/null)
[ -n "$resp" ] || { log "no usable match: $ARTIST - $TITLE"; miss_set; exit 0; }

synced=$(printf '%s' "$resp" | jq -r '.syncedLyrics // empty')
plain=$(printf '%s' "$resp" | jq -r '.plainLyrics // empty')
if [ -n "$synced" ]; then body="$synced"; kind=synced
else body="$plain"; kind=plain; fi
[ -n "$body" ] || { log "empty lyrics: $ARTIST - $TITLE"; miss_set; exit 0; }

mkdir -p "$(dirname "$LRC_FILE")" 2>/dev/null || true
{
    printf '[ar:%s]\n' "$ARTIST"
    [ -n "${ALBUM:-}" ] && printf '[al:%s]\n' "$ALBUM"
    printf '[ti:%s]\n' "$TITLE"
    printf '%s\n' "$body"
} >"$LRC_FILE"
log "wrote $kind: $LRC_FILE"

# Synced -> clear miss. Plain-only -> keep the file but mark a miss.
if [ "$kind" = synced ]; then miss_clear; else miss_set; fi

# Notify running rmpc to re-read so the *current* song's pane populates.
rmpc remote indexlrc --path "$LRC_FILE" 2>/dev/null && log "indexed: $LRC_FILE"
