import Foundation

public enum RenewalKind: String, Codable, Sendable, CaseIterable {
    case roadTax
    case insurance
    case licence
    case puspakom
    case other

    public var displayName: String {
        switch self {
        case .roadTax: "Road tax"
        case .insurance: "Insurance"
        case .licence: "Driving licence"
        case .puspakom: "Puspakom"
        case .other: "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .roadTax: "doc.text.fill"
        case .insurance: "shield.lefthalf.filled"
        case .licence: "person.text.rectangle.fill"
        case .puspakom: "checkmark.seal.fill"
        case .other: "calendar.badge.clock"
        }
    }
}

public struct Renewal: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var kind: RenewalKind
    /// Optional custom label; the kind's name is used when empty.
    public var name: String
    public var expiry: Date

    public init(id: UUID = UUID(), kind: RenewalKind, name: String = "", expiry: Date) {
        self.id = id
        self.kind = kind
        self.name = name
        self.expiry = expiry
    }

    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.displayName : trimmed
    }
}

/// Everything the Road Tax & Insurance tracker stores (`renewals.json`).
public struct RenewalLog: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var items: [Renewal]

    public init(version: Int = RenewalLog.currentVersion, items: [Renewal] = []) {
        self.version = version
        self.items = items
    }

    public static let empty = RenewalLog()
}

public enum RenewalRules {
    /// Amber at this many days or fewer.
    public static let dueSoonDays = 30
    /// Red at this many days or fewer, and when overdue.
    public static let urgentDays = 7
    /// Local reminders go out this many days before expiry.
    public static let reminderDaysBefore = [30, 7]
    /// Reminder time of day (24 h clock).
    public static let reminderHour = 9

    public static func daysLeft(until expiry: Date, from now: Date, calendar: Calendar = .current) -> Int {
        DayMath.days(from: now, to: expiry, calendar: calendar)
    }

    public static func urgency(daysLeft: Int) -> Urgency {
        if daysLeft <= urgentDays { return .urgent }
        if daysLeft <= dueSoonDays { return .dueSoon }
        return .ok
    }

    /// Items ordered by expiry, so overdue items come first and the nearest renewal is `first`.
    public static func sorted(_ items: [Renewal]) -> [Renewal] {
        items.sorted { $0.expiry < $1.expiry }
    }

    /// Reminder fire dates (09:00, 30 and 7 days before expiry) that are still in the future.
    public static func reminderDates(for expiry: Date, now: Date, calendar: Calendar = .current) -> [(daysBefore: Int, date: Date)] {
        reminderDaysBefore.compactMap { daysBefore in
            let day = calendar.startOfDay(for: expiry)
            guard
                let shifted = calendar.date(byAdding: .day, value: -daysBefore, to: day),
                let fire = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: shifted),
                fire > now
            else { return nil }
            return (daysBefore, fire)
        }
    }
}
