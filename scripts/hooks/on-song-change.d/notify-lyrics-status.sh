#!/bin/sh
# rmpc on_song_change hook: send desktop notifications for lyrics fetch status.
# Reads status file written by lyrics-fetch.sh and sends notify-send notifications.
set -u

[ -n "${LRC_FILE:-}" ] || exit 0

NOTIFY_DIR="$HOME/.cache/rmpc/lyrics-notify"
NOTIFY_TIMEOUT=5000
STATUS_FILE="$NOTIFY_DIR/$(printf '%s' "$LRC_FILE" | cksum | cut -d' ' -f1)"

# Poll for status file (up to 2 seconds) — lyrics-fetch may write it after we start.
for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ -f "$STATUS_FILE" ]; then
        break
    fi
    sleep 0.2
done

[ -f "$STATUS_FILE" ] || exit 0

# Parse the status file. Do NOT `.`-source it: values hold spaces (and arbitrary
# track metadata), which sourcing would split into commands.
field() { sed -n "s/^$1=//p" "$STATUS_FILE" | head -n1; }
EVENT=$(field EVENT)
ARTIST=$(field ARTIST)
TITLE=$(field TITLE)
ERROR=$(field ERROR)

# Send notification based on event.
case "${EVENT:-}" in
    fetching)
        notify-send -t "$NOTIFY_TIMEOUT" "Fetching lyrics" "for ${TITLE:-?} by ${ARTIST:-?}" 2>/dev/null || true
        ;;
    success)
        notify-send -t "$NOTIFY_TIMEOUT" "Lyrics fetched" "Saved for ${TITLE:-?} by ${ARTIST:-?}" 2>/dev/null || true
        ;;
    no-match)
        notify-send -t "$NOTIFY_TIMEOUT" "No lyrics found" "for ${TITLE:-?} by ${ARTIST:-?}. Will retry in 30 days" 2>/dev/null || true
        ;;
    network-error)
        notify-send -t "$NOTIFY_TIMEOUT" "Connection failed" "for ${TITLE:-?} by ${ARTIST:-?}: ${ERROR:-?}" 2>/dev/null || true
        ;;
esac

# Clean up status file.
rm -f "$STATUS_FILE" 2>/dev/null || true
