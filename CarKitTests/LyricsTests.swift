import Foundation
import Testing
@testable import CarKit

@Suite("Synced lyrics")
struct LyricsTests {
    private let lrc = """
    [ar:Someone]
    [ti:A Song]
    [00:01.50]First line
    [00:04.00][00:20.00]Chorus line
    [00:08.25]Third line
    [00:12:50]Old-style stamp
    [00:15.00]
    """

    @Test func parsesTimestampsRepeatsAndMetadata() {
        let lines = LRCParser.parse(lrc)
        #expect(lines.map(\.time) == [1.5, 4, 8.25, 12.5, 15, 20])
        #expect(lines.first?.text == "First line")
        #expect(lines.last?.text == "Chorus line")
        #expect(lines[4].text.isEmpty)   // an instrumental gap clears the line
    }

    @Test func offsetShiftsLines() {
        let lines = LRCParser.parse("[offset:+500]\n[00:02.00]Hi")
        #expect(lines.first?.time == 1.5)
    }

    @Test func windowForOneThreeAndFiveLines() {
        let lines = LRCParser.parse(lrc)
        #expect(LyricsTimeline.index(at: 0.5, in: lines) == nil)
        #expect(LyricsTimeline.index(at: 9, in: lines) == 2)
        let one = LyricsTimeline.window(at: 9, lines: lines, lineCount: 1)
        #expect(one.current == "Third line" && one.previous == nil && one.next.isEmpty)
        let three = LyricsTimeline.window(at: 9, lines: lines, lineCount: 3)
        #expect(three.previous == "Chorus line" && three.next == ["Old-style stamp"])
        let five = LyricsTimeline.window(at: 9, lines: lines, lineCount: 5)
        #expect(five.next.count == 3)
        let before = LyricsTimeline.window(at: 0, lines: lines, lineCount: 3)
        #expect(before.current == nil && before.next == ["First line"])
    }

    @Test func timelineHasOneEntryPerLineUntilTheSongEnds() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let playing = NowPlaying(title: "A Song", artist: "Someone", duration: 18, songStart: start, isPlaying: true, seenAt: start)
        let song = SongLyrics(title: "A Song", artist: "Someone", lines: LRCParser.parse(lrc))
        let dates = LyricsTimeline.dates(nowPlaying: playing, lyrics: song, from: start.addingTimeInterval(5))
        // now, 8.25, 12.5, 15 (20 is after the 18 s end), then the end itself
        #expect(dates.map { $0.timeIntervalSince(start) } == [5, 8.25, 12.5, 15, 18])
        var paused = playing
        paused.isPlaying = false
        #expect(LyricsTimeline.dates(nowPlaying: paused, lyrics: song, from: start).count == 1)
    }

    @Test func summaryModes() {
        let now = Date()
        #expect(LyricsSummary.make(state: .empty, at: now).mode == .idle)
        var state = LyricsState(nowPlaying: NowPlaying(title: "A Song", artist: "Someone", duration: 200, songStart: now.addingTimeInterval(-9), isPlaying: true, seenAt: now))
        #expect(LyricsSummary.make(state: state, at: now).mode == .songOnly(note: "Looking for lyrics…"))
        state.store(SongLyrics(title: "a song", artist: "SOMEONE", lines: LRCParser.parse(lrc)))
        guard case .synced(let window) = LyricsSummary.make(state: state, at: now).mode else {
            Issue.record("expected synced lines")
            return
        }
        #expect(window.current == "Third line")
        state.store(SongLyrics(title: "A Song", artist: "Someone", plain: "words"))
        #expect(LyricsSummary.make(state: state, at: now).mode == .songOnly(note: "No synced lyrics"))
        #expect(SampleData.card(for: .lyrics, now: now).source == .lyrics)
    }

    @Test func cacheKeepsRecentSongsOnly() {
        var state = LyricsState()
        for i in 0..<(LyricsState.cacheLimit + 5) { state.store(SongLyrics(title: "Song \(i)", artist: "A")) }
        #expect(state.songs.count == LyricsState.cacheLimit)
        #expect(state.songs.first?.title == "Song \(LyricsState.cacheLimit + 4)")
    }

    @Test func lrclibRecordBecomesSong() {
        let record = LRCLIBClient.Record(trackName: "A Song", artistName: "Someone", albumName: nil, duration: 181, instrumental: false, plainLyrics: "", syncedLyrics: "[00:01.00]Hello")
        let song = LRCLIBClient.song(from: record, title: "A Song", artist: "Someone", album: nil, duration: nil)
        #expect(song.isSynced && song.duration == 181 && song.plain == nil)
        #expect(LRCLIBClient.closeEnough(180, 182) && !LRCLIBClient.closeEnough(180, 190))
    }
}
