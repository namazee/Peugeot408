# Asset licences

| Asset | Source | Licence |
|---|---|---|
| `remotion/assets/icon/icon-default.jpg` | The project author's own icon artwork, generated from a photo of their car | Owned by the project author |
| `Peugeot408/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024*.png`, `Peugeot408/Resources/IconReveal.mp4` | Rendered from the artwork above by `remotion` (`npm run icon`) | Owned by the project author |
| SF Symbols (in code) | Apple, system-provided | Apple SF Symbols licence (use in apps on Apple platforms) |
| Michroma font (DASHCRAFT wordmark on the app icon, via `@remotion/google-fonts`) | Vernon Adams, Google Fonts | SIL Open Font License 1.1 |

## Fonts (Phase 5)

Bundled unmodified in `Resources/Fonts/` (app and widget extension) for the Studio builder and templates. Downloaded on 2026-11-20 from the official Google Fonts repository (`github.com/google/fonts`, `ofl/` folder). Full licence texts are in `Resources/Licenses/`.

| File | Font | Copyright | Licence |
|---|---|---|---|
| `Orbitron.ttf` (variable weight) | Orbitron | 2018 The Orbitron Project Authors | SIL Open Font License 1.1 (Reserved Font Name "Orbitron") |
| `PlayfairDisplay.ttf` (variable weight) | Playfair Display | 2017 The Playfair Display Project Authors | SIL Open Font License 1.1 (Reserved Font Name "Playfair Display") |
| `Rajdhani-SemiBold.ttf`, `Rajdhani-Bold.ttf` | Rajdhani | 2014 Indian Type Foundry | SIL Open Font License 1.1 |

The files are renamed only (no glyph or table changes), so they are not "Modified Versions" under the OFL.

## Studio artwork (Phase 5)

