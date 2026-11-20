import Foundation

public enum FuelGrade: String, Codable, Sendable, CaseIterable {
    case ron95
    case ron97

    public var displayName: String {
        switch self {
        case .ron95: "RON95"
        case .ron97: "RON97"
        }
    }
}

public struct FillUp: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date
    public var odometerKm: Int
    public var litres: Double
    public var totalRM: Double
    public var grade: FuelGrade
    public var isFullTank: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        odometerKm: Int,
        litres: Double,
        totalRM: Double,
        grade: FuelGrade = .ron95,
        isFullTank: Bool = true
    ) {
        self.id = id
        self.date = date
        self.odometerKm = odometerKm
        self.litres = litres
        self.totalRM = totalRM
        self.grade = grade
        self.isFullTank = isFullTank
    }

    public var pricePerLitre: Double? {
        litres > 0 ? totalRM / litres : nil
    }
}

/// A change to the car (e.g. exhaust swap) used to compare consumption before and after.
public struct ModEvent: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date
    public var name: String

    public init(id: UUID = UUID(), date: Date, name: String) {
        self.id = id
        self.date = date
        self.name = name
    }
}

/// Everything the Fuel Log stores (`fuel.json`).
public struct FuelLog: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var fillUps: [FillUp]
    public var mods: [ModEvent]

    public init(version: Int = FuelLog.currentVersion, fillUps: [FillUp] = [], mods: [ModEvent] = []) {
        self.version = version
        self.fillUps = fillUps
        self.mods = mods
    }

    public static let empty = FuelLog()

    /// Fill-up odometer values double as odometer readings for the mileage estimate.
    public var odometerReadings: [OdometerReading] {
        fillUps.map { OdometerReading(id: $0.id, date: $0.date, km: $0.odometerKm) }
    }
}

/// Distance and fuel between two full tanks.
public struct FuelSegment: Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let km: Int
    public let litres: Double
    /// The full fill-up that closes this segment.
    public let endFillID: UUID

    public var kmPerLitre: Double { Double(km) / litres }
}

public enum FuelMath {
    /// Full-to-full segments. Every litre added after one full tank, up to and including the next
    /// full tank, was burnt over the km between those two fills. Partial fills before the first
    /// full tank are ignored because there is no reference point for them.
    public static func segments(_ fills: [FillUp]) -> [FuelSegment] {
        let sorted = fills.sorted {
            $0.odometerKm != $1.odometerKm ? $0.odometerKm < $1.odometerKm : $0.date < $1.date
        }
        var result: [FuelSegment] = []
        var lastFull: FillUp?
        var litresSince = 0.0
        for fill in sorted {
            guard let start = lastFull else {
                if fill.isFullTank { lastFull = fill }
                continue
            }
            litresSince += fill.litres
            if fill.isFullTank {
                let km = fill.odometerKm - start.odometerKm
                if km > 0, litresSince > 0 {
                    result.append(FuelSegment(
                        startDate: start.date,
                        endDate: fill.date,
                        km: km,
                        litres: litresSince,
                        endFillID: fill.id
                    ))
                }
                lastFull = fill
                litresSince = 0
            }
        }
        return result
    }

    /// Distance-weighted km/L over the last `count` full-to-full segments.
    public static func averageKmPerLitre(_ segments: [FuelSegment], last count: Int = 3) -> Double? {
        let recent = segments.suffix(count)
        let km = recent.reduce(0) { $0 + $1.km }
        let litres = recent.reduce(0.0) { $0 + $1.litres }
        guard km > 0, litres > 0 else { return nil }
        return Double(km) / litres
    }

    /// Price per litre of the most recent fill-up.
    public static func lastPricePerLitre(_ fills: [FillUp]) -> Double? {
        fills.max(by: { $0.date < $1.date })?.pricePerLitre
    }

    /// RM spent in the calendar month that contains `date`.
    public static func spentInMonth(of date: Date, fills: [FillUp], calendar: Calendar = .current) -> Double {
        fills
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalRM }
    }

    /// Average km/L of the segments that ended before the mod versus those that started on or after it.
    public static func comparison(around mod: ModEvent, segments: [FuelSegment]) -> (before: Double?, after: Double?) {
        let before = segments.filter { $0.endDate <= mod.date }
        let after = segments.filter { $0.startDate >= mod.date }
        return (
            averageKmPerLitre(before, last: before.count),
            averageKmPerLitre(after, last: after.count)
        )
    }
}
