import Foundation

public struct OdometerReading: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date
    public var km: Int

    public init(id: UUID = UUID(), date: Date, km: Int) {
        self.id = id
        self.date = date
        self.km = km
    }
}

/// A recurring service (interval in km and/or months) or a one-off check with its own due km/date.
public struct ServiceItem: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var isOneOff: Bool
    // Recurring
    public var intervalKm: Int?
    public var intervalMonths: Int?
    public var lastDoneKm: Int?
    public var lastDoneDate: Date?
    // One-off
    public var dueKm: Int?
    public var dueDate: Date?
    /// Set when a one-off item is ticked off; it then leaves the due list.
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "wrench.and.screwdriver.fill",
        isOneOff: Bool = false,
        intervalKm: Int? = nil,
        intervalMonths: Int? = nil,
        lastDoneKm: Int? = nil,
        lastDoneDate: Date? = nil,
        dueKm: Int? = nil,
        dueDate: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.isOneOff = isOneOff
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.lastDoneKm = lastDoneKm
        self.lastDoneDate = lastDoneDate
        self.dueKm = dueKm
        self.dueDate = dueDate
        self.completedAt = completedAt
    }

    /// Odometer value at which this item is next due, if it has a km rule.
    public var nextDueKm: Int? {
        if isOneOff { return dueKm }
        guard let intervalKm, let lastDoneKm else { return nil }
        return lastDoneKm + intervalKm
    }

    /// Date on which this item is next due, if it has a time rule.
    public func nextDueDate(calendar: Calendar = .current) -> Date? {
        if isOneOff { return dueDate }
        guard let intervalMonths, let lastDoneDate else { return nil }
        return calendar.date(byAdding: .month, value: intervalMonths, to: lastDoneDate)
    }

    public var isActive: Bool { !(isOneOff && completedAt != nil) }

    /// Records the service as done. Recurring items restart their interval; one-offs are closed.
    public mutating func markDone(km: Int, date: Date) {
        if isOneOff {
            completedAt = date
        } else {
            lastDoneKm = km
            lastDoneDate = date
        }
    }
}

public struct ServicePreset: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let symbol: String
    public let intervalKm: Int?
    public let intervalMonths: Int?

    /// Typical intervals for a 1.6 PureTech; editable per item. Check the service booklet.
    public static let all: [ServicePreset] = [
        ServicePreset(name: "Engine oil & filter", symbol: "oilcan.fill", intervalKm: 10_000, intervalMonths: 12),
        ServicePreset(name: "Tyre rotation", symbol: "arrow.triangle.2.circlepath", intervalKm: 10_000, intervalMonths: 12),
        ServicePreset(name: "Brake pads check", symbol: "exclamationmark.brakesignal", intervalKm: 20_000, intervalMonths: 12),
        ServicePreset(name: "Wheel alignment check", symbol: "steeringwheel", intervalKm: 20_000, intervalMonths: 12),
        ServicePreset(name: "Air filter", symbol: "wind", intervalKm: 20_000, intervalMonths: 24),
        ServicePreset(name: "Spark plugs", symbol: "bolt.fill", intervalKm: 60_000, intervalMonths: 48),
        ServicePreset(name: "Battery check", symbol: "minus.plus.batteryblock.fill", intervalKm: nil, intervalMonths: 12),
    ]

    public func makeItem(lastDoneKm: Int?, lastDoneDate: Date?) -> ServiceItem {
        ServiceItem(
            name: name,
            symbol: symbol,
            intervalKm: intervalKm,
            intervalMonths: intervalMonths,
            lastDoneKm: intervalKm == nil ? nil : lastDoneKm,
            lastDoneDate: lastDoneDate
        )
    }
}

/// Everything the Service Tracker stores (`service.json`).
public struct ServiceLog: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var readings: [OdometerReading]
    public var items: [ServiceItem]

    public init(version: Int = ServiceLog.currentVersion, readings: [OdometerReading] = [], items: [ServiceItem] = []) {
        self.version = version
        self.readings = readings
        self.items = items
    }

    public static let empty = ServiceLog()
}

// MARK: - Mileage estimation

public enum MileageEstimator {
    /// Readings older than this (counted back from the newest) are ignored for the average,
    /// so the estimate follows current driving habits.
    public static let averagingWindowDays: Double = 180

