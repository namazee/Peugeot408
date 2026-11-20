import Foundation

/// The data-driven widgets. Each can be added on its own or assigned to a Car Slot.
public enum DataSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case service
    case fuel
    case renewals
    case tng
    case parking
    case prayer
    case commute
    case weather
    case map

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .service: "Service Tracker"
        case .fuel: "Fuel Log"
        case .renewals: "Road Tax & Insurance"
        case .tng: "Touch 'n Go"
        case .parking: "Parking"
        case .prayer: "Prayer Times"
        case .commute: "Commute"
        case .weather: "Weather & Haze"
        case .map: "Map Snapshot"
        }
    }

    public var symbol: String {
        switch self {
        case .service: "wrench.and.screwdriver.fill"
        case .fuel: "fuelpump.fill"
        case .renewals: "calendar.badge.clock"
        case .tng: "creditcard.fill"
        case .parking: "parkingsign.circle.fill"
        case .prayer: "moon.stars.fill"
        case .commute: "car.rear.road.lane"
        case .weather: "cloud.sun.fill"
        case .map: "map.fill"
        }
    }

    /// Kind string of the dedicated widget.
    public var widgetKind: String {
        switch self {
        case .service: "ServiceTracker"
        case .fuel: "FuelLog"
        case .renewals: "Renewals"
        case .tng: "TouchNGo"
        case .parking: "Parking"
        case .prayer: "PrayerTimes"
        case .commute: "Commute"
        case .weather: "WeatherHaze"
        case .map: "MapSnapshot"
        }
    }

    /// `peugeot408://data/<source>` opens the matching screen in the app.
    public var deepLink: URL? {
        URL(string: "peugeot408://data/\(rawValue)")
    }

    /// Sources whose widgets must redraw when this source's data changes.
    /// Fill-ups carry odometer readings, so they move the service estimate too.
    public var affectedSources: [DataSource] {
        switch self {
        case .fuel: [.fuel, .service]
        // The map shows the parked car, or the commute destination when there is none.
        case .parking, .commute: [self, .map]
        default: [self]
        }
    }

    /// Sources whose data comes from the network or location (refreshed by `LiveRefresher`).
    public var isLive: Bool {
        switch self {
        case .prayer, .commute, .weather, .map: true
        default: false
        }
    }
}

/// File names in the App Group container.
public enum CarStores {
    public static func service(in directory: URL = AppGroup.containerURL) -> JSONFileStore<ServiceLog> {
        JSONFileStore(directory: directory, fileName: "service.json") { .empty }
    }

    public static func fuel(in directory: URL = AppGroup.containerURL) -> JSONFileStore<FuelLog> {
        JSONFileStore(directory: directory, fileName: "fuel.json") { .empty }
    }

    public static func renewals(in directory: URL = AppGroup.containerURL) -> JSONFileStore<RenewalLog> {
        JSONFileStore(directory: directory, fileName: "renewals.json") { .empty }
    }

    public static func tng(in directory: URL = AppGroup.containerURL) -> JSONFileStore<TnGState> {
        JSONFileStore(directory: directory, fileName: "tng.json") { .empty }
    }
}

/// All Phase 2 data in one value, as the widgets read it.
public struct CarData: Sendable, Equatable {
    public var service: ServiceLog
    public var fuel: FuelLog
    public var renewals: RenewalLog
    public var tng: TnGState
    // Phase 3
    public var parking: ParkingState
    public var prayerSettings: PrayerSettings
    public var prayer: PrayerCache
    public var commute: CommuteSettings
    public var commuteCache: CommuteCacheFile
    public var calendar: CalendarCache
    public var weather: WeatherCache
    public var map: MapSnapshotIndex
    /// Folder the map PNGs live in.
    public var directory: URL?

    public init(
        service: ServiceLog = .empty,
        fuel: FuelLog = .empty,
        renewals: RenewalLog = .empty,
        tng: TnGState = .empty,
        parking: ParkingState = .empty,
        prayerSettings: PrayerSettings = PrayerSettings(),
        prayer: PrayerCache = .empty,
        commute: CommuteSettings = .empty,
        commuteCache: CommuteCacheFile = .empty,
        calendar: CalendarCache = .empty,
        weather: WeatherCache = .empty,
        map: MapSnapshotIndex = .empty,
        directory: URL? = nil
    ) {
        self.service = service
        self.fuel = fuel
        self.renewals = renewals
        self.tng = tng
        self.parking = parking
        self.prayerSettings = prayerSettings
        self.prayer = prayer
        self.commute = commute
        self.commuteCache = commuteCache
        self.calendar = calendar
        self.weather = weather
        self.map = map
        self.directory = directory
    }

    public static let empty = CarData()

