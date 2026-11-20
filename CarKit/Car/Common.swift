import Foundation

/// How pressing something is. Drives the amber / red colouring on widgets.
public enum Urgency: Int, Codable, Sendable, Comparable, CaseIterable {
    case ok
    /// Amber.
    case dueSoon
    /// Red: overdue, or a renewal 7 days or less away.
    case urgent

    public static func < (lhs: Urgency, rhs: Urgency) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum DayMath {
    /// Whole calendar days from `from` to `to` (negative when `to` is in the past).
    public static func days(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// `now`, then each of the next `count` midnights. Used for timelines whose text changes daily.
    public static func refreshDates(from now: Date, days count: Int = 7, calendar: Calendar = .current) -> [Date] {
        var dates = [now]
        var day = calendar.startOfDay(for: now)
        for _ in 0..<count {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            dates.append(next)
            day = next
        }
        return dates
    }
}

/// Number formatting shared by the app and the widgets.
public enum CarFormat {
    public static func km(_ value: Int) -> String {
        "\(value.formatted()) km"
    }

    public static func rm(_ value: Double, decimals: Int = 2) -> String {
        "RM \(value.formatted(.number.precision(.fractionLength(decimals))))"
    }

    public static func kmPerLitre(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) km/L"
    }

    public static func litres(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2)))) L"
    }

    public static func days(_ value: Int) -> String {
        value == 1 ? "1 day" : "\(value) days"
    }
}
