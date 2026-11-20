import SwiftUI
import UIKit
import WidgetKit

// Split / Quad slot layouts (spec §4b): each card is icon + short label + one large value,
// readable on the car screen, with the due-soon / overdue colours per card.

/// The big value of a compact card. Timers and relative times tick by themselves in widgets.
public enum CompactValue: Sendable, Equatable {
    case text(String)
    case timer(Date)
    case relative(Date)
}

public struct CompactCard: Sendable, Equatable {
    public let symbol: String
    public let label: String
    public let value: CompactValue
    public let urgency: Urgency
    /// Full-bleed image (map, photo, music artwork) behind the label.
    public let imagePath: String?
    /// Show the whole image (a slot picture) instead of filling the card.
    public let imageFits: Bool

    public init(symbol: String, label: String, value: CompactValue, urgency: Urgency = .ok, imagePath: String? = nil, imageFits: Bool = false) {
        self.symbol = symbol
        self.label = label
        self.value = value
        self.urgency = urgency
        self.imagePath = imagePath
        self.imageFits = imageFits
    }
}

public extension DataCard {
    /// One-line version of the card for Split and Quad slots.
    var compact: CompactCard {
        switch self {
        case .service(let s):
            guard let line = s.lines.first else { return CompactCard(symbol: source.symbol, label: "Service", value: .text("--")) }
            let value = line.kmLeft.map { $0 <= 0 ? "\(CarFormat.km(-$0)) over" : CarFormat.km($0) }
                ?? line.daysLeft.map { $0 < 0 ? "\(-$0) d late" : CarFormat.days($0) } ?? "--"
            return CompactCard(symbol: line.symbol, label: line.name, value: .text(value), urgency: line.urgency)
        case .fuel(let s):
            let value = s.averageKmPerLitre.map { "\($0.formatted(.number.precision(.fractionLength(1)))) km/L" } ?? "--"
            return CompactCard(symbol: "fuelpump.fill", label: s.hasFills ? "Fuel avg" : "Fuel", value: .text(value))
        case .renewals(let s):
            guard let line = s.lines.first else { return CompactCard(symbol: source.symbol, label: "Road tax", value: .text("--")) }
            let value = line.daysLeft < 0 ? "\(-line.daysLeft) d over" : (line.daysLeft == 0 ? "Today" : CarFormat.days(line.daysLeft))
            return CompactCard(symbol: line.symbol, label: line.name, value: .text(value), urgency: line.urgency)
        case .tng(let s):
            return CompactCard(symbol: "creditcard.fill", label: s.isLow ? "TnG · top up" : "Touch 'n Go",
                               value: .text(s.balance.map { CarFormat.rm($0) } ?? "--"), urgency: s.isLow ? .dueSoon : .ok)
        case .parking(let s):
            guard let spot = s.spot else { return CompactCard(symbol: "parkingsign.circle.fill", label: "Parking", value: .text("Not parked")) }
            let label = spot.detailLine.isEmpty ? "Parked" : spot.detailLine
            return CompactCard(symbol: "parkingsign.circle.fill", label: label, value: .text(spot.title))
        case .prayer(let s):
            guard let next = s.next else { return CompactCard(symbol: "moon.stars.fill", label: "Prayer", value: .text("--")) }
            let time = next.time.formatted(date: .omitted, time: .shortened)
            return CompactCard(symbol: next.prayer.symbol, label: "\(next.prayer.displayName) \(time)", value: .timer(next.time))
        case .commute(let s):
            guard let destination = s.destination, !s.needsSetup else { return CompactCard(symbol: "car.rear.road.lane", label: "Commute", value: .text("Set up")) }
            return CompactCard(symbol: destination.symbol, label: destination.title, value: .text(s.travelText))
        case .weather(let s):
            let label = s.air.map { "API \($0.value) \($0.band.displayName)" } ?? (s.rainText ?? "Weather")
            return CompactCard(symbol: s.symbol, label: label, value: .text(s.temperatureText), urgency: s.air?.band.urgency ?? .ok)
        case .map(let s):
            return CompactCard(symbol: "map.fill", label: s.caption ?? "Map", value: .text(""), imagePath: s.imagePath)
        case .photos(let s):
            return CompactCard(symbol: "photo.fill", label: s.albumName ?? "Photos", value: .text(""), imagePath: s.imagePath)
        case .music(let s):
            return CompactCard(symbol: "music.note", label: s.title ?? "Music", value: .text(s.subtitle ?? ""), imagePath: s.artworkPath)
        case .obd(let s):
            return CompactCard(symbol: "gauge.with.dots.needle.67percent", label: "Boost", value: .text(s.reading?.text(.boost) ?? "--"), urgency: s.urgency)
        }
    }
}

/// The cards of a Split or Quad slot.
public struct SlotCardsView: View {
    let slot: Int
    let layout: SlotLayout
    let parts: [SlotContent]
    let isMedium: Bool
    /// Called with the card index when a card is tapped (the app's mock screen); nil in widgets.
    let onTap: ((Int) -> Void)?

    public init(slot: Int, layout: SlotLayout, parts: [SlotContent], isMedium: Bool = false, onTap: ((Int) -> Void)? = nil) {
        self.slot = slot
        self.layout = layout
        self.parts = parts
        self.isMedium = isMedium
        self.onTap = onTap
    }

    /// Gap between cards (the spec's "thin divider or gap").
    static let gap: CGFloat = 6

    public var body: some View {
        switch layout {
        case .single:
            card(0)
        case .split:
            if isMedium {
                HStack(spacing: Self.gap) { card(0); card(1) }
            } else {
                VStack(spacing: Self.gap) { card(0); card(1) }
            }
        case .quad:
            VStack(spacing: Self.gap) {
                HStack(spacing: Self.gap) { card(0); card(1) }
                HStack(spacing: Self.gap) { card(2); card(3) }
            }
        }
    }

