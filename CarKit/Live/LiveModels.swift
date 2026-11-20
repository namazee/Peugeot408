import Foundation

/// A plain, Codable coordinate (CLLocationCoordinate2D isn't Codable).
public struct GeoPoint: Codable, Sendable, Equatable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Rough distance in metres (equirectangular; fine for "has the target moved?").
    public func distance(to other: GeoPoint) -> Double {
        let r = 6_371_000.0
        let x = (other.longitude - longitude) * .pi / 180 * cos((latitude + other.latitude) / 2 * .pi / 180)
        let y = (other.latitude - latitude) * .pi / 180
        return sqrt(x * x + y * y) * r
    }
}

/// The most recent location any part of the app saw (`location.json`). Fallback for widgets
/// when they can't get a fresh fix.
public struct LastLocation: Codable, Sendable, Equatable {
    public var point: GeoPoint
    public var date: Date

    public init(point: GeoPoint, date: Date) {
        self.point = point
        self.date = date
    }
}

// MARK: - Parking

public struct ParkingSpot: Codable, Sendable, Equatable {
    public var point: GeoPoint?
    public var savedAt: Date
    /// Place name from reverse geocoding, e.g. "IOI City Mall". Editable.
    public var placeName: String
    public var floor: String
    public var bay: String
    public var note: String
    /// True when no fresh GPS fix was available and an older location was used.
    public var isApproximate: Bool

    public init(point: GeoPoint?, savedAt: Date, placeName: String = "", floor: String = "", bay: String = "", note: String = "", isApproximate: Bool = false) {
        self.point = point
        self.savedAt = savedAt
        self.placeName = placeName
        self.floor = floor
        self.bay = bay
        self.note = note
        self.isApproximate = isApproximate
    }

    /// Title line: the place name, or a fallback.
    public var title: String {
        let name = placeName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Parked here" : name
    }

    /// "B2 · C14 · near lift", without empty parts.
    public var detailLine: String {
        [floor, bay, note]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// `parking.json`: the current spot (nil when cleared).
public struct ParkingState: Codable, Sendable, Equatable {
    public var spot: ParkingSpot?

    public init(spot: ParkingSpot? = nil) {
        self.spot = spot
    }

    public static let empty = ParkingState()
}

// MARK: - Commute

public struct SavedPlace: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var point: GeoPoint

    public init(name: String, point: GeoPoint) {
        self.name = name
        self.point = point
    }
}

public enum CommuteDestination: String, Codable, Sendable, CaseIterable {
    case work
    case home

    public var title: String {
        switch self {
        case .work: "To Work"
        case .home: "To Home"
        }
    }

    public var symbol: String {
        switch self {
        case .work: "building.2.fill"
        case .home: "house.fill"
        }
    }

    public var other: CommuteDestination { self == .work ? .home : .work }
}

/// `commute.json`: Home, Work and when to switch.
public struct CommuteSettings: Codable, Sendable, Equatable {
    public var home: SavedPlace?
    public var work: SavedPlace?
    /// From this hour (24 h) the widget shows the trip home; before it, the trip to work.
    public var homeFromHour: Int

    public init(home: SavedPlace? = nil, work: SavedPlace? = nil, homeFromHour: Int = 16) {
        self.home = home
        self.work = work
        self.homeFromHour = homeFromHour
    }

    public static let empty = CommuteSettings()

    public func place(_ destination: CommuteDestination) -> SavedPlace? {
        destination == .work ? work : home
    }

    public var isSetUp: Bool { home != nil && work != nil }
}

public enum CommuteRules {
    /// Work in the morning, Home from `homeFromHour`. Only one place set → that place.
    public static func destination(at date: Date, settings: CommuteSettings, calendar: Calendar = .current) -> CommuteDestination? {
        switch (settings.home, settings.work) {
        case (nil, nil): return nil
        case (nil, _): return .work
        case (_, nil): return .home
        default:
            let hour = calendar.component(.hour, from: date)
            return hour >= settings.homeFromHour ? .home : .work
        }
    }

