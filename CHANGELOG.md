# Changelog

Fresh session? Read `docs/SPEC.md`, then this file, then continue from **Current phase**.

## Current phase: 9 (Remotion) — done; Phase 8 still waiting for your car test. Next: "Continue with Phase 10" (Polish)

## Change before Phase 10 — built-in slot pictures keep their original colours (spec updated first)
- Built-in photos picked as a slot picture are no longer recoloured with your My Car paint. They keep their original colours and still get your plate. The live My Car option still follows your paint.
- Pictures already picked keep their old colours until you pick them again.

## Change before Phase 10 — picture instead of an icon in slots (spec updated first)
- Text slot designs, and the new "Custom text" option in Split/Quad cards, can show a **picture** instead of the SF Symbol icon:
  - your live My Car photo (`mycar.png`, so paint and plate changes follow);
  - any of the 11 built-in photos, rendered with your paint and plate;
  - an upload (PhotosPicker).
- Uploads are shrunk to 800 px. Transparent pictures stay PNG with their empty margins trimmed; opaque ones become JPEG. Files go in `slot-images/` in the App Group.
- The picture is always drawn whole (fit), as large as the slot allows: the value and label sit below it (small) or beside it (medium), or the picture shows alone when the text is empty. In cards, the picture fills the card with the value underneath.
- Changing the My Car photo reloads all slot widgets.
- `SlotDesign.imageFile` is optional, so older files still load.

## Change before Phase 10 — pre-cut studio My Car photos (spec updated first)
- You supplied the six studio renders already cut out. They replace the studio JPGs: no on-device Vision step, cleaner edges, and picking one is instant.
- Wheel-hub logos are removed with the same smooth fill, and each photo is cropped to the car. Plate corners and window outlines are shifted by each crop.
- A studio photo already in use is re-rendered once on first launch (`cutoutVersion` 3). The on-device cut-out code stays for your own photos.

## Phase 9 — Remotion assets (§7)

### Done
- **Shared theme:** `theme/tokens.json` holds the colours, AQI bands and radii. Remotion imports it directly; `tools/gen-theme.py` writes `CarKit/Theme/ThemeTokens.swift`, which `Theme.Hex` and the AQI bands now use. `ci/generate.sh` runs `gen-theme.py --check`, so CI fails if the JSON and the Swift constants drift apart.
- **Shared Remotion UI** (`remotion/src/shared`): theme, fonts (Inter and Nunito via `@remotion/google-fonts`, the closest open fonts to SF Pro / SF Rounded), an original icon set, a `SplitCard` drawn like the app's slot card, `Column`, and `CarPlayScreen`.
- `WidgetShowcase` (1920×720, 18 s): CarPlay-style dashboard. Columns animate in; the prayer countdown and the service km tick, the boost gauge rises on two "pulls", the photo frame crossfades between your studio shots, and it ends on a title card.
- `AppPreview` (886×1920, 20 s): the Fuel Log, adding a fill-up (fields type in, Save), the new row and km/L 14.2 → 14.4, then the head unit's Fuel card updating. With captions.
- **Onboarding clips** (720×900): `OnboardingWelcome` (the head unit filling with split cards), `OnboardingSetup` (Settings → General → CarPlay → My 408 → Widgets → add Car Slot 1–5), and `OnboardingFlash` (each card shows "Slot N · Top/Bottom ✓").
  - They play muted and looping in the app via `ClipView` (AVQueuePlayer + AVPlayerLooper): page 2 shows setup, page 3 the flash test, and the welcome clip is at the top of "How to add to CarPlay". Page 1 keeps the icon reveal.
- **Seasonal artwork:** `SeasonalArt` stills (600×600, transparent) for all 8 packs, saved as `Resources/Seasonal/seasonal-<occasion>.png` and bundled in the app and the widget.
  - Seasonal designs use the new `LayerContent.seasonalArt`, which falls back to the drawn artwork if a PNG is missing.
  - The builder has "Seasonal art" in its Add menu.
- **Rendering:** `npm run videos` renders everything and copies the clips and art into the app (`--no-copy` skips the copy). The Remotion workflow now also renders them and uploads `videos-<run>` as build artifacts.

- CI: the Remotion workflow is green (renders and uploads every video and still). The iOS build needed one fix: an orphaned footer left in the slot editor by the Phase 8 edit. "Reset to default" now restores the split defaults. Green on run 33 (147 tests in 24 suites); **1.1 (33)** includes Phases 8 and 9.

### Decisions
- The rendered clips and art are committed (like the icon), because the iOS build doesn't run Node. CI re-renders them as artifacts.
- The videos use Inter and Nunito, since SF fonts can't be used on the web or in Linux renders.


Note: this change request came after Phase 2, so it became the new Phase 8 (spec commit "spec: split-card slot layouts"). Remotion moved to Phase 9 and Polish to Phase 10.

