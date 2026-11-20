import CarKit
import SwiftUI
import WeatherKit

struct WeatherView: View {
    @Environment(CarDataModel.self) private var model
    @State private var attribution: (mark: URL, legal: URL)?

    private var cache: WeatherCache { model.data.weather }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .weather))

            Section {
                if let weather = cache.weather {
                    LabeledContent("Now", value: "\(CarFormat.temperature(weather.temperatureC)) · \(weather.condition)")
                    LabeledContent("Rain", value: WeatherRules.rainText(at: .now, in: weather))
                }
                if let place = cache.placeLabel {
                    LabeledContent("For", value: place)
                }
                if let fetched = cache.weatherFetchedAt, cache.weather != nil {
                    LabeledContent("Updated", value: fetched.formatted(date: .omitted, time: .shortened))
                }
                if let error = cache.weatherError {
                    Text(error).font(.footnote).foregroundStyle(Theme.overdue)
                }
            } header: {
                Text("Weather")
            }

            Section {
                if let air = cache.air {
                    HStack {
                        Circle().fill(Color(hex: air.band.hex)).frame(width: 12, height: 12)
                        Text("API \(air.value) · \(air.band.displayName)")
                    }
                    LabeledContent("Station", value: air.station)
                    if let observed = air.observedAt {
                        LabeledContent("Reading", value: observed.formatted(date: .omitted, time: .shortened))
                    }
                    LabeledContent("Source", value: air.provider)
                }
                if let error = cache.airError {
                    Text(error).font(.footnote).foregroundStyle(Theme.overdue)
                }
                NavigationLink {
                    APIKeysView()
                } label: {
                    Label("Air-quality token", systemImage: "key.fill")
                }
            } header: {
                Text("Haze")
            } footer: {
                Text("Colours follow the Malaysian API bands: Good (blue) up to 50, Moderate (green) up to 100, Unhealthy (yellow) up to 200, Very Unhealthy (orange) up to 300, Hazardous (red) above.")
            }

            Section {
                Button {
                    Task { await model.refresh(.weather, force: true) }
                } label: {
                    HStack {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                        if model.isRefreshing.contains(.weather) {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            } footer: {
                Text("Widgets refresh about every 30 minutes, using your location if allowed, otherwise Home.")
            }

            Section {
                if let attribution {
                    AsyncImage(url: attribution.mark) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text("\u{F8FF}Weather")
                    }
                    .frame(height: 18)
                    Link("Weather data sources and legal information", destination: attribution.legal)
                        .font(.footnote)
                } else {
                    Text("\u{F8FF}Weather")
                }
            }
        }
        .navigationTitle("Weather & Haze")
        .task {
            _ = await LocationService.current(askPermission: true)
            await model.refresh(.weather)
            if let value = try? await WeatherService.shared.attribution {
                attribution = (value.combinedMarkDarkURL, value.legalPageURL)
            }
        }
    }
}

/// Settings → API keys. The built-in token comes from the AQI_API_KEY GitHub secret.
struct APIKeysView: View {
    @Environment(CarDataModel.self) private var model
    @State private var token = ""
    @State private var hasOverride = AirQualityKey.override != nil
    @State private var saved: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Built into this build", value: AirQualityKey.builtIn == nil ? "No" : "Yes")
                LabeledContent("Your own token", value: hasOverride ? "Saved" : "None")
            } footer: {
                Text("Get a free token at aqicn.org/data-platform/token. Add it as the AQI_API_KEY GitHub secret so every build has it, or paste one here to override it on this phone.")
            }
            Section {
                SecureField("WAQI token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save token") {
                    let ok = AirQualityKey.setOverride(token)
                    hasOverride = AirQualityKey.override != nil
                    token = ""
                    saved = ok ? "Saved. Refreshing haze…" : "Couldn't save to the Keychain."
                    Task { await model.refresh(.weather, force: true) }
                }
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                if hasOverride {
                    Button("Remove my token", role: .destructive) {
                        AirQualityKey.setOverride(nil)
                        hasOverride = false
                        saved = "Removed."
                    }
                }
                if let saved {
                    Text(saved).font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            } header: {
                Text("Override")
            }
        }
        .navigationTitle("API keys")
    }
}
