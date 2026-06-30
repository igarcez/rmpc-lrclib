# LRCLIB API

The upstream lyrics service this repo fetches from. Source docs: `https://lrclib.net/docs`
(the page is a JS SPA — fetch the endpoints live, don't scrape the HTML). Base URL
`https://lrclib.net/api`. No auth or API key for reads; publishing uses a proof-of-work token.
How `scripts/lyrics-fetch.sh` consumes this API: [lyrics-hook.md](lyrics-hook.md).

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/get` | Single best match by exact metadata. `404` when no track matches. |
| GET | `/api/get/{id}` | Fetch one record by its numeric `id`. |
| GET | `/api/search` | Fuzzy search; returns an array (≤20), `200` + `[]` when nothing matches. |
| POST | `/api/request-challenge` | Get a proof-of-work challenge `{prefix, target}` for publishing. |
| POST | `/api/publish` | Submit lyrics; requires a solved `X-Publish-Token` header. |

### GET /api/get
Query params: `artist_name` (required), `track_name` (required), `album_name` (optional),
`duration` (optional, **seconds**). The server matches `duration` within a **±2s** tolerance.
Returns one track record (below) or HTTP `404`.

### GET /api/search
Either free-text `q`, **or** `track_name` (required) plus optional `artist_name` / `album_name`.
Returns a JSON **array** of track records, newest/most-relevant first, capped around 20. Always `200`;
an empty result is `[]`, not an error. Unlike `/get`, a record here may have `syncedLyrics: null` even
when another variant in the same array is synced — iterate and pick a synced one.

### POST /api/publish (proof-of-work)
1. `POST /api/request-challenge` → `{ "prefix": "<str>", "target": "<hex>" }`.
2. Find a `nonce` such that `SHA-256(prefix + nonce)` is numerically **below** `target`.
3. `POST /api/publish` with header `X-Publish-Token: <prefix>:<nonce>` and a JSON body:
   `trackName`, `artistName`, `albumName`, `duration`, `plainLyrics`, `syncedLyrics`. `201` on success.

## Track record fields

Returned by `/api/get`, `/api/get/{id}`, and each element of `/api/search` (confirmed live):

- `id` — integer.
- `trackName`, `artistName`, `albumName` — strings.
- `duration` — float, **seconds**.
- `instrumental` — boolean (no lyrics expected; the hook drops these).
- `plainLyrics` — string or `null` (no `[mm:ss]` timestamps).
- `syncedLyrics` — string or `null` (LRC with `[mm:ss.xx]` timestamps).

## Rules

- **Set a descriptive `User-Agent`** identifying the app + version + a contact/URL — LRCLIB requests this
  of all clients. `scripts/lyrics-fetch.sh` sends it via `curl -A "$UA"` (`UA` constant near the `API`
  definition: `rmpc-lrclib/1.0 (+https://github.com/igarcez/rmpc-lrclib)`); bump the version when the
  script changes materially.
- Be polite on **batch** fetches: serialize/throttle requests; there is no published hard rate limit but
  the service is free and donation-funded.
- A no-match on `/api/get` is `404` (curl `-f` exits `22`) — distinct from a transport failure; the hook
  uses this to decide whether to write a miss marker. See [lyrics-hook.md](lyrics-hook.md).

## Reference

- API docs: `https://lrclib.net/docs`
- Source / self-host: `https://github.com/tranxuanthang/lrclib`
