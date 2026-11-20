import CarKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct SlotEntry: TimelineEntry {
    let date: Date
    let slot: Int
    let content: SlotContent

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
        let items = SlotTimeline.items(slot: slot, state: SlotStore.live.load(), data: CarData.load(), now: now)
        let content = items.first?.content ?? .design(.starter(for: slot))
        completion(SlotEntry(date: now, slot: slot, content: content))
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
        let source = state.design(for: slot).source
        // Live sources refresh their cache first (throttled); text slots skip the data files.
        if let source, source.isLive {
            await LiveRefresher.refresh(source, now: now, mapSize: displaySize)
        }
        let data = source == nil ? CarData.empty : CarData.load()
        let items = SlotTimeline.items(slot: slot, state: state, data: data, now: now)
        var entries = items.map { item -> SlotEntry in
            // The map uses the PNG rendered for this slot's size.
            if source == .map, case .data = item.content {
                return SlotEntry(date: item.date, slot: slot, content: .data(data.mapCard(at: item.date, width: displaySize.width, height: displaySize.height)))
            }
            return SlotEntry(date: item.date, slot: slot, content: item.content)
        }
        if entries.isEmpty {
            entries = [.sample(slot: slot, date: now)]
        }
        // The app reloads this kind whenever the slot or its data changes. Text slots never need
        // a refresh; data slots follow their source's policy (e.g. weather every 30 minutes).
        guard let source else { return Timeline(entries: entries, policy: .never) }
        let flashEnd = state.flashUntil.flatMap { $0 > now ? $0 : nil }
        let reload = DataTimeline.reloadDate(for: source, data: data, now: flashEnd ?? now)
        return Timeline(entries: entries, policy: reload.map { TimelineReloadPolicy.after($0) } ?? TimelineReloadPolicy.atEnd)
    }
}

// MARK: - View

struct SlotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SlotEntry

    var body: some View {
        WidgetCard(style: entry.content.cardStyle, tint: entry.content.tint) {
            SlotContentView(slot: entry.slot, content: entry.content, isMedium: family == .systemMedium)
        }
        .widgetURL(URL(string: "peugeot408://slot/\(entry.slot)"))
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