    @ViewBuilder
    private func card(_ index: Int) -> some View {
        let content = parts.indices.contains(index) ? parts[index] : .design(.starter(for: slot))
        let view = SlotCardView(slot: slot, content: content, compact: layout == .quad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        if let onTap {
            Button { onTap(index) } label: { view }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit slot \(slot), \(layout.cardNames[min(index, layout.cardNames.count - 1)]) card")
        } else {
            view
        }
    }
}

/// One card. `compact` = Quad: icon + value only, no label.
struct SlotCardView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.cardLook) private var look
    let slot: Int
    let content: SlotContent
    let compact: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            switch content {
            case .studio(let card):
                DesignView(card: card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .flashCard(let name):
                flash(name)
            case .data(let card):
                values(card.compact)
            case .design(let design):
                values(CompactCard(symbol: design.symbol, label: design.title, value: .text(design.value),
                                   imagePath: design.imageURL?.path(percentEncoded: false), imageFits: true))
            case .flash:
                flash("")
            case .cards:
                EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            UrgencyMark(urgency: urgency, size: compact ? 12 : 14).padding(compact ? 5 : 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Read by VoiceOver: "Next prayer Asr 4:30 PM, 1:12:05" rather than symbol names.
    private var accessibilityText: String {
        func spoken(_ card: CompactCard) -> String {
            let value: String = switch card.value {
            case .text(let text): text
            case .timer(let date), .relative(let date): "in " + date.formatted(.relative(presentation: .numeric))
            }
            let warning = card.urgency == .urgent ? ", overdue" : (card.urgency == .dueSoon ? ", due soon" : "")
            return [card.label, value].filter { !$0.isEmpty }.joined(separator: ", ") + warning
        }
        switch content {
        case .data(let card): return spoken(card.compact)
        case .design(let design):
            let text = [design.title, design.value].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
            return text.isEmpty ? design.cardSummary : text
        case .studio(let card): return card.design.name
        case .flashCard(let name): return name.isEmpty ? "Slot \(slot) test card" : "Slot \(slot), \(name) test card"
        case .flash: return "Slot \(slot) test card"
        case .cards: return ""
        }
    }

    private var urgency: Urgency {
        if case .data(let card) = content { return card.compact.urgency }
        return .ok
    }

    private var paint: CardPaint {
        switch content {
        case .data(let card): card.paint
        case .design(let design): design.paint
        default: .plain
        }
    }

    /// Neon value / icon colour; white on Bold tiles.
    private var ink: Color { look == .neon ? paint.color(.neon) : Theme.primaryText }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if renderingMode == .fullColor {
            switch look {
            case .bold:
                BoldBackground(color: paint.color(.bold))
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
            case .neon:
                shape.fill(Color(hex: 0x0A0D14).opacity(0.92))
                    .overlay(RadialGradient(colors: [paint.color(.neon).opacity(0.28), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 110).clipShape(shape))
                    .overlay(shape.strokeBorder(paint.color(.neon).opacity(0.55), lineWidth: 1.2))
            }
        } else {
            // Tinted / clear CarPlay: no fills, so a thin line keeps the cards apart.
            shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func values(_ card: CompactCard) -> some View {
        if card.imageFits, let path = card.imagePath, let image = UIImage(contentsOfFile: path) {
            // A slot picture: whole, as large as the card allows, with the value under it.
            VStack(spacing: 2) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if case .text(let text) = card.value, !text.isEmpty {
                    Text(text)
                        .font(Theme.number(compact ? 15 : 18))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(compact ? 5 : 7)
        } else if let path = card.imagePath, let image = UIImage(contentsOfFile: path) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if !compact {
                    Text(card.label)
                        .font(Theme.label(12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                        .padding(5)
                }
            }
        } else {
            let color = card.urgency.color()
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                HStack(spacing: 5) {
                    Image(systemName: card.symbol)
                        .font(.system(size: compact ? 18 : 16, weight: .bold))
                        .foregroundStyle(look == .bold ? Theme.primaryText : ink)
                        .widgetAccentable()
                        .neonGlow(look == .neon ? ink : nil, radius: 3)
                    if !compact {
                        Text(card.label.uppercased())
                            .font(Theme.label(12))
                            .tracking(0.4)
                            .foregroundStyle(look == .bold ? Color.white.opacity(0.85) : Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85) // never below ~11 pt
                    }
                }
                Spacer(minLength: 0)
                valueText(card.value)
                    .font(Theme.number(compact ? 22 : 30, weight: .heavy))
                    .foregroundStyle(look == .bold ? Theme.primaryText : (card.urgency == .ok ? Theme.primaryText : color))
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.6) // never below ~14 / 18 pt
                    .widgetAccentable()
                    .neonGlow(look == .neon && renderingMode == .fullColor ? ink : nil, radius: 5)
            }
            .padding(compact ? 7 : 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func valueText(_ value: CompactValue) -> Text {
        switch value {
        case .text(let text): Text(text)
        case .timer(let date): Text(date, style: .timer)
        case .relative(let date): Text(date, style: .relative)
        }
    }

    private func flash(_ name: String) -> some View {
        VStack(spacing: 2) {
            Text(name.isEmpty ? "Slot \(slot) ✓" : "Slot \(slot)")
                .font(Theme.number(compact ? 16 : 20))
            if !name.isEmpty {
                Text("\(name) ✓")
                    .font(Theme.label(compact ? 11 : 14))
            }
        }
        .foregroundStyle(Theme.primaryText)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent))
    }
}