## Phase 8 — Split-card slot layouts (§4b) — built; waiting for your car test
- Fix after the first CI run: single-layout slots counted a phantom card as a source (made a Studio test fail); they now don't.

### Done
- `SlotLayout`: Single / Split (default) / Quad. Each `SlotDesign` has an optional `layout` and `cards` (each card is its own data source, Studio design or text). Older files decode, since both fields are optional.
- **Default setup:** Slot 1 = Next prayer / Road tax, Slot 2 = Service / Fuel, Slot 3 = Weather & haze / Parking, all Split. Slots 4–5 stay single for stacking behind the columns.
  - `SlotsState` is now version 2. A version-1 file is upgraded once when loaded: slots 1–3 take the defaults, 4–5 are kept.
- **Timeline:**
  - Split and Quad slots draw `.cards(layout, parts)`, and their entry dates are the union of every card's dates (e.g. prayer times and midnights).
  - Reload and live-refresh logic includes every card's sources.
  - Seasonal takeover still replaces the whole slot. Time-of-day rotation applies to Single only.
- **Cards (`SlotCardsView` / `SlotCardView`):**
  - Split: icon + short label (13 pt, never below about 11) + one big value (26 pt, never below about 18).
  - Quad: icon + value only (20 pt).
  - 6 pt gaps between cards, with a thin outline in tinted/clear CarPlay. The urgency colour applies per card (value colour and border).
  - Map, photo and music cards show their image. Timers and relative times tick by themselves.
  - The compact version of every data source is `DataCard.compact`.
- **Flash test:** each card shows "Slot N · Top ✓" / "Bottom ✓" (Quad: Top left …); single slots still show "Slot N ✓".
- **Slots tab:**
  - The mock screen shows the real 3 tall columns (Slot 1–3) with split cards; tapping a card opens the editor with that card highlighted. Slots 4–5 are shown smaller underneath as "Behind (Smart Rotate)".
  - The editor has a Layout picker and one "Shows" picker per card. Quad shows the readability warning.
- **Widget:** split content uses 7 pt insets so the cards fill the tall CarPlay column; single content keeps the system margins.
- **Tests:** default setup, the one-time upgrade (and that your later edits are kept), split/quad card counts, layout switching keeping cards, single → first card, entry dates covering every card, flash labels, sources, compact urgency, summaries.

### Left over / open
- [ ] You: install the new build, check that the head unit shows 6 cards in Slot 1–3, try the flash test, and tap a card in the Slots tab to change it. Tell me if any text is too small or a value gets cut.


## Change after Phase 7 — built-in My Car photos (spec §4b)
- Spec updated first (`spec:` commit): five photos of the 408 that you supplied, already cut out, are bundled as built-in My Car photos.
- The lion badges (grille, tailgate, fender, wheel caps) are pixelated, so the "no lion emblem" rule still holds. The straight rear view was left out because it had a third-party watermark.
- Studio → My Car photo has a "Built-in photos" row. The side view is used until you choose, and choosing your own photo (Vision cut-out) still works and replaces it.
- `StudioState.builtInCarPhoto` (optional, so older files still load) records which built-in photo is in use.
- **Paint colour** (built-in photos only, spec updated first):
  - Swatches for Obsession Blue (original), Elixir Red, Okenite White, Selenium Grey and Perla Nera Black, plus a free colour picker.
  - `PaintRecolor` gives each colour a "paint weight" (hue 185–230°, saturated, not too dark), then maps paint to the target colour while keeping shading. Trim, glass, grey plate, red lights and green reflections are left alone.
  - The mapping is baked into a 32³ `CIColorCubeWithColorSpace`, applied on the device.
- **Number plate** (built-in photos only):
  - Your plate text is drawn as a black plate with white characters, warped onto the measured corners of the "408" show plate with `CIPerspectiveTransform`.
  - It appears on the front, front ¾, rear ¾ and front detail photos; the side view has no visible plate.
  - Leaving the text empty keeps the original plate.
- **Plate font:** classic bold, condensed, monospaced, rounded, Orbitron or Rajdhani (bundled or system fonts only, nothing new downloaded). The same font is used by plate layers in Studio designs.
- Tests: paint weight (paint vs trim, plate, lights, reflections, highlights), the red recolour keeping shading, unchanged non-paint pixels, cube size, presets, plate quad aspect and growth, older studio files decoding.
- CI green on run 26 (137 tests in 23 suites); uploaded as **1.1 (26)**.
- **Six studio-render built-in photos** (spec updated first): front ¾, front, side, rear ¾, rear and detail, on a dark background.
  - Wheel-cap logos are pixelated; the grille shields and plates were already blank.
  - They're bundled as JPEGs (about 780 KB in total). When you pick one, the app removes the background on the device with Vision and keeps the mask (`mask-<id>.png` in the App Group), so later colour or plate changes only repaint.
  - The paint colour and plate work the same way; plate corners were measured for the five views that show a plate.
