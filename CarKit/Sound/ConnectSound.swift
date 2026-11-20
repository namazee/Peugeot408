import Foundation

/// A sound the "Play Connect Sound" shortcut can play.
public enum ConnectSoundKind: Codable, Sendable, Equatable, Hashable {
    /// One of the bundled sounds (`Resources/Sounds/<name>.wav`).
    case bundled(String)
    /// A clip you imported (file in the App Group `sounds/` folder).
    case imported(UUID)
    /// "Welcome back, <name>" spoken on the device.
    case greeting
    /// A short spoken voice cue (`VoiceCue.id`), spoken on the device.
    case voice(String)
}

/// Sound packs (spec §4b Connect sound, Phase 12).
public enum SoundPack: String, Codable, Sendable, CaseIterable, Identifiable {
    case engine, ev, luxury, arcade, pings, scifi, voice, classic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .engine: "Engine starts"
        case .ev: "EV whoosh"
        case .luxury: "Luxury"
        case .arcade: "Retro arcade"
        case .pings: "Minimal pings"
        case .scifi: "Sci-fi"
        case .voice: "Voice cues"
        case .classic: "Classic"
        }
    }

    public var symbol: String {
        switch self {
        case .engine: "engine.combustion.fill"
        case .ev: "bolt.car.fill"
        case .luxury: "sparkles"
        case .arcade: "gamecontroller.fill"
        case .pings: "circle.circle"
        case .scifi: "airplane.circle.fill"
        case .voice: "person.wave.2.fill"
        case .classic: "bell.fill"
        }
    }

    public var summary: String {
        switch self {
        case .engine: "Real recordings: V8s, V10/V12, flat-six, boxer and EV (public domain / CC0)."
        case .ev: "Rising whooshes and electric hums."
        case .luxury: "Soft, low, confident tone pairs and chords."
        case .arcade: "Coins, level-ups and power-ups, 8-bit style."
        case .pings: "A single clean note, for a quiet acknowledgement."
        case .scifi: "Airlocks, consoles and warp sweeps."
        case .voice: "Short spoken lines in English or Malay, in the voice you pick."
        case .classic: "The original chimes, tones and synthesised revs."
        }
    }
}

