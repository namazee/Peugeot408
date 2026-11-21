# Build "Peugeot408" — iOS 26 CarPlay widget app (no Mac, cloud builds)

You are building a personal iOS app called Peugeot408 for my 2025 Peugeot 408 GT (1.6T PureTech, Malaysia). Its main purpose is a set of WidgetKit widgets that show on the CarPlay widget screen (iOS 26+ shows any iPhone widget in CarPlay, no CarPlay entitlement needed). The app itself is the place where I enter data and change settings; the widgets display it.

App name: the public name is **DashCraft** (display name, home-screen and CarPlay label, App Store name, every user-visible text). The Xcode targets, scheme, bundle IDs, App Group and URL scheme keep their internal `Peugeot408`/`peugeot408` names, which users never see (§10). It started as a personal app for me through TestFlight and is now also prepared for the App Store (Phase 15, §10); it is not affiliated with Peugeot/Stellantis or any car maker. Do not use Peugeot logos or the lion emblem anywhere — use my own car photo and original artwork only. Keep the display name in one setting (`PRODUCT_NAME`/`CFBundleDisplayName` in `project.yml`) so I can rename it later.

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

### Widget styles (switchable)

* Every widget, every Split/Quad card, and the app's screens come in two complete looks. Settings → Appearance sets the style for the whole app; each Car Slot can override it (Default / Bold / Neon). The aim is attractive and eye-catching, like a gallery of designed tiles rather than one repeated dark card.
   * **Bold:** each data source has its own full-colour background (a soft gradient with a subtle texture), and the colour follows the state:
      * air quality uses the AQI band colours;
      * service and renewals go blue → amber → red;
      * Touch 'n Go is teal, and amber when low;
      * prayer shows a sky that changes with the next prayer (dawn, day, dusk, night);
      * weather shows a sky for the condition and time of day.
     Each tile has one huge centred number, a short caps label, and a large symbol or illustration.
   * **Neon:** a near-black base, and the key value in a bright colour with a soft glow. It has progress rings and arc gauges (service km left of the interval, renewal days, fuel against my best km/L, boost), thin tick rings, and glowing accent lines. It uses the same state colours.
   * Both styles:
      * use rings and gauges wherever a value has a range;
      * show my My Car photo as the hero on car widgets where it fits;
      * keep every value big and glanceable (§2).
   * Tinted / clear rendering: backgrounds and glows step aside, key values stay `widgetAccentable()`, and the warning glyph stays.
   * Both palettes live in `theme/tokens.json`, so Remotion can match.
   * The app's screens use the selected style (the Slots mock, the card previews on the Car and Daily screens, the tab tint), so the phone matches the head unit.
   * Original artwork only; no brand logos.

### Panorama hero (Phase 14)

* One wide "hero" design spread across Car Slots 1–3. Each slot draws its third, so the three tall columns read as one picture, e.g. my My Car photo spanning the screen with big lettering behind it. The gaps between columns stay, because CarPlay draws them.
* A Hero template for it: a greeting, big "408 GT" (or my own text) lettering behind the car, my car photo and a weather line. No brand logos or emblems.
* New data fields:
   * a time-of-day greeting with my name ("Good morning, …" / "Selamat pagi, …");
   * the weather place and condition ("Kuala Lumpur · Sunny").
* Turning Panorama on asks before it replaces what Slots 1–3 show, and turning it off restores them.

### App icon

