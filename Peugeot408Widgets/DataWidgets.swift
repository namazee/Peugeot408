import CarKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct DataEntry: TimelineEntry {
    let date: Date
    let card: DataCard
}

struct DataProvider: TimelineProvider {
    let source: DataSource

    func placeholder(in context: Context) -> DataEntry {
        DataEntry(date: .now, card: SampleData.card(for: source))
    }

    func getSnapshot(in context: Context, completion: @escaping (DataEntry) -> Void) {
        let now = Date()
        if context.isPreview {
            completion(DataEntry(date: now, card: SampleData.card(for: source, now: now)))
            return
        }
        completion(DataEntry(date: now, card: CarData.load().card(for: source, at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DataEntry>) -> Void) {
        let now = Date()
        let entries = DataTimeline.items(for: source, data: CarData.load(), now: now)
            .map { DataEntry(date: $0.date, card: $0.card) }
        let safe = entries.isEmpty ? [DataEntry(date: now, card: CarData.empty.card(for: source, at: now))] : entries
        // Entries cover the next 7 midnights; the app reloads this kind whenever the data changes.
        completion(Timeline(entries: safe, policy: .atEnd))
    }
}

// MARK: - View

struct DataWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DataEntry

    var body: some View {
        WidgetCard(style: .standard, tint: entry.card.tint) {
            DataCardView(card: entry.card, size: CardSize(family))
        }
        .widgetURL(entry.card.source.deepLink)
    }
}

// MARK: - Widgets

@MainActor
enum DataWidgetConfiguration {
    static func make(source: DataSource, description: String) -> some WidgetConfiguration {
        // Plain Strings: an interpolated literal becomes a LocalizedStringKey, which crashed
        // the extension on iOS 27 (see CHANGELOG, Phase 1 fixes).
        let name: String = source.displayName
        let details: String = description
        return StaticConfiguration(kind: source.widgetKind, provider: DataProvider(source: source)) { entry in
            DataWidgetView(entry: entry)
        }
        .configurationDisplayName(name)
        .description(details)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct ServiceTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .service, description: "The most urgent service item, by km or date.")
    }
}

struct FuelLogWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .fuel, description: "Average km/L, last price per litre and this month's spend.")
    }
}

struct RenewalsWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .renewals, description: "Days until the next road tax or insurance renewal.")
    }
}

struct TouchNGoWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .tng, description: "Your Touch 'n Go balance, with a top-up warning.")
    }
}

// MARK: - Previews

#Preview("Service", as: .systemSmall) {
    ServiceTrackerWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .service))
    DataEntry(date: .now, card: CarData.empty.card(for: .service, at: .now))
}

#Preview("Service medium", as: .systemMedium) {
    ServiceTrackerWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .service))
}

#Preview("Fuel", as: .systemSmall) {
    FuelLogWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .fuel))
    DataEntry(date: .now, card: CarData.empty.card(for: .fuel, at: .now))
}

#Preview("Renewals", as: .systemMedium) {
    RenewalsWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .renewals))
}

#Preview("Touch 'n Go", as: .systemSmall) {
    TouchNGoWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .tng))
    DataEntry(date: .now, card: .tng(TnGSummary(balance: 8.4, threshold: 20, isLow: true)))
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    RenewalsWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .renewals))
}
