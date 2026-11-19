# Changelog

Fresh session? Read `docs/SPEC.md`, then this file, then continue from **Current phase**.

## Current phase: 1 — Skeleton + slots (code done, waiting on setup + device check)

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
- Version and build number were stuck at 1.0 (1): XcodeGen writes its own defaults into the generated Info.plist. Both Info.plists now use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`, so uploads get 0.1.0 and the run number (spec: build number from the GitHub run number).
- Open: on device, Car Slot widgets don't appear in the iPhone widget gallery or in CarPlay. The IPA checks out: the extension is embedded, signed and has the App Group, and the binary contains CarSlot1–5. Waiting on a restart test and the iPhone's Analytics Data crash logs for `Peugeot408Widgets`.

### Left over / open
- [x] Setup done; build 4 (0.1.0) uploaded to TestFlight on 2026-11-19.
- [ ] You: install via TestFlight, add Car Slot 1–5 in CarPlay, confirm a slot change shows on the head unit.
- [ ] Onboarding screenshots: deferred to Phase 8 (Remotion onboarding clip), since there are no device screenshots yet.
- [ ] Slot rotation (up to 3 designs per slot) and assigning data widgets/templates: Phases 2 and 5 once those designs exist.