- **Realism pass** (spec updated first):
  - **Badges:** removed with a smooth fill from the surrounding pixels instead of the blocky pixelation, which showed as a grid. The checkerboard behind the thumbnails is gone too.
  - **Body-only paint:** the hue range is now 196–235° (the cyan light glows at about 187° are skipped) and only strongly saturated colours count (pale glass reflections are skipped). Windows traced per photo and the plate area are masked out with a soft edge.
  - **Plate:** near-black with a thin edge, a faint gloss band and raised characters (with a shadow). Its brightness follows the original plate's lighting (sunlit about 1, dark studio about 0.45), and a 0.6 px blur matches the photo's sharpness.
- CI green on run 28 (137 tests); the studio photos and realism pass are in **1.1 (28)**.
- **Fix (reported from 1.1 (28)): cut-outs were cropped through the car.** `CarCutout.opaqueBounds` flipped the mask rows, assuming a bottom-up bitmap, but an image drawn into a bitmap context is stored top row first. On the studio photos the crop box came from the wrong end and cut the wheels off. Fixed; this also affects your own cut-out photos, so re-pick or redo any you made. The built-in photo in use is re-rendered once automatically.
- [ ] You: check on the phone that the paint stays off the windows and lights in each view, and that the plate looks natural. Window outlines are hand-traced, so tell me if an edge is off on any photo.
- [ ] You: check the recolour and plate overlay on the phone. White paint looks flatter than real white, as expected, and the plate perspective on the front-detail photo is the steepest.

## Phase 7 — OBD2 + Live Activity (with demo mode)

### Done
- **`CarKit/OBD` parser:** reads ELM327 replies with spaces on or off, echo, `SEARCHING...` and several ECUs answering (the first one wins).
  - `NO DATA` and `?` mean unsupported; `UNABLE TO CO24ECT`, `CAN ERROR` and bus errors mean no connection.
- **`CarKit/OBD` formulas:**
  - RPM (0C) = (256A + B) / 4.
  - Coolant (05) = A − 40 °C.
  - MAP (0B) and barometric (33) in kPa; **boost = MAP − baro, in bar** (barometric read once per session, sea level until then).
  - Battery voltage from `ATRV`.
- **Demo simulator:** cruise, then a pull to about 5,500 rpm and +1.15 bar every 20 s; coolant warms from 40 to 90 °C; voltage around 14.1 V.
- **Bluetooth UUIDs:** configurable, with presets for generic FFF0/FFF1/FFF2 (most BLE ELM327 dongles, OBDLink CX) and Vgate iCar Pro BLE.
- `obd.json` stores the dongle, UUIDs, poll rate, last values, unsupported PIDs and session state.
- **App: Bluetooth client** for BLE ELM327 dongles.
  - Scan (likely dongles listed first) and connect with a timeout.
  - Find the notify and write characteristics, run the setup (`ATZ ATE0 ATL0 ATS0 ATH0 ATSP0`), then send commands one at a time, reading each reply up to the `>` prompt.
- **App: drive session.**
  - Polls RPM every cycle, coolant every 3rd, MAP every cycle, barometric once, and voltage every 5th.
  - Two `NO DATA` answers in a row mark a value as "not reported by this car" (n/a), as PSA/Stellantis ECUs may skip PIDs.
  - Updates the Live Activity every 2 s and saves the last values every 10 s.
- **Live Activity** (`DriveActivityAttributes`): Lock Screen layout with all 4 values; Dynamic Island with boost in compact; `.supplementalActivityFamilies([.small, .medium])` with a compact 2×2 layout for CarPlay. It goes stale after 2 minutes without updates and stays for 15 minutes after the session ends.
- **Live OBD2** widget and data source: last-known values with the time read. It turns amber or red for coolant ≥105/110 °C or battery <12.2/11.8 V, and can be assigned to slots. Studio has 4 new data fields (boost, coolant, battery, RPM).
- **App screens:**
  - Car → Live OBD2 (values, status, start/stop with a demo toggle, dongle link, card preview).
  - OBD2 dongle (scan, pick, UUID presets/custom with validation, poll rate, test connection that reads voltage and RPM), also under Settings.
- **Info.plist:** `NSBluetoothAlwaysUsageDescription`, `bluetooth-central` background mode (keeps polling with the screen locked), `NSSupportsLiveActivities`.
- **Tests:** parser variants, formulas, **boost conversion** (raw replies → +0.8 bar; vacuum −0.65), voltage, demo ranges, UUID validation, card urgency, value text. 129 tests in 22 suites.
- CI green on run 24; uploaded as **1.1 (24)**.

