# Peugeot408

Personal iOS 26 app whose WidgetKit widgets show on the CarPlay widget screen of a 2025 Peugeot 408 GT.
The app is where data and settings are entered; the widgets display it. Distributed only to the owner via TestFlight.

Not affiliated with Peugeot or Stellantis. No Peugeot logos or emblems are used.

- **Spec (source of truth):** [docs/SPEC.md](docs/SPEC.md)
- **Progress:** [CHANGELOG.md](CHANGELOG.md)
- **Manual setup (Apple, App Store Connect, GitHub secrets):** [SETUP.md](SETUP.md)

## Layout

| Path | What |
|---|---|
| `project.yml` | XcodeGen spec; the `.xcodeproj` is generated on CI and never committed |
| `CarKit/` | Shared code: theme, `WidgetCard`, App Group storage, slot model |
| `CarKitTests/` | Unit tests (Swift Testing) |
| `Peugeot408/` | The iPhone app |
| `Peugeot408Widgets/` | Widget extension (Car Slot 1–5, later the data widgets and Live Activity) |
| `fastlane/` | Signing (match) + archive + TestFlight upload |
| `ci/` | Scripts used by the GitHub Actions workflows |
| `Config/` | xcconfig files; secrets go in the gitignored `Secrets.xcconfig` |

## Building

There is no local build: GitHub Actions on `macos-26` generates the project, runs tests and uploads to TestFlight.
See `.github/workflows/ios.yml`.
