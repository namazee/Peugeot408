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
        state.migrate()
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
    /// Otherwise one entry per date on which the slot's content can change:
    /// - a text design: a single entry;
    /// - a data widget: the same dates as its dedicated widget (`DataTimeline.dates`);
    /// - a Studio design: its fields' dates (`DesignResolver.dates`);
    /// - rotations add their hour boundaries, and the seasonal takeover adds midnights.
    public static func items(
        slot: Int,
        state: SlotsState,
        data: CarData = .empty,
        studio: StudioState = .empty,
        now: Date,
        calendar: Calendar = .current
    ) -> [SlotTimelineItem] {
        let design = state.design(for: slot)
        let flashUntil = state.flashUntil.flatMap { $0 > now ? $0 : nil }
        let start = flashUntil ?? now
        let rotations = Array((design.rotations ?? []).prefix(SlotDesign.maxRotations))
        let seasonal = studio.seasonal.enabled && studio.seasonal.slot == slot

        var dates = Set<Date>()
        if design.effectiveLayout == .single {
            dates.formUnion(choiceDates(design.primaryChoice, data: data, studio: studio, from: start, calendar: calendar))
        } else {
            for card in design.layoutCards {
                dates.formUnion(choiceDates(card.primaryChoice, data: data, studio: studio, from: start, calendar: calendar))
            }
        }
        for rotation in rotations {
            dates.formUnion(choiceDates(rotation.choice, data: data, studio: studio, from: start, calendar: calendar))
            dates.formUnion(hourBoundaries([rotation.fromHour, rotation.toHour], from: start, calendar: calendar))
        }
        if seasonal {
            dates.formUnion(DayMath.refreshDates(from: start, days: 2, calendar: calendar))
            if let occasion = SeasonalCalendar.active(at: start, settings: studio.seasonal) {
                dates.formUnion(DesignResolver.dates(for: Templates.seasonal(occasion), data: data, from: start, calendar: calendar))
            }
        }
        let ordered = [start] + dates.filter { $0 > start }.sorted().prefix(70)

        var items: [SlotTimelineItem] = []
        if flashUntil != nil {
            items.append(SlotTimelineItem(date: now, content: flashContent(for: design)))
        }
        for date in ordered {
            let entryContent = content(at: date, design: design, rotations: rotations, seasonal: seasonal, data: data, studio: studio, calendar: calendar)
            items.append(SlotTimelineItem(date: date, content: entryContent))
        }
        return items
    }

    /// The content at `date`: the seasonal design, else a rotation whose hours match, else the main design.
    public static func content(at date: Date, design: SlotDesign, rotations: [SlotRotation], seasonal: Bool, data: CarData, studio: StudioState, calendar: Calendar = .current) -> SlotContent {
        if seasonal, let occasion = SeasonalCalendar.active(at: date, settings: studio.seasonal) {
            return .studio(DesignResolver.card(for: Templates.seasonal(occasion), data: data, studio: studio, at: date, calendar: calendar))
        }
        if design.effectiveLayout != .single {
            let parts = design.layoutCards.map { card in
                choiceContent(card.primaryChoice, data: data, studio: studio, at: date, calendar: calendar) ?? .design(card)
            }
            return .cards(design.effectiveLayout, parts)
        }
        let hour = calendar.component(.hour, from: date)
        if let rotation = rotations.first(where: { $0.contains(hour: hour) }),
           let content = choiceContent(rotation.choice, data: data, studio: studio, at: date, calendar: calendar) {
            return content
        }
        return choiceContent(design.primaryChoice, data: data, studio: studio, at: date, calendar: calendar) ?? .design(design)
    }

    static func choiceContent(_ choice: SlotChoice, data: CarData, studio: StudioState, at date: Date, calendar: Calendar) -> SlotContent? {
        if let id = choice.studioDesignID, let studioDesign = studio.design(id) {
            return .studio(DesignResolver.card(for: studioDesign, data: data, studio: studio, at: date, calendar: calendar))
        }
        if let source = choice.source {
            return .data(data.card(for: source, at: date, calendar: calendar))
        }
        return nil
    }

    static func choiceDates(_ choice: SlotChoice, data: CarData, studio: StudioState, from start: Date, calendar: Calendar) -> [Date] {
        if let id = choice.studioDesignID, let design = studio.design(id) {
            return DesignResolver.dates(for: design, data: data, from: start, calendar: calendar)
        }
        if let source = choice.source {
            return DataTimeline.dates(for: source, data: data, from: start, calendar: calendar)
        }
        return [start]
    }

    /// The next occurrences (within 24 h) of the given hours.
    static func hourBoundaries(_ hours: [Int], from start: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: start)
        var result: [Date] = []
        for hour in hours {
            for day in 0...1 {
                guard let base = calendar.date(byAdding: .day, value: day, to: today),
                      let date = calendar.date(bySettingHour: hour % 24, minute: 0, second: 0, of: base) else { continue }
                if date > start && date <= start.addingTimeInterval(24 * 3600) { result.append(date) }
            }
        }
        return result
    }

    /// The flash test: "Slot N ✓" for a single card, or one labelled card per part ("Slot 2 · Top ✓").
    public static func flashContent(for design: SlotDesign) -> SlotContent {
        let layout = design.effectiveLayout
        guard layout != .single else { return .flash }
        return .cards(layout, layout.cardNames.map { .flashCard($0) })
    }

    /// Every source a slot can show (main, rotations, Studio fields, seasonal), for live refreshes.
    public static func sources(slot: Int, state: SlotsState, studio: StudioState) -> Set<DataSource> {
        let design = state.design(for: slot)
        var result = Set<DataSource>()
        let choices = [design.primaryChoice] + (design.rotations ?? []).map { $0.choice } + design.layoutCards.map(\.primaryChoice)
        for choice in choices {
            if let source = choice.source { result.insert(source) }
            if let studioDesign = studio.design(choice.studioDesignID) { result.formUnion(studioDesign.sources) }
        }
        if studio.seasonal.enabled && studio.seasonal.slot == slot { result.insert(.prayer) }
        return result
    }

    /// True when the slot needs data files at all (a pure text slot doesn't).
    public static func needsData(slot: Int, state: SlotsState, studio: StudioState) -> Bool {
        let design = state.design(for: slot)
        return design.source != nil || design.studioDesignID != nil || !(design.rotations ?? []).isEmpty
            || (design.effectiveLayout != .single && design.layoutCards.contains { $0.source != nil || $0.studioDesignID != nil })
            || (studio.seasonal.enabled && studio.seasonal.slot == slot)
    }
}
