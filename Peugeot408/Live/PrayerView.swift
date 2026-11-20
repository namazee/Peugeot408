import CarKit
import SwiftUI

struct PrayerView: View {
    @Environment(CarDataModel.self) private var model
    @State private var locating = false
    @State private var locateMessage: String?

    private var settings: PrayerSettings { model.data.prayerSettings }
    private var cache: PrayerCache { model.data.prayer }

    private var today: PrayerDay? {
        guard cache.zoneCode == settings.zoneCode else { return nil }
        return PrayerSchedule.day(containing: .now, in: cache.days)
    }

    var body: some View {
        List {
            CardPreviewSection(card: model.card(for: .prayer))

            Section {
                NavigationLink {
                    ZonePickerView()
                } label: {
                    LabeledContent("Zone") {
                        Text("\(settings.zone.code) · \(settings.zone.shortName)")
                            .lineLimit(1)
                    }
                }
                Toggle("Pick zone from my location", isOn: autoZone)
                if locating {
                    HStack {
                        ProgressView()
                        Text("Finding your zone…")
                    }
                }
                if let locateMessage {
                    Text(locateMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            } footer: {
                Text("SGR01 covers Sepang and Cyberjaya; WLY01 covers Kuala Lumpur and Putrajaya. With location on, the zone updates each time you open the app.")
            }

            Section {
                if let today {
                    ForEach(today.moments, id: \.prayer) { moment in
                        HStack {
                            Label(moment.prayer.displayName, systemImage: moment.prayer.symbol)
                                .foregroundStyle(moment.prayer.isPrayer ? Theme.primaryText : Theme.secondaryText)
                            Spacer()
                            Text(moment.time, style: .time)
                                .monospacedDigit()
                        }
                    }
                } else {
                    Text("No times yet. Tap Refresh.")
                        .foregroundStyle(Theme.secondaryText)
                }
                Button {
                    Task { await model.refresh(.prayer, force: true) }
                } label: {
                    HStack {
                        Label("Refresh from e-Solat", systemImage: "arrow.clockwise")
                        if model.isRefreshing.contains(.prayer) {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            } header: {
                Text("Today")
            } footer: {
                Text(sourceText)
            }
        }
        .navigationTitle("Prayer Times")
        .task {
            if settings.autoZone { await locateZone() }
            await model.refresh(.prayer)
        }
    }

    private var sourceText: String {
        var parts: [String] = []
        if today?.origin == .calculated {
            parts.append("Estimated offline (within about 2 minutes of JAKIM). e-Solat will be tried again later.")
        } else if let fetched = cache.fetchedAt {
            parts.append("JAKIM e-Solat, downloaded \(fetched.formatted(.relative(presentation: .named))). About a month is cached.")
        }
        if let error = cache.lastError {
            parts.append("Last download failed: \(error)")
        }
        return parts.joined(separator: " ")
    }

    private var autoZone: Binding<Bool> {
        Binding(
            get: { settings.autoZone },
            set: { value in
                model.updatePrayerSettings { $0.autoZone = value }
                if value { Task { await locateZone() } }
            }
        )
    }

    private func locateZone() async {
        locating = true
        defer { locating = false }
        guard let point = await LocationService.current(askPermission: true) else {
            locateMessage = "Location isn't available, so the zone stays \(settings.zoneCode)."
            return
        }
        let place = await PlaceNamer.place(for: point)
        let zone = PrayerZone.locate(
            latitude: point.latitude,
            longitude: point.longitude,
            placeNames: place?.areaNames ?? [],
            state: place?.state
        )
        locateMessage = "Your location is in \(zone.code)."
        if zone.code != settings.zoneCode {
            model.updatePrayerSettings { $0.zoneCode = zone.code }
        }
    }
}

struct ZonePickerView: View {
    @Environment(CarDataModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        List {
            ForEach(PrayerZone.byState, id: \.state) { group in
                let zones = group.zones.filter(matches)
                if !zones.isEmpty {
                    Section(group.state) {
                        ForEach(zones) { zone in
                            Button {
                                model.updatePrayerSettings {
                                    $0.zoneCode = zone.code
                                    $0.autoZone = false
                                }
                                dismiss()
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(zone.code).font(.headline)
                                        Text(zone.areas)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                    Spacer()
                                    if zone.code == model.data.prayerSettings.zoneCode {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Town or zone code")
        .navigationTitle("Prayer zone")
    }

    private func matches(_ zone: PrayerZone) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return zone.code.localizedCaseInsensitiveContains(query)
            || zone.areas.localizedCaseInsensitiveContains(query)
            || zone.stateName.localizedCaseInsensitiveContains(query)
    }
}
