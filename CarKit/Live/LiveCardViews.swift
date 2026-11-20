import SwiftUI
import UIKit
import WidgetKit

// Small and medium layouts for the Phase 3 cards. Same building blocks as the Phase 2 cards
// (CardHeader, BigValue, SmallLine, EmptyCard) so every widget reads as one family.

// MARK: - Parking

struct ParkingCard: View {
    let summary: ParkingSummary
    let size: CardSize

    var body: some View {
        if let spot = summary.spot {
            VStack(alignment: .leading, spacing: 3) {
                CardHeader(symbol: "parkingsign.circle.fill", title: "Parking", color: Theme.accent)
                Spacer(minLength: 0)
                Text(spot.title)
                    .font(.system(size: size == .medium ? 24 : 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                if !spot.detailLine.isEmpty {
                    Text(spot.detailLine)
                        .font(Theme.number(size == .medium ? 20 : 16, weight: .semibold))
                        .foregroundStyle(Theme.primaryText.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                // Ticks by itself: "Parked 2 hr, 14 min ago".
                Text("Parked \(Text(spot.savedAt, style: .relative)) ago")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } else {
            EmptyCard(source: .parking, hint: "No parking saved")
        }
    }
}

// MARK: - Prayer

struct PrayerCard: View {
    let summary: PrayerSummary
    let size: CardSize

    var body: some View {
        if let next = summary.next {
            if size == .medium {
                HStack(alignment: .top, spacing: 14) {
                    nextBlock(next)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(summary.today.filter { $0.prayer.isPrayer }, id: \.prayer) { moment in
                            let isNext = moment == next
                            HStack {
                                Text(moment.prayer.displayName)
                                    .font(.system(size: 14, weight: isNext ? .bold : .medium, design: .rounded))
                                Spacer(minLength: 4)
                                Text(moment.time, style: .time)
                                    .font(Theme.number(14, weight: isNext ? .bold : .medium))
                            }
                            .foregroundStyle(isNext ? Theme.primaryText : Theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                nextBlock(next)
            }
        } else {
            EmptyCard(source: .prayer, hint: "Open the app to load times")
        }
    }

    private func nextBlock(_ next: PrayerMoment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CardHeader(symbol: next.prayer.symbol, title: summary.isEstimated ? "\(summary.zoneCode) · est." : summary.zoneCode, color: Theme.accent)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(next.prayer.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Text(next.time, style: .time)
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.secondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // Live countdown to the next prayer.
            Text(next.time, style: .timer)
                .font(Theme.number(30))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Commute

struct CommuteCard: View {
    let summary: CommuteSummary
    let size: CardSize

    var body: some View {
        if let destination = summary.destination, !summary.needsSetup {
            if size == .medium {
                HStack(alignment: .top, spacing: 14) {
                    trip(destination)
                    eventBlock
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            } else {
                trip(destination)
            }
        } else {
            EmptyCard(source: .commute, hint: "Set Home and Work")
        }
    }

    private func trip(_ destination: CommuteDestination) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CardHeader(symbol: destination.symbol, title: destination.title, color: Theme.accent)
            Spacer(minLength: 0)
            BigValue(text: summary.travelText, size: 34)
            if let arrival = summary.arrival {
                Text("Arrive \(Text(arrival, style: .time))")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.primaryText.opacity(0.85))
                    .lineLimit(1)
            } else {
                SmallLine(text: "Updating…")
            }
            if size != .medium, let event = summary.nextEvent {
                SmallLine(text: "\(event.start.formatted(date: .omitted, time: .shortened)) \(event.title)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var eventBlock: some View {
        if let event = summary.nextEvent {
            VStack(alignment: .leading, spacing: 2) {
                SmallLine(text: "NEXT")
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(event.start, style: .time)
                    .font(Theme.number(18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                if let location = event.location, !location.isEmpty {
                    SmallLine(text: location)
                }
            }
        } else {
            SmallLine(text: "No more events today")
        }
    }
}

// MARK: - Weather & haze

struct WeatherCard: View {
    let summary: WeatherSummary
    let size: CardSize

    var body: some View {
        if summary.temperatureC == nil && summary.air == nil {
            VStack(alignment: .leading, spacing: 4) {
                CardHeader(symbol: "cloud.sun.fill", title: "Weather & Haze", color: Theme.accent)
                Spacer(minLength: 0)
                Text(summary.weatherError == nil ? "Loading…" : "No weather yet")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                SmallLine(text: "Open Peugeot408")
                attribution
            }
        } else if size == .medium {
            HStack(alignment: .top, spacing: 14) {
                weatherBlock
                airBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                header
                Spacer(minLength: 0)
                BigValue(text: summary.temperatureText, size: 34)
                if let rain = summary.rainText {
                    SmallLine(text: rain, color: Theme.primaryText.opacity(0.85))
                }
                if let air = summary.air {
                    airLine(air)
                } else if summary.needsAirToken {
                    SmallLine(text: "Haze: add token")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: summary.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
            Spacer(minLength: 0)
            attribution
        }
    }

    /// Apple requires the  Weather mark wherever WeatherKit data is shown.
    private var attribution: some View {
        Text("\u{F8FF}Weather")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
    }

    private var weatherBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            Spacer(minLength: 0)
            BigValue(text: summary.temperatureText, size: 38)
            if let rain = summary.rainText {
                SmallLine(text: rain, color: Theme.primaryText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var airBlock: some View {
        if let air = summary.air {
            VStack(alignment: .leading, spacing: 2) {
                SmallLine(text: "HAZE · API")
                BigValue(text: "\(air.value)", size: 34, color: Color(hex: air.band.hex))
                Text(air.band.displayName)
                    .font(Theme.label(14))
                    .foregroundStyle(Color(hex: air.band.hex))
                    .lineLimit(1)
                SmallLine(text: air.station)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                SmallLine(text: "HAZE")
                SmallLine(text: summary.needsAirToken ? "Add an air-quality token" : "No reading", color: Theme.primaryText)
            }
        }
    }

    private func airLine(_ air: AirQuality) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: air.band.hex))
                .frame(width: 9, height: 9)
            Text("API \(air.value) \(air.band.displayName)")
                .font(Theme.label(13))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Map snapshot

struct MapCard: View {
    let summary: MapSummary
    let size: CardSize

    var body: some View {
        if let path = summary.imagePath, let image = UIImage(contentsOfFile: path) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    if let caption = summary.caption {
                        Text(caption)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    if let parkedAt = summary.parkedAt {
                        Text("\(Text(parkedAt, style: .relative)) ago")
                            .font(Theme.label(12))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(6)
            }
        } else if summary.caption != nil {
            VStack(alignment: .leading, spacing: 4) {
                CardHeader(symbol: "map.fill", title: "Map", color: Theme.accent)
                Spacer(minLength: 0)
                Text(summary.caption ?? "")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                SmallLine(text: "Drawing map…")
            }
        } else {
            EmptyCard(source: .map, hint: "Save parking or set Home/Work")
        }
    }
}
