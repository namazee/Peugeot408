# Asset licences

| Asset | Source | Licence |
|---|---|---|
| `remotion/assets/icon/icon-default.jpg` | The project author's own icon artwork, generated from a photo of their car | Owned by the project author |
| `Peugeot408/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024*.png`, `Peugeot408/Resources/IconReveal.mp4` | Rendered from the artwork above by `remotion` (`npm run icon`) | Owned by the project author |
| SF Symbols (in code) | Apple, system-provided | Apple SF Symbols licence (use in apps on Apple platforms) |
| Michroma font (GTCP wordmark on the app icon, via `@remotion/google-fonts`) | Vernon Adams, Google Fonts | SIL Open Font License 1.1 |

## Fonts (Phase 5)

Bundled unmodified in `Resources/Fonts/` (app and widget extension) for the Studio builder and templates. Downloaded on 2026-11-20 from the official Google Fonts repository (`github.com/google/fonts`, `ofl/` folder). Full licence texts are in `Resources/Licenses/`.

| File | Font | Copyright | Licence |
|---|---|---|---|
| `Orbitron.ttf` (variable weight) | Orbitron | 2018 The Orbitron Project Authors | SIL Open Font License 1.1 (Reserved Font Name "Orbitron") |
| `PlayfairDisplay.ttf` (variable weight) | Playfair Display | 2017 The Playfair Display Project Authors | SIL Open Font License 1.1 (Reserved Font Name "Playfair Display") |
| `Rajdhani-SemiBold.ttf`, `Rajdhani-Bold.ttf` | Rajdhani | 2014 Indian Type Foundry | SIL Open Font License 1.1 |

The files are renamed only (no glyph or table changes), so they are not "Modified Versions" under the OFL.

## Studio artwork (Phase 5)

All seasonal artwork and stickers are original: drawn in code with SwiftUI shapes and SF Symbols (`CarKit/Studio/Artwork.swift`). No Peugeot logos or lion emblem, nothing copied from other apps.

## Connect sounds (Phase 6)

| Asset | Source | Licence |
|---|---|---|
| `Resources/Sounds/*.wav` (chime-bright, chime-soft, welcome-tone, rev-sport, rev-blip, goodbye) | Synthesised from scratch by `tools/make-sounds.py` (sine, saw and noise oscillators; no samples) on 2026-11-20 | Owned by the project author |
| Spoken greeting | Generated on the device at run time by Apple's `AVSpeechSynthesizer` | Apple system voices (on-device use) |
| Imported clips | Chosen by the user on their own phone; not part of the repo | The user's own |

## My Car built-in photos

| Asset | Source | Licence |
|---|---|---|
| `Resources/MyCar/mycar-{side,front-three-quarter,rear-three-quarter,front,front-detail}.png` | Supplied by the project author on 2026-11-20 as their own photos (backgrounds already removed). The lion badges (grille, tailgate, fender, wheel caps) were pixelated here, and the photos were cropped and scaled to 900 px wide. A sixth (straight rear) photo was left out because it still showed a third-party watermark. | The project author, who stated they hold the rights |
| `Resources/MyCar/mycar-studio-{front-three-quarter,front,side,rear-three-quarter,rear,front-detail}.jpg` | Studio renders of the 408 supplied by the project author on 2026-11-20 (dark background; the app removes it on the device). Wheel-cap logos were pixelated here; the grille shields are already blank and the plates already empty. Re-encoded as JPEG (quality 90), 1024 × 1024. | The project author, who stated they hold the rights |
