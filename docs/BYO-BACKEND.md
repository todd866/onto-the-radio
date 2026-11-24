# Bring-Your-Own AI Backend Spec

**Onto the Radio** ships as a thin native client (iOS, macOS, tvOS) over an open-source showcase and shared embedding coordinate pool. When you want to stream your own collection, **you and your AI build the personal backend** on hardware you control while [Manifold](https://github.com/todd866/manifold) distributes only canonical coordinates and signed curation lenses.

## Three-Layer Architecture

```
+-------------------------------------------------------------------+
| Layer 1: Manifold (Public Embeddings + Signed Lenses + MCP)       |
| - 32-D / 3072-D coordinates keyed by mbid: / isrc:                |
| - Ed25519-signed station lenses & canary reputation               |
| - k-anonymous 2-hex shard fetch: GET /api/v1/shard/:prefix        |
+---------------------------------+---------------------------------+
                                  | pulls lenses & 1/256th shards
                                  v (zero local paths uploaded)
+-------------------------------------------------------------------+
| Layer 2: You + Your AI Agent (Private BYO Backend)                |
| - Indexes your audio files locally on your machine / NAS          |
| - Joins local tracks with Manifold vectors & lens anchors         |
| - Exposes the 6 core routes (+ optional Glancebar remote routes)  |
+---------------------------------+---------------------------------+
                                  | cookie session + Range streaming
                                  v
+-------------------------------------------------------------------+
| Layer 3: Onto the Radio (Thin Native Frontend)                    |
| - SwiftUI player for iOS, macOS, and tvOS                         |
| - Works offline with CC0/PD showcase + Apple/YouTube handoff      |
| - Connects seamlessly to your Home Server in Settings             |
+-------------------------------------------------------------------+
```

A working zero-dependency Python implementation lives at [`examples/byo-backend/server.py`](../examples/byo-backend/server.py).

## Wire Contract (`Shared/HomeRadioClient.swift`)

The native app normalizes your configured server URL, stores the password in the system Keychain, and uses `URLSession.shared` (`HTTPCookieStorage.shared`). All audio requests made by `AVPlayer` forward matching cookies via `AVURLAssetHTTPCookiesKey`.

### 1. `POST /api/login`

Authenticate and receive an HTTP session cookie.

Request:
```json
{
  "pass": "your-server-passphrase",
  "name": "Onto the Radio"
}
```

Response (`200 OK`, with `Set-Cookie: <name>=<token>; Path=/; HttpOnly`):
```json
{
  "name": "My Radio Server"
}
```

Return `401 Unauthorized` when the passphrase does not match.

### 2. `GET /api/home`

Return shelves of playable tracks and station tiles. Note that every tile requires non-null string `title` and `sub` fields.

Response (`200 OK`):
```json
{
  "shelves": [
    {
      "id": "library",
      "title": "Your Library",
      "tiles": [
        {
          "kind": "song",
          "s": "8a3c19f04b7e12d4",
          "title": "Gymnopédie No. 1",
          "sub": "Erik Satie · 1888",
          "artist": "Erik Satie",
          "art": true,
          "color": "#2F6BFF",
          "point": { "x": -0.6284, "y": 0.4621 }
        }
      ]
    },
    {
      "id": "stations",
      "title": "Stations",
      "tiles": [
        {
          "kind": "station",
          "title": "Miles orbit",
          "sub": "Modal jazz, muted trumpet space, and nocturnal Rhodes",
          "color": "#D97706",
          "station": {
            "id": "lens:radio:jazz-miles-orbit",
            "name": "Miles orbit",
            "color": "#D97706",
            "count": 420
          }
        }
      ]
    }
  ]
}
```

### 3. `POST /api/queue`

Sequence tracks for a selected station or mood. When a user taps a Home Server station tile whose `station.id` is `<id>`, the client sends `"station:<id>"` as `mood`.

Request:
```json
{
  "mood": "station:lens:radio:jazz-miles-orbit",
  "n": 18
}
```

Response (`200 OK`):
```json
{
  "picks": [
    {
      "s": "8a3c19f04b7e12d4",
      "a": "Miles Davis",
      "t": "So What",
      "al": "Kind of Blue",
      "y": 1959,
      "g": "modal jazz",
      "e": 0.42,
      "h": 0.28,
      "x": -0.34,
      "yy": 0.48,
      "tag": "Cool muted trumpet lead",
      "dur": 562,
      "color": "#D97706",
      "art": true,
      "pt": "pick_tok_01"
    }
  ]
}
```

Field mapping inside `HomeRadioClient.swift`:

| Key | Required | Meaning |
|---|---|---|
| `s` | Yes | Opaque track ID used for `/api/audio/<s>` and `/api/art/<s>` |
| `a` | Yes | Artist name |
| `t` | Yes | Track title |
| `al` | No | Album name |
| `y` | No | Release year (int) |
| `g` | No | Genre / style label |
| `e`, `h` | No | Normalized Energy and Heaviness (`0.0`–`1.0`) |
| `x`, `yy` | No | 2-D Manifold map coordinates (`-1.0`–`1.0`) |
| `tag` | No | Short hook / mood note |
| `dur` | No | Duration in seconds |
| `color` | No | Accent hex (`#RRGGBB`) |
| `art` | No | Set `true` when `/api/art/<s>` is available |
| `pt` | No | Opaque pick token echoed back to `/api/event` |

### 4. `GET /api/audio/<sha>` (and `HEAD /api/audio/<sha>`)

Stream the audio bytes for `<sha>`. The app requests `/api/audio/<sha>?q=aac`.

- Require the session cookie (`401` if missing/invalid).
- Support `Accept-Ranges: bytes` and HTTP `206 Partial Content` (`Content-Range: bytes <start>-<end>/<total>`) for Apple `AVPlayer` playback and scrubbing.
- Never accept raw filesystem paths or `..` segments in `<sha>`.

### 5. `GET /api/art/<sha>`

Serve square cover artwork for `<sha>`. The app requests `?size=300` on cards and `?size=600` in Now Playing. Return `404` when a track has no artwork.

### 6. `POST /api/event`

Record playback feedback to steer subsequent queues.

Request:
```json
{
  "pt": "pick_tok_01",
  "ev": "like",
  "pos": 148.5
}
```

Standard `ev` values emitted by `RadioEngine.swift`: `"like"`, `"dislike"`, `"finish"`.

### 7. Optional Glancebar Remote Connector (`/api/glancebar/now`, `/api/glancebar/cmd`)

If your home connector also bridges a desktop player (such as Glancebar on macOS), **Onto the Radio** probes `GET /api/glancebar/now` after home login and shows a **Mac / Local** output toggle pill in the top bar when available.

#### `GET /api/glancebar/now`

- Require the same session cookie (`401` if missing/invalid; return `404` if desktop remote control is not configured).
- Response (`200 OK`):

```json
{
  "state": "playing",
  "title": "So What",
  "artist": "Miles Davis",
  "liked": true,
  "host": "studio-mac",
  "epoch": 1732400000.0
}
```

| Key | Required | Meaning |
|---|---|---|
| `state` | Yes | `"playing"`, `"paused"`, or `"stopped"` |
| `title` | No | Active desktop track title |
| `artist` | No | Active desktop artist |
| `liked` | No | Whether the active track is hearted/liked |
| `host` | No | Display label for the desktop host |
| `epoch` | No | Unix timestamp (seconds) of state snapshot |

#### `POST /api/glancebar/cmd`

- Require the same session cookie (`401` if missing/invalid).
- Request:

```json
{
  "cmd": "toggle"
}
```

Standard `cmd` values sent by `RadioEngine.swift`:
- `"toggle"` — Play/pause toggle
- `"next"` / `"prev"` — Skip forward/back
- `"like"` — Toggle like/heart on the active desktop track
- `"dislike"` — Dislike and skip the active desktop track
- `"mood:chill"`, `"mood:dance"`, `"mood:any"`, or `"mood:<stationKey>"` — Steer desktop station/mood selection

- Response (`200 OK`):

```json
{
  "ok": true,
  "now": {
    "state": "paused",
    "title": "So What",
    "artist": "Miles Davis",
    "liked": true,
    "host": "studio-mac",
    "epoch": 1732400004.0
  }
}
```

## K-Anonymous Manifold Enrichment

To map your local tracks into Manifold's coordinate space without revealing your collection:

1. Match each local track to a public `mbid:<uuid>` or `isrc:<code>` locally.
2. Compute `prefix = sha256(workId)[:2]` (lowercase hex).
3. Fetch `GET https://manifold-chi.vercel.app/api/v1/shard/<prefix>?domain=radio` (only 1/256th bucket prefix, zero filenames).
4. Fetch signed stations via `GET https://manifold-chi.vercel.app/api/v1/lenses?domain=radio`.
5. Score tracks locally against lens anchor vectors (`vec32`) and your own `events.jsonl` history.

## Prompt for Your AI Agent

Copy this prompt into your AI coding assistant when building or customizing your own backend:

> Read `docs/BYO-BACKEND.md` and `examples/byo-backend/server.py` in `onto-the-radio`, and connect to the Manifold MCP server at `https://manifold-chi.vercel.app/api/mcp`. Build a personal backend for my audio library folder that serves the 6 Onto the Radio HTTP endpoints (`/api/login`, `/api/home`, `/api/queue`, `/api/audio/:sha`, `/api/art/:sha`, `/api/event`) with `Range`/`206` support, matches my files locally against Manifold shards (`sha256(workId)[:2]`) without uploading file paths, and persists my taste events locally.
