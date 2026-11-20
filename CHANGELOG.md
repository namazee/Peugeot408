# Changelog

Fresh session? Read `docs/SPEC.md`, then this file, then continue from **Current phase**.

## Current phase: 4 — done, waiting for "Continue with Phase 5"

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