    /// The next time the destination flips (the switch hour today, or midnight).
    public static func nextSwitch(after date: Date, settings: CommuteSettings, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: date)
        let switchTime = calendar.date(bySettingHour: settings.homeFromHour, minute: 0, second: 0, of: start)
        if let switchTime, switchTime > date { return switchTime }
        return calendar.date(byAdding: .day, value: 1, to: start)
    }

    /// Travel times older than this are shown as "updating".
    public static let staleAfter: TimeInterval = 90 * 60
}

/// `commute-cache.json`: the last ETA computed.
public struct CommuteCache: Codable, Sendable, Equatable {
    public var destination: CommuteDestination
    public var travelSeconds: TimeInterval
    public var computedAt: Date
    /// True when the trip started from the phone's location rather than the other saved place.
    public var fromCurrentLocation: Bool

    public init(destination: CommuteDestination, travelSeconds: TimeInterval, computedAt: Date, fromCurrentLocation: Bool) {
        self.destination = destination
        self.travelSeconds = travelSeconds
        self.computedAt = computedAt
        self.fromCurrentLocation = fromCurrentLocation
    }
}

public struct CommuteCacheFile: Codable, Sendable, Equatable {
    public var latest: CommuteCache?
    public var lastError: String?

    public init(latest: CommuteCache? = nil, lastError: String? = nil) {
        self.latest = latest
        self.lastError = lastError
    }

    public static let empty = CommuteCacheFile()
}

// MARK: - Calendar

public struct CachedEvent: Codable, Sendable, Equatable, Hashable {
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?

    public init(title: String, start: Date, end: Date, location: String? = nil) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
    }
}

/// `calendar.json`: upcoming timed events, written by the app (and the widget when it has access).
public struct CalendarCache: Codable, Sendable, Equatable {
    public var events: [CachedEvent]
    public var updatedAt: Date?

    public init(events: [CachedEvent] = [], updatedAt: Date? = nil) {
        self.events = events
        self.updatedAt = updatedAt
    }

    public static let empty = CalendarCache()

    /// The next event that hasn't ended at `date`, within the next 24 hours.
    public func nextEvent(at date: Date) -> CachedEvent? {
        let horizon = date.addingTimeInterval(24 * 3600)
        return events
            .filter { $0.end > date && $0.start < horizon }
            .min { $0.start < $1.start }
    }
}

// MARK: - Weather & haze

public struct HourForecast: Codable, Sendable, Equatable {
    public var date: Date
    public var temperatureC: Double
    /// 0…1
    public var precipitationChance: Double
    public var symbol: String
    public var isRain: Bool

    public init(date: Date, temperatureC: Double, precipitationChance: Double, symbol: String, isRain: Bool) {
        self.date = date
        self.temperatureC = temperatureC
        self.precipitationChance = precipitationChance
        self.symbol = symbol
        self.isRain = isRain
    }
}

public struct WeatherSnapshot: Codable, Sendable, Equatable {
    public var observedAt: Date
    public var temperatureC: Double
    public var symbol: String
    public var condition: String
    public var isRainingNow: Bool
    public var hours: [HourForecast]

    public init(observedAt: Date, temperatureC: Double, symbol: String, condition: String, isRainingNow: Bool, hours: [HourForecast]) {
        self.observedAt = observedAt
        self.temperatureC = temperatureC
        self.symbol = symbol
        self.condition = condition
        self.isRainingNow = isRainingNow
        self.hours = hours
    }
}

public enum WeatherRules {
    /// An hour counts as rainy from this chance (or when rain is the forecast precipitation).
    public static let rainChance = 0.4

    /// Temperature and symbol for `date`: the forecast hour containing it, else "now".
    public static func conditions(at date: Date, in weather: WeatherSnapshot) -> (temperatureC: Double, symbol: String) {
        if date.timeIntervalSince(weather.observedAt) > 30 * 60,
           let hour = weather.hours.last(where: { $0.date <= date }),
           date.timeIntervalSince(hour.date) < 3600 {
            return (hour.temperatureC, hour.symbol)
        }
        return (weather.temperatureC, weather.symbol)
    }

