import CarKit
import SwiftUI

/// Car tab: service, fuel, renewals and parking. OBD2 comes in Phase 7.
struct CarView: View {
    @Environment(CarDataModel.self) private var model
    @Binding var path: [DataSource]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach([DataSource.service, .fuel, .renewals, .parking]) { source in
                        NavigationLink(value: source) {
                            DataSourceRow(source: source, card: model.card(for: source))
                        }
                    }
                }
                Section("Coming later") {
                    Label("Live OBD2: Phase 7", systemImage: "gauge.with.dots.needle.67percent")
                }
                .foregroundStyle(Theme.secondaryText)

                if let error = model.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.overdue)
                    }
                }
            }
            .navigationTitle("Car")
            .navigationDestination(for: DataSource.self) { DataSourceScreen(source: $0) }
        }
    }
}

/// Daily tab: prayer, commute, weather and Touch 'n Go.
struct DailyView: View {
    @Environment(CarDataModel.self) private var model
    @Binding var path: [DataSource]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach([DataSource.prayer, .commute, .weather, .tng]) { source in
                        NavigationLink(value: source) {
                            DataSourceRow(source: source, card: model.card(for: source))
                        }
                    }
                }

                if let error = model.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.overdue)
                    }
                }
            }
            .navigationTitle("Daily")
            .navigationDestination(for: DataSource.self) { DataSourceScreen(source: $0) }
        }
    }
}

struct DataSourceScreen: View {
    let source: DataSource

    var body: some View {
        switch source {
        case .service: ServiceView()
        case .fuel: FuelView()
        case .renewals: RenewalsView()
        case .tng: TnGView()
        case .parking: ParkingView()
        case .prayer: PrayerView()
        case .commute: CommuteView()
        case .weather: WeatherView()
        case .map: MapSnapshotView()
        case .photos: PhotoFrameView()
        case .music: MusicView()
        }
    }
}

/// A list row with the source name and its current headline value.
struct DataSourceRow: View {
    let source: DataSource
    let card: DataCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.symbol)
                .font(.title3)
                .foregroundStyle(card.urgency.color(fallback: Theme.accent))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName).font(.headline)
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(card.urgency == .ok ? Theme.secondaryText : card.urgency.color())
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var headline: String {
        switch card {
        case .service(let summary):
            guard let line = summary.lines.first else { return "No items yet" }
            return "\(line.name): \(line.compactText)"
        case .fuel(let summary):
            guard summary.hasFills else { return "No fill-ups yet" }
            let average = summary.averageKmPerLitre.map(CarFormat.kmPerLitre) ?? "km/L after 2 full tanks"
            return "\(average) · \(CarFormat.rm(summary.spentThisMonth, decimals: 0)) this month"
        case .renewals(let summary):
            guard let line = summary.lines.first else { return "No dates yet" }
            return "\(line.name): \(line.countText) \(line.unitText)"
        case .tng(let summary):
            guard let balance = summary.balance else { return "No balance yet" }
            return summary.isLow ? "\(CarFormat.rm(balance)) · top up soon" : CarFormat.rm(balance)
        case .parking(let summary):
            guard let spot = summary.spot else { return "No spot saved" }
            return "\(spot.title) · \(spot.savedAt.formatted(.relative(presentation: .named)))"
        case .prayer(let summary):
            guard let next = summary.next else { return "Loading times…" }
            return "\(next.prayer.displayName) \(next.time.formatted(date: .omitted, time: .shortened)) · \(summary.zoneCode)"
        case .commute(let summary):
            guard let destination = summary.destination, !summary.needsSetup else { return "Set Home and Work" }
            return "\(destination.title): \(summary.travelText)"
        case .weather(let summary):
            var parts = [summary.temperatureText]
            if let air = summary.airText { parts.append(air) }
            return parts.joined(separator: " · ")
        case .map(let summary):
            return summary.caption ?? "Nothing to show yet"
        case .photos(let summary):
            return summary.photoCount == 0 ? "No photos yet" : "\(summary.photoCount) photos"
        case .music(let summary):
            return summary.title ?? "Not set up"
        }
    }
}
