import AppIntents
import AVFoundation
import CarKit
import Foundation

/// Plays a connect sound through the current audio route (the car speakers when CarPlay is
/// connected), ducking whatever else is playing, then hands audio back.
@MainActor
final class ConnectSoundPlayer: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = ConnectSoundPlayer()

    enum PlayError: Error, LocalizedError {
        case missingFile(String)

        var errorDescription: String? {
            switch self {
            case .missingFile(let name): "The sound \"\(name)\" is missing."
            }
        }
    }

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    func play(_ sound: ConnectSoundKind? = nil, directory: URL = AppGroup.containerURL) async throws {
        let settings = SoundStores.settings(in: directory).load()
        let chosen = settings.resolved(sound)
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: chosen == .greeting ? .voicePrompt : .default, options: [.duckOthers])
        try session.setActive(true)
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }

        switch chosen {
        case .greeting:
            let utterance = AVSpeechUtterance(string: settings.greetingText)
            utterance.voice = AVSpeechSynthesisVoice(language: settings.greetingLanguage.voiceLanguage)
                ?? AVSpeechSynthesisVoice(language: "en-GB")
            utterance.volume = Float(settings.clampedVolume)
            await waitForFinish(timeout: 8) { self.synthesizer.speak(utterance) }

        case .bundled(let id):
            guard let url = Bundle.main.url(forResource: id, withExtension: "wav") else { throw PlayError.missingFile(id) }
            try await playFile(url, volume: settings.clampedVolume)

        case .imported(let id):
            guard let item = settings.imported.first(where: { $0.id == id }) else { throw PlayError.missingFile("imported") }
            let url = SoundStores.folder(in: directory).appending(path: item.fileName, directoryHint: .notDirectory)
            try await playFile(url, volume: settings.clampedVolume)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finish()
    }

    private func playFile(_ url: URL, volume: Double) async throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = Float(volume)
        player.delegate = self
        self.player = player
        // Clips are 5 s at most; the timeout is a safety net if the route changes mid-play.
        await waitForFinish(timeout: min(player.duration + 2, 10)) { _ = player.play() }
        self.player = nil
    }

    private func waitForFinish(timeout: TimeInterval, start: () -> Void) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish()
            }
        }
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}

// MARK: - Shortcut

struct ConnectSoundEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Sound" }
    static var defaultQuery: ConnectSoundQuery { ConnectSoundQuery() }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ConnectSoundQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ConnectSoundEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ConnectSoundEntity] {
        let settings = SoundStores.settings().load()
        return settings.allSounds.map { ConnectSoundEntity(id: ConnectSoundSettings.entityID($0), name: settings.name(of: $0)) }
    }
}

/// "Play Connect Sound": meant for a Shortcuts automation "When CarPlay connects", set to run
/// immediately. Plays through the car speakers at the volume set in the app, ducking other audio.
struct PlayConnectSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Play Connect Sound" }
    static var description: IntentDescription {
        IntentDescription("Plays your Peugeot408 connect sound (or the one you pick) through the car speakers.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Sound", description: "Leave empty to use the sound chosen in the app.")
    var sound: ConnectSoundEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        let chosen = sound.flatMap { ConnectSoundSettings.sound(entityID: $0.id) }
        try await ConnectSoundPlayer.shared.play(chosen)
        return .result()
    }
}
