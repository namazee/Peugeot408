# Changelog

Fresh session? Read `docs/SPEC.md`, then this file, then continue from **Current phase**.

## Current phase: 2 — done, waiting for "Continue with Phase 3"

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
- [ ] You: install the new TestFlight build, enter some real data, assign e.g. Service to a slot, and check it in the car.
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
