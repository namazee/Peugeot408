import Foundation

// Synced lyrics (spec §4 item 13, Phase 13). The app reads the song and position from the Apple
// Music system player, fetches time-coded lyrics from LRCLIB (free, no key), and saves them here
// with an anchor (when the song started). The widget then pre-schedules one timeline entry per
// line, so lines change without the app running. Lyrics are fetched on demand, cached for songs
// you play, and never bundled.

/// One time-coded line.
public struct LyricLine: Codable, Sendable, Equatable, Hashable {
    /// Seconds from the start of the song.
    public var time: Double
    public var text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

/// Lyrics for one song.
public struct SongLyrics: Codable, Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String?
    public var duration: Double?
    /// Time-coded lines (empty when only plain lyrics exist).
    public var lines: [LyricLine]
    /// Plain (unsynced) lyrics, when that's all LRCLIB has.
    public var plain: String?
    public var instrumental: Bool
    public var fetchedAt: Date

    public init(title: String, artist: String, album: String? = nil, duration: Double? = nil, lines: [LyricLine] = [], plain: String? = nil, instrumental: Bool = false, fetchedAt: Date = .now) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.lines = lines
        self.plain = plain
        self.instrumental = instrumental
        self.fetchedAt = fetchedAt
    }

    public var isSynced: Bool { !lines.isEmpty }

    /// Cache key: lower-cased title and artist.
    public static func key(title: String, artist: String) -> String {
        "\(artist.lowercased().trimmingCharacters(in: .whitespaces))|\(title.lowercased().trimmingCharacters(in: .whitespaces))"
    }

    public var key: String { Self.key(title: title, artist: artist) }
}

/// What is playing, as last seen by the app.
public struct NowPlaying: Codable, Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String?
    public var duration: Double?
    /// When position 0 of the song was (now − playback time). Moves when you pause or seek.
    public var songStart: Date
    public var isPlaying: Bool
    public var seenAt: Date

    public init(title: String, artist: String, album: String? = nil, duration: Double? = nil, songStart: Date, isPlaying: Bool, seenAt: Date = .now) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.songStart = songStart
        self.isPlaying = isPlaying
        self.seenAt = seenAt
    }

    public var key: String { SongLyrics.key(title: title, artist: artist) }

    /// Playback position at `date` (stays put while paused).
    public func position(at date: Date) -> Double {
        isPlaying ? date.timeIntervalSince(songStart) : seenAt.timeIntervalSince(songStart)
    }

    /// When the song ends, if the length is known and it's playing.
    public var songEnd: Date? {
        guard isPlaying, let duration else { return nil }
        return songStart.addingTimeInterval(duration)
    }
}

/// How the lyrics are shown.
public struct LyricsSettings: Codable, Sendable, Equatable {
    public static let lineChoices = [1, 3, 5]

    public var lineCount: Int
    /// Text size factor: 0.85 small, 1 normal, 1.2 large.
    public var textScale: Double
    /// Active-line colour (0xRRGGBB); nil = the look's colour.
    public var accentHex: UInt32?

    public init(lineCount: Int = 3, textScale: Double = 1, accentHex: UInt32? = nil) {
        self.lineCount = lineCount
        self.textScale = textScale
        self.accentHex = accentHex
    }

    public var clampedLineCount: Int { Self.lineChoices.contains(lineCount) ? lineCount : 3 }
}

/// `lyrics.json`: settings, what's playing, and lyrics of recently played songs.
public struct LyricsState: Codable, Sendable, Equatable {
    public static let cacheLimit = 30

    public var settings: LyricsSettings
    public var nowPlaying: NowPlaying?
    public var songs: [SongLyrics]
    public var lastError: String?

    public init(settings: LyricsSettings = LyricsSettings(), nowPlaying: NowPlaying? = nil, songs: [SongLyrics] = [], lastError: String? = nil) {
        self.settings = settings
        self.nowPlaying = nowPlaying
        self.songs = songs
        self.lastError = lastError
    }

    public static let empty = LyricsState()

    public var current: SongLyrics? {
        guard let nowPlaying else { return nil }
        return songs.first { $0.key == nowPlaying.key }
    }

