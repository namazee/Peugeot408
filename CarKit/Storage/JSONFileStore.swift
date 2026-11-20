import Foundation

/// A small Codable value saved as one JSON file in the App Group container.
/// `load()` never throws: a missing or unreadable file gives the fallback value,
/// so widget providers always have something valid to draw.
public struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    public let fileURL: URL
    private let fallback: @Sendable () -> Value

    public init(directory: URL, fileName: String, fallback: @escaping @Sendable () -> Value) {
        self.fileURL = directory.appending(path: fileName, directoryHint: .notDirectory)
        self.fallback = fallback
    }

    public func load() -> Value {
        guard
            let data = try? Data(contentsOf: fileURL),
            let value = try? JSONDecoder().decode(Value.self, from: data)
        else {
            return fallback()
        }
        return value
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: fileURL, options: .atomic)
    }
}