/// The bundled library. Synthesised packs are made by `tools/make-sounds.py`; the engine pack
/// comes from CC0 / public-domain recordings via `tools/process-engine-sounds.py` (ASSETS-LICENSES.md).
/// Files live in `Resources/Sounds/<id>.m4a`, all at about the same loudness.
public struct BundledSound: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let symbol: String
    public let pack: SoundPack

    public init(_ id: String, _ name: String, _ symbol: String, _ pack: SoundPack) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.pack = pack
    }

    public static let fileExtension = "m4a"

    public static let all: [BundledSound] = engine + [
        BundledSound("ev-rise", "Rising whoosh", "wind", .ev),
        BundledSound("ev-pulse", "Power pulse", "bolt.fill", .ev),
        BundledSound("ev-glide", "Glide up", "arrow.up.right", .ev),
        BundledSound("ev-hum", "Inverter hum", "waveform.path", .ev),
        BundledSound("lux-duet", "Duet", "music.note", .luxury),
        BundledSound("lux-bloom", "Bloom", "sparkles", .luxury),
        BundledSound("lux-glass", "Crystal", "wineglass", .luxury),
        BundledSound("lux-velvet", "Velvet", "circle.lefthalf.filled", .luxury),
        BundledSound("lux-arrival", "Arrival", "door.left.hand.open", .luxury),
        BundledSound("lux-crest", "Crest", "crown.fill", .luxury),
        BundledSound("arc-coin", "Coin", "centsign.circle.fill", .arcade),
        BundledSound("arc-levelup", "Level up", "arrow.up.circle.fill", .arcade),
        BundledSound("arc-powerup", "Power-up", "bolt.circle.fill", .arcade),
        BundledSound("arc-start", "Game start", "play.circle.fill", .arcade),
        BundledSound("arc-1up", "Extra life", "heart.circle.fill", .arcade),
        BundledSound("arc-chain", "Combo", "link.circle.fill", .arcade),
        BundledSound("arc-pinball", "Pinball", "circle.hexagongrid.fill", .arcade),
        BundledSound("arc-victory", "Victory", "trophy.fill", .arcade),
        BundledSound("ping-high", "High", "circle.fill", .pings),
        BundledSound("ping-mid", "Middle", "circle.lefthalf.filled", .pings),
        BundledSound("ping-low", "Low", "circle", .pings),
        BundledSound("ping-double", "Double", "circle.circle", .pings),
        BundledSound("ping-glass", "Glass", "drop.fill", .pings),
        BundledSound("sf-airlock", "Airlock", "door.sliding.left.hand.open", .scifi),
        BundledSound("sf-console", "Console", "terminal.fill", .scifi),
        BundledSound("sf-warp", "Warp", "hurricane", .scifi),
        BundledSound("sf-scan", "Scanner", "dot.radiowaves.left.and.right", .scifi),
        BundledSound("sf-power", "Power up", "power.circle.fill", .scifi),
        BundledSound("sf-portal", "Portal", "circle.dashed", .scifi),
        BundledSound("chime-bright", "Bright chime", "bell.fill", .classic),
        BundledSound("chime-soft", "Soft chime", "bell", .classic),
        BundledSound("welcome-tone", "Welcome tone", "music.note", .classic),
        BundledSound("rev-sport", "Sporty rev (synth)", "gauge.with.dots.needle.100percent", .classic),
        BundledSound("rev-blip", "Double blip (synth)", "gauge.with.dots.needle.67percent", .classic),
        BundledSound("goodbye", "Goodbye", "hand.wave.fill", .classic),
    ]

    /// Engine starts: CC0 / public-domain recordings (tools/engine-sounds.json, ASSETS-LICENSES.md).
    public static let engine: [BundledSound] = [
        BundledSound("eng-v8-bigblock", "Big-block V8", "flame.fill", .engine),
        BundledSound("eng-v8-corvette", "'74 Corvette V8 start", "engine.combustion.fill", .engine),
        BundledSound("eng-v8-mustang", "'85 Mustang V8", "engine.combustion.fill", .engine),
        BundledSound("eng-v8-ferrari", "Ferrari 360 V8", "flag.checkered", .engine),
        BundledSound("eng-v12-lambo", "Lamborghini start-up", "bolt.horizontal.fill", .engine),
        BundledSound("eng-supercar", "Supercar rev", "gauge.with.dots.needle.100percent", .engine),
        BundledSound("eng-flat6-911", "Porsche 911 flat-six", "circle.hexagonpath.fill", .engine),
        BundledSound("eng-boxer-wrx", "Subaru WRX boxer", "wind", .engine),
        BundledSound("eng-v10-m6", "BMW M6 V10 start", "key.fill", .engine),
        BundledSound("eng-v8-maserati", "Maserati sport mode", "speedometer", .engine),
        BundledSound("eng-ev-start", "Electric car start", "bolt.car.fill", .engine),
        BundledSound("eng-hatch-start", "Hatchback start", "car.fill", .engine),
    ]

    public static func sounds(in pack: SoundPack) -> [BundledSound] { all.filter { $0.pack == pack } }
}

/// Short spoken lines for the Voice cues pack. Your name is added when you've set one.
public struct VoiceCue: Sendable, Equatable, Identifiable {
    public let id: String
    public let english: String
    public let malay: String
    public let symbol: String

    public static let all: [VoiceCue] = [
        VoiceCue(id: "welcome", english: "Welcome back", malay: "Selamat kembali", symbol: "hand.wave.fill"),
        VoiceCue(id: "drive-safe", english: "Drive safe", malay: "Pandu dengan selamat", symbol: "shield.fill"),
        VoiceCue(id: "connected", english: "CarPlay connected", malay: "CarPlay disambungkan", symbol: "link"),
        VoiceCue(id: "lets-go", english: "Let's go", malay: "Jom gerak", symbol: "flag.checkered"),
        VoiceCue(id: "seatbelt", english: "Seatbelt on. Let's roll", malay: "Pakai tali pinggang. Jom", symbol: "figure.seated.seatbelt"),
        VoiceCue(id: "journey", english: "Have a good journey", malay: "Semoga perjalanan anda lancar", symbol: "road.lanes"),
        VoiceCue(id: "time-greeting", english: "Good morning", malay: "Selamat pagi", symbol: "sun.max.fill"),
        VoiceCue(id: "home", english: "Taking you home", malay: "Jom balik rumah", symbol: "house.fill"),
        VoiceCue(id: "see-you", english: "See you soon", malay: "Jumpa lagi", symbol: "moon.zzz.fill"),
    ]

