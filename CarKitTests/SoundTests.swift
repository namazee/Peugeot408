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
        for sound in [ConnectSoundKind.bundled("chime-soft"), .imported(id), .greeting] {
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
        #expect(settings.allSounds.count == BundledSound.all.count + 2)
        #expect(settings.allSounds.last == .imported(clip.id))
        #expect(settings.name(of: .imported(clip.id)) == "Horn")
        #expect(settings.name(of: .bundled("rev-sport")) == "Sporty rev")
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
