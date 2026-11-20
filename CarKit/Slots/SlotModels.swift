import Foundation

/// Background choice for a simple slot design.
public enum SlotStyle: String, Codable, CaseIterable, Sendable {
    case dark
    case accent

    public var displayName: String {
        switch self {
        case .dark: "Dark"
        case .accent: "Blue"
        }
    }

    public var cardStyle: CardStyle {
        switch self {
        case .dark: .standard
        case .accent: .accentFill
        }
    }
}

/// How a slot widget is divided (spec §4b, split-card layouts). The 408 shows 3 tall columns,
/// so splitting a slot puts more information on the screen.
public enum SlotLayout: String, Codable, Sendable, CaseIterable, Identifiable {
    /// One card: the original behaviour.
    case single
    /// Two cards stacked top / bottom (the default).
    case split
    /// 2 × 2 cards, icon + value only.
    case quad

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .single: "Single"
        case .split: "Split"
        case .quad: "Quad"
        }
    }

    public var cardCount: Int {
        switch self {
        case .single: 1
        case .split: 2
        case .quad: 4
        }
    }

    /// Card names, for the editor and the flash test.
    public var cardNames: [String] {
        switch self {
        case .single: ["Card"]
        case .split: ["Top", "Bottom"]
        case .quad: ["Top left", "Top right", "Bottom left", "Bottom right"]
        }
    }
}

/// A slot design: either a simple text card (one big value, a short label and an SF Symbol)
/// or, when `source` is set, one of the live data widgets.
public struct SlotDesign: Codable, Sendable, Equatable, Hashable {
    public var value: String
    public var title: String
    public var symbol: String
    public var style: SlotStyle
    /// When set, the slot shows this data widget instead of the text. Missing in Phase 1 files (decodes as nil).
    public var source: DataSource?
    /// When set, the slot shows this Studio design (Phase 5). Takes priority over `source`.
    public var studioDesignID: UUID?
    /// Up to 2 more designs shown during set hours (3 in total with this one). Nil in older files.
    public var rotations: [SlotRotation]?
    /// Single / Split / Quad. Nil in older files (= single).
    public var layout: SlotLayout?
    /// The cards of a Split or Quad layout, each with its own data source, Studio design or text.
    public var cards: [SlotDesign]?
    /// A picture shown instead of the icon (path in the App Group, e.g. "slot-images/x.png", or
    /// "mycar.png" for the live My Car photo). Nil in older files.
    public var imageFile: String?
    /// This slot's own look (Bold / Neon); nil = the app-wide look from Settings → Appearance.
    public var look: CardLook?

    public init(value: String, title: String, symbol: String, style: SlotStyle = .dark, source: DataSource? = nil, studioDesignID: UUID? = nil, rotations: [SlotRotation]? = nil, layout: SlotLayout? = nil, cards: [SlotDesign]? = nil, imageFile: String? = nil, look: CardLook? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
        self.style = style
        self.source = source
        self.studioDesignID = studioDesignID
        self.rotations = rotations
        self.layout = layout
        self.cards = cards
        self.imageFile = imageFile
        self.look = look
    }

    /// The picture's file, if one is set.
    public var imageURL: URL? {
        imageFile.map { AppGroup.containerURL.appending(path: $0, directoryHint: .notDirectory) }
    }

    /// The file name used for the live My Car photo.
    public static let myCarImageFile = "mycar.png"

    public var effectiveLayout: SlotLayout { layout ?? .single }

    /// A card showing a data source.
    public static func card(_ source: DataSource) -> SlotDesign {
        SlotDesign(value: source.displayName, title: "", symbol: source.symbol, source: source)
    }

    /// Cards used to fill a layout when it gains cards.
    static let fillerSources: [DataSource] = [.prayer, .renewals, .service, .fuel, .weather, .parking, .tng, .commute]

    /// The card at `index` (padded with sensible defaults, never empty).
    public func card(_ index: Int) -> SlotDesign {
        let list = cards ?? []
        if list.indices.contains(index) { return list[index] }
        return .card(Self.fillerSources[index % Self.fillerSources.count])
    }

    /// Exactly the cards the current layout shows.
    public var layoutCards: [SlotDesign] {
        (0..<effectiveLayout.cardCount).map(card)
    }