### Fixes during the phase
- Swift 6 `sending` errors: ActivityKit's `Activity` isn't Sendable, so it's used only from nonisolated helpers. The CoreBluetooth delegate now uses a `@preconcurrency` conformance on the main actor (the manager runs on the main queue).

### Decisions
- Demo mode updates while the app is open or in the foreground. A live dongle session keeps running in the background through the `bluetooth-central` mode, because each dongle reply wakes the app.
- Boost uses the car's barometric reading when it reports one (80–110 kPa), otherwise 101 kPa.

### Left over / open
- [ ] You: install 1.1 (24). Car → Live OBD2 → Demo mode → Start drive session; check the Live Activity on the Lock Screen and in CarPlay.
- [ ] With a BLE dongle (when you have one): OBD2 dongle → Scan → pick it → Test connection, then a real drive session. Report which values show n/a on the 408.

## Phase 6 — Connect sound

### Done
- **Sound library:** 6 original sounds synthesised from scratch by `tools/make-sounds.py` (Python standard library; sine, saw and noise oscillators, no samples), saved in `Resources/Sounds/`.
  - Bright chime, soft chime, welcome tone, sporty rev (idle → 6,000 rpm blip), double blip, and goodbye.
  - Recorded in `ASSETS-LICENSES.md`.
- `CarKit/Sound`: settings in `connect-sound.json`.
  - Default sound, volume, greeting name and language (English or Malay), and imported clips.
  - Stable entity ids for the shortcut, a fallback to the welcome tone when a sound is gone, and the ≤5 s trim range.
- **Play Connect Sound** App Intent (an `AudioPlaybackIntent` that doesn't open the app).
  - It has an optional *Sound* parameter (bundled, imported, or the spoken greeting) and the Siri phrase "Play connect sound in Peugeot408".
  - It plays through the current audio route (the car speakers in CarPlay) at the set volume. `AVAudioSession` `.playback` with `.duckOthers` lowers other audio, which comes back when the sound ends.
  - The greeting ("Welcome back, <name>." / "Selamat kembali, <name>.") is spoken on the device by `AVSpeechSynthesizer`, falling back to English if no Malay voice is installed.
  - `UIBackgroundModes: audio` lets it run from an automation.
- **App:** Studio → Connect sounds.
  - Pick the default sound and play any sound; volume; test button; greeting name and language.
  - Import an audio file and trim it to ≤5 s with a preview; it's saved as AAC in the App Group and can be swiped to delete.
  - Step-by-step guides with drawn phone screens for *When CarPlay connects → Play Connect Sound* and *When CarPlay disconnects → Play Connect Sound (Goodbye) + Save Parking*.
- SETUP.md §12 has the same steps.
- **Tests:** greeting text in both languages, entity id round-trip, fallback, picker list, volume clamp, trim range, settings round-trip. 117 tests in 21 suites.
- CI green on run 21; uploaded as **1.1 (21)**.

### Decisions
- Guide "screenshots" are drawn phone screens, because there's no way to capture real Shortcuts screenshots without a Mac or device here. Real ones can come with the Phase 8 onboarding clip.
- Volume is relative to the phone's volume. iOS doesn't let apps set the system volume.

### Left over / open
- [ ] You: install 1.1 (21), go to Studio → Connect sounds, pick a sound or the greeting, set it up with the guide (or SETUP.md §12), and test it in the car.
- [ ] Not verifiable on CI: whether the automation plays through the car speakers without opening the app, and whether a Malay voice is installed.

## Phase 5 — Studio: designs, templates, builder, My Car, seasonal packs

### Done
- `CarKit/Studio`:
  - **`CardDesign`:** a versioned Codable JSON model stored in `studio.json`.
    - Layers: text, SF Symbol icon, sticker, My Car photo, data field, gauge arc, analogue clock, number plate.
    - Each layer has position, size, rotation, opacity, font, weight, size, colour, alignment, shadow and lock. Positions are fractions of the canvas, so a design scales to any widget.
    - Backgrounds: solid, gradient, texture (carbon, brushed, dots) or a Photo Frame photo.
  - **`DesignView`:** one renderer used by the builder, the gallery, the Slots screen and the widget, so the car looks exactly like the app.
  - **Data fields:** 25, covering every value from §4 plus clock, date, "days since" (anniversary) and "days until" (countdown). Resolved per timeline entry, with live timer and relative text where it fits; the analogue clock gets an entry every minute.
  - **Original artwork:** drawn in code (ketupat, crescent, lantern, pelita, diya, stripes, tree, fireworks, gauge, speed lines). No image assets, nothing copied.
  - **Glanceability linter:** warns on text under 14 pt and on WCAG contrast under 3:1. It blocks saving a small design with more than 2 data fields.
  - Designs export and import as JSON files (an import gets fresh ids; a newer format is refused).
- **Templates:** Sporty, Minimal, Premium, Dashboard, Photo, analogue and digital Clock, Countdown, Anniversary, My Car. The data templates can be bound to any of the 11 data sources, and the gallery previews them with your real data.
- **Seasonal packs:** Ramadan (iftar countdown to Maghrib), Hari Raya Aidilfitri, Aidiladha, Merdeka/Malaysia Day, Chinese New Year, Deepavali, Christmas, New Year.
  - When switched on, one chosen Car Slot shows the pack's design on the right dates, then goes back to normal.
  - Hijri dates use iOS's Umm al-Qura calendar (windows start 1–2 days early, since JAKIM's sighting can differ). Chinese New Year uses iOS's Chinese calendar. Deepavali comes from an editable table: 2026–27 confirmed, 2028–30 estimates.
  - Each pack can be switched off on its own.
