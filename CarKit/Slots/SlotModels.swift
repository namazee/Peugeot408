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

    public init(value: String, title: String, symbol: String, style: SlotStyle = .dark, source: DataSource? = nil, studioDesignID: UUID? = nil, rotations: [SlotRotation]? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
        self.style = style
        self.source = source
        self.studioDesignID = studioDesignID
        self.rotations = rotations
    }

    /// Name shown in the app's slot list (Studio design names are looked up by the app).
    public var summary: String {
        if studioDesignID != nil { return "Studio design" }
        return source?.displayName ?? value
    }

    /// This design without its rotations: what shows outside the rotation hours.
    public var primaryChoice: SlotChoice {
        SlotChoice(source: source, studioDesignID: studioDesignID)
    }

    public static let maxRotations = 2

    /// Longest big value that still reads comfortably at a glance on the CarPlay small size.
    public static let maxGlanceableValueLength = 10

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

    public var cardStyle: CardStyle {
        switch self {
        case .design(let design): design.style.cardStyle
        case .data, .studio: .standard
        case .flash: .accentFill
        }
    }
}

/// Everything the five Car Slot widgets need, stored as JSON in the App Group.
public struct SlotsState: Codable, Sendable, Equatable {
    public static let currentVersion = 1
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
        SlotsState(slots: slotNumbers.map(SlotDesign.starter(for:)))
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
