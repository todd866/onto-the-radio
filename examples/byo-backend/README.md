# Onto the Radio — Reference BYO AI Backend

A zero-dependency Python 3 reference server implementing the **Onto the Radio** home server contract (`Shared/HomeRadioClient.swift`). Point it at any local folder of audio you own, optionally join canonical IDs (`mbid:...` / `isrc:...`) with [Manifold](https://github.com/todd866/manifold) k-anonymous shards, and stream straight into the iOS, macOS, or tvOS app.

## Quick start

```bash
python3 examples/byo-backend/server.py \
  --media-dir ~/Music/Library \
  --pass "choose-a-strong-passphrase" \
  --name "My Radio Server"
```

Run offline (no calls to Manifold):

```bash
python3 examples/byo-backend/server.py \
  --media-dir ~/Music/Library \
  --pass "choose-a-strong-passphrase" \
  --offline
```

## Optional Manifold join (`--catalog`)

Pass `--catalog catalog.json` mapping relative file paths to canonical MusicBrainz/ISRC IDs and metadata:

```json
{
  "Ambient/Satie - Gymnopédie No. 1.m4a": {
    "workId": "mbid:f0d2b6c2-9f4e-4b3b-891c-8398409e2736",
    "artist": "Erik Satie",
    "title": "Gymnopédie No. 1",
    "year": 1888,
    "genre": "classical"
  }
}
```

When `workId` is set, the server computes `sha256(workId)[:2]` locally and requests only `/api/v1/shard/<prefix>?domain=radio` plus `/api/v1/lenses?domain=radio`. File paths, filenames, and your full library list never leave your machine.

Sidecar artwork (`cover.jpg`, `cover.png`, `folder.jpg`, `folder.png`, `artwork.jpg`) in any track's folder is automatically served over `/api/art/<sha>`.

## Connecting from Onto the Radio (iOS / macOS / tvOS)

1. For testing on the same Mac: use `http://127.0.0.1:8787`.
2. From iPhone or Apple TV over HTTPS: put the loopback listener behind an HTTPS reverse proxy (for example `tailscale serve https / http://127.0.0.1:8787` or Caddy/Cloudflare Tunnel).
3. In **Onto the Radio** → **Settings** → **Home Server**, enter the server URL and passphrase.

## Run tests

```bash
python3 -m unittest discover -s examples/byo-backend -v
```