- **Slots:**
  - Studio designs can be assigned to a slot.
  - Rotation: up to 2 extra designs shown during set hours (3 per slot), done with timeline entries.
  - Studio designs fill the widget edge to edge (`contentMarginsDisabled`; other content adds the margins back).
  - Reloads also reach slots that show a source through a rotation or a Studio design's data field.
- **App:**
  - **Studio tab:** my designs (with warnings), template gallery, blank design, import, seasonal packs, My Car, data sources.
  - **Builder:** small/medium canvas at the exact widget aspect ratio, with a safe-area overlay. Drag, pinch and twist; 1/24 snap grid with 15° rotation steps; undo/redo (one step per gesture); duplicate, delete, lock, layer order; per-layer inspector; background editor; export via the share sheet.
  - **My Car:** Vision `VNGenerateForegroundInstanceMaskRequest` on the device, an erase/restore brush with undo on the mask, cropped and downsampled to a 600 px transparent PNG. Also the number-plate text and one-tap My Car designs.
- **Fonts:** Orbitron, Playfair Display and Rajdhani (OFL), bundled in the app and the widget, with licences in `Resources/Licenses` and `ASSETS-LICENSES.md`.
- **Tests:** every template (×2 sizes, plus the 8 seasonal designs) round-trips through JSON and renders from it with `ImageRenderer`; templates pass the linter; linter rules; data fields (anniversary, countdown, iftar, missing data, clock entries); seasonal dates (CNY 2027, Raya and Ramadan via Hijri, Merdeka window, Deepavali table, disabled packs); slot rotation (wrap past midnight, switching), a Studio design in a slot, seasonal takeover, old slot files. 110 tests in 20 suites.
- CI green on run 20, uploaded as **1.1 (20)**.

### Fixes during the phase
- An edit script damaged `Templates.swift` (an empty match inserted text between every character), and another left a stray `}` in SlotsView. Both were fixed.
- The JSON round-trip test now ignores sub-second save times, since ISO 8601 keeps whole seconds.

### Decisions
- Fonts: the user chose to bundle 3 OFL fonts from the official Google Fonts repo (downloaded 2026-11-20), rather than use built-in fonts only.
- Analogue clocks use one entry per minute for the next hour, then reload (about 24 reloads a day, within the widget budget). The digital clock uses a timer counting up from midnight, so it ticks without reloads.
- Seasonal artwork is drawn in SwiftUI rather than rendered in Remotion. Remotion versions can replace it in Phase 8.

### Left over / open
- [ ] You: install 1.1 (20). Make a design (gallery → builder → Save), assign it to a slot, try a rotation (e.g. Prayer Times 18:00–21:00), switch on seasonal packs, and try My Car with a photo of your 408.
- [ ] The Vision cut-out and the font rendering can only be checked on the device.
- [ ] Deepavali 2028–2030 dates are estimates; check them in Studio → Seasonal packs when the gazette is out.

## Phase 4 — Photo Frame, Music

### Done
- `CarKit/Media`:
  - photo library in `photos.json`: photos, named albums, 30/45/60-minute interval, and the album Car Slots show;
  - music cache in `music.json`;
  - `.photos` and `.music` data sources with cards, so both can be assigned to Car Slots.
- Rotation is a pure function of the clock (slot = time ÷ interval, photo = slot mod count), so a widget reload never restarts the sequence. Timelines hold one entry per change for the next 12 hours.
- Photo Frame widget (small and medium) uses `AppIntentConfiguration`: long-press → Edit Widget → Album, with "All photos" as the default.
- Music widget (small and medium): artwork, title and kind (Album, Playlist, Station).
  - The medium size has optional play/pause and next buttons: `AudioPlaybackIntent`s in `Shared/`, compiled into both targets, which run in the app process and drive the system music player.
  - The widget looks complete without the buttons, and a toggle in the app hides them.
- App: Studio → Data sources → Photo Frame and Music.
  - **Photo Frame:** PhotosPicker, up to 60 photos, shrunk with ImageIO to a 1,000 px long side (EXIF rotation applied), stored as JPEG in the App Group. Albums can be created and edited, with remove via long-press.
  - **Music:** asks for Apple Music access. Shows "Recently played" or a featured library playlist. Artwork is cached at 600 px. The card refreshes whenever the app becomes active.
