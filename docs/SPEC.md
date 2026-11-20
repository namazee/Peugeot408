# Build "Peugeot408" — iOS 26 CarPlay widget app (no Mac, cloud builds)

You are building a personal iOS app called Peugeot408 for my 2025 Peugeot 408 GT (1.6T PureTech, Malaysia). Its main purpose is a set of WidgetKit widgets that show on the CarPlay widget screen (iOS 26+ shows any iPhone widget in CarPlay, no CarPlay entitlement needed). The app itself is the place where I enter data and change settings; the widgets display it.

App name everywhere (display name, Xcode target, scheme, home-screen label): Peugeot408. This is a personal app distributed only to me through TestFlight internal testing; it is not affiliated with Peugeot/Stellantis. Do not use Peugeot logos or the lion emblem anywhere — use my own car photo and original artwork only. Keep the display name in one setting (`PRODUCT_NAME`/`CFBundleDisplayName` in `project.yml`) so I can rename it later.

I do not own a Mac. Everything must build, sign and upload to TestFlight through GitHub Actions on a macOS runner. Never assume I can open Xcode. Generate the Xcode project from a spec file (XcodeGen), and keep every manual step I must do (Apple Developer portal, App Store Connect, GitHub secrets) in a checklist in `SETUP.md`.

## 0. How we work (read this first, every session)

* This file is the spec. On the very first run, save this entire prompt as `docs/SPEC.md` and commit it before writing any code. From then on, `docs/SPEC.md` is the single source of truth for what the app should be.
* Every new session starts the same way: read `docs/SPEC.md` and `CHANGELOG.md`, work out which phase we're on, and continue from there. Don't ask me to paste the prompt again.
* Changes go into the spec first. When I ask for anything new or different later (a new widget, a different colour, a changed behaviour), you must:
   1. Update `docs/SPEC.md` with the change (in the right section, and in the phase list if it adds work), and show me the diff.
   2. Commit the spec change on its own (`spec: …`).
   3. Only then build it, and record it in `CHANGELOG.md`. Never implement something that isn't in the spec. If code and spec disagree, the spec wins; ask me if it's unclear.
* One phase at a time. Build only the current phase. At the end of each phase, stop and wait for me to say "Continue with Phase N". Don't start the next phase on your own.
* Keep `CHANGELOG.md` up to date with which phase is done and anything left over, so a fresh session can pick up where the last one stopped.

Work in phases (below). At the end of each phase: commit, push, make sure the CI build is green, and give me a short summary plus anything I need to do by hand. Ask me before anything that costs money or can't be undone.

## 1. Tech stack and project structure

* Swift 6, SwiftUI, WidgetKit, ActivityKit, App Intents, SwiftData, CoreBluetooth, CoreLocation, MapKit, EventKit, WeatherKit, PhotosUI, MusicKit
* Deployment target: iOS 26.0; iPhone only
* XcodeGen (`project.yml`) generates the `.xcodeproj` on CI. Do not commit the `.xcodeproj`.
* Targets:
   * `Peugeot408`: main app
   * `Peugeot408Widgets`: widget extension (all widgets + the Live Activity UI)
   * `CarKit`: shared Swift package/framework (models, storage, services, formatting, theme) used by both
   * `CarKitTests`: unit tests
* App Group `group.<bundle-prefix>.peugeot408` shared by app and extension. All widget data lives in a SwiftData store (or JSON files where simpler) in the App Group container.
* Bundle ID prefix: ask me once at the start, then put it in one place (`project.yml` settings) so it's easy to change.
* After any data change in the app, call `WidgetCenter.shared.reloadTimelines(ofKind:)` for the affected widget only.

## 2. CarPlay widget rules (follow these strictly)

