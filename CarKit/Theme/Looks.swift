import SwiftUI
import WidgetKit

// Widget styles (spec §3 "Widget styles"): two complete looks, Bold and Neon, for every widget,
// split/quad card and the app's previews. Colours come from theme/tokens.json (ThemeTokens.bold / .neon).

/// The look of the widgets and cards.
public enum CardLook: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Full-colour tiles whose colour follows the state; one huge centred number.
    case bold
    /// Near-black with glowing values, rings and gauges.
    case neon

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bold: "Bold"
        case .neon: "Neon"
        }
    }

    public var summary: String {
        switch self {
        case .bold: "Full-colour tiles that turn amber or red when something's due."
        case .neon: "Dark tiles with glowing numbers, rings and gauges."
        }
    }

    /// The app's tint for this look.
    public var appTint: Color {
        switch self {
        case .bold: Theme.accent
        case .neon: Color(hex: 0x22D3EE)
        }
    }
}

public extension EnvironmentValues {
    /// Set at the root of the app and of each widget (app-wide look, or the slot's own).
    @Entry var cardLook: CardLook = .bold
}

/// `appearance.json`: the app-wide look.
public struct AppearanceSettings: Codable, Sendable, Equatable {
    public var look: CardLook

    public init(look: CardLook = .bold) {
        self.look = look
    }

    public static let `default` = AppearanceSettings()
}

public enum AppearanceStore {
    public static let fileName = "appearance.json"

    public static func settings(in directory: URL = AppGroup.containerURL) -> JSONFileStore<AppearanceSettings> {
        JSONFileStore(directory: directory, fileName: fileName) { .default }
    }
}

/// What colours a card: its data source and, when something needs attention, a state colour.
public struct CardPaint: Sendable, Equatable {
    public var source: DataSource?
    /// Amber / red when due, the AQI band colour for haze.
    public var stateHex: UInt32?

    public init(source: DataSource? = nil, stateHex: UInt32? = nil) {
        self.source = source
        self.stateHex = stateHex
    }

    public static let plain = CardPaint()

    /// Bold: the tile colour. Neon: the glow colour.
    public func hex(_ look: CardLook) -> UInt32 {
        if let stateHex { return stateHex }
        guard let source else { return look == .bold ? Theme.Hex.accent : ThemeTokens.glow }
        switch look {
        case .bold: return ThemeTokens.bold[source.rawValue] ?? Theme.Hex.accent
        case .neon: return ThemeTokens.neon[source.rawValue] ?? ThemeTokens.glow
        }
    }

    public func color(_ look: CardLook) -> Color { Color(hex: hex(look)) }
}

public extension Urgency {
    /// Amber / red, nil when fine.
    var stateHex: UInt32? {
        switch self {
        case .ok: nil
        case .dueSoon: Theme.Hex.dueSoon
        case .urgent: Theme.Hex.overdue
        }
    }
}

public extension DataCard {
    var paint: CardPaint {
        if case .weather(let s) = self, let air = s.air, air.band.urgency != .ok {
            return CardPaint(source: .weather, stateHex: air.band.hex)
        }
        return CardPaint(source: source, stateHex: urgency.stateHex)
    }
}

public extension SlotContent {
    var paint: CardPaint {
        switch self {
        case .data(let card): card.paint
        case .design(let design): design.paint
        default: .plain
        }
    }
}

// MARK: - Face: one model for every data card

/// The glanceable core of a data card, drawn by `FaceView` in either look.
public struct CardFace: Sendable, Equatable {
    public enum Meter: Sendable, Equatable {
        /// Full ring (how much is left).
        case ring
        /// 240° gauge (boost, fuel economy).
        case gauge
    }

    public struct Row: Sendable, Equatable {
        public let name: String
        public let value: String
        public let urgency: Urgency
        public let isCurrent: Bool

        public init(_ name: String, _ value: String, urgency: Urgency = .ok, isCurrent: Bool = false) {
            self.name = name
            self.value = value
            self.urgency = urgency
            self.isCurrent = isCurrent
        }
    }

    public let symbol: String
    public let label: String
    public let value: CompactValue
    public let unit: String?
    public let detail: String?
    /// 0…1 for the ring or gauge; nil draws none.
    public let progress: Double?
    public let meter: Meter
    public let urgency: Urgency
    /// Extra lines for the medium size.
    public let rows: [Row]

    public init(symbol: String, label: String, value: CompactValue, unit: String? = nil, detail: String? = nil,
                progress: Double? = nil, meter: Meter = .ring, urgency: Urgency = .ok, rows: [Row] = []) {
        self.symbol = symbol
        self.label = label
        self.value = value
        self.unit = unit
        self.detail = detail
        self.progress = progress.map { min(max($0, 0), 1) }
        self.meter = meter
        self.urgency = urgency
        self.rows = rows
    }
}