- Tests: rotation (clock-based, wraps, boundaries, 12 h count), the interval clamp, album filtering and fallback, photo removal cleaning albums, photo and music cards, slot timeline, store round-trips. 85 tests in 15 suites.
- CI green on run 14, uploaded as **1.1 (14)**.

### Decisions
- The widget never calls MusicKit: the app caches the card, which avoids extension authorisation problems. The card therefore updates when you open the app.
- Library-only playlist artwork uses a private URL scheme that can't be downloaded, so those cards show original placeholder art (accent gradient and a note).
- Photo Frame shows the photo inset in the card (not full-bleed), so it stays visible in CarPlay's tinted mode. The full-bleed "Photo" template comes in Phase 5.

### Left over / open
- [ ] You: install 1.1 (14), add photos, allow Apple Music, and try the play buttons on the medium Music widget on the iPhone. If they do nothing, turn them off in Studio → Music and tell me; per the spec they then get removed.
- [ ] MusicKit must be enabled on the App ID (App Services). SETUP.md §11.

## Phase 4 — App icon (spec §3 App icon; IconPreview.png approved 2026-11-20)

### Done
- `remotion/` project (Remotion 4.0.540): `AppIcon` (1024, `variant` default/dark/tinted, 4 layers), `IconPreview` (1920×1080: every variant at 1024/180/120/60/40, light and dark home screens, CarPlay mock), `IconReveal` (3.5 s, `format` square 1080×1080 or vertical 1080×1920).
- Source art `remotion/assets/icon/icon-default.jpg`; dark and tinted are generated (no source images given).
- `npm run icon` renders everything into `remotion/out`, flattens the PNGs to RGB, runs the alpha check, and copies the icons into `AppIcon.appiconset` (Any/Dark/Tinted) and `IconReveal.mp4` into the app.
- The onboarding welcome page plays `IconReveal.mp4` once (falls back to the old slot tile if the clip is missing).
- Alpha check `remotion/scripts/check-icon-alpha.mjs` runs in `npm run icon`, the new `remotion.yml` workflow (which uploads the outputs as artifacts) and `ci/test.sh` (iOS builds fail on an alpha icon).
- SETUP.md §12: how to re-render on Windows; the Icon Composer `.icon` needs a Mac.
- GTCP wordmark (spec §3 App icon, layer 5): Michroma, white with a cyan glow (white on tinted), below the car; car moved up 20 px. Fades in at the end of IconReveal. IconPreview.png approved 2026-11-20.

## Phase 3 — Parking + Map Snapshot, Prayer Times, Commute, Weather & Haze

