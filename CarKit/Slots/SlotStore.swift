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
    /// Otherwise: just the design.
    public static func items(slot: Int, state: SlotsState, now: Date) -> [SlotTimelineItem] {
        let design = state.design(for: slot)
        if let until = state.flashUntil, until > now {
            return [
                SlotTimelineItem(date: now, content: .flash),
                SlotTimelineItem(date: until, content: .design(design)),
            ]
        }
        return [SlotTimelineItem(date: now, content: .design(design))]
    }
}
