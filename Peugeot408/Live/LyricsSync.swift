// Not in the App Store build (spec §10 Build flavours): LRCLIB lyrics are personal-build only.
#if !STORE_BUILD
import ActivityKit
import AppIntents
import CarKit
import Foundation
import MediaPlayer
import WidgetKit

/// Reads what the Apple Music system player is playing, fetches its time-coded lyrics from
/// LRCLIB when they aren't cached, saves both to `lyrics.json`, and redraws the Lyrics widget and
/// any slot showing it. The widget then changes lines by itself from the saved timing.
@MainActor
final class LyricsSync {
    static let shared = LyricsSync()

    private var observing = false
    /// `Activity` isn't Sendable, so it's only touched in the nonisolated helpers below
    /// (the same pattern as the drive-session Live Activity).
    nonisolated(unsafe) private var activity: Activity<LyricsActivityAttributes>?
    private var activityTitle: String?
    private var activityTask: Task<Void, Never>?

    /// Starts listening to the player's song / play-pause changes (while the app runs).
    func startObserving() {
        guard !observing else { return }
        observing = true
        let player = MPMusicPlayerController.systemMusicPlayer
        player.beginGeneratingPlaybackNotifications()
        let center = NotificationCenter.default
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, .MPMusicPlayerControllerPlaybackStateDidChange] {
            center.addObserver(forName: name, object: player, queue: .main) { _ in
                Task { @MainActor in await LyricsSync.shared.sync() }
            }
        }
    }

    /// Re-anchors the timing and fetches lyrics if needed. Returns a short status for the app.
    @discardableResult
    func sync(directory: URL = AppGroup.containerURL, now: Date = .now) async -> String {
        let store = LyricsStores.state(in: directory)
        var state = store.load()
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem, let title = item.title, !title.isEmpty else {
            if state.nowPlaying?.isPlaying == true {
                state.nowPlaying?.isPlaying = false
                state.nowPlaying?.seenAt = now
                try? store.save(state)
                reloadWidgets(directory: directory)
            }
            endActivity()
            return "Nothing is playing in Apple Music."
        }
        let position = player.currentPlaybackTime.isFinite ? player.currentPlaybackTime : 0
        let playing = NowPlaying(
            title: title,
            artist: item.artist ?? item.albumArtist ?? "",
            album: item.albumTitle,
            duration: item.playbackDuration > 0 ? item.playbackDuration : nil,
            songStart: now.addingTimeInterval(-position),
            isPlaying: player.playbackState == .playing,
            seenAt: now
        )
        state.nowPlaying = playing
        try? store.save(state)
        reloadWidgets(directory: directory)

        var status = "Synced"
        if state.lyrics(for: playing.key) == nil {
            do {
                let song = try await LRCLIBClient.fetch(title: playing.title, artist: playing.artist, album: playing.album, duration: playing.duration)
                state = store.load()
                state.store(song)
                state.lastError = nil
                try? store.save(state)
                reloadWidgets(directory: directory)
                status = song.isSynced ? "Lyrics found" : (song.plain != nil ? "Only plain lyrics for this song" : "No lyrics found for this song")
            } catch {
                state = store.load()
                state.lastError = "Couldn't reach LRCLIB: \(error.localizedDescription)"
                try? store.save(state)
                status = "Couldn't download lyrics"
            }
        }
        updateActivity(state: store.load())
        return status
    }

    private func reloadWidgets(directory: URL) {
        WidgetCenter.shared.reloadTimelines(ofKind: DataSource.lyrics.widgetKind)
        let slots = SlotStore(directory: directory).load()
        let studio = StudioStores.studio(in: directory).load()
        for slot in SlotsState.slotNumbers where SlotTimeline.sources(slot: slot, state: slots, studio: studio).contains(.lyrics) {
            WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
        }
    }

    // MARK: Live Activity

    /// Shows the lines as a Live Activity while the app is running (if allowed and turned on).
    private func updateActivity(state: LyricsState) {
        activityTask?.cancel()
        guard UserDefaults.standard.bool(forKey: "lyricsLiveActivity"),
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let playing = state.nowPlaying, playing.isPlaying,
              let song = state.current, song.isSynced else {
            endActivity()
            return
        }
        let attributes = LyricsActivityAttributes(title: playing.title, artist: playing.artist)
        activityTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let position = playing.position(at: now)
                let window = LyricsTimeline.window(at: position, lines: song.lines, lineCount: 3)
                let content = LyricsActivityAttributes.ContentState(previous: window.previous, current: window.current ?? "♪", next: window.next.first)
                await self?.show(content, attributes: attributes)
                // Sleep until the next line (or the song ends).
                guard let index = LyricsTimeline.index(at: position, in: song.lines).map({ $0 + 1 }) ?? (song.lines.isEmpty ? nil : 0),
                      index < song.lines.count else { break }
                let wait = playing.songStart.addingTimeInterval(song.lines[index].time).timeIntervalSince(now)
                try? await Task.sleep(for: .seconds(max(wait, 0.2)))
            }
            self?.endActivity()
        }
    }

    private func show(_ content: LyricsActivityAttributes.ContentState, attributes: LyricsActivityAttributes) async {
        if activityTitle == attributes.title {
            await updateActivity(content)
        } else {
            await finishActivity()
            activityTitle = attributes.title
            startActivity(attributes, content)
        }
    }

    nonisolated private func startActivity(_ attributes: LyricsActivityAttributes, _ content: LyricsActivityAttributes.ContentState) {
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: content, staleDate: Date().addingTimeInterval(60)))
    }

    nonisolated private func updateActivity(_ content: LyricsActivityAttributes.ContentState) async {
        await activity?.update(ActivityContent(state: content, staleDate: Date().addingTimeInterval(60)))
    }

    nonisolated private func finishActivity() async {
        let current = activity
        activity = nil
        await current?.end(nil, dismissalPolicy: .immediate)
    }

    func endActivity() {
        activityTitle = nil
        Task { await finishActivity() }
    }
}

/// "Sync Lyrics": for a Shortcuts automation (e.g. when CarPlay connects, or when the Music app
/// opens) so the Lyrics widget knows the song and its timing without opening DashCraft.
struct SyncLyricsIntent: AppIntent {
    static var title: LocalizedStringResource { "Sync Lyrics" }
    static var description: IntentDescription {
        IntentDescription("Reads the song playing in Music and updates the DashCraft Lyrics widget.")
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = await LyricsSync.shared.sync()
        return .result(dialog: IntentDialog(stringLiteral: status))
    }
}
#endif