### Done
- `CarKit/PrayerTimes` (self-contained, Foundation only, reusable in another app):
  - JAKIM e-Solat client. Format checked on 2026-11-20: Malay month names in dates ("Mac", "Ogos", "Dis"); "NO_RECORD!" replies; `period=duration` stops at 31 December, so ranges are split per year.
  - Offline fallback calculator with JAKIM-style parameters (Subuh 18°, Isyak 18°, Shafi'i Asar, +1 min ihtiyat). Tuned against JAKIM's 2026 tables for 7 zones: within about 2 minutes. Shown as "est." on the widget.
  - All 60 zones. "Pick zone from my location" matches the geocoded district within the state (Cyberjaya → Sepang → SGR01, Bukit Jalil → WLY01), else the nearest zone town.
  - Caches 35 days ahead (`prayer-cache.json`), refreshes weekly, retries failures hourly, and fills gaps by calculation (e.g. next year before JAKIM publishes it).
- `CarKit/Live`:
  - Models and caches: parking, commute, calendar, weather/haze, map index, last location.
  - One-shot location service (app and widget, with `NSWidgetWantsLocation`).
  - WeatherKit: current conditions and 24 h hourly.
  - Swappable air-quality provider (WAQI). The token comes from the `AQI_API_KEY` secret via Info.plist, or from a Settings override kept in the Keychain (App Group access group).
  - MapKit drive-time ETA and EventKit next event.
  - `MKMapSnapshotter` renderer: dark map, blue pin, one PNG per widget size.
  - `LiveRefresher` with per-source throttles: weather and haze 30 min, commute 15 min, map on target change or 6 h.
- Widgets: Parking ("Parked 2 hr, 14 min ago" ticks live), Prayer Times (next prayer plus live countdown; medium lists all 5), Commute (drive time, arrival, next event), Weather & Haze (temperature, rain today, API colour band,  Weather mark), and Map Snapshot (parked car, else the commute area).
  - Small and medium sizes, plus Lock Screen for all but Map.
  - All are assignable to Car Slots. Slots use the same entry dates and reload policy as the dedicated widget.
- Timelines per source:
  - prayer: an entry at each prayer time for 48 h, plus midnights;
  - weather: the next 6 forecast hours, reloaded after 30 min;
  - commute: the 16:00 switch and event start/end times, reloaded after 30 min;
  - parking: midnights only (the relative text ticks by itself);
  - map: a single entry.
- App:
  - Car → Parking: save here, edit floor/bay/note, Maps directions, clear.
  - Save Parking App Intent and Siri phrase "Save parking in Peugeot408". SETUP.md §10 has the CarPlay-disconnect automation.
  - Daily → Prayer Times (zone picker, auto zone, today's times, source line), Commute (Home/Work search, switch hour, calendar access), and Weather & Haze (sources, API bands, Apple Weather attribution and legal link).
  - Studio → Data sources → Map Snapshot.
  - Settings → Data: prayer zone, Home and Work, API keys.
  - Returning to the app reloads files (e.g. after the shortcut ran) and tops up prayer and calendar caches.
- Deep links `peugeot408://data/<parking|prayer|commute|weather|map>`.
- Tests:
  - prayer: JAKIM parsing, next prayer across midnight, the calculator within 3 min of JAKIM, gap filling, prayer timeline;
  - zone lookup;
  - commute: switch rules, stale ETA, next event;
  - weather and haze: rain text, API band edges, WAQI parsing;
  - parking and map: map target choice, map index;
  - slots: a slot showing prayer uses the prayer dates;
  - every source gives a valid card with no data.

### Decisions
- Prayer fallback is our own calculator in `CarKit/PrayerTimes` instead of the Adhan library (the spec says "e.g."). This keeps the module dependency-free, and it is tested against JAKIM's tables.
- Commute origin is the phone's location when allowed, otherwise the other saved place.
- The calendar is read directly by the widget when full access is granted; otherwise the app's cached copy is used.
- WAQI reports the US EPA AQI scale; it is coloured with the Malaysian API bands, as the spec asks.
- Map Snapshot's setup lives under Studio → Data sources (spec §5). The other Studio items still name their phase.

### Fixes during the phase
- The first CI runs failed on three things: a sample-data expression too slow to type-check (split up); the Phase 2 storage test comparing the whole `CarData` (it now checks the four Phase 2 stores); and a Swift 6 `sending` error when calling the widget completion handler from a `Task` (now wrapped in `CompletionBox`).
- CI green on run 12: 74 tests in 13 suites. Signing with the WeatherKit entitlement worked without regenerating profiles. Uploaded as **1.1 (12)**.

### Left over / open
- [ ] You: install the new build, allow location (and calendar if you want the next event), set Home and Work, check your prayer zone, save a parking spot, and assign e.g. Prayer Times or Commute to a slot.
- [ ] You: add the `AQI_API_KEY` secret (free WAQI token) so haze shows; until then the card says "add token".
- [ ] You: optional Shortcuts automation "When CarPlay disconnects → Save Parking" (SETUP.md §10).
- [ ] Not verifiable on CI: WeatherKit and WAQI responses, widget location access and map rendering on the device.

## Phase 2 — Service Tracker, Fuel Log, Road Tax & Insurance, Touch 'n Go

### Done
- CarKit `Car/`: `ServiceLog`, `FuelLog`, `RenewalLog`, `TnGState`, each saved as JSON in the App Group (`service.json`, `fuel.json`, `renewals.json`, `tng.json`) through a generic `JSONFileStore`. `CarData` loads all four and builds view-ready summaries (`DataCard`).
- Calculations, all unit-tested (35 tests in total):
  - full-to-full km/L, with partial fills counted toward the next full tank;
  - distance-weighted average over the last 3 segments, last price per litre, RM this month, mod before/after comparison;
  - mileage estimate from the average daily km (180-day window; fill-ups count as odometer readings);
  - service due by km or date, whichever comes first (amber at 1,000 km or 30 days or less, red when overdue);
  - renewal countdowns (amber at 30 days or less, red at 7 days or less or overdue) and reminder dates (30 and 7 days before, at 09:00);
  - TnG "Top up soon" when the balance is below the threshold.
- Widgets: Service Tracker, Fuel Log, Road Tax & Insurance and Touch 'n Go, each `.systemSmall` + `.systemMedium` + Lock Screen `.accessoryRectangular`. Timelines hold entries for now and the next 7 midnights. The card glow turns amber or red with urgency, and each widget has empty states and `#Preview`s with sample data.
- Slots: the slot editor has a "Shows" picker (custom text or any of the four data widgets). Phase 1 `slots.json` still decodes (`source` is optional).
- App: the Car tab (Service, Fuel, Renewals) and Daily tab (Touch 'n Go) have entry screens, each showing a head-unit preview of its card. Service has presets, custom and one-off items, mark done and odometer readings. Fuel has fill-ups (RON95/97, full or partial) and mod tags. Renewals has road tax, insurance, licence, Puspakom and other, plus local reminders. TnG has quick +/- buttons, an exact balance, a threshold and recent changes.
- Each save reloads only the affected kinds: the source's widget plus any slot showing it. Fuel changes also reload Service, because fill-ups move the mileage estimate.
- Deep links `peugeot408://data/<service|fuel|renewals|tng>` open the matching screen.

### Decisions
- JSON files rather than SwiftData (the spec allows "JSON files where simpler"). The widget reads them without a model container.
- Service preset intervals are typical values (e.g. oil 10,000 km / 12 months), editable per item.
- Slot rotation (up to 3 designs per slot) stays in Phase 5, together with the Studio designs.

### Left over / open
- [ ] You: install the new TestFlight build, enter some real data, assign e.g. Service to a slot, and check it in the car. (Not confirmed before Phase 3 started.)
- [ ] Notification permission is asked the first time a renewal is saved.

## Phase 1 — Skeleton + slots

### Done
- `docs/SPEC.md` saved and committed first.
- XcodeGen `project.yml`: targets `Peugeot408` (app), `Peugeot408Widgets` (extension), `CarKit` (static framework), `CarKitTests`. iOS 26, iPhone only, Swift 6 strict concurrency.
- One-place settings in `project.yml`: `APP_DISPLAY_NAME`, `BUNDLE_PREFIX` (`com.namazee88`), `DEVELOPMENT_TEAM` (`YCS7MW628Y`), `APP_GROUP_ID` (`group.$(BUNDLE_PREFIX).peugeot408`).
- CarKit: `Theme` (all colours in one file), `WidgetCard` + `WidgetCardBackground` (full-colour and tinted/clear modes), `AppGroup`, slot model/store/timeline (`slots.json` in the App Group), shared `SlotContentView`/`SlotTile` so app previews match the car.
- Widgets: Car Slot 1–5 (one kind each, small + medium), flash test via timeline entries (flash now → design when it ends), `widgetURL` deep links, `#Preview`s.
- App: tabs Slots / Studio / Car / Daily / Settings (Studio, Car, Daily are placeholders naming their phase). Slots tab: mock CarPlay screen, tap-to-edit simple text design (value, label, icon, background), drag to reorder, "Test: flash all slots" (10 min) with stop. Saves reload only the changed slot kinds. Onboarding (3 pages), How to add to CarPlay, Reload all widgets, App Group diagnostic.
- Tests (Swift Testing): slot normalisation, reorder semantics, changed-slot detection, timeline with/without flash, store round-trip and corrupt-file fallback.
- CI: `ios.yml` (push to main / manual: test job, then match → gym → TestFlight; skips upload with a warning if secrets are missing), `pr.yml` (test only). Xcode 26 on `macos-26`, build number = GitHub run number.
- Original app icon drawn with shapes (`tools/make-icon.ps1`).

### Decisions
- Signing: fastlane match (appstore) + App Store Connect API key. Reason in `SETUP.md` §5 and `fastlane/Fastfile`.
- CarKit is a static framework: nothing to embed or sign separately.
- Spec has a single accent colour in Swift for now; the shared theme JSON for Remotion comes in Phase 8.

### Fixes
- First TestFlight upload was rejected (error 90474, iPad multitasking orientations): XcodeGen's target defaults made the app iPhone + iPad. `TARGETED_DEVICE_FAMILY: "1"` is now set on each target. Signing with match worked on the first try.
- Version and build number were stuck at 1.0 (1): XcodeGen writes its own defaults into the generated Info.plist. Both Info.plists now use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`, so uploads get the marketing version (now 1.1) and the run number (spec: build number from the GitHub run number).
- Car Slot widgets missing from the iPhone widget gallery and CarPlay: the widget extension crashed at launch on iOS 27.2.1 (`_assertionFailure` in WidgetKit while reading the widget body; `_LocalizationInfo` in registers). The cause is the interpolated `configurationDisplayName`/`description` literals, which become `LocalizedStringKey`s. They are now plain `String`s. Found via the device crash log (build 1.1 (6)). Confirmed fixed on the iPhone in 1.1 (7): Car Slot 1–5 show in the widget gallery.

### Left over / open
- [x] Setup done; first upload (went up as 1.0 (1)) on 2026-11-19. Build 5 was 0.1.0; from build 6 the version is 1.1.
- [x] Confirmed in the car on 2026-11-20: Car Slot 1–3 show on the head unit and the flash test works.
- [ ] Onboarding screenshots: deferred to Phase 8 (Remotion onboarding clip), since there are no device screenshots yet.
- [ ] Slot rotation (up to 3 designs per slot) and assigning data widgets/templates: Phases 2 and 5 once those designs exist.
