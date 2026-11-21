import AppIntents
#if !WIDGET_EXTENSION
import MusicKit
#endif

// Compiled into both the app and the widget extension. The widget only needs the types for
// `Button(intent:)`; as `AudioPlaybackIntent`s they run in the app's process, which is where
// the system music player can be controlled. Spec: these buttons are a bonus. The Music
// widget looks complete without them, and Music → "Show play buttons" turns them off.

struct MusicPlayPauseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Play or Pause Music" }
    static var description: IntentDescription { IntentDescription("Plays or pauses the Music app.") }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let player = SystemMusicPlayer.shared
        if player.state.playbackStatus == .playing {
            player.pause()
        } else {
            try await player.play()
        }
        #endif
        return .result()
    }
}

struct MusicNextIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Next Track" }
    static var description: IntentDescription { IntentDescription("Skips to the next track in the Music app.") }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        try await SystemMusicPlayer.shared.skipToNextEntry()
        #if !STORE_BUILD
        try? await Task.sleep(for: .milliseconds(600))
        await LyricsSync.shared.sync()
        #endif
        #endif
        return .result()
    }
}
