import SwiftUI
import WidgetKit

public extension Urgency {
    /// Amber for due soon, red for urgent; `fallback` otherwise.
    func color(fallback: Color = Theme.primaryText) -> Color {
        switch self {
        case .ok: fallback
        case .dueSoon: Theme.dueSoon
        case .urgent: Theme.overdue
        }
    }
}

public extension DataCard {
    /// Card glow colour: the accent normally, amber/red when something needs attention.
    var tint: Color { urgency.color(fallback: Theme.accent) }
}

public extension SlotContent {
    var tint: Color {
        if case .data(let card) = self { return card.tint }
        return Theme.accent
    }
}

/// Which layout to draw.
public enum CardSize: Sendable {
    case small
    case medium
    /// Lock Screen `accessoryRectangular`: text only, the system tints it.
    case accessory

    public init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium, .systemLarge, .systemExtraLarge: self = .medium
        case .accessoryRectangular, .accessoryCircular, .accessoryInline: self = .accessory
        default: self = .small
        }
    }
}

/// Foreground of every data widget (and of a slot showing one). Shared by the app and the extension.
public struct DataCardView: View {
    private let card: DataCard
    private let size: CardSize

    public init(card: DataCard, size: CardSize = .small) {
        self.card = card
        self.size = size
    }