    /// "Raining now", "Rain ~3 PM (60%)", or "No rain today", for the rest of `date`'s day.
    public static func rainText(at date: Date, in weather: WeatherSnapshot, calendar: Calendar = .current) -> String {
        if weather.isRainingNow, date.timeIntervalSince(weather.observedAt) < 45 * 60 {
            return "Raining now"
        }
        guard let rain = nextRainHour(after: date, in: weather, calendar: calendar) else {
            return "No rain today"
        }
        if rain.date <= date { return "Rain this hour" }
        let hour = rain.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        return "Rain ~\(hour) (\(Int((rain.precipitationChance * 100).rounded()))%)"
    }

    /// The first rainy forecast hour from the hour containing `date` until midnight.
    public static func nextRainHour(after date: Date, in weather: WeatherSnapshot, calendar: Calendar = .current) -> HourForecast? {
        let hourStart = date.addingTimeInterval(-3600)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return nil }
        return weather.hours
            .filter { $0.date > hourStart && $0.date < midnight }
            .sorted { $0.date < $1.date }
            .first { $0.isRain || $0.precipitationChance >= rainChance }
    }
}

/// Malaysian Air Pollutant Index bands (Department of Environment).
public enum AQIBand: String, Codable, Sendable, CaseIterable {
    case good
    case moderate
    case unhealthy
    case veryUnhealthy
    case hazardous

    public init(value: Int) {
        switch value {
        case ..<51: self = .good
        case 51...100: self = .moderate
        case 101...200: self = .unhealthy
        case 201...300: self = .veryUnhealthy
        default: self = .hazardous
        }
    }

    public var displayName: String {
        switch self {
        case .good: "Good"
        case .moderate: "Moderate"
        case .unhealthy: "Unhealthy"
        case .veryUnhealthy: "Very Unhealthy"
        case .hazardous: "Hazardous"
        }
    }

    /// DOE colours: blue, green, yellow, orange, red.
    public var hex: UInt32 {
        switch self {
        case .good: ThemeTokens.aqiGood
        case .moderate: ThemeTokens.aqiModerate
        case .unhealthy: ThemeTokens.aqiUnhealthy
        case .veryUnhealthy: ThemeTokens.aqiVeryUnhealthy
        case .hazardous: ThemeTokens.aqiHazardous
        }
    }

    public var urgency: Urgency {
        switch self {
        case .good, .moderate: .ok
        case .unhealthy: .dueSoon
        case .veryUnhealthy, .hazardous: .urgent
        }
    }
}

public struct AirQuality: Codable, Sendable, Equatable {
    public var value: Int
    public var station: String
    public var observedAt: Date?
    public var dominantPollutant: String?
    /// Name of the provider, for the app's source line.
    public var provider: String

    public init(value: Int, station: String, observedAt: Date?, dominantPollutant: String?, provider: String) {
        self.value = value
        self.station = station
        self.observedAt = observedAt
        self.dominantPollutant = dominantPollutant
        self.provider = provider
    }

    public var band: AQIBand { AQIBand(value: value) }
}

/// `weather.json`: latest weather and air quality, with fetch times and errors.
public struct WeatherCache: Codable, Sendable, Equatable {
    public var weather: WeatherSnapshot?
    public var air: AirQuality?
    public var weatherFetchedAt: Date?
    public var airFetchedAt: Date?
    public var weatherError: String?
    public var airError: String?
    /// Where the data is for, e.g. "Current location" or "Home".
    public var placeLabel: String?
    public var point: GeoPoint?

    public init(weather: WeatherSnapshot? = nil, air: AirQuality? = nil, weatherFetchedAt: Date? = nil, airFetchedAt: Date? = nil, weatherError: String? = nil, airError: String? = nil, placeLabel: String? = nil, point: GeoPoint? = nil) {
        self.weather = weather
        self.air = air
        self.weatherFetchedAt = weatherFetchedAt
        self.airFetchedAt = airFetchedAt
        self.weatherError = weatherError
        self.airError = airError
        self.placeLabel = placeLabel
        self.point = point
    }