    /// Average km per day from the readings, or nil with fewer than two readings at least a day apart.
    public static func averageDailyKm(_ readings: [OdometerReading]) -> Double? {
        let sorted = readings.sorted { $0.date < $1.date }
        guard let newest = sorted.last else { return nil }
        let windowStart = newest.date.addingTimeInterval(-averagingWindowDays * 86_400)
        var window = sorted.filter { $0.date >= windowStart }
        if window.count < 2 { window = sorted }
        guard let first = window.first, let last = window.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86_400
        let km = Double(last.km - first.km)
        guard days >= 1, km >= 0 else { return nil }
        return km / days
    }

    /// Estimated odometer at `date`: the newest reading plus the daily average for the days since.
    public static func estimatedKm(_ readings: [OdometerReading], at date: Date) -> Int? {
        guard let newest = readings.max(by: { $0.date < $1.date }) else { return nil }
        let highest = readings.map(\.km).max() ?? newest.km
        guard let average = averageDailyKm(readings), date > newest.date else { return highest }
        let days = date.timeIntervalSince(newest.date) / 86_400
        return max(highest, newest.km + Int((average * days).rounded()))
    }
}

// MARK: - Due logic

public struct ServiceStatus: Sendable, Equatable, Identifiable {
    public var id: UUID { item.id }
    public let item: ServiceItem
    /// Km until due (negative when overdue), if the item has a km rule and the odometer is known.
    public let kmLeft: Int?
    /// Days until due (negative when overdue), if the item has a time rule.
    public let daysLeft: Int?
    public let urgency: Urgency
    /// Days until due, taking whichever comes first of km (converted via the daily average) and date.
    public let effectiveDaysLeft: Double?
}

public enum ServiceRules {
    /// Amber when within this many km...
    public static let dueSoonKm = 1_000
    /// ...or this many days.
    public static let dueSoonDays = 30

    public static func status(
        of item: ServiceItem,
        estimatedKm: Int?,
        averageDailyKm: Double?,
        now: Date,
        calendar: Calendar = .current
    ) -> ServiceStatus {
        var kmLeft: Int?
        if let due = item.nextDueKm, let estimatedKm {
            kmLeft = due - estimatedKm
        }
        var daysLeft: Int?
        if let dueDate = item.nextDueDate(calendar: calendar) {
            daysLeft = DayMath.days(from: now, to: dueDate, calendar: calendar)
        }

        let urgency: Urgency
        if (kmLeft.map { $0 <= 0 } ?? false) || (daysLeft.map { $0 < 0 } ?? false) {
            urgency = .urgent
        } else if (kmLeft.map { $0 <= dueSoonKm } ?? false) || (daysLeft.map { $0 <= dueSoonDays } ?? false) {
            urgency = .dueSoon
        } else {
            urgency = .ok
        }

        var candidates: [Double] = []
        if let daysLeft { candidates.append(Double(daysLeft)) }
        if let kmLeft {
            if let averageDailyKm, averageDailyKm > 0 {
                candidates.append(Double(kmLeft) / averageDailyKm)
            } else if kmLeft <= 0 {
                candidates.append(0)
            }
        }
        return ServiceStatus(
            item: item,
            kmLeft: kmLeft,
            daysLeft: daysLeft,
            urgency: urgency,
            effectiveDaysLeft: candidates.min()
        )
    }

    /// Active items, most urgent first: by urgency, then by whichever-comes-first days left.
    /// Items with no due data go last.
    public static func statuses(
        log: ServiceLog,
        extraReadings: [OdometerReading] = [],
        now: Date,
        calendar: Calendar = .current
    ) -> [ServiceStatus] {
        let readings = log.readings + extraReadings
        let estimate = MileageEstimator.estimatedKm(readings, at: now)
        let average = MileageEstimator.averageDailyKm(readings)
        return log.items
            .filter(\.isActive)
            .map { status(of: $0, estimatedKm: estimate, averageDailyKm: average, now: now, calendar: calendar) }
            .sorted { a, b in
                if a.urgency != b.urgency { return a.urgency > b.urgency }
                switch (a.effectiveDaysLeft, b.effectiveDaysLeft) {
                case let (x?, y?): return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return a.item.name < b.item.name
                }
            }
    }
}