    public static func load(from directory: URL = AppGroup.containerURL) -> CarData {
        let prayer = PrayerService(directory: directory)
        return CarData(
            service: CarStores.service(in: directory).load(),
            fuel: CarStores.fuel(in: directory).load(),
            renewals: CarStores.renewals(in: directory).load(),
            tng: CarStores.tng(in: directory).load(),
            parking: LiveStores.parking(in: directory).load(),
            prayerSettings: prayer.loadSettings(),
            prayer: prayer.loadCache(),
            commute: LiveStores.commute(in: directory).load(),
            commuteCache: LiveStores.commuteCache(in: directory).load(),
            calendar: LiveStores.calendar(in: directory).load(),
            weather: LiveStores.weather(in: directory).load(),
            map: LiveStores.map(in: directory).load(),
            directory: directory
        )
    }

    public func serviceStatuses(at date: Date, calendar: Calendar = .current) -> [ServiceStatus] {
        ServiceRules.statuses(log: service, extraReadings: fuel.odometerReadings, now: date, calendar: calendar)
    }

    public func estimatedKm(at date: Date) -> Int? {
        MileageEstimator.estimatedKm(service.readings + fuel.odometerReadings, at: date)
    }

    /// View-ready snapshot of one source at `date`.
    public func card(for source: DataSource, at date: Date, calendar: Calendar = .current) -> DataCard {
        switch source {
        case .service:
            let lines = serviceStatuses(at: date, calendar: calendar).prefix(3).map {
                ServiceLine(
                    name: $0.item.name,
                    symbol: $0.item.symbol,
                    kmLeft: $0.kmLeft,
                    daysLeft: $0.daysLeft,
                    urgency: $0.urgency
                )
            }
            return .service(ServiceSummary(lines: Array(lines), estimatedKm: estimatedKm(at: date)))

        case .fuel:
            let segments = FuelMath.segments(fuel.fillUps)
            return .fuel(FuelSummary(
                lastPricePerLitre: FuelMath.lastPricePerLitre(fuel.fillUps),
                averageKmPerLitre: FuelMath.averageKmPerLitre(segments),
                spentThisMonth: FuelMath.spentInMonth(of: date, fills: fuel.fillUps, calendar: calendar),
                hasFills: !fuel.fillUps.isEmpty
            ))

        case .renewals:
            let lines = RenewalRules.sorted(renewals.items).prefix(3).map { item in
                let days = RenewalRules.daysLeft(until: item.expiry, from: date, calendar: calendar)
                return RenewalLine(
                    name: item.displayName,
                    symbol: item.kind.symbol,
                    expiry: item.expiry,
                    daysLeft: days,
                    urgency: RenewalRules.urgency(daysLeft: days)
                )
            }
            return .renewals(RenewalSummary(lines: Array(lines)))

        case .tng:
            return .tng(TnGSummary(balance: tng.balance, threshold: tng.threshold, isLow: tng.isLow))

        case .parking, .prayer, .commute, .weather, .map:
            return liveCard(for: source, at: date, calendar: calendar)
        }
    }
}

// MARK: - View-ready summaries

public struct ServiceLine: Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let kmLeft: Int?
    public let daysLeft: Int?
    public let urgency: Urgency

    public init(name: String, symbol: String, kmLeft: Int?, daysLeft: Int?, urgency: Urgency) {
        self.name = name
        self.symbol = symbol
        self.kmLeft = kmLeft
        self.daysLeft = daysLeft
        self.urgency = urgency
    }

    public var isOverdue: Bool {
        (kmLeft.map { $0 <= 0 } ?? false) || (daysLeft.map { $0 < 0 } ?? false)
    }

    /// Big value: km left if known, otherwise days left.
    public var primaryText: String {
        if let kmLeft { return CarFormat.km(abs(kmLeft)) }
        if let daysLeft { return CarFormat.days(abs(daysLeft)) }
        return "Not set"
    }

    /// Second line: days left when the big value is km, or a short status.
    public var secondaryText: String {
        if isOverdue { return "Overdue" }
        if kmLeft != nil, let daysLeft { return "\(CarFormat.days(daysLeft)) left" }
        return "left"
    }

    /// One line, e.g. "1,240 km / 23 days".
    public var compactText: String {
        var parts: [String] = []
        if let kmLeft { parts.append(kmLeft <= 0 ? "\(CarFormat.km(-kmLeft)) over" : CarFormat.km(kmLeft)) }
        if let daysLeft { parts.append(daysLeft < 0 ? "\(CarFormat.days(-daysLeft)) late" : CarFormat.days(daysLeft)) }
        return parts.isEmpty ? "Not set" : parts.joined(separator: " / ")
    }
}

public struct ServiceSummary: Sendable, Equatable {
    public let lines: [ServiceLine]
    public let estimatedKm: Int?

    public init(lines: [ServiceLine], estimatedKm: Int?) {
        self.lines = lines
        self.estimatedKm = estimatedKm
    }
}

public struct FuelSummary: Sendable, Equatable {
    public let lastPricePerLitre: Double?
    public let averageKmPerLitre: Double?
    public let spentThisMonth: Double
    public let hasFills: Bool

    public init(lastPricePerLitre: Double?, averageKmPerLitre: Double?, spentThisMonth: Double, hasFills: Bool) {
        self.lastPricePerLitre = lastPricePerLitre
        self.averageKmPerLitre = averageKmPerLitre
        self.spentThisMonth = spentThisMonth
        self.hasFills = hasFills
    }
}