* Source art: my own icon artwork (generated from a photo of my car), stored in `remotion/assets/icon/` as `icon-default.jpg` (plus `icon-dark.jpg` and `icon-tinted.jpg` if I provide them). This is the master art: don't redraw the car. No logos; the only text is the "DASHCRAFT" wordmark (layer 5).
* Remotion composition `AppIcon` (1024×1024), prop `variant: "default" | "dark" | "tinted"`, built in layers:
   1. Background `#05070D` with a soft radial blue glow (`#1F4FD8` at ~25% opacity) behind the car.
   2. The source image, scaled/cropped so the headlights, light strips and grille sit inside the central 80% safe area.
   3. Glow boost: duplicate the brightest areas (luminance threshold), blur, tint `#7FD4FF`, screen-blend at ~40%, so the lights pop at small sizes.
   4. A subtle vignette and a faint Liquid Glass highlight along the top edge.
   5. Wordmark "DASHCRAFT" (the app name in capitals; it replaced the earlier "GTCP") centred below the car on one line, inside the safe area: wide-tracked (less than before so the nine letters fit), wide sans-serif (open-licence font, recorded in `ASSETS-LICENSES.md`), white with a soft `#7FD4FF` glow (white glow on tinted), sized to be readable at 180 and 120 px. The car moves up slightly to make room; the lights stay inside the safe area. In `IconReveal` the wordmark fades in as the icon settles.
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
13. Synced lyrics (Phase 13):
   * A Lyrics widget, a Lyrics card for slots, and a Live Activity version.
   * It shows the current song's lines: 1, 3 or 5 at once, with the active line big and bright, the previous line faded, and the next line dimmer.
   * The song and playback position come from the Apple Music system player (MusicKit / `MPMusicPlayerController.systemMusicPlayer`).
   * Time-coded lyrics come from the free LRCLIB service (no key). They are cached in the App Group and fetched only for songs I play.
   * Each line becomes a pre-scheduled timeline entry (or Live Activity update), so lines change without the app running. Sync is approximate and is re-anchored whenever the app sees the player.
   * Settings: number of lines, text size, accent colour, an optional translation line when LRCLIB has one.
   * Spotify isn't supported: other apps can't read its now-playing data. Say so in the app and in `SETUP.md`.
   * When a song has no synced lyrics, show the title and artist instead (or plain lyrics if that's all there is).
   * Personal use; lyrics are fetched on demand and never bundled.
   * The App Store build leaves this whole feature out (§10 Build flavours): LRCLIB lyrics are only in my personal TestFlight builds.

## 4b. Customisation studio (design it in the app → the head unit updates by itself)

Goal: I set things up once in the app, and my car's CarPlay screen reflects it automatically. I should never have to dig back into iPhone Settings → CarPlay → Widgets after the first setup.

### The "slot" system (the core of this)

* Provide 5 generic widgets named "Car Slot 1" to "Car Slot 5" (one widget kind each, `.systemSmall` + `.systemMedium`). I add them to my CarPlay widget stacks once.
* In the app, a Slots screen lets me assign any design to any slot: one of the data widgets from section 4 (service, fuel, prayer…), a template, or a custom design from the builder. I can reorder slots by dragging.
* Assignments live in the App Group. Saving a slot calls `WidgetCenter.shared.reloadTimelines(ofKind:)` for that slot, so the head unit changes within seconds the next time CarPlay draws it.
* Each slot can optionally rotate between up to 3 assigned designs on a schedule (e.g. prayer times at dawn and dusk, service tracker otherwise) or by time-of-day rules. Use timeline entries for this, not reloads.
* Keep the dedicated widgets from section 4 too, for people who'd rather add them individually. The slots are the main path.
* Picture instead of an icon (simple text slot designs and cards): besides the SF Symbol icons, I can pick a picture: my current My Car photo (live, with my paint colour and plate), any built-in My Car photo (always in its original colours, whatever paint colour I picked in My Car, but with my plate), or one I upload (PhotosPicker). Uploaded pictures are downsampled, keep their transparency, and have empty transparent margins trimmed. The picture is always shown whole (fit, never cropped) at the largest size the slot allows, with the big value and label beside or below it (or alone if I leave the text empty).
* Background colour for simple text slot designs (and Custom text cards): Dark, Blue, or **any colour** from a colour picker, with quick swatches including the 408's Malaysian paint colours. In the Bold look the tile is that colour (with the same sheen and texture as the data tiles). In the Neon look it's the glow colour on near-black. "Dark" is always a near-black tile.
* Single-layout slot extras (any content, data source or custom text):
   * **Centre picture:** my My Car photo, any built-in photo, or an uploaded picture, drawn whole in the middle of the tile, with the label at the top and the big value at the bottom, so a single slot isn't plain in the middle.
   * Custom text: **text alignment** Left / Centre / Right.
   * Custom text: **text size per line**, separate sliders for the big value and the small label (about 70–150%), still shrinking to fit so nothing is cut off.
* Split-card slot layouts. My 408's head unit shows 3 columns of tall widgets (Slot 1–3 visible), and the car controls the column count, so each slot can be split into several cards for more information:
   * Each Car Slot has a layout setting: "Single" (1 card, the original behaviour), "Split" (2 cards stacked top/bottom, the default), or "Quad" (2×2, icon + value only).
   * Each card in a layout is assigned its own data source or design (any widget from section 4 or the Studio), so 3 visible slots in Split = 6 cards on screen.
   * Split card design: icon + short label + one large value, with minimum font sizes so it stays readable on the car screen; a thin divider or gap between cards; the "due soon/overdue" colours still apply per card.
   * Quad: icon + value only, no labels; the app warns that it's harder to read while driving.
   * The Slots tab mock CarPlay screen shows the real 3-column layout with split cards, and I can tap any card to change it.
   * Default setup: Slot 1 = Next prayer / Road tax, Slot 2 = Service tracker / Fuel log, Slot 3 = Weather & haze / Parking.
   * Slots 4 and 5 stay available for stacking behind the visible columns (Smart Rotate).
   * The "flash all slots" test labels each card, e.g. "Slot 2 · Top ✓" / "Slot 2 · Bottom ✓".
* First-run onboarding walks me through the one-time step (add Car Slot 1–5 in Settings → General → CarPlay → [car] → Widgets, 5 per stack) with screenshots, plus a "Test: flash all slots" button that pushes an identifying design ("Slot 3 ✓") to each slot so I can check which is which in the car.

### Templates (ready-made styles)

* A template gallery with live previews using my real data. Styles: Sporty (carbon texture, red/blue accents, gauge-like arcs), Minimal (big number, thin label), Premium (dark glass, fine serif accents), Dashboard (multi-value grid), Photo (full-bleed image with a caption), Clock (analogue and digital variants), Countdown, and Anniversary ("Married 9 years, 213 days" / days until an event).
* Every template can be bound to any data source (e.g. Sporty + Fuel Log, Minimal + Prayer Times).
* More eye-catching templates, added to the ones above:
   * **Bold Tile:** a solid, vivid colour that follows the bound source's state, with one huge centred number and a caps label.
   * **Neon Ring:** black, a glowing progress ring and a glowing value.
   * **Twin Gauges:** two arc gauges side by side (the primary and secondary values).
   * **Aurora:** a vivid multi-colour gradient behind a huge value.
   * **Sunset Drive:** an orange-to-purple sky with a sun and an open road.
   * **Night Drive:** a deep navy glow, my My Car photo and a glowing value.
   * **Showroom:** a spotlight behind my My Car photo, with my plate.
   * **Racing Stripes:** a bold colour with diagonal stripes and the value in Orbitron.
   * **Starry Night:** a starfield with a crescent and the prayer countdown.
   * **Big Date:** a calendar page with the weekday, a giant day number and the month.
   * **Year Progress:** this year's percentage, with a progress bar.
   * **Retro LED:** an amber digital clock with a soft glow on black.
  To draw these, the design model gains:
   * a multi-colour (aurora) gradient and a radial spotlight background;
   * a progress ring and a progress bar layer;
   * an optional glow on any layer;
   * calendar fields (weekday, day of month, month, year progress);
   * new original stickers (sun, road, starfield).
  All of these are optional fields, so saved designs still load. The gallery groups templates (Data, Car, Clock & Date, Special) so the new ones are easy to find, and every new template is also available in the builder.
* Seasonal packs for Malaysia that the app can switch to automatically on the right dates: Hari Raya Aidilfitri, Ramadan (with an iftar countdown using the prayer module's Maghrib time), Aidiladha, Merdeka/Malaysia Day, Chinese New Year, Deepavali, Christmas, New Year. All original artwork, drawn in SwiftUI shapes/SF Symbols or as bundled assets generated in Remotion; nothing copied from other apps.

### Custom builder

* A layer-based editor (a canvas in the exact aspect ratio of the CarPlay small and medium widgets, with a safe-area overlay): background (solid, gradient, photo, texture), car photo, text, SF Symbols icons, stickers (a bundled set of original stickers), and data fields (any value from section 4: next prayer, km to service, km/L, TnG balance, days to road tax, parking time, etc.).
* Per layer: position, size, rotation, opacity, font (system fonts plus a few bundled open-licence fonts), colour, shadow. Snap-to-grid, undo/redo, duplicate, lock.
* Store designs as a versioned Codable JSON model in the App Group. The widget extension renders that JSON with SwiftUI, so builder previews and the car look identical. Write snapshot/unit tests that render each template from JSON.
* Enforce glanceability: warn when text is too small for CarPlay or the contrast is too low (WCAG contrast check), and limit each design to 2 data fields in `.systemSmall`.
* Export/import designs as files (share sheet) so I can back them up or share them.

### My car as the hero image

* Pick a photo of my 408 GT, then use one-tap background removal with Apple's Vision framework (`VNGenerateForegroundInstanceMaskRequest`, fully on-device). Allow manual touch-up (erase/restore brush), then save it as a transparent PNG downsampled for widget size.
* Built-in default photos: a few photos of my 408 that I supplied (already cut out, transparent background), bundled with the app so My Car works before I pick my own. The lion badges are removed with a smooth fill (no visible mosaic or grid), so no Peugeot emblem shows. I can pick one of these in My Car, and choosing my own photo (above) still works and replaces it. The side view is used until I choose.
  * Studio renders: six more built-in photos of my 408 that I supplied (front, front ¾, side, rear ¾, rear, front detail) supplied already cut out (transparent background), so no on-device background removal is needed. The paint colour and plate work the same as on the other built-in photos. Any badge or wheel-cap logo is removed the same way.
  * Paint colour (built-in photos only): a colour picker with swatches of the 408's Malaysian colours (Obsession Blue = original, Elixir Red, Okenite White, Selenium Grey, Perla Nera Black) plus any colour. Only the body paint is recoloured on the device (keeping its shading): windows (traced per photo), plates, lights and their glow, trim and tyres stay as they are.
  * Number plate (built-in photos only): the plate text I type in My Car is drawn over the white "408" show plate on the photos where a plate is visible, in Malaysian style (black plate, white characters), following the plate's perspective and matched to the photo's lighting and sharpness so it looks real. With no plate text, the original plate stays.
  * Plate font: I can pick the plate's font from a few styles (classic bold, condensed, monospaced, rounded, Orbitron, Rajdhani; bundled or system fonts only). The same font is used by the plate layer in Studio designs.
* A ready-made "My Car" template: the cut-out car over a gradient in Obsession Blue, with a chosen data line underneath (e.g. "Oil service in 1,240 km"), plus an optional number-plate-style label (text I type in).

### Connect sound (plays when CarPlay connects)

* iOS doesn't let an app play a sound automatically when CarPlay connects, so implement it the supported way:
   * An App Intent "Play Connect Sound" (with the sound selection as a parameter) that plays through the current audio route (so it comes out of the car speakers), at a set volume, with ducking.
   * The app guides me step by step to create a Shortcuts personal automation: "When CarPlay connects → Play Connect Sound", set to run immediately without asking. Provide a screen with the exact steps and screenshots, and a "Test sound" button.
* A bundled library of original sounds (generate them yourself or use clearly licensed free sounds and record the licence in `ASSETS-LICENSES.md`): clean chimes, a soft "welcome" tone, sporty engine-style revs, and a spoken "Welcome back" made with on-device `AVSpeechSynthesizer` in English or Malay with my name.
* Let me import my own audio file (trim to ≤5 seconds in-app).
* Optional matching "disconnect" automation that also triggers Save Parking (ties into the Parking widget).
* Sound packs (Phase 12). The library grows into packs, each with several sounds and a preview button:
   * **Engine starts:** real recordings (V8, V12, flat-six, turbo four, rotary or similar, and EV whine) taken only from public-domain (CC0) sources such as Freesound. Each file's source, author and licence goes in `ASSETS-LICENSES.md`. Ask me before downloading.
   * **EV whoosh, Luxury, Retro arcade, Minimal pings, Sci-fi:** original sounds synthesised by `tools/make-sounds.py`.
   * **Voice cues:** short spoken lines ("Drive safe", "Welcome back", "CarPlay connected", Malay versions too), made on-device with `AVSpeechSynthesizer` and a choice of voices.
   * Every sound is trimmed to at most 5 seconds and loudness-normalised, so none is much louder than the others. Imported clips are normalised the same way.
   * A separate sound choice for disconnect, as well as for connect.
   * No sounds are copied from other apps or websites.

### Sync behaviour

* Any edit in the builder, templates, slots or data shows on the CarPlay head unit without opening Settings: it all goes through the App Group plus `reloadTimelines`. Document in the app that CarPlay may take a moment to redraw, and that the car screen redraws faster after reconnecting.
* Also mirror the slots as iPhone Home Screen/StandBy widgets for free (the same widget kinds work there).

## 5. The app (iPhone)

* Tab layout: Slots (what's on my head unit right now, as a mock CarPlay screen showing all 5 slots with live data; tap a slot to change it), Studio (templates, custom builder, seasonal packs, my car photo, connect sounds), Car (service, fuel, renewals, parking, OBD2), Daily (prayer, commute, weather, TnG), Settings (Map, Music and Photos setup live under Studio → Data sources).
* Settings: units, theme accent colour, prayer zone, home/work locations, API keys, OBD2 dongle, data export/import as JSON (for backup), "Reload all widgets" button.
* A "How to add to CarPlay" screen: Settings → General → CarPlay → [car] → Widgets, up to 5 widgets per stack, Smart Rotate on/off.
   * Include a tip for Google Maps' own CarPlay ETA widget (ETA, distance and next turn while Google Maps navigates). Other apps can't read Google Maps' navigation, so don't rebuild it: add Google's widget to the same stack as a Car Slot, and Smart Rotate brings it forward while navigating.
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
8. Split-card slot layouts (§4b): Single / Split / Quad per slot, a data source or design per card, the 3-column mock with tap-to-change cards, the new default setup, and per-card flash labels. Stop and let me test it in the car.
9. Remotion assets (also use Remotion to render seasonal pack artwork and the onboarding clip showing the slot setup).
10. Polish: rendering modes, accessibility, empty states, JSON backup, README with screenshots/video frames.
11. Widget styles (§3): Bold and Neon looks for every widget, card and app screen, Settings → Appearance plus a per-slot override, both palettes in the shared tokens, the 12 new Studio templates (§4b Templates), and refreshed README snapshots.
12. Sound packs (§4b Connect sound): engine starts from CC0 recordings, synthesised EV, luxury, arcade, pings and sci-fi packs, voice cues, normalising and the 5-second trim, and a separate disconnect sound.
13. Synced lyrics (§4 item 13): the Lyrics widget, card and Live Activity from the Apple Music system player and LRCLIB.
14. Panorama hero (§3): one wide design across Slots 1–3, the Hero template, and the greeting and weather-place fields.
15. App Store release (§10): the DashCraft name in all user-visible text and the "DASHCRAFT" icon wordmark, the `store` build flavour without lyrics, Sample data mode, privacy manifests, the support and privacy pages, store metadata and screenshots, and the `store_metadata` lane. Stop before anything public: I turn on Pages and submit for review myself.

## 9. Quality bar

* Unit tests for every calculation: km/L full-to-full, service due logic (km vs date, whichever comes first), mileage estimation, renewal countdowns, prayer "next prayer" logic across midnight, TnG threshold, boost conversion.
* No force unwraps in widget code; every provider returns a valid entry even with no data.
* No secrets in git. Keep a `.env.example` for Remotion and an `xcconfig` template for Swift.
* Keep a `CHANGELOG.md` updated each phase.

## 10. App Store release (Phase 15)

### Name and wording

* Public name: **DashCraft**. App Store subtitle: "Car widgets & dashboard". `APP_DISPLAY_NAME` in `project.yml` is `DashCraft`.
* Internal names stay as they are: targets and scheme `Peugeot408`, bundle IDs `….peugeot408…`, App Group `group.….peugeot408`, URL scheme `peugeot408://`, backup format id `peugeot408-backup`. Renaming them would lose the data in the App Group, need new signing and break existing backups, and users never see them.
* No user-visible text says "Peugeot", "Stellantis" or "408": permission prompts, Siri/Shortcuts descriptions, Settings, help texts, onboarding, error messages, backup file names ("DashCraft backup <date>.json"), the IconPreview mock label. Generic wording instead ("your car", "Some cars' ECUs don't answer every standard PID"). Settings footer: "Not affiliated with any car maker."
* Defaults for a new install use neutral text: Slot 1 "MY CAR" instead of "408 GT", the Hero template lettering "MY CAR", plate placeholder "ABC 1234". My own saved slots and designs are not changed.
* The built-in My Car photos are my own photos and stay in both builds.

### Build flavours

* `personal` (default): every push to `main`, as now. Everything in this spec, including LRCLIB lyrics. Goes to TestFlight.
* `store`: run the iOS workflow by hand with input `flavour: store`. Compiles with the Swift condition `STORE_BUILD`, which leaves out the Lyrics feature completely: the LRCLIB client, the Lyrics widget, the Lyrics data source and card, the Lyrics Live Activity, the Sync Lyrics intent and the lyrics screen. A saved slot that points at Lyrics shows the Music card instead. No hidden switches: the code isn't in the store binary at all.
* Both flavours upload to the same App Store Connect app and share the run-number build numbers; the store build's TestFlight note says "Store build". Only a store build is ever submitted for review (`SETUP.md` says how to pick it).

### Sample data (for App Review and first look)

* Settings → "Sample data" switch, also offered on the last onboarding page ("Try it with sample data"). While it is on, the app and every widget show `SampleData` (a full service history, fill-ups, renewals, prayer times, TnG, parking, OBD values) and the app shows a small "Sample data" badge at the top of each tab. My real data is untouched and comes back when it is turned off.
* The App Review notes tell the reviewer to turn it on, so they can see filled widgets without a car, OBD dongle or Malaysian data.

### Privacy

* No account, no analytics, no tracking, no ads; nothing is sent to me. Data stays on the phone in the App Group (and in backups I export myself). App Privacy answer in App Store Connect: "Data Not Collected".
* What leaves the phone, only to answer a request: location to Apple WeatherKit (weather) and, if I add a WAQI key, to the WAQI air-quality service; the prayer zone code to JAKIM e-solat; song title and artist to LRCLIB (personal build only).
* `PrivacyInfo.xcprivacy` privacy manifests in the app and the widget extension, declaring the required-reason APIs used (UserDefaults, file timestamps, system boot time if used) and no tracking.
* `ITSAppUsesNonExemptEncryption = NO` stays (export compliance).

### Web pages

* `site/index.html` (support: what the app does, how to add widgets to CarPlay, contact by GitHub issue), `site/privacy.html` (the Privacy section above in plain words). Plain HTML and CSS in the app's colours, the DashCraft icon, no logos, no trackers, no external scripts.
* Published with GitHub Pages from the `site/` folder by a `pages.yml` workflow. Turning Pages on makes the pages public: ask me first. Their URLs are the App Store support and privacy URLs.

### Store listing

* `fastlane/metadata/` (deliver format), English (primary) and Malay: name, subtitle, description, keywords, promotional text, release notes, support URL, privacy URL; plus the review notes (no login; turn on Sample data; how to add widgets in CarPlay on iOS 26; the OBD2 dongle is optional hardware), category Utilities (secondary Lifestyle), free, and the age-rating answers (4+), all written down in `SETUP.md` for anything deliver can't set.
* The description says what works best in Malaysia (JAKIM prayer times, Touch 'n Go, road tax and insurance renewals). Availability is set by me in App Store Connect (suggested: Malaysia first).
* Screenshots for the 6.9-inch iPhone size (1320×2868), 6 of them, taken from the app running on the simulator with Sample data on (a UI test with launch argument `-screenshots`), then framed in Remotion (`StoreScreenshot` composition: dark background in the theme colours, a short headline above the phone screen, no device frame from Apple's artwork). Screens: Slots mock CarPlay, Studio template gallery, a Bold vs Neon card pair, Car service and fuel, Panorama hero, Connect sounds. Rendered by a manual `store-assets` job and uploaded as an artifact.
* fastlane lane `store_metadata` uploads the metadata and screenshots only (`skip_binary_upload`, `submit_for_review: false`), from a manual workflow run. I submit for review myself in App Store Connect; CI never submits.
* `SETUP.md` §15 lists my manual steps in order: rename the app record to DashCraft (and check the name is free), answer App Privacy, approve turning on GitHub Pages, run the store build, run `store_metadata`, pick the store build, submit.

Start with Phase 1. First, ask me only for: the bundle ID prefix, my Apple Developer Team ID (or whether I've enrolled yet), and the GitHub repo name.
