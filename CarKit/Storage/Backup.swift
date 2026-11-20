import Foundation

/// Settings → Backup (spec §5: "data export/import as JSON"). One readable JSON file holding every
/// file I entered data into. Caches (weather, prayer times, commute, map, music, calendar, location)
/// are left out because the app rebuilds them; pictures, photos and imported sounds are not
/// included either (a slot or design whose picture is missing falls back to its icon or artwork).
public enum Backup {
    public static let format = "peugeot408-backup"
    public static let version = 1

    /// A file in the backup, with a check that its JSON still decodes as the right type.
    public struct Entry: Sendable {
        public let fileName: String
        public let title: String
        let validate: @Sendable (Data) throws -> Void

        init<Value: Decodable>(_ fileName: String, _ title: String, as type: Value.Type) {
            self.fileName = fileName
            self.title = title
            self.validate = { _ = try JSONDecoder().decode(Value.self, from: $0) }
        }
    }

    public static let entries: [Entry] = [
        Entry("service.json", "Service", as: ServiceLog.self),
        Entry("fuel.json", "Fuel", as: FuelLog.self),
        Entry("renewals.json", "Road tax & insurance", as: RenewalLog.self),
        Entry("tng.json", "Touch 'n Go", as: TnGState.self),
        Entry("parking.json", "Parking", as: ParkingState.self),
        Entry("commute.json", "Home and Work", as: CommuteSettings.self),
        Entry(PrayerService.settingsFile, "Prayer zone", as: PrayerSettings.self),
        Entry("slots.json", "Car Slots", as: SlotsState.self),
        Entry("studio.json", "Studio", as: StudioState.self),
        Entry(AppearanceStore.fileName, "Appearance", as: AppearanceSettings.self),
        Entry("connect-sound.json", "Connect sound", as: ConnectSoundSettings.self),
        Entry("obd.json", "OBD2", as: OBDState.self),
    ]

    public enum BackupError: LocalizedError, Equatable {
        case notABackup
        case newerVersion(Int)
        case badFile(String)

        public var errorDescription: String? {
            switch self {
            case .notABackup: "This isn't a Peugeot408 backup file."
            case .newerVersion(let version): "This backup is from a newer version of the app (format \(version))."
            case .badFile(let title): "The \(title) data in this backup is damaged, so nothing was changed."
            }
        }
    }

    /// What an import changed.
    public struct ImportResult: Sendable, Equatable {
        public let restored: [String]
        public let createdAt: Date?
    }

    /// Builds the backup file from the files that exist in `directory`.
    public static func export(from directory: URL = AppGroup.containerURL, now: Date = .now) throws -> Data {
        var files: [String: Any] = [:]
        for entry in entries {
            let url = directory.appending(path: entry.fileName, directoryHint: .notDirectory)
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { continue }
            files[entry.fileName] = object
        }
        let root: [String: Any] = [
            "format": format,
            "version": version,
            "createdAt": ISO8601DateFormatter().string(from: now),
            "files": files,
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// Restores a backup into `directory`. Every file is checked first, so a damaged backup changes nothing.
    /// Files missing from the backup are left as they are.
    @discardableResult
    public static func restore(_ data: Data, into directory: URL = AppGroup.containerURL) throws -> ImportResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["format"] as? String == format,
              let files = root["files"] as? [String: Any] else {
            throw BackupError.notABackup
        }
        if let fileVersion = root["version"] as? Int, fileVersion > version {
            throw BackupError.newerVersion(fileVersion)
        }

        var pending: [(Entry, Data)] = []
        for entry in entries {
            guard let object = files[entry.fileName] else { continue }
            guard let fileData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
                  (try? entry.validate(fileData)) != nil else {
                throw BackupError.badFile(entry.title)
            }
            pending.append((entry, fileData))
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (entry, fileData) in pending {
            try fileData.write(to: directory.appending(path: entry.fileName, directoryHint: .notDirectory), options: .atomic)
        }
        let createdAt = (root["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return ImportResult(restored: pending.map(\.0.title), createdAt: createdAt)
    }

    /// "Peugeot408 backup 2026-11-20.json"
    public static func fileName(for date: Date = .now) -> String {
        "Peugeot408 backup \(date.formatted(.iso8601.year().month().day())).json"
    }
}
