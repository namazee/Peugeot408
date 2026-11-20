import Foundation

/// The data-driven widgets. Each can be added on its own or assigned to a Car Slot.
public enum DataSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case service
    case fuel
    case renewals
    case tng

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .service: "Service Tracker"
        case .fuel: "Fuel Log"
        case .renewals: "Road Tax & Insurance"
        case .tng: "Touch 'n Go"
        }
    }

    public var symbol: String {
        switch self {
        case .service: "wrench.and.screwdriver.fill"
        case .fuel: "fuelpump.fill"
        case .renewals: "calendar.badge.clock"
        case .tng: "creditcard.fill"
        }
    }

    /// Kind string of the dedicated widget.
    public var widgetKind: String {
        switch self {
        case .service: "ServiceTracker"
        case .fuel: "FuelLog"
        case .renewals: "Renewals"
        case .tng: "TouchNGo"
        }
    }

    /// `peugeot408://data/<source>` opens the matching screen in the app.
    public var deepLink: URL? {
        URL(string: "peugeot408://data/\(rawValue)")
    }

    /// Sources whose widgets must redraw when this source's data changes.
    /// Fill-ups carry odometer readings, so they move the service estimate too.
    public var affectedSources: [DataSource] {
        self == .fuel ? [.fuel, .service] : [self]
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

    public init(service: ServiceLog = .empty, fuel: FuelLog = .empty, renewals: RenewalLog = .empty, tng: TnGState = .empty) {
        self.service = service
        self.fuel = fuel
        self.renewals = renewals
        self.tng = tng
    }

    public static let empty = CarData()

    public static func load(from directory: URL = AppGroup.containerURL) -> CarData {
        CarData(
            service: CarStores.service(in: directory).load(),
            fuel: CarStores.fuel(in: directory).load(),
            renewals: CarStores.renewals(in: directory).load(),
            tng: CarStores.tng(in: directory).load()
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

    public var source: DataSource {
        switch self {
        case .service: .service
        case .fuel: .fuel
        case .renewals: .renewals
        case .tng: .tng
        }
    }

    /// Drives the card tint: amber or red when something needs attention.
    public var urgency: Urgency {
        switch self {
        case .service(let summary): summary.lines.first?.urgency ?? .ok
        case .fuel: .ok
        case .renewals(let summary): summary.lines.first?.urgency ?? .ok
        case .tng(let summary): summary.isLow ? .dueSoon : .ok
        }
    }
}

// MARK: - Timelines

public enum DataTimeline {
    /// Entries for now and each of the next 7 midnights (day counts and "this month" change daily).
    public static func items(for source: DataSource, data: CarData, now: Date, calendar: Calendar = .current) -> [(date: Date, card: DataCard)] {
        DayMath.refreshDates(from: now, calendar: calendar).map { date in
            (date, data.card(for: source, at: date, calendar: calendar))
        }
    }
}