* CarPlay shows widgets in stacks on a dedicated screen. Support `.systemSmall` for every widget (this is what CarPlay uses). Also support `.systemMedium` and the Lock Screen accessory families where they make sense, for use on the iPhone itself.
* Treat the CarPlay display as glanceable while driving: one or two big values per widget, short labels, high contrast, no paragraphs, no small print, no scrolling.
* Taps on third-party widgets may do nothing in CarPlay. Design every widget to be fully useful read-only. Add `widgetURL`/`Link` deep links into the app as a bonus for when it's used on the iPhone.
* Use `containerBackground(for: .widget)` and make sure each widget looks right in both the default and the tinted/clear (Liquid Glass) rendering modes. Use `widgetAccentable()` on key values and check with `@Environment(\.widgetRenderingMode)`.
* Remember the widget extension memory limit (~30 MB). Downsample all images to the widget's pixel size before saving them to the App Group.
* Widgets refresh on a budget. Build sensible timelines (pre-computed future entries for countdowns, `Text(date, style: .timer/.relative)` for live-ticking text) instead of relying on frequent reloads.

## 3. Visual design

* Dark-first look for the car: near-black background, Peugeot "Obsession Blue"-style accent (a deep, saturated blue, roughly `#1F4FD8`; put it in one theme file so I can tune it), white primary text, muted grey secondary text, amber for "due soon", red for "overdue".
* SF Pro Rounded for numbers, SF Symbols for icons. Big monospaced digits for countdowns.
* Build a shared `WidgetCard` style in `CarKit` so all widgets look like one family.
* Every widget gets an Xcode `#Preview` with sample data (useful later even though I can't run previews now), and the same sample data powers the placeholder and snapshot states.

### App icon

* Source art: my own icon artwork (generated from a photo of my car), stored in `remotion/assets/icon/` as `icon-default.jpg` (plus `icon-dark.jpg` and `icon-tinted.jpg` if I provide them). This is the master art: don't redraw the car. No logos; the only text is the "GTCP" wordmark (layer 5).
* Remotion composition `AppIcon` (1024×1024), prop `variant: "default" | "dark" | "tinted"`, built in layers:
   1. Background `#05070D` with a soft radial blue glow (`#1F4FD8` at ~25% opacity) behind the car.
   2. The source image, scaled/cropped so the headlights, light strips and grille sit inside the central 80% safe area.
   3. Glow boost: duplicate the brightest areas (luminance threshold), blur, tint `#7FD4FF`, screen-blend at ~40%, so the lights pop at small sizes.
   4. A subtle vignette and a faint Liquid Glass highlight along the top edge.
   5. Wordmark "GTCP" centred below the car, inside the safe area: wide-tracked, wide sans-serif (open-licence font, recorded in `ASSETS-LICENSES.md`), white with a soft `#7FD4FF` glow (white glow on tinted), sized to be readable at 180 and 120 px. The car moves up slightly to make room; the lights stay inside the safe area. In `IconReveal` the wordmark fades in as the icon settles.
   * If the dark/tinted source images aren't provided, generate them: dark = pure-black background and the car at −15% brightness, lights unchanged; tinted = grayscale with strong contrast, lights brightest.
* `IconPreview` (1920×1080): each variant at 1024, 180, 120, 60 and 40 px on a mock iPhone home screen (light and dark wallpaper) and on a CarPlay-style dark dashboard mock, to judge it at real sizes.
* `IconReveal` (3.5 s; 1080×1080 and 1080×1920): starts black, the light strips draw on top to bottom, the headlights flash on with a bloom, a glow sweeps across, then it settles on the final icon. Used on the app's first-run screen and for sharing.
* `npm run icon` (in `/remotion`) renders `AppIcon-1024.png`, `AppIcon-1024-dark.png`, `AppIcon-1024-tinted.png` (`npx remotion still`), `IconPreview.png` and the `IconReveal` MP4s into `/remotion/out`, and copies the three PNGs into the app's `Assets.xcassets/AppIcon.appiconset/` with a `Contents.json` for a single 1024 iOS icon with Any, Dark and Tinted appearances.
* The default PNG must have no alpha channel: a check script fails the build if it has one.
* The icon render runs in the Remotion GitHub Actions job, which uploads the outputs as artifacts.
* `SETUP.md` notes that a full Icon Composer `.icon` file needs a Mac; these PNG appearances are the no-Mac route and work on iOS 26.

## 4. The widgets

For each widget: an app screen to enter or configure the data, a timeline provider, `.systemSmall` CarPlay layout first, plus empty/placeholder and error states.

### Car and driving

1. Service Tracker
   * App: log odometer readings; define service items with an interval in km and/or months (presets: engine oil & filter, tyre rotation, brake pads check, wheel alignment check, air filter, spark plugs, battery check). Allow a one-off item such as "alignment check after rim swap".
   * Estimate current mileage between readings from the average daily km.
   * Widget: the most urgent item, e.g. "Oil service · 1,240 km / 23 days", coloured by urgency. The medium size shows the top 3.
2. Fuel Log
   * App: add fill-ups (date, odometer, litres, RM total, RON95/RON97, full tank yes/no). Compute km/L with the full-to-full method. Allow tagging a "mod" event (e.g. exhaust change) so I can compare consumption before and after.
   * Widget: last price per litre, average km/L (last 3 fills), RM spent this month.
3. Road Tax & Insurance
   * App: expiry dates for road tax (LKM), insurance, and optional extras (driving licence, Puspakom, etc.).
   * Widget: the nearest renewal with a days-left countdown; amber at ≤30 days, red at ≤7 days or overdue. Also schedule a local notification 30 and 7 days before.
4. Parking
   * App and App Intent/Shortcut: "Save parking" stores GPS location, time, and optional floor/bay/note (e.g. "IOI City Mall, B2, pillar C14"). Also offer an option to auto-save when the iPhone disconnects from CarPlay, if feasible; otherwise document a Shortcuts automation for it in `SETUP.md`.
   * Widget: location name, floor/bay, "parked 2h 14m ago" (live relative time).
5. Live OBD2 (Live Activity): build this last.
   * CoreBluetooth client for a BLE ELM327-type OBD2 dongle (e.g. Vgate iCar Pro BLE / OBDLink CX). Make the BLE service/characteristic UUIDs configurable and add a dongle scan screen.
   * Read: coolant temp (PID 0x05), intake manifold pressure (0x0B) minus barometric pressure (0x33) = boost in bar, battery voltage (`ATRV`), RPM (0x0C). Poll at a modest rate and handle unsupported PIDs gracefully (PSA/Stellantis ECUs may not report every PID).
   * Show the values in an ActivityKit Live Activity (which CarPlay displays) while a "Drive session" is running. Also write the latest values to the App Group so a normal widget can show the last-known values with a timestamp.
   * Add a demo mode with simulated values so the Live Activity can be tested without a dongle.

### Daily life

6. Prayer Times
   * Primary source: JAKIM e-Solat API, zone SGR01 by default (covers Sepang/Cyberjaya), with a zone picker and an "auto from location" option. Endpoint pattern: `https://www.e-solat.gov.my/index.php?r=esolatApi/TakwimSolat&period=month&zone=SGR01`. Verify the current response format before coding against it.
   * Fallback: offline calculation (e.g. the Adhan Swift library) using JAKIM-style parameters, in case the API is down.
   * Cache a month ahead in the App Group. Widget: next prayer name, time, and a live countdown. Medium size shows all 5 times for today.
   * Keep this module self-contained in `CarKit/PrayerTimes`. I'll reuse it in another app later.
7. Commute
   * App: save Home and Work (APU, Bukit Jalil) locations.
   * Widget: ETA and travel time to whichever is relevant (to Work in the morning, Home after 4pm, configurable) using MapKit `MKDirections`, plus my next calendar event (EventKit: read in the app and cache in the App Group if extension access is a problem).
8. Weather & Haze
   * WeatherKit (add the capability and include the attribution Apple requires): current temp, rain in the next hour or the next rainy hour today.
   * Air quality: use an API that covers Malaysia (e.g. WAQI/aqicn.org with a free token, or OpenWeather Air Pollution). Make the provider swappable, store the API key safely (not hard-coded in git), and show the API value colour-coded (Malaysian API bands: Good / Moderate / Unhealthy / Very Unhealthy / Hazardous).
9. Touch 'n Go Reminder
   * No API exists, so this is manual: I enter my balance after top-ups and tolls (quick +/- buttons), and set a low-balance threshold.
   * Widget: balance and "Top up soon" when below the threshold.

### Map, Music and Photos (widget versions; no live navigation or audio)

CarPlay widgets can't play audio or run navigation (those need Apple CarPlay entitlements), so build display-only versions:

10. Map Snapshot: `MKMapSnapshotter` image rendered in the timeline provider. Show the parked-car location when a parking spot is saved, otherwise the route/area to the next commute destination. Dark map style, with a pin in the accent colour.
11. Music: an Apple Music card via MusicKit (ask for authorisation in the app): a featured playlist or recently played item with artwork and title. Add interactive App Intent buttons (play/pause/next for the system music player) only if they work; it must still look complete without them. Note in `SETUP.md` that Spotify's now-playing info isn't available to third-party widgets.
12. Photo Frame: pick photos in the app (PhotosPicker, e.g. family photos), downsample them into the App Group, and have the widget rotate through them every 30–60 minutes using timeline entries. Allow a configurable album/selection via an App Intent widget configuration.

## 4b. Customisation studio (design it in the app → the head unit updates by itself)

Goal: I set things up once in the app, and my car's CarPlay screen reflects it automatically. I should never have to dig back into iPhone Settings → CarPlay → Widgets after the first setup.

### The "slot" system (the core of this)

* Provide 5 generic widgets named "Car Slot 1" to "Car Slot 5" (one widget kind each, `.systemSmall` + `.systemMedium`). I add them to my CarPlay widget stacks once.
* In the app, a Slots screen lets me assign any design to any slot: one of the data widgets from section 4 (service, fuel, prayer…), a template, or a custom design from the builder. I can reorder slots by dragging.
* Assignments live in the App Group. Saving a slot calls `WidgetCenter.shared.reloadTimelines(ofKind:)` for that slot, so the head unit changes within seconds the next time CarPlay draws it.
* Each slot can optionally rotate between up to 3 assigned designs on a schedule (e.g. prayer times at dawn and dusk, service tracker otherwise) or by time-of-day rules. Use timeline entries for this, not reloads.
* Keep the dedicated widgets from section 4 too, for people who'd rather add them individually. The slots are the main path.
* First-run onboarding walks me through the one-time step (add Car Slot 1–5 in Settings → General → CarPlay → [car] → Widgets, 5 per stack) with screenshots, plus a "Test: flash all slots" button that pushes an identifying design ("Slot 3 ✓") to each slot so I can check which is which in the car.

### Templates (ready-made styles)

* A template gallery with live previews using my real data. Styles: Sporty (carbon texture, red/blue accents, gauge-like arcs), Minimal (big number, thin label), Premium (dark glass, fine serif accents), Dashboard (multi-value grid), Photo (full-bleed image with a caption), Clock (analogue and digital variants), Countdown, and Anniversary ("Married 9 years, 213 days" / days until an event).
* Every template can be bound to any data source (e.g. Sporty + Fuel Log, Minimal + Prayer Times).
* Seasonal packs for Malaysia that the app can switch to automatically on the right dates: Hari Raya Aidilfitri, Ramadan (with an iftar countdown using the prayer module's Maghrib time), Aidiladha, Merdeka/Malaysia Day, Chinese New Year, Deepavali, Christmas, New Year. All original artwork, drawn in SwiftUI shapes/SF Symbols or as bundled assets generated in Remotion; nothing copied from other apps.

### Custom builder

* A layer-based editor (a canvas in the exact aspect ratio of the CarPlay small and medium widgets, with a safe-area overlay): background (solid, gradient, photo, texture), car photo, text, SF Symbols icons, stickers (a bundled set of original stickers), and data fields (any value from section 4: next prayer, km to service, km/L, TnG balance, days to road tax, parking time, etc.).
* Per layer: position, size, rotation, opacity, font (system fonts plus a few bundled open-licence fonts), colour, shadow. Snap-to-grid, undo/redo, duplicate, lock.
* Store designs as a versioned Codable JSON model in the App Group. The widget extension renders that JSON with SwiftUI, so builder previews and the car look identical. Write snapshot/unit tests that render each template from JSON.
* Enforce glanceability: warn when text is too small for CarPlay or the contrast is too low (WCAG contrast check), and limit each design to 2 data fields in `.systemSmall`.
* Export/import designs as files (share sheet) so I can back them up or share them.

### My car as the hero image

* Pick a photo of my 408 GT, then use one-tap background removal with Apple's Vision framework (`VNGenerateForegroundInstanceMaskRequest`, fully on-device). Allow manual touch-up (erase/restore brush), then save it as a transparent PNG downsampled for widget size.
* Built-in default photos: a few photos of my 408 that I supplied (already cut out, transparent background), bundled with the app so My Car works before I pick my own. The lion badges are pixelated on them, so no Peugeot emblem shows. I can pick one of these in My Car, and choosing my own photo (above) still works and replaces it. The side view is used until I choose.
* A ready-made "My Car" template: the cut-out car over a gradient in Obsession Blue, with a chosen data line underneath (e.g. "Oil service in 1,240 km"), plus an optional number-plate-style label (text I type in).

### Connect sound (plays when CarPlay connects)

* iOS doesn't let an app play a sound automatically when CarPlay connects, so implement it the supported way:
   * An App Intent "Play Connect Sound" (with the sound selection as a parameter) that plays through the current audio route (so it comes out of the car speakers), at a set volume, with ducking.
   * The app guides me step by step to create a Shortcuts personal automation: "When CarPlay connects → Play Connect Sound", set to run immediately without asking. Provide a screen with the exact steps and screenshots, and a "Test sound" button.
* A bundled library of original sounds (generate them yourself or use clearly licensed free sounds and record the licence in `ASSETS-LICENSES.md`): clean chimes, a soft "welcome" tone, sporty engine-style revs, and a spoken "Welcome back" made with on-device `AVSpeechSynthesizer` in English or Malay with my name.
* Let me import my own audio file (trim to ≤5 seconds in-app).
* Optional matching "disconnect" automation that also triggers Save Parking (ties into the Parking widget).

### Sync behaviour

* Any edit in the builder, templates, slots or data shows on the CarPlay head unit without opening Settings: it all goes through the App Group plus `reloadTimelines`. Document in the app that CarPlay may take a moment to redraw, and that the car screen redraws faster after reconnecting.
* Also mirror the slots as iPhone Home Screen/StandBy widgets for free (the same widget kinds work there).

## 5. The app (iPhone)

* Tab layout: Slots (what's on my head unit right now, as a mock CarPlay screen showing all 5 slots with live data; tap a slot to change it), Studio (templates, custom builder, seasonal packs, my car photo, connect sounds), Car (service, fuel, renewals, parking, OBD2), Daily (prayer, commute, weather, TnG), Settings (Map, Music and Photos setup live under Studio → Data sources).
* Settings: units, theme accent colour, prayer zone, home/work locations, API keys, OBD2 dongle, data export/import as JSON (for backup), "Reload all widgets" button.
* A "How to add to CarPlay" screen: Settings → General → CarPlay → [car] → Widgets, up to 5 widgets per stack, Smart Rotate on/off.
* Accessibility: Dynamic Type in the app and VoiceOver labels on widgets.

## 6. CI/CD: GitHub Actions → TestFlight (no Mac)

* Workflow `ios.yml` on a macOS runner with Xcode 26 selected (pick the runner image that has it; fail with a clear message if not).
* Steps: install XcodeGen → generate the project → resolve packages → run `CarKitTests` on an iOS simulator → archive → export IPA → upload to TestFlight.
* Signing without a Mac: use App Store Connect API key authentication with `xcodebuild -allowProvisioningUpdates` (or fastlane `match` with a private certs repo). Choose one, explain why, and document it.
* Secrets to document in `SETUP.md`: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (base64), `TEAM_ID`, plus any API keys (air quality).
* Auto-increment the build number from the GitHub run number.
* Separate workflow (or job) that only builds and tests on pull requests, without uploading.
* `SETUP.md` must list in order: Apple Developer Program enrolment, creating the App ID(s) with App Groups, WeatherKit, and the other capabilities, creating the app record in App Store Connect, creating the API key, adding GitHub secrets, installing TestFlight on my iPhone, and adding the widgets to CarPlay.

## 7. Remotion (design and marketing assets)

Widgets themselves are static SwiftUI, so use Remotion only for the animated assets around the app, in a separate `/remotion` folder (TypeScript, React):

* Widget showcase video: a CarPlay-style dashboard (wide screen, ~1920×720) where each widget animates in and its values tick (service countdown, prayer countdown, boost gauge rising, photo frame crossfade). Use the same colours, typography and sample data as the Swift theme (export the theme tokens to a shared JSON file that both Swift and Remotion read).
* App Store/TestFlight preview video (iPhone portrait, 886×1920 or the current required size) walking through logging a fill-up and seeing the widget update.
* Onboarding animation clips rendered to MP4 for the app's first-run screens (played with AVPlayer).
* Add a GitHub Actions job that renders the Remotion videos and uploads them as build artifacts.

## 8. Phases

1. Skeleton + slots: XcodeGen project, three targets, App Group, theme, `WidgetCard`, Car Slot 1–5 widgets with a simple text design I can change from the app, and the "flash all slots" test. Get CI green and upload the first TestFlight build. Stop and let me install it, add the slots in CarPlay, and confirm that changing a slot in the app updates the head unit before continuing.
2. Service Tracker, Fuel Log, Road Tax & Insurance, Touch 'n Go (all local data), each assignable to a slot.
3. Parking + Map Snapshot, Prayer Times, Commute, Weather & Haze.
4. Photo Frame, Music. App icon from my artwork (§3 App icon): `AppIcon`, `IconPreview` and `IconReveal` in `/remotion`, the three icon appearances in the asset catalog, the alpha check, and the CI render job.
5. Studio: design JSON model + renderer, template gallery, custom builder, My Car photo with background removal, seasonal packs.
6. Connect sound: App Intent, sound library, Speech greeting, guided Shortcuts automation, disconnect → Save Parking.
7. OBD2 + Live Activity (with demo mode).
8. Remotion assets (also use Remotion to render seasonal pack artwork and the onboarding clip showing the slot setup).
9. Polish: rendering modes, accessibility, empty states, JSON backup, README with screenshots/video frames.

## 9. Quality bar

* Unit tests for every calculation: km/L full-to-full, service due logic (km vs date, whichever comes first), mileage estimation, renewal countdowns, prayer "next prayer" logic across midnight, TnG threshold, boost conversion.
* No force unwraps in widget code; every provider returns a valid entry even with no data.
* No secrets in git. Keep a `.env.example` for Remotion and an `xcconfig` template for Swift.
* Keep a `CHANGELOG.md` updated each phase.

Start with Phase 1. First, ask me only for: the bundle ID prefix, my Apple Developer Team ID (or whether I've enrolled yet), and the GitHub repo name.
