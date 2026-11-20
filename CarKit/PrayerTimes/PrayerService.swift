import Foundation

/// The user's prayer settings.
public struct PrayerSettings: Codable, Sendable, Equatable {
    public var zoneCode: String
    /// When true, the app picks the zone from the phone's location each time it opens.
    public var autoZone: Bool

    public init(zoneCode: String = PrayerZone.defaultCode, autoZone: Bool = false) {
        self.zoneCode = zoneCode
        self.autoZone = autoZone
    }

    public var zone: PrayerZone {
        PrayerZone.zone(code: zoneCode) ?? PrayerZone.zone(code: PrayerZone.defaultCode) ?? PrayerZone.all[0]
    }
}

/// About a month of prayer times for one zone, cached on disk.
public struct PrayerCache: Codable, Sendable, Equatable {
    public var zoneCode: String
    public var days: [PrayerDay]
    /// Last successful JAKIM download.
    public var fetchedAt: Date?
    /// Last download attempt (successful or not), to avoid hammering e-Solat when it's down.
    public var attemptedAt: Date?
    public var lastError: String?

    public init(zoneCode: String = PrayerZone.defaultCode, days: [PrayerDay] = [], fetchedAt: Date? = nil, attemptedAt: Date? = nil, lastError: String? = nil) {
        self.zoneCode = zoneCode
        self.days = days
        self.fetchedAt = fetchedAt
        self.attemptedAt = attemptedAt
        self.lastError = lastError
    }

    public static let empty = PrayerCache()

    /// True when JAKIM times cover every day from `start` through `end`.
    public func hasJAKIM(from start: Date, through end: Date, calendar: Calendar = PrayerCalendar.malaysia) -> Bool {
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            guard days.contains(where: { $0.origin == .jakim && calendar.isDate($0.date, inSameDayAs: day) }) else { return false }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
            day = next
        }
        return true
    }
}

/// Keeps the prayer cache filled: JAKIM first, offline calculation for any gaps.
/// Works on a plain directory so it has no dependency on the rest of CarKit.
public struct PrayerService: Sendable {
    public static let settingsFile = "prayer-settings.json"
    public static let cacheFile = "prayer-cache.json"
    /// Days cached ahead ("a month ahead", plus a few days).
    public static let daysAhead = 35

    public let directory: URL
    public let calendar: Calendar

    public init(directory: URL, calendar: Calendar = PrayerCalendar.malaysia) {
        self.directory = directory
        self.calendar = calendar
    }

    // MARK: Files

    public func loadSettings() -> PrayerSettings { read(Self.settingsFile) ?? PrayerSettings() }
    public func saveSettings(_ settings: PrayerSettings) throws { try write(settings, to: Self.settingsFile) }
    public func loadCache() -> PrayerCache { read(Self.cacheFile) ?? .empty }
    public func saveCache(_ cache: PrayerCache) throws { try write(cache, to: Self.cacheFile) }

    // MARK: Refresh

    /// Downloads from e-Solat when the cache is for another zone, runs short, or is a week old.
    /// Failed attempts are retried at most hourly. Gaps are always filled by calculation, so the
    /// returned cache covers yesterday through `daysAhead` days.
    @discardableResult
    public func refreshIfNeeded(now: Date = .now, force: Bool = false, session: URLSession = .shared) async -> PrayerCache {
        let settings = loadSettings()
        var cache = loadCache()
        if cache.zoneCode != settings.zoneCode {
            cache = PrayerCache(zoneCode: settings.zoneCode)
        }

        let today = calendar.startOfDay(for: now)
        let soon = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let fresh = cache.hasJAKIM(from: today, through: soon, calendar: calendar) && (cache.fetchedAt ?? .distantPast) > weekAgo
        let recentlyTried = (cache.attemptedAt ?? .distantPast) > now.addingTimeInterval(-3_600)

        if force || (!fresh && !recentlyTried) {
            let start = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: Self.daysAhead, to: today) ?? today
            cache.attemptedAt = now
            do {
                let fetched = try await JAKIMClient.fetch(zone: settings.zoneCode, from: start, to: end, session: session, calendar: calendar)
                cache.days = Self.merge(existing: cache.days, incoming: fetched, calendar: calendar)
                cache.fetchedAt = now
                cache.lastError = nil
            } catch {
                cache.lastError = error.localizedDescription
            }
        }

        cache = Self.filled(cache, zone: settings.zone, now: now, calendar: calendar)
        try? saveCache(cache)
        return cache
    }

    /// Adds calculated days for every missing day from yesterday to `daysAhead`, and drops older days.
    public static func filled(_ cache: PrayerCache, zone: PrayerZone, now: Date, calendar: Calendar = PrayerCalendar.malaysia) -> PrayerCache {
        var result = cache
        let today = calendar.startOfDay(for: now)
        guard let first = calendar.date(byAdding: .day, value: -1, to: today) else { return result }
        var days = result.days.filter { $0.date >= first }
        for offset in 0...(daysAhead + 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            if !days.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }),
               let calculated = PrayerCalculator.jakim.day(for: day, zone: zone, calendar: calendar) {
                days.append(calculated)
            }
        }
        result.days = days.sorted { $0.date < $1.date }
        return result
    }

    /// JAKIM days replace any day already present; other days are kept.
    static func merge(existing: [PrayerDay], incoming: [PrayerDay], calendar: Calendar) -> [PrayerDay] {
        var result = existing.filter { old in !incoming.contains { calendar.isDate($0.date, inSameDayAs: old.date) } }
        result += incoming
        return result.sorted { $0.date < $1.date }
    }

    // MARK: JSON helpers (kept local so the module stays self-contained)

    private func read<T: Decodable>(_ name: String) -> T? {
        let url = directory.appending(path: name, directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: directory.appending(path: name, directoryHint: .notDirectory), options: .atomic)
    }
}
