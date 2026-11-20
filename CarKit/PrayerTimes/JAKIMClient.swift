import Foundation

/// JAKIM e-Solat API client.
///
/// Response format checked on 2026-11-20:
/// `{"prayerTime":[{"hijri":"1448-06-10","date":"20-Nov-2026","day":"Friday","imsak":"05:39:00",
///   "fajr":"05:49:00","syuruk":"06:58:00","dhuha":"07:23:00","dhuhr":"13:02:00","asr":"16:24:00",
///   "maghrib":"18:59:00","isha":"20:12:00"}, …],"status":"OK!","zone":"SGR01", …}`
/// - Month names in `date` are Malay ("Mac", "Mei", "Ogos", "Okt", "Dis").
/// - With no data, `prayerTime` is an object (`{"data":[…]}`) and `status` is `"NO_RECORD!"`.
/// - `period=duration` (POST `datestart`/`dateend`) stops at 31 December, and next year's
///   table only appears once JAKIM publishes it, so ranges are requested one year at a time.
public enum JAKIMClient {
    public static let endpoint = URL(string: "https://www.e-solat.gov.my/index.php?r=esolatApi/TakwimSolat&period=duration")

    public enum ClientError: Error, Equatable, LocalizedError {
        case badURL
        case http(Int)
        case noData(String)
        case unreadable

        public var errorDescription: String? {
            switch self {
            case .badURL: "Bad e-Solat URL"
            case .http(let code): "e-Solat returned HTTP \(code)"
            case .noData(let status): "e-Solat has no times for this range (\(status))"
            case .unreadable: "Couldn't read the e-Solat response"
            }
        }
    }

    // MARK: Parsing

    private struct Response: Decodable {
        let rows: [Row]
        let status: String

        enum CodingKeys: String, CodingKey { case prayerTime, status }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = (try? container.decode(String.self, forKey: .status)) ?? ""
            rows = (try? container.decode([Row].self, forKey: .prayerTime)) ?? []
        }
    }

    private struct Row: Decodable {
        let hijri: String?
        let date: String
        let fajr: String
        let syuruk: String
        let dhuhr: String
        let asr: String
        let maghrib: String
        let isha: String
    }

    /// Parses an e-Solat response into days. Throws `.noData` for a "NO_RECORD!" reply.
    public static func parse(_ data: Data, calendar: Calendar = PrayerCalendar.malaysia) throws -> [PrayerDay] {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ClientError.unreadable
        }
        guard !response.rows.isEmpty else {
            throw ClientError.noData(response.status.isEmpty ? "empty" : response.status)
        }
        let days = response.rows.compactMap { day(from: $0, calendar: calendar) }
        guard !days.isEmpty else { throw ClientError.unreadable }
        return days.sorted { $0.date < $1.date }
    }

    private static func day(from row: Row, calendar: Calendar) -> PrayerDay? {
        guard let date = parseDate(row.date, calendar: calendar) else { return nil }
        func at(_ text: String) -> Date? { time(text, on: date, calendar: calendar) }
        guard
            let fajr = at(row.fajr), let syuruk = at(row.syuruk), let dhuhr = at(row.dhuhr),
            let asr = at(row.asr), let maghrib = at(row.maghrib), let isha = at(row.isha)
        else { return nil }
        return PrayerDay(
            date: date, fajr: fajr, syuruk: syuruk, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha,
            hijri: row.hijri, origin: .jakim
        )
    }

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mac": 3, "mar": 3, "apr": 4, "mei": 5, "may": 5, "jun": 6,
        "jul": 7, "ogo": 8, "ogos": 8, "aug": 8, "sep": 9, "okt": 10, "oct": 10, "nov": 11,
        "dis": 12, "dec": 12,
    ]

    /// "20-Nov-2026" / "31-Dis-2026" → midnight of that day in Malaysia time.
    static func parseDate(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-")
        guard
            parts.count == 3,
            let day = Int(parts[0]),
            let month = months[parts[1].lowercased()],
            let year = Int(parts[2])
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// "13:02:00" on `day` → Date.
    static func time(_ text: String, on day: Date, calendar: Calendar) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    // MARK: Fetching

    /// POST request for one range (must not cross a year boundary).
    public static func request(zone: String, from start: Date, to end: Date, calendar: Calendar = PrayerCalendar.malaysia) throws -> URLRequest {
        guard let base = endpoint, var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw ClientError.badURL
        }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "zone", value: zone)]
        guard let url = components.url else { throw ClientError.badURL }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("datestart=\(isoDay(start, calendar))&dateend=\(isoDay(end, calendar))".utf8)
        return request
    }

    /// Times for `start…end`, split per calendar year. Years JAKIM hasn't published are skipped;
    /// throws only when nothing at all comes back.
    public static func fetch(zone: String, from start: Date, to end: Date, session: URLSession = .shared, calendar: Calendar = PrayerCalendar.malaysia) async throws -> [PrayerDay] {
        var days: [PrayerDay] = []
        var firstError: Error?
        for range in yearRanges(from: start, to: end, calendar: calendar) {
            do {
                let (data, response) = try await session.data(for: request(zone: zone, from: range.start, to: range.end, calendar: calendar))
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw ClientError.http(http.statusCode)
                }
                days += try parse(data, calendar: calendar)
            } catch {
                firstError = firstError ?? error
            }
        }
        if days.isEmpty { throw firstError ?? ClientError.unreadable }
        return days
    }

    /// Splits a range at 31 December.
    static func yearRanges(from start: Date, to end: Date, calendar: Calendar) -> [(start: Date, end: Date)] {
        var ranges: [(Date, Date)] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while cursor <= last {
            let year = calendar.component(.year, from: cursor)
            let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? last
            let rangeEnd = min(yearEnd, last)
            ranges.append((cursor, rangeEnd))
            guard let next = calendar.date(byAdding: .day, value: 1, to: rangeEnd) else { break }
            cursor = next
        }
        return ranges
    }

    private static func isoDay(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