public extension DataCard {
    /// Nil for the image cards (map, photos, music) and when there's no data yet (they draw their own empty state).
    var face: CardFace? {
        switch self {
        case .service(let s):
            guard let top = s.lines.first else { return nil }
            let progress: Double? = {
                guard let interval = top.intervalKm, interval > 0, let left = top.kmLeft else { return nil }
                return Double(left) / Double(interval)
            }()
            let value: String, unit: String?
            if let km = top.kmLeft {
                value = abs(km).formatted(.number)
                unit = km <= 0 ? "km over" : "km"
            } else if let days = top.daysLeft {
                value = "\(abs(days))"
                unit = days < 0 ? "days late" : "days"
            } else {
                value = "--"
                unit = nil
            }
            return CardFace(symbol: top.symbol, label: top.name, value: .text(value), unit: unit,
                            detail: top.isOverdue ? "Overdue" : (top.kmLeft != nil ? top.daysLeft.map { "\(CarFormat.days($0)) left" } : "left"),
                            progress: progress ?? (top.isOverdue ? 0 : nil), urgency: top.urgency,
                            rows: s.lines.map { CardFace.Row($0.name, $0.compactText, urgency: $0.urgency) })

        case .fuel(let s):
            guard s.hasFills else { return nil }
            let average = s.averageKmPerLitre
            let best = max(s.bestKmPerLitre ?? 0, average ?? 0, 1)
            return CardFace(symbol: "fuelpump.fill", label: "Fuel avg", value: .text(average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "--"),
                            unit: "km/L", detail: s.lastPricePerLitre.map { "\(CarFormat.rm($0))/L" },
                            progress: average.map { $0 / best }, meter: .gauge,
                            rows: [
                                CardFace.Row("Last price", s.lastPricePerLitre.map { "\(CarFormat.rm($0))/L" } ?? "--"),
                                CardFace.Row("This month", CarFormat.rm(s.spentThisMonth, decimals: 0)),
                                CardFace.Row("Best", s.bestKmPerLitre.map(CarFormat.kmPerLitre) ?? "--"),
                            ])

        case .renewals(let s):
            guard let top = s.lines.first else { return nil }
            return CardFace(symbol: top.symbol, label: top.name, value: .text(top.countText), unit: top.unitText,
                            detail: top.expiry.formatted(.dateTime.day().month(.abbreviated)),
                            progress: Double(max(top.daysLeft, 0)) / 365, urgency: top.urgency,
                            rows: s.lines.map { CardFace.Row($0.name, "\($0.countText) \($0.unitText)", urgency: $0.urgency) })

        case .tng(let s):
            guard let balance = s.balance else { return nil }
            return CardFace(symbol: "creditcard.fill", label: "Touch 'n Go", value: .text(CarFormat.rm(balance)),
                            detail: s.isLow ? "Top up soon" : "Top up below \(CarFormat.rm(s.threshold, decimals: 0))",
                            progress: balance / max(s.threshold * 5, 1), urgency: s.isLow ? .dueSoon : .ok,
                            rows: [CardFace.Row("Warn below", CarFormat.rm(s.threshold, decimals: 0)),
                                   CardFace.Row("Status", s.isLow ? "Top up soon" : "OK", urgency: s.isLow ? .dueSoon : .ok)])

        case .parking(let s):
            guard let spot = s.spot else { return nil }
            let since = spot.savedAt.formatted(date: .omitted, time: .shortened)
            return CardFace(symbol: "parkingsign.circle.fill", label: spot.detailLine.isEmpty ? "Parked" : spot.detailLine,
                            value: .text(spot.title), detail: "Since \(since)",
                            rows: [CardFace.Row("Since", since), CardFace.Row("Spot", spot.detailLine.isEmpty ? "--" : spot.detailLine)])

        case .prayer(let s):
            guard let next = s.next else { return nil }
            let time = next.time.formatted(date: .omitted, time: .shortened)
            let progress: Double? = s.current.map { current in
                let span = next.time.timeIntervalSince(current.time)
                return span > 0 ? 1 - min(max(Date.now.timeIntervalSince(current.time) / span, 0), 1) : 1
            }
            return CardFace(symbol: next.prayer.symbol, label: "\(next.prayer.displayName) \(time)", value: .timer(next.time),
                            detail: s.zoneCode, progress: progress,
                            rows: s.today.filter { $0.prayer != .syuruk }.map {
                                CardFace.Row($0.prayer.displayName, $0.time.formatted(date: .omitted, time: .shortened), isCurrent: $0 == next)
                            })

        case .commute(let s):
            guard let destination = s.destination, !s.needsSetup else { return nil }
            var rows: [CardFace.Row] = []
            if let arrival = s.arrival { rows.append(CardFace.Row("Arrive", arrival.formatted(date: .omitted, time: .shortened))) }
            if let event = s.nextEvent { rows.append(CardFace.Row(event.start.formatted(date: .omitted, time: .shortened), event.title)) }
            return CardFace(symbol: destination.symbol, label: destination.title, value: .text(s.travelText),
                            detail: s.arrival.map { "Arrive \($0.formatted(date: .omitted, time: .shortened))" }, rows: rows)

        case .weather(let s):
            var rows: [CardFace.Row] = []
            if let rain = s.rainText { rows.append(CardFace.Row("Rain", rain)) }
            if let air = s.air { rows.append(CardFace.Row("Haze", "API \(air.value) \(air.band.displayName)", urgency: air.band.urgency)) }
            if let place = s.placeLabel { rows.append(CardFace.Row("Place", place)) }
            return CardFace(symbol: s.symbol, label: s.placeLabel ?? (s.condition ?? "Weather"), value: .text(s.temperatureText),
                            detail: s.airText ?? s.rainText, progress: s.air.map { Double($0.value) / 300 },
                            urgency: s.air?.band.urgency ?? .ok, rows: rows)

        case .obd(let s):
            guard let reading = s.reading else { return nil }
            let boost = reading.boostBar
            return CardFace(symbol: "gauge.with.dots.needle.67percent", label: "Boost",
                            value: .text(boost.map { String(format: "%+.2f", $0) } ?? "--"), unit: "bar",
                            detail: reading.text(.coolant), progress: boost.map { ($0 + 1) / 2.5 }, meter: .gauge, urgency: s.urgency,
                            rows: [CardFace.Row("Coolant", reading.text(.coolant)), CardFace.Row("Battery", reading.text(.voltage)),
                                   CardFace.Row("RPM", reading.text(.rpm))])

        case .map, .photos, .music:
            return nil
        }
    }
}
