import Foundation

/// Reads and writes `slots.json` in the App Group container.
public struct SlotStore: Sendable {
    public let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appending(path: "slots.json", directoryHint: .notDirectory)
    }

    public static var live: SlotStore { SlotStore(directory: AppGroup.containerURL) }

    /// Always returns a usable state: missing or unreadable files fall back to the starter designs.
    public func load() -> SlotsState {
        guard
            let data = try? Data(contentsOf: fileURL),
            var state = try? JSONDecoder().decode(SlotsState.self, from: data)
        else {
            return .starter
        }
        state.normalize()
        return state
    }

    public func save(_ state: SlotsState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}

/// One timeline entry's worth of slot content.
public struct SlotTimelineItem: Sendable, Equatable {
    public let date: Date
    public let content: SlotContent

    public init(date: Date, content: SlotContent) {
        self.date = date
        self.content = content
    }
}

/// Pure timeline logic for a slot widget, kept here so it is unit-tested.
public enum SlotTimeline {
    /// While a flash test is running: the flash card now, then the real design when it ends.
    /// A text design is a single entry. A data design gets the same entry dates as its dedicated
    /// widget (`DataTimeline.dates`), e.g. each midnight for day counts or each prayer time.
    public static func items(
        slot: Int,
        state: SlotsState,
        data: CarData = .empty,
        now: Date,
        calendar: Calendar = .current
    ) -> [SlotTimelineItem] {
        let design = state.design(for: slot)
        let flashUntil = state.flashUntil.flatMap { $0 > now ? $0 : nil }
        let start = flashUntil ?? now

        var items: [SlotTimelineItem] = []
        if flashUntil != nil {
            items.append(SlotTimelineItem(date: now, content: .flash))
        }
        if let source = design.source {
            let dates = DataTimeline.dates(for: source, data: data, from: start, calendar: calendar)
            items += dates.map { SlotTimelineItem(date: $0, content: .data(data.card(for: source, at: $0, calendar: calendar))) }
        } else {
            items.append(SlotTimelineItem(date: start, content: .design(design)))
        }
        return items
    }
}