All seasonal artwork and stickers are original: drawn in code with SwiftUI shapes and SF Symbols (`CarKit/Studio/Artwork.swift`, and `CarKit/Studio/RealisticArt.swift` for the realistic templates' dials, odometer, sky, glass, leather, sign, HUD and ticket art, and `CarKit/Studio/MoreArt.swift` for the split-flap tiles, rain, wood, brick, neon tube, thermal ticket, plate, tuning scale, street map, LCD, skyline, neon grid and striped sun, and `CarKit/Studio/ExtraArt.swift` for the shift lights, thermometer, battery, moon phase, cork, chalkboard, halftone, instant-photo frame, sticky note, dot-matrix panel, speed sign, letter grid, vinyl record, comic burst, light cone, palms, waves, mountains, start lights and chequered strip, and `CarKit/Studio/RoundFourArt.swift` for the compass, glow orb, light trails, paddy terraces, rainforest canopy, lightning bolt, strip lights, tyre stack, dimension lines, cassette tape, neon tube clips, calendar rings, postmark and perforated stamp; the tachometer is in `RealisticArt.swift`). No Peugeot logos or lion emblem, nothing copied from other apps.

## Connect sounds (Phase 6, packs in Phase 12)

| Asset | Source | Licence |
|---|---|---|
| `Resources/Sounds/*.m4a`, synthesised packs: Classic (chime-bright, chime-soft, welcome-tone, rev-sport, rev-blip, goodbye), EV whoosh (`ev-*`), Luxury (`lux-*`), Retro arcade (`arc-*`), Minimal pings (`ping-*`), Sci-fi (`sf-*`) | Synthesised from scratch by `tools/make-sounds.py` (sine, square, saw and noise oscillators; no samples), loudness-matched; regenerated 2026-11-20 (Phase 12) | Owned by the project author |
| Voice cues | Spoken on the device at run time by Apple's `AVSpeechSynthesizer`; the lines are original | Apple system voices (on-device use) |
| Spoken greeting | Generated on the device at run time by Apple's `AVSpeechSynthesizer` | Apple system voices (on-device use) |
| Imported clips | Chosen by the user on their own phone; not part of the repo | The user's own |

### Engine starts pack (Phase 12)

Real recordings, each checked on its own page as CC0 1.0 (Freesound) or public domain (Wikimedia Commons) on 2026-11-20.
Freesound files are the site's high-quality MP3 previews of the originals (same recordings, same licence).
`tools/process-engine-sounds.py` keeps at most 5 s from the moment the engine fires, fades the ends and loudness-matches them.
CC0 needs no attribution; the authors are listed anyway, with thanks.

| Asset | Recording | Author | Licence |
|---|---|---|---|
| `Resources/Sounds/eng-v8-bigblock.m4a` (Big-block V8) | https://freesound.org/people/Henaway/sounds/127980/ | Henaway | CC0 1.0 |
| `Resources/Sounds/eng-v8-corvette.m4a` ('74 Corvette V8 start) | https://freesound.org/people/DigPro120/sounds/432638/ | DigPro120 | CC0 1.0 |
| `Resources/Sounds/eng-v8-mustang.m4a` ('85 Mustang V8) | https://freesound.org/people/lmbubec/sounds/119449/ | lmbubec | CC0 1.0 |
| `Resources/Sounds/eng-v8-ferrari.m4a` (Ferrari 360 V8) | https://freesound.org/people/PritzProductions/sounds/241083/ | PritzProductions | CC0 1.0 |
| `Resources/Sounds/eng-v12-lambo.m4a` (Lamborghini start-up) | https://freesound.org/people/JaimeLopes/sounds/564373/ | JaimeLopes | CC0 1.0 |
| `Resources/Sounds/eng-supercar.m4a` (Supercar rev) | https://freesound.org/people/richwise/sounds/478756/ | richwise | CC0 1.0 |
| `Resources/Sounds/eng-flat6-911.m4a` (Porsche 911 flat-six) | https://freesound.org/people/mharo/sounds/55727/ | mharo | CC0 1.0 |
| `Resources/Sounds/eng-boxer-wrx.m4a` (Subaru WRX boxer) | https://freesound.org/people/ulose2piranha/sounds/273334/ | ulose2piranha | CC0 1.0 |
| `Resources/Sounds/eng-v10-m6.m4a` (BMW M6 V10 start) | https://freesound.org/people/Kinoton/sounds/478597/ | Kinoton | CC0 1.0 |
| `Resources/Sounds/eng-v8-maserati.m4a` (Maserati sport mode) | https://freesound.org/people/myeclecticself/sounds/585215/ | myeclecticself | CC0 1.0 |
| `Resources/Sounds/eng-ev-start.m4a` (Electric car start) | https://freesound.org/people/evsecrets/sounds/324119/ | evsecrets | CC0 1.0 |
| `Resources/Sounds/eng-hatch-start.m4a` (Hatchback start) | https://commons.wikimedia.org/wiki/File:Open_Corsa_E_model_2014_engine_startup_sound.ogg | MKFI | Public domain |

## My Car built-in photos

| Asset | Source | Licence |
|---|---|---|
| `Resources/MyCar/mycar-{side,front-three-quarter,rear-three-quarter,front,front-detail}.png` | Supplied by the project author on 2026-11-20 as their own photos (backgrounds already removed). The lion badges (grille, tailgate, fender, wheel caps) were removed here with a smooth fill from the surrounding pixels, and the photos were cropped and scaled to 900 px wide. A sixth (straight rear) photo was left out because it still showed a third-party watermark. | The project author, who stated they hold the rights |
| `Resources/MyCar/mycar-studio-{front-three-quarter,front,side,rear-three-quarter,rear,front-detail}.png` | Studio renders of the 408 supplied by the project author on 2026-11-20, already cut out (transparent). Wheel-cap logos were removed here with a smooth fill; the grille shields are already blank and the plates already empty. Cropped to the car (from 1024 × 1024). | The project author, who stated they hold the rights |

## Phase 9: Remotion videos and art

| Asset | Source | Licence |
|---|---|---|
| `remotion/src/**` compositions (WidgetShowcase, AppPreview, Onboarding*, SeasonalArt) | Original, written for this project | Owned by the project author |
| `Peugeot408/Resources/Onboarding/Onboarding{Welcome,Setup,Flash}.mp4` | Rendered from the compositions above (`npm run videos`) | Owned by the project author |
| `Resources/Seasonal/seasonal-*.png` | Original SVG illustrations in `SeasonalArt.tsx`, rendered by Remotion. The Malaysian flag (Jalur Gemilang) is drawn as a national symbol; no logos. | Owned by the project author |
| `remotion/assets/car/*` | Copies of the built-in My Car photos (see above) for the showcase video | The project author |
| Inter, Nunito fonts (videos only, loaded by `@remotion/google-fonts`) | Google Fonts | SIL Open Font License 1.1 |
| Remotion | remotion.dev | Remotion free licence (individuals / small teams); this is a personal project |