    /// Changes the layout, keeping existing cards and filling new ones.
    public mutating func setLayout(_ newLayout: SlotLayout) {
        if newLayout != .single, (cards ?? []).isEmpty, source != nil || studioDesignID != nil {
            // The single design becomes the first card.
            cards = [SlotDesign(value: value, title: title, symbol: symbol, style: style, source: source, studioDesignID: studioDesignID)]
        }
        layout = newLayout
        if newLayout != .single {
            let current = self
            cards = (0..<newLayout.cardCount).map { current.card($0) }
        }
    }

    /// Name shown in the app's slot list (Studio design names are looked up by the app).
    public var summary: String {
        if effectiveLayout != .single {
            return layoutCards.map(\.cardSummary).joined(separator: " / ")
        }
        return cardSummary
    }

    var cardSummary: String {
        if studioDesignID != nil { return "Studio design" }
        if let source { return source.displayName }
        if value.trimmingCharacters(in: .whitespaces).isEmpty, imageFile != nil {
            return imageFile == Self.myCarImageFile ? "My Car picture" : "Picture"
        }
        return value
    }

    /// This design without its rotations: what shows outside the rotation hours.
    public var primaryChoice: SlotChoice {
        SlotChoice(source: source, studioDesignID: studioDesignID)
    }

    public static let maxRotations = 2

    /// Longest big value that still reads comfortably at a glance on the CarPlay small size.
    public static let maxGlanceableValueLength = 10

    /// Spec default setup: Slot 1 = Next prayer / Road tax, Slot 2 = Service / Fuel, Slot 3 = Weather / Parking,
    /// all Split. Slots 4 and 5 stay single, for stacking behind the visible columns.
    public static func splitDefault(for slot: Int) -> SlotDesign? {
        let pairs: [Int: (DataSource, DataSource)] = [1: (.prayer, .renewals), 2: (.service, .fuel), 3: (.weather, .parking)]
        guard let pair = pairs[slot] else { return nil }
        var design = starter(for: slot)
        design.layout = .split
        design.cards = [.card(pair.0), .card(pair.1)]
        return design
    }

    public static func starter(for slot: Int) -> SlotDesign {
        switch slot {
        case 1: SlotDesign(value: "408 GT", title: "Selamat jalan", symbol: "car.side.fill", style: .accent)
        case 2: SlotDesign(value: "Slot 2", title: "Set in app", symbol: "fuelpump.fill")
        case 3: SlotDesign(value: "Slot 3", title: "Set in app", symbol: "wrench.and.screwdriver.fill")
        case 4: SlotDesign(value: "Slot 4", title: "Set in app", symbol: "moon.stars.fill")
        default: SlotDesign(value: "Slot \(slot)", title: "Set in app", symbol: "star.fill")
        }
    }

    /// Icons offered in the simple slot editor.
    public static let symbolChoices: [String] = [
        "car.side.fill", "car.fill", "fuelpump.fill", "wrench.and.screwdriver.fill",
        "gauge.with.dots.needle.67percent", "speedometer", "parkingsign.circle.fill", "map.fill",
        "moon.stars.fill", "sun.max.fill", "cloud.rain.fill", "leaf.fill",
        "clock.fill", "calendar", "creditcard.fill", "bolt.fill",
        "house.fill", "building.2.fill", "music.note", "photo.fill",
        "heart.fill", "star.fill", "flag.checkered", "hand.wave.fill",
    ]
}

/// What a rotation shows: a data widget or a Studio design.
public struct SlotChoice: Codable, Sendable, Equatable, Hashable {
    public var source: DataSource?
    public var studioDesignID: UUID?

    public init(source: DataSource? = nil, studioDesignID: UUID? = nil) {
        self.source = source
        self.studioDesignID = studioDesignID
    }
}

/// "Show this between `fromHour` and `toHour`" (24 h clock, `toHour` exclusive; wraps past midnight,
/// e.g. 18 to 6). Example: Prayer Times 5-7 and 18-21, Service Tracker the rest of the day.
public struct SlotRotation: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var choice: SlotChoice
    public var fromHour: Int
    public var toHour: Int

    public init(id: UUID = UUID(), choice: SlotChoice, fromHour: Int, toHour: Int) {
        self.id = id
        self.choice = choice
        self.fromHour = fromHour
        self.toHour = toHour
    }

    public func contains(hour: Int) -> Bool {
        if fromHour == toHour { return true }
        if fromHour < toHour { return hour >= fromHour && hour < toHour }
        return hour >= fromHour || hour < toHour
    }

    public var label: String { String(format: "%02d:00-%02d:00", fromHour, toHour) }
}