    /// The line to speak. "time-greeting" follows the time of day; the name is added when set.
    public func text(language: GreetingLanguage, name: String, at date: Date = .now, calendar: Calendar = .current) -> String {
        var line = language == .english ? english : malay
        if id == "time-greeting" {
            let hour = calendar.component(.hour, from: date)
            switch (language, hour) {
            case (.english, 5..<12): line = "Good morning"
            case (.english, 12..<18): line = "Good afternoon"
            case (.english, _): line = "Good evening"
            case (.malay, 5..<12): line = "Selamat pagi"
            case (.malay, 12..<15): line = "Selamat tengah hari"
            case (.malay, 15..<19): line = "Selamat petang"
            case (.malay, _): line = "Selamat malam"
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(line)." : "\(line), \(trimmed)."
    }
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
    /// What "Play Disconnect Sound" plays. Nil in older files = Goodbye.
    public var disconnectSound: ConnectSoundKind?
    /// The iPhone voice for the greeting and voice cues (`AVSpeechSynthesisVoice.identifier`); nil = default.
    public var voiceIdentifier: String?

    public init(defaultSound: ConnectSoundKind = .bundled("welcome-tone"), volume: Double = 0.8, greetingName: String = "", greetingLanguage: GreetingLanguage = .english, imported: [ImportedSound] = [], disconnectSound: ConnectSoundKind? = nil, voiceIdentifier: String? = nil) {
        self.defaultSound = defaultSound
        self.volume = volume
        self.greetingName = greetingName
        self.greetingLanguage = greetingLanguage
        self.imported = imported
        self.disconnectSound = disconnectSound
        self.voiceIdentifier = voiceIdentifier
    }

    /// The disconnect sound, falling back to Goodbye when unset or missing.
    public var resolvedDisconnect: ConnectSoundKind {
        let chosen = disconnectSound ?? .bundled("goodbye")
        let fixed = resolved(chosen)
        return fixed == .bundled("welcome-tone") && chosen != .bundled("welcome-tone") ? .bundled("goodbye") : fixed
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
        case .voice(let id): "“\(VoiceCue.all.first { $0.id == id }?.english ?? id)”"
        }
    }

    /// The text spoken for a voice sound (nil for other sounds).
    public func spokenText(_ sound: ConnectSoundKind, at date: Date = .now) -> String? {
        switch sound {
        case .greeting: greetingText
        case .voice(let id): VoiceCue.all.first { $0.id == id }?.text(language: greetingLanguage, name: greetingName, at: date)
        default: nil
        }
    }

    /// Every sound, in picker order.
    public var allSounds: [ConnectSoundKind] {
        BundledSound.all.map { .bundled($0.id) } + [.greeting] + VoiceCue.all.map { .voice($0.id) } + imported.map { .imported($0.id) }
    }

    /// Falls back to the default welcome tone when the chosen sound no longer exists.
    public func resolved(_ sound: ConnectSoundKind?) -> ConnectSoundKind {
        let chosen = sound ?? defaultSound
        switch chosen {
        case .imported(let id) where !imported.contains(where: { $0.id == id }):
            return .bundled("welcome-tone")
        case .bundled(let id) where !BundledSound.all.contains(where: { $0.id == id }):
            return .bundled("welcome-tone")
        case .voice(let id) where !VoiceCue.all.contains(where: { $0.id == id }):
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
        case .voice(let id): "voice:\(id)"
        }
    }

    public static func sound(entityID: String) -> ConnectSoundKind? {
        if entityID == "greeting" { return .greeting }
        let parts = entityID.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "bundled": return .bundled(parts[1])
        case "imported": return UUID(uuidString: parts[1]).map { .imported($0) }
        case "voice": return .voice(parts[1])
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
