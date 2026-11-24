import Foundation

// One-tap templates and ready-made setups (spec §4b Templates, Phase 19).

/// What the slots showed before a setup was applied, so it can be undone.
public struct SetupUndo: Codable, Sendable, Equatable {
    public var setupName: String
    public var slots: [SlotDesign]
    public var panorama: PanoramaSettings?

    public init(setupName: String, slots: [SlotDesign], panorama: PanoramaSettings?) {
        self.setupName = setupName
        self.slots = slots
        self.panorama = panorama
    }
}

/// A Studio design (template) placed on a slot as a single card.
public enum TemplateUse {
    public static func slotDesign(showing design: CardDesign) -> SlotDesign {
        SlotDesign(value: design.name, title: "", symbol: "paintpalette.fill", studioDesignID: design.id)
    }

    /// True when using a template on this slot would replace a Split or Quad layout (the app warns first).
    public static func replacesCards(_ current: SlotDesign) -> Bool {
        current.effectiveLayout != .single
    }
}

/// The four ready-made setups: each fills all five slots in one tap.
public enum ReadySetup: String, CaseIterable, Identifiable, Sendable {
    case dailyDriver
    case nightCruise
    case roadTrip
    case ramadan

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dailyDriver: "Daily Driver"
        case .nightCruise: "Night Cruise"
        case .roadTrip: "Road Trip"
        case .ramadan: "Ramadan"
        }
    }

    public var symbol: String {
        switch self {
        case .dailyDriver: "car.fill"
        case .nightCruise: "moon.stars.fill"
        case .roadTrip: "map.fill"
        case .ramadan: "moon.haze.fill"
        }
    }

    public var summary: String {
        switch self {
        case .dailyDriver: "Prayer, weather, service, fuel, parking, road tax, commute and Touch 'n Go."
        case .nightCruise: "Neon look: a digital clock, weather, live OBD2, fuel, parking, prayer and music."
        case .roadTrip: "Commute, weather, fuel, Touch 'n Go, parking, service, map and prayer."
        case .ramadan: "Iftar countdown, Hijri date, prayer, weather, service and fuel."
        }
    }

    /// The Studio designs this setup uses (new ones are saved; existing ones with the same template and name are reused).
    public var designs: [CardDesign] {
        switch self {
        case .nightCruise: [Templates.make(.clockDigital)]
        case .ramadan: [Templates.seasonal(.ramadan), Templates.make(.hijriDate)]
        case .dailyDriver, .roadTrip: []
        }
    }

    /// The five slot designs. `designs` are the Studio designs to point at (same order as `designs`).
    public func slots(using designs: [CardDesign]) -> [SlotDesign] {
        func split(_ slot: Int, _ top: DataSource, _ bottom: DataSource, look: CardLook? = nil) -> SlotDesign {
            var design = SlotDesign.starter(for: slot)
            design.layout = .split
            design.cards = [.card(top), .card(bottom)]
            design.look = look
            return design
        }
        func single(_ source: DataSource, look: CardLook? = nil) -> SlotDesign {
            var design = SlotDesign.card(source)
            design.look = look
            return design
        }
        func studio(_ index: Int, look: CardLook? = nil) -> SlotDesign {
            guard designs.indices.contains(index) else { return .starter(for: 1) }
            var design = TemplateUse.slotDesign(showing: designs[index])
            design.look = look
            return design
        }
        switch self {
        case .dailyDriver:
            return [split(1, .prayer, .weather), split(2, .service, .fuel), split(3, .parking, .renewals), single(.commute), single(.tng)]
        case .nightCruise:
            return [studio(0, look: .neon), split(2, .weather, .obd, look: .neon), split(3, .fuel, .parking, look: .neon),
                    single(.prayer, look: .neon), single(.music, look: .neon)]
        case .roadTrip:
            return [split(1, .commute, .weather), split(2, .fuel, .tng), split(3, .parking, .service), single(.map), single(.prayer)]
        case .ramadan:
            return [studio(0), studio(1), split(3, .prayer, .weather), single(.service), single(.fuel)]
        }
    }

    /// Reuses saved designs that match this setup's templates; returns the designs to point at and the ones to save.
    public func resolveDesigns(existing: [CardDesign]) -> (use: [CardDesign], new: [CardDesign]) {
        var use: [CardDesign] = []
        var new: [CardDesign] = []
        for wanted in designs {
            if let saved = existing.first(where: { $0.template == wanted.template && $0.name == wanted.name && $0.canvas == wanted.canvas }) {
                use.append(saved)
            } else {
                use.append(wanted)
                new.append(wanted)
            }
        }
        return (use, new)
    }
}

public extension SlotsState {
    /// Fills all five slots with a setup, keeping what was there for "Undo setup". Panorama is turned
    /// off, because it would cover Slots 1–3.
    mutating func apply(_ setup: ReadySetup, designs: [CardDesign]) {
        normalize()
        undoSetup = SetupUndo(setupName: setup.displayName, slots: slots, panorama: panorama)
        slots = setup.slots(using: designs)
        normalize()
        if panorama?.enabled == true { panorama?.enabled = false }
    }

    /// Brings back the slots from before the last setup. False when there is nothing to undo.
    @discardableResult
    mutating func undoLastSetup() -> Bool {
        guard let undo = undoSetup else { return false }
        slots = undo.slots
        panorama = undo.panorama
        undoSetup = nil
        normalize()
        return true
    }
}
