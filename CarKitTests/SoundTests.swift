import Foundation
import Testing
@testable import CarKit

@Suite("Connect sound")
struct ConnectSoundTests {
    @Test func greetingTextInBothLanguages() {
        var settings = ConnectSoundSettings(greetingName: " Namazee ")
        #expect(settings.greetingText == "Welcome back, Namazee.")
        settings.greetingLanguage = .malay
        #expect(settings.greetingText == "Selamat kembali, Namazee.")
        settings.greetingName = ""
        #expect(settings.greetingText == "Selamat kembali.")
        #expect(GreetingLanguage.malay.voiceLanguage == "ms-MY")
    }

    @Test func entityIDsRoundTrip() {
        let id = UUID()
        for sound in [ConnectSoundKind.bundled("chime-soft"), .imported(id), .greeting, .voice("drive-safe")] {
            #expect(ConnectSoundSettings.sound(entityID: ConnectSoundSettings.entityID(sound)) == sound)
        }
        #expect(ConnectSoundSettings.sound(entityID: "nonsense") == nil)
    }

    @Test func missingSoundsFallBackToTheWelcomeTone() {
        let settings = ConnectSoundSettings(defaultSound: .imported(UUID()))
        #expect(settings.resolved(nil) == .bundled("welcome-tone"))
        #expect(settings.resolved(.bundled("gone")) == .bundled("welcome-tone"))
        #expect(settings.resolved(.greeting) == .greeting)
        #expect(settings.resolved(.bundled("rev-sport")) == .bundled("rev-sport"))
    }

    @Test func pickerListsBundledGreetingAndImported() {
        let clip = ImportedSound(name: "Horn", fileName: "a.m4a", duration: 2)
        let settings = ConnectSoundSettings(imported: [clip])
        #expect(settings.allSounds.count == BundledSound.all.count + VoiceCue.all.count + 2)
        #expect(settings.allSounds.last == .imported(clip.id))
        #expect(settings.name(of: .imported(clip.id)) == "Horn")
        #expect(settings.name(of: .bundled("rev-sport")) == "Sporty rev (synth)")
    }

    @Test func packsAndVoiceCues() {
        for pack in SoundPack.allCases where pack != .voice {
            #expect(!BundledSound.sounds(in: pack).isEmpty, "\(pack)")
        }
        #expect(Set(BundledSound.all.map(\.id)).count == BundledSound.all.count)
        #expect(BundledSound.sounds(in: .engine).count >= 10)
        let cue = VoiceCue.all.first { $0.id == "drive-safe" }
        #expect(cue?.text(language: .english, name: "Namazee") == "Drive safe, Namazee.")
        #expect(cue?.text(language: .malay, name: "") == "Pandu dengan selamat.")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 20)) ?? .now
        let time = VoiceCue.all.first { $0.id == "time-greeting" }
        #expect(time?.text(language: .malay, name: "", at: evening, calendar: calendar) == "Selamat malam.")
        #expect(time?.text(language: .english, name: "", at: evening, calendar: calendar) == "Good evening.")
    }

    @Test func disconnectSoundDefaultsToGoodbyeAndOlderFilesLoad() throws {
        #expect(ConnectSoundSettings().resolvedDisconnect == .bundled("goodbye"))
        #expect(ConnectSoundSettings(disconnectSound: .voice("see-you")).resolvedDisconnect == .voice("see-you"))
        #expect(ConnectSoundSettings(disconnectSound: .imported(UUID())).resolvedDisconnect == .bundled("goodbye"))
        let old = #"{"defaultSound":{"greeting":{}},"volume":0.8,"greetingName":"","greetingLanguage":"english","imported":[]}"#
        let decoded = try JSONDecoder().decode(ConnectSoundSettings.self, from: Data(old.utf8))
        #expect(decoded.disconnectSound == nil && decoded.voiceIdentifier == nil)
    }

    @Test func volumeIsClamped() {
        #expect(ConnectSoundSettings(volume: 0).clampedVolume == 0.1)
        #expect(ConnectSoundSettings(volume: 3).clampedVolume == 1)
    }

    @Test func trimKeepsAtMostFiveSecondsInsideTheClip() {
        let long = ClipTrim.range(start: 2, length: 9, clipDuration: 30)
        #expect(long == 2...7)
        let nearEnd = ClipTrim.range(start: 28, length: 5, clipDuration: 30)
        #expect(nearEnd == 28...30)
        let short = ClipTrim.range(start: -3, length: 5, clipDuration: 2.5)
        #expect(short == 0...2.5)
    }

    @Test func settingsRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = ConnectSoundSettings(defaultSound: .greeting, volume: 0.6, greetingName: "Amir", greetingLanguage: .malay)
        try SoundStores.settings(in: directory).save(settings)
        #expect(SoundStores.settings(in: directory).load() == settings)
    }
}
