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
        let items = SlotTimeline.items(slot: slot, state: SlotStore.live.load(), now: now)
        let content = items.first?.content ?? .design(.starter(for: slot))
        completion(SlotEntry(date: now, slot: slot, content: content))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SlotEntry>) -> Void) {
        let now = Date()
        let items = SlotTimeline.items(slot: slot, state: SlotStore.live.load(), now: now)
        var entries = items.map { SlotEntry(date: $0.date, slot: slot, content: $0.content) }
        if entries.isEmpty {
            entries = [.sample(slot: slot, date: now)]
        }
        // The app reloads this kind whenever the slot changes, so no periodic refresh is needed.
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: - View

struct SlotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SlotEntry

    var body: some View {
        WidgetCard(style: entry.content.cardStyle) {
            SlotContentView(slot: entry.slot, content: entry.content, isMedium: family == .systemMedium)
        }
        .widgetURL(URL(string: "peugeot408://slot/\(entry.slot)"))
    }
}

// MARK: - Widgets (one kind per slot)

@MainActor
enum CarSlotConfiguration {
    static func make(slot: Int) -> some WidgetConfiguration {
        StaticConfiguration(kind: SlotKind.kind(for: slot), provider: SlotProvider(slot: slot)) { entry in
            SlotWidgetView(entry: entry)
        }
        .configurationDisplayName("Car Slot \(slot)")
        .description("Shows whatever you assign to slot \(slot) in the Peugeot408 app.")
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
