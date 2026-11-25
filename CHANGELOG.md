# Changelog

Fresh session? Read `docs/SPEC.md`, then this file, then continue from **Current phase**.

## Current phase: 20 (Simpler car screen) — built, waiting for you to try it. Phase 18–19 templates, the Phase 15 store steps (SETUP.md §15) and the Phase 8 car test are still yours.

## Phase 20 — Simpler car screen
### Done
- Drive panel values: Car → Live OBD2 → "Drive panel in the car" picks the four values on the Drive session panel (CarPlay, Lock Screen, Dynamic Island) from all nine. Picking one that's already there swaps them. Panel values are read at least every 2nd poll (fuel every 5th).
- "Start Drive Session" and "Stop Drive Session" Shortcut actions. The connect and disconnect automation guides have an optional step for them, and Live OBD2 has a "Start automatically in the car" row.
- Slots screen: the car-screen mock, Undo setup, Panorama hero and "More options" (slot order and the flash test).
- Slot editor: "Pick what it shows" grid of big live previews of every data widget and Studio design; tap, then Save. Everything else is under "More options".
- Tests: DrivePanelTests.
### Not verified yet
- In the car: changing panel values during a drive; the Start/Stop Drive Session automations, including starting from the background when CarPlay connects; the new Slots screen and editor.

## Version 1.2
- Apple approved version 1.1 (store build 64), so TestFlight no longer accepts 1.1 builds. New builds are 1.2. Nothing is submitted to the App Store until you create a 1.2 version in App Store Connect.

## Fix — OBD2 slow on the car screen
### Done
- During a drive session, the Live OBD2 widget and every slot showing OBD2 are now asked to redraw: every 5 s while DashCraft is open on the iPhone, every 60 s in the background. Before, they were only redrawn when the session started and stopped.
- The Live OBD2 screen explains that the iPhone does the reading and that the Live Activity is the quickest view.
### Not verified yet
- In the car: slots showing OBD2 update every few seconds with DashCraft open on the phone, and about once a minute with the phone locked.

