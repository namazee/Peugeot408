import Foundation

/// When each Malaysian seasonal pack is active.
///
/// - Islamic dates use the Umm al-Qura calendar built into iOS. JAKIM's official dates come from
///   moon sighting and can differ by a day, so the windows start a day or two early.
/// - Chinese New Year uses the Chinese calendar built into iOS.
/// - Deepavali follows the Hindu calendar (not in iOS), so it comes from a table you can edit
///   in Studio → Seasonal packs.
public enum SeasonalCalendar {
    /// Deepavali public holiday in Malaysia. 2026–2027 confirmed; later years are estimates to check against the gazette.
    public static let defaultDeepavali: [Int: String] = [
        2026: "2026-11-08",
        2027: "2027-10-28",
        2028: "2028-10-17",
        2029: "2029-11-05",
        2030: "2030-10-25",
    ]

    /// Highest priority first, for overlapping windows (e.g. Raya over the last days of Ramadan).
    static let priority: [SeasonalOccasion] = [.hariRaya, .aidiladha, .chineseNewYear, .deepavali, .newYear, .christmas, .merdeka, .ramadan]

    /// The occasion active at `date`, if any.
    public static func active(at date: Date, settings: SeasonalSettings, calendar: Calendar = PrayerCalendar.malaysia) -> SeasonalOccasion? {
        let day = calendar.startOfDay(for: date)
        return priority.first { occasion in
            !settings.disabled.contains(occasion)
                && windows(for: occasion, around: day, settings: settings, calendar: calendar).contains { $0.contains(day) }
        }
    }

    /// The occasion's windows in the years around `date` (inclusive day ranges, start-of-day dates).
    public static func windows(for occasion: SeasonalOccasion, around date: Date, settings: SeasonalSettings = SeasonalSettings(), calendar: Calendar = PrayerCalendar.malaysia) -> [ClosedRange<Date>] {
        let year = calendar.component(.year, from: date)
        return (year - 1...year + 1).flatMap { windows(for: occasion, year: year, settings: settings, calendar: calendar, gregorianYear: $0) }
    }

    /// The main day of an occasion in a Gregorian year (e.g. 1 Syawal), if it falls in that year.
    public static func mainDay(of occasion: SeasonalOccasion, year: Int, settings: SeasonalSettings = SeasonalSettings(), calendar: Calendar = PrayerCalendar.malaysia) -> Date? {
        switch occasion {
        case .ramadan: hijri(month: 9, day: 1, gregorianYear: year, calendar: calendar)
        case .hariRaya: hijri(month: 10, day: 1, gregorianYear: year, calendar: calendar)
        case .aidiladha: hijri(month: 12, day: 10, gregorianYear: year, calendar: calendar)
        case .merdeka: calendar.date(from: DateComponents(year: year, month: 8, day: 31))
        case .chineseNewYear: chineseNewYear(year, calendar: calendar)
        case .deepavali: settings.deepavaliDates[year].flatMap { isoDay($0, calendar: calendar) }
        case .christmas: calendar.date(from: DateComponents(year: year, month: 12, day: 25))
        case .newYear: calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        }
    }

    private static func windows(for occasion: SeasonalOccasion, year: Int, settings: SeasonalSettings, calendar: Calendar, gregorianYear: Int) -> [ClosedRange<Date>] {
        func range(_ start: Date?, _ before: Int, _ after: Int) -> [ClosedRange<Date>] {
            guard let start,
                  let from = calendar.date(byAdding: .day, value: -before, to: start),
                  let to = calendar.date(byAdding: .day, value: after, to: start) else { return [] }
            return [calendar.startOfDay(for: from)...calendar.startOfDay(for: to)]
        }
        let main = mainDay(of: occasion, year: gregorianYear, settings: settings, calendar: calendar)
        switch occasion {
        case .ramadan:
            // 1 Ramadan until the eve of Raya.
            guard let main, let raya = calendar.date(byAdding: .day, value: 29, to: main) else { return [] }
            return [main...raya]
        case .hariRaya: return range(main, 2, 6)          // countdown, then the first week of Syawal
        case .aidiladha: return range(main, 1, 3)
        case .merdeka:
            guard let main, let malaysiaDay = calendar.date(from: DateComponents(year: gregorianYear, month: 9, day: 16)) else { return [] }
            return range(main, 7, 0).map { $0.lowerBound...malaysiaDay }
        case .chineseNewYear: return range(main, 3, 14)   // until Chap Goh Mei
        case .deepavali: return range(main, 3, 2)
        case .christmas: return range(main, 7, 1)
        case .newYear: return range(main, 2, 1)
        }
    }

    /// Gregorian date of a Hijri day whose Gregorian year is `gregorianYear` (checks both Hijri years that overlap it).
    static func hijri(month: Int, day: Int, gregorianYear: Int, calendar: Calendar) -> Date? {
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = calendar.timeZone
        guard let jan1 = calendar.date(from: DateComponents(year: gregorianYear, month: 1, day: 1)) else { return nil }
        let hijriYear = islamic.component(.year, from: jan1)
        for candidate in [hijriYear, hijriYear + 1] {
            if let date = islamic.date(from: DateComponents(year: candidate, month: month, day: day)),
               calendar.component(.year, from: date) == gregorianYear {
                return calendar.startOfDay(for: date)
            }
        }
        return nil
    }

    static func chineseNewYear(_ gregorianYear: Int, calendar: Calendar) -> Date? {
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        // Mid-March is always after the new year, so its Chinese year is the one that starts this year.
        guard let march = calendar.date(from: DateComponents(year: gregorianYear, month: 3, day: 15)) else { return nil }
        let parts = chinese.dateComponents([.era, .year], from: march)
        guard let date = chinese.date(from: DateComponents(era: parts.era, year: parts.year, month: 1, day: 1)) else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// "2027-10-28" → that day.
    public static func isoDate(_ text: String, calendar: Calendar = PrayerCalendar.malaysia) -> Date? {
        isoDay(text, calendar: calendar)
    }

    static func isoDay(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The next midnight when the active occasion may change (for slot timelines).
    public static func nextChange(after date: Date, calendar: Calendar = PrayerCalendar.malaysia) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
    }
}