    public func lyrics(for key: String) -> SongLyrics? { songs.first { $0.key == key } }

    /// Adds or replaces a song, keeping the most recent `cacheLimit`.
    public mutating func store(_ song: SongLyrics) {
        songs.removeAll { $0.key == song.key }
        songs.insert(song, at: 0)
        if songs.count > Self.cacheLimit { songs.removeLast(songs.count - Self.cacheLimit) }
    }
}

public enum LyricsStores {
    public static func state(in directory: URL = AppGroup.containerURL) -> JSONFileStore<LyricsState> {
        JSONFileStore(directory: directory, fileName: "lyrics.json") { .empty }
    }
}

// MARK: - LRC

public enum LRCParser {
    /// Parses "[mm:ss.xx] text" lines. A line may carry several time tags; metadata tags
    /// ([ar:], [ti:], [offset:]) are skipped, except [offset:±ms], which shifts every line.
    public static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        var offset = 0.0
        for raw in text.components(separatedBy: .newlines) {
            var rest = Substring(raw.trimmingCharacters(in: .whitespaces))
            var times: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let time = timestamp(tag) {
                    times.append(time)
                } else if tag.lowercased().hasPrefix("offset:"), let ms = Double(tag.dropFirst(7).trimmingCharacters(in: .whitespaces)) {
                    offset = ms / 1000
                }
                rest = rest[rest.index(after: close)...]
            }
            let words = rest.trimmingCharacters(in: .whitespaces)
            for time in times {
                lines.append(LyricLine(time: time, text: words))
            }
        }
        // A positive offset means the lyrics should appear earlier.
        return lines.map { LyricLine(time: max($0.time - offset, 0), text: $0.text) }.sorted { $0.time < $1.time }
    }

    /// "mm:ss", "mm:ss.xx" or "mm:ss:xx" → seconds.
    static func timestamp(_ tag: Substring) -> Double? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, let minutes = Double(parts[0]), minutes >= 0 else { return nil }
        if parts.count == 2 {
            guard let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        }
        guard parts.count == 3, let seconds = Double(parts[1]), let hundredths = Double(parts[2]) else { return nil }
        return minutes * 60 + seconds + hundredths / 100
    }
}

// MARK: - What to show

/// The lines to draw at one moment: previous (faded), current (bright), next ones (dim).
public struct LyricsWindow: Sendable, Equatable {
    public let previous: String?
    public let current: String?
    public let next: [String]
}

public enum LyricsTimeline {
    /// Index of the line being sung at `position` (nil before the first line).
    public static func index(at position: Double, in lines: [LyricLine]) -> Int? {
        var low = 0, high = lines.count - 1, found: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position { found = mid; low = mid + 1 } else { high = mid - 1 }
        }
        return found
    }

    /// The window for `lineCount` lines (1: current only; 3: previous, current, next; 5: one before, three after).
    public static func window(at position: Double, lines: [LyricLine], lineCount: Int) -> LyricsWindow {
        let index = Self.index(at: position, in: lines)
        let current = index.map { lines[$0].text }
        let previous = lineCount > 1 ? index.flatMap { $0 > 0 ? lines[$0 - 1].text : nil } : nil
        let start = (index ?? -1) + 1
        let wanted = lineCount == 1 ? 0 : lineCount - 2
        let next = start < lines.count ? lines[start..<min(start + wanted, lines.count)].map(\.text) : []
        return LyricsWindow(previous: previous, current: current, next: next)
    }

    /// Entry dates: each line start between `start` and the song's end (at most `limit`).
    public static func dates(nowPlaying: NowPlaying?, lyrics: SongLyrics?, from start: Date, limit: Int = 150) -> [Date] {
        guard let nowPlaying, nowPlaying.isPlaying, let lyrics, lyrics.isSynced else { return [start] }
        let end = nowPlaying.songEnd ?? start.addingTimeInterval(15 * 60)
        let times = lyrics.lines.map { nowPlaying.songStart.addingTimeInterval($0.time) }.filter { $0 > start && $0 <= end }
        var dates = [start] + times.prefix(limit)
        if let songEnd = nowPlaying.songEnd, songEnd > start, dates.count <= limit { dates.append(songEnd) }
        return dates
    }
}

