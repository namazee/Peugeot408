import Foundation

// Self-contained prayer-times module: depends on Foundation only, so it can be copied into
// another app as-is (see docs/SPEC.md §4, item 6).

/// The daily times JAKIM publishes. `syuruk` (sunrise) is not a prayer but is shown in lists.
public enum Prayer: String, Codable, Sendable, CaseIterable, Identifiable {
    case fajr
    case syuruk
    case dhuhr
    case asr
    case maghrib
    case isha

    public var id: String { rawValue }

    /// Malay names, as used by JAKIM and mosques in Malaysia.
    public var displayName: String {
        switch self {
        case .fajr: "Subuh"
        case .syuruk: "Syuruk"
        case .dhuhr: "Zohor"
        case .asr: "Asar"
        case .maghrib: "Maghrib"
        case .isha: "Isyak"
        }
    }

    public var symbol: String {
        switch self {
        case .fajr: "sun.haze.fill"
        case .syuruk: "sunrise.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.min.fill"
        case .maghrib: "sunset.fill"
        case .isha: "moon.stars.fill"
        }
    }

    /// False for syuruk: it never becomes the "next prayer".
    public var isPrayer: Bool { self != .syuruk }

    /// The five daily prayers.
    public static let fard: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}

/// Where a day's times came from.
public enum PrayerTimesOrigin: String, Codable, Sendable {
    /// JAKIM e-Solat.
    case jakim
    /// Offline calculation with JAKIM-style parameters (API down, or the year isn't published yet).
    case calculated
}

/// One day of prayer times for a zone.
public struct PrayerDay: Codable, Sendable, Equatable {
    /// Midnight at the start of the day, in Malaysia time.
    public var date: Date
    public var fajr: Date
    public var syuruk: Date
    public var dhuhr: Date
    public var asr: Date
    public var maghrib: Date
    public var isha: Date
    public var hijri: String?
    public var origin: PrayerTimesOrigin

    public init(
        date: Date,
        fajr: Date,
        syuruk: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        hijri: String? = nil,
        origin: PrayerTimesOrigin
    ) {
        self.date = date
        self.fajr = fajr
        self.syuruk = syuruk
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.hijri = hijri
        self.origin = origin
    }

    public func time(of prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: fajr
        case .syuruk: syuruk
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    public var moments: [PrayerMoment] {
        Prayer.allCases.map { PrayerMoment(prayer: $0, time: time(of: $0), origin: origin) }
    }
}

/// A single prayer at a single time.
public struct PrayerMoment: Codable, Sendable, Equatable, Hashable {
    public let prayer: Prayer
    public let time: Date
    public let origin: PrayerTimesOrigin

    public init(prayer: Prayer, time: Date, origin: PrayerTimesOrigin = .jakim) {
        self.prayer = prayer
        self.time = time
        self.origin = origin
    }
}

public enum PrayerCalendar {
    /// Gregorian calendar in Malaysia time (UTC+8), used for all JAKIM dates.
    public static let malaysia: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .gmt
        calendar.locale = Locale(identifier: "en_MY")
        return calendar
    }()
}

/// "Next prayer" logic, including the jump from Isyak to tomorrow's Subuh.
public enum PrayerSchedule {
    /// All moments in `days`, sorted by time.
    public static func moments(in days: [PrayerDay], includeSyuruk: Bool = false) -> [PrayerMoment] {
        days.flatMap(\.moments)
            .filter { includeSyuruk || $0.prayer.isPrayer }
            .sorted { $0.time < $1.time }
    }

    /// The first prayer strictly after `date`. Nil only when `days` doesn't reach that far.
    public static func next(after date: Date, in days: [PrayerDay]) -> PrayerMoment? {
        moments(in: days).first { $0.time > date }
    }

    /// The prayer whose time has most recently started at `date` (Isyak until tomorrow's Subuh).
    public static func current(at date: Date, in days: [PrayerDay]) -> PrayerMoment? {
        moments(in: days).last { $0.time <= date }
    }

    /// The day that contains `date` in Malaysia time.
    public static func day(containing date: Date, in days: [PrayerDay], calendar: Calendar = PrayerCalendar.malaysia) -> PrayerDay? {
        let start = calendar.startOfDay(for: date)
        return days.first { calendar.isDate($0.date, inSameDayAs: start) }
    }
}
