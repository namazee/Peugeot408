# SETUP — everything you do by hand

Everything here works from Windows in a browser plus PowerShell. You never need a Mac or Xcode.
Do the steps in order. Values used by this project:

| Thing | Value |
|---|---|
| Team ID | `YCS7MW628Y` |
| Bundle ID prefix | `com.namazee88` (change in `project.yml` → `BUNDLE_PREFIX`) |
| App ID (app) | `com.namazee88.peugeot408` |
| App ID (widgets) | `com.namazee88.peugeot408.widgets` |
| App Group | `group.com.namazee88.peugeot408` |
| GitHub repo | `namazee/Peugeot408` (public) |
| Certificates repo | `namazee/Peugeot408-certs` (**private**) |

---

## 1. Apple Developer Program

- [x] Enrolled (Team ID `YCS7MW628Y`). Membership must be active for TestFlight.

## 2. Identifiers (developer.apple.com → Certificates, IDs & Profiles → Identifiers)

1. **App Group**: `+` → App Groups → Description `Peugeot408`, Identifier `group.com.namazee88.peugeot408`.
2. **App ID for the app**: `+` → App IDs → App → Description `Peugeot408`, Bundle ID *Explicit* `com.namazee88.peugeot408`.
   - Capabilities tab: tick **App Groups**. Save, then *Edit/Configure* next to App Groups and tick `group.com.namazee88.peugeot408`.
   - Also tick now so later phases don't need new profiles: **WeatherKit** (Capabilities tab *and* App Services tab), **MusicKit** (App Services tab).
3. **App ID for the widgets**: same steps with Bundle ID `com.namazee88.peugeot408.widgets`, App Groups → the same group, plus **WeatherKit**.

> If you add a capability to an App ID later, run the iOS workflow manually with **Regenerate provisioning profiles** ticked (Actions → iOS → Run workflow).

## 3. App record (appstoreconnect.apple.com → Apps → `+` → New App)

- Platform iOS, Name `Peugeot408` (store names must be unique; if it's taken use e.g. `Peugeot408 Garage` — the home-screen name stays Peugeot408), Primary language English, Bundle ID `com.namazee88.peugeot408`, SKU `peugeot408`, User access Full.
- Internal TestFlight builds are not reviewed by Apple, so you don't need screenshots or a description.

## 4. App Store Connect API key

1. App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → `+`.
2. Name `GitHub CI`, Access **Admin** (needed to create the distribution certificate and profiles).
3. Download `AuthKey_XXXXXXXXXX.p8` (only downloadable once; keep it somewhere safe, never in the repo).
4. Note the **Key ID** and the **Issuer ID** (shown above the keys list).

## 5. Private certificates repo for fastlane match

Signing uses **fastlane match** with the API key. Why this and not `-allowProvisioningUpdates`:
automatic signing on a fresh CI machine needs a development certificate and at least one registered device,
and makes a new certificate on every run. match creates **one** distribution certificate and App Store
profiles on the first run, stores them encrypted in a private repo, and reuses them every time. No Mac, no device.

1. Create an empty **private** repo `namazee/Peugeot408-certs` on GitHub (no README).
2. Create a fine-grained token: GitHub → Settings → Developer settings → Fine-grained tokens → Generate.
   Repository access: only `Peugeot408-certs`; Permissions → Contents: **Read and write**. Copy the token.
3. Pick a long random **match password** and save it in your password manager. It encrypts the certificates.

## 6. GitHub secrets

In PowerShell, from the folder with your `.p8` file (replace the placeholders):

```powershell
$p8 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))
```

```powershell
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("namazee:YOUR_FINE_GRAINED_TOKEN"))
```

Then set the secrets (each `gh secret set` prompts for nothing when you pass `--body`):

```powershell
gh secret set ASC_KEY_ID --repo namazee/Peugeot408 --body "XXXXXXXXXX"
```

```powershell
gh secret set ASC_ISSUER_ID --repo namazee/Peugeot408 --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

```powershell
gh secret set ASC_KEY_P8 --repo namazee/Peugeot408 --body $p8
```

```powershell
gh secret set MATCH_GIT_URL --repo namazee/Peugeot408 --body "https://github.com/namazee/Peugeot408-certs.git"
```

```powershell
gh secret set MATCH_GIT_BASIC_AUTHORIZATION --repo namazee/Peugeot408 --body $basic
```

```powershell
gh secret set MATCH_PASSWORD --repo namazee/Peugeot408
```

| Secret | Required | What it is |
|---|---|---|
| `ASC_KEY_ID` | yes | API key ID (step 4) |
| `ASC_ISSUER_ID` | yes | Issuer ID (step 4) |
| `ASC_KEY_P8` | yes | The `.p8` file, base64 |
| `MATCH_GIT_URL` | yes | HTTPS URL of the private certs repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | yes | base64 of `namazee:<token>` |
| `MATCH_PASSWORD` | yes | Encrypts the certs repo |
| `TEAM_ID` | no | Overrides `DEVELOPMENT_TEAM` in `project.yml` |
| `AQI_API_KEY` | Phase 3 | Air-quality token (WAQI) |

Until the required secrets exist, CI still runs the tests and skips the upload with a warning.

## 7. First TestFlight build

1. GitHub → Actions → **iOS** → Run workflow (or push to `main`). The first run creates the certificate and profiles in the certs repo.
2. When it's green, App Store Connect → your app → TestFlight. The build appears after Apple processes it (usually 5–30 min).
3. TestFlight → Internal Testing → `+` group `Me`, add yourself, turn on automatic distribution.
4. Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption = NO`).

## 8. Install on the iPhone

1. Install **TestFlight** from the App Store.
2. Accept the email invite (or open TestFlight; it shows up there) and install Peugeot408.
3. Open the app once so it creates its shared data.

