import CarKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct SlotEntry: TimelineEntry {
    let date: Date
    let slot: Int
    let content: SlotContent
    /// The slot's own look, or the app-wide one.
    var look: CardLook = .bold

    /// Settings → Appearance, overridden by the slot's own choice.
    static func look(slot: Int, state: SlotsState) -> CardLook {
        state.design(for: slot).look ?? AppearanceStore.settings().load().look
    }

    static func sample(slot: Int, date: Date = .now) -> SlotEntry {
        SlotEntry(date: date, slot: slot, content: .design(.starter(for: slot)))
    }
}

struct SlotProvider: TimelineProvider {
    let slot: Int

    func placeholder(in context: Context) -> SlotEntry {
        .sample(slot: slot)
    }

    func getSnapshot(in context: Context, completion: @escaping (SlotEntry) -> Void) {
        if context.isPreview {
            completion(.sample(slot: slot))
            return
        }
        let now = Date()
        let items = SlotTimeline.items(slot: slot, state: SlotStore.live.load(), data: CarData.load(), studio: StudioStores.studio().load(), now: now)
        let state = SlotStore.live.load()
        let content = items.first?.content ?? .design(.starter(for: slot))
        completion(SlotEntry(date: now, slot: slot, content: content, look: SlotEntry.look(slot: slot, state: state)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SlotEntry>) -> Void) {
        let slot = slot
        let size = context.displaySize
        let reply = CompletionBox(completion)
        Task {
            reply.call(await Self.timeline(slot: slot, displaySize: size))
        }
    }

    static func timeline(slot: Int, displaySize: CGSize) async -> Timeline<SlotEntry> {
        let now = Date()
        let state = SlotStore.live.load()
        let studio = StudioStores.studio().load()
        let sources = SlotTimeline.sources(slot: slot, state: state, studio: studio)
        // Live sources refresh their cache first (each throttles itself); text slots skip the data files.
        for source in sources where source.isLive {
            await LiveRefresher.refresh(source, now: now, mapSize: displaySize)
        }
        let needsData = SlotTimeline.needsData(slot: slot, state: state, studio: studio)
        let data = needsData ? CarData.load() : CarData.empty
        let items = SlotTimeline.items(slot: slot, state: state, data: data, studio: studio, now: now)
        let look = SlotEntry.look(slot: slot, state: state)
        var entries = items.map { item -> SlotEntry in
            // The map uses the PNG rendered for this slot's size.
            if case .data(let card) = item.content, card.source == .map {
                return SlotEntry(date: item.date, slot: slot, content: .data(data.mapCard(at: item.date, width: displaySize.width, height: displaySize.height)), look: look)
            }
            return SlotEntry(date: item.date, slot: slot, content: item.content, look: look)
        }
        if entries.isEmpty {
            entries = [.sample(slot: slot, date: now)]
        }
        // The app reloads this kind whenever the slot, its designs or its data change. Text slots
        // never need a refresh; otherwise ask again after the soonest source policy, or at the end.
        guard needsData else { return Timeline(entries: entries, policy: .never) }
        let flashEnd = state.flashUntil.flatMap { $0 > now ? $0 : nil }
        let reload = sources.compactMap { DataTimeline.reloadDate(for: $0, data: data, now: flashEnd ?? now) }.min()
        return Timeline(entries: entries, policy: reload.map { TimelineReloadPolicy.after($0) } ?? TimelineReloadPolicy.atEnd)
    }
}

// MARK: - View

struct SlotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins
    let entry: SlotEntry

    var body: some View {
        content
            .environment(\.cardLook, entry.look)
            .widgetURL(URL(string: "peugeot408://slot/\(entry.slot)"))
    }

    @ViewBuilder
    private var content: some View {
        if case .studio(let card) = entry.content {
            DesignView(card: card, showsBackground: false)
                .containerBackground(for: .widget) {
                    DesignBackgroundView(background: card.design.background, card: card)
                }
        } else if case .panorama(let card, let part) = entry.content {
            // This slot's third of the Panorama hero, edge to edge.
            Color.clear
                .containerBackground(for: .widget) {
                    PanoramaSlice(card: card, part: part)
                }
        } else {
            WidgetCard(style: entry.content.cardStyle, paint: entry.content.paint) {
                SlotContentView(slot: entry.slot, content: entry.content, isMedium: family == .systemMedium)
                    // Split / Quad cards use most of the tall CarPlay column; single content keeps the system margins.
                    .padding(entry.content.isCards ? EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7) : margins)
            }
        }
    }
}

// MARK: - Widgets (one kind per slot)

@MainActor
enum CarSlotConfiguration {
    static func make(slot: Int) -> some WidgetConfiguration {
        // Plain Strings on purpose: an interpolated literal here becomes a LocalizedStringKey,
        // and WidgetKit on iOS 27 hits an assertion on it, crashing the extension at launch
        // so no Car Slot shows in the widget gallery or CarPlay.
        let name: String = "Car Slot \(slot)"
        let details: String = "Shows whatever you assign to slot \(slot) in the Peugeot408 app."
        return StaticConfiguration(kind: SlotKind.kind(for: slot), provider: SlotProvider(slot: slot)) { entry in
            SlotWidgetView(entry: entry)
        }
        .configurationDisplayName(name)
        .description(details)
        .supportedFamilies([.systemSmall, .systemMedium])
        // Studio designs fill the whole widget; other content adds the margins back itself.
        .contentMarginsDisabled()
    }
}

struct CarSlot1: Widget {
    var body: some WidgetConfiguration { CarSlotConfiguration.make(slot: 1) }
}

struct CarSlot2: Widget {
    var body: some WidgetConfiguration { CarSlotConfiguration.make(slot: 2) }
}

struct CarSlot3: Widget {
    var body: some WidgetConfiguration { CarSlotConfiguration.make(slot: 3) }
}

struct CarSlot4: Widget {
    var body: some WidgetConfiguration { CarSlotConfiguration.make(slot: 4) }
}

struct CarSlot5: Widget {
    var body: some WidgetConfiguration { CarSlotConfiguration.make(slot: 5) }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CarSlot1()
} timeline: {
    SlotEntry.sample(slot: 1)
    SlotEntry(date: .now, slot: 1, content: .flash)
    SlotEntry(
        date: .now,
        slot: 1,
        content: .design(SlotDesign(value: "1,240 km", title: "Oil service", symbol: "wrench.and.screwdriver.fill"))
    )
}

#Preview("Medium", as: .systemMedium) {
    CarSlot3()
} timeline: {
    SlotEntry.sample(slot: 3)
    SlotEntry(date: .now, slot: 3, content: .flash)
}
