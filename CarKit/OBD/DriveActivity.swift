import ActivityKit
import SwiftUI
import WidgetKit

/// The drive-session Live Activity (shown on the Lock Screen, in the Dynamic Island and in CarPlay).
public struct DriveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var rpm: Int?
        public var coolantC: Int?
        public var boostBar: Double?
        public var voltage: Double?
        public var updatedAt: Date
        /// "Connecting…", "Live", "No answer from the car", …
        public var status: String

        public init(rpm: Int? = nil, coolantC: Int? = nil, boostBar: Double? = nil, voltage: Double? = nil, updatedAt: Date, status: String) {
            self.rpm = rpm
            self.coolantC = coolantC
            self.boostBar = boostBar
            self.voltage = voltage
            self.updatedAt = updatedAt
            self.status = status
        }

        public init(reading: OBDReading, status: String) {
            self.init(rpm: reading.rpm, coolantC: reading.coolantC, boostBar: reading.boostBar, voltage: reading.voltage, updatedAt: reading.date, status: status)
        }

        public var reading: OBDReading {
            OBDReading(rpm: rpm, coolantC: coolantC, boostBar: boostBar, voltage: voltage, date: updatedAt)
        }
    }

    public var startedAt: Date
    public var isDemo: Bool

    public init(startedAt: Date, isDemo: Bool) {
        self.startedAt = startedAt
        self.isDemo = isDemo
    }
}

/// One value: label, big number. Shared by the card, the Live Activity and the app.
public struct OBDTile: View {
    let value: OBDValue
    let reading: OBDReading?
    var big: CGFloat = 26
    var unsupported = false

    public init(value: OBDValue, reading: OBDReading?, big: CGFloat = 26, unsupported: Bool = false) {
        self.value = value
        self.reading = reading
        self.big = big
        self.unsupported = unsupported
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(value.displayName.uppercased(), systemImage: value.symbol)
                .font(Theme.label(11))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            Text(unsupported ? "n/a" : (reading?.text(value) ?? "--"))
                .font(Theme.number(big))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        guard let reading else { return Theme.primaryText }
        switch value {
        case .coolant:
            guard let c = reading.coolantC else { return Theme.primaryText }
            return c >= 110 ? Theme.overdue : c >= 105 ? Theme.dueSoon : Theme.primaryText
        case .voltage:
            guard let v = reading.voltage else { return Theme.primaryText }
            return v < 11.8 ? Theme.overdue : v < 12.2 ? Theme.dueSoon : Theme.primaryText
        case .boost:
            return (reading.boostBar ?? 0) > 0.2 ? Theme.accent.mix(with: .white, by: 0.35) : Theme.primaryText
        case .rpm:
            return (reading.rpm ?? 0) > 5_500 ? Theme.dueSoon : Theme.primaryText
        }
    }
}

/// The "Live OBD2" card: last-known values with a timestamp (dedicated widget and slots).
struct OBDCard: View {
    let summary: OBDSummary
    let size: CardSize

    var body: some View {
        if let reading = summary.reading {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    CardHeader(symbol: "gauge.with.dots.needle.67percent", title: summary.isDemo ? "OBD2 · demo" : "OBD2", color: summary.urgency.color(fallback: Theme.accent))
                    Spacer(minLength: 0)
                    Text(reading.date, style: .time)
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                if size == .medium {
                    HStack(spacing: 10) {
                        ForEach(OBDValue.allCases) { value in
                            OBDTile(value: value, reading: reading, big: 22, unsupported: summary.unsupported.contains(value))
                        }
                    }
                } else {
                    OBDTile(value: .boost, reading: reading, big: 26, unsupported: summary.unsupported.contains(.boost))
                    HStack(spacing: 8) {
                        OBDTile(value: .coolant, reading: reading, big: 17, unsupported: summary.unsupported.contains(.coolant))
                        OBDTile(value: .voltage, reading: reading, big: 17, unsupported: summary.unsupported.contains(.voltage))
                    }
                }
            }
        } else {
            EmptyCard(source: .obd, hint: "Start a drive session")
        }
    }
}

/// Live Activity body for the Lock Screen and CarPlay (`.small` is the compact CarPlay/Watch family).
public struct DriveActivityView: View {
    @Environment(\.activityFamily) private var family
    let state: DriveActivityAttributes.ContentState
    let attributes: DriveActivityAttributes

    public init(state: DriveActivityAttributes.ContentState, attributes: DriveActivityAttributes) {
        self.state = state
        self.attributes = attributes
    }

    public var body: some View {
        let reading = state.reading
        if family == .small {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    OBDTile(value: .boost, reading: reading, big: 20)
                    OBDTile(value: .rpm, reading: reading, big: 20)
                }
                HStack {
                    OBDTile(value: .coolant, reading: reading, big: 16)
                    OBDTile(value: .voltage, reading: reading, big: 16)
                }
            }
            .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(attributes.isDemo ? "Drive session · demo" : "Drive session", systemImage: "car.side.fill")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(state.status)
                        .font(Theme.label(12))
                        .foregroundStyle(Theme.secondaryText)
                }
                HStack(spacing: 12) {
                    ForEach(OBDValue.allCases) { value in
                        OBDTile(value: value, reading: reading, big: 24)
                    }
                }
            }
            .padding(14)
        }
    }
}