## 9. Add the widgets to CarPlay (one time)

1. Connect the iPhone to the car.
2. iPhone Settings → General → CarPlay → your car → **Widgets**.
3. Add **Car Slot 1, 2, 3, 4, 5** (up to 5 widgets per stack). Turn Smart Rotate off if you want a stack to stay put.
4. In the app: Slots → **Test: flash all slots**. Each slot shows "Slot N ✓" for 10 minutes.
5. Change a slot in the app and check the head unit updates (Phase 1 sign-off).

## 10. Phase 3: location, calendar, haze and auto-save parking

1. **Haze token**: get a free token at <https://aqicn.org/data-platform/token> (email sign-up), then add it as the GitHub secret `AQI_API_KEY` (step 6). The next build has it built in. You can also paste one in the app: Settings → API keys.
2. **Permissions** (asked the first time you use each feature):
   - Location **While Using the App**: parking, prayer zone, weather and drive times. Widgets also use it when allowed (iPhone Settings → Peugeot408 → Location: *While Using the App or Widgets*).
   - Calendars **Full Access**: only for the next event on the Commute widget. Optional.
   - Notifications: renewal reminders (Phase 2).
3. **WeatherKit** must be ticked on both App IDs (step 2). If the upload fails with a WeatherKit entitlement error, tick it and rerun with *Regenerate provisioning profiles*.
4. **Auto-save parking when you leave the car** (iOS can't run app code on CarPlay disconnect by itself, so use a Shortcuts automation):
   1. Open **Shortcuts** → **Automation** → **+** → **CarPlay**.
   2. Choose **Disconnects**, then **Run Immediately** (turn off *Notify When Run*, if you like).
   3. **Next** → **New Blank Automation** → **Add Action** → search **Save Parking** (Peugeot408) → add it. Leave Floor/Bay empty or set *Ask Each Time*.
   4. **Done**. Test it by unplugging from the car, then check the Parking widget.

   Siri works too: "Save parking in Peugeot408".

## 12. Phase 6: Connect sound (one-time Shortcuts automation)

iOS doesn't let an app play a sound by itself when CarPlay connects, so a Shortcuts automation runs the app's **Play Connect Sound** action. The app shows the same steps under Studio → Connect sounds.

1. In the app: Studio → **Connect sounds**. Pick a sound (or the spoken greeting with your name), set the volume, and tap **Test sound**.
2. **Shortcuts** → **Automation** → **+** → **CarPlay** → tick **Connects** only → **Run Immediately**.
3. **Next** → **New Blank Automation** → **Add Action** → search **Play Connect Sound** (Peugeot408). Leave *Sound* empty to use the app's choice.
4. **Done**.

Optional, when you leave the car: the same steps with **Disconnects**, adding **Play Connect Sound** (Sound: Goodbye) and then **Save Parking**. This is the same automation as §10 step 4, with a goodbye sound.

## 11. Phase 4: Photo Frame and Music

1. **MusicKit** must be ticked on the app's App ID under *App Services* (step 2). If Music says it can't load anything even after you allow access, check that, then rerun with *Regenerate provisioning profiles*.
2. In the app: Studio → Music → **Allow Apple Music**. Recently played needs an Apple Music subscription; a featured playlist needs the playlist in your library (Sync Library on).
3. Studio → Photo Frame → **Add photos**. To give the Photo Frame widget its own album: long-press the widget → **Edit Widget** → Album. Car Slots use the album chosen in the app.

## 12. App icon (no Mac)

The icon comes from your artwork in `remotion/assets/icon/` (spec §3 App icon). To change it on Windows:

1. Replace `remotion/assets/icon/icon-default.jpg` (optionally add `icon-dark.jpg` / `icon-tinted.jpg`; otherwise those are generated).
2. In PowerShell: `cd remotion`, `npm install` (first time), `npm run icon`.
3. Check `remotion/out/IconPreview.png`, then commit. The script has already copied the three PNGs into `Peugeot408/Resources/Assets.xcassets/AppIcon.appiconset/` and the reveal clip to `Peugeot408/Resources/IconReveal.mp4`.

`npm run icon` and the iOS test job both fail if the default icon PNG has an alpha channel (App Store Connect rejects it). The **Remotion** workflow re-renders everything on each push under `remotion/` and uploads the outputs as artifacts.

> A full Icon Composer `.icon` file (layered Liquid Glass icon) needs Icon Composer on a Mac. Our no-Mac route is a single 1024 PNG with **Any**, **Dark** and **Tinted** appearances in the asset catalog; iOS 26 uses those directly and applies its own glass treatment.

---

## Troubleshooting

- **"Missing secrets" warning** — step 6.
- **match: "Could not find App ID"** — step 2; both App IDs must exist.
- **Widgets show starter text, Settings → Diagnostics says App Group "Not available"** — the App Group isn't assigned to both App IDs (step 2), then rerun with *Regenerate provisioning profiles*.
- **"Maximum number of certificates"** — delete an unused *Apple Distribution* certificate in the portal and rerun with *Regenerate provisioning profiles*.
- **Upload says the app record doesn't exist** — step 3; the bundle ID must match exactly.

## Platform limits (for later phases)

- Spotify's now-playing info isn't available to third-party widgets; the Music widget uses Apple Music via MusicKit (Phase 4).
- iOS can't run app code automatically on CarPlay connect/disconnect. Auto-saving parking uses a Shortcuts automation (step 10); Phase 6 adds the connect sound the same way.
- "Rain soon" uses WeatherKit's hourly forecast (Apple's minute-by-minute forecast doesn't cover every country).
- WAQI reports the US EPA AQI scale; the widget colours it with the Malaysian API bands, as the spec asks.
