import Foundation

// View-ready summaries for the Phase 3 widgets, built from the cached files in `CarData`.

public struct ParkingSummary: Sendable, Equatable {
    public let spot: ParkingSpot?

    public init(spot: ParkingSpot?) {
        self.spot = spot
    }
}

public struct PrayerSummary: Sendable, Equatable {
    public let zoneCode: String
    public let next: PrayerMoment?
    public let current: PrayerMoment?
    /// Today's five prayers (plus syuruk), for the medium size.
    public let today: [PrayerMoment]
    /// True when the times shown are the offline calculation, not JAKIM's.
    public let isEstimated: Bool

    public init(zoneCode: String, next: PrayerMoment?, current: PrayerMoment?, today: [PrayerMoment], isEstimated: Bool) {
        self.zoneCode = zoneCode
        self.next = next
        self.current = current
        self.today = today
        self.isEstimated = isEstimated
    }
}

public struct CommuteSummary: Sendable, Equatable {
    public let destination: CommuteDestination?
    public let placeName: String?
    /// Travel time, when a recent enough ETA is cached for this destination.
    public let travelSeconds: TimeInterval?
    /// Arrival if leaving at the entry's time.
    public let arrival: Date?
    public let computedAt: Date?
    public let nextEvent: CachedEvent?
    public let needsSetup: Bool

    public init(destination: CommuteDestination?, placeName: String?, travelSeconds: TimeInterval?, arrival: Date?, computedAt: Date?, nextEvent: CachedEvent?, needsSetup: Bool) {
        self.destination = destination
        self.placeName = placeName
        self.travelSeconds = travelSeconds
        self.arrival = arrival
        self.computedAt = computedAt
        self.nextEvent = nextEvent
        self.needsSetup = needsSetup
    }

    /// "32 min" / "1 h 05"
    public var travelText: String {
        guard let travelSeconds else { return "--" }
        return CarFormat.duration(travelSeconds)
    }
}

public struct WeatherSummary: Sendable, Equatable {
    public let temperatureC: Double?
    public let symbol: String
    public let condition: String?
    public let rainText: String?
    public let air: AirQuality?
    public let placeLabel: String?
    /// No air-quality token configured.
    public let needsAirToken: Bool
    public let weatherError: String?

    public init(temperatureC: Double?, symbol: String, condition: String?, rainText: String?, air: AirQuality?, placeLabel: String?, needsAirToken: Bool, weatherError: String?) {
        self.temperatureC = temperatureC
        self.symbol = symbol
        self.condition = condition
        self.rainText = rainText
        self.air = air
        self.placeLabel = placeLabel
        self.needsAirToken = needsAirToken
        self.weatherError = weatherError
    }

    public var temperatureText: String {
        temperatureC.map { "\(Int($0.rounded()))°" } ?? "--°"
    }

    public var airText: String? {
        air.map { "API \($0.value) · \($0.band.displayName)" }
    }
}

public struct MapSummary: Sendable, Equatable {
    /// Full path of the rendered PNG, if one exists for the current target.
    public let imagePath: String?
    public let caption: String?
    public let isParking: Bool
    /// Set when the parked car is shown, for the "ago" line.
    public let parkedAt: Date?

    public init(imagePath: String?, caption: String?, isParking: Bool, parkedAt: Date?) {
        self.imagePath = imagePath
        self.caption = caption
        self.isParking = isParking
        self.parkedAt = parkedAt
    }
}

public extension CarFormat {
    /// "32 min", "1 h 05 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        return String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    static func temperature(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°C"
    }
}

extension CarData {
    /// Cards for the Phase 3 sources. `mapSizeKey` picks the PNG rendered for a widget size.
    func liveCard(for source: DataSource, at date: Date, calendar: Calendar, mapSizeKey: String? = nil) -> DataCard {
        switch source {
        case .parking:
            return .parking(ParkingSummary(spot: parking.spot))

        case .prayer:
            let days = prayer.zoneCode == prayerSettings.zoneCode ? prayer.days : []
            let next = PrayerSchedule.next(after: date, in: days)
            let today = PrayerSchedule.day(containing: date, in: days)?.moments ?? []
            return .prayer(PrayerSummary(
                zoneCode: prayerSettings.zoneCode,
                next: next,
                current: PrayerSchedule.current(at: date, in: days),
                today: today,
                isEstimated: next?.origin == .calculated
            ))

        case .commute:
            let destination = CommuteRules.destination(at: date, settings: commute, calendar: calendar)
            var travel: TimeInterval?
            var computedAt: Date?
            if let latest = commuteCache.latest, latest.destination == destination,
               date.timeIntervalSince(latest.computedAt) < CommuteRules.staleAfter {
                travel = latest.travelSeconds
                computedAt = latest.computedAt
            }
            return .commute(CommuteSummary(
                destination: destination,
                placeName: destination.flatMap { commute.place($0)?.name },
                travelSeconds: travel,
                arrival: travel.map { date.addingTimeInterval($0) },
                computedAt: computedAt,
                nextEvent: self.calendar.nextEvent(at: date),
                needsSetup: destination == nil
            ))

        case .weather:
            let snapshot = weather.weather
            let conditions = snapshot.map { WeatherRules.conditions(at: date, in: $0) }
            let freshAir = weather.air.flatMap { air -> AirQuality? in
                guard let fetched = weather.airFetchedAt, date.timeIntervalSince(fetched) < 6 * 3600 else { return nil }
                return air
            }
            return .weather(WeatherSummary(
                temperatureC: conditions?.temperatureC,
                symbol: conditions?.symbol ?? "cloud.sun.fill",
                condition: snapshot?.condition,
                rainText: snapshot.map { WeatherRules.rainText(at: date, in: $0, calendar: calendar) },
                air: freshAir,
                placeLabel: weather.placeLabel,
                needsAirToken: AirQualityKey.current == nil,
                weatherError: snapshot == nil ? weather.weatherError : nil
            ))

        case .map:
            let target = MapTarget.choose(parking: parking, commute: commute, at: date, calendar: calendar)
            let entry = target.flatMap { map.entry(for: $0.key, sizeKey: mapSizeKey) }
            let path = entry.flatMap { entry in
                directory?.appending(path: entry.fileName, directoryHint: .notDirectory).path(percentEncoded: false)
            }
            return .map(MapSummary(
                imagePath: path,
                caption: target?.label,
                isParking: target?.isParking ?? false,
                parkedAt: target?.isParking == true ? parking.spot?.savedAt : nil
            ))

        case .service, .fuel, .renewals, .tng, .photos, .music:
            return card(for: source, at: date, calendar: calendar)
        }
    }

    /// Map card for a specific widget size (dedicated widget and slots render their own PNG).
    public func mapCard(at date: Date, width: Double, height: Double, calendar: Calendar = .current) -> DataCard {
        liveCard(for: .map, at: date, calendar: calendar, mapSizeKey: MapSnapshotIndex.sizeKey(width: width, height: height))
    }
}