    public var body: some View {
        Group {
            switch size {
            case .accessory: accessory
            case .small, .medium:
                switch card {
                case .service(let summary): ServiceCard(summary: summary, size: size)
                case .fuel(let summary): FuelCard(summary: summary, size: size)
                case .renewals(let summary): RenewalsCard(summary: summary, size: size)
                case .tng(let summary): TnGCard(summary: summary, size: size)
                case .parking(let summary): ParkingCard(summary: summary, size: size)
                case .prayer(let summary): PrayerCard(summary: summary, size: size)
                case .commute(let summary): CommuteCard(summary: summary, size: size)
                case .weather(let summary): WeatherCard(summary: summary, size: size)
                case .map(let summary): MapCard(summary: summary, size: size)
                case .photos(let summary): PhotoCard(summary: summary, size: size)
                case .music(let summary): MusicCardView(summary: summary, size: size)
                case .obd(let summary): OBDCard(summary: summary, size: size)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Lock Screen

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(card.source.displayName, systemImage: card.source.symbol)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            ForEach(Array(accessoryLines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? .headline : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable(index == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryLines: [String] {
        switch card {
        case .service(let summary):
            guard let line = summary.lines.first else { return ["Add a service item"] }
            return [line.compactText, line.name]
        case .fuel(let summary):
            guard summary.hasFills else { return ["Add a fill-up"] }
            var lines: [String] = []
            lines.append(summary.averageKmPerLitre.map(CarFormat.kmPerLitre) ?? "Need 2 full tanks")
            lines.append("\(CarFormat.rm(summary.spentThisMonth, decimals: 0)) this month")
            return lines
        case .renewals(let summary):
            guard let line = summary.lines.first else { return ["Add a renewal date"] }
            return ["\(line.countText) \(line.unitText)", line.name]
        case .tng(let summary):
            guard let balance = summary.balance else { return ["Enter your balance"] }
            return [CarFormat.rm(balance), summary.isLow ? "Top up soon" : "Balance OK"]
        case .parking(let summary):
            guard let spot = summary.spot else { return ["No parking saved"] }
            let detail = spot.detailLine
            return [spot.title, detail.isEmpty ? "Since \(spot.savedAt.formatted(date: .omitted, time: .shortened))" : detail]
        case .prayer(let summary):
            guard let next = summary.next else { return ["Open the app to load times"] }
            return ["\(next.prayer.displayName) \(next.time.formatted(date: .omitted, time: .shortened))", summary.zoneCode]
        case .commute(let summary):
            guard let destination = summary.destination, !summary.needsSetup else { return ["Set Home and Work"] }
            var lines = ["\(destination.title): \(summary.travelText)"]
            if let event = summary.nextEvent {
                lines.append("\(event.start.formatted(date: .omitted, time: .shortened)) \(event.title)")
            }
            return lines
        case .weather(let summary):
            var lines = ["\(summary.temperatureText) \(summary.rainText ?? "")".trimmingCharacters(in: .whitespaces)]
            if let air = summary.airText { lines.append(air) }
            return lines
        case .map(let summary):
            return [summary.caption ?? "Save parking or set Home/Work"]
        case .photos(let summary):
            return [summary.photoCount == 0 ? "Add photos in the app" : "\(summary.photoCount) photos"]
        case .music(let summary):
            guard let title = summary.title else { return ["Open Music in the app"] }
            return [title, summary.subtitle ?? summary.kindLabel]
        case .obd(let summary):
            guard let reading = summary.reading else { return ["No drive session yet"] }
            return ["\(reading.text(.boost)) · \(reading.text(.coolant))", "\(reading.text(.voltage)) · \(reading.date.formatted(date: .omitted, time: .shortened))"]
        }
    }

    private var accessibilityText: String {
        "\(card.source.displayName): " + accessoryLines.joined(separator: ", ")
    }
}

// MARK: - Building blocks

struct CardHeader: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .widgetAccentable()
            Text(title.uppercased())
                .font(Theme.label(12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct BigValue: View {
    let text: String
    var size: CGFloat = 32
    var color: Color = Theme.primaryText

    var body: some View {
        Text(text)
            .font(Theme.number(size))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
    }
}

struct SmallLine: View {
    let text: String
    var color: Color = Theme.secondaryText

    var body: some View {
        Text(text)
            .font(Theme.label(13))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct EmptyCard: View {
    let source: DataSource
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(symbol: source.symbol, title: source.displayName, color: Theme.accent)
            Spacer(minLength: 0)
            Text(hint)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            SmallLine(text: "Open Peugeot408")
        }
    }
}

// MARK: - Service

private struct ServiceCard: View {
    let summary: ServiceSummary
    let size: CardSize

    var body: some View {
        if let top = summary.lines.first {
            if size == .medium {
                VStack(alignment: .leading, spacing: 8) {
                    CardHeader(symbol: "wrench.and.screwdriver.fill", title: "Service", color: top.urgency.color(fallback: Theme.accent))
                    ForEach(Array(summary.lines.prefix(3).enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(line.urgency.color(fallback: Theme.accent))
                                .frame(width: 8, height: 8)
                            Text(line.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(line.compactText)
                                .font(Theme.number(15, weight: .semibold))
                                .foregroundStyle(line.urgency.color())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .widgetAccentable()
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    CardHeader(symbol: top.symbol, title: "Service", color: top.urgency.color(fallback: Theme.accent))
                    Spacer(minLength: 0)
                    SmallLine(text: top.name, color: Theme.primaryText.opacity(0.85))
                    BigValue(text: top.primaryText, color: top.urgency.color())
                    SmallLine(text: top.secondaryText, color: top.urgency.color(fallback: Theme.secondaryText))
                }
            }
        } else {
            EmptyCard(source: .service, hint: "Add a service item")
        }
    }
}

// MARK: - Fuel

private struct FuelCard: View {
    let summary: FuelSummary
    let size: CardSize

    private var average: String {
        summary.averageKmPerLitre.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "--"
    }

    private var price: String {
        summary.lastPricePerLitre.map { "\(CarFormat.rm($0))/L" } ?? "--"
    }

    private var month: String { CarFormat.rm(summary.spentThisMonth, decimals: 0) }

    var body: some View {
        if !summary.hasFills {
            EmptyCard(source: .fuel, hint: "Add a fill-up")
        } else if size == .medium {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(symbol: "fuelpump.fill", title: "Fuel", color: Theme.accent)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 12) {
                    column(value: average, label: "km/L avg")
                    column(value: price, label: "last price")
                    column(value: month, label: "this month")
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                CardHeader(symbol: "fuelpump.fill", title: "Fuel", color: Theme.accent)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    BigValue(text: average, size: 34)
                    SmallLine(text: "km/L")
                }
                SmallLine(text: price, color: Theme.primaryText.opacity(0.85))
                SmallLine(text: "\(month) this month")
            }
        }
    }

    private func column(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            BigValue(text: value, size: 24)
            SmallLine(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Renewals

private struct RenewalsCard: View {
    let summary: RenewalSummary
    let size: CardSize

    var body: some View {
        if let top = summary.lines.first {
            if size == .medium {
                HStack(alignment: .top, spacing: 14) {
                    nearest(top)
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer(minLength: 0)
                        ForEach(Array(summary.lines.dropFirst().prefix(2).enumerated()), id: \.offset) { _, line in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(line.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .lineLimit(1)
                                Text("\(line.countText) \(line.unitText)")
                                    .font(Theme.number(14, weight: .semibold))
                                    .foregroundStyle(line.urgency.color(fallback: Theme.secondaryText))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                nearest(top)
            }
        } else {
            EmptyCard(source: .renewals, hint: "Add road tax & insurance dates")
        }
    }

    private func nearest(_ line: RenewalLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CardHeader(symbol: line.symbol, title: line.name, color: line.urgency.color(fallback: Theme.accent))
            Spacer(minLength: 0)
            BigValue(text: line.countText, size: 44, color: line.urgency.color())
            SmallLine(text: line.unitText, color: line.urgency.color(fallback: Theme.secondaryText))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Touch 'n Go

private struct TnGCard: View {
    let summary: TnGSummary
    let size: CardSize

    var body: some View {
        if let balance = summary.balance {
            let color = summary.isLow ? Theme.dueSoon : Theme.primaryText
            VStack(alignment: .leading, spacing: 2) {
                CardHeader(symbol: "creditcard.fill", title: "Touch 'n Go", color: summary.isLow ? Theme.dueSoon : Theme.accent)
                Spacer(minLength: 0)
                BigValue(text: CarFormat.rm(balance), size: size == .medium ? 40 : 30, color: color)
                if summary.isLow {
                    SmallLine(text: "Top up soon", color: Theme.dueSoon)
                } else {
                    SmallLine(text: "Top up below \(CarFormat.rm(summary.threshold, decimals: 0))")
                }
            }
        } else {
            EmptyCard(source: .tng, hint: "Enter your balance")
        }
    }
}

// MARK: - Tile for in-app previews

/// A data card drawn as a rounded tile, the same as on the head unit.
public struct DataCardTile: View {
    private let card: DataCard
    private let size: CardSize

    public init(card: DataCard, size: CardSize = .small) {
        self.card = card
        self.size = size
    }

    public var body: some View {
        DataCardView(card: card, size: size)
            .padding(14)
            .background(WidgetCardBackground(style: .standard, tint: card.tint))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
