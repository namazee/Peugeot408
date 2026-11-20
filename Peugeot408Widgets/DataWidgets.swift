import CarKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

/// WidgetKit's completion handlers aren't marked Sendable, but WidgetKit expects them to be
/// called from any thread. This box lets the async timeline work call it from a Task.
struct CompletionBox<Value>: @unchecked Sendable {
    private let handler: (Value) -> Void

    init(_ handler: @escaping (Value) -> Void) {
        self.handler = handler
    }

    func call(_ value: Value) {
        handler(value)
    }
}

struct DataEntry: TimelineEntry {
    let date: Date
    let card: DataCard
    /// Settings → Appearance.
    let look: CardLook = AppearanceStore.settings().load().look
}

/// Builds the timeline for one data source. Live sources (prayer, commute, weather, map) first
/// refresh their cached files (each throttles itself), then everything is drawn from the cache.
enum DataTimelineBuilder {
    static func timeline(for source: DataSource, displaySize: CGSize) async -> Timeline<DataEntry> {
        let now = Date()
        if source.isLive {
            await LiveRefresher.refresh(source, now: now, mapSize: displaySize)
        }
        let data = CarData.load()
        var entries = DataTimeline.dates(for: source, data: data, from: now).map { date in
            DataEntry(date: date, card: card(source, data: data, at: date, size: displaySize))
        }
        if entries.isEmpty {
            entries = [DataEntry(date: now, card: CarData.empty.card(for: source, at: now))]
        }
        let policy: TimelineReloadPolicy = DataTimeline.reloadDate(for: source, data: data, now: now).map { TimelineReloadPolicy.after($0) } ?? TimelineReloadPolicy.atEnd
        return Timeline(entries: entries, policy: policy)
    }

    static func card(_ source: DataSource, data: CarData, at date: Date, size: CGSize) -> DataCard {
        source == .map
            ? data.mapCard(at: date, width: size.width, height: size.height)
            : data.card(for: source, at: date)
    }
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
        let size = context.displaySize
        completion(DataEntry(date: now, card: DataTimelineBuilder.card(source, data: CarData.load(), at: now, size: size)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DataEntry>) -> Void) {
        let source = source
        let size = context.displaySize
        let reply = CompletionBox(completion)
        Task {
            reply.call(await DataTimelineBuilder.timeline(for: source, displaySize: size))
        }
    }
}

// MARK: - View

struct DataWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DataEntry

    var body: some View {
        WidgetCard(style: .standard, paint: entry.card.paint) {
            DataCardView(card: entry.card, size: CardSize(family))
                .overlay(alignment: .bottomTrailing) { musicControls }
        }
        .environment(\.cardLook, entry.look)
        .widgetURL(entry.card.source.deepLink)
    }

    /// Play/pause and next on the medium Music widget (iPhone; CarPlay may ignore taps).
    @ViewBuilder
    private var musicControls: some View {
        if family == .systemMedium, case .music(let summary) = entry.card, summary.showControls, summary.title != nil {
            HStack(spacing: 8) {
                Button(intent: MusicPlayPauseIntent()) {
                    Image(systemName: "playpause.fill")
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Play or pause")
                Button(intent: MusicNextIntent()) {
                    Image(systemName: "forward.fill")
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Next track")
            }
            .font(.system(size: 15, weight: .semibold))
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
    }
}

// MARK: - Widgets

@MainActor
enum DataWidgetConfiguration {
    static func make(source: DataSource, description: String, lockScreen: Bool = true) -> some WidgetConfiguration {
        // Plain Strings: an interpolated literal becomes a LocalizedStringKey, which crashed
        // the extension on iOS 27 (see CHANGELOG, Phase 1 fixes).
        let name: String = source.displayName
        let details: String = description
        let families: [WidgetFamily] = lockScreen
            ? [.systemSmall, .systemMedium, .accessoryRectangular]
            : [.systemSmall, .systemMedium]
        return StaticConfiguration(kind: source.widgetKind, provider: DataProvider(source: source)) { entry in
            DataWidgetView(entry: entry)
        }
        .configurationDisplayName(name)
        .description(details)
        .supportedFamilies(families)
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

struct ParkingWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .parking, description: "Where you parked, floor and bay, and how long ago.")
    }
}

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .prayer, description: "Next prayer with a live countdown (JAKIM e-Solat).")
    }
}

struct CommuteWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .commute, description: "Drive time to Work or Home, and your next event.")
    }
}

struct WeatherHazeWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .weather, description: "Temperature, rain today and the haze (API) level.")
    }
}

struct MusicWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .music, description: "Your recently played or featured Apple Music item.", lockScreen: false)
    }
}

struct LyricsWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .lyrics, description: "Synced lyrics of the Apple Music song that's playing; the current line is highlighted.")
    }
}

struct MapSnapshotWidget: Widget {
    var body: some WidgetConfiguration {
        DataWidgetConfiguration.make(source: .map, description: "Map of your parked car, or of your next commute.", lockScreen: false)
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

#Preview("Parking", as: .systemSmall) {
    ParkingWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .parking))
    DataEntry(date: .now, card: CarData.empty.card(for: .parking, at: .now))
}

#Preview("Prayer", as: .systemSmall) {
    PrayerTimesWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .prayer))
}

#Preview("Prayer medium", as: .systemMedium) {
    PrayerTimesWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .prayer))
}

#Preview("Commute", as: .systemMedium) {
    CommuteWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .commute))
    DataEntry(date: .now, card: CarData.empty.card(for: .commute, at: .now))
}

#Preview("Weather & Haze", as: .systemSmall) {
    WeatherHazeWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .weather))
}

#Preview("Map", as: .systemSmall) {
    MapSnapshotWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .map))
}

#Preview("Music", as: .systemMedium) {
    MusicWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .music))
    DataEntry(date: .now, card: CarData.empty.card(for: .music, at: .now))
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    PrayerTimesWidget()
} timeline: {
    DataEntry(date: .now, card: SampleData.card(for: .prayer))
}
