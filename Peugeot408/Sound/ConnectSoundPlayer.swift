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

    /// `disconnect: true` plays the disconnect sound when `sound` is nil.
    func play(_ sound: ConnectSoundKind? = nil, disconnect: Bool = false, directory: URL = AppGroup.containerURL) async throws {
        let settings = SoundStores.settings(in: directory).load()
        let chosen = sound.map { settings.resolved($0) } ?? (disconnect ? settings.resolvedDisconnect : settings.resolved(nil))
        stop()

        let spoken = settings.spokenText(chosen)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: spoken != nil ? .voicePrompt : .default, options: [.duckOthers])
        try session.setActive(true)
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }

        switch chosen {
        case .greeting, .voice:
            let utterance = AVSpeechUtterance(string: spoken ?? settings.greetingText)
            utterance.voice = settings.voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
                ?? AVSpeechSynthesisVoice(language: settings.greetingLanguage.voiceLanguage)
                ?? AVSpeechSynthesisVoice(language: "en-GB")
            utterance.volume = Float(settings.clampedVolume)
            await waitForFinish(timeout: 8) { self.synthesizer.speak(utterance) }

        case .bundled(let id):
            guard let url = Bundle.main.url(forResource: id, withExtension: BundledSound.fileExtension)
                ?? Bundle.main.url(forResource: id, withExtension: "wav") else { throw PlayError.missingFile(id) }
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

/// "Play Disconnect Sound": for the "When CarPlay disconnects" automation. Plays the disconnect
/// sound chosen in the app (Goodbye unless changed).
struct PlayDisconnectSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Play Disconnect Sound" }
    static var description: IntentDescription {
        IntentDescription("Plays your Peugeot408 disconnect sound through the car speakers.")
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await ConnectSoundPlayer.shared.play(nil, disconnect: true)
        return .result()
    }
}

/// Brings an imported clip to the same loudness as the bundled sounds (RMS about -17 dBFS,
/// peaks kept below -0.7 dBFS), rewriting it as AAC.
enum SoundNormalizer {
    static let targetRMS: Float = 0.14
    static let peakLimit: Float = 0.92

    static func normalize(_ url: URL) throws {
        let input = try AVAudioFile(forReading: url)
        let format = input.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(input.length)) else { return }
        try input.read(into: buffer)
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let count = Int(buffer.frameLength), channelCount = Int(format.channelCount)
        var sumSquares: Float = 0, peak: Float = 0
        for c in 0..<channelCount {
            for i in 0..<count {
                let v = channels[c][i]
                sumSquares += v * v
                peak = max(peak, abs(v))
            }
        }
        let rms = (sumSquares / Float(count * channelCount)).squareRoot()
        guard rms > 0.0001, peak > 0 else { return }
        let gain = min(targetRMS / rms, peakLimit / peak)
        guard abs(gain - 1) > 0.05 else { return }
        for c in 0..<channelCount {
            for i in 0..<count { channels[c][i] *= gain }
        }
        let output = url.deletingLastPathComponent().appending(path: "norm-\(url.lastPathComponent)", directoryHint: .notDirectory)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
                                       AVNumberOfChannelsKey: channelCount, AVEncoderBitRateKey: 128_000]
        do {
            let file = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: output)
    }
}