    public static let empty = WeatherCache()
}

// MARK: - Map snapshot

/// What the map snapshot shows.
public enum MapTarget: Sendable, Equatable {
    case parking(GeoPoint, label: String)
    case commute(destination: GeoPoint, origin: GeoPoint?, label: String, symbol: String)

    /// Stable key: re-render only when this changes (to ~50 m).
    public var key: String {
        func r(_ p: GeoPoint) -> String { String(format: "%.4f,%.4f", p.latitude, p.longitude) }
        switch self {
        case .parking(let point, _): return "parking:\(r(point))"
        case .commute(let destination, let origin, _, _): return "commute:\(r(destination))>\(origin.map(r) ?? "-")"
        }
    }

    public var label: String {
        switch self {
        case .parking(_, let label): label
        case .commute(_, _, let label, _): label
        }
    }

    public var isParking: Bool {
        if case .parking = self { return true }
        return false
    }

    /// Parked car if there is one, otherwise the next commute destination.
    public static func choose(parking: ParkingState, commute: CommuteSettings, at date: Date, calendar: Calendar = .current) -> MapTarget? {
        if let spot = parking.spot, let point = spot.point {
            return .parking(point, label: spot.title)
        }
        guard let destination = CommuteRules.destination(at: date, settings: commute, calendar: calendar),
              let place = commute.place(destination) else { return nil }
        return .commute(
            destination: place.point,
            origin: commute.place(destination.other)?.point,
            label: "\(destination.title): \(place.name)",
            symbol: destination.symbol
        )
    }
}

/// `map.json`: one rendered PNG per widget size.
public struct MapSnapshotIndex: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var fileName: String
        public var targetKey: String
        public var renderedAt: Date

        public init(fileName: String, targetKey: String, renderedAt: Date) {
            self.fileName = fileName
            self.targetKey = targetKey
            self.renderedAt = renderedAt
        }
    }

    public var entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    public static let empty = MapSnapshotIndex()

    public static func sizeKey(width: Double, height: Double) -> String {
        "\(Int(width.rounded()))x\(Int(height.rounded()))"
    }

    /// The best image for a target: an exact size match, else any image of the same target.
    public func entry(for targetKey: String, sizeKey: String?) -> Entry? {
        if let sizeKey, let exact = entries[sizeKey], exact.targetKey == targetKey { return exact }
        return entries.values
            .filter { $0.targetKey == targetKey }
            .max { $0.renderedAt < $1.renderedAt }
    }
}

// MARK: - Stores

public enum LiveStores {
    public static func parking(in directory: URL = AppGroup.containerURL) -> JSONFileStore<ParkingState> {
        JSONFileStore(directory: directory, fileName: "parking.json") { .empty }
    }

    public static func commute(in directory: URL = AppGroup.containerURL) -> JSONFileStore<CommuteSettings> {
        JSONFileStore(directory: directory, fileName: "commute.json") { .empty }
    }

    public static func commuteCache(in directory: URL = AppGroup.containerURL) -> JSONFileStore<CommuteCacheFile> {
        JSONFileStore(directory: directory, fileName: "commute-cache.json") { .empty }
    }

    public static func calendar(in directory: URL = AppGroup.containerURL) -> JSONFileStore<CalendarCache> {
        JSONFileStore(directory: directory, fileName: "calendar.json") { .empty }
    }

    public static func weather(in directory: URL = AppGroup.containerURL) -> JSONFileStore<WeatherCache> {
        JSONFileStore(directory: directory, fileName: "weather.json") { .empty }
    }

    public static func map(in directory: URL = AppGroup.containerURL) -> JSONFileStore<MapSnapshotIndex> {
        JSONFileStore(directory: directory, fileName: "map.json") { .empty }
    }

    public static func lastLocation(in directory: URL = AppGroup.containerURL) -> JSONFileStore<LastLocation?> {
        JSONFileStore(directory: directory, fileName: "location.json") { nil }
    }
}