## Phase 19 — One-tap templates
### Done
- **One-tap use:** tapping a template in Studio → Template gallery now asks what to do: **Use on Slot 1–5** (saves it as a design with the chosen data and size and puts it on that slot; a Split or Quad slot's button says it replaces its cards) or **Customise** (the builder, as before). Hero templates offer **Use as Panorama** (saves it, selects it and turns Panorama on; the dialog says it replaces Slots 1–3).
- **Setups:** a new section at the top of the gallery fills all five slots in one tap, after a confirmation: **Daily Driver**, **Night Cruise** (Neon look, Digital Clock), **Road Trip** and **Ramadan** (iftar countdown and Hijri Date designs). Panorama is turned off. **Undo setup** on the Slots tab brings back what was there (kept in `slots.json` as `undoSetup`, optional, so older files load). Setups reuse their designs if you've saved them before instead of adding copies.
- **6 Hero templates:** Highway Lights, Paddy Fields, Rainforest, Monsoon Storm, Pit Lane, Blueprint.
- **8 templates:** Tachometer, Compass, Cassette, Neon Tube, Glow Orb, Postage Stamp (Realistic, any data source), Tear-off Calendar and LCD Watch (Clock & Date), each with its own Small and Medium layout.
- New pieces: a tachometer dial style, compass and glow-orb layers (also in the builder's + menu), and 12 stickers (light trails, paddy terraces, rainforest canopy, lightning bolt, strip lights, tyre stack, dimension lines, cassette tape, neon tube clips, calendar rings, postmark, perforated stamp). All drawn in code (`RoundFourArt.swift`).
- Tests: grouping, the glanceability linter for every source and size, Hero text inside one column, render from JSON, setups fill five slots and undo, design reuse, older slot files.
### Not verified yet
- How the new art looks on the phone and in the car (CI only renders it).

## More OBD2 values
### Done
- Drive sessions also read **speed** (PID 0D), **intake air temp** (0F), **throttle** (11), **engine load** (04) and **fuel level** (2F). Speed is read every poll, throttle and load every 2nd, intake air every 5th, fuel every 10th, so a poll stays quick. Values the car doesn't report show n/a, as before.
- They show under the four big values on Car → Live OBD2 and can be picked in a Split/Quad card's **Value** picker. The Live Activity and the Live OBD2 widget keep the original four.
- Demo mode simulates all nine. Older saved readings still load (the new values start empty).
### Not verified yet
- Which of the new PIDs the 408 answers (fuel level often isn't reported by PSA/Stellantis ECUs).

## Fix — OBD2 readings dropping out; per-card OBD2 value
### Done
- **Dongle timeouts:** every command's timeout now applies to that command only. Before, a late timer from an earlier command (e.g. the 4 s `ATZ` reset) cancelled whatever command was waiting, so the slow first RPM request (while the adapter searches for the car's protocol) often failed: RPM read on one start and not the next. The same went for the 12 s connect timer after a quick reconnect, and for live sessions at a short "Read every". After setup the app now sends `0100` once with a 6 s timeout so the protocol search finishes before the first reading.
- **Value picker:** a Live OBD2 card in a Split or Quad slot has a "Value" picker (RPM, Coolant, Boost, Battery; Boost by default). The card's icon, label, value and gauge follow it, so Slot 2 can show Boost on top and Coolant below.
### Not verified yet
- In the car with the Vgate dongle (needs a new TestFlight build).

## Fix — connect sound "Session activation failed"
### Done
- The CarPlay automation's Play Connect Sound failed every time with "Session activation failed": the shortcut runs DashCraft in the background, and iOS refused to start audio that only ducked others. The audio session now ducks and mixes with others, retries for up to 3 s, then tries once without ducking; a final failure names iOS's audio error code. Same for the disconnect sound.
### Not verified yet
- In the car (needs a new TestFlight build).

## Store listing language
### Done
- App Store Connect: the app record is renamed **DashCraft**, subtitle "Car widgets & dashboard" (done in the browser).
- Store screenshots run in Malaysia time, so the Panorama shot no longer says "Good evening" beside a 4 AM clock, and shot 2 now shows Settings → Appearance with Bold and Neon side by side, as the spec asks, instead of a second Slots screen.
- **Product page header banner:** new Remotion still `StoreHeader` (`npm run header`), 5244×2950 PNG, saved as `fastlane/creative/store-header.png`: the Hero on a head-unit screen in Apple's safe area, real widget tiles floating at the sides, a neon grid floor, no words.
- The English store text moved from `fastlane/metadata/en-US` to `en-GB`, and the framed screenshots render into `en-GB`, to match the record's primary language, English (U.K.). Otherwise the upload would have added a separate US listing and left the UK one empty.

## Fix — Panorama hero blank in the car
### Done
- Slots 1–3 now draw their part of the Hero as the widget's content on black, instead of only as the widget background, which CarPlay can drop (it showed blank on the head unit).
### Not verified yet
- On the head unit.

## Phase 18 — Another round of templates
### Done
- **8 more realistic templates**, each with its own Small and Medium layout: Shift Lights, Polaroid (your My Car photo pinned to cork; Medium adds a sticky note), Sticky Note (Medium: two notes), Dot Matrix (amber LED board), Chalkboard, Thermometer, Battery (green, amber under 30%, red under 15%) and Speed Sign.
- **6 more templates in the other sections:** Flip Clock, Word Clock ("HALF PAST TEN", a timeline entry every five minutes) and Hijri Date (Malay month names, Umm al-Qura calendar, changes at midnight) in Clock & Date; Moon Phase (the real phase, worked out from the date) in Special; Vinyl and Comic Pop in Data.
- **6 more Hero templates:** Garage, Coastal Drive, Rain City, Starting Grid, Mountain Pass and Departure Board.
- **New pieces** (all in the builder too): Shift lights, Thermometer, Battery and Moon phase layers; Cork, Chalkboard and Halftone textures; data fields Time in words, Hijri date and Moon phase; stickers: Instant photo frame, Sticky note, Dot-matrix panel, Speed sign, Letter grid, Vinyl record, Comic burst, Light cone, Palms, Waves, Mountains, Start lights and Chequered strip (`ExtraArt.swift`). Older design files still load.
- `RoundThreeTemplateTests` (groups, no linter warnings in both sizes and three sources, Hero text inside one column, JSON round trip and render, word clock, Hijri and moon). README snapshots add `templates-round3.png`.
### Not verified yet
- How the new templates look on the head unit. The Hijri date is calculated and can be a day off JAKIM's official date.

## Phase 17 — More realistic and Hero templates
### Done
- **8 more realistic templates** in the Realistic section, each with its own Small and Medium layout: Split-Flap (Medium: a two-row departure board), Neon Sign (on brick), Wood Trim (walnut and brass), Car Stereo (amber LCD; Medium adds a radio tuning scale), Navigation (night street map with a route), Rainy Window (city bokeh and raindrops), Parking Ticket (thermal paper; Medium turned on a car-park floor) and Number Plate.
- **6 more Hero templates** for the Panorama across Slots 1–3: Sunset Road, Night City, Cockpit (three dials), Live Sky, Neon Grid and Glass Info (three glass panels). Text stays inside one column so the gaps never cut it.
- **Hero gallery section** (the old Hero moved there from Car), previewed at the panorama shape across the full width; the Panorama hero screen's "Create a Hero design" now offers every Hero template.
- **New pieces** (all in the builder too): a Split-flap layer, Wood and Brick textures, a Rain background, and stickers: Neon tube, Thermal ticket, Plate frame, Radio tuning scale, Street map, LCD panel, City skyline, Neon grid floor and Striped sun (`MoreArt.swift`). Older design files still load.
- `MoreTemplateTests` (groups, no linter warnings in both sizes and three sources, Hero text inside one column, JSON round trip and render, new pieces). README snapshots add `templates-realistic-more.png`, `templates-hero.png` and `carplay-heroes.png`.
### Not verified yet
- How the new templates look on the head unit.

## Phase 16 — Realistic templates
### Done
- **10 realistic templates** in a new **Realistic** section at the top of the template gallery, each with its own Small and Medium layout and bindable to any data source: Chrome Dial (Medium: two dials around a digital readout), Fuel Gauge, Odometer, Highway Sign, Leather Stitch, Digital Cockpit, Head-Up Display, Frosted Glass, Live Sky and Boarding Pass (Small: the stub only).
- **New design pieces** (all in the builder too): a Dial layer (Instrument or Fuel E–F, with ticks, numbers and a needle at the value's progress), an Odometer layer (rolling-counter wheels), segments on the progress bar, a Leather texture, Frosted and Live Sky backgrounds, and stickers: Stitching, Sign frame, Road arrow, HUD horizon, Ticket and Glass panel. All drawn in code (`RealisticArt.swift`). Older design files still load.
- **Live Sky** shows dawn, day, dusk or night from today's Syuruk and Maghrib (7:15 am / 7:20 pm without prayer times), with the sun moving along its arc; the widget timeline has entries at each change and every hour while the sun is up.
- `RealisticTemplateTests` (both sizes: no linter warnings, JSON round trip, render; sky phases and timeline). README snapshots add `templates-realistic-both.png`.
- **Upload fix:** App Store Connect rejected build 53 (error 90626) because the Sync Lyrics intent description said "Apple Music". It now reads "Reads the song playing in Music and updates the DashCraft Lyrics widget." No App Intent text says Apple (spec §1).
### Not verified yet
- How the templates look on the head unit; check the `readme-snapshots` artifact and the gallery.

## Phase 15 — App Store release as DashCraft
### Done
- **Prayer countdown fix (car test):** prayer and iftar countdowns stop at 0:00 when the time arrives instead of counting up ("0:01, 0:02…") while CarPlay waits to show the next timeline entry. New `Text.countdown(to:)` (`Text(timerInterval:countsDown:)`) in widgets, slots, faces and Studio designs; the clock still counts up. `CountdownTests`.
- **Connect sound fix (car test):** "Test sound" worked but the CarPlay automation was silent, because the sound played before the car had switched its audio to the iPhone. The Play Connect Sound shortcut now waits up to 6 s for a car output (CarPlay, Bluetooth or USB) in the audio route, plus about 1 s to settle, then plays (or plays anyway after 6 s). Music isn't ducked while it waits. Test sound and the disconnect sound play straight away as before.
- **GitHub Pages on:** support and privacy pages are live at https://namazee.github.io/Peugeot408/.
- **Name:** the display name, permission prompts, Siri/Shortcuts texts, help texts, onboarding, backups ("DashCraft backup <date>.json") and widget descriptions say **DashCraft**; nothing user-visible says Peugeot, Stellantis or 408. Target, bundle ID, App Group and URL-scheme names are unchanged, so your data and signing carry over. New-install defaults say "MY CAR" (Slot 1, Hero lettering); your saved slots and designs aren't changed.
- **Icon:** the wordmark is now **DASHCRAFT** (Michroma, tighter tracking so nine letters fit on one line); Any, Dark and Tinted re-rendered, plus IconPreview and IconReveal. The onboarding setup clip says "My Car" instead of "My 408".
- **Build flavours:** `FLAVOUR_CONDITION` in `project.yml`; the iOS workflow has a `flavour` input (personal / store). The store build compiles with `STORE_BUILD`: no LRCLIB client, Lyrics widget, Lyrics Live Activity, Sync Lyrics intent or lyrics screen, and Lyrics isn't offered in pickers (an old Lyrics slot shows Music). Store builds wait for processing and get the TestFlight note "Store build". CI also compiles the store flavour on every push.
- **Sample data:** Settings → Sample data, and "Try it with sample data" on the last onboarding page. The app and all widgets then show `SampleData`, with a "Sample data" badge; your files aren't touched. `SampleModeTests`.
- **Privacy:** `PrivacyInfo.xcprivacy` for the app (UserDefaults, reason CA92.1) and the widgets; no tracking, nothing collected.
- **Web pages:** `site/index.html` (support) and `site/privacy.html`, published by the manual `pages.yml` workflow once you turn Pages on.
- **Listing:** `fastlane/metadata` in English and Malay (name, subtitle, description, keywords, promotional text, release notes, URLs, review notes, categories). Lane `store_metadata` uploads text and screenshots only.
- **Screenshots:** `DashCraftUITests/StoreScreenshots` (scheme `StoreScreenshots`) shoots six screens on a 6.9-inch simulator with Sample data on (`ScreenshotMode` launch flags); Remotion `StoreScreenshot` frames them with English and Malay headlines (`npm run store`). Manual workflow `store.yml`.
### Not verified yet
- The screenshots, the store build and the listing upload only run when you trigger them (SETUP.md §15); check the `store-screenshots` artifact before uploading.

## Phase 14 — Panorama hero
### Done
- **One picture across Slots 1–3.** There's a new **Panorama** canvas (3 columns + 2 gaps, about 2.25:1). Each of Slots 1–3 draws its third (`PanoramaSlice`, `SlotContent.panorama`), skipping the gaps between the 408's columns, so the three columns read as one picture.
- **Slots → Panorama hero:**
  - a live 3-column preview;
  - an on/off switch that asks first ("replaces what Slots 1–3 show until you turn it off");
  - a design picker with an edit button;
  - **Create a Hero design**.
  - Slots 1–3 keep their own designs underneath, so turning it off brings them back. The Slots mock and the slot editor show when the panorama is on. Slots 4–5 aren't affected.
- **Hero template:**
  - your My Car photo in the middle, with big "408 GT" lettering behind it (change the text in the builder);
  - a greeting top left and the clock top right;
  - temperature and "place · condition" bottom left;
  - your plate bottom right.
  - No logos.
- **New data fields:**
  - **Greeting:** "Good morning, …" / "Selamat pagi, …", which changes at 5:00, 12:00, 15:00 and 18:00/19:00 (timeline entries at those hours). The name and language are set on the Panorama screen.
  - **Weather place · condition.**
- **Builder:** the Panorama canvas is available, with the cut lines between columns shown as shaded gaps. The template gallery and My Car stay on Small/Medium; Hero is in the gallery's Car section, previewed at its real width.
- A flash test still takes over Slots 1–3. The backup includes the panorama settings (slots and studio files).
- CI run 46: all 173 tests passed and fastlane uploaded **1.1 (46)** to TestFlight. Only the extra "keep a copy of the IPA" step failed, because GitHub's artifact storage timed out. That step is now `continue-on-error`.
- The Hero greeting is narrowed to stay inside Slot 1 (it touched the first gap in the render).
- Tests: `PanoramaTests` (geometry, slots 1–3 vs 4, sources, designs kept, greeting by hour, older files). The README snapshots add `carplay-panorama.png`.


## Change after Phase 13 — single-slot extras (spec updated first)
- **Centre picture** for any Single slot showing data (Service, Prayer, Fuel and so on; not Map, Photos or Music, which are pictures already).
  - Pick your My Car photo, a built-in photo or an upload in the slot editor's new "Centre picture" row.
  - The tile then shows the label on top, the car whole in the middle, and the big value at the bottom. On medium widgets the car sits on the left.
  - It's drawn by a new `SlotContent.pictured` case.
- **Custom text:**
  - **Align** Left / Centre / Right.
  - **Big value size** and **Label size** sliders (70–150%). Text still shrinks to fit, so nothing is cut off.
- New `SlotDesign` fields are optional, so older files still load.

## Phase 13 — Synced lyrics
### Done
- **New data source "Lyrics":**
  - a Lyrics widget (small, medium and Lock Screen);
  - a Lyrics card for any slot or Split/Quad card;
  - a Lyrics Live Activity.
- **Display:**
  - The active line is big and bright: white in Bold, glowing pink in Neon, or your own colour.
  - The previous line is faded and the next one(s) are dimmer.
  - Choose 1, 3 or 5 lines, and text size small, normal or large.
  - Without synced lyrics it shows the song and why ("No synced lyrics", "Instrumental", "No lyrics found").
- **How it syncs (`LyricsSync`):**
  - The app reads the Apple Music system player: song, artist, album, length, position, playing or paused.
  - It saves when the song started, then fetches time-coded lyrics from **LRCLIB**, trying an exact match and then a search, with no key. Lyrics are cached in `lyrics.json` for your last 30 songs.
  - The widget timeline has **one entry per line** until the song ends, so lines change without the app running.
  - It re-syncs when the app opens, while it's open (song and play/pause changes), after the widget's Next button, and from the new **Sync Lyrics** shortcut action. That action is meant for a "CarPlay connects" automation; see SETUP.md §14.
- **LRC parser:** handles several time tags on one line, `[mm:ss:xx]` stamps, `[offset:]`, and empty lines (instrumental gaps).
- **Live Activity:** turned on in the Lyrics screen. It changes lines only while the app is running, because iOS doesn't let Live Activities change text on their own.
- **Translations:** LRCLIB has none, so there's no translation line; the spec only asks for one when the source provides it.
- **Spotify** isn't supported. The app and SETUP.md say why.
- CI: green first time on run 44 (168 tests); **1.1 (44)** is in TestFlight.
- Tests: `LyricsTests` (parser, windows, timeline dates, summary modes, cache limit, LRCLIB mapping).


## Phase 12 — Sound packs
### Done
- **8 packs, 47 bundled sounds plus 9 voice cues.** Studio → Connect sounds now opens a pack list: Engine starts, EV whoosh, Luxury, Retro arcade, Minimal pings, Sci-fi, Voice cues and Classic. Each pack lists its sounds with ▶ previews.
- **Engine starts:** 12 real recordings.
  - V8: big-block, '74 Corvette, '85 Mustang, Ferrari 360, Maserati sport mode.
  - Lamborghini start-up, BMW M6 V10, Porsche 911 flat-six, Subaru WRX boxer, a supercar rev, an EV start, and a hatchback start.
  - Each was checked on its own page as CC0 (Freesound) or public domain (Wikimedia Commons), then cut by `tools/process-engine-sounds.py` to at most 5 s from when the engine fires.
  - Sources are in `tools/engine-sounds.json` and `ASSETS-LICENSES.md`.
  - The Commons Rover V8 was left out (Wikimedia kept rate-limiting the download).
- **Synthesised packs** (`tools/make-sounds.py`, original, no samples):
  - 4 EV, 6 Luxury, 8 Arcade, 5 Pings and 6 Sci-fi;
  - the 6 Classic sounds regenerated.
  - Encoded as AAC (.m4a, 2.2 MB for everything).
- **Same loudness everywhere:** every bundled sound sits at about -17 dBFS RMS with peaks limited. Imported clips are brought to the same level after trimming (`SoundNormalizer`).
- **Voice cues:**
  - "Welcome back", "Drive safe", "CarPlay connected", "Let's go", "Seatbelt on. Let's roll", "Have a good journey", "Taking you home", "See you soon", and a time-of-day greeting.
  - English or Malay, with your name added when set.
  - A **Voice** picker lists the iPhone voices, with enhanced voices first.
- **Separate disconnect sound:** a Connect / Disconnect switch at the top chooses what a tapped sound is for. There's a new **Play Disconnect Sound** shortcut action; the disconnect automation guide now uses it before Save Parking. The default is Goodbye.
- Older `connect-sound.json` files still load: the new fields are optional.
- CI: green first time on run 43 (161 tests); **1.1 (43)** is in TestFlight.
- Tests: packs, unique ids, voice cue text in both languages (including the evening greeting), disconnect fallback, entity ids for voice cues.


## Change after Phase 11 — any background colour for text slots (spec updated first)
- Text slot designs have a third background option, **Colour**: 12 swatches (the 408's five paint colours first, then vivid ones) plus a full colour picker. Custom text cards in Split/Quad slots get an **Own colour** toggle with the same picker.
- Bold look: the tile is that colour, with the usual sheen and texture. Light colours such as Okenite White switch to dark text. Neon look: the colour becomes the glow on black.
- "Dark" is now a true near-black tile in both looks (before, in Bold it showed blue).
- `SlotDesign.backgroundHex` is optional, so older files still load.

## Phase 11 — Widget styles and new templates
### Done
- **Two looks:** Bold and Neon (spec §3), for every data widget, split/quad card, text slot and app preview.
  - **Bold:** a full-colour gradient tile per source, with a sheen and a fine dot texture. The colour turns amber or red when something is due, or the AQI band colour for haze. One huge centred number, a caps label and a progress bar.
  - **Neon:** near-black with a pool of glow colour, and a glowing ring (what's left) or a 240° gauge (fuel against your best tank, boost) around a glowing number. Split cards get a glowing outline.
  - Medium widgets add a list on the right (service items, today's prayers, fuel figures and so on).
  - Every data card is drawn from one `CardFace` model by `FaceView`; map, photos and music keep their image layouts.
- **Palettes** in `theme/tokens.json` (`bold` and `neon` per source). `gen-theme.py` now writes them into `ThemeTokens`.
- **Settings → Appearance:** choose Bold or Neon, with previews of your own data. It's saved in the App Group (`appearance.json`) and reloads every widget.
  - Each Car Slot editor has a **Look** picker (App / Bold / Neon), and the Slots mock shows each slot in its own look.
  - The app tint follows the look (Neon is cyan).
  - The backup includes appearance.
- **12 new Studio templates:** Bold Tile, Neon Ring, Twin Gauges, Aurora, Sunset Drive, Night Drive, Showroom, Racing Stripes, Starry Night, Big Date, Year Progress and Retro LED.
  - The gallery is grouped into Data, Car, Clock & Date and Special, with a NEW badge on the new ones.
- **Design model additions** (all optional, so saved designs still load):
  - backgrounds: aurora, spotlight, and a state colour that follows the first data field;
  - progress ring and progress bar layers;
  - a neon glow toggle on any layer;
  - weekday, day, month and year-progress fields;
  - sun, road and starfield stickers.
  - The builder has all of these too.
- **How to add to CarPlay:** a Google Maps ETA tip (add Google's own widget to a slot's stack). Also in SETUP.md step 9.6.
- Fixes after reviewing the CI renders:
  - Racing Stripes used the Merdeka flag artwork; it now has plain white racing stripes.
  - Twin Gauges' values sit inside the gauges, with the label underneath.
  - Split/Quad slots sit on a neutral near-black frame, so the coloured cards stand out.
- CI: green on run 40. The builder needed the new ring and bar layers in its sizing switch.
- Sample data now has an OBD reading, so the OBD widget's preview shows a gauge.
- Tests: `LooksTests` (palettes, faces, the new templates pass the glanceability checks, calendar fields, JSON round trip). README snapshots now render both looks and the template gallery.


## Phase 10 — Polish
### Done
- **Rendering modes:** tinted and clear (Liquid Glass) CarPlay drops the amber and red. So data widgets and split/quad cards that are due soon or overdue now also show a warning glyph (triangle or octagon) in the top corner, marked `widgetAccentable`. Full-colour mode is unchanged.
- **Accessibility:**
  - Each split/quad card is read as one sentence: label, value and "due soon" / "overdue". Timers are read as "in 1 hour, 12 minutes". Symbol names are no longer read out.
  - Data widgets add "due soon" / "overdue" to their label.
  - Picture slots with no text are read as "Car slot 1: my car picture" instead of an empty label.
- **Empty states:** every widget already shows a hint when it has no data ("Add a fill-up", "Set Home and Work" and so on). Removed the leftover "arrives in Phase 9" note in Settings and the unused "coming soon" screen.
- **JSON backup** (Settings → Backup):
  - Export writes one readable JSON file (`Peugeot408 backup <date>.json`) for the share sheet. It holds service, fuel, renewals, TnG, parking, Home/Work, prayer zone, slots, Studio, connect sound and OBD2.
  - Restore asks first and checks every file against its type before writing. A damaged backup changes nothing, and a newer format is refused.
  - After a restore the app reloads its data and all widgets.
  - Caches, photos, pictures and imported sounds are not included.
  - Covered by `BackupTests`.
- **README** now has:
  - widget and head-unit snapshots, rendered by CI from the real SwiftUI views (`ReadmeSnapshots`, artifact `readme-snapshots`);
  - frames from the Remotion videos (`docs/images/`);
  - the feature list, backup notes and the repo layout.
- CI: green on run 37 (**1.1 (37)** in TestFlight). The snapshot test rendered all 11 images; they're committed in `docs/images/`.
- SETUP.md section numbers fixed (Phase 4 and Phase 6 were out of order, and two sections were both numbered 12).


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
