# Onto the Radio (iOS, macOS, tvOS)

Native SwiftUI audio player and latent-space station tuner for **Onto the Radio**, paired with [Manifold](https://manifold-chi.vercel.app) for signed station Lenses, 32-D / 3072-D vector sequencing, and canary-verified contributor reputation.

- **Targets (`project.yml` via `xcodegen`)**:
  - `OntoTheRadio` — iOS 18+ (`com.iantodd.ontotheradio`, iPhone & iPad)
  - `OntoTheRadioMac` — macOS 15+ (`com.iantodd.ontotheradio.mac`, Hardened Runtime, Developer ID notarizable)
  - `OntoTheRadioTV` — tvOS 18+ (`com.iantodd.ontotheradio.tv`, Apple TV)
  - `OntoTheRadioTests` — XCTest unit suite (Lens cosine ranking, Energy/Heaviness dial filtering, silent initialization)
- **Zero copyrighted payload**: Plays user-imported local files (`Files.app` / security-scoped bookmarks) plus bundled CC0 / Public-Domain showcase works (*Open Goldberg Variations*, Satie, Debussy, Bach) so cold launches work offline and in App Review without external server setup.
- **Silent QA**: Pass `-onto.silentQA` or `MUSIC_SILENT_QA=1` to clamp `AVPlayer` output to mute during automated checks.

## Build & Test

```bash
xcodegen generate
xcodebuild -scheme OntoTheRadio -destination 'platform=iOS Simulator,name=iPhone Duo' test
xcodebuild -scheme OntoTheRadioMac -destination 'platform=macOS' build
xcodebuild -scheme OntoTheRadioTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
```