public struct RenewalLine: Sendable, Equatable {
    public let name: String
    public let symbol: String
    public let expiry: Date
    public let daysLeft: Int
    public let urgency: Urgency

    public init(name: String, symbol: String, expiry: Date, daysLeft: Int, urgency: Urgency) {
        self.name = name
        self.symbol = symbol
        self.expiry = expiry
        self.daysLeft = daysLeft
        self.urgency = urgency
    }

    /// Big countdown number.
    public var countText: String { "\(abs(daysLeft))" }

    public var unitText: String {
        if daysLeft < 0 { return abs(daysLeft) == 1 ? "day overdue" : "days overdue" }
        if daysLeft == 0 { return "expires today" }
        return daysLeft == 1 ? "day left" : "days left"
    }
}

public struct RenewalSummary: Sendable, Equatable {
    public let lines: [RenewalLine]

    public init(lines: [RenewalLine]) {
        self.lines = lines
    }
}

public struct TnGSummary: Sendable, Equatable {
    public let balance: Double?
    public let threshold: Double
    public let isLow: Bool

    public init(balance: Double?, threshold: Double, isLow: Bool) {
        self.balance = balance
        self.threshold = threshold
        self.isLow = isLow
    }
}

/// What a data widget (or a slot showing one) draws for one timeline entry.
public enum DataCard: Sendable, Equatable {
    case service(ServiceSummary)
    case fuel(FuelSummary)
    case renewals(RenewalSummary)
    case tng(TnGSummary)
    case parking(ParkingSummary)
    case prayer(PrayerSummary)
    case commute(CommuteSummary)
    case weather(WeatherSummary)
    case map(MapSummary)

    public var source: DataSource {
        switch self {
        case .service: .service
        case .fuel: .fuel
        case .renewals: .renewals
        case .tng: .tng
        case .parking: .parking
        case .prayer: .prayer
        case .commute: .commute
        case .weather: .weather
        case .map: .map
        }
    }

    /// Drives the card tint: amber or red when something needs attention.
    public var urgency: Urgency {
        switch self {
        case .service(let summary): summary.lines.first?.urgency ?? .ok
        case .fuel: .ok
        case .renewals(let summary): summary.lines.first?.urgency ?? .ok
        case .tng(let summary): summary.isLow ? .dueSoon : .ok
        case .weather(let summary): summary.air?.band.urgency ?? .ok
        case .parking, .prayer, .commute, .map: .ok
        }
    }
}

// MARK: - Timelines

public enum DataTimeline {
    /// One entry per date from `dates(for:)`.
    public static func items(for source: DataSource, data: CarData, now: Date, calendar: Calendar = .current) -> [(date: Date, card: DataCard)] {
        dates(for: source, data: data, from: now, calendar: calendar).map { date in
            (date, data.card(for: source, at: date, calendar: calendar))
        }
    }

    /// When the card's content changes on its own:
    /// - Phase 2 cards and Parking: now and each of the next 7 midnights (day counts; parking's
    ///   "ago" text ticks by itself).
    /// - Prayer: every prayer time in the next 2 days (the "next prayer" moves on), plus midnights.
    /// - Commute: the switch to the trip home, the start and end of upcoming events, midnight.
    /// - Weather: each of the next 6 forecast hours.
    /// - Map: a single entry (the image only changes when it's re-rendered).
    public static func dates(for source: DataSource, data: CarData, from start: Date, calendar: Calendar = .current) -> [Date] {
        var dates: [Date]
        switch source {
        case .service, .fuel, .renewals, .tng, .parking:
            return DayMath.refreshDates(from: start, calendar: calendar)

        case .prayer:
            let horizon = start.addingTimeInterval(48 * 3600)
            dates = PrayerSchedule.moments(in: data.prayer.days)
                .map(\.time)
                .filter { $0 > start && $0 <= horizon }
            dates += DayMath.refreshDates(from: start, days: 2, calendar: calendar).dropFirst()

        case .commute:
            let horizon = start.addingTimeInterval(24 * 3600)
            dates = [CommuteRules.nextSwitch(after: start, settings: data.commute, calendar: calendar)].compactMap { $0 }
            dates += data.calendar.events.flatMap { [$0.start, $0.end] }.filter { $0 > start && $0 <= horizon }
            dates += DayMath.refreshDates(from: start, days: 1, calendar: calendar).dropFirst()

        case .weather:
            dates = (data.weather.weather?.hours ?? []).map(\.date).filter { $0 > start }.prefix(6).map { $0 }

        case .map:
            return [start]
        }
        let unique = Set(dates.filter { $0 > start })
        return [start] + unique.sorted().prefix(40)
    }

    /// When WidgetKit should ask for a new timeline. Nil means after the last entry (`.atEnd`).
    /// Live data that comes from the network asks again sooner.
    public static func reloadDate(for source: DataSource, data: CarData, now: Date) -> Date? {
        switch source {
        case .commute, .weather:
            return now.addingTimeInterval(30 * 60)
        case .map:
            return data.parking.spot == nil ? now.addingTimeInterval(60 * 60) : nil
        default:
            return nil
        }
    }
}
