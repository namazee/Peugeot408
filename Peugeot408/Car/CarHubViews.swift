import CarKit
import SwiftUI

/// Car tab: service, fuel and renewals. Parking and OBD2 come in later phases.
struct CarView: View {
    @Environment(CarDataModel.self) private var model
    @Binding var path: [DataSource]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach([DataSource.service, .fuel, .renewals]) { source in
                        NavigationLink(value: source) {
                            DataSourceRow(source: source, card: model.card(for: source))
                        }
                    }
                }
                Section("Coming later") {
                    Label("Parking: Phase 3", systemImage: "parkingsign.circle")
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

/// Daily tab: Touch 'n Go. Prayer, commute and weather come in Phase 3.
struct DailyView: View {
    @Environment(CarDataModel.self) private var model
    @Binding var path: [DataSource]

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: DataSource.tng) {
                        DataSourceRow(source: .tng, card: model.card(for: .tng))
                    }
                }
                Section("Coming in Phase 3") {
                    Label("Prayer times", systemImage: "moon.stars")
                    Label("Commute", systemImage: "car.rear.road.lane")
                    Label("Weather & haze", systemImage: "cloud.sun")
                }
                .foregroundStyle(Theme.secondaryText)

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
        }
    }
}
