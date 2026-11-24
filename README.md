# Onto the Radio (iOS, macOS, tvOS)

**A thin native radio frontend over open showcase streams, signed Manifold lenses, and your own AI-built personal backend.**

Onto the Radio follows a three-layer architecture ([Manifold architecture overview](https://github.com/todd866/manifold/blob/main/docs/BYO-AI-ARCHITECTURE.md)):

1. **Open Embeddings & Lenses ([Manifold](https://manifold-chi.vercel.app)):** Canonical audio coordinates (`mbid:` / `isrc:`) and Ed25519-signed station lenses.
2. **Open-Source Showcase & Thin Native UI (this repo):** SwiftUI app for iOS, macOS, and tvOS with zero copyrighted payload — ready to play out of the box using open CC0 / Public-Domain streams plus Apple Music & YouTube Music handoffs.
3. **You + Your AI Backend (`docs/BYO-BACKEND.md`):** Connect your own self-hosted audio server over HTTPS (`Shared/HomeRadioClient.swift`), fed by local files and k-anonymous Manifold shard lookups.

## What's Inside

- **Targets (`project.yml` via `xcodegen`)**:
  - `OntoTheRadio` — iOS 18+ (`com.iantodd.ontotheradio`, iPhone & iPad)
  - `OntoTheRadioMac` — macOS 15+ (`com.iantodd.ontotheradio.mac`, Hardened Runtime, Developer ID notarizable)
  - `OntoTheRadioTV` — tvOS 18+ (`com.iantodd.ontotheradio.tv`, Apple TV)
  - `OntoTheRadioTests` — XCTest suite (Lens cosine ranking, Energy/Heaviness dial filtering, Jazz & Classical coordinate coverage, silent QA initialization)
- **Zero copyrighted payload & open showcase**:
  - **10 open CC0 / Public-Domain full-length streams** (*Open Goldberg Variations*, Satie, Debussy, Bach cello, Holst *Mars*, Vivaldi *Summer Presto*, Mussorgsky, Kevin MacLeod *Acid Jazz* & *Night on the Docks*).
  - **Jazz (*Miles orbit*) & Classical (*Heavy & hypnotic*) gateway shelves** (`19` offline works and `5` signed lenses bundled in `Shared/ManifoldRadioClient.swift`, expanded to `38` works when synced with Manifold), plus `30s` catalog previews and deep links to **Apple Music** and **YouTube Music** (`Shared/AppleMusicCatalog.swift`).
- **On-device AI title fitting (`Shared/AITitleFitter.swift`)**:
  - Uses Apple `FoundationModels` (iOS 26 / macOS 26 when available, guarded cleanly out of tvOS) paired with deterministic editorial heuristics so long titles fit cleanly with zero `...` truncation.
- **User-supplied content**:
  - Import local audio files directly via `Files.app` (security-scoped bookmarks), or connect a **Home Server** in Settings.
- **Glancebar / OtR desktop remote connector (`Shared/HomeRadioClient.swift`)**:
  - When your home server exposes `/api/glancebar/now` and `/api/glancebar/cmd`, switch the top-bar pill between **Local** and **Mac** to pause local playback and control your desktop player (play/pause, skip, heart/like, mood & station steering).
- **Silent QA**: Pass `-onto.silentQA` or `MUSIC_SILENT_QA=1` to mute `AVPlayer` output during automated tests.

## Quickstart: Run the Reference BYO Backend

A zero-dependency Python 3 server in [`examples/byo-backend/`](examples/byo-backend/) turns any folder of audio you own into a compatible Home Server and enriches tracks via k-anonymous `/api/v1/shard/:prefix` calls to Manifold:

```bash
python3 examples/byo-backend/server.py \
  --media-dir ~/Music/Library \
  --pass "choose-a-strong-passphrase"
```

Run its unit tests:

```bash
python3 -m unittest discover -s examples/byo-backend -v
```

See [docs/BYO-BACKEND.md](docs/BYO-BACKEND.md) for the complete HTTP contract and an AI agent setup prompt for building custom backends.

## Build & Test

```bash
xcodegen generate
MUSIC_SILENT_QA=1 xcodebuild -scheme OntoTheRadio -destination 'platform=iOS Simulator,name=iPhone 16' test
xcodebuild -scheme OntoTheRadioMac -destination 'platform=macOS' build
xcodebuild -scheme OntoTheRadioTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
```