/// What a slot widget draws for one timeline entry.
public enum SlotContent: Sendable, Equatable {
    case design(SlotDesign)
    /// A live data widget (Service, Fuel, Renewals, Touch 'n Go).
    case data(DataCard)
    /// A Studio design with its data resolved.
    case studio(StudioCard)
    /// Identifying "Slot N ✓" card used by the "Test: flash all slots" button.
    case flash
    /// Split / Quad: one content per card.
    indirect case cards(SlotLayout, [SlotContent])
    /// Flash label for one card, e.g. "Top" → "Slot 2 · Top ✓".
    case flashCard(String)

    public var cardStyle: CardStyle {
        switch self {
        case .design(let design): design.style.cardStyle
        case .data, .studio, .cards: .standard
        case .flash, .flashCard: .accentFill
        }
    }
}

/// Everything the five Car Slot widgets need, stored as JSON in the App Group.
public struct SlotsState: Codable, Sendable, Equatable {
    /// 2: split-card layouts (slots 1–3 move to the new default setup once).
    public static let currentVersion = 2
    public static let slotCount = 5
    public static let slotNumbers = Array(1...slotCount)

    public var version: Int
    public var slots: [SlotDesign]
    /// While set and in the future, every slot shows its identifying flash card.
    public var flashUntil: Date?

    public init(version: Int = SlotsState.currentVersion, slots: [SlotDesign], flashUntil: Date? = nil) {
        self.version = version
        self.slots = slots
        self.flashUntil = flashUntil
        normalize()
    }

    public static var starter: SlotsState {
        SlotsState(slots: slotNumbers.map { SlotDesign.splitDefault(for: $0) ?? SlotDesign.starter(for: $0) })
    }

    /// Upgrades older files: slots 1–3 take the split default setup (spec §4b), slots 4–5 are kept.
    public mutating func migrate() {
        normalize()
        guard version < 2 else { return }
        for slot in 1...3 {
            if let design = SlotDesign.splitDefault(for: slot) { setDesign(design, for: slot) }
        }
        version = 2
    }

    /// Design for a 1-based slot number; never traps on bad input.
    public func design(for slot: Int) -> SlotDesign {
        let index = slot - 1
        return slots.indices.contains(index) ? slots[index] : .starter(for: slot)
    }

    public mutating func setDesign(_ design: SlotDesign, for slot: Int) {
        normalize()
        let index = slot - 1
        guard slots.indices.contains(index) else { return }
        slots[index] = design
    }

    public func isFlashing(at date: Date) -> Bool {
        guard let flashUntil else { return false }
        return flashUntil > date
    }

    /// Reorders slots with the same semantics as SwiftUI's `move(fromOffsets:toOffset:)`.
    public mutating func moveSlots(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.filter { slots.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.sorted().map { slots[$0] }
        var remaining = slots.enumerated().filter { !valid.contains($0.offset) }.map(\.element)
        let shift = valid.filter { $0 < destination }.count
        let insertAt = min(max(destination - shift, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        slots = remaining
    }

    /// 1-based slot numbers whose design differs from `other`.
    public func changedSlots(comparedTo other: SlotsState) -> [Int] {
        Self.slotNumbers.filter { design(for: $0) != other.design(for: $0) }
    }

    /// Pads or trims to exactly `slotCount` slots.
    public mutating func normalize() {
        if slots.count > Self.slotCount {
            slots = Array(slots.prefix(Self.slotCount))
        }
        while slots.count < Self.slotCount {
            slots.append(.starter(for: slots.count + 1))
        }
    }
}

/// Widget kind strings for the five slot widgets.
public enum SlotKind {
    public static let prefix = "CarSlot"

    public static func kind(for slot: Int) -> String { "\(prefix)\(slot)" }

    public static var all: [String] { SlotsState.slotNumbers.map(kind(for:)) }
}