/// View-ready lyrics card.
public struct LyricsSummary: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        /// Synced lines.
        case synced(LyricsWindow)
        /// Plain lyrics only, or no lyrics found: show the song.
        case songOnly(note: String)
        /// Nothing seen playing.
        case idle
    }

    public let title: String?
    public let artist: String?
    public let mode: Mode
    public let lineCount: Int
    public let textScale: Double
    public let accentHex: UInt32?

    public init(title: String?, artist: String?, mode: Mode, lineCount: Int, textScale: Double, accentHex: UInt32?) {
        self.title = title
        self.artist = artist
        self.mode = mode
        self.lineCount = lineCount
        self.textScale = textScale
        self.accentHex = accentHex
    }

    public static func make(state: LyricsState, at date: Date) -> LyricsSummary {
        let settings = state.settings
        guard let playing = state.nowPlaying,
              // A song last seen more than its length (or 15 min) ago is stale.
              date.timeIntervalSince(playing.seenAt) < max(playing.duration ?? 0, 900) + 60 else {
            return LyricsSummary(title: nil, artist: nil, mode: .idle, lineCount: settings.clampedLineCount, textScale: settings.textScale, accentHex: settings.accentHex)
        }
        let mode: Mode
        if let song = state.current, song.isSynced {
            if let end = playing.songEnd, date >= end {
                mode = .songOnly(note: "Song ended")
            } else {
                mode = .synced(LyricsTimeline.window(at: playing.position(at: date), lines: song.lines, lineCount: settings.clampedLineCount))
            }
        } else if let song = state.current {
            mode = .songOnly(note: song.instrumental ? "Instrumental" : (song.plain != nil ? "No synced lyrics" : "No lyrics found"))
        } else {
            mode = .songOnly(note: "Looking for lyrics…")
        }
        return LyricsSummary(title: playing.title, artist: playing.artist, mode: mode, lineCount: settings.clampedLineCount, textScale: settings.textScale, accentHex: settings.accentHex)
    }
}

// MARK: - LRCLIB

#if !STORE_BUILD   // Not in the App Store build (spec §10 Build flavours): LRCLIB lyrics are personal-build only.

/// https://lrclib.net — free, community time-coded lyrics, no key.
public enum LRCLIBClient {
    struct Record: Decodable {
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    static let userAgent = "DashCraft/1.1 (CarPlay widget app)"

    /// Exact match first (title, artist, album, duration), then a search.
    public static func fetch(title: String, artist: String, album: String?, duration: Double?, session: URLSession = .shared) async throws -> SongLyrics {
        var exact = URLComponents(string: "https://lrclib.net/api/get")
        var items = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let album, !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if let duration { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        exact?.queryItems = items
        if let url = exact?.url, let record: Record = try await get(url, session: session) {
            return song(from: record, title: title, artist: artist, album: album, duration: duration)
        }
        var search = URLComponents(string: "https://lrclib.net/api/search")
        search?.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let url = search?.url, let records: [Record] = try await get(url, session: session) {
            let best = records.first { $0.syncedLyrics?.isEmpty == false && closeEnough($0.duration, duration) }
                ?? records.first { $0.syncedLyrics?.isEmpty == false }
                ?? records.first
            if let best { return song(from: best, title: title, artist: artist, album: album, duration: duration) }
        }
        return SongLyrics(title: title, artist: artist, album: album, duration: duration)
    }

    static func closeEnough(_ a: Double?, _ b: Double?) -> Bool {
        guard let a, let b else { return true }
        return abs(a - b) <= 3
    }

    static func song(from record: Record, title: String, artist: String, album: String?, duration: Double?) -> SongLyrics {
        SongLyrics(
            title: title, artist: artist, album: album, duration: duration ?? record.duration,
            lines: LRCParser.parse(record.syncedLyrics ?? ""),
            plain: record.plainLyrics?.isEmpty == false ? record.plainLyrics : nil,
            instrumental: record.instrumental ?? false
        )
    }

    /// Nil on 404 (not found).
    static func get<T: Decodable>(_ url: URL, session: URLSession) async throws -> T? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
#endif
