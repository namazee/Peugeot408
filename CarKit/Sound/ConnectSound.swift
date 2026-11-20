import Foundation

/// A sound the "Play Connect Sound" shortcut can play.
public enum ConnectSoundKind: Codable, Sendable, Equatable, Hashable {
    /// One of the bundled sounds (`Resources/Sounds/<name>.wav`).
    case bundled(String)
    /// A clip you imported (file in the App Group `sounds/` folder).
    case imported(UUID)
    /// "Welcome back, <name>" spoken on the device.
    case greeting
}

/// The bundled library (original, made by `tools/make-sounds.py`).
public struct BundledSound: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let symbol: String

    public static let all: [BundledSound] = [
        BundledSound(id: "chime-bright", name: "Bright chime", symbol: "bell.fill"),
        BundledSound(id: "chime-soft", name: "Soft chime", symbol: "bell"),
        BundledSound(id: "welcome-tone", name: "Welcome tone", symbol: "music.note"),
        BundledSound(id: "rev-sport", name: "Sporty rev", symbol: "gauge.with.dots.needle.100percent"),
        BundledSound(id: "rev-blip", name: "Double blip", symbol: "gauge.with.dots.needle.67percent"),
        BundledSound(id: "goodbye", name: "Goodbye", symbol: "hand.wave.fill"),
    ]
}

public struct ImportedSound: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var fileName: String
    public var duration: Double

    public init(id: UUID = UUID(), name: String, fileName: String, duration: Double) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
    }
}

public enum GreetingLanguage: String, Codable, Sendable, CaseIterable {
    case english
    case malay

    public var displayName: String { self == .english ? "English" : "Bahasa Melayu" }

    /// Voice language for AVSpeechSynthesizer.
    public var voiceLanguage: String { self == .english ? "en-GB" : "ms-MY" }
}

/// `connect-sound.json`.
public struct ConnectSoundSettings: Codable, Sendable, Equatable {
    public static let maxClipSeconds = 5.0
    public static let folder = "sounds"

    /// What the shortcut plays when no sound is chosen in the action.
    public var defaultSound: ConnectSoundKind
    /// 0.1…1 (relative to the current volume; apps can't set the system volume).
    public var volume: Double
    public var greetingName: String
    public var greetingLanguage: GreetingLanguage
    public var imported: [ImportedSound]

    public init(defaultSound: ConnectSoundKind = .bundled("welcome-tone"), volume: Double = 0.8, greetingName: String = "", greetingLanguage: GreetingLanguage = .english, imported: [ImportedSound] = []) {
        self.defaultSound = defaultSound
        self.volume = volume
        self.greetingName = greetingName
        self.greetingLanguage = greetingLanguage
        self.imported = imported
    }

    public static let empty = ConnectSoundSettings()

    public var clampedVolume: Double { min(max(volume, 0.1), 1) }

    /// "Welcome back, Namazee" / "Selamat kembali, Namazee" (no name: just the greeting).
    public var greetingText: String {
        let name = greetingName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch greetingLanguage {
        case .english: return name.isEmpty ? "Welcome back." : "Welcome back, \(name)."
        case .malay: return name.isEmpty ? "Selamat kembali." : "Selamat kembali, \(name)."
        }
    }

    /// Display name for any sound.
    public func name(of sound: ConnectSoundKind) -> String {
        switch sound {
        case .bundled(let id): BundledSound.all.first { $0.id == id }?.name ?? id
        case .imported(let id): imported.first { $0.id == id }?.name ?? "Imported sound"
        case .greeting: "Spoken greeting"
        }
    }

    /// Every sound, in picker order.
    public var allSounds: [ConnectSoundKind] {
        BundledSound.all.map { .bundled($0.id) } + [.greeting] + imported.map { .imported($0.id) }
    }

    /// Falls back to the default welcome tone when the chosen sound no longer exists.
    public func resolved(_ sound: ConnectSoundKind?) -> ConnectSoundKind {
        let chosen = sound ?? defaultSound
        switch chosen {
        case .imported(let id) where !imported.contains(where: { $0.id == id }):
            return .bundled("welcome-tone")
        case .bundled(let id) where !BundledSound.all.contains(where: { $0.id == id }):
            return .bundled("welcome-tone")
        default:
            return chosen
        }
    }

    /// String id used by the App Intent entity ("bundled:chime-soft", "imported:<uuid>", "greeting").
    public static func entityID(_ sound: ConnectSoundKind) -> String {
        switch sound {
        case .bundled(let id): "bundled:\(id)"
        case .imported(let id): "imported:\(id.uuidString)"
        case .greeting: "greeting"
        }
    }

    public static func sound(entityID: String) -> ConnectSoundKind? {
        if entityID == "greeting" { return .greeting }
        let parts = entityID.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "bundled": return .bundled(parts[1])
        case "imported": return UUID(uuidString: parts[1]).map { .imported($0) }
        default: return nil
        }
    }
}

/// Picks the part of an imported clip to keep (at most 5 seconds).
public enum ClipTrim {
    /// A valid range: starts within the clip and lasts at most `maxClipSeconds`.
    public static func range(start: Double, length: Double, clipDuration: Double) -> ClosedRange<Double> {
        let duration = max(clipDuration, 0)
        let begin = min(max(start, 0), max(duration - 0.1, 0))
        let span = min(max(length, 0.1), ConnectSoundSettings.maxClipSeconds, duration - begin)
        return begin...(begin + max(span, 0))
    }
}

public enum SoundStores {
    public static func settings(in directory: URL = AppGroup.containerURL) -> JSONFileStore<ConnectSoundSettings> {
        JSONFileStore(directory: directory, fileName: "connect-sound.json") { .empty }
    }

    public static func folder(in directory: URL = AppGroup.containerURL) -> URL {
        directory.appending(path: ConnectSoundSettings.folder, directoryHint: .isDirectory)
    }
}
