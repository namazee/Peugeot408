import Foundation

/// Sunrise and sunset for the Live Sky background (spec §4b, Phase 16).
public struct SunTimes: Sendable, Equatable, Hashable {
    public var sunrise: Date
    public var sunset: Date

    public init(sunrise: Date, sunset: Date) {
        self.sunrise = sunrise
        self.sunset = sunset
    }
}

/// The part of the day the Live Sky shows.
public enum SkyPhase: String, Sendable, CaseIterable {
    case night, dawn, day, dusk
}

public enum Sky {
    /// Dawn and dusk last from this long before to this long after sunrise / sunset.
    public static let twilight: TimeInterval = 40 * 60

    /// Today's Syuruk and Maghrib, or 7:15 am and 7:20 pm when there are no prayer times.
    public static func sunTimes(on date: Date, prayerDays: [PrayerDay], calendar: Calendar = .current) -> SunTimes {
        if let day = PrayerSchedule.day(containing: date, in: prayerDays) {
            return SunTimes(sunrise: day.syuruk, sunset: day.maghrib)
        }
        let start = calendar.startOfDay(for: date)
        return SunTimes(sunrise: start.addingTimeInterval(7 * 3600 + 15 * 60), sunset: start.addingTimeInterval(19 * 3600 + 20 * 60))
    }

    public static func phase(at date: Date, sun: SunTimes) -> SkyPhase {
        if abs(date.timeIntervalSince(sun.sunrise)) <= twilight { return .dawn }
        if abs(date.timeIntervalSince(sun.sunset)) <= twilight { return .dusk }
        return date > sun.sunrise && date < sun.sunset ? .day : .night
    }

    /// Where the sun is on its arc: 0 at sunrise, 1 at sunset (clamped).
    public static func sunProgress(at date: Date, sun: SunTimes) -> Double {
        let length = sun.sunset.timeIntervalSince(sun.sunrise)
        guard length > 0 else { return 0.5 }
        return min(max(date.timeIntervalSince(sun.sunrise) / length, 0), 1)
    }

    /// When the sky changes on its own over the next two days: the start and end of dawn and dusk,
    /// and every hour while the sun is up (it moves along its arc).
    public static func changeDates(from start: Date, prayerDays: [PrayerDay], calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        for offset in 0..<2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let sun = sunTimes(on: day, prayerDays: prayerDays, calendar: calendar)
            dates += [sun.sunrise - twilight, sun.sunrise + twilight, sun.sunset - twilight, sun.sunset + twilight]
            var hour = sun.sunrise + twilight + 3600
            while hour < sun.sunset - twilight {
                dates.append(hour)
                hour += 3600
            }
        }
        return dates.filter { $0 > start }
    }
}
